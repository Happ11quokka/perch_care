"""건강 변화 요약 서비스 — 체중/BHI/이상 소견/급여 일관성 집계."""
from uuid import UUID
from datetime import date, timedelta

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.weight_record import WeightRecord
from app.models.food_record import FoodRecord
from app.models.water_record import WaterRecord
from app.models.ai_health_check import AiHealthCheck
from app.services.bhi_service import calculate_bhi, _get_weight_near_date
from app.schemas.health_summary import HealthSummaryResponse


def _weight_trend(change_pct: float | None) -> str:
    if change_pct is None:
        return "stable"
    if change_pct > 1.0:
        return "up"
    if change_pct < -1.0:
        return "down"
    return "stable"


def _bhi_trend_label(current: float | None, previous: float | None) -> str | None:
    if current is None or previous is None:
        return None
    diff = current - previous
    if diff > 3:
        return "improving"
    if diff < -3:
        return "declining"
    return "stable"


async def _count_abnormals(db: AsyncSession, pet_id: UUID, since: date) -> int:
    result = await db.execute(
        select(func.count()).where(
            AiHealthCheck.pet_id == pet_id,
            AiHealthCheck.status != "normal",
            AiHealthCheck.checked_at >= since,
        )
    )
    return result.scalar_one() or 0


async def _calc_consistency(
    db: AsyncSession, pet_id: UUID, model, date_col, since: date, until: date,
) -> float:
    """기간 내 기록 존재 일수 / 전체 일수 비율 (0~100)."""
    total_days = (until - since).days + 1
    if total_days <= 0:
        return 0.0
    result = await db.execute(
        select(func.count(func.distinct(date_col))).where(
            model.pet_id == pet_id,
            date_col >= since,
            date_col <= until,
        )
    )
    recorded_days = result.scalar_one() or 0
    return round(recorded_days / total_days * 100, 1)


async def get_health_summary(
    db: AsyncSession, pet_id: UUID, tier: str, target_date: date,
) -> HealthSummaryResponse:
    # 현재 BHI 계산
    bhi = await calculate_bhi(db, pet_id, target_date)

    # 현재 체중
    weight_current = await _get_weight_near_date(db, pet_id, target_date)

    # 7일 전 체중 비교
    weight_prev = await _get_weight_near_date(
        db, pet_id, target_date - timedelta(days=7),
    )
    weight_change_pct: float | None = None
    if weight_current and weight_prev and weight_prev > 0:
        weight_change_pct = round(
            (weight_current - weight_prev) / weight_prev * 100, 1,
        )

    has_data = bhi.has_weight_data or bhi.has_food_data or bhi.has_water_data

    # 기본 응답 (Free + Premium 공통)
    resp = HealthSummaryResponse(
        bhi_score=bhi.bhi_score if has_data else None,
        wci_level=bhi.wci_level,
        weight_current=weight_current,
        weight_change_percent=weight_change_pct,
        weight_trend=_weight_trend(weight_change_pct),
        has_data=has_data,
        target_date=bhi.target_date,
    )

    # Premium 전용 상세 필드
    if tier == "premium":
        since_30d = target_date - timedelta(days=30)

        resp.abnormal_count = await _count_abnormals(db, pet_id, since_30d)
        resp.food_consistency = await _calc_consistency(
            db, pet_id, FoodRecord, FoodRecord.recorded_date, since_30d, target_date,
        )
        resp.water_consistency = await _calc_consistency(
            db, pet_id, WaterRecord, WaterRecord.recorded_date, since_30d, target_date,
        )

        # 7일 전 BHI로 추세 계산
        bhi_prev = await calculate_bhi(db, pet_id, target_date - timedelta(days=7))
        prev_has = bhi_prev.has_weight_data or bhi_prev.has_food_data or bhi_prev.has_water_data
        resp.bhi_previous = bhi_prev.bhi_score if prev_has else None
        resp.bhi_trend = _bhi_trend_label(
            bhi.bhi_score if has_data else None,
            resp.bhi_previous,
        )

    return resp
