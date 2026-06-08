from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.orm import Session
from typing import List
from app.core.database import get_db
from app.models import User, Spin
from app.schemas import SpinCreateRequest, SpinResponse
from app.core.security import get_current_user
from app.services import SpinGameService

router = APIRouter(prefix="/spin", tags=["spin"])

@router.post("/create", response_model=SpinResponse)
def create_spin(
    request: SpinCreateRequest,
    req_raw: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    ip_address = req_raw.client.host if req_raw.client else "unknown"
    try:
        spin = SpinGameService.execute_spin(
            db=db,
            user_id=current_user.id,
            bet_amount=request.bet_amount,
            idempotency_key=request.idempotency_key,
            device_id=request.device_id or "mobile_app",
            ip_address=ip_address
        )
        return spin
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )

@router.get("/history", response_model=List[SpinResponse])
def get_spin_history(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    spins = (
        db.query(Spin)
        .filter(Spin.user_id == current_user.id)
        .order_by(Spin.created_at.desc())
        .limit(50)
        .all()
    )
    
    # Map physical segment index for history display as well
    for spin in spins:
        multiplier = spin.multiplier
        matching_segments = [
            idx for idx, seg in enumerate(SpinGameService.WHEEL_SEGMENTS)
            if (abs(multiplier) < 1e-4 and seg["type"] == "LOSE") or (multiplier > 0.0 and abs(seg["multiplier"] - multiplier) < 1e-4)
        ]
        spin.segment_index = matching_segments[0] if matching_segments else 0
        spin.updated_balance = 0.0 # Not needed for list
        
    return spins

@router.get("/detail/{id}", response_model=SpinResponse)
def get_spin_detail(
    id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    spin = db.query(Spin).filter(Spin.id == id).first()
    if not spin:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Spin record not found"
        )
    if spin.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to view this spin record"
        )
        
    multiplier = spin.multiplier
    matching_segments = [
        idx for idx, seg in enumerate(SpinGameService.WHEEL_SEGMENTS)
        if (abs(multiplier) < 1e-4 and seg["type"] == "LOSE") or (multiplier > 0.0 and abs(seg["multiplier"] - multiplier) < 1e-4)
    ]
    spin.segment_index = matching_segments[0] if matching_segments else 0
    spin.updated_balance = 0.0
    
    return spin
