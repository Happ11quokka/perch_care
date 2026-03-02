import re
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, field_validator


class PremiumCodeRequest(BaseModel):
    code: str

    @field_validator("code")
    @classmethod
    def validate_code_format(cls, v: str) -> str:
        v = v.strip().upper()
        if not re.match(r"^PERCH-[A-Z0-9]{4}-[A-Z0-9]{4}$", v):
            raise ValueError("코드 형식이 올바르지 않습니다")
        return v


class PremiumCodeResponse(BaseModel):
    success: bool
    expires_at: datetime | None = None


class TierResponse(BaseModel):
    tier: Literal["free", "premium"]
    premium_expires_at: datetime | None = None


# ── Admin: 코드 생성 ──

class GenerateCodesRequest(BaseModel):
    count: int = 1
    duration_days: int = 30

    @field_validator("count")
    @classmethod
    def validate_count(cls, v: int) -> int:
        if v < 1 or v > 50:
            raise ValueError("count는 1~50 사이여야 합니다")
        return v

    @field_validator("duration_days")
    @classmethod
    def validate_duration(cls, v: int) -> int:
        if v < 1 or v > 365:
            raise ValueError("duration_days는 1~365 사이여야 합니다")
        return v


class GeneratedCodeItem(BaseModel):
    code: str
    duration_days: int


class GenerateCodesResponse(BaseModel):
    codes: list[GeneratedCodeItem]


class PremiumCodeListItem(BaseModel):
    code: str
    duration_days: int
    is_used: bool
    used_by_email: str | None = None
    used_by_nickname: str | None = None
    used_at: datetime | None = None
    created_at: datetime


# ── Admin: 사용자 프리미엄 관리 ──

class AdminUserPremiumInfo(BaseModel):
    user_id: str
    email: str
    nickname: str | None = None
    tier: Literal["free", "premium"]
    premium_started_at: datetime | None = None
    premium_expires_at: datetime | None = None
    activated_code: str | None = None


class RevokeResponse(BaseModel):
    success: bool
    message: str


class DeleteCodeResponse(BaseModel):
    success: bool
    message: str
