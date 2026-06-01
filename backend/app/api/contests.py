from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime, timedelta, timezone
import random
import json
from typing import List
from app.core.database import get_db
from app.models import User, Contest, ContestParticipant, Question, UserQuestionHistory
from app.schemas import ContestResponse, ContestJoinRequest, SubmitScoreRequest, LeaderboardItem, QuestionSchema
from app.core.security import get_current_user
from app.services import WalletService, ReferralService, leaderboard_manager
from app.websocket import manager  # We will implement this websocket manager shortly

router = APIRouter(prefix="/contests", tags=["contests"])

@router.get("", response_model=List[ContestResponse])
def get_contests(db: Session = Depends(get_db)):
    from app.services import ContestService
    # Auto start/complete contests based on time if we want to simulate state transitions
    now = datetime.now()
    contests = db.query(Contest).all()
    
    response_contests = []
    for c in contests:
        if c.status == "UPCOMING" and c.start_time <= now:
            c.status = "ACTIVE"
            db.commit()
            
        if c.status == "ACTIVE" and c.end_time and c.end_time <= now:
            # Auto complete contest and pay out winnings
            ContestService.complete_contest(db, c.id)
            db.refresh(c)
            
        # Omit completed contests that ended more than 24 hours ago
        if c.status == "COMPLETED" and c.end_time:
            if (now - c.end_time).total_seconds() > 24 * 3600:
                continue
            
        # Detach from session to strip questions safely in-memory only (prevents sniffing)
        db.expunge(c)
        c.questions = None
        response_contests.append(c)
        
    return response_contests

@router.post("/join", response_model=ContestResponse)
def join_contest(
    request: ContestJoinRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    contest = db.query(Contest).filter(Contest.id == request.contest_id).first()
    if not contest:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Contest not found."
        )
    
    if contest.status != "UPCOMING" and contest.status != "ACTIVE":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Cannot join contest in '{contest.status}' status."
        )
        
    if contest.joined_slots >= contest.total_slots:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Contest is full."
        )
        
    # Check if already joined
    existing = (
        db.query(ContestParticipant)
        .filter(
            ContestParticipant.contest_id == contest.id,
            ContestParticipant.user_id == current_user.id
        )
        .first()
    )
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You have already joined this contest."
        )
        
    # Deduct entry fee using wallet service rules
    try:
        WalletService.deduct_entry_fee(db, current_user, contest.entry_fee)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
        
    # Add participant
    participant = ContestParticipant(
        contest_id=contest.id,
        user_id=current_user.id,
        score=0,
        rank=0,
        joined_at=datetime.now(timezone.utc)
    )
    db.add(participant)
    
    # Increment joined slots
    contest.joined_slots += 1
    db.commit()
    db.refresh(contest)
    
    # Check if first contest joined by referred user to award referral bonus!
    participation_count = (
        db.query(ContestParticipant)
        .filter(ContestParticipant.user_id == current_user.id)
        .count()
    )
    if participation_count == 1:
        # Trigger referral bonus!
        ReferralService.check_and_trigger_referral(db, current_user)
        db.refresh(current_user)

    # Boot the leaderboard manager for this contest
    leaderboard_manager.update_score(
        contest_id=contest.id,
        user_id=current_user.id,
        name=current_user.name or current_user.phone,
        score=0
    )
    
    return contest

@router.get("/{id}/questions", response_model=List[QuestionSchema])
def get_contest_questions(
    id: int,
    lang: str = "en",
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # 1. Check if the user is a registered participant in this contest
    participant = (
        db.query(ContestParticipant)
        .filter(
            ContestParticipant.contest_id == id,
            ContestParticipant.user_id == current_user.id
        )
        .first()
    )
    if not participant:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied. You must join this contest to play."
        )

    # 2. Check if questions are already generated for this session
    if participant.quiz_questions:
        try:
            stored_question_ids = json.loads(participant.quiz_questions)
            # Fetch stored questions preserving order
            questions_dict = {
                q.id: q for q in db.query(Question).filter(Question.id.in_(stored_question_ids)).all()
            }
            questions = [questions_dict[qid] for qid in stored_question_ids if qid in questions_dict]
            
            # Check if language matches requested lang
            if questions and questions[0].language == lang:
                parsed_questions = []
                for q in questions:
                    parsed_questions.append(
                        QuestionSchema(
                            text=q.text,
                            options=json.loads(q.options),
                            correct_answer_index=q.correct_answer_index
                        )
                    )
                return parsed_questions
        except Exception:
            # Fall back to regenerating if parsing fails
            pass

    # 3. Choose a random cutoff threshold between 40 and 60 days
    cutoff_days = random.randint(40, 60)
    cutoff_date = datetime.now(timezone.utc) - timedelta(days=cutoff_days)

    # 4. Find question IDs seen by the user inside the cutoff window
    seen_question_ids = [
        r[0] for r in db.query(UserQuestionHistory.question_id)
        .filter(UserQuestionHistory.user_id == current_user.id)
        .filter(UserQuestionHistory.served_at >= cutoff_date)
        .all()
    ]

    # 5. Retrieve available question IDs not seen in the cutoff window for the specified language
    # OPTIMIZED: Query ONLY the id column to avoid fetching full row objects into memory
    available_question_ids = [
        r[0] for r in db.query(Question.id)
        .filter(Question.language == lang)
        .filter(~Question.id.in_(seen_question_ids))
        .all()
    ]

    # 6. Fallback if the pool of unused questions is too small
    if len(available_question_ids) < 5:
        available_question_ids = [
            r[0] for r in db.query(Question.id)
            .filter(Question.language == lang)
            .all()
        ]

    # 7. Randomly sample 5 question IDs
    if len(available_question_ids) >= 5:
        selected_ids = random.sample(available_question_ids, 5)
    else:
        selected_ids = available_question_ids
        if not selected_ids:
            # Absolute fallback to any questions in DB
            all_backup_ids = [r[0] for r in db.query(Question.id).all()]
            selected_ids = random.sample(all_backup_ids, min(len(all_backup_ids), 5))

    # 8. Fetch the full question objects for the selected IDs and preserve order
    selected_questions_dict = {
        q.id: q for q in db.query(Question).filter(Question.id.in_(selected_ids)).all()
    }
    selected_questions = [selected_questions_dict[qid] for qid in selected_ids if qid in selected_questions_dict]

    # 9. Record the generated question IDs in the participant's session
    selected_ids_actual = [q.id for q in selected_questions]
    participant.quiz_questions = json.dumps(selected_ids_actual)

    # 10. Log the questions in UserQuestionHistory
    for q in selected_questions:
        history_entry = UserQuestionHistory(
            user_id=current_user.id,
            question_id=q.id,
            served_at=datetime.now(timezone.utc)
        )
        db.add(history_entry)
    
    db.commit()

    # 11. Format and return questions response
    parsed_questions = []
    for q in selected_questions:
        parsed_questions.append(
            QuestionSchema(
                text=q.text,
                options=json.loads(q.options),
                correct_answer_index=q.correct_answer_index
            )
        )
    return parsed_questions

@router.post("/submit-score")
async def submit_score(
    request: SubmitScoreRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    contest = db.query(Contest).filter(Contest.id == request.contest_id).first()
    if not contest:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Contest not found."
        )
        
    participant = (
        db.query(ContestParticipant)
        .filter(
            ContestParticipant.contest_id == contest.id,
            ContestParticipant.user_id == current_user.id
        )
        .first()
    )
    if not participant:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You must join the contest first."
        )
        
    score_to_save = request.score

    # Secure server-side validation if answers are provided
    if request.answers is not None:
        if participant.quiz_questions:
            try:
                stored_question_ids = json.loads(participant.quiz_questions)
                # Fetch stored questions preserving order
                questions_dict = {
                    q.id: q for q in db.query(Question).filter(Question.id.in_(stored_question_ids)).all()
                }
                questions = [questions_dict[qid] for qid in stored_question_ids if qid in questions_dict]
                
                calculated_score = 0
                for idx, q in enumerate(questions):
                    if idx < len(request.answers):
                        if request.answers[idx] == q.correct_answer_index:
                            calculated_score += 20
                            
                # Verify score
                if calculated_score != request.score:
                    print(f"[SECURITY] Score mismatch detected! User {current_user.phone} submitted {request.score} but verified score is {calculated_score}")
                
                # Override with secure server-calculated score
                score_to_save = calculated_score
            except Exception as e:
                print(f"Error during secure score calculation: {e}")
                
    # Save the score
    participant.score = score_to_save
    participant.completed = True
    db.commit()
    
    # Update in-memory leaderboard
    leaderboard_manager.update_score(
        contest_id=contest.id,
        user_id=current_user.id,
        name=current_user.name or current_user.phone,
        score=score_to_save
    )
    
    # Recalculate ranks in the DB
    updated_leaderboard = leaderboard_manager.get_leaderboard(contest.id)
    for entry in updated_leaderboard:
        db_participant = (
            db.query(ContestParticipant)
            .filter(
                ContestParticipant.contest_id == contest.id,
                ContestParticipant.user_id == entry["user_id"]
            )
            .first()
        )
        if db_participant:
            db_participant.rank = entry["rank"]
    db.commit()
    
    # Broadcast updated leaderboard to all WebSocket clients listening to this contest
    await manager.broadcast_leaderboard(contest.id, updated_leaderboard)
    
    return {"message": "Score submitted successfully.", "score": score_to_save}

@router.get("/{id}/leaderboard", response_model=List[LeaderboardItem])
def get_leaderboard(id: int, db: Session = Depends(get_db)):
    leaderboard = leaderboard_manager.get_leaderboard(id)
    if not leaderboard:
        # Try loading from database cache if in-memory is empty
        leaderboard_manager.load_from_db(db, id)
        leaderboard = leaderboard_manager.get_leaderboard(id)
    return leaderboard
