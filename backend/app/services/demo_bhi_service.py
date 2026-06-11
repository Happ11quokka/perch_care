"""웹 데모용 BHI 순수 계산 서비스.

bhi_service.py의 수식을 DB 조회 없이 입력값만으로 계산한다.
완화 상수(food 0.50, water 0.60)는 bhi_service 코드 기준과 동일.

BHI = WeightScore(60) + FoodScore(25) + WaterScore(15) = 0~100

성장 단계별 WeightScore:
  - adult:        WCI = (W_t - W_baseline) / W_baseline
                  WeightScore = 60 * (1 - clamp(|WCI| / 0.10, 0, 1))
  - post_growth:  WeightScore = 60 * (1 - clamp(|min(WCI, 0)| / 0.10, 0, 1))
  - rapid_growth: WeightScore = 60 * clamp(min(WCI, 0.1) / 0.10, 0, 1)
  - baseline None/0 이하 → 60.0 (만점 기본값, bhi_service의 데이터 없음 처리와 동일)

FoodScore:  Δf = (total - target) / target
            FoodScore = 25 * (1 - clamp(|min(Δf, 0)| / 0.50, 0, 1))   # target ≤ 0 → 0
WaterScore: Δd = (total - target) / target
            WaterScore = 15 * (1 - clamp(|Δd| / 0.60, 0, 1))          # target ≤ 0 → 0
"""


def _clamp(value: float, min_val: float, max_val: float) -> float:
    return max(min_val, min(value, max_val))


def _bhi_to_wci_level(bhi_score: float) -> int:
    """BHI 점수(0~100)를 WCI 레벨(1~5)로 변환. 0 이하면 0 (bhi_service와 동일 밴드)."""
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


def _calc_weight_score(growth_stage: str, weight_today_g: float, weight_baseline_g: float | None) -> float:
    """WeightScore 계산 (0-60). baseline 없으면 만점 기본값."""
    if weight_baseline_g is None or weight_baseline_g <= 0:
        return 60.0

    wci = (weight_today_g - weight_baseline_g) / weight_baseline_g

    if growth_stage == "adult":
        return 60 * (1 - _clamp(abs(wci) / 0.10, 0, 1))
    if growth_stage == "post_growth":
        return 60 * (1 - _clamp(abs(min(wci, 0)) / 0.10, 0, 1))
    # rapid_growth
    return 60 * _clamp(min(wci, 0.1) / 0.10, 0, 1)


def _calc_food_score(food_total_g: float, food_target_g: float) -> float:
    """FoodScore 계산 (0-25). target ≤ 0이면 0."""
    if food_target_g <= 0:
        return 0.0
    delta_f = (food_total_g - food_target_g) / food_target_g
    return 25 * (1 - _clamp(abs(min(delta_f, 0)) / 0.50, 0, 1))


def _calc_water_score(water_total_ml: float, water_target_ml: float) -> float:
    """WaterScore 계산 (0-15). target ≤ 0이면 0."""
    if water_target_ml <= 0:
        return 0.0
    delta_d = (water_total_ml - water_target_ml) / water_target_ml
    return 15 * (1 - _clamp(abs(delta_d) / 0.60, 0, 1))


def calculate_demo_bhi(
    growth_stage: str,
    weight_today_g: float,
    weight_baseline_g: float | None,
    food_total_g: float,
    food_target_g: float,
    water_total_ml: float,
    water_target_ml: float,
) -> dict:
    """입력값만으로 BHI를 계산한다 (DB 없음). 점수는 소수점 1자리 반올림.

    Returns:
        {"bhi_score", "weight_score", "food_score", "water_score", "wci_level"}
    """
    weight_score = round(_calc_weight_score(growth_stage, weight_today_g, weight_baseline_g), 1)
    food_score = round(_calc_food_score(food_total_g, food_target_g), 1)
    water_score = round(_calc_water_score(water_total_ml, water_target_ml), 1)
    bhi_score = round(weight_score + food_score + water_score, 1)

    return {
        "bhi_score": bhi_score,
        "weight_score": weight_score,
        "food_score": food_score,
        "water_score": water_score,
        "wci_level": _bhi_to_wci_level(bhi_score),
    }
