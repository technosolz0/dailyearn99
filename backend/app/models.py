from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from datetime import datetime, timezone
from app.core.database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=True)
    first_name = Column(String, nullable=True)
    last_name = Column(String, nullable=True)
    phone = Column(String, unique=True, index=True, nullable=False)
    email = Column(String, unique=True, index=True, nullable=True)
    referral_code = Column(String, unique=True, nullable=False)
    referred_by = Column(String, nullable=True)  # Store referrer's code
    deposit_balance = Column(Float, default=0.0)
    winning_balance = Column(Float, default=0.0)
    bonus_balance = Column(Float, default=0.0)
    kyc_status = Column(String, default="PENDING")  # PENDING, VERIFIED, REJECTED
    is_banned = Column(Boolean, default=False)
    fcm_token = Column(String, nullable=True)
    
    # Bank Details for Withdrawals
    bank_account_number = Column(String, nullable=True)
    bank_ifsc_code = Column(String, nullable=True)
    bank_account_holder_name = Column(String, nullable=True)
    bank_name = Column(String, nullable=True)
    
    participants = relationship("ContestParticipant", back_populates="user")
    transactions = relationship("WalletTransaction", back_populates="user")

    @property
    def joined_contest_ids(self):
        return [p.contest_id for p in self.participants]

    @property
    def completed_contest_ids(self):
        return [p.contest_id for p in self.participants if p.completed]

    @property
    def joined_word_contest_ids(self):
        from app.models import WordAttempt
        from sqlalchemy.orm import object_session
        session = object_session(self)
        if session:
            return [a.contest_id for a in session.query(WordAttempt).filter(WordAttempt.user_id == self.id).all()]
        return []

    @property
    def completed_word_contest_ids(self):
        from app.models import WordAttempt
        from sqlalchemy.orm import object_session
        session = object_session(self)
        if session:
            return [a.contest_id for a in session.query(WordAttempt).filter(WordAttempt.user_id == self.id, WordAttempt.status.in_(["SUBMITTED", "VERIFIED"])).all()]
        return []

    @property
    def joined_puzzle_contest_ids(self):
        from app.models import ImagePuzzleAttempt
        from sqlalchemy.orm import object_session
        session = object_session(self)
        if session:
            return [a.contest_id for a in session.query(ImagePuzzleAttempt).filter(ImagePuzzleAttempt.user_id == self.id).all()]
        return []

    @property
    def completed_puzzle_contest_ids(self):
        from app.models import ImagePuzzleAttempt
        from sqlalchemy.orm import object_session
        session = object_session(self)
        if session:
            return [a.contest_id for a in session.query(ImagePuzzleAttempt).filter(ImagePuzzleAttempt.user_id == self.id, ImagePuzzleAttempt.status.in_(["SUBMITTED", "VERIFIED"])).all()]
        return []

    @property
    def joined_fruit_contest_ids(self):
        from app.models import FruitMatch
        from sqlalchemy.orm import object_session
        session = object_session(self)
        if session:
            return [m.contest_id for m in session.query(FruitMatch).filter(FruitMatch.user_id == self.id).all()]
        return []

    @property
    def completed_fruit_contest_ids(self):
        from app.models import FruitMatch
        from sqlalchemy.orm import object_session
        session = object_session(self)
        if session:
            return [m.contest_id for m in session.query(FruitMatch).filter(FruitMatch.user_id == self.id, FruitMatch.status.in_(["SUBMITTED", "VERIFIED"])).all()]
        return []

    @property
    def joined_arrow_contest_ids(self):
        from app.models import ArrowAttempt
        from sqlalchemy.orm import object_session
        session = object_session(self)
        if session:
            return [a.contest_id for a in session.query(ArrowAttempt).filter(ArrowAttempt.user_id == self.id).all()]
        return []

    @property
    def completed_arrow_contest_ids(self):
        from app.models import ArrowAttempt
        from sqlalchemy.orm import object_session
        session = object_session(self)
        if session:
            return [a.contest_id for a in session.query(ArrowAttempt).filter(ArrowAttempt.user_id == self.id, ArrowAttempt.status.in_(["SUBMITTED", "VERIFIED"])).all()]
        return []

class Contest(Base):
    __tablename__ = "contests"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    entry_fee = Column(Float, nullable=False)
    total_slots = Column(Integer, nullable=False)
    joined_slots = Column(Integer, default=0)
    prize_pool = Column(Float, nullable=False)
    start_time = Column(DateTime, nullable=False)
    end_time = Column(DateTime, nullable=True)
    status = Column(String, default="UPCOMING")  # UPCOMING, ACTIVE, COMPLETED
    prize_rules = Column(String, nullable=True)  # JSON string of rank-wise rules
    questions = Column(String, nullable=True)  # JSON string of quiz questions

    participants = relationship("ContestParticipant", back_populates="contest")

class ContestParticipant(Base):
    __tablename__ = "contest_participants"

    id = Column(Integer, primary_key=True, index=True)
    contest_id = Column(Integer, ForeignKey("contests.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    score = Column(Integer, default=0)
    rank = Column(Integer, default=0)
    joined_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    quiz_questions = Column(String, nullable=True)  # JSON string array of generated question IDs
    completed = Column(Boolean, default=False)

    user = relationship("User", back_populates="participants")
    contest = relationship("Contest", back_populates="participants")


class WalletTransaction(Base):
    __tablename__ = "wallet_transactions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    type = Column(String, nullable=False)  # DEPOSIT, WITHDRAWAL, ENTRY_FEE, PRIZE_WIN, REFERRAL_BONUS
    amount = Column(Float, nullable=False)
    status = Column(String, default="PENDING")  # PENDING, SUCCESS, FAILED
    utr = Column(String, unique=True, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    description = Column(String, nullable=True)

    user = relationship("User", back_populates="transactions")

class Referral(Base):
    __tablename__ = "referrals"

    id = Column(Integer, primary_key=True, index=True)
    referrer_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    referred_user_id = Column(Integer, ForeignKey("users.id"), unique=True, nullable=False)
    bonus_given = Column(Boolean, default=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

class Spin(Base):
    __tablename__ = "spins"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    bet_amount = Column(Float, nullable=False)
    multiplier = Column(Float, nullable=False)
    win_amount = Column(Float, nullable=False)
    result_type = Column(String, nullable=False)  # "WIN" or "LOSE"
    wheel_segment = Column(String, nullable=False) # e.g. "1.5x", "Lose"
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    user = relationship("User")

class RTPSettings(Base):
    __tablename__ = "rtp_settings"

    id = Column(Integer, primary_key=True, index=True)
    min_amount = Column(Float, nullable=False)
    max_amount = Column(Float, nullable=False)
    probability_json = Column(String, nullable=False)  # JSON representation of weights
    enabled = Column(Boolean, default=True)

class SpinAuditLog(Base):
    __tablename__ = "spin_audit_logs"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    request_payload = Column(String, nullable=False)
    generated_result = Column(String, nullable=False)
    ip_address = Column(String, nullable=True)
    device_id = Column(String, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    user = relationship("User")


class Question(Base):
    __tablename__ = "questions"

    id = Column(Integer, primary_key=True, index=True)
    text = Column(String, nullable=False)
    options = Column(String, nullable=False)  # JSON-serialized array of strings
    correct_answer_index = Column(Integer, nullable=False)
    language = Column(String, nullable=False, default="en", index=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))


class UserQuestionHistory(Base):
    __tablename__ = "user_question_history"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    question_id = Column(Integer, ForeignKey("questions.id"), nullable=False)
    served_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))


class ImagePuzzleContest(Base):
    __tablename__ = "image_puzzle_contests"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    entry_fee = Column(Float, nullable=False)
    total_slots = Column(Integer, nullable=False)
    joined_slots = Column(Integer, default=0)
    prize_pool = Column(Float, nullable=False)
    start_time = Column(DateTime, nullable=False)
    end_time = Column(DateTime, nullable=True)
    status = Column(String, default="UPCOMING")  # UPCOMING, ACTIVE, COMPLETED, CANCELLED
    prize_rules = Column(String, nullable=True)  # JSON string of rank-wise rules
    image_url = Column(String, nullable=False)
    grid_size = Column(Integer, default=3)  # 3 for 3x3, 4 for 4x4, etc.
    duration_seconds = Column(Integer, default=300)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))


class ImagePuzzleGame(Base):
    __tablename__ = "image_puzzle_games"

    id = Column(Integer, primary_key=True, index=True)
    contest_id = Column(Integer, ForeignKey("image_puzzle_contests.id"), nullable=False, unique=True)
    shuffled_layout = Column(String, nullable=False)  # JSON-serialized array of indices/coordinates
    solution_hash = Column(String, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))


class ImagePuzzleAttempt(Base):
    __tablename__ = "image_puzzle_attempts"

    id = Column(Integer, primary_key=True, index=True)
    contest_id = Column(Integer, ForeignKey("image_puzzle_contests.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    score = Column(Integer, default=0)
    completion_seconds = Column(Float, nullable=False)
    moves = Column(Integer, default=0)
    hints_used = Column(Integer, default=0)
    move_sequence = Column(String, nullable=False)  # JSON-serialized MoveTelemetry list
    is_verified = Column(Boolean, default=False)
    device_fingerprint = Column(String, nullable=False)
    session_id = Column(String, unique=True, nullable=False)
    ip_address = Column(String, nullable=False)
    started_at = Column(DateTime, nullable=False)
    submitted_at = Column(DateTime, nullable=False)
    status = Column(String, default="IN_PROGRESS")  # IN_PROGRESS, SUBMITTED, VERIFIED, SUSPICIOUS
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    user = relationship("User")


class ImagePuzzleLeaderboard(Base):
    __tablename__ = "image_puzzle_leaderboard"

    id = Column(Integer, primary_key=True, index=True)
    contest_id = Column(Integer, ForeignKey("image_puzzle_contests.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    score = Column(Integer, nullable=False)
    completion_seconds = Column(Float, nullable=False)
    rank = Column(Integer, nullable=False)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    user = relationship("User")


class WordContest(Base):
    __tablename__ = "word_contests"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    entry_fee = Column(Float, nullable=False, default=0.0)
    total_slots = Column(Integer, nullable=False)
    joined_slots = Column(Integer, default=0)
    prize_pool = Column(Float, nullable=False, default=0.0)
    difficulty = Column(String, nullable=False) # 'EASY', 'MEDIUM', 'HARD'
    status = Column(String, default="UPCOMING")  # UPCOMING, ACTIVE, COMPLETED, CANCELLED
    prize_rules = Column(String, nullable=False)  # JSON string
    duration_seconds = Column(Integer, default=300)
    start_time = Column(DateTime, nullable=False)
    end_time = Column(DateTime, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))


class WordQuestion(Base):
    __tablename__ = "word_questions"

    id = Column(Integer, primary_key=True, index=True)
    contest_id = Column(Integer, ForeignKey("word_contests.id", ondelete="CASCADE"), nullable=True)
    game_type = Column(String, nullable=False) # 'WORD_SEARCH', 'UNSCRAMBLE', 'MISSING_LETTERS', 'CROSSWORD'
    difficulty = Column(String, nullable=False) # 'EASY', 'MEDIUM', 'HARD'
    puzzle_data = Column(String, nullable=False) # JSON string
    clues = Column(String, nullable=True) # JSON string
    correct_answer = Column(String, nullable=False)
    points_reward = Column(Integer, default=100)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))


class WordAttempt(Base):
    __tablename__ = "word_attempts"

    id = Column(Integer, primary_key=True, index=True)
    contest_id = Column(Integer, ForeignKey("word_contests.id", ondelete="RESTRICT"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    session_id = Column(String, unique=True, index=True, nullable=False)
    total_score = Column(Integer, default=0)
    completion_time_seconds = Column(Float, nullable=True)
    hints_used = Column(Integer, default=0)
    wrong_attempts = Column(Integer, default=0)
    device_fingerprint = Column(String, nullable=False)
    ip_address = Column(String, nullable=False)
    status = Column(String, default="IN_PROGRESS") # 'IN_PROGRESS', 'SUBMITTED', 'VERIFIED', 'DISQUALIFIED'
    started_at = Column(DateTime, nullable=False)
    submitted_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    user = relationship("User")


class WordAnswer(Base):
    __tablename__ = "word_answers"

    id = Column(Integer, primary_key=True, index=True)
    attempt_id = Column(Integer, ForeignKey("word_attempts.id", ondelete="CASCADE"), nullable=False)
    question_id = Column(Integer, ForeignKey("word_questions.id", ondelete="RESTRICT"), nullable=False)
    is_correct = Column(Boolean, nullable=False)
    answer_submitted = Column(String, nullable=True)
    points_awarded = Column(Integer, default=0)
    hints_used = Column(Integer, default=0)
    attempts_count = Column(Integer, default=1)
    time_taken_seconds = Column(Float, nullable=False)
    telemetry_data = Column(String, nullable=True) # JSON string
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))


class WordLeaderboard(Base):
    __tablename__ = "word_leaderboards"

    id = Column(Integer, primary_key=True, index=True)
    contest_id = Column(Integer, ForeignKey("word_contests.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    score = Column(Integer, nullable=False)
    completion_time_seconds = Column(Float, nullable=False)
    rank = Column(Integer, nullable=False)
    prize_amount = Column(Float, default=0.0)
    is_paid = Column(Boolean, default=False)
    paid_at = Column(DateTime, nullable=True)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))

    user = relationship("User")


class FruitContest(Base):
    __tablename__ = "fruit_contests"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    entry_fee = Column(Float, nullable=False, default=0.0)
    total_slots = Column(Integer, nullable=False)
    joined_slots = Column(Integer, default=0)
    prize_pool = Column(Float, nullable=False, default=0.0)
    status = Column(String, default="UPCOMING")  # UPCOMING, ACTIVE, COMPLETED, CANCELLED
    prize_rules = Column(String, nullable=False)  # JSON string of rank-wise rules
    seed = Column(String, nullable=False)  # Random seed for fruit spawner sequence
    duration_seconds = Column(Integer, default=60)
    start_time = Column(DateTime, nullable=False)
    end_time = Column(DateTime, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))


class FruitMatch(Base):
    __tablename__ = "fruit_matches"

    id = Column(Integer, primary_key=True, index=True)
    contest_id = Column(Integer, ForeignKey("fruit_contests.id", ondelete="RESTRICT"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    session_id = Column(String, unique=True, index=True, nullable=False)
    status = Column(String, default="JOINED")  # JOINED, IN_PROGRESS, SUBMITTED, VERIFIED, SUSPICIOUS
    device_fingerprint = Column(String, nullable=False)
    ip_address = Column(String, nullable=False)
    started_at = Column(DateTime, nullable=False)
    submitted_at = Column(DateTime, nullable=True)
    signature = Column(String, nullable=False)  # Cryptographic validation hash
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    user = relationship("User")


class FruitEvent(Base):
    __tablename__ = "fruit_events"

    id = Column(Integer, primary_key=True, index=True)
    match_id = Column(Integer, ForeignKey("fruit_matches.id", ondelete="CASCADE"), nullable=False)
    event_type = Column(String, nullable=False)  # SWIPE, BOMB_HIT, MISS
    timestamp_ms = Column(Integer, nullable=False)
    coordinates = Column(String, nullable=True)  # JSON-serialized array of swipe coordinates
    sliced_items = Column(String, nullable=True)  # JSON-serialized array of sliced fruit details
    points_delta = Column(Integer, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))


class FruitScore(Base):
    __tablename__ = "fruit_scores"

    id = Column(Integer, primary_key=True, index=True)
    match_id = Column(Integer, ForeignKey("fruit_matches.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    contest_id = Column(Integer, ForeignKey("fruit_contests.id", ondelete="RESTRICT"), nullable=False)
    score = Column(Integer, default=0)
    max_combo = Column(Integer, default=0)
    miss_count = Column(Integer, default=0)
    bomb_hit_count = Column(Integer, default=0)
    is_verified = Column(Boolean, default=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    user = relationship("User")


class FruitLeaderboard(Base):
    __tablename__ = "fruit_leaderboards"

    id = Column(Integer, primary_key=True, index=True)
    contest_id = Column(Integer, ForeignKey("fruit_contests.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    score = Column(Integer, nullable=False)
    max_combo = Column(Integer, nullable=False)
    miss_count = Column(Integer, nullable=False)
    rank = Column(Integer, nullable=False)
    prize_amount = Column(Float, default=0.0)
    is_paid = Column(Boolean, default=False)
    paid_at = Column(DateTime, nullable=True)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))

    user = relationship("User")


class ArrowContest(Base):
    __tablename__ = "arrow_contests"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    entry_fee = Column(Float, nullable=False, default=0.0)
    total_slots = Column(Integer, nullable=False)
    joined_slots = Column(Integer, default=0)
    prize_pool = Column(Float, nullable=False, default=0.0)
    status = Column(String, default="UPCOMING")  # UPCOMING, ACTIVE, COMPLETED, CANCELLED
    prize_rules = Column(String, nullable=False)  # JSON string of rank-wise rules
    grid_size = Column(Integer, default=4)  # 4 for 4x4, 5 for 5x5
    duration_seconds = Column(Integer, default=120)
    difficulty = Column(String, nullable=False, default="MEDIUM")
    arrow_count = Column(Integer, nullable=False, default=80)
    start_time = Column(DateTime, nullable=False)
    end_time = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))


class ArrowPuzzleSeed(Base):
    __tablename__ = "arrow_puzzle_seeds"

    id = Column(Integer, primary_key=True, index=True)
    contest_id = Column(Integer, ForeignKey("arrow_contests.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    seed = Column(Integer, nullable=False)
    difficulty = Column(String, nullable=False, default="MEDIUM")
    generated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    user = relationship("User")
    contest = relationship("ArrowContest")


class ArrowGame(Base):
    __tablename__ = "arrow_games"

    id = Column(Integer, primary_key=True, index=True)
    contest_id = Column(Integer, ForeignKey("arrow_contests.id", ondelete="CASCADE"), nullable=False, unique=True)
    layout = Column(String, nullable=False)  # JSON string representing blocks e.g. [{"id": 0, "row": 0, "col": 0, "dir": "UP"}, ...]
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))


class ArrowAttempt(Base):
    __tablename__ = "arrow_attempts"

    id = Column(Integer, primary_key=True, index=True)
    contest_id = Column(Integer, ForeignKey("arrow_contests.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    session_id = Column(String, unique=True, index=True, nullable=False)
    score = Column(Integer, default=0)
    completion_seconds = Column(Float, nullable=False, default=0.0)
    moves = Column(Integer, default=0)  # total taps
    taps_sequence = Column(String, nullable=False, default="[]")  # JSON telemetry
    is_verified = Column(Boolean, default=False)
    device_fingerprint = Column(String, nullable=False)
    ip_address = Column(String, nullable=False)
    status = Column(String, default="IN_PROGRESS")  # IN_PROGRESS, SUBMITTED, VERIFIED, SUSPICIOUS
    started_at = Column(DateTime, nullable=False)
    submitted_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    user = relationship("User")


class ArrowLeaderboard(Base):
    __tablename__ = "arrow_leaderboards"

    id = Column(Integer, primary_key=True, index=True)
    contest_id = Column(Integer, ForeignKey("arrow_contests.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    score = Column(Integer, nullable=False)
    completion_seconds = Column(Float, nullable=False)
    rank = Column(Integer, nullable=False)
    prize_amount = Column(Float, default=0.0)
    is_paid = Column(Boolean, default=False)
    paid_at = Column(DateTime, nullable=True)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))

    user = relationship("User")


class Notification(Base):
    __tablename__ = "notifications"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True)  # Null implies broadcast notification
    title = Column(String, nullable=False)
    body = Column(String, nullable=False)
    data_json = Column(String, nullable=True)  # JSON-serialized metadata
    is_read = Column(Boolean, default=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))


class PortfolioConfig(Base):
    __tablename__ = "portfolio_configs"

    id = Column(Integer, primary_key=True, index=True)
    contact_email = Column(String, nullable=True)
    contact_phone = Column(String, nullable=True)
    contact_address = Column(String, nullable=True)
    office_hours = Column(String, nullable=True)
    apk_link = Column(String, nullable=True)
    telegram_link = Column(String, nullable=True)
    instagram_link = Column(String, nullable=True)
    referral_code = Column(String, nullable=True)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))


class PortfolioContactMessage(Base):
    __tablename__ = "portfolio_contact_messages"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    email = Column(String, nullable=False)
    subject = Column(String, nullable=False)
    message = Column(String, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

