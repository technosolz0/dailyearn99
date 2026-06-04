from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime, timedelta, timezone
import json
from typing import List, Dict, Any

from app.core.database import get_db
from app.models import WordContest, WordQuestion, WordAttempt, WordAnswer, WordLeaderboard
from app.schemas import CreateWordContestRequest, WordContestResponse
from app.services import WordRewardService
from app.core.security import get_current_admin

router = APIRouter(prefix="/admin/word-puzzle", tags=["Admin Word Puzzle"], dependencies=[Depends(get_current_admin)])


@router.post("/contests", response_model=WordContestResponse)
def create_word_contest(
    payload: CreateWordContestRequest,
    db: Session = Depends(get_db)
):
    """
    Admin utility to create a new Word Puzzle contest.
    """
    prize_rules_json = json.dumps([r.model_dump() for r in payload.prize_rules])

    contest = WordContest(
        title=payload.title,
        entry_fee=payload.entry_fee,
        total_slots=payload.total_slots,
        joined_slots=0,
        prize_pool=payload.prize_pool,
        difficulty=payload.difficulty.upper(),
        status="UPCOMING",
        prize_rules=prize_rules_json,
        duration_seconds=payload.duration_seconds,
        start_time=payload.start_time,
        end_time=payload.end_time
    )
    db.add(contest)
    db.commit()
    db.refresh(contest)

    # Send push notification to all users
    try:
        from app.core.notifications import send_push_to_all_background
        send_push_to_all_background(
            db,
            title="🧩 New Word Puzzle Contest!",
            body=f"Join the new '{contest.title}' contest now! Entry fee is only ₹{contest.entry_fee:.2f}, Prize Pool: ₹{contest.prize_pool:.2f}.",
            data={"type": "contest_created", "contest_id": str(contest.id), "category": "WORD"}
        )
    except Exception as e:
        print(f"Failed to trigger background push notification: {e}")

    return contest


@router.post("/contests/{contest_id}/complete")
def complete_word_contest(
    contest_id: int,
    db: Session = Depends(get_db)
):
    """
    Admin utility to force complete a contest and execute the prize distribution logic.
    """
    try:
        result = WordRewardService.complete_contest_rewards(db, contest_id)
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


@router.post("/questions/bulk/{contest_id}")
def upload_contest_questions(
    contest_id: int,
    questions: List[Dict[str, Any]],
    db: Session = Depends(get_db)
):
    """
    Bulk uploads questions for a specific contest, performing a clean overwrite.
    Each question dictionary has:
    - game_type (WORD_SEARCH, UNSCRAMBLE, MISSING_LETTERS, CROSSWORD)
    - difficulty (EASY, MEDIUM, HARD)
    - puzzle_data (dict)
    - clues (list of clues / clues dict, optional)
    - correct_answer (string)
    - points_reward (int, default 100)
    """
    contest = db.query(WordContest).filter(WordContest.id == contest_id).first()
    if not contest:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Contest not found."
        )

    # Clean overwrite: Delete existing questions for this contest
    try:
        db.query(WordQuestion).filter(WordQuestion.contest_id == contest_id).delete()
        db.commit()
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot update questions because users have already attempted this contest."
        )

    questions_added = 0
    for q_data in questions:
        p_data = q_data.get("puzzle_data")
        puzzle_str = json.dumps(p_data) if isinstance(p_data, (dict, list)) else str(p_data)

        clues_val = q_data.get("clues")
        clues_str = json.dumps(clues_val) if clues_val else None

        db_q = WordQuestion(
            contest_id=contest_id,
            game_type=q_data["game_type"].upper(),
            difficulty=q_data["difficulty"].upper(),
            puzzle_data=puzzle_str,
            clues=clues_str,
            correct_answer=q_data["correct_answer"].strip(),
            points_reward=int(q_data.get("points_reward", 100))
        )
        db.add(db_q)
        questions_added += 1

    db.commit()
    return {"status": "SUCCESS", "questions_added": questions_added}


@router.get("/contests/{contest_id}/questions")
def get_contest_questions(
    contest_id: int,
    db: Session = Depends(get_db)
):
    """
    Fetches all questions for a specific Word Puzzle contest.
    """
    contest = db.query(WordContest).filter(WordContest.id == contest_id).first()
    if not contest:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Contest not found."
        )

    questions = db.query(WordQuestion).filter(WordQuestion.contest_id == contest_id).all()
    
    result = []
    for q in questions:
        try:
            p_data = json.loads(q.puzzle_data)
        except Exception:
            p_data = q.puzzle_data
        
        try:
            clues_val = json.loads(q.clues) if q.clues else None
        except Exception:
            clues_val = q.clues

        result.append({
            "id": q.id,
            "game_type": q.game_type,
            "difficulty": q.difficulty,
            "puzzle_data": p_data,
            "clues": clues_val,
            "correct_answer": q.correct_answer,
            "points_reward": q.points_reward
        })
    return result

@router.post("/maintenance")
def toggle_word_maintenance(enabled: bool):
    from app.services import WordGameService
    WordGameService.set_maintenance_mode(enabled)
    return {"maintenance_mode": WordGameService.is_maintenance_mode()}

@router.get("/maintenance")
def get_word_maintenance():
    from app.services import WordGameService
    return {"maintenance_mode": WordGameService.is_maintenance_mode()}


@router.delete("/contests/{contest_id}")
def delete_word_contest(contest_id: int, db: Session = Depends(get_db)):
    contest = db.query(WordContest).filter(WordContest.id == contest_id).first()
    if not contest:
        raise HTTPException(status_code=404, detail="Contest not found")
        
    # Delete related attempts, answers, leaderboards, questions
    # Note: WordQuestion has ForeignKey cascade.
    # WordLeaderboard has ForeignKey cascade.
    # WordAttempt has RESTRICT, so we must delete WordAnswer first, then WordAttempt.
    attempts = db.query(WordAttempt).filter(WordAttempt.contest_id == contest_id).all()
    for att in attempts:
        db.query(WordAnswer).filter(WordAnswer.attempt_id == att.id).delete()
        db.delete(att)
    
    db.query(WordLeaderboard).filter(WordLeaderboard.contest_id == contest_id).delete()
    db.query(WordQuestion).filter(WordQuestion.contest_id == contest_id).delete()
    
    db.delete(contest)
    db.commit()
    return {"message": "Word contest deleted successfully"}


