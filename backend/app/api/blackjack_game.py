import json
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.security import get_current_user
from app.models import User, BlackjackGame, BlackjackSetting
from app.schemas import BlackjackGameResponse, BlackjackStartRequest, BlackjackSettingsResponse
from app.services import BlackjackGameService

router = APIRouter(prefix="/blackjack", tags=["Blackjack Game"])

@router.post("/start", response_model=BlackjackGameResponse)
def start_blackjack(payload: BlackjackStartRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    try:
        return BlackjackGameService.start_game(db, current_user.id, payload.bet_amount)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/hit", response_model=BlackjackGameResponse)
def blackjack_hit(payload: dict, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    game_id = payload.get("game_id")
    if not game_id:
        raise HTTPException(status_code=400, detail="game_id is required.")
    try:
        return BlackjackGameService.hit(db, current_user.id, game_id)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/stand", response_model=BlackjackGameResponse)
def blackjack_stand(payload: dict, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    game_id = payload.get("game_id")
    if not game_id:
        raise HTTPException(status_code=400, detail="game_id is required.")
    try:
        return BlackjackGameService.stand(db, current_user.id, game_id)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/double", response_model=BlackjackGameResponse)
def blackjack_double(payload: dict, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    game_id = payload.get("game_id")
    if not game_id:
        raise HTTPException(status_code=400, detail="game_id is required.")
    try:
        return BlackjackGameService.double(db, current_user.id, game_id)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/split", response_model=BlackjackGameResponse)
def blackjack_split(payload: dict, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    game_id = payload.get("game_id")
    if not game_id:
        raise HTTPException(status_code=400, detail="game_id is required.")
    try:
        return BlackjackGameService.split(db, current_user.id, game_id)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/active", response_model=Optional[BlackjackGameResponse])
def get_active_blackjack(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    game = db.query(BlackjackGame).filter(BlackjackGame.user_id == current_user.id, BlackjackGame.status == "IN_PROGRESS").first()
    if game:
        locked_user = db.query(User).filter(User.id == current_user.id).first()
        res_game = BlackjackGameService.mask_dealer_card_if_needed(game)
        res_game.updated_balance = locked_user.winning_balance + locked_user.deposit_balance + locked_user.bonus_balance
        return res_game
    return None

@router.get("/history", response_model=List[BlackjackGameResponse])
def get_blackjack_history(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    games = db.query(BlackjackGame).filter(BlackjackGame.user_id == current_user.id).order_by(BlackjackGame.created_at.desc()).limit(20).all()
    return games

@router.get("/settings", response_model=BlackjackSettingsResponse)
def get_blackjack_settings(db: Session = Depends(get_db)):
    settings = db.query(BlackjackSetting).first()
    if not settings:
        settings = BlackjackSetting()
        db.add(settings)
        db.commit()
        db.refresh(settings)
    return settings
