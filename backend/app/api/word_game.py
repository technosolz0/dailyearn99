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
    now = datetime.utcnow()
    
    # 1. Select upcoming contests to transition and trigger notifications
    upcoming_to_active = db.query(WordContest).filter(
        WordContest.status == "UPCOMING",
        WordContest.start_time <= now
    ).all()

    for c in upcoming_to_active:
        c.status = "ACTIVE"
        db.commit()

        # Find all users registered in this contest
        from app.models import WordAttempt, Notification
        from app.core.notifications import send_push_to_user
        import json

        attempts = db.query(WordAttempt).filter(WordAttempt.contest_id == c.id).all()
        for att in attempts:
            title = "🔤 Word Guess Contest Started!"
            body = f"The contest '{c.title}' has officially started! Tap to unscramble and earn!"
            data = {"type": "contest_started", "contest_id": str(c.id), "category": "WORD"}

            # Save in database
            db_notification = Notification(
                user_id=att.user_id,
                title=title,
                body=body,
                data_json=json.dumps(data)
            )
            db.add(db_notification)
            db.commit()

            # Trigger push notification
            send_push_to_user(db, att.user_id, title, body, data)

    # 2. Selectively process rewards only for expired ACTIVE contests
    expired_contests = db.query(WordContest).filter(
        WordContest.status == "ACTIVE",
        WordContest.end_time <= now
    ).all()

    for c in expired_contests:
        WordRewardService.complete_contest_rewards(db, c.id)

    # 3. Retrieve all contests and filter completed ones > 24 hours
    contests = db.query(WordContest).all()
    filtered_contests = []
    for c in contests:
        if c.status == "COMPLETED" and c.end_time:
            if (now - c.end_time).total_seconds() > 24 * 3600:
                continue
        filtered_contests.append(c)
    return filtered_contests



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
        if str(e) == "You have already joined this contest.":
            from app.models import WordAttempt
            att = db.query(WordAttempt).filter(
                WordAttempt.contest_id == payload.contest_id,
                WordAttempt.user_id == current_user.id
            ).first()
            if att:
                return {
                    "session_id": att.session_id,
                    "entry_fee_deducted": 0.0,
                    "status": "SUCCESS"
                }
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
        if str(e) == "Session already started or processed.":
            from app.models import WordAttempt, WordQuestion
            from app.services import WordAntiCheatService
            import json
            att = db.query(WordAttempt).filter(
                WordAttempt.session_id == session_id,
                WordAttempt.user_id == current_user.id
            ).first()
            contest = db.query(WordContest).filter(WordContest.id == contest_id).first()
            if att and contest:
                # Fetch questions
                questions = db.query(WordQuestion).filter(WordQuestion.contest_id == contest_id).all()
                stripped_questions = []
                for q in questions:
                    try:
                        p_data = json.loads(q.puzzle_data)
                    except Exception:
                        p_data = q.puzzle_data

                    try:
                        clues_data = json.loads(q.clues) if q.clues else None
                    except Exception:
                        clues_data = q.clues

                    stripped_questions.append({
                        "id": q.id,
                        "game_type": q.game_type,
                        "puzzle_data": p_data,
                        "clues": clues_data,
                        "points_reward": q.points_reward
                    })
                signature = WordAntiCheatService.generate_signature(session_id, current_user.id)
                return {
                    "questions": stripped_questions,
                    "duration_seconds": contest.duration_seconds,
                    "started_at": att.started_at,
                    "signature": signature
                }
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
