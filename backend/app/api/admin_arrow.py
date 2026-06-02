from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
import json

from app.core.database import get_db
from app.models import ArrowContest, ArrowGame
from app.schemas import ArrowContestCreate, ArrowContestResponse
from app.services import ArrowRewardService, ArrowGameService
from app.core.security import get_current_user  # If authentication is required

router = APIRouter(prefix="/admin/arrow", tags=["admin-arrow"])

@router.post("/contests", response_model=ArrowContestResponse)
def create_arrow_contest(payload: ArrowContestCreate, db: Session = Depends(get_db)):
    # Convert prize_rules model to JSON string
    rules_json = json.dumps([r.model_dump() for r in payload.prize_rules])
    
    # Generate layout for the game immediately on creation
    layout_data = ArrowGameService.generate_solvable_layout(payload.grid_size)

    db_contest = ArrowContest(
        title=payload.title,
        entry_fee=payload.entry_fee,
        total_slots=payload.total_slots,
        prize_pool=payload.prize_pool,
        start_time=payload.start_time,
        end_time=payload.end_time,
        prize_rules=rules_json,
        grid_size=payload.grid_size,
        duration_seconds=payload.duration_seconds,
        status="UPCOMING"
    )
    db.add(db_contest)
    db.flush()  # Populates db_contest.id

    arrow_game = ArrowGame(
        contest_id=db_contest.id,
        layout=json.dumps(layout_data)
    )
    db.add(arrow_game)
    db.commit()
    db.refresh(db_contest)

    return db_contest


@router.post("/contests/{contest_id}/complete")
def complete_arrow_contest(contest_id: int, db: Session = Depends(get_db)):
    try:
        result = ArrowRewardService.complete_contest_rewards(db, contest_id)
        return result
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.get("/maintenance")
def get_arrow_maintenance():
    return {"maintenance_mode": ArrowGameService.is_maintenance_mode()}


@router.post("/maintenance/toggle")
def toggle_arrow_maintenance(db: Session = Depends(get_db)):
    new_state = not ArrowGameService.is_maintenance_mode()
    ArrowGameService.set_maintenance_mode(new_state)
    return {"maintenance_mode": new_state}
