from pydantic import BaseModel, Field
from datetime import datetime
from uuid import UUID
from typing import Any, Literal


class ChatSessionCreate(BaseModel):
    pet_id: UUID | None = None
    first_message: str


class ChatSessionResponse(BaseModel):
    id: UUID
    user_id: UUID
    pet_id: UUID | None = None
    title: str
    started_at: datetime
    last_message_at: datetime
    message_count: int
    created_at: datetime

    model_config = {"from_attributes": True}


class ChatSessionListResponse(BaseModel):
    id: UUID
    title: str
    pet_id: UUID | None = None
    last_message_at: datetime
    message_count: int

    model_config = {"from_attributes": True}


class ChatMessageCreate(BaseModel):
    role: Literal["user", "assistant"]
    content: str
    metadata: dict[str, Any] | None = None


class ChatMessageResponse(BaseModel):
    id: UUID
    session_id: UUID
    role: str
    content: str
    metadata: dict[str, Any] | None = Field(default=None, validation_alias="metadata_")
    created_at: datetime

    model_config = {"from_attributes": True}
