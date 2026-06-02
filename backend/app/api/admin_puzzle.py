from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime, timedelta, timezone
import json

from app.core.database import get_db
from app.models import ImagePuzzleContest, ImagePuzzleGame
from app.schemas import ImagePuzzleContestCreate, ImagePuzzleContestResponse
from app.services import PuzzleRewardService
from app.core.security import get_current_admin

router = APIRouter(prefix="/admin/puzzle", tags=["admin_puzzle"], dependencies=[Depends(get_current_admin)])


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

    # Send push notification to all users
    try:
        from app.core.notifications import send_push_to_all_background
        send_push_to_all_background(
            db,
            title="🖼️ New Image Puzzle Contest!",
            body=f"Join the new '{contest.title}' contest now! Entry fee is only ₹{contest.entry_fee:.2f}, Prize Pool: ₹{contest.prize_pool:.2f}.",
            data={"type": "contest_created", "contest_id": str(contest.id), "category": "PUZZLE"}
        )
    except Exception as e:
        print(f"Failed to trigger background push notification: {e}")

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

@router.post("/maintenance")
def toggle_puzzle_maintenance(enabled: bool):
    from app.services import PuzzleGameService
    PuzzleGameService.set_maintenance_mode(enabled)
    return {"maintenance_mode": PuzzleGameService.is_maintenance_mode()}

@router.get("/maintenance")
def get_puzzle_maintenance():
    from app.services import PuzzleGameService
    return {"maintenance_mode": PuzzleGameService.is_maintenance_mode()}
