from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List
import json

from app.core.database import get_db
from app.models import User, MinesGame, MinesSetting
from app.schemas import MinesStatsResponse, MinesLogAdminResponse, MinesSettingsResponse, MinesSettingsUpdateRequest
from app.core.security import get_current_admin

router = APIRouter(prefix="/admin/mines", tags=["Admin Mines"], dependencies=[Depends(get_current_admin)])


@router.get("/stats", response_model=MinesStatsResponse)
def get_mines_stats(db: Session = Depends(get_db)):
    total_games = db.query(MinesGame).count()
    total_bet = db.query(func.sum(MinesGame.bet_amount)).scalar() or 0.0
    total_win = db.query(func.sum(MinesGame.current_win)).scalar() or 0.0
    
    profit = total_bet - total_win
    ratio = (total_win / total_bet) * 100 if total_bet > 0 else 0.0
    
    return MinesStatsResponse(
        total_games=total_games,
        total_bet_amount=total_bet,
        total_winnings_paid=total_win,
        platform_net_profit=profit,
        payout_ratio=ratio
    )


@router.get("/logs", response_model=List[MinesLogAdminResponse])
def get_mines_logs(db: Session = Depends(get_db)):
    results = (
        db.query(MinesGame, User.phone, User.name)
        .join(User, MinesGame.user_id == User.id)
        .order_by(MinesGame.created_at.desc())
        .limit(200)
        .all()
    )
    
    logs = []
    for game, phone, name in results:
        logs.append(
            MinesLogAdminResponse(
                id=game.id,
                user_id=game.user_id,
                user_phone=phone,
                user_name=name,
                bet_amount=game.bet_amount,
                mines_count=game.mines_count,
                multiplier=game.current_multiplier,
                win_amount=game.current_win,
                result_type=game.status,
                created_at=game.created_at
            )
        )
    return logs


@router.get("/settings", response_model=MinesSettingsResponse)
def get_mines_settings(db: Session = Depends(get_db)):
    settings = db.query(MinesSetting).first()
    if not settings:
        settings = MinesSetting(house_edge=0.03, min_bet=10.0, max_bet=5000.0, maintenance_mode=False)
        db.add(settings)
        db.commit()
        db.refresh(settings)
    return settings


@router.post("/settings", response_model=MinesSettingsResponse)
def update_mines_settings(payload: MinesSettingsUpdateRequest, db: Session = Depends(get_db)):
    settings = db.query(MinesSetting).first()
    if not settings:
        settings = MinesSetting()
        db.add(settings)
    
    settings.house_edge = payload.house_edge
    settings.min_bet = payload.min_bet
    settings.max_bet = payload.max_bet
    settings.maintenance_mode = payload.maintenance_mode
    
    db.commit()
    db.refresh(settings)
    return settings


@router.post("/maintenance")
def toggle_mines_maintenance(enabled: bool, db: Session = Depends(get_db)):
    settings = db.query(MinesSetting).first()
    if not settings:
        settings = MinesSetting()
        db.add(settings)
        
    settings.maintenance_mode = enabled
    db.commit()
    return {"maintenance_mode": settings.maintenance_mode}
