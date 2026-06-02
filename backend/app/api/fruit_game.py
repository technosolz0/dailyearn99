from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime, timezone
from typing import List

from app.core.database import get_db
from app.models import User, FruitContest
from app.schemas import (
    FruitContestResponse,
    JoinFruitContestRequest,
    JoinFruitContestResponse,
    StartFruitContestResponse,
    SubmitFruitScoreRequest,
    FruitLeaderboardItem
)
from app.core.security import get_current_user
from app.services import FruitGameService, FruitRewardService
from app.websocket import fruit_leaderboard_manager

router = APIRouter(prefix="/fruit-game", tags=["Fruit Slicing Game"])

@router.get("/contests", response_model=List[FruitContestResponse])
def get_fruit_contests(db: Session = Depends(get_db)):
    """
    Fetches all fruit slicing contests. Automatically transitions status from UPCOMING
    to ACTIVE and completes expired contests payouts.
    """
    now = datetime.now(timezone.utc)
    
    # 1. Select upcoming contests to transition and trigger notifications
    upcoming_to_active = db.query(FruitContest).filter(
        FruitContest.status == "UPCOMING",
        FruitContest.start_time <= now
    ).all()

    for c in upcoming_to_active:
        c.status = "ACTIVE"
        db.commit()

        # Find all users registered in this contest
        from app.models import FruitMatch, Notification
        from app.core.notifications import send_push_to_user
        import json

        matches = db.query(FruitMatch).filter(FruitMatch.contest_id == c.id).all()
        for match in matches:
            title = "🍎 Fruit Slicing Tournament Started!"
            body = f"The tournament '{c.title}' has officially started! Tap to slice and earn now!"
            data = {"type": "contest_started", "contest_id": str(c.id), "category": "FRUIT"}

            # Save in database
            db_notification = Notification(
                user_id=match.user_id,
                title=title,
                body=body,
                data_json=json.dumps(data)
            )
            db.add(db_notification)
            db.commit()

            # Trigger push notification
            send_push_to_user(db, match.user_id, title, body, data)

    # 2. Selectively process rewards only for expired ACTIVE contests
    expired_contests = db.query(FruitContest).filter(
        FruitContest.status == "ACTIVE",
        FruitContest.end_time <= now
    ).all()

    for c in expired_contests:
        FruitRewardService.complete_contest_rewards(db, c.id)

    # 3. Retrieve all contests and filter completed ones > 24 hours
    contests = db.query(FruitContest).all()
    filtered_contests = []
    for c in contests:
        if c.status == "COMPLETED" and c.end_time:
            c_end_utc = c.end_time.replace(tzinfo=timezone.utc) if c.end_time.tzinfo is None else c.end_time
            if (now - c_end_utc).total_seconds() > 24 * 3600:
                continue
        filtered_contests.append(c)
    return filtered_contests



@router.post("/join", response_model=JoinFruitContestResponse)
def join_fruit_contest(
    payload: JoinFruitContestRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Registers a user in the contest, deducting entry fees cleanly with wallet transactions.
    """
    try:
        result = FruitGameService.start_fruit_session(
            db=db,
            user=current_user,
            contest_id=payload.contest_id,
            device_fingerprint=payload.device_fingerprint,
            ip_address=payload.ip_address
        )
        return JoinFruitContestResponse(
            session_id=result["session_id"],
            entry_fee_deducted=db.query(FruitContest).filter(FruitContest.id == payload.contest_id).first().entry_fee,
            status="SUCCESS"
        )
    except ValueError as e:
        if str(e) == "You have already started or joined this contest.":
            from app.models import FruitMatch
            m = db.query(FruitMatch).filter(FruitMatch.contest_id == payload.contest_id, FruitMatch.user_id == current_user.id).first()
            if m:
                return JoinFruitContestResponse(
                    session_id=m.session_id,
                    entry_fee_deducted=0.0,
                    status="SUCCESS"
                )
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.post("/start/{contest_id}", response_model=StartFruitContestResponse)
def start_fruit_contest(
    contest_id: int,
    session_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Starts the active tournament match and releases the deterministic random seed and signature.
    """
    try:
        match_record = db.query(FruitContest).filter(FruitContest.id == contest_id).first()
        if not match_record:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Contest not found")
        
        now = datetime.now(timezone.utc)
        if now < match_record.start_time.replace(tzinfo=timezone.utc) or now > match_record.end_time.replace(tzinfo=timezone.utc):
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Contest is not active")

        return StartFruitContestResponse(
            session_id=session_id,
            seed=match_record.seed,
            duration_seconds=match_record.duration_seconds,
            started_at=now,
            signature=FruitGameService.start_fruit_session(db, current_user, contest_id, "unknown", "127.0.0.1")["signature"] # Return existing signature or generate dynamically
        )
    except ValueError as e:
        # If already joined/started we fetch and serve existing signature details
        from app.models import FruitMatch
        m = db.query(FruitMatch).filter(FruitMatch.contest_id == contest_id, FruitMatch.user_id == current_user.id).first()
        if m:
            return StartFruitContestResponse(
                session_id=m.session_id,
                seed=match_record.seed,
                duration_seconds=match_record.duration_seconds,
                started_at=m.started_at,
                signature=m.signature
            )
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )


@router.post("/submit")
def submit_fruit_score(
    payload: SubmitFruitScoreRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Submits completed gameplay swipe event streams, performing kinematic and cryptographic validation.
    """
    try:
        result = FruitGameService.submit_fruit_score(
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


@router.get("/leaderboard/{contest_id}", response_model=List[FruitLeaderboardItem])
def get_fruit_leaderboard(contest_id: int, db: Session = Depends(get_db)):
    """
    Returns live sorting scoreboard standings from cache, falling back to db queries if cold.
    """
    leaderboard = fruit_leaderboard_manager.get_leaderboard(contest_id)
    if not leaderboard:
        # Load from DB standings
        fruit_leaderboard_manager.load_from_db(db, contest_id)
        leaderboard = fruit_leaderboard_manager.get_leaderboard(contest_id)

    result = []
    for item in leaderboard:
        # Find if paid or not
        from app.models import FruitLeaderboard
        lbl_db = db.query(FruitLeaderboard).filter(FruitLeaderboard.contest_id == contest_id, FruitLeaderboard.user_id == item["user_id"]).first()
        prize = lbl_db.prize_amount if lbl_db else 0.0

        result.append(FruitLeaderboardItem(
            user_id=item["user_id"],
            name=item["name"],
            score=item["score"],
            max_combo=item["max_combo"],
            miss_count=item["miss_count"],
            rank=item["rank"],
            prize_amount=prize
        ))
    return result
