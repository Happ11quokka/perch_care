from pydantic import BaseModel
from datetime import date, datetime
from uuid import UUID


class DailyRecordCreate(BaseModel):
    recorded_date: date
    notes: str | None = None
    mood: str | None = None
    activity_level: int | None = None


class DailyRecordResponse(BaseModel):
    id: UUID
    pet_id: UUID
    recorded_date: date
    notes: str | None = None
    mood: str | None = None
    activity_level: int | None = None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
