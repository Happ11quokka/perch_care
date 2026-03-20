import re
from pydantic import BaseModel, EmailStr, field_validator


def _validate_password_strength(password: str) -> str:
    if len(password) < 8:
        raise ValueError("Password must be at least 8 characters")
    if not re.search(r"[A-Za-z]", password):
        raise ValueError("Password must contain at least one letter")
    if not re.search(r"[0-9]", password):
        raise ValueError("Password must contain at least one digit")
    return password


class SignUpRequest(BaseModel):
    email: str
    password: str
    nickname: str | None = None

    @field_validator("password")
    @classmethod
    def check_password(cls, v: str) -> str:
        return _validate_password_strength(v)


class LoginRequest(BaseModel):
    email: str
    password: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class RefreshRequest(BaseModel):
    refresh_token: str


class OAuthRequest(BaseModel):
    id_token: str | None = None
    access_token: str | None = None
    authorization_code: str | None = None
    provider: str | None = None
    email: str | None = None
    user_identifier: str | None = None  # Apple userIdentifier
    full_name: str | None = None  # Apple fullName (첫 로그인 시에만 제공됨)


class OAuthLoginResponse(BaseModel):
    status: str  # "authenticated" or "signup_required"
    access_token: str | None = None
    refresh_token: str | None = None
    token_type: str | None = None
    provider: str | None = None
    provider_id: str | None = None
    provider_email: str | None = None


class ResetPasswordRequest(BaseModel):
    email: str


class VerifyResetCodeRequest(BaseModel):
    email: str | None = None
    code: str


class UpdatePasswordRequest(BaseModel):
    email: str | None = None
    code: str
    new_password: str

    @field_validator("new_password")
    @classmethod
    def check_password(cls, v: str) -> str:
        return _validate_password_strength(v)
