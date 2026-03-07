from uuid import UUID
from datetime import date, datetime

from pydantic import BaseModel


class PetInsightResponse(BaseModel):
    id: UUID
    pet_id: UUID
    insight_type: str
    period_start: date
    period_end: date
    summary: str
    key_metrics: dict
    recommendations: list
    language: str
    generated_at: datetime

    model_config = {"from_attributes": True}
