from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime, timezone, timedelta
import json
import random
from typing import List, Optional

from app.core.database import get_db
from app.models import FruitContest, FruitLeaderboard, FruitScore, FruitMatch, FruitEvent
from app.schemas import FruitContestCreate, FruitContestResponse
from app.services import FruitRewardService
from app.core.security import get_current_admin

router = APIRouter(prefix="/admin/fruit-slicing", tags=["Admin Fruit Slicing"], dependencies=[Depends(get_current_admin)])


@router.post("/contests", response_model=FruitContestResponse)
def create_fruit_contest(
    payload: FruitContestCreate,
    db: Session = Depends(get_db)
):
    """
    Creates a new Fruit Slicing Tournament contest with custom slot sizes, entry fees, and prize rule JSON arrays.
    """
    prize_rules_json = json.dumps([r.model_dump() for r in payload.prize_rules])
    
    # Generate random seed for deterministic fruit spawner
    chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    seed = "".join(random.choice(chars) for _ in range(16))

    now = datetime.now(timezone.utc)
    end_time = payload.end_time if payload.end_time else payload.start_time + timedelta(hours=2)

    contest = FruitContest(
        title=payload.title,
        entry_fee=payload.entry_fee,
        total_slots=payload.total_slots,
        joined_slots=0,
        prize_pool=payload.prize_pool,
        status="UPCOMING",
        prize_rules=prize_rules_json,
        seed=seed,
        duration_seconds=payload.duration_seconds,
        start_time=payload.start_time,
        end_time=end_time
    )
    db.add(contest)
    db.commit()
    db.refresh(contest)

    # Send push notification to all users
    try:
        from app.core.notifications import send_push_to_all_background
        send_push_to_all_background(
            db,
            title="🍎 New Fruit Slicing Tournament!",
            body=f"Join the new '{contest.title}' contest now! Entry fee is only ₹{contest.entry_fee:.2f}, Prize Pool: ₹{contest.prize_pool:.2f}.",
            data={"type": "contest_created", "contest_id": str(contest.id), "category": "FRUIT"}
        )
    except Exception as e:
        print(f"Failed to trigger background push notification: {e}")

    return contest


@router.post("/contests/{contest_id}/complete")
def complete_fruit_contest(
    contest_id: int,
    db: Session = Depends(get_db)
):
    """
    Manually overrides timer deadlines to force complete a tournament and release payout distributions instantly.
    """
    try:
        result = FruitRewardService.complete_contest_rewards(db, contest_id)
        if "error" in result:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=result["error"]
            )
        return result
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )

@router.post("/maintenance")
def toggle_fruit_maintenance(enabled: bool):
    from app.services import FruitGameService
    FruitGameService.set_maintenance_mode(enabled)
    return {"maintenance_mode": FruitGameService.is_maintenance_mode()}

@router.get("/maintenance")
def get_fruit_maintenance():
    from app.services import FruitGameService
    return {"maintenance_mode": FruitGameService.is_maintenance_mode()}


@router.delete("/contests/{contest_id}")
def delete_fruit_contest(contest_id: int, db: Session = Depends(get_db)):
    contest = db.query(FruitContest).filter(FruitContest.id == contest_id).first()
    if not contest:
        raise HTTPException(status_code=404, detail="Contest not found")
        
    # Delete related leaderboards, scores, and matches
    db.query(FruitLeaderboard).filter(FruitLeaderboard.contest_id == contest_id).delete()
    db.query(FruitScore).filter(FruitScore.contest_id == contest_id).delete()
    
    # Matches have events
    matches = db.query(FruitMatch).filter(FruitMatch.contest_id == contest_id).all()
    for m in matches:
        db.query(FruitEvent).filter(FruitEvent.match_id == m.id).delete()
        db.delete(m)
        
    db.delete(contest)
    db.commit()
    return {"message": "Fruit contest deleted successfully"}

