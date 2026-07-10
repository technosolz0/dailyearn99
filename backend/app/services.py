from app.models import FruitGame
from app.models import FruitSetting
from datetime import datetime, timezone
from typing import List, Dict, Tuple, Optional
import asyncio
import hashlib
import hmac
import json
import random
import secrets
import threading
import time
import uuid

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core.notifications import send_push_to_admin
from app.core.notifications import send_push_to_user
from app.models import ArrowAttempt
from app.models import ArrowContest
from app.models import ArrowGame
from app.models import ArrowLeaderboard
from app.models import ArrowPuzzleSeed
from app.models import Contest, ContestParticipant, User
from app.models import FruitContest
from app.models import FruitEvent
from app.models import FruitLeaderboard
from app.models import FruitMatch
from app.models import FruitScore
from app.models import ImagePuzzleAttempt
from app.models import ImagePuzzleContest
from app.models import ImagePuzzleGame
from app.models import ImagePuzzleLeaderboard
from app.models import RTPSettings
from app.models import Spin as SpinModel, SpinAuditLog as AuditLogModel
from app.models import User, Contest, ContestParticipant, WalletTransaction, Referral, Spin, WordContest, WordQuestion, WordAttempt, WordAnswer, WordLeaderboard, LotteryDraw, LotteryTicket, MinesGame, MinesSetting, PlinkoGame, PlinkoSetting, PlinkoMultiplier, PlinkoRTP, BlackjackGame
from app.websocket import arrow_leaderboard_manager, arrow_ws_manager
from app.websocket import fruit_leaderboard_manager, fruit_ws_manager
from app.websocket import puzzle_leaderboard_manager
from app.websocket import puzzle_ws_manager
from app.websocket import word_leaderboard_manager
from app.websocket import word_ws_manager

# Thread-safe in-memory Leaderboard Manager mimicking Redis Sorted Sets
class LeaderboardManager:
    def __init__(self):
        self._lock = threading.Lock()
        # Format: {contest_id: {user_id: (score, timestamp, user_name)}}
        self._scores: Dict[int, Dict[int, Tuple[int, datetime, str]]] = {}

    def update_score(self, contest_id: int, user_id: int, name: str, score: int):
        with self._lock:
            if contest_id not in self._scores:
                self._scores[contest_id] = {}
            self._scores[contest_id][user_id] = (score, datetime.now(timezone.utc), name)

    def get_leaderboard(self, contest_id: int) -> List[Dict]:
        with self._lock:
            if contest_id not in self._scores:
                return []
            
            # Sort players: highest score first, then earliest timestamp (faster answer)
            sorted_players = sorted(
                self._scores[contest_id].items(),
                key=lambda x: (-x[1][0], x[1][1])
            )
            
            leaderboard = []
            for rank, (u_id, (score, _, name)) in enumerate(sorted_players, start=1):
                leaderboard.append({
                    "user_id": u_id,
                    "name": name,
                    "score": score,
                    "rank": rank
                })
            return leaderboard

    def load_from_db(self, db: Session, contest_id: int):
        # Bootstrap in-memory cache from DB records
        participants = (
            db.query(ContestParticipant)
            .join(User)
            .filter(ContestParticipant.contest_id == contest_id)
            .all()
        )
        with self._lock:
            self._scores[contest_id] = {}
            for p in participants:
                self._scores[contest_id][p.user_id] = (p.score, p.joined_at, p.user.name or p.user.phone)

leaderboard_manager = LeaderboardManager()


class WalletService:
    @staticmethod
    def deduct_entry_fee(db: Session, user: User, entry_fee: float, bonus_cap_pct: float = 0.10, description: str = None) -> WalletTransaction:
        """
        Deduction Rules:
        - Max bonus_cap_pct of entry fee can be paid using Bonus Wallet.
        - Rest is paid by Deposit Wallet.
        - If Deposit Wallet is insufficient, remainder is paid by Winnings Wallet.
        """
        bonus_limit = entry_fee * bonus_cap_pct
        bonus_to_deduct = min(user.bonus_balance, bonus_limit)
        remaining_fee = entry_fee - bonus_to_deduct
        
        deposit_to_deduct = min(user.deposit_balance, remaining_fee)
        winnings_to_deduct = remaining_fee - deposit_to_deduct
        
        if winnings_to_deduct > user.winning_balance:
            raise ValueError("Insufficient wallet balance for this bet.")
            
        # Perform deductions
        user.bonus_balance -= bonus_to_deduct
        user.deposit_balance -= deposit_to_deduct
        user.winning_balance -= winnings_to_deduct
        
        # Create transaction record
        transaction = WalletTransaction(
            user_id=user.id,
            type="ENTRY_FEE",
            amount=entry_fee,
            status="SUCCESS",
            description=description
        )
        db.add(transaction)
        db.commit()
        
        # Trigger referral bonus check
        ReferralService.check_and_trigger_referral(db, user)
        
        return transaction

    @staticmethod
    def credit_prize(db: Session, user: User, amount: float, description: str = None, send_push: bool = True) -> WalletTransaction:
        user.winning_balance += amount
        transaction = WalletTransaction(
            user_id=user.id,
            type="PRIZE_WIN",
            amount=amount,
            status="SUCCESS",
            description=description
        )
        db.add(transaction)
        
        # Send push notification
        if send_push:
            try:
                send_push_to_user(
                    db,
                    user.id,
                    title="🏆 Contest Prize Credited!",
                    body=f"Congratulations! A prize of ₹{amount:.2f} has been credited to your Winnings wallet."
                )
            except Exception:
                pass
        
        return transaction

    @staticmethod
    def process_deposit(db: Session, user: User, amount: float, description: str = "Deposit") -> WalletTransaction:
        user.deposit_balance += amount
        transaction = WalletTransaction(
            user_id=user.id,
            type="DEPOSIT",
            amount=amount,
            status="SUCCESS",
            description=description
        )
        db.add(transaction)
        db.commit()
        
        # Send push notification
        send_push_to_user(
            db,
            user.id,
            title="💰 Deposit Successful!",
            body=f"₹{amount:.2f} has been successfully added to your Deposit wallet."
        )
        
        return transaction

    @staticmethod
    def process_withdrawal(db: Session, user: User, amount: float, description: str = "Withdrawal") -> WalletTransaction:
        if user.winning_balance < amount:
            raise ValueError("Insufficient winning balance to withdraw.")
        
        user.winning_balance -= amount
        transaction = WalletTransaction(
            user_id=user.id,
            type="WITHDRAWAL",
            amount=amount,
            status="PENDING",  # Needs admin approval
            description=description
        )
        db.add(transaction)
        db.commit()
        
        # Send push notification to user
        try:
            send_push_to_user(
                db,
                user.id,
                title="💸 Withdrawal Request Submitted",
                body=f"Your withdrawal request of ₹{amount:.2f} has been submitted and is pending admin approval.",
                data={"event": "withdrawal_pending", "transaction_id": str(transaction.id), "amount": str(amount)}
            )
        except Exception as e:
            print(f"Failed to send withdrawal push to user: {e}")

        # Send push notification to Admin
        try:
            send_push_to_admin(
                db=db,
                title="💸 Withdrawal Request Submitted",
                body=f"User {user.name or user.phone} requested a withdrawal of ₹{amount:.2f}.",
                data={"event": "withdrawal_request", "transaction_id": str(transaction.id), "amount": str(amount)}
            )
        except Exception as e:
            print(f"Failed to send withdrawal push to admin: {e}")
            
        return transaction


class ReferralService:
    @staticmethod
    def check_and_trigger_referral(db: Session, referred_user: User):
        """
        Triggers when a referred user joins their first contest.
        Referral Flow:
        - Referrer (User A) receives ₹50 bonus
        - Referred user (User B) receives ₹20 bonus
        """
        if not referred_user.referred_by:
            return

        # Check if already processed
        existing_referral = (
            db.query(Referral)
            .filter(Referral.referred_user_id == referred_user.id)
            .first()
        )
        
        if existing_referral and existing_referral.bonus_given:
            return

        # Find referrer
        referrer = db.query(User).filter(User.referral_code == referred_user.referred_by.upper()).first()
        if not referrer:
            return

        # Award bonuses
        referrer.bonus_balance += 50.0
        referred_user.bonus_balance += 20.0

        # Create/Update referral record
        if not existing_referral:
            referral = Referral(
                referrer_id=referrer.id,
                referred_user_id=referred_user.id,
                bonus_given=True
            )
            db.add(referral)
        else:
            existing_referral.bonus_given = True

        # Log Transactions
        tx_referrer = WalletTransaction(
            user_id=referrer.id,
            type="REFERRAL_BONUS",
            amount=50.0,
            status="SUCCESS",
            description=f"Referral Bonus: Invited {referred_user.name or referred_user.phone}"
        )
        tx_referred = WalletTransaction(
            user_id=referred_user.id,
            type="REFERRAL_BONUS",
            amount=20.0,
            status="SUCCESS",
            description="Referral Bonus: Welcome Bonus"
        )
        db.add(tx_referrer)
        db.add(tx_referred)
        db.commit()

        # Send push notifications
        send_push_to_user(
            db,
            referrer.id,
            title="🎁 Referral Bonus Credited!",
            body=f"Your friend {referred_user.name or referred_user.phone} joined their first contest! ₹50.00 bonus has been credited to your wallet."
        )
        send_push_to_user(
            db,
            referred_user.id,
            title="🎉 Welcome Referral Bonus!",
            body="Thanks for signing up using a referral link! ₹20.00 welcome bonus has been credited to your wallet."
        )


class SpinGameService:
    # 20 glossy sectors on the real-money casino wheel matching frontend exactly
    WHEEL_SEGMENTS = [
        {"label": "Lose",  "multiplier": 0.0,  "type": "LOSE"},  # 0
        {"label": "0.1x", "multiplier": 0.1,  "type": "WIN"},   # 1
        {"label": "10x",  "multiplier": 10.0, "type": "WIN"},   # 2
        {"label": "0.2x", "multiplier": 0.2,  "type": "WIN"},   # 3
        {"label": "0.4x", "multiplier": 0.4,  "type": "WIN"},   # 4
        {"label": "20x",  "multiplier": 20.0, "type": "WIN"},   # 5
        {"label": "0.5x", "multiplier": 0.5,  "type": "WIN"},   # 6
        {"label": "0.6x", "multiplier": 0.6,  "type": "WIN"},   # 7
        {"label": "30x",  "multiplier": 30.0, "type": "WIN"},   # 8
        {"label": "0.8x", "multiplier": 0.8,  "type": "WIN"},   # 9
        {"label": "1x",   "multiplier": 1.0,  "type": "WIN"},   # 10
        {"label": "40x",  "multiplier": 40.0, "type": "WIN"},   # 11
        {"label": "1.1x", "multiplier": 1.1,  "type": "WIN"},   # 12
        {"label": "Lose", "multiplier": 0.0,  "type": "LOSE"},  # 13
        {"label": "50x",  "multiplier": 50.0, "type": "WIN"},   # 14
        {"label": "1.2x", "multiplier": 1.2,  "type": "WIN"},   # 15
        {"label": "1.5x", "multiplier": 1.5,  "type": "WIN"},   # 16
        {"label": "2x",   "multiplier": 2.0,  "type": "WIN"},   # 17
        {"label": "3x",   "multiplier": 3.0,  "type": "WIN"},   # 18
        {"label": "5x",   "multiplier": 5.0,  "type": "WIN"},   # 19
    ]

    MULTIPLIER_MAP = {
        "Lose": 0.0,
        "0x": 0.0,
        "Try Again": 0.0,
        "0.1x": 0.1,
        "0.2x": 0.2,
        "0.4x": 0.4,
        "0.5x": 0.5,
        "0.6x": 0.6,
        "0.8x": 0.8,
        "1x": 1.0,
        "1.1x": 1.1,
        "1.2x": 1.2,
        "1.5x": 1.5,
        "2x": 2.0,
        "3x": 3.0,
        "5x": 5.0,
        "10x": 10.0,
        "20x": 20.0,
        "30x": 30.0,
        "40x": 40.0,
        "50x": 50.0,
    }

    # In-memory idempotency check to prevent duplicate spins within 5 seconds
    _processed_idempotency_keys = {}
    _idempotency_lock = threading.Lock()
    _maintenance_mode = False

    @classmethod
    def set_maintenance_mode(cls, enabled: bool):
        cls._maintenance_mode = enabled

    @classmethod
    def is_maintenance_mode(cls) -> bool:
        return cls._maintenance_mode

    @classmethod
    def execute_spin(
        cls,
        db: Session,
        user_id: int,
        bet_amount: float,
        idempotency_key: str,
        device_id: str = None,
        ip_address: str = None
    ) -> Spin:
        if cls._maintenance_mode:
            raise ValueError("Spin Wheel is currently under maintenance. Please try again later.")

        # Check KYC status
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            raise ValueError("User not found.")
        if user.is_banned:
            raise ValueError("User account is banned.")
        if user.kyc_status == "REJECTED":
            raise ValueError("KYC has been rejected. Game access restricted.")

        # Check daily responsible gaming limits (Max ₹5000 bet per day)
        today_start = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
        daily_bet_sum = (
            db.query(func.sum(SpinModel.bet_amount))
            .filter(SpinModel.user_id == user_id, SpinModel.created_at >= today_start)
            .scalar()
        ) or 0.0
        if daily_bet_sum + bet_amount > 100000.0:
            raise ValueError("Daily gaming limit reached (₹100000). Keep gaming responsible!")

        # 1. Thread-safe duplicate check using idempotency key
        with cls._idempotency_lock:
            now = datetime.now(timezone.utc)
            if idempotency_key in cls._processed_idempotency_keys:
                last_time = cls._processed_idempotency_keys[idempotency_key]
                if (now - last_time).total_seconds() < 5:
                    raise ValueError("Duplicate spin request detected. Please wait.")
            cls._processed_idempotency_keys[idempotency_key] = now

            # Clean up old keys (older than 10 seconds) to prevent memory leak
            keys_to_delete = [
                k for k, t in cls._processed_idempotency_keys.items()
                if (now - t).total_seconds() > 10
            ]
            for k in keys_to_delete:
                del cls._processed_idempotency_keys[k]

        # 2. Concurrency-safe Wallet lock inside transactional context
        # Lock user record to prevent race conditions (double spending)
        locked_user = (
            db.query(User)
            .filter(User.id == user_id)
            .with_for_update()
            .first()
        )

        # Wallet Deduction: Max 20% bonus balance, rest from Deposit -> Winnings
        WalletService.deduct_entry_fee(db, locked_user, bet_amount, bonus_cap_pct=0.20, description="Entry Fee: Spin Wheel")

        # 3. First-time play check or dynamic weighted random result selection
        first_spin = db.query(SpinModel).filter(SpinModel.user_id == user_id).first() is None
        
        if first_spin:
            if bet_amount < 100:
                multiplier = 1.5
                chosen_outcome = "1.5x"
            else:
                multiplier = 1.2
                chosen_outcome = "1.2x"
        else:
            
            # First check for exact-match override
            rtp = (
                db.query(RTPSettings)
                .filter(
                    RTPSettings.min_amount == bet_amount,
                    RTPSettings.max_amount == bet_amount,
                    RTPSettings.enabled == True
                )
                .first()
            )
            
            # Fallback to checking ranges (ordered by narrowest range first)
            if not rtp:
                rtp = (
                    db.query(RTPSettings)
                    .filter(
                        RTPSettings.min_amount <= bet_amount,
                        RTPSettings.max_amount >= bet_amount,
                        RTPSettings.enabled == True
                    )
                    .order_by((RTPSettings.max_amount - RTPSettings.min_amount).asc())
                    .first()
                )

            if rtp:
                weights = json.loads(rtp.probability_json)
            else:
                # Fallback to standard specifications
                if bet_amount < 50:
                    weights = {
                        "Lose": 20.0, "1x": 20.0, "1.1x": 18.0, "1.2x": 15.0, "1.5x": 12.0,
                        "2x": 8.0, "3x": 5.0, "5x": 1.91,
                        "10x": 0.02, "20x": 0.02, "30x": 0.01, "40x": 0.005, "50x": 0.002,
                        "0.1x": 0.01, "0.2x": 0.01, "0.4x": 0.01,
                        "0.5x": 0.01, "0.6x": 0.01, "0.8x": 0.01,
                    }
                elif bet_amount <= 100:
                    weights = {
                        "Lose": 45.0, "1x": 20.0, "1.1x": 15.0, "1.2x": 8.0, "1.5x": 6.0,
                        "2x": 4.0, "3x": 1.41, "5x": 0.5,
                        "10x": 0.02, "20x": 0.02, "30x": 0.01, "40x": 0.005, "50x": 0.002,
                        "0.1x": 0.01, "0.2x": 0.01, "0.4x": 0.01,
                        "0.5x": 0.01, "0.6x": 0.01, "0.8x": 0.01,
                    }
                else:
                    weights = {
                        "Lose": 65.0, "1x": 15.0, "1.1x": 10.0, "1.2x": 5.0, "1.5x": 3.0,
                        "2x": 1.41, "3x": 0.4, "5x": 0.1,
                        "10x": 0.02, "20x": 0.02, "30x": 0.01, "40x": 0.005, "50x": 0.002,
                        "0.1x": 0.01, "0.2x": 0.01, "0.4x": 0.01,
                        "0.5x": 0.01, "0.6x": 0.01, "0.8x": 0.01,
                    }

            outcomes = list(weights.keys())
            probabilities = list(weights.values())

            chosen_outcome = random.choices(outcomes, weights=probabilities, k=1)[0]
            multiplier = cls.MULTIPLIER_MAP.get(chosen_outcome, 0.0)

        # Find matching segment indices on physical wheel
        matching_segments = [
            (idx, seg) for idx, seg in enumerate(cls.WHEEL_SEGMENTS)
            if (abs(multiplier) < 1e-4 and seg["type"] == "LOSE") or (multiplier > 0.0 and abs(seg["multiplier"] - multiplier) < 1e-4)
        ]
        
        # Pick one at random when multiple LOSE segments exist (e.g. two "Lose" slots)
        segment_index, chosen_segment = random.choice(matching_segments)
        win_amount = bet_amount * multiplier

        # 4. Auto-credit winnings on positive multipliers
        if win_amount > 0:
            WalletService.credit_prize(db, locked_user, win_amount, description="Prize Win: Spin Wheel", send_push=False)

        # 5. Save Spin details
        spin = SpinModel(
            user_id=user_id,
            bet_amount=bet_amount,
            multiplier=multiplier,
            win_amount=win_amount,
            result_type="WIN" if win_amount > 0 else "LOSE",
            wheel_segment=chosen_segment["label"]
        )
        db.add(spin)
        db.flush() # Populate spin.id

        # 6. Save Audit Logs
        audit = AuditLogModel(
            user_id=user_id,
            request_payload=json.dumps({
                "bet_amount": bet_amount,
                "idempotency_key": idempotency_key,
                "device_id": device_id
            }),
            generated_result=json.dumps({
                "spin_id": spin.id,
                "multiplier": multiplier,
                "win_amount": win_amount,
                "segment_index": segment_index,
                "segment_label": chosen_segment["label"]
            }),
            ip_address=ip_address,
            device_id=device_id
        )
        db.add(audit)

        # Trigger referral bonus check if applicable
        ReferralService.check_and_trigger_referral(db, locked_user)

        db.commit()

        # Add physical segment index parameter for API response mappings
        spin.segment_index = segment_index
        spin.updated_balance = locked_user.winning_balance + locked_user.deposit_balance + locked_user.bonus_balance

        # Send push notification for significant wins (>3x)
        if multiplier >= 3.0:
            send_push_to_user(
                db,
                user_id,
                title="🔥 JACKPOT SPIN WINNER!",
                body=f"Whoa! You spun the wheel and hit a massive {multiplier}x! ₹{win_amount:.2f} credited instantly."
            )

        return spin


class PlinkoGameService:
    DEFAULT_MULTIPLIERS = {
        8: {
            "low": [5.6, 1.6, 1.1, 1.0, 0.5, 1.0, 1.1, 1.6, 5.6],
            "medium": [13.0, 3.0, 1.3, 0.7, 0.4, 0.7, 1.3, 3.0, 13.0],
            "high": [29.0, 4.0, 1.5, 0.3, 0.2, 0.3, 1.5, 4.0, 29.0]
        },
        9: {
            "low": [5.6, 2.0, 1.6, 1.0, 0.7, 0.7, 1.0, 1.6, 2.0, 5.6],
            "medium": [18.0, 4.0, 1.6, 0.9, 0.5, 0.5, 0.9, 1.6, 4.0, 18.0],
            "high": [43.0, 7.0, 2.0, 0.6, 0.2, 0.2, 0.6, 2.0, 7.0, 43.0]
        },
        10: {
            "low": [16.0, 9.0, 2.0, 1.4, 1.1, 1.0, 1.1, 1.4, 2.0, 9.0, 16.0],
            "medium": [22.0, 5.0, 2.0, 1.4, 0.6, 0.4, 0.6, 1.4, 2.0, 5.0, 22.0],
            "high": [110.0, 15.0, 4.0, 1.8, 0.7, 0.3, 0.7, 1.8, 4.0, 15.0, 110.0]
        },
        11: {
            "low": [24.0, 10.0, 3.0, 1.8, 1.2, 1.0, 1.0, 1.2, 1.8, 3.0, 10.0, 24.0],
            "medium": [33.0, 8.0, 3.0, 1.6, 0.7, 0.5, 0.5, 0.7, 1.6, 3.0, 8.0, 33.0],
            "high": [170.0, 24.0, 8.1, 2.0, 0.7, 0.2, 0.2, 0.7, 2.0, 8.1, 24.0, 170.0]
        },
        12: {
            "low": [33.0, 11.0, 4.0, 2.0, 1.3, 1.1, 1.0, 1.1, 1.3, 2.0, 4.0, 11.0, 33.0],
            "medium": [50.0, 11.0, 4.0, 2.0, 1.1, 0.6, 0.3, 0.6, 1.1, 2.0, 4.0, 11.0, 50.0],
            "high": [260.0, 33.0, 11.0, 4.0, 2.0, 0.5, 0.2, 0.5, 2.0, 4.0, 11.0, 33.0, 260.0]
        },
        13: {
            "low": [43.0, 13.0, 6.0, 3.0, 1.3, 1.2, 1.0, 1.0, 1.2, 1.3, 3.0, 6.0, 13.0, 43.0],
            "medium": [76.0, 14.0, 6.0, 3.0, 1.3, 0.7, 0.4, 0.4, 0.7, 1.3, 3.0, 6.0, 14.0, 76.0],
            "high": [420.0, 56.0, 18.0, 6.0, 3.0, 1.0, 0.2, 0.2, 1.0, 3.0, 6.0, 18.0, 56.0, 420.0]
        },
        14: {
            "low": [56.0, 18.0, 8.0, 3.8, 2.0, 1.2, 1.0, 1.0, 1.0, 1.2, 2.0, 3.8, 8.0, 18.0, 56.0],
            "medium": [110.0, 18.0, 8.0, 3.8, 1.5, 1.0, 0.5, 0.2, 0.5, 1.0, 1.5, 3.8, 8.0, 18.0, 110.0],
            "high": [620.0, 83.0, 27.0, 8.0, 3.0, 1.3, 0.5, 0.2, 0.5, 1.3, 3.0, 8.0, 27.0, 83.0, 620.0]
        },
        15: {
            "low": [79.0, 24.0, 10.0, 4.8, 2.5, 1.5, 1.0, 1.0, 1.0, 1.0, 1.5, 2.5, 4.8, 10.0, 24.0, 79.0],
            "medium": [180.0, 29.0, 11.0, 5.0, 2.0, 1.1, 0.6, 0.3, 0.3, 0.6, 1.1, 2.0, 5.0, 11.0, 29.0, 180.0],
            "high": [1000.0, 130.0, 37.0, 11.0, 4.0, 1.5, 1.0, 0.5, 0.5, 1.0, 1.5, 4.0, 11.0, 37.0, 130.0, 1000.0]
        },
        16: {
            "low": [110.0, 33.0, 12.0, 6.0, 3.0, 1.8, 1.2, 1.0, 1.0, 1.0, 1.2, 1.8, 3.0, 6.0, 12.0, 33.0, 110.0],
            "medium": [260.0, 43.0, 15.0, 6.0, 3.0, 1.5, 1.0, 0.5, 0.3, 0.5, 1.0, 1.5, 3.0, 6.0, 15.0, 43.0, 260.0],
            "high": [1000.0, 130.0, 43.0, 14.0, 5.0, 2.0, 1.3, 0.5, 0.2, 0.5, 1.3, 2.0, 5.0, 14.0, 43.0, 130.0, 1000.0]
        }
    }

    _maintenance_mode = False

    @classmethod
    def set_maintenance_mode(cls, enabled: bool):
        cls._maintenance_mode = enabled

    @classmethod
    def is_maintenance_mode(cls) -> bool:
        return cls._maintenance_mode

    @classmethod
    def play_plinko(
        cls,
        db: Session,
        user_id: int,
        bet_amount: float,
        rows: int,
        mode: str
    ) -> PlinkoGame:
        # Load settings
        settings = db.query(PlinkoSetting).first()
        if not settings:
            settings = PlinkoSetting(min_bet=10.0, max_bet=5000.0, maintenance_mode=False)
            db.add(settings)
            db.commit()
            db.refresh(settings)

        if settings.maintenance_mode or cls._maintenance_mode:
            raise ValueError("Plinko is currently under maintenance. Please try again later.")

        if bet_amount < settings.min_bet or bet_amount > settings.max_bet:
            raise ValueError(f"Bet amount must be between ₹{settings.min_bet:.2f} and ₹{settings.max_bet:.2f}.")

        # Check KYC
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            raise ValueError("User not found.")
        if user.is_banned:
            raise ValueError("User account is banned.")
        if user.kyc_status == "REJECTED":
            raise ValueError("KYC has been rejected. Game access restricted.")

        # Check daily limits
        today_start = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
        daily_bet_sum = (
            db.query(func.sum(PlinkoGame.bet_amount))
            .filter(PlinkoGame.user_id == user_id, PlinkoGame.created_at >= today_start)
            .scalar()
        ) or 0.0
        if daily_bet_sum + bet_amount > 100000.0:
            raise ValueError("Daily gaming limit reached (₹100000). Keep gaming responsible!")

        # Lock user wallet
        locked_user = (
            db.query(User)
            .filter(User.id == user_id)
            .with_for_update()
            .first()
        )

        # Deduct wallet: Max 20% bonus balance, rest from Deposit -> Winnings
        WalletService.deduct_entry_fee(db, locked_user, bet_amount, bonus_cap_pct=0.20, description="Entry Fee: Plinko Game")

        # ─── Fetch multiplier table (needed for both seeded & normal paths) ───
        multiplier_record = (
            db.query(PlinkoMultiplier)
            .filter(PlinkoMultiplier.rows == rows, PlinkoMultiplier.mode == mode)
            .first()
        )
        if multiplier_record:
            multipliers = json.loads(multiplier_record.multipliers_json)
        else:
            multipliers = cls.DEFAULT_MULTIPLIERS.get(rows, {}).get(mode, [1.0] * (rows + 1))

        # ─── NEW USER SEEDED WIN LOGIC (Pehle 6 bets par fixed multiplier sequence) ───
        # Bet range ₹10–₹49  → sequence: 2.0x, 1.4x, 1.4x, 0.6x, 1.4x, 0.0x
        # Bet range ₹50–₹100 → sequence: 1.4x, 1.2x, 1.5x, 0.6x, 0.5x, 2.0x
        # After 6th bet OR bet amount outside ₹10–₹100 → normal RTP/random logic
        NEW_USER_SEEDED_SEQUENCES = {
            "low_range":  [2.0, 1.4, 1.4, 0.6, 1.4, 0.0],  # ₹10–₹49
            "high_range": [1.4, 1.2, 1.5, 0.6, 0.5, 2.0],  # ₹50–₹100
        }

        is_new_user_bet = locked_user.plinko_bet_count < 6 and 10.0 <= bet_amount <= 100.0

        if is_new_user_bet:
            bet_index = locked_user.plinko_bet_count  # 0-based index (0 = 1st bet, 5 = 6th bet)

            if bet_amount <= 49.99:
                target_multiplier = NEW_USER_SEEDED_SEQUENCES["low_range"][bet_index]
            else:
                target_multiplier = NEW_USER_SEEDED_SEQUENCES["high_range"][bet_index]

            # Find the bucket index whose multiplier is closest to the target
            if target_multiplier == 0.0:
                # Full loss: pick bucket with the lowest multiplier value
                final_bucket = int(multipliers.index(min(multipliers)))
            else:
                final_bucket = int(
                    min(range(len(multipliers)), key=lambda i: abs(multipliers[i] - target_multiplier))
                )

            # Construct ball path that lands in final_bucket
            # (final_bucket = number of right-bounces = sum of path)
            steps = [1] * final_bucket + [0] * (rows - final_bucket)
            random.shuffle(steps)
            path = steps

            # Use exact seeded multiplier (not the bucket's real table value)
            multiplier = target_multiplier
            win_amount = round(bet_amount * multiplier, 2)

        else:
            # ─── Normal Path Generation (existing RTP / binomial logic) ───
            rtp = (
                db.query(PlinkoRTP)
                .filter(
                    PlinkoRTP.min_amount <= bet_amount,
                    PlinkoRTP.max_amount >= bet_amount,
                    PlinkoRTP.rows == rows,
                    PlinkoRTP.mode == mode,
                    PlinkoRTP.enabled == True
                )
                .first()
            )

            if rtp:
                # Admin-configured weighted bucket selection
                weights_map = json.loads(rtp.probability_json)
                outcomes = [int(k) for k in weights_map.keys()]
                probabilities = list(weights_map.values())
                final_bucket = random.choices(outcomes, weights=probabilities, k=1)[0]
                steps = [1] * final_bucket + [0] * (rows - final_bucket)
                random.shuffle(steps)
                path = steps
            else:
                # Standard binomial path simulation
                path = [random.choice([0, 1]) for _ in range(rows)]
                final_bucket = sum(path)

            multiplier = float(multipliers[final_bucket])
            win_amount = bet_amount * multiplier

        # Credit winnings if any
        if win_amount > 0:
            WalletService.credit_prize(db, locked_user, win_amount, description="Prize Win: Plinko Game", send_push=False)

        # Save game
        game = PlinkoGame(
            user_id=user_id,
            bet_amount=bet_amount,
            rows=rows,
            mode=mode,
            path=json.dumps(path),
            final_bucket=final_bucket,
            multiplier=multiplier,
            win_amount=win_amount
        )
        db.add(game)
        db.flush()

        # Trigger referral check
        ReferralService.check_and_trigger_referral(db, locked_user)

        # Increment plinko bet count (used for new user seeded win tracking)
        locked_user.plinko_bet_count += 1

        db.commit()

        # Send push notification for significant wins (>3x)
        if multiplier >= 3.0:
            send_push_to_user(
                db,
                user_id,
                title="🔥 MASSSIVE PLINKO WIN!",
                body=f"Congratulations! You hit a {multiplier}x multiplier and won ₹{win_amount:.2f} on Plinko!"
            )

        game.updated_balance = locked_user.winning_balance + locked_user.deposit_balance + locked_user.bonus_balance
        return game


class ContestService:
    _maintenance_mode = False

    @classmethod
    def set_maintenance_mode(cls, enabled: bool):
        cls._maintenance_mode = enabled

    @classmethod
    def is_maintenance_mode(cls) -> bool:
        return cls._maintenance_mode
    @staticmethod
    def complete_contest(db: Session, contest_id: int) -> dict:

        contest = db.query(Contest).filter(Contest.id == contest_id).first()
        if not contest:
            return {"error": "Contest not found"}
            
        if contest.status == "COMPLETED":
            return {"message": "Contest is already completed", "payouts": 0}
            
        contest.status = "COMPLETED"
        db.commit()
        
        # Query participants ordered by rank
        participants = (
            db.query(ContestParticipant)
            .filter(ContestParticipant.contest_id == contest_id)
            .order_by(ContestParticipant.rank.asc())
            .all()
        )
        
        if not participants:
            return {"message": "Contest completed with 0 participants.", "payouts": 0}
            
        # Standard rank-based prize pool distribution
        payout_pcts = {1: 0.50, 2: 0.30, 3: 0.20}
        if len(participants) == 1:
            payout_pcts = {1: 1.0}
        elif len(participants) == 2:
            payout_pcts = {1: 0.60, 2: 0.40}
            
        rules = []
        if contest.prize_rules:
            try:
                rules = json.loads(contest.prize_rules)
            except Exception:
                pass
                
        payouts_made = 0
        for p in participants:
            user = db.query(User).filter(User.id == p.user_id).first()
            if not user:
                continue
                
            payout_amount = 0.0
            if rules:
                for rule in rules:
                    min_r = rule.get("min_rank")
                    max_r = rule.get("max_rank")
                    prize = rule.get("prize", 0.0)
                    if min_r <= p.rank <= max_r:
                        payout_amount = float(prize)
                        break
            else:
                if p.rank in payout_pcts:
                    payout_amount = contest.prize_pool * payout_pcts[p.rank]
                    
            if payout_amount > 0:
                WalletService.credit_prize(db, user, payout_amount, description=f"Prize Win: Quiz Contest ({contest.title})")
                payouts_made += 1
            else:
                send_push_to_user(
                    db,
                    user.id,
                    title="🏁 Contest Finished!",
                    body=f"Contest '{contest.title}' is completed. You finished at Rank {p.rank}. Better luck next time!"
                )
                
        db.commit()
        return {"message": f"Contest completed. {payouts_made} winners paid out.", "payouts": payouts_made}



class PuzzleAntiCheatService:
    SECRET_KEY = b"PUZZLE_ANTI_CHEAT_SECRET_KEY_12345"

    @classmethod
    def generate_signature(cls, session_id: str, contest_id: int, user_id: int) -> str:
        payload = f"{session_id}:{contest_id}:{user_id}".encode()
        return hmac.new(cls.SECRET_KEY, payload, hashlib.sha256).hexdigest()

    @classmethod
    def verify_signature(cls, session_id: str, contest_id: int, user_id: int, signature: str) -> bool:
        expected = cls.generate_signature(session_id, contest_id, user_id)
        return hmac.compare_digest(expected, signature)

    @classmethod
    def validate_and_playback_session(
        cls,
        shuffled_layout: list,
        grid_size: int,
        telemetry: list,
        reported_time: float,
        reported_moves: int,
        started_at: datetime
    ) -> bool:
        # Check overall duration mismatch against actual wall clock
        actual_elapsed = (datetime.now(timezone.utc) - started_at).total_seconds()
        if reported_time > actual_elapsed + 3.0:
            return False
            
        if len(telemetry) != reported_moves:
            return False

        current_state = list(shuffled_layout)
        pieces_count = grid_size * grid_size

        prev_dt = 0
        for i, move in enumerate(telemetry):
            from_idx = move.get("from_index")
            to_idx = move.get("to_index")
            dt = move.get("dt")

            # Physical limit checks (minimum 100ms between swaps)
            if i > 0:
                if (dt - prev_dt) < 100:
                    return False
            prev_dt = dt

            if not (0 <= from_idx < pieces_count) or not (0 <= to_idx < pieces_count):
                return False

            current_state[from_idx], current_state[to_idx] = current_state[to_idx], current_state[from_idx]

        expected_solved = list(range(pieces_count))
        return current_state == expected_solved


class PuzzleGameService:
    _maintenance_mode = False

    @classmethod
    def set_maintenance_mode(cls, enabled: bool):
        cls._maintenance_mode = enabled

    @classmethod
    def is_maintenance_mode(cls) -> bool:
        return cls._maintenance_mode

    @staticmethod
    def join_puzzle_contest(db: Session, user: User, contest_id: int, device_fingerprint: str, ip_address: str) -> dict:
        if PuzzleGameService.is_maintenance_mode():
            raise ValueError("Image Puzzle is currently under maintenance. Please try again later.")
        contest = db.query(ImagePuzzleContest).filter(ImagePuzzleContest.id == contest_id).with_for_update().first()
        if not contest:
            raise ValueError("Contest not found.")
        if contest.status != "UPCOMING":
            raise ValueError("Registration closed. You can only join upcoming contests.")
        if contest.joined_slots >= contest.total_slots:
            raise ValueError("Contest is full.")

        existing_attempt = db.query(ImagePuzzleAttempt).filter(
            ImagePuzzleAttempt.contest_id == contest_id,
            ImagePuzzleAttempt.user_id == user.id
        ).first()
        if existing_attempt:
            raise ValueError("You have already joined this contest.")

        # Deduct entry fee using the central WalletService
        WalletService.deduct_entry_fee(db, user, contest.entry_fee, description=f"Entry Fee: Puzzle Contest ({contest.title})")
        contest.joined_slots += 1

        session_id = str(uuid.uuid4())
        started_at = datetime.now(timezone.utc)

        attempt = ImagePuzzleAttempt(
            contest_id=contest_id,
            user_id=user.id,
            score=0,
            completion_seconds=0.0,
            moves=0,
            hints_used=0,
            move_sequence="[]",
            is_verified=False,
            device_fingerprint=device_fingerprint,
            session_id=session_id,
            ip_address=ip_address,
            started_at=started_at,
            submitted_at=started_at,
            status="JOINED"
        )
        db.add(attempt)
        db.commit()

        return {
            "session_id": session_id,
            "entry_fee_deducted": contest.entry_fee,
            "status": "SUCCESS"
        }

    @staticmethod
    def start_puzzle_session(db: Session, user: User, contest_id: int, device_fingerprint: str, ip_address: str) -> dict:
        if PuzzleGameService.is_maintenance_mode():
            raise ValueError("Image Puzzle is currently under maintenance. Please try again later.")
        contest = db.query(ImagePuzzleContest).filter(ImagePuzzleContest.id == contest_id).first()
        if not contest:
            raise ValueError("Contest not found.")
        if contest.status != "ACTIVE":
            raise ValueError("Contest is not active.")

        attempt = db.query(ImagePuzzleAttempt).filter(
            ImagePuzzleAttempt.contest_id == contest_id,
            ImagePuzzleAttempt.user_id == user.id
        ).first()
        if not attempt:
            raise ValueError("Access denied. You must join this contest to play.")

        if attempt.status != "JOINED" and attempt.status != "IN_PROGRESS":
            raise ValueError("Session already completed or closed.")

        puzzle_game = db.query(ImagePuzzleGame).filter(ImagePuzzleGame.contest_id == contest_id).first()
        if not puzzle_game:
            n = contest.grid_size * contest.grid_size
            indices = list(range(n))
            while indices == list(range(n)):
                random.shuffle(indices)
            puzzle_game = ImagePuzzleGame(
                contest_id=contest_id,
                shuffled_layout=json.dumps(indices),
                solution_hash=hashlib.sha256(json.dumps(list(range(n))).encode()).hexdigest()
            )
            db.add(puzzle_game)
            db.flush()

        if attempt.status == "JOINED":
            attempt.status = "IN_PROGRESS"
            attempt.started_at = datetime.now(timezone.utc)
            attempt.device_fingerprint = device_fingerprint
            attempt.ip_address = ip_address
            db.commit()

        signature = PuzzleAntiCheatService.generate_signature(attempt.session_id, contest_id, user.id)

        return {
            "session_id": attempt.session_id,
            "shuffled_layout": json.loads(puzzle_game.shuffled_layout),
            "started_at": attempt.started_at,
            "grid_size": contest.grid_size,
            "duration_seconds": contest.duration_seconds,
            "image_url": contest.image_url,
            "signature": signature
        }

    @staticmethod
    def calculate_score(seconds: float, moves: int, hints: int) -> int:
        score = 10000 - (seconds * 5) - (moves * 2) - (hints * 100)
        return max(0, int(score))

    @classmethod
    def submit_puzzle_score(cls, db: Session, user: User, data) -> dict:
        attempt = db.query(ImagePuzzleAttempt).filter(
            ImagePuzzleAttempt.session_id == data.session_id,
            ImagePuzzleAttempt.user_id == user.id
        ).with_for_update().first()

        if not attempt:
            raise ValueError("Puzzle session not found.")
        if attempt.status != "IN_PROGRESS":
            raise ValueError("Score already submitted or session closed.")

        if not PuzzleAntiCheatService.verify_signature(data.session_id, data.contest_id, user.id, data.signature):
            attempt.status = "SUSPICIOUS"
            db.commit()
            raise ValueError("Invalid session signature.")

        contest = db.query(ImagePuzzleContest).filter(ImagePuzzleContest.id == data.contest_id).first()
        puzzle_game = db.query(ImagePuzzleGame).filter(ImagePuzzleGame.contest_id == data.contest_id).first()
        shuffled_layout = json.loads(puzzle_game.shuffled_layout)

        telemetry_dicts = [{"from_index": t.from_index, "to_index": t.to_index, "dt": t.dt} for t in data.telemetry]
        is_legit = PuzzleAntiCheatService.validate_and_playback_session(
            shuffled_layout=shuffled_layout,
            grid_size=contest.grid_size,
            telemetry=telemetry_dicts,
            reported_time=data.completion_seconds,
            reported_moves=data.moves,
            started_at=attempt.started_at
        )

        if not is_legit:
            attempt.status = "SUSPICIOUS"
            db.commit()
            raise ValueError("Anti-Cheat validation failed.")

        score = cls.calculate_score(data.completion_seconds, data.moves, data.hints_used)

        attempt.score = score
        attempt.completion_seconds = data.completion_seconds
        attempt.moves = data.moves
        attempt.hints_used = data.hints_used
        attempt.move_sequence = json.dumps(telemetry_dicts)
        attempt.is_verified = True
        attempt.status = "VERIFIED"
        attempt.submitted_at = datetime.now(timezone.utc)
        db.commit()

        leaderboard_entry = db.query(ImagePuzzleLeaderboard).filter(
            ImagePuzzleLeaderboard.contest_id == data.contest_id,
            ImagePuzzleLeaderboard.user_id == user.id
        ).first()

        if not leaderboard_entry:
            leaderboard_entry = ImagePuzzleLeaderboard(
                contest_id=data.contest_id,
                user_id=user.id,
                score=score,
                completion_seconds=data.completion_seconds,
                rank=9999
            )
            db.add(leaderboard_entry)
        else:
            if score > leaderboard_entry.score:
                leaderboard_entry.score = score
                leaderboard_entry.completion_seconds = data.completion_seconds
        db.commit()

        try:
            puzzle_leaderboard_manager.update_score(data.contest_id, user.id, user.name or user.phone, score, data.completion_seconds)
            leaderboard = puzzle_leaderboard_manager.get_leaderboard(data.contest_id)
            loop = asyncio.get_event_loop()
            if loop.is_running():
                asyncio.run_coroutine_threadsafe(
                    puzzle_ws_manager.broadcast_leaderboard(data.contest_id, leaderboard),
                    loop
                )
        except Exception as e:
            print(f"Puzzle leaderboard WS broadcast error: {e}")

        return {"status": "SUCCESS", "score": score}


class PuzzleRewardService:
    @staticmethod
    def complete_contest_rewards(db: Session, contest_id: int) -> dict:
        contest = db.query(ImagePuzzleContest).filter(ImagePuzzleContest.id == contest_id).with_for_update().first()
        if not contest:
            return {"error": "Contest not found"}
        if contest.status == "COMPLETED":
            return {"message": "Contest is already completed"}

        contest.status = "COMPLETED"
        db.commit()

        attempts = db.query(ImagePuzzleAttempt).filter(
            ImagePuzzleAttempt.contest_id == contest_id,
            ImagePuzzleAttempt.status == "VERIFIED"
        ).order_by(
            ImagePuzzleAttempt.score.desc(),
            ImagePuzzleAttempt.completion_seconds.asc(),
            ImagePuzzleAttempt.moves.asc(),
            ImagePuzzleAttempt.hints_used.asc()
        ).all()

        payout_rules = []
        if contest.prize_rules:
            try:
                payout_rules = json.loads(contest.prize_rules)
            except Exception:
                pass

        payouts_made = 0
        for rank_idx, att in enumerate(attempts, start=1):
            db_leaderboard = db.query(ImagePuzzleLeaderboard).filter(
                ImagePuzzleLeaderboard.contest_id == contest_id,
                ImagePuzzleLeaderboard.user_id == att.user_id
            ).first()
            if db_leaderboard:
                db_leaderboard.rank = rank_idx
            
            user = db.query(User).filter(User.id == att.user_id).first()
            if not user:
                continue

            payout_amount = 0.0
            if payout_rules:
                for rule in payout_rules:
                    if rule.get("min_rank") <= rank_idx <= rule.get("max_rank"):
                        payout_amount = float(rule.get("prize", 0.0))
                        break
            else:
                pcts = {1: 0.5, 2: 0.3, 3: 0.2}
                if rank_idx in pcts:
                    payout_amount = contest.prize_pool * pcts[rank_idx]

            if payout_amount > 0:
                WalletService.credit_prize(db, user, payout_amount, description=f"Prize Win: Puzzle Contest ({contest.title})")
                payouts_made += 1
            else:
                send_push_to_user(
                    db,
                    user.id,
                    title="🏁 Puzzle Contest Completed",
                    body=f"'{contest.title}' has finished! You placed Rank #{rank_idx}. Better luck next time!"
                )

        db.commit()
        return {"status": "SUCCESS", "payouts_made": payouts_made}



class WordAntiCheatService:
    SECRET_KEY = b"WORD_PUZZLE_ANTI_CHEAT_SECRET_KEY_12345"

    @classmethod
    def generate_signature(cls, session_id: str, user_id: int) -> str:
        payload = f"{session_id}:{user_id}".encode()
        return hmac.new(cls.SECRET_KEY, payload, hashlib.sha256).hexdigest()

    @classmethod
    def verify_signature(cls, session_id: str, user_id: int, signature: str) -> bool:
        expected = cls.generate_signature(session_id, user_id)
        return hmac.compare_digest(expected, signature)




class WordGameService:
    _maintenance_mode = False

    @classmethod
    def set_maintenance_mode(cls, enabled: bool):
        cls._maintenance_mode = enabled

    @classmethod
    def is_maintenance_mode(cls) -> bool:
        return cls._maintenance_mode

    @staticmethod
    def join_word_contest(db: Session, user: User, contest_id: int, device_fingerprint: str, ip_address: str) -> dict:
        if WordGameService.is_maintenance_mode():
            raise ValueError("Word Puzzle is currently under maintenance. Please try again later.")
        contest = db.query(WordContest).filter(WordContest.id == contest_id).with_for_update().first()
        if not contest:
            raise ValueError("Contest not found.")
        if contest.status != "UPCOMING":
            raise ValueError("Registration closed. You can only join upcoming contests.")
        if contest.joined_slots >= contest.total_slots:
            raise ValueError("Contest is full.")

        existing_attempt = db.query(WordAttempt).filter(
            WordAttempt.contest_id == contest_id,
            WordAttempt.user_id == user.id
        ).first()
        if existing_attempt:
            raise ValueError("You have already joined this contest.")

        # Deduct entry fee using central WalletService
        WalletService.deduct_entry_fee(db, user, contest.entry_fee, description=f"Entry Fee: Word Contest ({contest.title})")
        contest.joined_slots += 1

        session_id = str(uuid.uuid4())
        started_at = datetime.now(timezone.utc)

        attempt = WordAttempt(
            contest_id=contest_id,
            user_id=user.id,
            total_score=0,
            completion_time_seconds=0.0,
            hints_used=0,
            wrong_attempts=0,
            device_fingerprint=device_fingerprint,
            session_id=session_id,
            ip_address=ip_address,
            started_at=started_at,
            submitted_at=None,
            status="JOINED"
        )
        db.add(attempt)
        db.commit()

        return {
            "session_id": session_id,
            "entry_fee_deducted": contest.entry_fee,
            "status": "SUCCESS"
        }

    @staticmethod
    def start_word_contest(db: Session, user: User, contest_id: int, session_id: str) -> dict:
        attempt = db.query(WordAttempt).filter(
            WordAttempt.session_id == session_id,
            WordAttempt.user_id == user.id
        ).with_for_update().first()

        if not attempt or attempt.contest_id != contest_id:
            raise ValueError("Invalid session or contest pairing.")
        if attempt.status != "JOINED":
            raise ValueError("Session already started or processed.")

        contest = db.query(WordContest).filter(WordContest.id == contest_id).first()
        if not contest:
            raise ValueError("Contest not found.")

        if contest.status != "ACTIVE":
            raise ValueError("Contest is not active.")

        # Fetch questions
        questions = db.query(WordQuestion).filter(WordQuestion.contest_id == contest_id).all()
        
        # Strip answers to prevent inspection
        stripped_questions = []
        for q in questions:
            try:
                p_data = json.loads(q.puzzle_data)
            except Exception:
                p_data = q.puzzle_data

            try:
                clues_data = json.loads(q.clues) if q.clues else None
            except Exception:
                clues_data = q.clues

            stripped_questions.append({
                "id": q.id,
                "game_type": q.game_type,
                "puzzle_data": p_data,
                "clues": clues_data,
                "points_reward": q.points_reward
            })

        attempt.status = "IN_PROGRESS"
        attempt.started_at = datetime.now(timezone.utc)
        db.commit()

        signature = WordAntiCheatService.generate_signature(session_id, user.id)

        return {
            "questions": stripped_questions,
            "duration_seconds": contest.duration_seconds,
            "started_at": attempt.started_at,
            "signature": signature
        }

    @staticmethod
    def submit_word_answer(db: Session, user: User, data) -> dict:
        attempt = db.query(WordAttempt).filter(
            WordAttempt.session_id == data.session_id,
            WordAttempt.user_id == user.id
        ).with_for_update().first()

        if not attempt:
            raise ValueError("Attempt session not found.")
        if attempt.status != "IN_PROGRESS":
            raise ValueError("Session is not in progress.")

        # Cryptographic signature validation
        if not WordAntiCheatService.verify_signature(data.session_id, user.id, data.signature):
            attempt.status = "DISQUALIFIED"
            db.commit()
            raise ValueError("Session integrity verification failed. Disqualified.")

        # Time drift validation
        actual_elapsed = (datetime.now(timezone.utc) - attempt.started_at).total_seconds()
        if abs(actual_elapsed - data.elapsed_time_seconds) > 5.0: # Allow max 5s network latency buffer
            attempt.status = "DISQUALIFIED"
            db.commit()
            raise ValueError("Unusual clock delay/drift detected. Disqualified.")

        # Fetch Question
        question = db.query(WordQuestion).filter(WordQuestion.id == data.question_id).first()
        if not question:
            raise ValueError("Question not found.")

        # Answer check
        is_correct = (question.correct_answer.strip().lower() == data.answer.strip().lower())
        
        points = 0
        penalty = 0

        if is_correct:
            points = question.points_reward
            # Fast completion bonus (completed under 15 seconds)
            if data.time_taken_seconds < 15.0:
                points += 50
        else:
            penalty += 10 # -10 points wrong attempt
            attempt.wrong_attempts += 1

        if data.used_hint:
            penalty += 20 # -20 points hint usage
            attempt.hints_used += 1

        net_points = points - penalty
        attempt.total_score = max(0, attempt.total_score + net_points)

        # Log WordAnswer detail
        db_answer = WordAnswer(
            attempt_id=attempt.id,
            question_id=data.question_id,
            is_correct=is_correct,
            answer_submitted=data.answer,
            points_awarded=net_points,
            hints_used=1 if data.used_hint else 0,
            attempts_count=1,
            time_taken_seconds=data.time_taken_seconds,
            telemetry_data=data.telemetry
        )
        db.add(db_answer)

        # Update attempt completion seconds to current total elapsed
        attempt.completion_time_seconds = actual_elapsed

        # Check if all questions of the contest are answered
        total_questions = db.query(WordQuestion).filter(WordQuestion.contest_id == attempt.contest_id).count()
        answered_questions = db.query(WordAnswer).filter(WordAnswer.attempt_id == attempt.id).count()

        if answered_questions >= total_questions:
            attempt.status = "SUBMITTED"
            attempt.submitted_at = datetime.now(timezone.utc)

        db.commit()

        # Update WebSocket/Realtime leaderboard cache
        try:
            word_leaderboard_manager.update_score(
                attempt.contest_id,
                user.id,
                user.name or user.phone,
                attempt.total_score,
                attempt.completion_time_seconds
            )
            
            # Broadcast updated scores to contest WebSockets
            leaderboard = word_leaderboard_manager.get_leaderboard(attempt.contest_id)
            loop = asyncio.get_event_loop()
            if loop.is_running():
                asyncio.run_coroutine_threadsafe(
                    word_ws_manager.broadcast_leaderboard(attempt.contest_id, leaderboard),
                    loop
                )
        except Exception as e:
            print(f"Word leaderboard WS broadcast error: {e}")

        return {
            "is_correct": is_correct,
            "net_points": net_points,
            "accumulated_score": attempt.total_score,
            "server_elapsed_seconds": actual_elapsed
        }


class WordRewardService:
    @staticmethod
    def complete_contest_rewards(db: Session, contest_id: int) -> dict:
        contest = db.query(WordContest).filter(WordContest.id == contest_id).with_for_update().first()
        if not contest:
            return {"error": "Contest not found"}
        if contest.status == "COMPLETED":
            return {"message": "Contest already completed."}

        contest.status = "COMPLETED"
        db.commit()

        # Transition any remaining IN_PROGRESS attempts to SUBMITTED
        in_progress_attempts = db.query(WordAttempt).filter(
            WordAttempt.contest_id == contest_id,
            WordAttempt.status == "IN_PROGRESS"
        ).all()
        for att in in_progress_attempts:
            att.status = "SUBMITTED"
            if att.completion_time_seconds is None:
                att.completion_time_seconds = float(contest.duration_seconds or 300)
            if att.submitted_at is None:
                att.submitted_at = datetime.now(timezone.utc)
        if in_progress_attempts:
            db.commit()

        # Gather all attempts and rank them by:
        # 1. Total Score (desc)
        # 2. Completion Time (asc)
        attempts = db.query(WordAttempt).filter(
            WordAttempt.contest_id == contest_id,
            WordAttempt.status == "SUBMITTED"
        ).order_by(
            WordAttempt.total_score.desc(),
            WordAttempt.completion_time_seconds.asc()
        ).all()

        payout_rules = []
        if contest.prize_rules:
            try:
                payout_rules = json.loads(contest.prize_rules)
            except Exception:
                pass

        payouts_made = 0
        for rank_idx, att in enumerate(attempts, start=1):
            # Save or update entry in Leaderboard
            leaderboard_entry = db.query(WordLeaderboard).filter(
                WordLeaderboard.contest_id == contest_id,
                WordLeaderboard.user_id == att.user_id
            ).first()

            payout_amount = 0.0
            if payout_rules:
                for rule in payout_rules:
                    if rule.get("min_rank") <= rank_idx <= rule.get("max_rank"):
                        payout_amount = float(rule.get("prize", 0.0))
                        break
            else:
                pcts = {1: 0.5, 2: 0.3, 3: 0.2}
                if rank_idx in pcts:
                    payout_amount = contest.prize_pool * pcts[rank_idx]

            if not leaderboard_entry:
                leaderboard_entry = WordLeaderboard(
                    contest_id=contest_id,
                    user_id=att.user_id,
                    score=att.total_score,
                    completion_time_seconds=att.completion_time_seconds or 0.0,
                    rank=rank_idx,
                    prize_amount=payout_amount,
                    is_paid=payout_amount > 0.0,
                    paid_at=datetime.now(timezone.utc) if payout_amount > 0.0 else None
                )
                db.add(leaderboard_entry)
            else:
                leaderboard_entry.rank = rank_idx
                leaderboard_entry.prize_amount = payout_amount
                leaderboard_entry.is_paid = payout_amount > 0.0
                leaderboard_entry.paid_at = datetime.now(timezone.utc) if payout_amount > 0.0 else None

            user = db.query(User).filter(User.id == att.user_id).first()
            if not user:
                continue

            if payout_amount > 0.0:
                WalletService.credit_prize(db, user, payout_amount, description=f"Prize Win: Word Contest ({contest.title})")
                payouts_made += 1
            else:
                send_push_to_user(
                    db,
                    user.id,
                    title="🏁 Word Contest Completed",
                    body=f"'{contest.title}' has finished! You placed Rank #{rank_idx}. Better luck next time!"
                )

        db.commit()
        return {"status": "SUCCESS", "payouts_made": payouts_made}


class FruitAntiCheatService:
    SECRET_KEY = b"FRUIT_SLICING_TOURNAMENT_ANTI_CHEAT_SECRET_KEY_9988"

    @classmethod
    def generate_signature(cls, session_id: str, contest_id: int, user_id: int) -> str:
        payload = f"{session_id}:{contest_id}:{user_id}".encode()
        return hmac.new(cls.SECRET_KEY, payload, hashlib.sha256).hexdigest()

    @classmethod
    def verify_signature(cls, session_id: str, contest_id: int, user_id: int, signature: str) -> bool:
        expected = cls.generate_signature(session_id, contest_id, user_id)
        return hmac.compare_digest(expected, signature)

    @classmethod
    def validate_telemetry_kinematics(
        cls,
        telemetry: List[dict],
        reported_score: int,
        reported_combo: int,
        reported_misses: int,
        reported_bombs: int,
        started_at: datetime
    ) -> bool:
        """
        Validates physics velocity sweeps, chronological swipes, score maths, and timing limitations.
        """
        # Rule 1: Overall timing check
        actual_elapsed = (datetime.now(timezone.utc) - started_at).total_seconds()
        if actual_elapsed > 68.0:  # 60s match duration + 8s network/grace buffer
            return False

        calculated_score = 0
        current_combo_streak = 0
        calculated_max_combo = 0
        calculated_bombs = 0
        last_swipe_timestamp = -1

        for swipe in telemetry:
            t_ms = swipe.get("timestamp_ms")
            path = swipe.get("path", [])
            sliced_items = swipe.get("sliced_items", [])
            is_bomb_hit = swipe.get("is_bomb_hit", False)

            # Rule 2: Chronological ordering
            if t_ms <= last_swipe_timestamp:
                return False
            
            # Rule 3: Swipe velocity physics (bot/clicker detection)
            if len(path) >= 2:
                # Calculate absolute pixels traveled in coordinates space
                dist = 0.0
                for idx in range(1, len(path)):
                    dx = path[idx]["x"] - path[idx-1]["x"]
                    dy = path[idx]["y"] - path[idx-1]["y"]
                    dist += (dx**2 + dy**2)**0.5
                
                # Assume a fixed delta timing of 16-100ms or use t parameter
                p1_t = path[0].get("t")
                p2_t = path[-1].get("t")
                duration_sec = (p2_t - p1_t) / 1000.0 if (p1_t is not None and p2_t is not None and p2_t > p1_t) else 0.1
                
                velocity = dist / max(0.005, duration_sec)
                # Humans slice between 100 and 15,000 pixels/sec. Anything outside is script/macro.
                if velocity > 25000.0:
                    return False

            # Rule 4: Reconstruct scoring
            if is_bomb_hit:
                calculated_bombs += 1
                calculated_score -= 100
                current_combo_streak = 0
            else:
                slice_count = len(sliced_items)
                if slice_count > 0:
                    calculated_score += (slice_count * 10)
                    
                    # Combos
                    if slice_count >= 5:
                        calculated_score += 50
                        current_combo_streak = max(current_combo_streak, 5)
                    elif slice_count >= 3:
                        calculated_score += 20
                        current_combo_streak = max(current_combo_streak, 3)
                else:
                    current_combo_streak = 0
            
            calculated_max_combo = max(calculated_max_combo, current_combo_streak)
            last_swipe_timestamp = t_ms

        # Deduct misses
        calculated_score -= (reported_misses * 5)
        calculated_score = max(0, calculated_score)

        # Rule 5: Compare results strictly
        if calculated_score != reported_score:
            return False
        if calculated_max_combo != reported_combo:
            return False
        if calculated_bombs != reported_bombs:
            return False

        return True


class FruitGameService:
    _maintenance_mode = False

    @classmethod
    def set_maintenance_mode(cls, enabled: bool):
        cls._maintenance_mode = enabled

    @classmethod
    def is_maintenance_mode(cls) -> bool:
        return cls._maintenance_mode

    @staticmethod
    def join_fruit_contest(db: Session, user: User, contest_id: int, device_fingerprint: str, ip_address: str) -> dict:
        if FruitGameService.is_maintenance_mode():
            raise ValueError("Fruit Puzzle is currently under maintenance. Please try again later.")
        contest = db.query(FruitContest).filter(FruitContest.id == contest_id).with_for_update().first()
        if not contest:
            raise ValueError("Contest not found.")
        if contest.status != "UPCOMING":
            raise ValueError("Registration closed. You can only join upcoming contests.")
        if contest.joined_slots >= contest.total_slots:
            raise ValueError("Contest is full.")

        existing_attempt = db.query(FruitMatch).filter(
            FruitMatch.contest_id == contest_id,
            FruitMatch.user_id == user.id
        ).first()
        if existing_attempt:
            raise ValueError("You have already joined this contest.")

        # Deduct wallet entry fee via existing central WalletService
        WalletService.deduct_entry_fee(db, user, contest.entry_fee, description=f"Entry Fee: Fruit Contest ({contest.title})")
        contest.joined_slots += 1

        session_id = str(uuid.uuid4())
        started_at = datetime.now(timezone.utc)

        match_record = FruitMatch(
            contest_id=contest_id,
            user_id=user.id,
            session_id=session_id,
            status="JOINED",
            device_fingerprint=device_fingerprint,
            ip_address=ip_address,
            started_at=started_at,
            signature=FruitAntiCheatService.generate_signature(session_id, contest_id, user.id)
        )
        db.add(match_record)
        db.commit()

        return {
            "session_id": session_id,
            "entry_fee_deducted": contest.entry_fee,
            "status": "SUCCESS"
        }

    @staticmethod
    def start_fruit_session(db: Session, user: User, contest_id: int, device_fingerprint: str, ip_address: str) -> dict:
        if FruitGameService.is_maintenance_mode():
            raise ValueError("Fruit Puzzle is currently under maintenance. Please try again later.")
        contest = db.query(FruitContest).filter(FruitContest.id == contest_id).first()
        if not contest:
            raise ValueError("Contest not found.")
        if contest.status != "ACTIVE":
            raise ValueError("Contest is not active.")

        match_record = db.query(FruitMatch).filter(
            FruitMatch.contest_id == contest_id,
            FruitMatch.user_id == user.id
        ).first()
        if not match_record:
            raise ValueError("Access denied. You must join this contest to play.")

        if match_record.status != "JOINED" and match_record.status != "IN_PROGRESS":
            raise ValueError("Session already completed or closed.")

        if match_record.status == "JOINED":
            match_record.status = "IN_PROGRESS"
            match_record.started_at = datetime.now(timezone.utc)
            match_record.device_fingerprint = device_fingerprint
            match_record.ip_address = ip_address
            db.commit()

        return {
            "session_id": match_record.session_id,
            "seed": contest.seed,
            "duration_seconds": contest.duration_seconds,
            "started_at": match_record.started_at,
            "signature": match_record.signature
        }

    @staticmethod
    def submit_fruit_score(db: Session, user: User, data) -> dict:
        match_record = db.query(FruitMatch).filter(
            FruitMatch.session_id == data.session_id,
            FruitMatch.user_id == user.id
        ).with_for_update().first()

        if not match_record:
            raise ValueError("Fruit match session not found.")
        if match_record.status != "IN_PROGRESS":
            raise ValueError("Score already submitted or session closed.")

        # Verify signature
        if not FruitAntiCheatService.verify_signature(data.session_id, data.contest_id, user.id, data.signature):
            match_record.status = "SUSPICIOUS"
            db.commit()
            raise ValueError("Invalid session signature.")

        contest = db.query(FruitContest).filter(FruitContest.id == data.contest_id).first()
        
        # Telemetry verification
        telemetry_dicts = []
        for swipe in data.telemetry:
            telemetry_dicts.append({
                "timestamp_ms": swipe.timestamp_ms,
                "path": [{"x": p.x, "y": p.y, "t": p.t} for p in swipe.path],
                "sliced_items": [{"id": item.id, "item_type": item.item_type, "slice_angle": item.slice_angle} for item in swipe.sliced_items],
                "is_bomb_hit": swipe.is_bomb_hit
            })

        is_legit = FruitAntiCheatService.validate_telemetry_kinematics(
            telemetry=telemetry_dicts,
            reported_score=data.score,
            reported_combo=data.max_combo,
            reported_misses=data.miss_count,
            reported_bombs=data.bomb_hit_count,
            started_at=match_record.started_at
        )

        if not is_legit:
            match_record.status = "SUSPICIOUS"
            db.commit()
            raise ValueError("Anti-Cheat validation failed.")

        # Save match score records
        score_record = FruitScore(
            match_id=match_record.id,
            user_id=user.id,
            contest_id=data.contest_id,
            score=data.score,
            max_combo=data.max_combo,
            miss_count=data.miss_count,
            bomb_hit_count=data.bomb_hit_count,
            is_verified=True
        )
        db.add(score_record)

        # Save telemetry events in the database
        for swipe in data.telemetry:
            if swipe.is_bomb_hit:
                points_delta = -100
                event_type = "BOMB_HIT"
            else:
                event_type = "SWIPE"
                slice_count = len(swipe.sliced_items)
                points_delta = slice_count * 10
                if slice_count >= 5:
                    points_delta += 50
                elif slice_count >= 3:
                    points_delta += 20

            db_event = FruitEvent(
                match_id=match_record.id,
                event_type=event_type,
                timestamp_ms=swipe.timestamp_ms,
                coordinates=json.dumps([{"x": p.x, "y": p.y, "t": p.t} for p in swipe.path]),
                sliced_items=json.dumps([{"id": item.id, "item_type": item.item_type, "slice_angle": item.slice_angle} for item in swipe.sliced_items]),
                points_delta=points_delta
            )
            db.add(db_event)

        match_record.status = "SUBMITTED"
        match_record.submitted_at = datetime.now(timezone.utc)
        db.commit()

        # Update in-memory WebSocket leaderboard Standings
        try:
            name = user.name or user.phone
            fruit_leaderboard_manager.update_score(
                contest_id=data.contest_id,
                user_id=user.id,
                name=name,
                score=data.score,
                max_combo=data.max_combo,
                miss_count=data.miss_count,
                submitted_at=match_record.submitted_at
            )
            leaderboard = fruit_leaderboard_manager.get_leaderboard(data.contest_id)
            
            # Broadcast updates asynchronously
            loop = asyncio.get_event_loop()
            if loop.is_running():
                asyncio.run_coroutine_threadsafe(
                    fruit_ws_manager.broadcast_leaderboard(data.contest_id, leaderboard),
                    loop
                )
        except Exception as e:
            print(f"Fruit live leaderboard WS broadcast failure: {e}")

        return {"status": "SUCCESS", "score": data.score}


class FruitRewardService:
    @staticmethod
    def complete_contest_rewards(db: Session, contest_id: int) -> dict:
        contest = db.query(FruitContest).filter(FruitContest.id == contest_id).with_for_update().first()
        if not contest:
            return {"error": "Contest not found"}
        if contest.status == "COMPLETED":
            return {"message": "Contest already completed."}

        contest.status = "COMPLETED"
        db.commit()

        # Ranks evaluation based on score desc, combo desc, miss asc, early submit asc
        scores = (
            db.query(FruitScore)
            .filter(FruitScore.contest_id == contest_id)
            .filter(FruitScore.is_verified == True)
            .order_by(
                FruitScore.score.desc(),
                FruitScore.max_combo.desc(),
                FruitScore.miss_count.asc(),
                FruitScore.created_at.asc()
            )
            .all()
        )

        payout_rules = []
        if contest.prize_rules:
            try:
                payout_rules = json.loads(contest.prize_rules)
            except Exception:
                pass

        payouts_made = 0
        for rank_idx, s in enumerate(scores, start=1):
            payout_amount = 0.0
            if payout_rules:
                for rule in payout_rules:
                    if rule.get("min_rank") <= rank_idx <= rule.get("max_rank"):
                        payout_amount = float(rule.get("prize", 0.0))
                        break
            else:
                pcts = {1: 0.5, 2: 0.3, 3: 0.2}
                if rank_idx in pcts:
                    payout_amount = contest.prize_pool * pcts[rank_idx]

            leaderboard_entry = FruitLeaderboard(
                contest_id=contest_id,
                user_id=s.user_id,
                score=s.score,
                max_combo=s.max_combo,
                miss_count=s.miss_count,
                rank=rank_idx,
                prize_amount=payout_amount,
                is_paid=payout_amount > 0.0,
                paid_at=datetime.now(timezone.utc) if payout_amount > 0.0 else None
            )
            db.add(leaderboard_entry)

            user = db.query(User).filter(User.id == s.user_id).first()
            if not user:
                continue

            if payout_amount > 0.0:
                WalletService.credit_prize(db, user, payout_amount, description=f"Prize Win: Fruit Contest ({contest.title})")
                payouts_made += 1
            else:
                send_push_to_user(
                    db,
                    user.id,
                    title="🏁 Fruit Tournament Completed",
                    body=f"'{contest.title}' has finished! You placed Rank #{rank_idx}. Better luck next time!"
                )

        db.commit()
        return {"status": "SUCCESS", "payouts_made": payouts_made}


class ArrowAntiCheatService:
    SECRET_KEY = b"ARROW_GAME_ANTI_CHEAT_SECRET_KEY_7744"

    @classmethod
    def generate_signature(cls, session_id: str, contest_id: int, user_id: int) -> str:
        payload = f"{session_id}:{contest_id}:{user_id}".encode()
        return hmac.new(cls.SECRET_KEY, payload, hashlib.sha256).hexdigest()

    @classmethod
    def verify_signature(cls, session_id: str, contest_id: int, user_id: int, signature: str) -> bool:
        expected = cls.generate_signature(session_id, contest_id, user_id)
        return hmac.compare_digest(expected, signature)

    @classmethod
    def validate_telemetry_kinematics(
        cls,
        telemetry: List[dict],
        reported_time: float,
        reported_moves: int,
        started_at: datetime
    ) -> bool:
        actual_elapsed = (datetime.now(timezone.utc) - started_at).total_seconds()
        # Max grace buffer is 10 seconds
        if actual_elapsed > reported_time + 10.0:
            return False

        # Verify that reported moves equals telemetry taps
        if len(telemetry) != reported_moves:
            return False

        # Taps speed validation (no auto clickers or macros: spacing must be at least 50ms)
        last_dt = -1
        for tap in telemetry:
            dt = tap.get("dt", 0)
            if last_dt >= 0:
                diff = dt - last_dt
                if diff < 50:  # Suspicious speed
                    return False
            last_dt = dt

        return True


class ArrowGameService:
    _maintenance_mode = False

    @classmethod
    def set_maintenance_mode(cls, enabled: bool):
        cls._maintenance_mode = enabled

    @classmethod
    def is_maintenance_mode(cls) -> bool:
        return cls._maintenance_mode

    @staticmethod
    def generate_solvable_layout_reverse(grid_size: int, arrow_count: int, seed: int) -> list:
        local_random = random.Random(seed)
        
        # Max density: 85% of board
        max_arrows = int(grid_size * grid_size * 0.85)
        target_count = min(arrow_count, max_arrows)
        
        placed_arrows = {} # key: (r, c), value: direction
        directions = ["UP", "DOWN", "LEFT", "RIGHT"]
        all_cells = [(r, c) for r in range(grid_size) for c in range(grid_size)]
        
        for attempt in range(20000):
            if len(placed_arrows) >= target_count:
                break
            empty_cells = [cell for cell in all_cells if cell not in placed_arrows]
            if not empty_cells:
                break
            r, c = local_random.choice(empty_cells)
            shuffled_dirs = list(directions)
            local_random.shuffle(shuffled_dirs)
            
            for d in shuffled_dirs:
                is_path_free = True
                if d == "UP":
                    for r_check in range(0, r):
                        if (r_check, c) in placed_arrows:
                            is_path_free = False
                            break
                elif d == "DOWN":
                    for r_check in range(r + 1, grid_size):
                        if (r_check, c) in placed_arrows:
                            is_path_free = False
                            break
                elif d == "LEFT":
                    for c_check in range(0, c):
                        if (r, c_check) in placed_arrows:
                            is_path_free = False
                            break
                elif d == "RIGHT":
                    for c_check in range(c + 1, grid_size):
                        if (r, c_check) in placed_arrows:
                            is_path_free = False
                            break
                if is_path_free:
                    placed_arrows[(r, c)] = d
                    break
                    
        blocks = []
        for idx, ((r, c), d) in enumerate(placed_arrows.items()):
            blocks.append({
                "id": idx,
                "row": r,
                "col": c,
                "dir": d
            })
        return blocks

    @staticmethod
    def generate_solvable_layout(grid_size: int) -> list:
        # Fallback/compatibility method for older code
        seed = int(time.time() * 1000) % 1000000
        return ArrowGameService.generate_solvable_layout_reverse(grid_size, int(grid_size * grid_size * 0.7), seed)

    @staticmethod
    def validate_arrow_telemetry_simulation(layout: list, grid_size: int, telemetry: list) -> bool:
        active_by_id = {b["id"]: b for b in layout}
        active_coords = {(b["row"], b["col"]): b["id"] for b in layout}
        
        for tap in telemetry:
            block_id = tap.get("block_id")
            reported_success = tap.get("success", False)
            
            if block_id not in active_by_id:
                if reported_success:
                    return False
                continue
                
            b = active_by_id[block_id]
            r, c, d = b["row"], b["col"], b["dir"]
            
            blocked = False
            if d == "UP":
                for r_check in range(0, r):
                    if (r_check, c) in active_coords:
                        blocked = True
                        break
            elif d == "DOWN":
                for r_check in range(r + 1, grid_size):
                    if (r_check, c) in active_coords:
                        blocked = True
                        break
            elif d == "LEFT":
                for c_check in range(0, c):
                    if (r, c_check) in active_coords:
                        blocked = True
                        break
            elif d == "RIGHT":
                for c_check in range(c + 1, grid_size):
                    if (r, c_check) in active_coords:
                        blocked = True
                        break
            
            actual_success = not blocked
            if reported_success != actual_success:
                return False
                
            if actual_success:
                active_by_id.pop(block_id)
                active_coords.pop((r, c))
                
        if len(active_coords) > 0:
            return False
            
        return True

    @staticmethod
    def join_arrow_contest(db: Session, user: User, contest_id: int, device_fingerprint: str, ip_address: str) -> dict:
        if ArrowGameService.is_maintenance_mode():
            raise ValueError("Go Arrows is currently under maintenance. Please try again later.")
        contest = db.query(ArrowContest).filter(ArrowContest.id == contest_id).with_for_update().first()
        if not contest:
            raise ValueError("Contest not found.")
        if contest.status != "UPCOMING":
            raise ValueError("Registration closed. You can only join upcoming contests.")
        if contest.joined_slots >= contest.total_slots:
            raise ValueError("Contest is full.")

        existing_attempt = db.query(ArrowAttempt).filter(
            ArrowAttempt.contest_id == contest_id,
            ArrowAttempt.user_id == user.id
        ).first()
        if existing_attempt:
            raise ValueError("You have already joined this contest.")

        # Wallet balances validation and deduction
        WalletService.deduct_entry_fee(db, user, contest.entry_fee, description=f"Entry Fee: Arrow Contest ({contest.title})")
        contest.joined_slots += 1

        session_id = str(uuid.uuid4())
        started_at = datetime.now(timezone.utc)

        attempt = ArrowAttempt(
            contest_id=contest_id,
            user_id=user.id,
            score=0,
            completion_seconds=0.0,
            moves=0,
            taps_sequence="[]",
            is_verified=False,
            device_fingerprint=device_fingerprint,
            ip_address=ip_address,
            session_id=session_id,
            started_at=started_at,
            submitted_at=started_at,
            status="JOINED"
        )
        db.add(attempt)
        db.commit()

        return {
            "session_id": session_id,
            "entry_fee_deducted": contest.entry_fee,
            "status": "SUCCESS"
        }

    @staticmethod
    def start_arrow_session(db: Session, user: User, contest_id: int, device_fingerprint: str, ip_address: str) -> dict:
        if ArrowGameService.is_maintenance_mode():
            raise ValueError("Go Arrows is currently under maintenance. Please try again later.")

        contest = db.query(ArrowContest).filter(ArrowContest.id == contest_id).first()
        if not contest:
            raise ValueError("Contest not found.")
        if contest.status != "ACTIVE":
            raise ValueError("Contest is not active.")

        attempt = db.query(ArrowAttempt).filter(
            ArrowAttempt.contest_id == contest_id,
            ArrowAttempt.user_id == user.id
        ).first()
        if not attempt:
            raise ValueError("Access denied. You must join this contest to play.")

        if attempt.status != "JOINED" and attempt.status != "IN_PROGRESS":
            raise ValueError("Session already completed or closed.")

        db_seed = db.query(ArrowPuzzleSeed).filter(
            ArrowPuzzleSeed.contest_id == contest_id,
            ArrowPuzzleSeed.user_id == user.id
        ).first()
        if not db_seed:
            seed_val = random.randint(100000, 999999)
            db_seed = ArrowPuzzleSeed(
                contest_id=contest_id,
                user_id=user.id,
                seed=seed_val,
                difficulty=contest.difficulty or "MEDIUM"
            )
            db.add(db_seed)
            db.flush()

        layout_data = ArrowGameService.generate_solvable_layout_reverse(
            contest.grid_size, contest.arrow_count, db_seed.seed
        )

        if attempt.status == "JOINED":
            attempt.status = "IN_PROGRESS"
            attempt.started_at = datetime.now(timezone.utc)
            attempt.device_fingerprint = device_fingerprint
            attempt.ip_address = ip_address
            db.commit()

        signature = ArrowAntiCheatService.generate_signature(attempt.session_id, contest_id, user.id)

        return {
            "session_id": attempt.session_id,
            "layout": layout_data,
            "started_at": attempt.started_at,
            "grid_size": contest.grid_size,
            "duration_seconds": contest.duration_seconds,
            "signature": signature
        }

    @staticmethod
    def calculate_score(seconds: float, moves: int, duration_seconds: int, arrow_count: int, wrong_taps: int) -> int:
        time_remaining = max(0.0, float(duration_seconds) - seconds)
        score = (time_remaining * 10.0) + (arrow_count * 5.0) - (wrong_taps * 20.0)
        return max(0, int(score))

    @classmethod
    def submit_arrow_score(cls, db: Session, user: User, data) -> dict:
        attempt = db.query(ArrowAttempt).filter(
            ArrowAttempt.session_id == data.session_id,
            ArrowAttempt.user_id == user.id
        ).with_for_update().first()

        if not attempt:
            raise ValueError("Arrows match session not found.")
        if attempt.status != "IN_PROGRESS":
            raise ValueError("Score already submitted or session closed.")

        if not ArrowAntiCheatService.verify_signature(data.session_id, data.contest_id, user.id, data.signature):
            attempt.status = "SUSPICIOUS"
            db.commit()
            raise ValueError("Invalid session signature.")

        contest = db.query(ArrowContest).filter(ArrowContest.id == data.contest_id).first()
        if not contest:
            raise ValueError("Contest not found.")

        db_seed = db.query(ArrowPuzzleSeed).filter(
            ArrowPuzzleSeed.contest_id == data.contest_id,
            ArrowPuzzleSeed.user_id == user.id
        ).first()
        if not db_seed:
            raise ValueError("Puzzle seed not found for validation.")

        layout = ArrowGameService.generate_solvable_layout_reverse(
            contest.grid_size, contest.arrow_count, db_seed.seed
        )

        telemetry_dicts = [{"block_id": t.block_id, "dt": t.dt, "success": t.success} for t in data.telemetry]

        is_legit_kinematics = ArrowAntiCheatService.validate_telemetry_kinematics(
            telemetry=telemetry_dicts,
            reported_time=data.completion_seconds,
            reported_moves=data.moves,
            started_at=attempt.started_at
        )
        if not is_legit_kinematics:
            attempt.status = "SUSPICIOUS"
            db.commit()
            raise ValueError("Anti-Cheat validation failed (Kinematics).")

        is_legit_simulation = ArrowGameService.validate_arrow_telemetry_simulation(
            layout=layout,
            grid_size=contest.grid_size,
            telemetry=telemetry_dicts
        )
        if not is_legit_simulation:
            attempt.status = "SUSPICIOUS"
            db.commit()
            raise ValueError("Anti-Cheat validation failed (Simulation mismatch).")

        wrong_taps = sum(1 for t in telemetry_dicts if not t.get("success", False))
        score = cls.calculate_score(
            seconds=data.completion_seconds,
            moves=data.moves,
            duration_seconds=contest.duration_seconds,
            arrow_count=contest.arrow_count,
            wrong_taps=wrong_taps
        )

        attempt.score = score
        attempt.completion_seconds = data.completion_seconds
        attempt.moves = data.moves
        attempt.taps_sequence = json.dumps(telemetry_dicts)
        attempt.is_verified = True
        attempt.status = "VERIFIED"
        attempt.submitted_at = datetime.now(timezone.utc)
        db.commit()

        leaderboard_entry = db.query(ArrowLeaderboard).filter(
            ArrowLeaderboard.contest_id == data.contest_id,
            ArrowLeaderboard.user_id == user.id
        ).first()

        if not leaderboard_entry:
            leaderboard_entry = ArrowLeaderboard(
                contest_id=data.contest_id,
                user_id=user.id,
                score=score,
                completion_seconds=data.completion_seconds,
                rank=9999
            )
            db.add(leaderboard_entry)
        else:
            if score > leaderboard_entry.score:
                leaderboard_entry.score = score
                leaderboard_entry.completion_seconds = data.completion_seconds
        db.commit()

        try:
            arrow_leaderboard_manager.update_score(
                contest_id=data.contest_id,
                user_id=user.id,
                name=user.name or user.phone,
                score=score,
                duration=data.completion_seconds
            )
            leaderboard = arrow_leaderboard_manager.get_leaderboard(data.contest_id)
            loop = asyncio.get_event_loop()
            if loop.is_running():
                asyncio.run_coroutine_threadsafe(
                    arrow_ws_manager.broadcast_leaderboard(data.contest_id, leaderboard),
                    loop
                )
        except Exception as e:
            print(f"Arrow live leaderboard WS broadcast failure: {e}")

        return {"status": "SUCCESS", "score": score}


class ArrowRewardService:
    @staticmethod
    def complete_contest_rewards(db: Session, contest_id: int) -> dict:
        contest = db.query(ArrowContest).filter(ArrowContest.id == contest_id).with_for_update().first()
        if not contest:
            return {"error": "Contest not found"}
        if contest.status == "COMPLETED":
            return {"message": "Contest already completed."}

        contest.status = "COMPLETED"
        db.commit()

        # Rank placements: score (desc), completion_seconds (asc), moves (asc)
        attempts = db.query(ArrowAttempt).filter(
            ArrowAttempt.contest_id == contest_id,
            ArrowAttempt.status == "VERIFIED"
        ).order_by(
            ArrowAttempt.score.desc(),
            ArrowAttempt.completion_seconds.asc(),
            ArrowAttempt.moves.asc()
        ).all()

        payout_rules = []
        if contest.prize_rules:
            try:
                payout_rules = json.loads(contest.prize_rules)
            except Exception:
                pass

        payouts_made = 0
        for rank_idx, att in enumerate(attempts, start=1):
            db_leaderboard = db.query(ArrowLeaderboard).filter(
                ArrowLeaderboard.contest_id == contest_id,
                ArrowLeaderboard.user_id == att.user_id
            ).first()
            if db_leaderboard:
                db_leaderboard.rank = rank_idx

            user = db.query(User).filter(User.id == att.user_id).first()
            if not user:
                continue

            payout_amount = 0.0
            if payout_rules:
                for rule in payout_rules:
                    if rule.get("min_rank") <= rank_idx <= rule.get("max_rank"):
                        payout_amount = float(rule.get("prize", 0.0))
                        break
            else:
                pcts = {1: 0.5, 2: 0.3, 3: 0.2}
                if rank_idx in pcts:
                    payout_amount = contest.prize_pool * pcts[rank_idx]

            if payout_amount > 0:
                WalletService.credit_prize(db, user, payout_amount, description=f"Prize Win: Arrow Contest ({contest.title})")
                if db_leaderboard:
                    db_leaderboard.prize_amount = payout_amount
                    db_leaderboard.is_paid = True
                    db_leaderboard.paid_at = datetime.now(timezone.utc)
                payouts_made += 1
            else:
                send_push_to_user(
                    db,
                    user.id,
                    title="🏁 Arrow Contest Completed",
                    body=f"'{contest.title}' has finished! You placed Rank #{rank_idx}. Better luck next time!"
                )

        db.commit()
        return {"status": "SUCCESS", "payouts_made": payouts_made}


class LotteryService:
    @staticmethod
    def buy_ticket(db: Session, user_id: int, draw_id: int) -> LotteryTicket:
        
        # 1. Fetch draw and lock it
        draw = db.query(LotteryDraw).filter(LotteryDraw.id == draw_id).with_for_update().first()
        if not draw:
            raise ValueError("Lottery draw not found.")
        if draw.status != "OPEN":
            raise ValueError("This draw is closed or cancelled.")
        if draw.joined_tickets >= draw.max_tickets:
            raise ValueError("Ticket limits reached for this draw.")
        
        # 2. Get user and lock
        user = db.query(User).filter(User.id == user_id).with_for_update().first()
        if not user:
            raise ValueError("User not found.")
        if user.is_banned:
            raise ValueError("Banned user cannot purchase tickets.")
        
        # 3. Deduct ticket price from user wallets (Deposit first, then Winnings)
        ticket_price = draw.ticket_price
        deposit_deduct = min(user.deposit_balance, ticket_price)
        remaining = ticket_price - deposit_deduct
        winnings_deduct = min(user.winning_balance, remaining)
        
        if deposit_deduct + winnings_deduct < ticket_price:
            raise ValueError("Insufficient wallet balance to buy ticket.")
        
        user.deposit_balance -= deposit_deduct
        user.winning_balance -= winnings_deduct
        
        # 4. Generate unique ticket number
        ticket_num = ""
        for _ in range(10):
            potential_num = str(secrets.randbelow(900000) + 100000)
            existing = db.query(LotteryTicket).filter(
                LotteryTicket.draw_id == draw_id,
                LotteryTicket.ticket_number == potential_num
            ).first()
            if not existing:
                ticket_num = potential_num
                break
        if not ticket_num:
            ticket_num = str(uuid.uuid4().hex[:6].upper())
            
        # 5. Create ticket record
        ticket = LotteryTicket(
            user_id=user_id,
            draw_id=draw_id,
            ticket_number=ticket_num,
            is_winner=False,
            reward_amount=0.0
        )
        db.add(ticket)
        
        # 6. Create wallet transaction record
        tx = WalletTransaction(
            user_id=user_id,
            type="ENTRY_FEE",
            amount=ticket_price,
            status="SUCCESS",
            description=f"Lottery Ticket: {draw.title} (Ticket: {ticket_num})"
        )
        db.add(tx)
        
        # 7. Update draw tickets count
        draw.joined_tickets += 1
        
        db.commit()
        db.refresh(ticket)
        return ticket

    @staticmethod
    def execute_draw(db: Session, draw_id: int, override_winning_number: Optional[str] = None) -> dict:
        
        draw = db.query(LotteryDraw).filter(LotteryDraw.id == draw_id).with_for_update().first()
        if not draw:
            return {"error": "Draw not found"}
        if draw.status != "OPEN":
            return {"error": f"Draw status is {draw.status}, only OPEN draws can be drawn."}
        
        tickets = db.query(LotteryTicket).filter(LotteryTicket.draw_id == draw_id).all()
        if not tickets:
            draw.status = "COMPLETED"
            draw.winning_number = "NO TICKETS SOLD"
            db.commit()
            return {"message": "Draw completed with 0 participants.", "winners": []}
            
        # Determine the target winning ticket number to force, if any
        target_winning_number = override_winning_number or draw.forced_winning_number
        
        winner_ticket = None
        if target_winning_number:
            # Check if anyone actually bought the forced number
            for t in tickets:
                if t.ticket_number == target_winning_number:
                    winner_ticket = t
                    break
        else:
            # No forced winner, decide based on win_percentage
            win_pct = draw.win_percentage if draw.win_percentage is not None else 100.0
            roll = random.uniform(0.0, 100.0)
            if roll <= win_pct:
                winner_ticket = secrets.choice(tickets)
        
        draw.status = "COMPLETED"
        
        if winner_ticket:
            draw.winning_number = winner_ticket.ticket_number
            winner_ticket.is_winner = True
            winner_ticket.reward_amount = draw.prize_pool
            
            winner_user = db.query(User).filter(User.id == winner_ticket.user_id).first()
            if winner_user:
                winner_user.winning_balance += draw.prize_pool
                
                tx = WalletTransaction(
                    user_id=winner_user.id,
                    type="PRIZE_WIN",
                    amount=draw.prize_pool,
                    status="SUCCESS",
                    description=f"Lottery Winner: {draw.title} (Ticket: {winner_ticket.ticket_number})"
                )
                db.add(tx)
                
                send_push_to_user(
                    db,
                    winner_user.id,
                    title="🎟️ YOU WON THE LUCKY DRAW!",
                    body=f"Congratulations! Your ticket #{winner_ticket.ticket_number} won the grand prize of ₹{draw.prize_pool:.2f} in '{draw.title}'!"
                )
                
            for t in tickets:
                if t.id == winner_ticket.id:
                    continue
                send_push_to_user(
                    db,
                    t.user_id,
                    title="🏁 Draw Results Announced",
                    body=f"Draw '{draw.title}' results are out. Winning Ticket: #{winner_ticket.ticket_number}. Better luck next time!"
                )
            
            db.commit()
            return {
                "message": "Draw executed successfully.",
                "winning_ticket": winner_ticket.ticket_number,
                "winner_user_id": winner_ticket.user_id,
                "prize_awarded": draw.prize_pool
            }
        else:
            # No winner (either forced ticket wasn't bought, or win_percentage roll failed)
            winning_num = target_winning_number or "NO WINNER (DRAW)"
            draw.winning_number = winning_num
            
            for t in tickets:
                send_push_to_user(
                    db,
                    t.user_id,
                    title="🏁 Draw Results Announced",
                    body=f"Draw '{draw.title}' results are out. Winning Ticket: #{winning_num}. Better luck next time!"
                )
            
            db.commit()
            return {
                "message": "Draw completed with no winner.",
                "winning_ticket": winning_num,
                "winner_user_id": None,
                "prize_awarded": 0.0
            }

    @staticmethod
    def cancel_draw(db: Session, draw_id: int) -> dict:
        
        draw = db.query(LotteryDraw).filter(LotteryDraw.id == draw_id).with_for_update().first()
        if not draw:
            return {"error": "Draw not found"}
        if draw.status != "OPEN":
            return {"error": f"Draw status is {draw.status}, only OPEN draws can be cancelled."}
            
        tickets = db.query(LotteryTicket).filter(LotteryTicket.draw_id == draw_id).all()
        refund_count = 0
        for ticket in tickets:
            user = db.query(User).filter(User.id == ticket.user_id).with_for_update().first()
            if user:
                user.deposit_balance += draw.ticket_price
                tx = WalletTransaction(
                    user_id=user.id,
                    type="DEPOSIT",
                    amount=draw.ticket_price,
                    status="SUCCESS",
                    description=f"Refund: Cancelled Lottery Draw '{draw.title}'"
                )
                db.add(tx)
                refund_count += 1
                
                send_push_to_user(
                    db,
                    user.id,
                    title="🎟️ Draw Cancelled & Refunded",
                    body=f"Lottery Draw '{draw.title}' was cancelled. Ticket price of ₹{draw.ticket_price:.2f} has been refunded to your Deposit wallet."
                )
                
        draw.status = "CANCELLED"
        db.commit()
        return {"message": f"Draw cancelled. Refunded {refund_count} tickets successfully."}

    @staticmethod
    def get_simulated_winners(db: Session) -> list:
        # Get real winners
        real_winners = (
            db.query(LotteryTicket)
            .join(User)
            .join(LotteryDraw)
            .filter(LotteryTicket.is_winner == True)
            .order_by(LotteryTicket.purchase_time.desc())
            .limit(50)
            .all()
        )
        
        winners_list = []
        for t in real_winners:
            phone = t.user.phone or ""
            masked_phone = phone
            if len(phone) >= 10:
                masked_phone = phone[:3] + "******" + phone[-2:]
            elif len(phone) >= 4:
                masked_phone = phone[:2] + "****" + phone[-2:]
            
            name = t.user.name or "User"
            if len(name) > 3 and "@" not in name:
                parts = name.split()
                if len(parts) > 1:
                    name = parts[0] + " " + parts[1][0] + "."
            
            winners_list.append({
                "name": name,
                "phone": masked_phone,
                "ticket_number": t.ticket_number,
                "draw_title": t.draw.title,
                "reward_amount": t.reward_amount,
                "win_time": t.draw.draw_time
            })
            
        from datetime import datetime, timezone, timedelta
        ist_tz = timezone(timedelta(hours=5, minutes=30))
        now_ist = datetime.now(ist_tz)
        
        date_seed_str = now_ist.strftime("%Y-%m-%d")
        import hashlib
        seed_int = int(hashlib.sha256(date_seed_str.encode('utf-8')).hexdigest(), 16) % 10**8
        
        import random
        rng = random.Random(seed_int)
        
        num_simulated = rng.randint(120, 180)
        
        first_names = [
            "Ramesh", "Suresh", "Rahul", "Amit", "Pooja", "Priya", "Ankit", "Sunita", "Deepak", "Vijay", 
            "Rajesh", "Karan", "Nisha", "Neha", "Vikram", "Ajay", "Pradeep", "Sanjay", "Anil", "Sunil", 
            "Ravi", "Manoj", "Jitendra", "Dinesh", "Arjun", "Sachin", "Vijay", "Rohit", "Mohit", "Ashok", 
            "Prem", "Harish", "Gopal", "Krishna", "Shiva", "Vishal", "Vivek", "Alok", "Abhishek", "Aditya", 
            "Rohan", "Siddharth", "Varun", "Neeraj", "Pankaj", "Sandip", "Kiran", "Geeta", "Jyoti", "Kavita", 
            "Lata", "Meena", "Rekha", "Seema", "Shashi", "Usha", "Arti", "Divya", "Komal", "Mamta", 
            "Preeti", "Ritu", "Sarita", "Suman", "Anita", "Babita", "Chitra", "Deepa", "Kriti", "Madhu", 
            "Payal", "Radha", "Rani", "Sapna", "Tanya", "Akash", "Bikram", "Chandan", "Gaurav", "Hemant", 
            "Ishwar", "Kamal", "Lalit", "Manish", "Nitin", "Pranav", "Rajiv", "Sandeep", "Tarun", "Umesh", 
            "Vinay", "Yash", "Kusum", "Maya", "Poonam", "Rupa", "Sneha", "Uma", "Vandana", "Yogita"
        ]
        last_names = [
            "Kumar", "Sharma", "Singh", "Verma", "Patel", "Yadav", "Gupta", "Joshi", "Mishra", "Pandey", 
            "Choudhary", "Reddy", "Nair", "Iyer", "Mehta", "Shah", "Sen", "Roy", "Dutta", "Das", 
            "Saxena", "Trivedi", "Pathak", "Rao", "Pillai", "Bose", "Chatterjee", "Banerjee", "Mukherjee", "Gill", 
            "Sodhi", "Kapoor", "Khanna", "Malhotra", "Kapil", "Dubey", "Dwivedi", "Tripathi", "Shukla", "Agrawal", 
            "Bansal", "Goel", "Garg", "Tayal", "Singhal", "Mittal", "Prasad", "Nath", "Sarkar", "Rana"
        ]
        
        draw_titles = [d.title for d in db.query(LotteryDraw).order_by(LotteryDraw.draw_time.desc()).limit(10).all()]
        if not draw_titles:
            draw_titles = [
                "🎟️ Daily Bumper ₹50K (₹50)",
                "💥 Daily Bumper ₹100K (₹100)",
                "💎 Daily Bumper ₹200K (₹200)",
                "🔥 Daily Bumper ₹500K (₹500)",
                "👑 Daily Bumper ₹1M (₹1000)"
            ]
            
        start_of_today = now_ist.replace(hour=0, minute=0, second=0, microsecond=0)
        
        for i in range(num_simulated):
            fn = rng.choice(first_names)
            ln = rng.choice(last_names)
            name = f"{fn} {ln[0]}."
            
            prefix = rng.choice(["98", "99", "97", "96", "88", "87", "70", "79", "81", "95"])
            suffix = f"{rng.randint(1000, 9999)}"
            masked_phone = f"+91 {prefix}*** **{suffix}"
            
            ticket_num = f"{rng.randint(100000, 999999)}"
            draw_title = rng.choice(draw_titles)
            
            prize_pool = 1000.0
            if "50K" in draw_title:
                prize_pool = 50000.0
            elif "100K" in draw_title:
                prize_pool = 100000.0
            elif "200K" in draw_title:
                prize_pool = 200000.0
            elif "500K" in draw_title:
                prize_pool = 500000.0
            elif "1M" in draw_title:
                prize_pool = 1000000.0
                
            tier_roll = rng.random()
            if tier_roll < 0.02:
                reward = rng.choice([prize_pool * 0.1, prize_pool * 0.05])
            elif tier_roll < 0.15:
                reward = rng.choice([1000.0, 2000.0, 5000.0])
            else:
                reward = rng.choice([100.0, 200.0, 500.0])
                
            offset_seconds = rng.randint(-86400, 43200)
            win_time = start_of_today + timedelta(seconds=offset_seconds)
            
            if win_time > now_ist:
                win_time = now_ist - timedelta(minutes=rng.randint(5, 60))
                
            win_time_utc = win_time.astimezone(timezone.utc).replace(tzinfo=None)
            
            winners_list.append({
                "name": name,
                "phone": masked_phone,
                "ticket_number": ticket_num,
                "draw_title": draw_title,
                "reward_amount": float(reward),
                "win_time": win_time_utc
            })
            
        winners_list.sort(key=lambda x: x["win_time"], reverse=True)
        return winners_list




class MinesGameService:
    @staticmethod
    def calculate_multiplier(mines_count: int, revealed_count: int, house_edge: float = 0.03) -> float:
        if revealed_count <= 0:
            return 1.0
        total_cells = 25
        gems_count = total_cells - mines_count
        if revealed_count > gems_count:
            return 0.0
        
        # Fair multiplier = nCr(25, N) / nCr(25 - M, N)
        import math
        ways_total = math.comb(total_cells, revealed_count)
        ways_gems = math.comb(gems_count, revealed_count)
        if ways_gems == 0:
            return 0.0
        
        fair_multiplier = ways_total / ways_gems
        # Apply RTP / house edge
        multiplier = fair_multiplier * (1.0 - house_edge)
        return round(multiplier, 2)

    @staticmethod
    def start_game(db: Session, user_id: int, bet_amount: float, mines_count: int) -> MinesGame:
        from app.models import User, MinesGame, MinesSetting, WalletTransaction
        import random
        import json
        
        # 1. Fetch settings
        settings = db.query(MinesSetting).first()
        if not settings:
            # Fallback settings
            settings = MinesSetting(house_edge=0.03, min_bet=10.0, max_bet=5000.0, maintenance_mode=False)
            db.add(settings)
            db.commit()
            db.refresh(settings)
            
        if settings.maintenance_mode:
            raise ValueError("Mines game is currently under maintenance. Please try again later.")
            
        if bet_amount < settings.min_bet or bet_amount > settings.max_bet:
            raise ValueError(f"Bet amount must be between ₹{settings.min_bet:.2f} and ₹{settings.max_bet:.2f}")

        # 2. Check user status
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            raise ValueError("User not found.")
        if user.is_banned:
            raise ValueError("User account is banned.")
        if user.kyc_status == "REJECTED":
            raise ValueError("KYC has been rejected. Game access restricted.")

        # 3. Check for active game
        active_game = db.query(MinesGame).filter(
            MinesGame.user_id == user_id,
            MinesGame.status == "IN_PROGRESS"
        ).first()
        if active_game:
            raise ValueError("You have an active game in progress. Please settle it first.")

        # 4. Lock user balance and deduct bet_amount
        locked_user = db.query(User).filter(User.id == user_id).with_for_update().first()
        
        # Deduct wallet: Max 20% bonus balance, rest from Deposit -> Winnings
        WalletService.deduct_entry_fee(db, locked_user, bet_amount, bonus_cap_pct=0.20, description="Entry Fee: Mines Game")

        # 5. Generate mine positions [0-24]
        mines_positions = random.sample(range(25), mines_count)

        # 6. Create game record
        game = MinesGame(
            user_id=user_id,
            bet_amount=bet_amount,
            mines_count=mines_count,
            mines_positions=json.dumps(mines_positions),
            revealed_positions="[]",
            current_multiplier=1.0,
            current_win=0.0,
            status="IN_PROGRESS"
        )
        db.add(game)
        db.commit()
        db.refresh(game)
        
        # Set dynamic balance for response mapping
        game.updated_balance = locked_user.winning_balance + locked_user.deposit_balance + locked_user.bonus_balance
        return game

    @staticmethod
    def reveal_cell(db: Session, user_id: int, game_id: int, position: int) -> MinesGame:
        from app.models import User, MinesGame, MinesSetting, WalletTransaction
        import json

        # 1. Fetch game session
        game = db.query(MinesGame).filter(
            MinesGame.id == game_id,
            MinesGame.user_id == user_id
        ).with_for_update().first()

        if not game:
            raise ValueError("Mines game record not found.")

        if game.status != "IN_PROGRESS":
            raise ValueError(f"Game is already completed (Status: {game.status}).")

        # 2. Parse arrays
        mines = json.loads(game.mines_positions)
        revealed = json.loads(game.revealed_positions)

        if position in revealed:
            raise ValueError("Cell already revealed.")

        # Apply Mines RTP / win chance override
        from app.models import MinesRTP
        rtp = db.query(MinesRTP).filter(
            MinesRTP.min_amount <= game.bet_amount,
            MinesRTP.max_amount >= game.bet_amount,
            MinesRTP.enabled == True
        ).first()

        if rtp:
            import random
            should_win = random.random() < rtp.win_rate
            if should_win and (position in mines):
                unrevealed_safe = [c for c in range(25) if (c not in mines) and (c not in revealed) and (c != position)]
                if unrevealed_safe:
                    swap_cell = random.choice(unrevealed_safe)
                    mines.remove(position)
                    mines.add(swap_cell) if isinstance(mines, set) else mines.append(swap_cell)
                    game.mines_positions = json.dumps(mines)
            elif (not should_win) and (position not in mines):
                unrevealed_mines = [m for m in mines if m not in revealed]
                if unrevealed_mines:
                    swap_mine = random.choice(unrevealed_mines)
                    mines.remove(swap_mine)
                    mines.add(position) if isinstance(mines, set) else mines.append(position)
                    game.mines_positions = json.dumps(mines)

        # 3. Check if position is a mine
        if position in mines:
            # Player hit a mine: lose game
            game.status = "LOST"
            game.current_multiplier = 0.0
            game.current_win = 0.0
            db.commit()
            
            user = db.query(User).filter(User.id == user_id).first()
            game.updated_balance = user.winning_balance + user.deposit_balance + user.bonus_balance
            return game

        # 4. Success: Gem revealed
        revealed.append(position)
        game.revealed_positions = json.dumps(revealed)

        # Get settings for house edge
        settings = db.query(MinesSetting).first()
        house_edge = settings.house_edge if settings else 0.03

        # Update multiplier & current win
        new_multiplier = MinesGameService.calculate_multiplier(game.mines_count, len(revealed), house_edge)
        game.current_multiplier = new_multiplier
        game.current_win = game.bet_amount * new_multiplier

        # Check if all gems are revealed (auto cashout)
        total_cells = 25
        gems_count = total_cells - game.mines_count
        if len(revealed) == gems_count:
            game.status = "WON"
            
            # Lock and update wallet
            locked_user = db.query(User).filter(User.id == user_id).with_for_update().first()
            WalletService.credit_prize(db, locked_user, game.current_win, description="Prize Win: Mines Game (Clean Sweep)", send_push=False)
            db.commit()

            game.updated_balance = locked_user.winning_balance + locked_user.deposit_balance + locked_user.bonus_balance
            
            # Send notification
            try:
                send_push_to_user(
                    db,
                    user_id,
                    title="🎉 Mines Sweep Winner!",
                    body=f"Fantastic! You swept the board in Mines and won ₹{game.current_win:.2f}!"
                )
            except Exception:
                pass
        else:
            db.commit()
            user = db.query(User).filter(User.id == user_id).first()
            game.updated_balance = user.winning_balance + user.deposit_balance + user.bonus_balance

        return game

    @staticmethod
    def cash_out(db: Session, user_id: int, game_id: int) -> MinesGame:
        from app.models import User, MinesGame, WalletTransaction
        import json

        # 1. Fetch game session
        game = db.query(MinesGame).filter(
            MinesGame.id == game_id,
            MinesGame.user_id == user_id
        ).with_for_update().first()

        if not game:
            raise ValueError("Mines game record not found.")

        if game.status != "IN_PROGRESS":
            raise ValueError(f"Game is already completed (Status: {game.status}).")

        revealed = json.loads(game.revealed_positions)
        if len(revealed) == 0:
            raise ValueError("You must reveal at least one gem before cashing out.")

        # 2. Process Cash Out
        game.status = "WON"
        win_amount = game.current_win

        # Lock user wallet and credit winnings
        locked_user = db.query(User).filter(User.id == user_id).with_for_update().first()
        WalletService.credit_prize(db, locked_user, win_amount, description="Prize Win: Mines Cashout", send_push=False)
        db.commit()

        game.updated_balance = locked_user.winning_balance + locked_user.deposit_balance + locked_user.bonus_balance

        # Send notification for big wins
        if game.current_multiplier >= 3.0:
            try:
                send_push_to_user(
                    db,
                    user_id,
                    title="🔥 Mines Big Winner!",
                    body=f"Nice! You cashed out with a {game.current_multiplier}x multiplier and won ₹{win_amount:.2f}!"
                )
            except Exception:
                pass

        return game


class FruitSlicingService:
    SECRET_KEY = b"FRUIT_SLICING_GAME_SECRET_KEY_9988_CASHOUT"

    @classmethod
    def generate_game_signature(cls, game_id: int, user_id: int, bet_amount: float) -> str:
        payload = f"{game_id}:{user_id}:{bet_amount}".encode()
        return hmac.new(cls.SECRET_KEY, payload, hashlib.sha256).hexdigest()

    @classmethod
    def verify_game_signature(cls, game_id: int, user_id: int, bet_amount: float, signature: str) -> bool:
        expected = cls.generate_game_signature(game_id, user_id, bet_amount)
        return hmac.compare_digest(expected, signature)

    @staticmethod
    def get_settings(db: Session) -> FruitSetting:
        settings = db.query(FruitSetting).first()
        if not settings:
            # If not seeded yet, seed default setting
            from app.core.seeds import seed_fruit_settings
            seed_fruit_settings(db)
            settings = db.query(FruitSetting).first()
        return settings

    @staticmethod
    def update_settings(
        db: Session,
        min_bet: float,
        max_bet: float,
        maintenance_mode: bool,
        winning_percentage: float,
        multipliers_json: str
    ) -> FruitSetting:
        settings = FruitSlicingService.get_settings(db)
        settings.min_bet = min_bet
        settings.max_bet = max_bet
        settings.maintenance_mode = maintenance_mode
        settings.winning_percentage = winning_percentage
        settings.multipliers_json = multipliers_json
        db.commit()
        db.refresh(settings)
        return settings

    @staticmethod
    def start_game(db: Session, user: User, bet_amount: float) -> dict:
        settings = FruitSlicingService.get_settings(db)
        if settings.maintenance_mode:
            raise ValueError("Fruit Slicing game is currently under maintenance. Please try again later.")
        
        if bet_amount < settings.min_bet or bet_amount > settings.max_bet:
            raise ValueError(f"Bet amount must be between ₹{settings.min_bet:.2f} and ₹{settings.max_bet:.2f}.")

        # Check KYC
        if user.is_banned:
            raise ValueError("User account is banned.")
        if user.kyc_status == "REJECTED":
            raise ValueError("KYC has been rejected. Game access restricted.")

        # Lock user wallet inside transactional context to prevent race conditions
        locked_user = db.query(User).filter(User.id == user.id).with_for_update().first()

        # Deduct wallet: Max 20% bonus balance, rest from Deposit -> Winnings
        WalletService.deduct_entry_fee(db, locked_user, bet_amount, bonus_cap_pct=0.20, description="Entry Fee: Fruit Slicing Game")

        # Create game session
        game = FruitGame(
            user_id=user.id,
            bet_amount=bet_amount,
            status="IN_PROGRESS",
            current_multiplier=1.0,
            win_amount=0.0
        )
        db.add(game)
        db.flush()  # Populate game.id

        db.commit()

        # Generate cryptographic signature for verification on cashout/bomb
        signature = FruitSlicingService.generate_game_signature(game.id, user.id, bet_amount)
        updated_balance = locked_user.winning_balance + locked_user.deposit_balance + locked_user.bonus_balance

        return {
            "game": game,
            "signature": signature,
            "updated_balance": updated_balance
        }

    @staticmethod
    def cashout_game(db: Session, user: User, game_id: int, final_multiplier: float, signature: str) -> FruitGame:
        # Find active session
        game = db.query(FruitGame).filter(FruitGame.id == game_id, FruitGame.user_id == user.id).with_for_update().first()
        if not game:
            raise ValueError("Fruit game session not found.")
        if game.status != "IN_PROGRESS":
            raise ValueError(f"Game session already completed (Status: {game.status}).")

        # Verify signature to prevent tampering
        if not FruitSlicingService.verify_game_signature(game.id, user.id, game.bet_amount, signature):
            raise ValueError("Invalid game signature.")

        if final_multiplier < 0.1:
            final_multiplier = 0.1  # enforce floor on backend

        # Update session
        game.status = "WON"
        game.current_multiplier = final_multiplier
        win_amount = round(game.bet_amount * final_multiplier, 2)
        game.win_amount = win_amount

        # Credit winnings
        locked_user = db.query(User).filter(User.id == user.id).with_for_update().first()
        WalletService.credit_prize(db, locked_user, win_amount, description="Prize Win: Fruit Slicing Game", send_push=False)
        db.commit()

        game.updated_balance = locked_user.winning_balance + locked_user.deposit_balance + locked_user.bonus_balance
        return game

    @staticmethod
    def bomb_hit_game(db: Session, user: User, game_id: int, signature: str) -> FruitGame:
        # Find active session
        game = db.query(FruitGame).filter(FruitGame.id == game_id, FruitGame.user_id == user.id).with_for_update().first()
        if not game:
            raise ValueError("Fruit game session not found.")
        if game.status != "IN_PROGRESS":
            raise ValueError(f"Game session already completed (Status: {game.status}).")

        # Verify signature
        if not FruitSlicingService.verify_game_signature(game.id, user.id, game.bet_amount, signature):
            raise ValueError("Invalid game signature.")

        # Update session to lost
        game.status = "LOST"
        game.current_multiplier = 0.0
        game.win_amount = 0.0

        db.commit()

        locked_user = db.query(User).filter(User.id == user.id).first()
        game.updated_balance = locked_user.winning_balance + locked_user.deposit_balance + locked_user.bonus_balance
        return game


class BlackjackGameService:
    SUITS = ["♠", "♥", "♦", "♣"]
    RANKS = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]

    @classmethod
    def get_random_card(cls):
        rank = random.choice(cls.RANKS)
        suit = random.choice(cls.SUITS)
        if rank in ["J", "Q", "K"]:
            val = 10
        elif rank == "A":
            val = 11
        else:
            val = int(rank)
        return {"suit": suit, "rank": rank, "value": val}

    @classmethod
    def calculate_hand_value(cls, hand):
        val = sum(c["value"] for c in hand)
        aces = sum(1 for c in hand if c["rank"] == "A")
        while val > 21 and aces > 0:
            val -= 10
            aces -= 1
        return val

    @classmethod
    def deal_card_to_player(cls, hand, target_outcome):
        current_val = cls.calculate_hand_value(hand)
        for _ in range(50):
            card = cls.get_random_card()
            temp_hand = hand + [card]
            new_val = cls.calculate_hand_value(temp_hand)
            
            if target_outcome == "WIN":
                if new_val > 21:
                    continue
                return card
            elif target_outcome == "LOSS":
                if current_val >= 12:
                    if new_val > 21:
                        return card  # Player busts
                    continue
                else:
                    # Player under 12, try to keep them awkward (< 17)
                    if new_val >= 17:
                        continue
                    return card
        return cls.get_random_card()

    @classmethod
    def deal_card_to_dealer(cls, dealer_hand, player_max_score, target_outcome):
        for _ in range(50):
            card = cls.get_random_card()
            temp_hand = dealer_hand + [card]
            new_val = cls.calculate_hand_value(temp_hand)
            
            if target_outcome == "WIN":
                if new_val > 21:
                    return card  # Dealer busts
                if new_val >= 17 and new_val > player_max_score:
                    continue  # Avoid dealer standing with score > player
                return card
            elif target_outcome == "LOSS":
                if new_val > 21:
                    continue  # Avoid busting the dealer
                if new_val >= 17 and new_val < player_max_score:
                    continue  # Avoid dealer standing on a losing score
                return card
        return cls.get_random_card()

    @classmethod
    def mask_dealer_card_if_needed(cls, game: BlackjackGame) -> BlackjackGame:
        if game.status == "COMPLETED":
            return game
        try:
            cards = json.loads(game.dealer_hand)
            if len(cards) > 0:
                masked = [cards[0]]
                game_copy = copy.copy(game)
                game_copy.dealer_hand = json.dumps(masked)
                return game_copy
        except Exception:
            pass
        return game

    @classmethod
    def play_dealer_turn(cls, db: Session, game: BlackjackGame, user: User):
        dealer_hand = json.loads(game.dealer_hand)
        player_hand_1 = json.loads(game.player_hand_1)
        p1_val = cls.calculate_hand_value(player_hand_1)

        if game.hand_1_status == "BUST":
            game.status = "COMPLETED"
            game.win_amount = 0.0
            return

        while True:
            d_val = cls.calculate_hand_value(dealer_hand)
            if d_val > 21:
                break
            if game.target_outcome == "LOSS":
                if d_val >= 21:
                    break
                if d_val >= 17 and d_val >= p1_val:
                    break
            else:
                if d_val >= 17 and d_val <= p1_val:
                    break
            card = cls.deal_card_to_dealer(dealer_hand, p1_val, game.target_outcome)
            dealer_hand.append(card)

        game.dealer_hand = json.dumps(dealer_hand)
        d_final_val = cls.calculate_hand_value(dealer_hand)

        win_amount = 0.0
        payout_desc = ""
        if d_final_val > 21:
            game.hand_1_status = "WON"
            win_amount = game.bet_amount * 2
            payout_desc = "Dealer Bust"
        else:
            if p1_val > d_final_val:
                game.hand_1_status = "WON"
                win_amount = game.bet_amount * 2
                payout_desc = "Player Higher Score"
            elif p1_val < d_final_val:
                game.hand_1_status = "LOST"
                win_amount = 0.0
            else:
                game.hand_1_status = "PUSH"
                win_amount = game.bet_amount
                payout_desc = "Push"

        game.status = "COMPLETED"
        game.win_amount = win_amount

        if win_amount > 0:
            locked_user = db.query(User).filter(User.id == user.id).with_for_update().first()
            WalletService.credit_prize(db, locked_user, win_amount, description=f"Prize Win: Blackjack ({payout_desc})", send_push=False)

    @classmethod
    def resolve_split_payouts(cls, db: Session, game: BlackjackGame, user: User):
        player_hand_1 = json.loads(game.player_hand_1)
        player_hand_2 = json.loads(game.player_hand_2)
        dealer_hand = json.loads(game.dealer_hand)

        p1_val = cls.calculate_hand_value(player_hand_1)
        p2_val = cls.calculate_hand_value(player_hand_2)

        if game.hand_1_status == "BUST" and game.hand_2_status == "BUST":
            game.status = "COMPLETED"
            game.win_amount = 0.0
            return

        valid_scores = []
        if game.hand_1_status != "BUST":
            valid_scores.append(p1_val)
        if game.hand_2_status != "BUST":
            valid_scores.append(p2_val)
        max_player_score = max(valid_scores) if valid_scores else 0

        while True:
            d_val = cls.calculate_hand_value(dealer_hand)
            if d_val > 21:
                break
            if game.target_outcome == "LOSS":
                if d_val >= 21:
                    break
                if d_val >= 17 and d_val >= max_player_score:
                    break
            else:
                if d_val >= 17 and d_val <= max_player_score:
                    break
            card = cls.deal_card_to_dealer(dealer_hand, max_player_score, game.target_outcome)
            dealer_hand.append(card)

        game.dealer_hand = json.dumps(dealer_hand)
        d_final_val = cls.calculate_hand_value(dealer_hand)

        win_1 = 0.0
        if game.hand_1_status != "BUST":
            if d_final_val > 21:
                game.hand_1_status = "WON"
                win_1 = game.bet_amount * 2
            elif p1_val > d_final_val:
                game.hand_1_status = "WON"
                win_1 = game.bet_amount * 2
            elif p1_val < d_final_val:
                game.hand_1_status = "LOST"
                win_1 = 0.0
            else:
                game.hand_1_status = "PUSH"
                win_1 = game.bet_amount

        win_2 = 0.0
        if game.hand_2_status != "BUST":
            if d_final_val > 21:
                game.hand_2_status = "WON"
                win_2 = game.split_bet_amount * 2
            elif p2_val > d_final_val:
                game.hand_2_status = "WON"
                win_2 = game.split_bet_amount * 2
            elif p2_val < d_final_val:
                game.hand_2_status = "LOST"
                win_2 = 0.0
            else:
                game.hand_2_status = "PUSH"
                win_2 = game.split_bet_amount

        game.status = "COMPLETED"
        total_win = win_1 + win_2
        game.win_amount = total_win

        if total_win > 0:
            locked_user = db.query(User).filter(User.id == user.id).with_for_update().first()
            WalletService.credit_prize(
                db,
                locked_user,
                total_win,
                description=f"Prize Win: Blackjack Split (H1: {game.hand_1_status}, H2: {game.hand_2_status})",
                send_push=False
            )

    @classmethod
    def start_game(cls, db: Session, user_id: int, bet_amount: float) -> BlackjackGame:
        from app.models import BlackjackSetting, BlackjackGame, User
        settings = db.query(BlackjackSetting).first()
        if not settings:
            settings = BlackjackSetting()
            db.add(settings)
            db.commit()
            db.refresh(settings)

        if settings.maintenance_mode:
            raise ValueError("Blackjack is currently under maintenance.")

        if bet_amount < settings.min_bet or bet_amount > settings.max_bet:
            raise ValueError(f"Bet amount must be between ₹{settings.min_bet} and ₹{settings.max_bet}")

        active = db.query(BlackjackGame).filter(BlackjackGame.user_id == user_id, BlackjackGame.status == "IN_PROGRESS").first()
        if active:
            raise ValueError("You already have an active game in progress.")

        locked_user = db.query(User).filter(User.id == user_id).with_for_update().first()
        WalletService.deduct_entry_fee(db, locked_user, bet_amount, bonus_cap_pct=0.20, description="Entry Fee: Blackjack Game")

        roll = random.uniform(0.0, 100.0)
        target_outcome = "WIN" if roll < settings.winning_percentage else "LOSS"

        player_hand = []
        dealer_hand = []

        # Player hand is always completely random, except we exclude a natural blackjack (21)
        for _ in range(10):
            p_hand = [cls.get_random_card(), cls.get_random_card()]
            if cls.calculate_hand_value(p_hand) == 21:
                continue
            player_hand = p_hand
            break
        if not player_hand:
            player_hand = [cls.get_random_card(), cls.get_random_card()]

        # Dealer hand
        if target_outcome == "LOSS":
            player_val = cls.calculate_hand_value(player_hand)
            for _ in range(50):
                d_hand = [cls.get_random_card(), cls.get_random_card()]
                d_val = cls.calculate_hand_value(d_hand)
                if d_val == 21:
                    continue
                if player_val >= 12:
                    if player_val == 20:
                        if d_val == 20:
                            dealer_hand = d_hand
                            break
                    else:
                        if player_val < d_val <= 20:
                            dealer_hand = d_hand
                            break
                else:
                    if 15 <= d_val <= 20:
                        dealer_hand = d_hand
                        break
            if not dealer_hand:
                for _ in range(20):
                    d_hand = [cls.get_random_card(), cls.get_random_card()]
                    d_val = cls.calculate_hand_value(d_hand)
                    if d_val != 21 and d_val >= player_val:
                        dealer_hand = d_hand
                        break
                if not dealer_hand:
                    dealer_hand = [cls.get_random_card(), cls.get_random_card()]
        else:
            player_val = cls.calculate_hand_value(player_hand)
            for _ in range(50):
                d_hand = [cls.get_random_card(), cls.get_random_card()]
                d_val = cls.calculate_hand_value(d_hand)
                if d_val == 21:
                    continue
                if d_val >= 17 and d_val > player_val:
                    continue
                dealer_hand = d_hand
                break
            if not dealer_hand:
                dealer_hand = [cls.get_random_card(), cls.get_random_card()]

        player_val = cls.calculate_hand_value(player_hand)
        dealer_val = cls.calculate_hand_value(dealer_hand)

        hand_1_status = "IN_PROGRESS"
        status_str = "IN_PROGRESS"
        win_amount = 0.0

        if player_val == 21:
            if dealer_val == 21:
                hand_1_status = "PUSH"
                status_str = "COMPLETED"
                win_amount = bet_amount
            else:
                hand_1_status = "BLACKJACK"
                status_str = "COMPLETED"
                win_amount = bet_amount * 2.5
        elif dealer_val == 21:
            hand_1_status = "LOST"
            status_str = "COMPLETED"
            win_amount = 0.0

        game = BlackjackGame(
            user_id=user_id,
            bet_amount=bet_amount,
            is_split=False,
            split_bet_amount=0.0,
            player_hand_1=json.dumps(player_hand),
            player_hand_2=json.dumps([]),
            dealer_hand=json.dumps(dealer_hand),
            current_hand_index=0,
            hand_1_status=hand_1_status,
            hand_2_status="IN_PROGRESS",
            status=status_str,
            win_amount=win_amount,
            target_outcome=target_outcome
        )
        db.add(game)
        db.commit()
        db.refresh(game)

        if status_str == "COMPLETED" and win_amount > 0:
            WalletService.credit_prize(db, locked_user, win_amount, description=f"Prize Win: Blackjack ({hand_1_status})", send_push=False)
            db.commit()

        res_game = cls.mask_dealer_card_if_needed(game)
        res_game.updated_balance = locked_user.winning_balance + locked_user.deposit_balance + locked_user.bonus_balance
        return res_game

    @classmethod
    def hit(cls, db: Session, user_id: int, game_id: int) -> BlackjackGame:
        from app.models import BlackjackGame, User
        game = db.query(BlackjackGame).filter(BlackjackGame.id == game_id, BlackjackGame.user_id == user_id).with_for_update().first()
        if not game:
            raise ValueError("Game session not found.")
        if game.status != "IN_PROGRESS":
            raise ValueError("Game already completed.")

        if game.current_hand_index == 0:
            hand = json.loads(game.player_hand_1)
        else:
            hand = json.loads(game.player_hand_2)

        card = cls.deal_card_to_player(hand, game.target_outcome)
        hand.append(card)
        val = cls.calculate_hand_value(hand)

        if game.current_hand_index == 0:
            game.player_hand_1 = json.dumps(hand)
            if val > 21:
                game.hand_1_status = "BUST"
                if not game.is_split:
                    game.status = "COMPLETED"
                    game.win_amount = 0.0
                else:
                    game.current_hand_index = 1
        else:
            game.player_hand_2 = json.dumps(hand)
            if val > 21:
                game.hand_2_status = "BUST"
                game.status = "COMPLETED"
                cls.resolve_split_payouts(db, game, game.user)

        db.commit()
        db.refresh(game)

        locked_user = db.query(User).filter(User.id == user_id).first()
        res_game = cls.mask_dealer_card_if_needed(game)
        res_game.updated_balance = locked_user.winning_balance + locked_user.deposit_balance + locked_user.bonus_balance
        return res_game

    @classmethod
    def stand(cls, db: Session, user_id: int, game_id: int) -> BlackjackGame:
        from app.models import BlackjackGame, User
        game = db.query(BlackjackGame).filter(BlackjackGame.id == game_id, BlackjackGame.user_id == user_id).with_for_update().first()
        if not game:
            raise ValueError("Game session not found.")
        if game.status != "IN_PROGRESS":
            raise ValueError("Game already completed.")

        if game.current_hand_index == 0:
            game.hand_1_status = "STAND"
            if game.is_split:
                game.current_hand_index = 1
            else:
                cls.play_dealer_turn(db, game, game.user)
        else:
            game.hand_2_status = "STAND"
            cls.resolve_split_payouts(db, game, game.user)

        db.commit()
        db.refresh(game)

        locked_user = db.query(User).filter(User.id == user_id).first()
        res_game = cls.mask_dealer_card_if_needed(game)
        res_game.updated_balance = locked_user.winning_balance + locked_user.deposit_balance + locked_user.bonus_balance
        return res_game

    @classmethod
    def double(cls, db: Session, user_id: int, game_id: int) -> BlackjackGame:
        from app.models import BlackjackGame, User
        game = db.query(BlackjackGame).filter(BlackjackGame.id == game_id, BlackjackGame.user_id == user_id).with_for_update().first()
        if not game:
            raise ValueError("Game session not found.")
        if game.status != "IN_PROGRESS":
            raise ValueError("Game already completed.")

        bet_to_deduct = game.bet_amount
        locked_user = db.query(User).filter(User.id == user_id).with_for_update().first()
        WalletService.deduct_entry_fee(db, locked_user, bet_to_deduct, bonus_cap_pct=0.20, description="Entry Fee: Blackjack Double Down")

        if game.current_hand_index == 0:
            game.bet_amount *= 2
            hand = json.loads(game.player_hand_1)
        else:
            game.split_bet_amount = game.bet_amount * 2
            hand = json.loads(game.player_hand_2)

        card = cls.deal_card_to_player(hand, game.target_outcome)
        hand.append(card)
        val = cls.calculate_hand_value(hand)

        if game.current_hand_index == 0:
            game.player_hand_1 = json.dumps(hand)
            if val > 21:
                game.hand_1_status = "BUST"
                if not game.is_split:
                    game.status = "COMPLETED"
                    game.win_amount = 0.0
                else:
                    game.current_hand_index = 1
            else:
                game.hand_1_status = "STAND"
                if game.is_split:
                    game.current_hand_index = 1
                else:
                    cls.play_dealer_turn(db, game, locked_user)
        else:
            game.player_hand_2 = json.dumps(hand)
            if val > 21:
                game.hand_2_status = "BUST"
            else:
                game.hand_2_status = "STAND"
            game.status = "COMPLETED"
            cls.resolve_split_payouts(db, game, locked_user)

        db.commit()
        db.refresh(game)

        res_game = cls.mask_dealer_card_if_needed(game)
        res_game.updated_balance = locked_user.winning_balance + locked_user.deposit_balance + locked_user.bonus_balance
        return res_game

    @classmethod
    def split(cls, db: Session, user_id: int, game_id: int) -> BlackjackGame:
        from app.models import BlackjackGame, User
        game = db.query(BlackjackGame).filter(BlackjackGame.id == game_id, BlackjackGame.user_id == user_id).with_for_update().first()
        if not game:
            raise ValueError("Game session not found.")
        if game.status != "IN_PROGRESS":
            raise ValueError("Game already completed.")
        if game.is_split:
            raise ValueError("Hand is already split.")

        player_hand = json.loads(game.player_hand_1)
        if len(player_hand) != 2:
            raise ValueError("Can only split on first two cards.")

        c1 = player_hand[0]
        c2 = player_hand[1]
        if c1["value"] != c2["value"] and c1["rank"] != c2["rank"]:
            raise ValueError("Cards must be of equal value or rank to split.")

        bet_to_deduct = game.bet_amount
        locked_user = db.query(User).filter(User.id == user_id).with_for_update().first()
        WalletService.deduct_entry_fee(db, locked_user, bet_to_deduct, bonus_cap_pct=0.20, description="Entry Fee: Blackjack Split")

        hand1 = [c1]
        hand2 = [c2]

        hand1.append(cls.deal_card_to_player(hand1, game.target_outcome))
        hand2.append(cls.deal_card_to_player(hand2, game.target_outcome))

        game.is_split = True
        game.split_bet_amount = game.bet_amount
        game.player_hand_1 = json.dumps(hand1)
        game.player_hand_2 = json.dumps(hand2)
        game.current_hand_index = 0

        db.commit()
        db.refresh(game)

        res_game = cls.mask_dealer_card_if_needed(game)
        res_game.updated_balance = locked_user.winning_balance + locked_user.deposit_balance + locked_user.bonus_balance
        return res_game









