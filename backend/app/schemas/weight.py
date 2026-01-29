from pydantic import BaseModel
from datetime import date, datetime
from uuid import UUID


class WeightRecordCreate(BaseModel):
    recorded_date: date
    weight: float
    memo: str | None = None


class WeightRecordResponse(BaseModel):
    id: UUID
    pet_id: UUID
    recorded_date: date
    weight: float
    memo: str | None = None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class MonthlyAverage(BaseModel):
    month: int
    avg_weight: float


class WeeklyData(BaseModel):
    recorded_date: date
    weight: float
