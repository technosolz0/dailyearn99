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
    
    # 1. Select upcoming contests to transition and trigger notifications
    upcoming_to_active = db.query(ImagePuzzleContest).filter(
        ImagePuzzleContest.status == "UPCOMING",
        ImagePuzzleContest.start_time <= now
    ).all()

    for c in upcoming_to_active:
        c.status = "ACTIVE"
        db.commit()

        # Find all users registered in this contest
        from app.models import ImagePuzzleAttempt, Notification
        from app.core.notifications import send_push_to_user
        import json

        attempts = db.query(ImagePuzzleAttempt).filter(ImagePuzzleAttempt.contest_id == c.id).all()
        for att in attempts:
            title = "🧩 Image Puzzle Contest Started!"
            body = f"The contest '{c.title}' has officially started! Tap to solve the grid now!"
            data = {"type": "contest_started", "contest_id": str(c.id), "category": "PUZZLE"}

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
    expired_contests = db.query(ImagePuzzleContest).filter(
        ImagePuzzleContest.status == "ACTIVE",
        ImagePuzzleContest.end_time <= now
    ).all()

    for c in expired_contests:
        PuzzleRewardService.complete_contest_rewards(db, c.id)

    # 3. Retrieve all contests and filter completed ones > 24 hours
    contests = db.query(ImagePuzzleContest).all()
    filtered_contests = []
    for c in contests:
        if c.status == "COMPLETED" and c.end_time:
            c_end_utc = c.end_time.replace(tzinfo=timezone.utc) if c.end_time.tzinfo is None else c.end_time
            if (now - c_end_utc).total_seconds() > 24 * 3600:
                continue
        filtered_contests.append(c)
    return filtered_contests


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
        if str(e) == "You have already started or joined this contest.":
            from app.models import ImagePuzzleAttempt, ImagePuzzleGame
            import json
            att = db.query(ImagePuzzleAttempt).filter(
                ImagePuzzleAttempt.contest_id == contest_id,
                ImagePuzzleAttempt.user_id == current_user.id
            ).first()
            puzzle_game = db.query(ImagePuzzleGame).filter(ImagePuzzleGame.contest_id == contest_id).first()
            contest = db.query(ImagePuzzleContest).filter(ImagePuzzleContest.id == contest_id).first()
            if att and puzzle_game and contest:
                from app.services import PuzzleAntiCheatService
                signature = PuzzleAntiCheatService.generate_signature(att.session_id, contest_id, current_user.id)
                return PuzzleStartSessionResponse(
                    session_id=att.session_id,
                    shuffled_layout=json.loads(puzzle_game.shuffled_layout),
                    started_at=att.started_at,
                    grid_size=contest.grid_size,
                    duration_seconds=contest.duration_seconds,
                    image_url=contest.image_url,
                    signature=signature
                )
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
