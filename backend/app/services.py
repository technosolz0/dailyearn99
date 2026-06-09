from app.models import ArrowLeaderboard
from app.models import ArrowGame
from app.models import ArrowAttempt
from app.models import ArrowContest
from app.models import ArrowPuzzleSeed
from app.models import FruitLeaderboard
from app.models import FruitScore
from app.models import FruitContest
from app.models import FruitMatch
from app.models import ImagePuzzleLeaderboard
from app.models import ImagePuzzleContest
from app.models import ImagePuzzleAttempt
from app.models import ImagePuzzleGame
from sqlalchemy import func
from sqlalchemy.orm import Session
from datetime import datetime, timezone
import threading
from typing import List, Dict, Tuple
from app.models import User, Contest, ContestParticipant, WalletTransaction, Referral, Spin, WordContest, WordQuestion, WordAttempt, WordAnswer, WordLeaderboard

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
    def deduct_entry_fee(db: Session, user: User, entry_fee: float) -> WalletTransaction:
        """
        Deduction Rules:
        - Max 10% of entry fee can be paid using Bonus Wallet.
        - Rest is paid by Deposit Wallet.
        - If Deposit Wallet is insufficient, remainder is paid by Winnings Wallet.
        """
        bonus_limit = entry_fee * 0.10
        bonus_to_deduct = min(user.bonus_balance, bonus_limit)
        remaining_fee = entry_fee - bonus_to_deduct
        
        deposit_to_deduct = min(user.deposit_balance, remaining_fee)
        winnings_to_deduct = remaining_fee - deposit_to_deduct
        
        if winnings_to_deduct > user.winning_balance:
            raise ValueError("Insufficient balance to join contest.")
            
        # Perform deductions
        user.bonus_balance -= bonus_to_deduct
        user.deposit_balance -= deposit_to_deduct
        user.winning_balance -= winnings_to_deduct
        
        # Create transaction record
        transaction = WalletTransaction(
            user_id=user.id,
            type="ENTRY_FEE",
            amount=entry_fee,
            status="SUCCESS"
        )
        db.add(transaction)
        db.commit()
        
        # Trigger referral bonus check
        ReferralService.check_and_trigger_referral(db, user)
        
        return transaction

    @staticmethod
    def credit_prize(db: Session, user: User, amount: float) -> WalletTransaction:
        user.winning_balance += amount
        transaction = WalletTransaction(
            user_id=user.id,
            type="PRIZE_WIN",
            amount=amount,
            status="SUCCESS"
        )
        db.add(transaction)
        
        # Send push notification
        from app.core.notifications import send_push_to_user
        send_push_to_user(
            db,
            user.id,
            title="🏆 Contest Prize Credited!",
            body=f"Congratulations! A prize of ₹{amount:.2f} has been credited to your Winnings wallet."
        )
        
        return transaction

    @staticmethod
    def process_deposit(db: Session, user: User, amount: float) -> WalletTransaction:
        user.deposit_balance += amount
        transaction = WalletTransaction(
            user_id=user.id,
            type="DEPOSIT",
            amount=amount,
            status="SUCCESS"
        )
        db.add(transaction)
        db.commit()
        
        # Send push notification
        from app.core.notifications import send_push_to_user
        send_push_to_user(
            db,
            user.id,
            title="💰 Deposit Successful!",
            body=f"₹{amount:.2f} has been successfully added to your Deposit wallet."
        )
        
        return transaction

    @staticmethod
    def process_withdrawal(db: Session, user: User, amount: float) -> WalletTransaction:
        if user.winning_balance < amount:
            raise ValueError("Insufficient winning balance to withdraw.")
        
        user.winning_balance -= amount
        transaction = WalletTransaction(
            user_id=user.id,
            type="WITHDRAWAL",
            amount=amount,
            status="PENDING"  # Needs admin approval
        )
        db.add(transaction)
        db.commit()
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
            status="SUCCESS"
        )
        tx_referred = WalletTransaction(
            user_id=referred_user.id,
            type="REFERRAL_BONUS",
            amount=20.0,
            status="SUCCESS"
        )
        db.add(tx_referrer)
        db.add(tx_referred)
        db.commit()

        # Send push notifications
        from app.core.notifications import send_push_to_user
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
        from app.models import Spin as SpinModel, SpinAuditLog as AuditLogModel
        daily_bet_sum = (
            db.query(func.sum(SpinModel.bet_amount))
            .filter(SpinModel.user_id == user_id, SpinModel.created_at >= today_start)
            .scalar()
        ) or 0.0
        if daily_bet_sum + bet_amount > 5000.0:
            raise ValueError("Daily gaming limit reached (₹5000). Keep gaming responsible!")

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
        bonus_limit = bet_amount * 0.20
        bonus_to_deduct = min(locked_user.bonus_balance, bonus_limit)
        remaining_fee = bet_amount - bonus_to_deduct

        deposit_to_deduct = min(locked_user.deposit_balance, remaining_fee)
        winnings_to_deduct = remaining_fee - deposit_to_deduct

        if winnings_to_deduct > locked_user.winning_balance:
            raise ValueError("Insufficient wallet balance for this bet.")

        # Deduct wallet
        locked_user.bonus_balance -= bonus_to_deduct
        locked_user.deposit_balance -= deposit_to_deduct
        locked_user.winning_balance -= winnings_to_deduct

        # Record spin charge transaction
        tx_deduct = WalletTransaction(
            user_id=user_id,
            type="ENTRY_FEE",
            amount=bet_amount,
            status="SUCCESS"
        )
        db.add(tx_deduct)

        # 3. Dynamic weighted random result selection
        from app.models import RTPSettings
        import json
        
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

        import random
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
            locked_user.winning_balance += win_amount
            tx_win = WalletTransaction(
                user_id=user_id,
                type="PRIZE_WIN",
                amount=win_amount,
                status="SUCCESS"
            )
            db.add(tx_win)

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
            from app.core.notifications import send_push_to_user
            send_push_to_user(
                db,
                user_id,
                title="🔥 JACKPOT SPIN WINNER!",
                body=f"Whoa! You spun the wheel and hit a massive {multiplier}x! ₹{win_amount:.2f} credited instantly."
            )

        return spin


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
        import json
        from app.models import Contest, ContestParticipant, User
        from app.services import WalletService
        from app.core.notifications import send_push_to_user

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
                WalletService.credit_prize(db, user, payout_amount)
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


import hmac
import hashlib
import json
import random
import uuid

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
    def start_puzzle_session(db: Session, user: User, contest_id: int, device_fingerprint: str, ip_address: str) -> dict:
        if PuzzleGameService.is_maintenance_mode():
            raise ValueError("Image Puzzle is currently under maintenance. Please try again later.")
        contest = db.query(ImagePuzzleContest).filter(ImagePuzzleContest.id == contest_id).first()
        if not contest:
            raise ValueError("Contest not found.")
        if contest.status != "ACTIVE" and contest.status != "UPCOMING":
            raise ValueError("Contest is not active.")
        if contest.joined_slots >= contest.total_slots:
            raise ValueError("Contest is full.")

        existing_attempt = db.query(ImagePuzzleAttempt).filter(
            ImagePuzzleAttempt.contest_id == contest_id,
            ImagePuzzleAttempt.user_id == user.id
        ).first()
        if existing_attempt:
            raise ValueError("You have already started or joined this contest.")

        # Deduct entry fee using the central WalletService
        WalletService.deduct_entry_fee(db, user, contest.entry_fee)
        contest.joined_slots += 1

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
            status="IN_PROGRESS"
        )
        db.add(attempt)
        db.commit()

        signature = PuzzleAntiCheatService.generate_signature(session_id, contest_id, user.id)

        return {
            "session_id": session_id,
            "shuffled_layout": json.loads(puzzle_game.shuffled_layout),
            "started_at": started_at,
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
            from app.websocket import puzzle_leaderboard_manager
            puzzle_leaderboard_manager.update_score(data.contest_id, user.id, user.name or user.phone, score, data.completion_seconds)
            leaderboard = puzzle_leaderboard_manager.get_leaderboard(data.contest_id)
            import asyncio
            from app.websocket import puzzle_ws_manager
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
                WalletService.credit_prize(db, user, payout_amount)
                payouts_made += 1
            else:
                from app.core.notifications import send_push_to_user
                send_push_to_user(
                    db,
                    user.id,
                    title="🏁 Puzzle Contest Completed",
                    body=f"'{contest.title}' has finished! You placed Rank #{rank_idx}. Better luck next time!"
                )

        db.commit()
        return {"status": "SUCCESS", "payouts_made": payouts_made}


import hmac
import hashlib
import uuid
import json

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


from app.websocket import word_leaderboard_manager


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
        if contest.status != "ACTIVE" and contest.status != "UPCOMING":
            raise ValueError("Contest has already started or completed.")
        if contest.joined_slots >= contest.total_slots:
            raise ValueError("Contest is full.")

        existing_attempt = db.query(WordAttempt).filter(
            WordAttempt.contest_id == contest_id,
            WordAttempt.user_id == user.id
        ).first()
        if existing_attempt:
            raise ValueError("You have already joined this contest.")

        # Deduct entry fee using central WalletService
        WalletService.deduct_entry_fee(db, user, contest.entry_fee)
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

        # Sanity check start/end time
        now = datetime.now(timezone.utc)
        if now < contest.start_time.replace(tzinfo=timezone.utc) or now > contest.end_time.replace(tzinfo=timezone.utc):
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
        attempt.started_at = now
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
        actual_elapsed = (datetime.now(timezone.utc) - attempt.started_at.replace(tzinfo=timezone.utc)).total_seconds()
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
            import asyncio
            from app.websocket import word_ws_manager
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
                WalletService.credit_prize(db, user, payout_amount)
                payouts_made += 1
            else:
                from app.core.notifications import send_push_to_user
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
        actual_elapsed = (datetime.now(timezone.utc) - started_at.replace(tzinfo=timezone.utc)).total_seconds()
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
    def start_fruit_session(db: Session, user: User, contest_id: int, device_fingerprint: str, ip_address: str) -> dict:
        if FruitGameService.is_maintenance_mode():
            raise ValueError("Fruit Puzzle is currently under maintenance. Please try again later.")
        contest = db.query(FruitContest).filter(FruitContest.id == contest_id).with_for_update().first()
        if not contest:
            raise ValueError("Contest not found.")
        if contest.status != "ACTIVE" and contest.status != "UPCOMING":
            raise ValueError("Contest is not active.")
        if contest.joined_slots >= contest.total_slots:
            raise ValueError("Contest is full.")

        existing_attempt = db.query(FruitMatch).filter(
            FruitMatch.contest_id == contest_id,
            FruitMatch.user_id == user.id
        ).first()
        if existing_attempt:
            raise ValueError("You have already started or joined this contest.")

        # Deduct wallet entry fee via existing central WalletService
        WalletService.deduct_entry_fee(db, user, contest.entry_fee)
        contest.joined_slots += 1

        session_id = str(uuid.uuid4())
        started_at = datetime.now(timezone.utc)

        match_record = FruitMatch(
            contest_id=contest_id,
            user_id=user.id,
            session_id=session_id,
            status="IN_PROGRESS",
            device_fingerprint=device_fingerprint,
            ip_address=ip_address,
            started_at=started_at,
            signature=FruitAntiCheatService.generate_signature(session_id, contest_id, user.id)
        )
        db.add(match_record)
        db.commit()

        return {
            "session_id": session_id,
            "seed": contest.seed,
            "duration_seconds": contest.duration_seconds,
            "started_at": started_at,
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

        match_record.status = "SUBMITTED"
        match_record.submitted_at = datetime.now(timezone.utc)
        db.commit()

        # Update in-memory WebSocket leaderboard Standings
        try:
            from app.websocket import fruit_leaderboard_manager, fruit_ws_manager
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
            import asyncio
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
                WalletService.credit_prize(db, user, payout_amount)
                payouts_made += 1
            else:
                from app.core.notifications import send_push_to_user
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
        actual_elapsed = (datetime.now(timezone.utc) - started_at.replace(tzinfo=timezone.utc)).total_seconds()
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
        import time
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
    def start_arrow_session(db: Session, user: User, contest_id: int, device_fingerprint: str, ip_address: str) -> dict:
        if ArrowGameService.is_maintenance_mode():
            raise ValueError("Go Arrows is currently under maintenance. Please try again later.")

        contest = db.query(ArrowContest).filter(ArrowContest.id == contest_id).first()
        if not contest:
            raise ValueError("Contest not found.")
        if contest.status != "ACTIVE" and contest.status != "UPCOMING":
            raise ValueError("Contest is not active.")

        existing_attempt = db.query(ArrowAttempt).filter(
            ArrowAttempt.contest_id == contest_id,
            ArrowAttempt.user_id == user.id
        ).first()
        
        if existing_attempt:
            # Re-entrant session recovery
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
                db.commit()
            
            layout_data = ArrowGameService.generate_solvable_layout_reverse(
                contest.grid_size, contest.arrow_count, db_seed.seed
            )
            signature = ArrowAntiCheatService.generate_signature(existing_attempt.session_id, contest_id, user.id)
            return {
                "session_id": existing_attempt.session_id,
                "layout": layout_data,
                "started_at": existing_attempt.started_at,
                "grid_size": contest.grid_size,
                "duration_seconds": contest.duration_seconds,
                "signature": signature
            }

        if contest.joined_slots >= contest.total_slots:
            raise ValueError("Contest is full.")

        # Wallet balances validation and deduction
        WalletService.deduct_entry_fee(db, user, contest.entry_fee)
        contest.joined_slots += 1

        # Generate seed and store it
        seed_val = random.randint(100000, 999999)
        db_seed = ArrowPuzzleSeed(
            contest_id=contest_id,
            user_id=user.id,
            seed=seed_val,
            difficulty=contest.difficulty or "MEDIUM"
        )
        db.add(db_seed)
        db.flush()

        # Generate solvable layout
        layout_data = ArrowGameService.generate_solvable_layout_reverse(
            contest.grid_size, contest.arrow_count, seed_val
        )

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
            status="IN_PROGRESS"
        )
        db.add(attempt)
        db.commit()

        signature = ArrowAntiCheatService.generate_signature(session_id, contest_id, user.id)

        return {
            "session_id": session_id,
            "layout": layout_data,
            "started_at": started_at,
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
            from app.websocket import arrow_leaderboard_manager, arrow_ws_manager
            arrow_leaderboard_manager.update_score(
                contest_id=data.contest_id,
                user_id=user.id,
                name=user.name or user.phone,
                score=score,
                duration=data.completion_seconds
            )
            leaderboard = arrow_leaderboard_manager.get_leaderboard(data.contest_id)
            import asyncio
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
                WalletService.credit_prize(db, user, payout_amount)
                if db_leaderboard:
                    db_leaderboard.prize_amount = payout_amount
                    db_leaderboard.is_paid = True
                    db_leaderboard.paid_at = datetime.now(timezone.utc)
                payouts_made += 1
            else:
                from app.core.notifications import send_push_to_user
                send_push_to_user(
                    db,
                    user.id,
                    title="🏁 Arrow Contest Completed",
                    body=f"'{contest.title}' has finished! You placed Rank #{rank_idx}. Better luck next time!"
                )

        db.commit()
        return {"status": "SUCCESS", "payouts_made": payouts_made}





