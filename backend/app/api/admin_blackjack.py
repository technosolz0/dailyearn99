from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List
import json

from app.core.database import get_db
from app.models import User, BlackjackGame, BlackjackSetting
from app.schemas import (
    BlackjackStatsResponse, BlackjackLogAdminResponse, BlackjackSettingsResponse,
    BlackjackSettingsUpdateRequest
)
from app.core.security import get_current_admin

router = APIRouter(prefix="/admin/blackjack", tags=["Admin Blackjack"], dependencies=[Depends(get_current_admin)])

@router.get("/stats", response_model=BlackjackStatsResponse)
def get_blackjack_stats(db: Session = Depends(get_db)):
    total_games = db.query(BlackjackGame).count()
    total_bet = db.query(func.sum(BlackjackGame.bet_amount + BlackjackGame.split_bet_amount)).scalar() or 0.0
    total_win = db.query(func.sum(BlackjackGame.win_amount)).scalar() or 0.0

    profit = total_bet - total_win
    ratio = (total_win / total_bet) * 100 if total_bet > 0 else 0.0

    return BlackjackStatsResponse(
        total_games=total_games,
        total_bet_amount=total_bet,
        total_winnings_paid=total_win,
        platform_net_profit=profit,
        payout_ratio=ratio
    )

@router.get("/logs", response_model=List[BlackjackLogAdminResponse])
def get_blackjack_logs(db: Session = Depends(get_db)):
    results = (
        db.query(BlackjackGame, User.phone, User.name)
        .join(User, BlackjackGame.user_id == User.id)
        .order_by(BlackjackGame.created_at.desc())
        .limit(200)
        .all()
    )

    logs = []
    settings = db.query(BlackjackSetting).first()
    win_prob = settings.winning_percentage if settings else 50.0

    for game, phone, name in results:
        # Multiplier = win_amount / bet_amount
        mult = game.win_amount / game.bet_amount if game.bet_amount > 0 else 0.0
        logs.append(
            BlackjackLogAdminResponse(
                id=game.id,
                user_id=game.user_id,
                user_phone=phone,
                user_name=name,
                bet_amount=game.bet_amount,
                multiplier=mult,
                win_amount=game.win_amount,
                status=game.status if game.status == "IN_PROGRESS" else f"{game.hand_1_status}" + (f" / {game.hand_2_status}" if game.is_split else ""),
                created_at=game.created_at,
                win_probability=win_prob
            )
        )
    return logs

@router.get("/settings", response_model=BlackjackSettingsResponse)
def get_blackjack_settings(db: Session = Depends(get_db)):
    settings = db.query(BlackjackSetting).first()
    if not settings:
        settings = BlackjackSetting(min_bet=10.0, max_bet=50000.0, winning_percentage=15.0, maintenance_mode=False)
        db.add(settings)
        db.commit()
        db.refresh(settings)
    return settings

@router.post("/settings", response_model=BlackjackSettingsResponse)
def update_blackjack_settings(payload: BlackjackSettingsUpdateRequest, db: Session = Depends(get_db)):
    settings = db.query(BlackjackSetting).first()
    if not settings:
        settings = BlackjackSetting()
        db.add(settings)

    settings.min_bet = payload.min_bet
    settings.max_bet = payload.max_bet
    settings.winning_percentage = payload.winning_percentage
    settings.maintenance_mode = payload.maintenance_mode

    db.commit()
    db.refresh(settings)
    return settings

@router.post("/maintenance")
def toggle_blackjack_maintenance(enabled: bool, db: Session = Depends(get_db)):
    settings = db.query(BlackjackSetting).first()
    if not settings:
        settings = BlackjackSetting()
        db.add(settings)

    settings.maintenance_mode = enabled
    db.commit()
    return {"maintenance_mode": settings.maintenance_mode}
