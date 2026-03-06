from pydantic import BaseModel
from uuid import UUID
from datetime import datetime


class BreedStandardResponse(BaseModel):
    id: UUID
    species_category: str
    breed_name_en: str
    breed_name_ko: str
    breed_name_zh: str
    breed_variant: str | None = None
    weight_min_g: float
    weight_ideal_min_g: float
    weight_ideal_max_g: float
    weight_max_g: float
    environment: str
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class BreedStandardListItem(BaseModel):
    """Localized breed list item for selection UI."""
    id: UUID
    display_name: str
    species_category: str
    breed_variant: str | None = None
    weight_min_g: float
    weight_ideal_min_g: float
    weight_ideal_max_g: float
    weight_max_g: float


class WeightRangeInfo(BaseModel):
    """Weight range position info for display."""
    min_g: float
    ideal_min_g: float
    ideal_max_g: float
    max_g: float
    current_position: str  # "below_min", "below_ideal", "in_ideal", "above_ideal", "above_max"
    current_percentage: float  # 0-100 where current weight falls in min-max range
