from pydantic import BaseModel
from datetime import datetime
from uuid import UUID


class NotificationCreate(BaseModel):
    pet_id: UUID | None = None
    type: str
    title: str
    message: str = ""


class NotificationResponse(BaseModel):
    id: UUID
    user_id: UUID
    pet_id: UUID | None = None
    type: str
    title: str
    message: str
    is_read: bool
    created_at: datetime

    model_config = {"from_attributes": True}


class UnreadCountResponse(BaseModel):
    count: int
