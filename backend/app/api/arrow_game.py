from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.orm import Session
from datetime import datetime, timezone
from typing import List

from app.core.database import get_db
from app.models import User, ArrowContest, ArrowAttempt, ArrowLeaderboard
from app.schemas import (
    ArrowContestResponse,
    ArrowStartSessionResponse,
    ArrowScoreSubmissionRequest,
    ArrowLeaderboardItem,
    JoinArrowContestRequest
)
from app.core.security import get_current_user
from app.services import ArrowGameService, ArrowRewardService

router = APIRouter(prefix="/arrow", tags=["arrow"])

@router.get("/contests", response_model=List[ArrowContestResponse])
def get_arrow_contests(db: Session = Depends(get_db)):
    now = datetime.now(timezone.utc)
    
    # 1. Transition UPCOMING to ACTIVE when start time is reached
    upcoming_to_active = db.query(ArrowContest).filter(
        ArrowContest.status == "UPCOMING",
        ArrowContest.start_time <= now
    ).all()

    for c in upcoming_to_active:
        c.status = "ACTIVE"
        db.commit()

        # Find registered users to notify (in the case of seat booking if applicable)
        from app.models import ArrowAttempt, Notification
        from app.core.notifications import send_push_to_user
        import json

        attempts = db.query(ArrowAttempt).filter(ArrowAttempt.contest_id == c.id).all()
        for att in attempts:
            title = "🏹 Go Arrows Contest Started!"
            body = f"The contest '{c.title}' has officially started! Tap to clear the grid now!"
            data = {"type": "contest_started", "contest_id": str(c.id), "category": "ARROW"}

            db_notification = Notification(
                user_id=att.user_id,
                title=title,
                body=body,
                data_json=json.dumps(data)
            )
            db.add(db_notification)
            db.commit()

            send_push_to_user(db, att.user_id, title, body, data, save_to_db=False)

    # 2. Process rewards for expired active contests
    expired_contests = db.query(ArrowContest).filter(
        ArrowContest.status == "ACTIVE",
        ArrowContest.end_time <= now
    ).all()

    for c in expired_contests:
        ArrowRewardService.complete_contest_rewards(db, c.id)

    # 3. Fetch list, filter completed contests older than 24 hours
    contests = db.query(ArrowContest).all()
    filtered_contests = []
    for c in contests:
        if c.status == "COMPLETED" and c.end_time:
            if (now - c.end_time).total_seconds() > 24 * 3600:
                continue
        filtered_contests.append(c)
    return filtered_contests


@router.post("/join")
def join_arrow_contest(
    payload: JoinArrowContestRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    try:
        result = ArrowGameService.join_arrow_contest(
            db=db,
            user=current_user,
            contest_id=payload.contest_id,
            device_fingerprint=payload.device_fingerprint,
            ip_address=payload.ip_address
        )
        return result
    except ValueError as e:
        if str(e) == "You have already joined this contest.":
            from app.models import ArrowAttempt
            att = db.query(ArrowAttempt).filter(
                ArrowAttempt.contest_id == payload.contest_id,
                ArrowAttempt.user_id == current_user.id
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


@router.post("/start/{contest_id}", response_model=ArrowStartSessionResponse)
def start_arrow_session(
    contest_id: int,
    request: Request,
    device_fingerprint: str = "web_fallback_fingerprint",
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    ip_address = request.client.host if request.client else "127.0.0.1"
    try:
        session_data = ArrowGameService.start_arrow_session(
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
def submit_arrow_score(
    payload: ArrowScoreSubmissionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    try:
        result = ArrowGameService.submit_arrow_score(db, current_user, payload)
        return result
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.get("/leaderboard/{contest_id}", response_model=List[ArrowLeaderboardItem])
def get_arrow_leaderboard(contest_id: int, db: Session = Depends(get_db)):
    from app.websocket import arrow_leaderboard_manager
    leaderboard = arrow_leaderboard_manager.get_leaderboard(contest_id)
    if not leaderboard:
        # Load from DB
        arrow_leaderboard_manager.load_from_db(db, contest_id)
        leaderboard = arrow_leaderboard_manager.get_leaderboard(contest_id)
    return leaderboard
