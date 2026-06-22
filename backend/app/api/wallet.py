from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from app.core.database import get_db
from app.models import User, WalletTransaction, AdminBankDetail
from app.schemas import (
    UserResponse, DepositRequest, WithdrawalRequest, TransactionResponse,
    SaveBankDetailsRequest, AdminBankDetailResponse
)
from app.core.security import get_current_user
from app.services import WalletService
from app.core.config import settings

router = APIRouter(prefix="/wallet", tags=["wallet"])

@router.post("/deposit", response_model=UserResponse)
def add_money(
    request: DepositRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if request.utr:
        # Validate 12-digit numeric UTR
        utr_str = request.utr.strip()
        if len(utr_str) != 12 or not utr_str.isdigit():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Please enter a valid 12-digit UTR/Reference ID."
            )
            
        # Check for duplicate UTR to prevent double-spending fraud
        existing_tx = (
            db.query(WalletTransaction)
            .filter(WalletTransaction.utr == utr_str)
            .first()
        )
        if existing_tx:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="This UTR / Transaction ID has already been submitted."
            )
            
        # Create a pending manual deposit transaction
        transaction = WalletTransaction(
            user_id=current_user.id,
            type="DEPOSIT",
            amount=request.amount,
            status="PENDING",
            utr=utr_str,
            description=f"Deposit via UTR ({utr_str})"
        )
        db.add(transaction)
        db.commit()
        
        # Send push notification to user
        try:
            from app.core.notifications import send_push_to_user
            send_push_to_user(
                db,
                current_user.id,
                title="📥 Deposit Request Pending",
                body=f"Your deposit request of ₹{request.amount:.2f} (UTR: {utr_str}) is pending validation.",
                data={"event": "deposit_pending", "transaction_id": str(transaction.id), "amount": str(request.amount), "utr": utr_str}
            )
        except Exception as e:
            print(f"Failed to send manual deposit push to user: {e}")
        
        # Send push notification to Admin
        try:
            from app.core.notifications import send_push_to_admin
            send_push_to_admin(
                db=db,
                title="📥 Manual Deposit Request",
                body=f"User {current_user.name or current_user.phone} requested manual deposit of ₹{request.amount:.2f} (UTR: {utr_str}).",
                data={"event": "deposit_request", "transaction_id": str(transaction.id), "amount": str(request.amount), "utr": utr_str}
            )
        except Exception as e:
            print(f"Failed to send manual deposit push to admin: {e}")
    else:
        # Default mock instant success route for gateway/testing if UTR is not supplied
        WalletService.process_deposit(db, current_user, request.amount, description="Instant Deposit")
        
        # Send push notification to Admin
        try:
            from app.core.notifications import send_push_to_admin
            send_push_to_admin(
                db=db,
                title="💰 Instant Deposit Success",
                body=f"User {current_user.name or current_user.phone} made an instant deposit of ₹{request.amount:.2f}.",
                data={"event": "deposit_instant", "amount": str(request.amount)}
            )
        except Exception as e:
            print(f"Failed to send instant deposit push to admin: {e}")
        
    db.refresh(current_user)
    return current_user

@router.post("/withdraw", response_model=UserResponse)
def withdraw_money(
    request: WithdrawalRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Enforce bank account details registration
    if not current_user.bank_account_number or not current_user.bank_ifsc_code:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Bank details not set. Please save your bank details before initiating a withdrawal."
        )

    pan = request.pan.strip().upper()
    if len(pan) != 10:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid PAN format. Must be a 10-character alphanumeric string."
        )
        
    # Verify KYC status simulation
    if current_user.kyc_status != "VERIFIED":
        current_user.kyc_status = "VERIFIED" # Mock auto-verification for PAN entry
        
    try:
        WalletService.process_withdrawal(db, current_user, request.amount, description=f"Withdrawal to Bank (PAN: {pan})")
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
        
    db.commit()
    db.refresh(current_user)
    return current_user

@router.post("/bank-details", response_model=UserResponse)
def save_bank_details(
    request: SaveBankDetailsRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    current_user.bank_account_number = request.account_number.strip()
    current_user.bank_ifsc_code = request.ifsc_code.strip().upper()
    current_user.bank_account_holder_name = request.account_holder_name.strip()
    current_user.bank_name = request.bank_name.strip()
    
    db.commit()
    db.refresh(current_user)
    return current_user

@router.get("/transactions", response_model=List[TransactionResponse])
def get_transactions(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    transactions = (
        db.query(WalletTransaction)
        .filter(WalletTransaction.user_id == current_user.id)
        .order_by(WalletTransaction.created_at.desc())
        .all()
    )
    return transactions

@router.get("/bank-details", response_model=List[AdminBankDetailResponse])
def get_user_bank_details(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    all_details = db.query(AdminBankDetail).all()
    targeted_details = []
    default_details = []
    
    for detail in all_details:
        if detail.target_user_ids:
            try:
                uids = [int(x.strip()) for x in detail.target_user_ids.split(",") if x.strip()]
                if current_user.id in uids:
                    targeted_details.append(detail)
            except Exception:
                pass
        else:
            if detail.is_default:
                default_details.append(detail)
                
    if targeted_details:
        return targeted_details
    elif default_details:
        return default_details
    else:
        non_targeted = [d for d in all_details if not d.target_user_ids]
        if non_targeted:
            return non_targeted
        return all_details

