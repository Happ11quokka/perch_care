from pydantic import BaseModel
from datetime import date


class HealthSummaryResponse(BaseModel):
    # 공통 (Free + Premium)
    bhi_score: float | None = None
    wci_level: int = 0
    weight_current: float | None = None
    weight_change_percent: float | None = None
    weight_trend: str = "stable"  # "up" / "down" / "stable"
    has_data: bool = False
    target_date: date

    # Premium 전용 (Free는 null)
    abnormal_count: int | None = None
    food_consistency: float | None = None
    water_consistency: float | None = None
    bhi_trend: str | None = None  # "improving" / "declining" / "stable"
    bhi_previous: float | None = None
