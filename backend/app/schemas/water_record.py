from pydantic import BaseModel
from datetime import date, datetime
from uuid import UUID


class WaterRecordCreate(BaseModel):
    recorded_date: date
    total_ml: float
    target_ml: float
    count: int = 1


class WaterRecordResponse(BaseModel):
    id: UUID
    pet_id: UUID
    recorded_date: date
    total_ml: float
    target_ml: float
    count: int
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
