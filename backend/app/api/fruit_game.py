from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime, timezone
from typing import List

from app.core.database import get_db
from app.models import User, FruitGame
from app.schemas import (
    FruitSettingsResponse,
    FruitGameStartRequest,
    FruitGameResponse
)
from app.core.security import get_current_user
from app.services import FruitSlicingService

router = APIRouter(prefix="/fruit-game", tags=["Fruit Slicing Game"])


@router.get("/settings", response_model=FruitSettingsResponse)
def get_fruit_settings(db: Session = Depends(get_db)):
    """
    Fetches the active Fruit Slicing game settings (bet limits, multipliers, maintenance mode).
    """
    try:
        return FruitSlicingService.get_settings(db)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch fruit settings: {str(e)}"
        )


@router.post("/start", response_model=FruitGameResponse)
def start_fruit_game(
    payload: FruitGameStartRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Starts a Fruit Slicing gameplay session, deducting bet amount from wallet balances.
    Returns the game details and cryptographic signature.
    """
    try:
        result = FruitSlicingService.start_game(
            db=db,
            user=current_user,
            bet_amount=payload.bet_amount
        )
        game_res = result["game"]
        response = FruitGameResponse(
            id=game_res.id,
            user_id=game_res.user_id,
            bet_amount=game_res.bet_amount,
            status=game_res.status,
            current_multiplier=game_res.current_multiplier,
            win_amount=game_res.win_amount,
            created_at=game_res.created_at,
            updated_balance=result["updated_balance"],
            signature=result["signature"]
        )
        return response
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.post("/cashout/{game_id}", response_model=FruitGameResponse)
def cashout_fruit_game(
    game_id: int,
    final_multiplier: float,
    signature: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Completes the game and claims bet * final_multiplier reward.
    """
    try:
        game = FruitSlicingService.cashout_game(
            db=db,
            user=current_user,
            game_id=game_id,
            final_multiplier=final_multiplier,
            signature=signature
        )
        return game
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.post("/bomb/{game_id}", response_model=FruitGameResponse)
def bomb_fruit_game(
    game_id: int,
    signature: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Marks the game as lost due to a bomb slice.
    """
    try:
        game = FruitSlicingService.bomb_hit_game(
            db=db,
            user=current_user,
            game_id=game_id,
            signature=signature
        )
        return game
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.get("/history", response_model=List[FruitGameResponse])
def get_fruit_history(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Fetches the history of past games played by the current user.
    """
    try:
        games = db.query(FruitGame).filter(
            FruitGame.user_id == current_user.id
        ).order_by(FruitGame.created_at.desc()).limit(50).all()
        return games
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )
