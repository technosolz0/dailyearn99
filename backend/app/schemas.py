from pydantic import BaseModel, Field, field_validator
from datetime import datetime
from typing import List, Optional
import json

class Token(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str

class TokenRefreshRequest(BaseModel):
    refresh_token: str

class SendOTPRequest(BaseModel):
    phone: str = Field(..., description="10-digit mobile number")

class VerifyOTPRequest(BaseModel):
    id_token: str
    referred_by: Optional[str] = None  # Optional referral code during registration
    first_name: Optional[str] = None
    last_name: Optional[str] = None

class UserResponse(BaseModel):
    id: int
    name: Optional[str] = None
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    phone: str
    email: Optional[str] = None
    referral_code: str
    referred_by: Optional[str] = None
    deposit_balance: float
    winning_balance: float
    bonus_balance: float
    kyc_status: str
    is_banned: bool
    fcm_token: Optional[str] = None
    bank_account_number: Optional[str] = None
    bank_ifsc_code: Optional[str] = None
    bank_account_holder_name: Optional[str] = None
    bank_name: Optional[str] = None
    joined_contest_ids: List[int] = []

    class Config:
        from_attributes = True

class PrizeRuleSchema(BaseModel):
    min_rank: int
    max_rank: int
    prize: float

class QuestionSchema(BaseModel):
    text: str
    options: List[str]
    correct_answer_index: int

class ContestCreate(BaseModel):
    title: str
    entry_fee: float
    total_slots: int
    prize_pool: float
    start_time: datetime
    prize_rules: Optional[List[PrizeRuleSchema]] = None
    questions: Optional[List[QuestionSchema]] = None

class ContestResponse(BaseModel):
    id: int
    title: str
    entry_fee: float
    total_slots: int
    joined_slots: int
    prize_pool: float
    start_time: datetime
    status: str
    prize_rules: Optional[List[PrizeRuleSchema]] = None
    questions: Optional[List[QuestionSchema]] = None

    @field_validator("prize_rules", mode="before")
    @classmethod
    def parse_prize_rules(cls, v):
        if isinstance(v, str):
            try:
                return json.loads(v)
            except Exception:
                return []
        return v

    @field_validator("questions", mode="before")
    @classmethod
    def parse_questions(cls, v):
        if isinstance(v, str):
            try:
                return json.loads(v)
            except Exception:
                return []
        return v

    class Config:
        from_attributes = True

class ContestJoinRequest(BaseModel):
    contest_id: int

class SubmitScoreRequest(BaseModel):
    contest_id: int
    score: int
    answers: Optional[List[int]] = None

class LeaderboardItem(BaseModel):
    user_id: int
    name: str
    score: int
    rank: int

    class Config:
        from_attributes = True

class TransactionResponse(BaseModel):
    id: int
    user_id: int
    type: str
    amount: float
    status: str
    utr: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True

class SaveBankDetailsRequest(BaseModel):
    account_number: str = Field(..., min_length=9, max_length=18)
    ifsc_code: str = Field(..., min_length=11, max_length=11)
    account_holder_name: str = Field(..., min_length=2)
    bank_name: str = Field(..., min_length=2)

class DepositRequest(BaseModel):
    amount: float = Field(..., gt=0)
    utr: Optional[str] = None

class WithdrawalRequest(BaseModel):
    amount: float = Field(..., gt=0)
    pan: str = Field(..., description="PAN card number for tax/legal validation")

class ReferralHistoryItem(BaseModel):
    referred_user_name: str
    referred_user_phone: str
    bonus_given: bool
    created_at: datetime

class ReferralDetailsResponse(BaseModel):
    referral_code: str
    referral_count: int
    bonus_earned: float
    referrals: List[ReferralHistoryItem]

class AdminStatsResponse(BaseModel):
    total_users: int
    total_revenue: float
    total_deposits: float
    total_winnings_paid: float
    active_contests: int

class FCMTokenRequest(BaseModel):
    fcm_token: str

class SendUserNotificationRequest(BaseModel):
    user_id: int
    title: str
    body: str

class SendAllNotificationRequest(BaseModel):
    title: str
    body: str

class AdminAdjustBalanceRequest(BaseModel):
    amount: float
    wallet_type: str = Field(..., description="'deposit', 'winning', or 'bonus'")

class RazorpayCreateOrderRequest(BaseModel):
    amount: float = Field(..., gt=0)

class RazorpayVerifyPaymentRequest(BaseModel):
    razorpay_order_id: str
    razorpay_payment_id: str
    razorpay_signature: str
    amount: float

class SpinCreateRequest(BaseModel):
    bet_amount: float = Field(..., gt=0, description="Bet amount in INR")
    idempotency_key: str = Field(..., description="Unique UUID to prevent duplicate spins")
    device_id: Optional[str] = None

class SpinResponse(BaseModel):
    id: int
    bet_amount: float
    multiplier: float
    win_amount: float
    result_type: str
    wheel_segment: str
    segment_index: int
    created_at: datetime
    updated_balance: float

    class Config:
        from_attributes = True

class RTPSettingsResponse(BaseModel):
    id: int
    min_amount: float
    max_amount: float
    probability_json: str
    enabled: bool

    class Config:
        from_attributes = True

class RTPUpdateRequest(BaseModel):
    probability_json: str
    enabled: bool

class SpinStatsResponse(BaseModel):
    total_spins: int
    total_winnings_paid: float
    total_bet_amount: float
    platform_net_profit: float
    payout_ratio: float

class SpinLogAdminResponse(BaseModel):
    id: int
    user_id: int
    user_phone: str
    bet_amount: float
    multiplier: float
    win_amount: float
    result_type: str
    wheel_segment: str
    created_at: datetime

    class Config:
        from_attributes = True

class SuspiciousUserResponse(BaseModel):
    user_id: int
    name: Optional[str]
    phone: str
    total_spins: int
    win_count: int
    win_ratio: float
    total_bet: float
    total_win: float


