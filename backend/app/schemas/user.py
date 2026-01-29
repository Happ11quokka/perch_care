from pydantic import BaseModel
from datetime import datetime
from uuid import UUID


class ProfileResponse(BaseModel):
    id: UUID
    email: str
    nickname: str | None = None
    avatar_url: str | None = None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class ProfileUpdateRequest(BaseModel):
    nickname: str | None = None
    avatar_url: str | None = None
