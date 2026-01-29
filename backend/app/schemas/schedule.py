from pydantic import BaseModel
from datetime import datetime
from uuid import UUID


class ScheduleCreate(BaseModel):
    start_time: datetime
    end_time: datetime
    title: str
    description: str | None = None
    color: str = "#FF9A42"
    reminder_minutes: int | None = None


class ScheduleUpdate(BaseModel):
    start_time: datetime | None = None
    end_time: datetime | None = None
    title: str | None = None
    description: str | None = None
    color: str | None = None
    reminder_minutes: int | None = None


class ScheduleResponse(BaseModel):
    id: UUID
    pet_id: UUID
    start_time: datetime
    end_time: datetime
    title: str
    description: str | None = None
    color: str
    reminder_minutes: int | None = None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
