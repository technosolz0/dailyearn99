from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Optional
import json

from app.core.database import get_db
from app.models import User, MinesGame, MinesSetting
from app.schemas import MinesStartRequest, MinesRevealRequest, MinesCashoutRequest, MinesGameResponse
from app.core.security import get_current_user
from app.services import MinesGameService

router = APIRouter(prefix="/mines", tags=["Mines Game"])


@router.post("/start", response_model=MinesGameResponse)
def start_mines_game(
    request: MinesStartRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    try:
        game = MinesGameService.start_game(
            db=db,
            user_id=current_user.id,
            bet_amount=request.bet_amount,
            mines_count=request.mines_count
        )
        # Clear secret mine positions for response
        response_game = MinesGameResponse.model_validate(game)
        response_game.mines_positions = None
        return response_game
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.post("/reveal", response_model=MinesGameResponse)
def reveal_mines_cell(
    request: MinesRevealRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    try:
        game = MinesGameService.reveal_cell(
            db=db,
            user_id=current_user.id,
            game_id=request.game_id,
            position=request.position
        )
        response_game = MinesGameResponse.model_validate(game)
        # Only reveal mine positions if status is no longer IN_PROGRESS
        if game.status == "IN_PROGRESS":
            response_game.mines_positions = None
        else:
            response_game.mines_positions = json.loads(game.mines_positions)
        return response_game
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.post("/cashout", response_model=MinesGameResponse)
def cashout_mines_game(
    request: MinesCashoutRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    try:
        game = MinesGameService.cash_out(
            db=db,
            user_id=current_user.id,
            game_id=request.game_id
        )
        response_game = MinesGameResponse.model_validate(game)
        response_game.mines_positions = json.loads(game.mines_positions)
        return response_game
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.get("/active", response_model=Optional[MinesGameResponse])
def get_active_mines_game(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    game = db.query(MinesGame).filter(
        MinesGame.user_id == current_user.id,
        MinesGame.status == "IN_PROGRESS"
    ).first()
    if not game:
        return None
    
    response_game = MinesGameResponse.model_validate(game)
    response_game.mines_positions = None
    return response_game


@router.get("/history", response_model=List[MinesGameResponse])
def get_mines_history(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    games = (
        db.query(MinesGame)
        .filter(MinesGame.user_id == current_user.id)
        .order_by(MinesGame.created_at.desc())
        .limit(50)
        .all()
    )
    # Parse lists for history display, but don't show full mines_positions for in_progress games (unlikely to have any)
    responses = []
    for g in games:
        resp = MinesGameResponse.model_validate(g)
        if g.status == "IN_PROGRESS":
            resp.mines_positions = None
        else:
            resp.mines_positions = json.loads(g.mines_positions)
        responses.append(resp)
    return responses
