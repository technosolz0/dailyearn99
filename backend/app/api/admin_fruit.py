from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime, timezone
import json
from typing import List

from app.core.database import get_db
from app.models import FruitGame, FruitSetting, User
from app.schemas import (
    FruitSettingsResponse,
    FruitSettingsUpdateRequest,
    FruitLogAdminResponse
)
from app.core.security import get_current_admin
from app.services import FruitSlicingService

router = APIRouter(prefix="/admin/fruit-slicing", tags=["Admin Fruit Slicing"], dependencies=[Depends(get_current_admin)])


@router.get("/settings", response_model=FruitSettingsResponse)
def get_fruit_settings(db: Session = Depends(get_db)):
    """
    Retrieves the current Fruit Slicing game configuration.
    """
    try:
        return FruitSlicingService.get_settings(db)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.post("/settings", response_model=FruitSettingsResponse)
def update_fruit_settings(
    payload: FruitSettingsUpdateRequest,
    db: Session = Depends(get_db)
):
    """
    Updates the Fruit Slicing game settings (bet ranges, RTP, multipliers).
    """
    try:
        return FruitSlicingService.update_settings(
            db=db,
            min_bet=payload.min_bet,
            max_bet=payload.max_bet,
            maintenance_mode=payload.maintenance_mode,
            winning_percentage=payload.winning_percentage,
            multipliers_json=payload.multipliers_json
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.post("/maintenance", response_model=FruitSettingsResponse)
def toggle_fruit_maintenance(
    enabled: bool,
    db: Session = Depends(get_db)
):
    """
    Toggles the fruit slicing game maintenance lockout state.
    """
    try:
        settings = FruitSlicingService.get_settings(db)
        settings.maintenance_mode = enabled
        db.commit()
        db.refresh(settings)
        return settings
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.get("/maintenance")
def get_fruit_maintenance(db: Session = Depends(get_db)):
    """
    Gets the maintenance mode status for Fruit Slicing.
    """
    settings = FruitSlicingService.get_settings(db)
    return {"maintenance_mode": settings.maintenance_mode}


@router.get("/history", response_model=List[FruitLogAdminResponse])
def get_fruit_games_history(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    """
    Returns a list of all historical play sessions of Fruit Slicing across all users.
    """
    try:
        games = db.query(FruitGame).join(User).order_by(FruitGame.created_at.desc()).offset(skip).limit(limit).all()
        result = []
        for g in games:
            result.append(FruitLogAdminResponse(
                id=g.id,
                user_id=g.user_id,
                user_phone=g.user.phone,
                user_name=g.user.name or g.user.phone,
                bet_amount=g.bet_amount,
                multiplier=g.current_multiplier,
                win_amount=g.win_amount,
                status=g.status,
                created_at=g.created_at
            ))
        return result
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )
