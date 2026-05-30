from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime, timedelta, timezone
import json

from app.core.database import get_db
from app.models import ImagePuzzleContest, ImagePuzzleGame
from app.schemas import ImagePuzzleContestCreate, ImagePuzzleContestResponse
from app.services import PuzzleRewardService

router = APIRouter(prefix="/admin/puzzle", tags=["admin_puzzle"])

@router.post("/contests", response_model=ImagePuzzleContestResponse)
def create_puzzle_contest(
    payload: ImagePuzzleContestCreate,
    db: Session = Depends(get_db)
):
    # Map prize rules list to serialized JSON
    prize_rules_json = json.dumps([r.model_dump() for r in payload.prize_rules])
    
    # Calculate end_time if not provided based on duration
    end_time = payload.end_time
    if not end_time:
        end_time = payload.start_time + timedelta(seconds=payload.duration_seconds)

    contest = ImagePuzzleContest(
        title=payload.title,
        entry_fee=payload.entry_fee,
        total_slots=payload.total_slots,
        joined_slots=0,
        prize_pool=payload.prize_pool,
        start_time=payload.start_time,
        end_time=end_time,
        status="UPCOMING",
        prize_rules=prize_rules_json,
        image_url=payload.image_url,
        grid_size=payload.grid_size,
        duration_seconds=payload.duration_seconds
    )
    db.add(contest)
    db.commit()
    db.refresh(contest)
    
    return contest

@router.post("/contests/{contest_id}/complete")
def complete_puzzle_contest(
    contest_id: int,
    db: Session = Depends(get_db)
):
    try:
        result = PuzzleRewardService.complete_contest_rewards(db, contest_id)
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
