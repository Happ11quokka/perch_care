from enum import Enum

from pydantic import BaseModel
from datetime import datetime
from uuid import UUID
from typing import Any


class VisionMode(str, Enum):
    full_body = "full_body"
    part_specific = "part_specific"
    droppings = "droppings"
    food = "food"


class VisionPart(str, Enum):
    eye = "eye"
    beak = "beak"
    feather = "feather"
    foot = "foot"


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


class VisionAnalyzeResponse(BaseModel):
    id: UUID
    pet_id: UUID
    check_type: str
    result: dict[str, Any]
    confidence_score: float | None = None
    status: str
    checked_at: datetime
    created_at: datetime

    model_config = {"from_attributes": True}
