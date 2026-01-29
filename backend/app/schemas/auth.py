from pydantic import BaseModel, EmailStr


class SignUpRequest(BaseModel):
    email: str
    password: str
    nickname: str | None = None


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
    authorization_code: str | None = None
    provider: str | None = None
    email: str | None = None


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
