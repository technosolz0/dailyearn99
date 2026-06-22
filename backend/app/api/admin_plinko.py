from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List
import json

from app.core.database import get_db
from app.models import User, PlinkoGame, PlinkoSetting, PlinkoMultiplier, PlinkoRTP
from app.schemas import (
    PlinkoStatsResponse, PlinkoLogAdminResponse, PlinkoSettingsResponse, PlinkoSettingsUpdateRequest,
    PlinkoMultiplierResponse, PlinkoMultiplierUpdateRequest, PlinkoRTPResponse, PlinkoRTPCreateRequest, PlinkoRTPUpdateRequest
)
from app.core.security import get_current_admin
from app.services import PlinkoGameService

router = APIRouter(prefix="/admin/plinko", tags=["Admin Plinko"], dependencies=[Depends(get_current_admin)])


@router.get("/stats", response_model=PlinkoStatsResponse)
def get_plinko_stats(db: Session = Depends(get_db)):
    total_games = db.query(PlinkoGame).count()
    total_bet = db.query(func.sum(PlinkoGame.bet_amount)).scalar() or 0.0
    total_win = db.query(func.sum(PlinkoGame.win_amount)).scalar() or 0.0

    profit = total_bet - total_win
    ratio = (total_win / total_bet) * 100 if total_bet > 0 else 0.0

    return PlinkoStatsResponse(
        total_games=total_games,
        total_bet_amount=total_bet,
        total_winnings_paid=total_win,
        platform_net_profit=profit,
        payout_ratio=ratio
    )


@router.get("/logs", response_model=List[PlinkoLogAdminResponse])
def get_plinko_logs(db: Session = Depends(get_db)):
    results = (
        db.query(PlinkoGame, User.phone, User.name)
        .join(User, PlinkoGame.user_id == User.id)
        .order_by(PlinkoGame.created_at.desc())
        .limit(200)
        .all()
    )

    import math
    logs = []
    # Fetch active RTP overrides
    rtps = db.query(PlinkoRTP).filter(PlinkoRTP.enabled == True).all()
    for game, phone, name in results:
        # Check if an override applies
        applied_rtp = None
        for r in rtps:
            if r.min_amount <= game.bet_amount <= r.max_amount and r.rows == game.rows and r.mode == game.mode.lower():
                applied_rtp = r
                break

        prob = 0.0
        if applied_rtp:
            try:
                weights = json.loads(applied_rtp.probability_json)
                if isinstance(weights, dict):
                    total_weight = sum(float(w) for w in weights.values())
                    val = float(weights.get(str(game.final_bucket)) or weights.get(game.final_bucket, 0.0))
                    prob = val / total_weight if total_weight > 0 else 0.0
                elif isinstance(weights, list):
                    total_weight = sum(float(w) for w in weights)
                    if 0 <= game.final_bucket < len(weights):
                        prob = float(weights[game.final_bucket]) / total_weight if total_weight > 0 else 0.0
            except Exception:
                pass
        else:
            # Binomial: C(rows, bucket) * 0.5^rows
            n = game.rows
            k = game.final_bucket
            if 0 <= k <= n:
                prob = math.comb(n, k) * (0.5 ** n)

        logs.append(
            PlinkoLogAdminResponse(
                id=game.id,
                user_id=game.user_id,
                user_phone=phone,
                user_name=name,
                bet_amount=game.bet_amount,
                rows=game.rows,
                mode=game.mode,
                multiplier=game.multiplier,
                win_amount=game.win_amount,
                created_at=game.created_at,
                win_probability=prob
            )
        )
    return logs


@router.get("/settings", response_model=PlinkoSettingsResponse)
def get_plinko_settings(db: Session = Depends(get_db)):
    settings = db.query(PlinkoSetting).first()
    if not settings:
        settings = PlinkoSetting(min_bet=10.0, max_bet=5000.0, maintenance_mode=False)
        db.add(settings)
        db.commit()
        db.refresh(settings)
    return settings


@router.post("/settings", response_model=PlinkoSettingsResponse)
def update_plinko_settings(payload: PlinkoSettingsUpdateRequest, db: Session = Depends(get_db)):
    settings = db.query(PlinkoSetting).first()
    if not settings:
        settings = PlinkoSetting()
        db.add(settings)

    settings.min_bet = payload.min_bet
    settings.max_bet = payload.max_bet
    settings.maintenance_mode = payload.maintenance_mode

    db.commit()
    db.refresh(settings)
    return settings


@router.get("/multipliers", response_model=List[PlinkoMultiplierResponse])
def get_plinko_multipliers(db: Session = Depends(get_db)):
    return db.query(PlinkoMultiplier).all()


@router.post("/multipliers", response_model=PlinkoMultiplierResponse)
def update_plinko_multipliers(payload: PlinkoMultiplierUpdateRequest, db: Session = Depends(get_db)):
    # Check multipliers list formatting
    try:
        parsed = json.loads(payload.multipliers_json)
        if not isinstance(parsed, list):
            raise ValueError("Must be a list")
        if len(parsed) != payload.rows + 1:
            raise ValueError(f"List must contain exactly {payload.rows + 1} multipliers")
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid multipliers format: {str(e)}"
        )

    item = db.query(PlinkoMultiplier).filter(
        PlinkoMultiplier.rows == payload.rows,
        PlinkoMultiplier.mode == payload.mode.lower()
    ).first()

    if not item:
        item = PlinkoMultiplier(rows=payload.rows, mode=payload.mode.lower())
        db.add(item)

    item.multipliers_json = payload.multipliers_json
    db.commit()
    db.refresh(item)
    return item


@router.get("/rtp", response_model=List[PlinkoRTPResponse])
def get_plinko_rtp(db: Session = Depends(get_db)):
    return db.query(PlinkoRTP).all()


@router.post("/rtp", response_model=PlinkoRTPResponse)
def create_or_update_plinko_rtp(payload: PlinkoRTPCreateRequest, db: Session = Depends(get_db)):
    # Validate JSON probabilities formatting
    try:
        parsed = json.loads(payload.probability_json)
        # Ensure it lists probabilities for all rows + 1 buckets
        # Note: can be list or map, e.g. mapping string bucket index key to weight
        # Example format: {"0": 5.0, "1": 10.0, ...} or list of weights [5.0, 10.0, ...]
        if isinstance(parsed, list):
            if len(parsed) != payload.rows + 1:
                raise ValueError(f"List must contain exactly {payload.rows + 1} probabilities")
            total_pct = sum(parsed)
        elif isinstance(parsed, dict):
            if len(parsed) != payload.rows + 1:
                raise ValueError(f"Map must contain exactly {payload.rows + 1} elements")
            total_pct = sum(parsed.values())
        else:
            raise ValueError("Must be a list or object mapping indices to weights")

        if not (99.0 <= total_pct <= 101.0) and not (0.99 <= total_pct <= 1.01):
            # Allow both percentage (sums to 100) or decimal weights (sums to 1.0) or custom weights (we normalize if needed, but checking is safe)
            pass
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid probability weights JSON: {str(e)}"
        )

    # Check if there is an overlapping tier
    item = db.query(PlinkoRTP).filter(
        PlinkoRTP.min_amount == payload.min_amount,
        PlinkoRTP.max_amount == payload.max_amount,
        PlinkoRTP.rows == payload.rows,
        PlinkoRTP.mode == payload.mode.lower()
    ).first()

    if not item:
        item = PlinkoRTP(
            min_amount=payload.min_amount,
            max_amount=payload.max_amount,
            rows=payload.rows,
            mode=payload.mode.lower()
        )
        db.add(item)

    item.probability_json = payload.probability_json
    item.enabled = payload.enabled
    db.commit()
    db.refresh(item)
    return item


@router.put("/rtp/{id}", response_model=PlinkoRTPResponse)
def update_plinko_rtp_by_id(id: int, payload: PlinkoRTPUpdateRequest, db: Session = Depends(get_db)):
    item = db.query(PlinkoRTP).filter(PlinkoRTP.id == id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Plinko RTP setting not found")

    try:
        parsed = json.loads(payload.probability_json)
        if isinstance(parsed, list):
            if len(parsed) != item.rows + 1:
                raise ValueError(f"List must contain exactly {item.rows + 1} probabilities")
        elif isinstance(parsed, dict):
            if len(parsed) != item.rows + 1:
                raise ValueError(f"Map must contain exactly {item.rows + 1} elements")
        else:
            raise ValueError("Must be a list or object mapping indices to weights")
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid probability weights JSON: {str(e)}"
        )

    item.probability_json = payload.probability_json
    item.enabled = payload.enabled
    db.commit()
    db.refresh(item)
    return item


@router.delete("/rtp/{id}")
def delete_plinko_rtp(id: int, db: Session = Depends(get_db)):
    item = db.query(PlinkoRTP).filter(PlinkoRTP.id == id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Plinko RTP override not found")

    db.delete(item)
    db.commit()
    return {"message": "Plinko RTP override deleted successfully"}


@router.post("/maintenance")
def toggle_plinko_maintenance(enabled: bool, db: Session = Depends(get_db)):
    settings = db.query(PlinkoSetting).first()
    if not settings:
        settings = PlinkoSetting()
        db.add(settings)

    settings.maintenance_mode = enabled
    db.commit()
    return {"maintenance_mode": settings.maintenance_mode}
