from pydantic import BaseModel
from datetime import datetime
from uuid import UUID


class SocialAccountResponse(BaseModel):
    id: UUID
    provider: str
    provider_id: str
    provider_email: str | None = None
    created_at: datetime

    model_config = {"from_attributes": True}


class SocialAccountLinkRequest(BaseModel):
    provider: str
    id_token: str | None = None
    provider_id: str | None = None
    provider_email: str | None = None


class ProfileResponse(BaseModel):
    id: UUID
    email: str
    nickname: str | None = None
    avatar_url: str | None = None
    created_at: datetime
    updated_at: datetime
    social_accounts: list[SocialAccountResponse] = []

    model_config = {"from_attributes": True}


class ProfileUpdateRequest(BaseModel):
    nickname: str | None = None
    avatar_url: str | None = None
