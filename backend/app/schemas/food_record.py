from pydantic import BaseModel
from datetime import date, datetime
from uuid import UUID


class FoodRecordCreate(BaseModel):
    recorded_date: date
    total_grams: float
    target_grams: float
    count: int = 1
    entries_json: str | None = None


class FoodRecordResponse(BaseModel):
    id: UUID
    pet_id: UUID
    recorded_date: date
    total_grams: float
    target_grams: float
    count: int
    entries_json: str | None = None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
