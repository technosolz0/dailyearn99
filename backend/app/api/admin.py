from sqlalchemy import Integer
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List, Optional
from datetime import datetime, timezone
from app.core.database import get_db
from app.models import User, Contest, WalletTransaction
from app.schemas import (
    AdminStatsResponse, UserResponse, ContestCreate, ContestResponse, TransactionResponse,
    AdminAdjustBalanceRequest, QuestionSchema, AdminLoginRequest
)
from app.core.config import settings
from app.core.security import get_current_admin, create_access_token

public_router = APIRouter(prefix="/admin", tags=["Admin Public"])

@public_router.post("/login")
def admin_login(request: AdminLoginRequest):
    if request.username == settings.ADMIN_USERNAME and request.password == settings.ADMIN_PASSWORD:
        token = create_access_token(subject="admin")
        return {"access_token": token, "token_type": "bearer"}
    else:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid admin username or password"
        )

router = APIRouter(
    prefix="/admin",
    tags=["admin"],
    dependencies=[Depends(get_current_admin)]
)


@router.get("/stats", response_model=AdminStatsResponse)
def get_stats(db: Session = Depends(get_db)):
    total_users = db.query(User).count()
    
    # Calculate deposits
    total_deposits = (
        db.query(func.sum(WalletTransaction.amount))
        .filter(WalletTransaction.type == "DEPOSIT", WalletTransaction.status == "SUCCESS")
        .scalar()
    ) or 0.0
    
    # Calculate winnings paid out
    total_winnings = (
        db.query(func.sum(WalletTransaction.amount))
        .filter(WalletTransaction.type == "PRIZE_WIN", WalletTransaction.status == "SUCCESS")
        .scalar()
    ) or 0.0
    
    # Calculate entry fees collected
    total_entry_fees = (
        db.query(func.sum(WalletTransaction.amount))
        .filter(WalletTransaction.type == "ENTRY_FEE", WalletTransaction.status == "SUCCESS")
        .scalar()
    ) or 0.0
    
    # Calculate platform revenue
    # Revenue = Entry Fees - Winnings Paid
    total_revenue = total_entry_fees - total_winnings
    
    active_contests = db.query(Contest).filter(Contest.status == "ACTIVE").count()
    
    return AdminStatsResponse(
        total_users=total_users,
        total_revenue=total_revenue,
        total_deposits=total_deposits,
        total_winnings_paid=total_winnings,
        active_contests=active_contests
    )

@router.get("/users", response_model=List[UserResponse])
def list_users(db: Session = Depends(get_db)):
    return db.query(User).order_by(User.id.desc()).all()

@router.post("/users/{id}/ban", response_model=UserResponse)
def ban_user(id: int, ban: bool, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.is_banned = ban
    db.commit()
    db.refresh(user)
    return user


@router.delete("/users/{id}")
def delete_user(id: int, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if not user.is_banned:
        raise HTTPException(status_code=400, detail="Only banned users can be deleted")
        
    # Delete related records from all user-dependent tables:
    from app.models import (
        ContestParticipant, WalletTransaction, Referral, Spin, SpinAuditLog, 
        UserQuestionHistory, ImagePuzzleAttempt, ImagePuzzleLeaderboard, 
        WordAttempt, WordAnswer, WordLeaderboard, FruitMatch, FruitEvent, FruitScore, 
        FruitLeaderboard, ArrowAttempt, ArrowLeaderboard, ArrowPuzzleSeed, Notification
    )
    
    db.query(ContestParticipant).filter(ContestParticipant.user_id == id).delete()
    db.query(WalletTransaction).filter(WalletTransaction.user_id == id).delete()
    
    # Referral table: user can be referrer or referred
    db.query(Referral).filter((Referral.referrer_id == id) | (Referral.referred_user_id == id)).delete()
    
    db.query(Spin).filter(Spin.user_id == id).delete()
    db.query(SpinAuditLog).filter(SpinAuditLog.user_id == id).delete()
    db.query(UserQuestionHistory).filter(UserQuestionHistory.user_id == id).delete()
    
    db.query(ImagePuzzleAttempt).filter(ImagePuzzleAttempt.user_id == id).delete()
    db.query(ImagePuzzleLeaderboard).filter(ImagePuzzleLeaderboard.user_id == id).delete()
    
    # WordAttempt has answers which must be deleted first
    attempts = db.query(WordAttempt).filter(WordAttempt.user_id == id).all()
    for att in attempts:
        db.query(WordAnswer).filter(WordAnswer.attempt_id == att.id).delete()
        db.delete(att)
    db.query(WordLeaderboard).filter(WordLeaderboard.user_id == id).delete()
    
    # Fruit Slicing
    matches = db.query(FruitMatch).filter(FruitMatch.user_id == id).all()
    for m in matches:
        db.query(FruitEvent).filter(FruitEvent.match_id == m.id).delete()
        db.delete(m)
    db.query(FruitScore).filter(FruitScore.user_id == id).delete()
    db.query(FruitLeaderboard).filter(FruitLeaderboard.user_id == id).delete()
    
    # Go Arrows
    db.query(ArrowAttempt).filter(ArrowAttempt.user_id == id).delete()
    db.query(ArrowLeaderboard).filter(ArrowLeaderboard.user_id == id).delete()
    db.query(ArrowPuzzleSeed).filter(ArrowPuzzleSeed.user_id == id).delete()
    
    db.query(Notification).filter(Notification.user_id == id).delete()
    
    db.delete(user)
    db.commit()
    return {"message": "User deleted successfully"}


@router.post("/users/{id}/adjust-balance", response_model=UserResponse)
def adjust_user_balance(id: int, request: AdminAdjustBalanceRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    wallet = request.wallet_type.strip().lower()
    if wallet == "deposit":
        user.deposit_balance += request.amount
    elif wallet == "winning":
        user.winning_balance += request.amount
    elif wallet == "bonus":
        user.bonus_balance += request.amount
    else:
        raise HTTPException(status_code=400, detail="Invalid wallet type. Must be 'deposit', 'winning', or 'bonus'")
        
    tx_type = "DEPOSIT" if request.amount >= 0 else "WITHDRAWAL"
    
    # Log transaction
    transaction = WalletTransaction(
        user_id=user.id,
        type=tx_type,
        amount=abs(request.amount),
        status="SUCCESS",
        description=f"Admin Adjustment: {wallet.capitalize()} Wallet"
    )
    db.add(transaction)
    db.commit()
    db.refresh(user)
    
    # Send push notification to user
    from app.core.notifications import send_push_to_user
    send_push_to_user(
        db,
        user.id,
        title="💰 Wallet Updated by Admin",
        body=f"Your {wallet.capitalize()} balance has been adjusted by {'+' if request.amount >= 0 else ''}₹{request.amount:.2f}."
    )
    
    return user

@router.post("/contests", response_model=ContestResponse)
def create_contest(request: ContestCreate, db: Session = Depends(get_db)):
    import json
    from app.core.seeds import DEFAULT_QUESTIONS

    prize_rules_json = None
    if request.prize_rules:
        prize_rules_json = json.dumps([r.model_dump() for r in request.prize_rules])
        
    questions_json = None
    if request.questions:
        questions_json = json.dumps([q.model_dump() for q in request.questions])
    else:
        questions_json = json.dumps(DEFAULT_QUESTIONS)

    contest = Contest(
        title=request.title,
        entry_fee=request.entry_fee,
        total_slots=request.total_slots,
        prize_pool=request.prize_pool,
        start_time=request.start_time,
        end_time=request.end_time,
        joined_slots=0,
        status="UPCOMING",
        prize_rules=prize_rules_json,
        questions=questions_json
    )
    db.add(contest)
    db.commit()
    db.refresh(contest)

    # Send push notification to all users
    try:
        from app.core.notifications import send_push_to_all_background
        send_push_to_all_background(
            db,
            title="🏆 New Math Contest Available!",
            body=f"Join the new '{contest.title}' contest now! Entry fee is only ₹{contest.entry_fee:.2f}, Prize Pool: ₹{contest.prize_pool:.2f}.",
            data={"type": "contest_created", "contest_id": str(contest.id), "category": "MATH"}
        )
    except Exception as e:
        print(f"Failed to trigger background push notification: {e}")

    return contest

@router.get("/withdrawals", response_model=List[TransactionResponse])
def get_withdrawals(db: Session = Depends(get_db)):
    return (
        db.query(WalletTransaction)
        .filter(WalletTransaction.type == "WITHDRAWAL")
        .order_by(WalletTransaction.created_at.desc())
        .all()
    )

@router.get("/transactions", response_model=List[TransactionResponse])
def get_transactions(db: Session = Depends(get_db)):
    return (
        db.query(WalletTransaction)
        .order_by(WalletTransaction.created_at.desc())
        .all()
    )

@router.post("/withdrawals/{id}/approve", response_model=TransactionResponse)
def approve_withdrawal(id: int, approve: bool, db: Session = Depends(get_db)):
    tx = db.query(WalletTransaction).filter(WalletTransaction.id == id).first()
    if not tx:
        raise HTTPException(status_code=404, detail="Transaction not found")
        
    if tx.status != "PENDING":
        raise HTTPException(status_code=400, detail="Transaction has already been processed")
        
    if approve:
        tx.status = "SUCCESS"
        db.commit()
        db.refresh(tx)
        
        # Send push notification for successful withdrawal approval
        from app.core.notifications import send_push_to_user
        send_push_to_user(
            db,
            tx.user_id,
            title="💸 Withdrawal Approved!",
            body=f"Your withdrawal request of ₹{tx.amount:.2f} has been approved."
        )
    else:
        tx.status = "FAILED"
        # Rollback: Refund the user's winning balance
        user = db.query(User).filter(User.id == tx.user_id).first()
        if user:
            user.winning_balance += tx.amount
        db.commit()
        db.refresh(tx)
        
        # Send push notification for rejected withdrawal
        from app.core.notifications import send_push_to_user
        send_push_to_user(
            db,
            tx.user_id,
            title="❌ Withdrawal Rejected",
            body=f"Your withdrawal request of ₹{tx.amount:.2f} was rejected. The amount has been refunded to your wallet."
        )
        
    return tx

@router.post("/deposits/{id}/approve", response_model=TransactionResponse)
def approve_deposit(id: int, approve: bool, db: Session = Depends(get_db)):
    tx = db.query(WalletTransaction).filter(WalletTransaction.id == id).first()
    if not tx:
        raise HTTPException(status_code=404, detail="Transaction not found")
        
    if tx.status != "PENDING" or tx.type != "DEPOSIT":
        raise HTTPException(status_code=400, detail="Transaction is not a pending deposit")
        
    user = db.query(User).filter(User.id == tx.user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
        
    if approve:
        tx.status = "SUCCESS"
        user.deposit_balance += tx.amount
        db.commit()
        db.refresh(tx)
        
        # Send push notification for deposit approval
        from app.core.notifications import send_push_to_user
        send_push_to_user(
            db,
            user.id,
            title="💰 Deposit Approved!",
            body=f"Your deposit of ₹{tx.amount:.2f} has been approved and credited."
        )
    else:
        tx.status = "FAILED"
        db.commit()
        db.refresh(tx)
        
        # Send push notification for rejected deposit
        from app.core.notifications import send_push_to_user
        send_push_to_user(
            db,
            user.id,
            title="❌ Deposit Rejected",
            body=f"Your deposit request of ₹{tx.amount:.2f} (UTR: {tx.utr}) was rejected."
        )
        
    return tx

# New Notification and Contest Completion Endpoints
from app.schemas import SendUserNotificationRequest, SendAllNotificationRequest
from app.core.notifications import send_push_to_user, send_push_to_all
from app.models import ContestParticipant
from app.services import WalletService

@router.post("/notifications/send-user")
def admin_send_user_notification(request: SendUserNotificationRequest, db: Session = Depends(get_db)):
    success = send_push_to_user(db, request.user_id, request.title, request.body)
    if not success:
        raise HTTPException(status_code=400, detail="Failed to send notification. Verify user exists and has a token.")
    return {"message": "Notification sent successfully."}

@router.post("/notifications/send-all")
def admin_send_all_notification(request: SendAllNotificationRequest, db: Session = Depends(get_db)):
    sent_count = send_push_to_all(db, request.title, request.body)
    return {"message": f"Notification broadcast sent to {sent_count} users."}

@router.post("/contests/{id}/complete")
def complete_contest(id: int, db: Session = Depends(get_db)):
    from app.services import ContestService
    res = ContestService.complete_contest(db, id)
    if "error" in res:
        raise HTTPException(status_code=404, detail=res["error"])
    if res.get("message") == "Contest is already completed":
        raise HTTPException(status_code=400, detail=res["message"])
    return res

@router.post("/contests/{id}/questions", response_model=ContestResponse)
def update_contest_questions(id: int, questions: List[QuestionSchema], db: Session = Depends(get_db)):
    contest = db.query(Contest).filter(Contest.id == id).first()
    if not contest:
        raise HTTPException(status_code=404, detail="Contest not found")
        
    import json
    contest.questions = json.dumps([q.model_dump() for q in questions])
    db.commit()
    db.refresh(contest)
    return contest


@router.delete("/contests/{id}")
def delete_contest(id: int, db: Session = Depends(get_db)):
    contest = db.query(Contest).filter(Contest.id == id).first()
    if not contest:
        raise HTTPException(status_code=404, detail="Contest not found")
        
    # Delete related participants
    db.query(ContestParticipant).filter(ContestParticipant.contest_id == id).delete()
    
    db.delete(contest)
    db.commit()
    return {"message": "Contest deleted successfully"}



from app.schemas import (
    SpinStatsResponse, SpinLogAdminResponse, RTPSettingsResponse, 
    RTPUpdateRequest, RTPCreateRequest, SuspiciousUserResponse
)

@router.get("/spin/stats", response_model=SpinStatsResponse)
def get_spin_stats(db: Session = Depends(get_db)):
    from app.models import Spin
    total_spins = db.query(Spin).count()
    total_bets = db.query(func.sum(Spin.bet_amount)).scalar() or 0.0
    total_wins = db.query(func.sum(Spin.win_amount)).scalar() or 0.0
    platform_net_profit = total_bets - total_wins
    payout_ratio = (total_wins / total_bets) * 100 if total_bets > 0 else 0.0
    
    return SpinStatsResponse(
        total_spins=total_spins,
        total_winnings_paid=total_wins,
        total_bet_amount=total_bets,
        platform_net_profit=platform_net_profit,
        payout_ratio=payout_ratio
    )

@router.get("/spin/logs", response_model=List[SpinLogAdminResponse])
def get_spin_logs(db: Session = Depends(get_db)):
    from app.models import Spin, User
    results = (
        db.query(Spin, User.phone, User.name)
        .join(User, Spin.user_id == User.id)
        .order_by(Spin.created_at.desc())
        .limit(100)
        .all()
    )
    logs = []
    for spin, phone, name in results:
        logs.append(
            SpinLogAdminResponse(
                id=spin.id,
                user_id=spin.user_id,
                user_phone=phone,
                user_name=name or phone,
                bet_amount=spin.bet_amount,
                multiplier=spin.multiplier,
                win_amount=spin.win_amount,
                result_type=spin.result_type,
                wheel_segment=spin.wheel_segment,
                created_at=spin.created_at
            )
        )
    return logs

@router.get("/rtp", response_model=List[RTPSettingsResponse])
def get_rtp_settings(db: Session = Depends(get_db)):
    from app.models import RTPSettings
    return db.query(RTPSettings).all()

@router.put("/rtp/{id}", response_model=RTPSettingsResponse)
def update_rtp_settings(id: int, request: RTPUpdateRequest, db: Session = Depends(get_db)):
    from app.models import RTPSettings
    import json
    rtp = db.query(RTPSettings).filter(RTPSettings.id == id).first()
    if not rtp:
        raise HTTPException(status_code=404, detail="RTP tier settings not found")
    
    try:
        # Validate JSON formatting
        parsed = json.loads(request.probability_json)
        # Verify sum of probabilities is 100% (within tolerance)
        total_pct = sum(parsed.values())
        if not (99.0 <= total_pct <= 101.0):
            raise ValueError(f"Total probability sum must be 100% (got {total_pct}%)")
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Invalid probability weights JSON: {str(e)}")
        
    rtp.probability_json = request.probability_json
    rtp.enabled = request.enabled
    db.commit()
    db.refresh(rtp)
    return rtp

@router.post("/rtp", response_model=RTPSettingsResponse)
def create_rtp_settings(request: RTPCreateRequest, db: Session = Depends(get_db)):
    from app.models import RTPSettings
    import json
    
    try:
        # Validate JSON formatting
        parsed = json.loads(request.probability_json)
        total_pct = sum(parsed.values())
        if not (99.0 <= total_pct <= 101.0):
            raise ValueError(f"Total probability sum must be 100% (got {total_pct}%)")
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Invalid probability weights JSON: {str(e)}")
        
    rtp = RTPSettings(
        min_amount=request.min_amount,
        max_amount=request.max_amount,
        probability_json=request.probability_json,
        enabled=request.enabled
    )
    db.add(rtp)
    db.commit()
    db.refresh(rtp)
    return rtp

@router.delete("/rtp/{id}")
def delete_rtp_settings(id: int, db: Session = Depends(get_db)):
    from app.models import RTPSettings
    rtp = db.query(RTPSettings).filter(RTPSettings.id == id).first()
    if not rtp:
        raise HTTPException(status_code=404, detail="RTP setting override not found")
    
    db.delete(rtp)
    db.commit()
    return {"message": "RTP setting override deleted successfully"}

@router.get("/suspicious-users", response_model=List[SuspiciousUserResponse])
def get_suspicious_users(db: Session = Depends(get_db)):
    from app.models import Spin, User
    from sqlalchemy import func
    
    # Query aggregated stats grouped by user
    aggregates = (
        db.query(
            Spin.user_id,
            func.count(Spin.id).label("total_spins"),
            func.sum(func.cast(Spin.result_type == "WIN", Integer)).label("win_count"),
            func.sum(Spin.bet_amount).label("total_bet"),
            func.sum(Spin.win_amount).label("total_win")
        )
        .group_by(Spin.user_id)
        .all()
    )
    
    suspicious = []
    for row in aggregates:
        total_spins = row.total_spins
        win_count = row.win_count or 0
        total_bet = row.total_bet or 0.0
        total_win = row.total_win or 0.0
        
        win_ratio = (win_count / total_spins) * 100 if total_spins > 0 else 0.0
        
        # Criteria: Either win ratio > 65% on >= 5 spins, or net winnings profit > ₹1000
        if (total_spins >= 5 and win_ratio > 65.0) or (total_win - total_bet > 1000.0):
            user = db.query(User).filter(User.id == row.user_id).first()
            if user:
                suspicious.append(
                    SuspiciousUserResponse(
                        user_id=row.user_id,
                        name=user.name,
                        phone=user.phone,
                        total_spins=total_spins,
                        win_count=win_count,
                        win_ratio=win_ratio,
                        total_bet=total_bet,
                        total_win=total_win
                    )
                )
    
    # Sort suspicious users by highest net profit first
    suspicious.sort(key=lambda u: -(u.total_win - u.total_bet))
    return suspicious

@router.post("/maintenance")
def toggle_spin_maintenance(enabled: bool):
    from app.services import SpinGameService
    SpinGameService.set_maintenance_mode(enabled)
    return {"maintenance_mode": SpinGameService.is_maintenance_mode()}

@router.get("/maintenance")
def get_spin_maintenance():
    from app.services import SpinGameService
    return {"maintenance_mode": SpinGameService.is_maintenance_mode()}

@router.post("/quiz/maintenance")
def toggle_quiz_maintenance(enabled: bool):
    from app.services import ContestService
    ContestService.set_maintenance_mode(enabled)
    return {"maintenance_mode": ContestService.is_maintenance_mode()}

@router.get("/quiz/maintenance")
def get_quiz_maintenance():
    from app.services import ContestService
    return {"maintenance_mode": ContestService.is_maintenance_mode()}

