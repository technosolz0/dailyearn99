from pydantic import BaseModel, Field, field_validator
from datetime import datetime, timezone
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
    device_details: Optional[str] = None

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
    device_details: Optional[str] = None
    last_login: Optional[datetime] = None
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

    @field_validator("last_login", mode="after", check_fields=False)
    @classmethod
    def make_utc(cls, v):
        if v and v.tzinfo is None:
            return v.replace(tzinfo=timezone.utc)
        return v

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

    @field_validator("start_time", "end_time", mode="after", check_fields=False)
    @classmethod
    def make_utc(cls, v):
        if v and v.tzinfo is None:
            return v.replace(tzinfo=timezone.utc)
        return v

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
    description: Optional[str] = None
    created_at: datetime

    @field_validator("created_at", mode="after", check_fields=False)
    @classmethod
    def make_utc(cls, v):
        if v and v.tzinfo is None:
            return v.replace(tzinfo=timezone.utc)
        return v

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

    @field_validator("created_at", mode="after", check_fields=False)
    @classmethod
    def make_utc(cls, v):
        if v and v.tzinfo is None:
            return v.replace(tzinfo=timezone.utc)
        return v

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

class RTPCreateRequest(BaseModel):
    min_amount: float
    max_amount: float
    probability_json: str
    enabled: bool = True

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
    user_name: Optional[str] = None
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

    @field_validator("start_time", "end_time", mode="after", check_fields=False)
    @classmethod
    def make_utc(cls, v):
        if v and v.tzinfo is None:
            return v.replace(tzinfo=timezone.utc)
        return v

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

    @field_validator("started_at", mode="after", check_fields=False)
    @classmethod
    def make_utc(cls, v):
        if v and v.tzinfo is None:
            return v.replace(tzinfo=timezone.utc)
        return v


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


class JoinPuzzleContestRequest(BaseModel):
    contest_id: int
    device_fingerprint: str
    ip_address: str


class JoinArrowContestRequest(BaseModel):
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

    @field_validator("start_time", "end_time", mode="after", check_fields=False)
    @classmethod
    def make_utc(cls, v):
        if v and v.tzinfo is None:
            return v.replace(tzinfo=timezone.utc)
        return v

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

    @field_validator("start_time", "end_time", mode="after", check_fields=False)
    @classmethod
    def make_utc(cls, v):
        if v and v.tzinfo is None:
            return v.replace(tzinfo=timezone.utc)
        return v

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

    @field_validator("started_at", mode="after", check_fields=False)
    @classmethod
    def make_utc(cls, v):
        if v and v.tzinfo is None:
            return v.replace(tzinfo=timezone.utc)
        return v


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

    @field_validator("start_time", "end_time", mode="after", check_fields=False)
    @classmethod
    def make_utc(cls, v):
        if v and v.tzinfo is None:
            return v.replace(tzinfo=timezone.utc)
        return v

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

    @field_validator("started_at", mode="after", check_fields=False)
    @classmethod
    def make_utc(cls, v):
        if v and v.tzinfo is None:
            return v.replace(tzinfo=timezone.utc)
        return v


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


class AdminBankDetailBase(BaseModel):
    bank_name: str
    account_holder_name: str
    account_number: str
    ifsc_code: str
    upi_id: Optional[str] = None
    is_default: bool = False
    target_user_ids: Optional[str] = None

class AdminBankDetailCreate(AdminBankDetailBase):
    pass

class AdminBankDetailUpdate(AdminBankDetailBase):
    pass

class AdminBankDetailResponse(AdminBankDetailBase):
    id: int
    created_at: datetime

    class Config:
        from_attributes = True


class PortfolioConfigResponse(BaseModel):
    id: int
    contact_email: Optional[str] = None
    contact_phone: Optional[str] = None
    contact_address: Optional[str] = None
    office_hours: Optional[str] = None
    apk_link: Optional[str] = None
    telegram_link: Optional[str] = None
    instagram_link: Optional[str] = None
    referral_code: Optional[str] = None
    add_amount_method: Optional[str] = "UPI"
    admin_upi_id: Optional[str] = None
    admin_bank_holder: Optional[str] = None
    admin_bank_name: Optional[str] = None
    admin_bank_account: Optional[str] = None
    admin_bank_ifsc: Optional[str] = None
    updated_at: datetime

    class Config:
        from_attributes = True


class PortfolioConfigUpdate(BaseModel):
    contact_email: str
    contact_phone: str
    contact_address: str
    office_hours: str
    apk_link: str
    telegram_link: Optional[str] = None
    instagram_link: Optional[str] = None
    referral_code: str
    add_amount_method: str = "UPI"
    admin_upi_id: Optional[str] = None
    admin_bank_holder: Optional[str] = None
    admin_bank_name: Optional[str] = None
    admin_bank_account: Optional[str] = None
    admin_bank_ifsc: Optional[str] = None


class PortfolioContactMessageCreate(BaseModel):
    name: str = Field(..., min_length=1)
    email: str = Field(..., min_length=1)
    subject: str = Field(..., min_length=1)
    message: str = Field(..., min_length=1)


class PortfolioContactMessageResponse(BaseModel):
    id: int
    name: str
    email: str
    subject: str
    message: str
    created_at: datetime

    class Config:
        from_attributes = True


class LotteryDrawCreate(BaseModel):
    title: str
    ticket_price: float
    prize_pool: float
    draw_time: datetime
    max_tickets: Optional[int] = 10000000
    win_percentage: Optional[float] = 0.01
    forced_winning_number: Optional[str] = None


class LotteryDrawResponse(BaseModel):
    id: int
    title: str
    ticket_price: float
    prize_pool: float
    draw_time: datetime
    max_tickets: int
    joined_tickets: int
    status: str
    winning_number: Optional[str] = None
    win_percentage: float
    forced_winning_number: Optional[str] = None
    created_at: datetime

    @field_validator("draw_time", "created_at", mode="after", check_fields=False)
    @classmethod
    def make_utc(cls, v):
        if v and v.tzinfo is None:
            return v.replace(tzinfo=timezone.utc)
        return v

    class Config:
        from_attributes = True


class LotteryTicketBuyRequest(BaseModel):
    draw_id: int


class LotteryTicketResponse(BaseModel):
    id: int
    user_id: int
    draw_id: int
    ticket_number: str
    purchase_time: datetime
    is_winner: bool
    reward_amount: float
    draw_title: Optional[str] = None
    draw_status: Optional[str] = None

    @field_validator("purchase_time", mode="after", check_fields=False)
    @classmethod
    def make_utc(cls, v):
        if v and v.tzinfo is None:
            return v.replace(tzinfo=timezone.utc)
        return v

    class Config:
        from_attributes = True


class MinesStartRequest(BaseModel):
    bet_amount: float = Field(..., gt=0, description="Bet amount in INR")
    mines_count: int = Field(..., ge=1, le=24, description="Number of mines on the board")


class MinesRevealRequest(BaseModel):
    game_id: int
    position: int = Field(..., ge=0, le=24, description="Index of cell clicked [0-24]")


class MinesCashoutRequest(BaseModel):
    game_id: int


class MinesGameResponse(BaseModel):
    id: int
    bet_amount: float
    mines_count: int
    revealed_positions: List[int]
    current_multiplier: float
    current_win: float
    status: str
    created_at: datetime
    mines_positions: Optional[List[int]] = None
    updated_balance: Optional[float] = None

    @field_validator("created_at", mode="after", check_fields=False)
    @classmethod
    def make_utc(cls, v):
        if v and v.tzinfo is None:
            return v.replace(tzinfo=timezone.utc)
        return v

    @field_validator("revealed_positions", mode="before")
    @classmethod
    def parse_revealed_positions(cls, v):
        if isinstance(v, str):
            try:
                return json.loads(v)
            except Exception:
                return []
        return v

    @field_validator("mines_positions", mode="before")
    @classmethod
    def parse_mines_positions(cls, v):
        if isinstance(v, str):
            try:
                return json.loads(v)
            except Exception:
                return []
        return v

    class Config:
        from_attributes = True


class MinesSettingsResponse(BaseModel):
    house_edge: float
    min_bet: float
    max_bet: float
    maintenance_mode: bool
    
    class Config:
        from_attributes = True


class MinesSettingsUpdateRequest(BaseModel):
    house_edge: float = Field(..., ge=0.0, le=0.5)
    min_bet: float = Field(..., gt=0)
    max_bet: float = Field(..., gt=0)
    maintenance_mode: bool


class MinesStatsResponse(BaseModel):
    total_games: int
    total_winnings_paid: float
    total_bet_amount: float
    platform_net_profit: float
    payout_ratio: float


class MinesLogAdminResponse(BaseModel):
    id: int
    user_id: int
    user_phone: str
    user_name: Optional[str] = None
    bet_amount: float
    mines_count: int
    multiplier: float
    win_amount: float
    result_type: str
    created_at: datetime
    win_probability: Optional[float] = None

    class Config:
        from_attributes = True


class PlinkoPlayRequest(BaseModel):
    bet_amount: float = Field(..., gt=0, description="Bet amount in INR")
    rows: int = Field(..., ge=10, le=16, description="Number of rows [10-16]")
    mode: str = Field(..., description="Risk mode: low, medium, high")


class PlinkoPlayResponse(BaseModel):
    id: int
    bet_amount: float
    rows: int
    mode: str
    path: List[int]
    final_bucket: int
    multiplier: float
    win_amount: float
    created_at: datetime
    updated_balance: float

    @field_validator("created_at", mode="after", check_fields=False)
    @classmethod
    def make_utc(cls, v):
        if v and v.tzinfo is None:
            return v.replace(tzinfo=timezone.utc)
        return v

    @field_validator("path", mode="before")
    @classmethod
    def parse_path(cls, v):
        if isinstance(v, str):
            try:
                return json.loads(v)
            except Exception:
                return []
        return v

    class Config:
        from_attributes = True


class PlinkoSettingsResponse(BaseModel):
    min_bet: float
    max_bet: float
    maintenance_mode: bool

    class Config:
        from_attributes = True


class PlinkoSettingsUpdateRequest(BaseModel):
    min_bet: float = Field(..., gt=0)
    max_bet: float = Field(..., gt=0)
    maintenance_mode: bool


class PlinkoStatsResponse(BaseModel):
    total_games: int
    total_winnings_paid: float
    total_bet_amount: float
    platform_net_profit: float
    payout_ratio: float


class PlinkoLogAdminResponse(BaseModel):
    id: int
    user_id: int
    user_phone: str
    user_name: Optional[str] = None
    bet_amount: float
    rows: int
    mode: str
    multiplier: float
    win_amount: float
    created_at: datetime
    win_probability: Optional[float] = None

    class Config:
        from_attributes = True


class PlinkoMultiplierResponse(BaseModel):
    id: int
    rows: int
    mode: str
    multipliers_json: str

    class Config:
        from_attributes = True


class PlinkoMultiplierUpdateRequest(BaseModel):
    rows: int = Field(..., ge=10, le=16)
    mode: str
    multipliers_json: str


class PlinkoRTPResponse(BaseModel):
    id: int
    min_amount: float
    max_amount: float
    rows: int
    mode: str
    probability_json: str
    enabled: bool

    class Config:
        from_attributes = True


class PlinkoRTPCreateRequest(BaseModel):
    min_amount: float = Field(..., ge=0)
    max_amount: float = Field(..., ge=0)
    rows: int = Field(..., ge=10, le=16)
    mode: str
    probability_json: str
    enabled: bool = True


class PlinkoRTPUpdateRequest(BaseModel):
    probability_json: str
    enabled: bool


class MinesRTPResponse(BaseModel):
    id: int
    min_amount: float
    max_amount: float
    win_rate: float
    enabled: bool

    class Config:
        from_attributes = True


class MinesRTPCreateRequest(BaseModel):
    min_amount: float = Field(..., ge=0)
    max_amount: float = Field(..., ge=0)
    win_rate: float = Field(..., ge=0.0, le=1.0)
    enabled: bool = True


class MinesRTPUpdateRequest(BaseModel):
    min_amount: float = Field(..., ge=0)
    max_amount: float = Field(..., ge=0)
    win_rate: float = Field(..., ge=0.0, le=1.0)
    enabled: bool


class UserGameLogItem(BaseModel):
    game_type: str
    game_id: int
    title: str
    bet_amount: float
    win_amount: float
    multiplier: Optional[float] = None
    status: str
    details: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


class FruitGameStartRequest(BaseModel):
    bet_amount: float = Field(..., gt=0)


class FruitGameResponse(BaseModel):
    id: int
    user_id: int
    bet_amount: float
    status: str
    current_multiplier: float
    win_amount: float
    created_at: datetime
    updated_balance: Optional[float] = None
    signature: Optional[str] = None


    @field_validator("created_at", mode="after", check_fields=False)
    @classmethod
    def make_utc(cls, v):
        if v and v.tzinfo is None:
            return v.replace(tzinfo=timezone.utc)
        return v

    class Config:
        from_attributes = True


class FruitSettingsResponse(BaseModel):
    min_bet: float
    max_bet: float
    maintenance_mode: bool
    winning_percentage: float
    multipliers_json: str

    class Config:
        from_attributes = True


class FruitSettingsUpdateRequest(BaseModel):
    min_bet: float = Field(..., gt=0)
    max_bet: float = Field(..., gt=0)
    maintenance_mode: bool
    winning_percentage: float = Field(..., ge=0.0, le=100.0)
    multipliers_json: str


class FruitLogAdminResponse(BaseModel):
    id: int
    user_id: int
    user_phone: str
    user_name: Optional[str] = None
    bet_amount: float
    multiplier: float
    win_amount: float
    status: str
    created_at: datetime

    class Config:
        from_attributes = True


class BlackjackStartRequest(BaseModel):
    bet_amount: float = Field(..., gt=0, description="Bet amount in INR")


class BlackjackGameResponse(BaseModel):
    id: int
    user_id: int
    bet_amount: float
    is_split: bool
    split_bet_amount: float
    player_hand_1: List[dict]
    player_hand_2: List[dict]
    dealer_hand: List[dict]
    current_hand_index: int
    hand_1_status: str
    hand_2_status: str
    status: str
    win_amount: float
    created_at: datetime
    updated_balance: Optional[float] = None

    @field_validator("created_at", mode="after", check_fields=False)
    @classmethod
    def make_utc(cls, v):
        if v and v.tzinfo is None:
            return v.replace(tzinfo=timezone.utc)
        return v

    @field_validator("player_hand_1", "player_hand_2", "dealer_hand", mode="before")
    @classmethod
    def parse_hands(cls, v):
        if isinstance(v, str):
            try:
                return json.loads(v)
            except Exception:
                return []
        return v

    class Config:
        from_attributes = True


class BlackjackSettingsResponse(BaseModel):
    min_bet: float
    max_bet: float
    winning_percentage: float
    maintenance_mode: bool

    class Config:
        from_attributes = True


class BlackjackSettingsUpdateRequest(BaseModel):
    min_bet: float = Field(..., gt=0)
    max_bet: float = Field(..., gt=0)
    winning_percentage: float = Field(..., ge=0.0, le=100.0)
    maintenance_mode: bool


class BlackjackStatsResponse(BaseModel):
    total_games: int
    total_winnings_paid: float
    total_bet_amount: float
    platform_net_profit: float
    payout_ratio: float


class BlackjackLogAdminResponse(BaseModel):
    id: int
    user_id: int
    user_phone: str
    user_name: Optional[str] = None
    bet_amount: float
    multiplier: float
    win_amount: float
    status: str
    created_at: datetime
    win_probability: Optional[float] = None

    class Config:
        from_attributes = True













