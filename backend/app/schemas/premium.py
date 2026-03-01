import re
from datetime import datetime

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
    tier: str
    premium_expires_at: datetime | None = None
