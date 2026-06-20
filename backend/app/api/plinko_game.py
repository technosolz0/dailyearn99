from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from app.core.database import get_db
from app.models import User, PlinkoGame, PlinkoSetting
from app.schemas import PlinkoPlayRequest, PlinkoPlayResponse, PlinkoSettingsResponse
from app.core.security import get_current_user
from app.services import PlinkoGameService

router = APIRouter(prefix="/plinko", tags=["Plinko"])


@router.post("/play", response_model=PlinkoPlayResponse)
def play_plinko(
    request: PlinkoPlayRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    try:
        game = PlinkoGameService.play_plinko(
            db=db,
            user_id=current_user.id,
            bet_amount=request.bet_amount,
            rows=request.rows,
            mode=request.mode.lower()
        )
        return game
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.get("/history", response_model=List[PlinkoPlayResponse])
def get_plinko_history(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    games = (
        db.query(PlinkoGame)
        .filter(PlinkoGame.user_id == current_user.id)
        .order_by(PlinkoGame.created_at.desc())
        .limit(50)
        .all()
    )
    # Set updated_balance to 0 for historical listing to keep model happy
    for g in games:
        g.updated_balance = 0.0
    return games


@router.get("/settings", response_model=PlinkoSettingsResponse)
def get_plinko_settings(db: Session = Depends(get_db)):
    settings = db.query(PlinkoSetting).first()
    if not settings:
        settings = PlinkoSetting(min_bet=10.0, max_bet=5000.0, maintenance_mode=False)
        db.add(settings)
        db.commit()
        db.refresh(settings)
    return settings
