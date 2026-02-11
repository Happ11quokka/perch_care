"""
BHI (Bird Health Index) 계산 서비스

BHI = WeightScore(60) + FoodScore(25) + WaterScore(15) = 0~100

성장 단계별 WeightScore 계산:
  - 청년(adult):      WCI_7 = (W_t - W_{t-7}) / W_{t-7}
                       WeightScore = 60 * (1 - clamp(|WCI_7| / 0.10, 0, 1))
  - 후속성장(post_growth): WCI_7 = (W_t - W_{t-7}) / W_{t-7}
                       WeightScore = 60 * (1 - clamp(|min(WCI_7, 0)| / 0.10, 0, 1))
  - 빠른성장(rapid_growth): WCI_1 = (W_t - W_{t-1}) / W_{t-1}
                       WeightScore = 60 * clamp(min(WCI_1, 0.1) / 0.10, 0, 1)

FoodScore: Δf = (f_t - f0) / f0
           FoodScore = 25 * (1 - clamp(|min(Δf, 0)| / 0.30, 0, 1))

WaterScore: Δd = (d_t - d0) / d0
            WaterScore = 15 * (1 - clamp(|Δd| / 0.40, 0, 1))
"""
from uuid import UUID
from datetime import date, timedelta
from sqlalchemy import select, union_all
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.pet import Pet
from app.models.weight_record import WeightRecord
from app.models.food_record import FoodRecord
from app.models.water_record import WaterRecord
from app.schemas.bhi import BHIResponse


def _clamp(value: float, min_val: float, max_val: float) -> float:
    return max(min_val, min(value, max_val))


def _bhi_to_wci_level(bhi_score: float) -> int:
    """BHI 점수(0~100)를 WCI 레벨(1~5)로 변환. 데이터 없으면 0."""
    if bhi_score <= 0:
        return 0
    if bhi_score <= 20:
        return 1
    if bhi_score <= 40:
        return 2
    if bhi_score <= 60:
        return 3
    if bhi_score <= 80:
        return 4
    return 5


async def _get_weight_on_date(db: AsyncSession, pet_id: UUID, target_date: date) -> float | None:
    """target_date의 체중 기록 반환. 없으면 None."""
    result = await db.execute(
        select(WeightRecord.weight).where(
            WeightRecord.pet_id == pet_id,
            WeightRecord.recorded_date == target_date,
        )
    )
    row = result.scalar_one_or_none()
    return float(row) if row is not None else None


async def _get_weight_near_date(db: AsyncSession, pet_id: UUID, target_date: date, window_days: int = 3) -> float | None:
    """target_date 근처(±window_days) 가장 가까운 체중 기록 반환. 정확한 날짜를 우선."""
    exact = await _get_weight_on_date(db, pet_id, target_date)
    if exact is not None:
        return exact

    # 정확한 날짜에 없으면 ±window_days 범위에서 가장 가까운 기록 (날짜 차이 오름차순)
    start = target_date - timedelta(days=window_days)
    end = target_date + timedelta(days=window_days)
    result = await db.execute(
        select(WeightRecord.weight, WeightRecord.recorded_date)
        .where(
            WeightRecord.pet_id == pet_id,
            WeightRecord.recorded_date >= start,
            WeightRecord.recorded_date <= end,
        )
    )
    rows = result.all()
    if not rows:
        return None

    # 가장 가까운 날짜의 기록 선택
    best = min(rows, key=lambda r: abs((r.recorded_date - target_date).days))
    return float(best.weight)


async def _get_previous_weight(db: AsyncSession, pet_id: UUID, before_date: date) -> float | None:
    """before_date 이전의 가장 최근 체중 기록 반환."""
    result = await db.execute(
        select(WeightRecord.weight)
        .where(
            WeightRecord.pet_id == pet_id,
            WeightRecord.recorded_date < before_date,
        )
        .order_by(WeightRecord.recorded_date.desc())
        .limit(1)
    )
    row = result.scalar_one_or_none()
    return float(row) if row is not None else None


async def _calc_weight_score(db: AsyncSession, pet_id: UUID, target_date: date, growth_stage: str | None) -> tuple[float, bool]:
    """WeightScore 계산. (score, has_data) 반환."""
    import logging
    logger = logging.getLogger(__name__)

    if not growth_stage:
        return 0.0, False

    # 오늘 체중 확인
    w_t = await _get_weight_on_date(db, pet_id, target_date)
    logger.info(f"[BHI DEBUG] weight for {pet_id} on {target_date}: w_t={w_t}")

    if w_t is None:
        return 0.0, False

    if growth_stage in ('adult', 'post_growth'):
        # 7일 기반 WCI (비교 체중은 ±3일 범위에서 탐색)
        w_t7 = await _get_weight_near_date(db, pet_id, target_date - timedelta(days=7), window_days=3)

        # 7일 전 데이터가 없으면 이전 기록 중 가장 최근 것 사용
        if w_t7 is None:
            w_t7 = await _get_previous_weight(db, pet_id, target_date)

        logger.info(f"[BHI DEBUG] weight comparison: w_t={w_t}, w_t7={w_t7}")

        # 비교 체중이 없으면 (첫 기록) 만점 부여
        if w_t7 is None or w_t7 == 0:
            logger.info(f"[BHI DEBUG] weight: first record, giving full score")
            return 60.0, True

        wci_7 = (w_t - w_t7) / w_t7

        if growth_stage == 'adult':
            # 체중 변화의 절대값 기준 (증가/감소 모두 페널티)
            score = 60 * (1 - _clamp(abs(wci_7) / 0.10, 0, 1))
        else:
            # post_growth: 체중 감소만 페널티 (성장 중이므로 증가는 OK)
            score = 60 * (1 - _clamp(abs(min(wci_7, 0)) / 0.10, 0, 1))

        logger.info(f"[BHI DEBUG] weight: wci_7={wci_7:.4f}, score={score:.2f}")
        return score, True

    elif growth_stage == 'rapid_growth':
        # 1일 기반 WCI (비교 체중은 ±1일 범위에서 탐색)
        w_t1 = await _get_weight_near_date(db, pet_id, target_date - timedelta(days=1), window_days=1)

        # 1일 전 데이터가 없으면 이전 기록 사용
        if w_t1 is None:
            w_t1 = await _get_previous_weight(db, pet_id, target_date)

        # 비교 체중이 없으면 (첫 기록) 만점 부여
        if w_t1 is None or w_t1 == 0:
            return 60.0, True

        wci_1 = (w_t - w_t1) / w_t1
        score = 60 * _clamp(min(wci_1, 0.1) / 0.10, 0, 1)
        return score, True

    return 0.0, False


async def _calc_food_score(db: AsyncSession, pet_id: UUID, target_date: date) -> tuple[float, bool, float | None, float | None]:
    """FoodScore 계산. (score, has_data, total, target) 반환."""
    import logging
    logger = logging.getLogger(__name__)

    result = await db.execute(
        select(FoodRecord).where(
            FoodRecord.pet_id == pet_id,
            FoodRecord.recorded_date == target_date,
        )
    )
    record = result.scalar_one_or_none()
    logger.info(f"[BHI DEBUG] food_record for {pet_id} on {target_date}: exists={record is not None}")

    if record is None or record.target_grams == 0:
        logger.info(f"[BHI DEBUG] food: no record or target_grams=0")
        return 0.0, False, None, None

    delta_f = (record.total_grams - record.target_grams) / record.target_grams
    score = 25 * (1 - _clamp(abs(min(delta_f, 0)) / 0.30, 0, 1))
    logger.info(f"[BHI DEBUG] food: total={record.total_grams}, target={record.target_grams}, delta_f={delta_f:.3f}, score={score:.2f}")
    return score, True, float(record.total_grams), float(record.target_grams)


async def _calc_water_score(db: AsyncSession, pet_id: UUID, target_date: date) -> tuple[float, bool, float | None, float | None]:
    """WaterScore 계산. (score, has_data, total, target) 반환."""
    import logging
    logger = logging.getLogger(__name__)

    result = await db.execute(
        select(WaterRecord).where(
            WaterRecord.pet_id == pet_id,
            WaterRecord.recorded_date == target_date,
        )
    )
    record = result.scalar_one_or_none()
    logger.info(f"[BHI DEBUG] water_record for {pet_id} on {target_date}: exists={record is not None}")

    if record is None or record.target_ml == 0:
        logger.info(f"[BHI DEBUG] water: no record or target_ml=0")
        return 0.0, False, None, None

    delta_d = (record.total_ml - record.target_ml) / record.target_ml
    score = 15 * (1 - _clamp(abs(delta_d) / 0.40, 0, 1))
    logger.info(f"[BHI DEBUG] water: total={record.total_ml}, target={record.target_ml}, delta_d={delta_d:.3f}, score={score:.2f}")
    return score, True, float(record.total_ml), float(record.target_ml)


async def _find_latest_record_date(db: AsyncSession, pet_id: UUID, up_to: date) -> date | None:
    """pet_id의 가장 최근 기록 날짜를 반환 (weight/food/water 중 가장 최신)."""
    q_weight = select(WeightRecord.recorded_date.label("d")).where(
        WeightRecord.pet_id == pet_id, WeightRecord.recorded_date <= up_to
    )
    q_food = select(FoodRecord.recorded_date.label("d")).where(
        FoodRecord.pet_id == pet_id, FoodRecord.recorded_date <= up_to
    )
    q_water = select(WaterRecord.recorded_date.label("d")).where(
        WaterRecord.pet_id == pet_id, WaterRecord.recorded_date <= up_to
    )
    combined = union_all(q_weight, q_food, q_water).subquery()
    result = await db.execute(
        select(combined.c.d).order_by(combined.c.d.desc()).limit(1)
    )
    row = result.scalar_one_or_none()
    return row


async def calculate_bhi(db: AsyncSession, pet_id: UUID, target_date: date) -> BHIResponse:
    """주어진 날짜의 BHI 점수를 계산. 해당 날짜에 데이터가 없으면 가장 최근 기록 날짜로 폴백."""
    # 펫 정보 조회
    result = await db.execute(select(Pet).where(Pet.id == pet_id))
    pet = result.scalar_one_or_none()
    if pet is None:
        from fastapi import HTTPException, status
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Pet not found")

    growth_stage = pet.growth_stage or 'adult'

    weight_score, has_weight = await _calc_weight_score(db, pet_id, target_date, growth_stage)
    food_score, has_food, food_total, food_target = await _calc_food_score(db, pet_id, target_date)
    water_score, has_water, water_total, water_target = await _calc_water_score(db, pet_id, target_date)

    effective_date = target_date

    # 요청 날짜에 데이터가 전혀 없으면 가장 최근 기록 날짜로 폴백
    if not has_weight and not has_food and not has_water:
        latest = await _find_latest_record_date(db, pet_id, target_date)
        if latest is not None and latest != target_date:
            effective_date = latest
            weight_score, has_weight = await _calc_weight_score(db, pet_id, effective_date, growth_stage)
            food_score, has_food, food_total, food_target = await _calc_food_score(db, pet_id, effective_date)
            water_score, has_water, water_total, water_target = await _calc_water_score(db, pet_id, effective_date)

    bhi_score = weight_score + food_score + water_score
    wci_level = _bhi_to_wci_level(bhi_score)

    return BHIResponse(
        bhi_score=round(bhi_score, 2),
        weight_score=round(weight_score, 2),
        food_score=round(food_score, 2),
        water_score=round(water_score, 2),
        wci_level=wci_level,
        growth_stage=growth_stage,
        target_date=effective_date,
        has_weight_data=has_weight,
        has_food_data=has_food,
        has_water_data=has_water,
        debug_food_total=food_total,
        debug_food_target=food_target,
        debug_water_total=water_total,
        debug_water_target=water_target,
    )
