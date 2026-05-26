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

class UserResponse(BaseModel):
    id: int
    name: Optional[str] = None
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

    class Config:
        from_attributes = True

class PrizeRuleSchema(BaseModel):
    min_rank: int
    max_rank: int
    prize: float

class ContestCreate(BaseModel):
    title: str
    entry_fee: float
    total_slots: int
    prize_pool: float
    start_time: datetime
    prize_rules: Optional[List[PrizeRuleSchema]] = None

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

class ContestJoinRequest(BaseModel):
    contest_id: int

class SubmitScoreRequest(BaseModel):
    contest_id: int
    score: int

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
