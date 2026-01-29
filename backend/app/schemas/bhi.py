from pydantic import BaseModel
from datetime import date


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
