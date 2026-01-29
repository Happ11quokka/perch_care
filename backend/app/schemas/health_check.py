from pydantic import BaseModel
from datetime import datetime
from uuid import UUID
from typing import Any


class HealthCheckCreate(BaseModel):
    check_type: str
    image_url: str | None = None
    result: dict[str, Any] = {}
    confidence_score: float | None = None
    status: str = "normal"
    checked_at: datetime


class HealthCheckResponse(BaseModel):
    id: UUID
    pet_id: UUID
    check_type: str
    image_url: str | None = None
    result: dict[str, Any]
    confidence_score: float | None = None
    status: str
    checked_at: datetime
    created_at: datetime

    model_config = {"from_attributes": True}
