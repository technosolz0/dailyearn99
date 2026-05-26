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

class Contest(Base):
    __tablename__ = "contests"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    entry_fee = Column(Float, nullable=False)
    total_slots = Column(Integer, nullable=False)
    joined_slots = Column(Integer, default=0)
    prize_pool = Column(Float, nullable=False)
    start_time = Column(DateTime, nullable=False)
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

    user = relationship("User", back_populates="participants")
    contest = relationship("Contest", back_populates="participants")

class WalletTransaction(Base):
    __tablename__ = "wallet_transactions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    type = Column(String, nullable=False)  # DEPOSIT, WITHDRAWAL, ENTRY_FEE, PRIZE_WIN, REFERRAL_BONUS
    amount = Column(Float, nullable=False)
    status = Column(String, default="PENDING")  # PENDING, SUCCESS, FAILED
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    user = relationship("User", back_populates="transactions")

class Referral(Base):
    __tablename__ = "referrals"

    id = Column(Integer, primary_key=True, index=True)
    referrer_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    referred_user_id = Column(Integer, ForeignKey("users.id"), unique=True, nullable=False)
    bonus_given = Column(Boolean, default=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
