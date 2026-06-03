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
    completed_contest_ids: List[int] = []
    joined_word_contest_ids: List[int] = []
    completed_word_contest_ids: List[int] = []
    joined_puzzle_contest_ids: List[int] = []
    completed_puzzle_contest_ids: List[int] = []
    joined_fruit_contest_ids: List[int] = []
    completed_fruit_contest_ids: List[int] = []
    joined_arrow_contest_ids: List[int] = []
    completed_arrow_contest_ids: List[int] = []

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
    end_time: Optional[datetime] = None
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
    end_time: Optional[datetime] = None
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

class AdminLoginRequest(BaseModel):
    username: str
    password: str


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


class ImagePuzzlePrizeRuleSchema(BaseModel):
    min_rank: int = Field(..., gt=0)
    max_rank: int = Field(..., gt=0)
    prize: float = Field(..., ge=0)


class ImagePuzzleContestCreate(BaseModel):
    title: str = Field(..., min_length=3, max_length=100)
    entry_fee: float = Field(..., ge=0)
    total_slots: int = Field(..., gt=1)
    prize_pool: float = Field(..., ge=0)
    start_time: datetime
    end_time: Optional[datetime] = None
    prize_rules: List[ImagePuzzlePrizeRuleSchema]
    image_url: str
    grid_size: int = Field(3, ge=3, le=5)  # 3 for 3x3, 4 for 4x4, 5 for 5x5
    duration_seconds: int = Field(300, gt=30)


class ImagePuzzleContestResponse(BaseModel):
    id: int
    title: str
    entry_fee: float
    total_slots: int
    joined_slots: int
    prize_pool: float
    start_time: datetime
    end_time: Optional[datetime] = None
    status: str
    prize_rules: Optional[List[ImagePuzzlePrizeRuleSchema]] = None
    image_url: str
    grid_size: int
    duration_seconds: int

    @field_validator("prize_rules", mode="before")
    @classmethod
    def parse_prize_rules(cls, v):
        if isinstance(v, str):
            try:
                return json.loads(v)
            except Exception:
                return []
        return v

    class Config:
        from_attributes = True


class PuzzleStartSessionResponse(BaseModel):
    session_id: str
    shuffled_layout: List[int]  # List of indices e.g. [2, 0, 1, 5, 4, 3, 6, 7, 8]
    started_at: datetime
    grid_size: int
    duration_seconds: int
    image_url: str
    signature: str


class PuzzleMoveTelemetry(BaseModel):
    from_index: int = Field(..., ge=0)
    to_index: int = Field(..., ge=0)
    dt: int = Field(..., ge=0)  # delta milliseconds from started_at


class PuzzleScoreSubmissionRequest(BaseModel):
    contest_id: int
    session_id: str
    completion_seconds: float = Field(..., gt=0)
    moves: int = Field(..., ge=0)
    hints_used: int = Field(..., ge=0)
    telemetry: List[PuzzleMoveTelemetry]
    device_fingerprint: str
    signature: str


class PuzzleLeaderboardItem(BaseModel):
    user_id: int
    name: str
    score: int
    rank: int

    class Config:
        from_attributes = True


class WordPrizeRuleSchema(BaseModel):
    min_rank: int = Field(..., gt=0)
    max_rank: int = Field(..., gt=0)
    prize: float = Field(..., ge=0)


class CreateWordContestRequest(BaseModel):
    title: str = Field(..., min_length=3, max_length=100)
    entry_fee: float = Field(..., ge=0)
    total_slots: int = Field(..., gt=1)
    prize_pool: float = Field(..., ge=0)
    difficulty: str = Field("EASY", description="EASY, MEDIUM, or HARD")
    duration_seconds: int = Field(300, gt=30)
    prize_rules: List[WordPrizeRuleSchema]
    start_time: datetime
    end_time: datetime


class JoinWordContestRequest(BaseModel):
    contest_id: int
    device_fingerprint: str
    ip_address: str


class SubmitWordAnswerRequest(BaseModel):
    session_id: str
    question_id: int
    answer: str
    elapsed_time_seconds: float = Field(..., ge=0)
    time_taken_seconds: float = Field(..., ge=0)
    used_hint: bool
    signature: str
    telemetry: Optional[str] = None  # JSON string representing Keystroke/touch timings


class WordAnswerResponse(BaseModel):
    is_correct: bool
    net_points: int
    accumulated_score: int
    server_elapsed_seconds: float


class WordQuestionResponse(BaseModel):
    id: int
    game_type: str
    puzzle_data: str
    clues: Optional[str] = None
    points_reward: int

    class Config:
        from_attributes = True


class WordLeaderboardItem(BaseModel):
    user_id: int
    name: str
    score: int
    completion_time_seconds: float
    rank: int
    prize_amount: float

    class Config:
        from_attributes = True


class WordContestResponse(BaseModel):
    id: int
    title: str
    entry_fee: float
    total_slots: int
    joined_slots: int
    prize_pool: float
    difficulty: str
    status: str
    prize_rules: Optional[List[WordPrizeRuleSchema]] = None
    duration_seconds: int
    start_time: datetime
    end_time: datetime

    @field_validator("prize_rules", mode="before")
    @classmethod
    def parse_prize_rules(cls, v):
        if isinstance(v, str):
            try:
                return json.loads(v)
            except Exception:
                return []
        return v

    class Config:
        from_attributes = True


class FruitPrizeRuleSchema(BaseModel):
    min_rank: int = Field(..., gt=0)
    max_rank: int = Field(..., gt=0)
    prize: float = Field(..., ge=0)


class FruitContestCreate(BaseModel):
    title: str = Field(..., min_length=3, max_length=100)
    entry_fee: float = Field(..., ge=0)
    total_slots: int = Field(..., gt=1)
    prize_pool: float = Field(..., ge=0)
    start_time: datetime
    end_time: Optional[datetime] = None
    prize_rules: List[FruitPrizeRuleSchema]
    duration_seconds: int = Field(60, gt=10)


class FruitContestResponse(BaseModel):
    id: int
    title: str
    entry_fee: float
    total_slots: int
    joined_slots: int
    prize_pool: float
    start_time: datetime
    end_time: Optional[datetime] = None
    status: str
    prize_rules: Optional[List[FruitPrizeRuleSchema]] = None
    duration_seconds: int
    seed: str

    @field_validator("prize_rules", mode="before")
    @classmethod
    def parse_prize_rules(cls, v):
        if isinstance(v, str):
            try:
                return json.loads(v)
            except Exception:
                return []
        return v

    class Config:
        from_attributes = True


class JoinFruitContestRequest(BaseModel):
    contest_id: int
    device_fingerprint: str
    ip_address: str


class JoinFruitContestResponse(BaseModel):
    session_id: str
    entry_fee_deducted: float
    status: str


class StartFruitContestResponse(BaseModel):
    session_id: str
    seed: str
    duration_seconds: int
    started_at: datetime
    signature: str


class FruitCoordinate(BaseModel):
    x: float
    y: float
    t: Optional[int] = None  # Optional delta ms from start


class FruitSlicedItem(BaseModel):
    id: int
    item_type: str  # e.g., 'apple', 'banana', 'watermelon', 'bomb'
    slice_angle: float


class FruitSwipeTelemetry(BaseModel):
    timestamp_ms: int
    path: List[FruitCoordinate]
    sliced_items: List[FruitSlicedItem]
    is_bomb_hit: bool


class SubmitFruitScoreRequest(BaseModel):
    contest_id: int
    session_id: str
    score: int
    max_combo: int
    miss_count: int
    bomb_hit_count: int
    telemetry: List[FruitSwipeTelemetry]
    signature: str


class FruitLeaderboardItem(BaseModel):
    user_id: int
    name: str
    score: int
    max_combo: int
    miss_count: int
    rank: int
    prize_amount: float

    class Config:
        from_attributes = True


class NotificationResponse(BaseModel):
    id: int
    title: str
    body: str
    data: Optional[dict] = None
    is_read: bool
    created_at: datetime

    class Config:
        from_attributes = True


class ArrowPrizeRuleSchema(BaseModel):
    min_rank: int = Field(..., gt=0)
    max_rank: int = Field(..., gt=0)
    prize: float = Field(..., ge=0)


class ArrowContestCreate(BaseModel):
    title: str = Field(..., min_length=3, max_length=100)
    entry_fee: float = Field(..., ge=0)
    total_slots: int = Field(..., gt=1)
    prize_pool: float = Field(..., ge=0)
    start_time: datetime
    end_time: Optional[datetime] = None
    prize_rules: List[ArrowPrizeRuleSchema]
    grid_size: int = Field(4, ge=3, le=20)  # Support up to 20x20 grid size
    duration_seconds: int = Field(120, gt=10)
    difficulty: str = Field("MEDIUM", description="EASY, MEDIUM, HARD, or EXPERT")
    arrow_count: int = Field(80, ge=1)


class ArrowContestResponse(BaseModel):
    id: int
    title: str
    entry_fee: float
    total_slots: int
    joined_slots: int
    prize_pool: float
    start_time: datetime
    end_time: Optional[datetime] = None
    status: str
    prize_rules: Optional[List[ArrowPrizeRuleSchema]] = None
    grid_size: int
    duration_seconds: int
    difficulty: str
    arrow_count: int

    @field_validator("prize_rules", mode="before")
    @classmethod
    def parse_prize_rules(cls, v):
        if isinstance(v, str):
            try:
                return json.loads(v)
            except Exception:
                return []
        return v

    class Config:
        from_attributes = True


class ArrowStartSessionResponse(BaseModel):
    session_id: str
    layout: List[dict]  # e.g. [{"id": 0, "row": 0, "col": 0, "dir": "UP"}, ...]
    started_at: datetime
    grid_size: int
    duration_seconds: int
    signature: str


class ArrowTapTelemetry(BaseModel):
    block_id: int = Field(..., ge=0)
    dt: int = Field(..., ge=0)  # delta ms from start
    success: bool


class ArrowScoreSubmissionRequest(BaseModel):
    contest_id: int
    session_id: str
    completion_seconds: float = Field(..., gt=0)
    moves: int = Field(..., ge=0)
    telemetry: List[ArrowTapTelemetry]
    device_fingerprint: str
    signature: str


class ArrowLeaderboardItem(BaseModel):
    user_id: int
    name: str
    score: int
    rank: int
    completion_seconds: float

    class Config:
        from_attributes = True







