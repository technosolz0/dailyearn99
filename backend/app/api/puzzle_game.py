from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.orm import Session
from datetime import datetime, timezone
from typing import List

from app.core.database import get_db
from app.models import User, ImagePuzzleContest, ImagePuzzleAttempt, ImagePuzzleLeaderboard
from app.schemas import (
    ImagePuzzleContestResponse,
    PuzzleStartSessionResponse,
    PuzzleScoreSubmissionRequest,
    PuzzleLeaderboardItem
)
from app.core.security import get_current_user
from app.services import PuzzleGameService, PuzzleRewardService

router = APIRouter(prefix="/puzzle", tags=["puzzle"])

@router.get("/contests", response_model=List[ImagePuzzleContestResponse])
def get_puzzle_contests(db: Session = Depends(get_db)):
    now = datetime.now(timezone.utc)
    
    # 1. Bulk transition UPCOMING to ACTIVE
    db.query(ImagePuzzleContest).filter(
        ImagePuzzleContest.status == "UPCOMING",
        ImagePuzzleContest.start_time <= now
    ).update({ImagePuzzleContest.status: "ACTIVE"}, synchronize_session=False)
    db.commit()

    # 2. Selectively process rewards only for expired ACTIVE contests
    expired_contests = db.query(ImagePuzzleContest).filter(
        ImagePuzzleContest.status == "ACTIVE",
        ImagePuzzleContest.end_time <= now
    ).all()

    for c in expired_contests:
        PuzzleRewardService.complete_contest_rewards(db, c.id)

    # 3. Retrieve all contests
    return db.query(ImagePuzzleContest).all()

@router.post("/start/{contest_id}", response_model=PuzzleStartSessionResponse)
def start_puzzle_session(
    contest_id: int,
    request: Request,
    device_fingerprint: str = "web_fallback_fingerprint",
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    ip_address = request.client.host if request.client else "127.0.0.1"
    try:
        session_data = PuzzleGameService.start_puzzle_session(
            db=db,
            user=current_user,
            contest_id=contest_id,
            device_fingerprint=device_fingerprint,
            ip_address=ip_address
        )
        return session_data
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )

@router.post("/submit-score")
def submit_puzzle_score(
    payload: PuzzleScoreSubmissionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    try:
        result = PuzzleGameService.submit_puzzle_score(db, current_user, payload)
        return result
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )

@router.get("/leaderboard/{contest_id}", response_model=List[PuzzleLeaderboardItem])
def get_puzzle_leaderboard(contest_id: int, db: Session = Depends(get_db)):
    from app.websocket import puzzle_leaderboard_manager
    leaderboard = puzzle_leaderboard_manager.get_leaderboard(contest_id)
    if not leaderboard:
        # Load from DB cache
        puzzle_leaderboard_manager.load_from_db(db, contest_id)
        leaderboard = puzzle_leaderboard_manager.get_leaderboard(contest_id)
    return leaderboard
