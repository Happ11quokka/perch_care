from pydantic import BaseModel
from datetime import date
from app.schemas.breed_standard import WeightRangeInfo


class BHIResponse(BaseModel):
    bhi_score: float
    weight_score: float
    food_score: float
    water_score: float
    wci_level: int
    growth_stage: str | None = None
    target_date: date
    has_weight_data: bool
    has_food_data: bool
    has_water_data: bool
    # Breed-based weight scoring breakdown
    weight_score_relative: float | None = None
    weight_score_absolute: float | None = None
    breed_weight_info: WeightRangeInfo | None = None
    # Debug fields
    debug_food_total: float | None = None
    debug_food_target: float | None = None
    debug_water_total: float | None = None
    debug_water_target: float | None = None
