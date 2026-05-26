from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List, Optional
from datetime import datetime, timezone
from app.core.database import get_db
from app.models import User, Contest, WalletTransaction
from app.schemas import (
    AdminStatsResponse, UserResponse, ContestCreate, ContestResponse, TransactionResponse,
    AdminAdjustBalanceRequest
)
from app.core.config import settings

router = APIRouter(prefix="/admin", tags=["admin"])

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
    return db.query(User).all()

@router.post("/users/{id}/ban", response_model=UserResponse)
def ban_user(id: int, ban: bool, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.is_banned = ban
    db.commit()
    db.refresh(user)
    return user

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
        status="SUCCESS"
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
        joined_slots=0,
        status="UPCOMING",
        prize_rules=prize_rules_json,
        questions=questions_json
    )
    db.add(contest)
    db.commit()
    db.refresh(contest)
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
        .filter(WalletTransaction.type.in_(["DEPOSIT", "WITHDRAWAL"]))
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
    contest = db.query(Contest).filter(Contest.id == id).first()
    if not contest:
        raise HTTPException(status_code=404, detail="Contest not found")
        
    if contest.status == "COMPLETED":
        raise HTTPException(status_code=400, detail="Contest is already completed")
        
    contest.status = "COMPLETED"
    db.commit()
    
    # Query participants ordered by rank (which was already calculated when they submitted scores)
    participants = (
        db.query(ContestParticipant)
        .filter(ContestParticipant.contest_id == id)
        .order_by(ContestParticipant.rank.asc())
        .all()
    )
    
    if not participants:
        return {"message": "Contest completed with 0 participants.", "payouts": 0}
        
    # Standard rank-based prize pool distribution
    # Rank 1: 50%, Rank 2: 30%, Rank 3: 20%
    payout_pcts = {1: 0.50, 2: 0.30, 3: 0.20}
    
    # Adjust percentages if fewer than 3 participants
    if len(participants) == 1:
        payout_pcts = {1: 1.0}
    elif len(participants) == 2:
        payout_pcts = {1: 0.60, 2: 0.40}
        
    # Check if custom prize rules exist
    import json
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
            # Credit prize triggers standard winning notification inside WalletService.credit_prize
            WalletService.credit_prize(db, user, payout_amount)
            payouts_made += 1
        else:
            # Send runner-up / completion notification to other participants
            send_push_to_user(
                db,
                user.id,
                title="🏁 Contest Finished!",
                body=f"Contest '{contest.title}' is completed. You finished at Rank {p.rank}. Better luck next time!"
            )
            
    db.commit()
    return {"message": f"Contest completed. {payouts_made} winners paid out.", "payouts": payouts_made}
