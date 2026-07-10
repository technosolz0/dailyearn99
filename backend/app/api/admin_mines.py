from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List
import json

from app.core.database import get_db
from app.models import User, MinesGame, MinesSetting, MinesRTP
from app.schemas import (
    MinesStatsResponse, MinesLogAdminResponse, MinesSettingsResponse,
    MinesSettingsUpdateRequest, MinesRTPResponse, MinesRTPCreateRequest,
    MinesRTPUpdateRequest
)
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
def get_mines_logs(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    results = (
        db.query(MinesGame, User.phone, User.name)
        .join(User, MinesGame.user_id == User.id)
        .order_by(MinesGame.created_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )
    
    logs = []
    # Fetch active safety override rules
    rtps = db.query(MinesRTP).filter(MinesRTP.enabled == True).all()
    for game, phone, name in results:
        # Check if an override rule applies to this bet amount
        applied_rtp = None
        for r in rtps:
            if r.min_amount <= game.bet_amount <= r.max_amount:
                applied_rtp = r
                break
        
        # Win rate is safety rate if rule active, else default is (25 - mines_count) / 25
        win_prob = applied_rtp.win_rate if applied_rtp else (25.0 - game.mines_count) / 25.0
        
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
                created_at=game.created_at,
                win_probability=win_prob
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


@router.get("/rtp", response_model=List[MinesRTPResponse])
def get_mines_rtp(db: Session = Depends(get_db)):
    return db.query(MinesRTP).all()


@router.post("/rtp", response_model=MinesRTPResponse)
def create_or_update_mines_rtp(payload: MinesRTPCreateRequest, db: Session = Depends(get_db)):
    item = db.query(MinesRTP).filter(
        MinesRTP.min_amount == payload.min_amount,
        MinesRTP.max_amount == payload.max_amount
    ).first()

    if not item:
        item = MinesRTP(
            min_amount=payload.min_amount,
            max_amount=payload.max_amount
        )
        db.add(item)

    item.win_rate = payload.win_rate
    item.enabled = payload.enabled
    db.commit()
    db.refresh(item)
    return item


@router.put("/rtp/{id}", response_model=MinesRTPResponse)
def update_mines_rtp_by_id(id: int, payload: MinesRTPUpdateRequest, db: Session = Depends(get_db)):
    item = db.query(MinesRTP).filter(MinesRTP.id == id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Mines RTP setting not found")

    item.min_amount = payload.min_amount
    item.max_amount = payload.max_amount
    item.win_rate = payload.win_rate
    item.enabled = payload.enabled
    db.commit()
    db.refresh(item)
    return item


@router.delete("/rtp/{id}")
def delete_mines_rtp(id: int, db: Session = Depends(get_db)):
    item = db.query(MinesRTP).filter(MinesRTP.id == id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Mines RTP override not found")

    db.delete(item)
    db.commit()
    return {"message": "Mines RTP override deleted successfully"}

