from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.orm import Session
from datetime import datetime, timezone
from typing import List

from app.core.database import get_db
from app.models import User, WordContest
from app.schemas import (
    WordContestResponse,
    JoinWordContestRequest,
    SubmitWordAnswerRequest,
    WordAnswerResponse,
    WordLeaderboardItem
)
from app.core.security import get_current_user
from app.services import WordGameService, WordRewardService, word_leaderboard_manager

router = APIRouter(prefix="/word-game", tags=["Word Game"])

@router.get("/contests", response_model=List[WordContestResponse])
def get_word_contests(db: Session = Depends(get_db)):
    """
    Fetches all word puzzle contests. Automatically transitions upcoming contests to active
    and triggers rewards payouts for completed contests.
    """
    now = datetime.now(timezone.utc)
    
    # 1. Bulk transition UPCOMING to ACTIVE
    db.query(WordContest).filter(
        WordContest.status == "UPCOMING",
        WordContest.start_time <= now
    ).update({WordContest.status: "ACTIVE"}, synchronize_session=False)
    db.commit()

    # 2. Selectively process rewards only for expired ACTIVE contests
    expired_contests = db.query(WordContest).filter(
        WordContest.status == "ACTIVE",
        WordContest.end_time <= now
    ).all()

    for c in expired_contests:
        WordRewardService.complete_contest_rewards(db, c.id)

    # 3. Retrieve all contests
    return db.query(WordContest).all()


@router.post("/join")
def join_word_contest(
    payload: JoinWordContestRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Deducts the entry fee and registers the user for a specific word contest.
    """
    try:
        result = WordGameService.join_word_contest(
            db=db,
            user=current_user,
            contest_id=payload.contest_id,
            device_fingerprint=payload.device_fingerprint,
            ip_address=payload.ip_address
        )
        return result
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.post("/start/{contest_id}")
def start_word_contest(
    contest_id: int,
    session_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Starts an active contest session and fetches the word puzzle questions (answers stripped).
    """
    try:
        session_data = WordGameService.start_word_contest(
            db=db,
            user=current_user,
            contest_id=contest_id,
            session_id=session_id
        )
        return session_data
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.post("/submit", response_model=WordAnswerResponse)
def submit_word_answer(
    payload: SubmitWordAnswerRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Validates a submitted answer, calculates points/penalties, and broadcasts live leaderboard updates.
    """
    try:
        result = WordGameService.submit_word_answer(
            db=db,
            user=current_user,
            data=payload
        )
        return result
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.get("/leaderboard/{contest_id}", response_model=List[WordLeaderboardItem])
def get_word_leaderboard(contest_id: int, db: Session = Depends(get_db)):
    """
    Fetches the live leaderboard standings for a specific contest.
    """
    leaderboard = word_leaderboard_manager.get_leaderboard(contest_id)
    if not leaderboard:
        # Load from DB cache
        word_leaderboard_manager.load_from_db(db, contest_id)
        leaderboard = word_leaderboard_manager.get_leaderboard(contest_id)
    
    # Map to schema objects
    result = []
    for item in leaderboard:
        result.append(WordLeaderboardItem(
            user_id=item["user_id"],
            name=item["name"],
            score=item["score"],
            completion_time_seconds=item["completion_time_seconds"],
            rank=item["rank"],
            prize_amount=0.0 # Default or look up if contest completed
        ))
    return result
