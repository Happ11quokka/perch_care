"""demo_bhi_service 순수 수식 테스트 (DB 불필요)."""

import pytest

from app.services.demo_bhi_service import _bhi_to_wci_level, calculate_demo_bhi


def _calc(**overrides) -> dict:
    """기본값(만점 입력)에서 일부만 바꿔 계산하는 헬퍼."""
    params = {
        "growth_stage": "adult",
        "weight_today_g": 32.0,
        "weight_baseline_g": 32.0,
        "food_total_g": 10.0,
        "food_target_g": 10.0,
        "water_total_ml": 6.0,
        "water_target_ml": 6.0,
    }
    params.update(overrides)
    return calculate_demo_bhi(**params)


class TestPerfectScore:
    def test_adult_all_on_target_is_100(self):
        result = _calc()
        assert result["weight_score"] == 60.0
        assert result["food_score"] == 25.0
        assert result["water_score"] == 15.0
        assert result["bhi_score"] == 100.0
        assert result["wci_level"] == 5


class TestWeightScore:
    def test_adult_drop_10_percent_is_zero(self):
        # WCI = -0.10 → clamp(|WCI|/0.10) = 1 → 0점
        result = _calc(weight_today_g=28.8, weight_baseline_g=32.0)
        assert result["weight_score"] == 0.0

    def test_adult_drop_over_10_percent_is_zero(self):
        result = _calc(weight_today_g=25.0, weight_baseline_g=32.0)
        assert result["weight_score"] == 0.0

    def test_adult_gain_penalized_symmetrically(self):
        # adult는 증가도 감점: WCI = +0.05 → 60 * (1 - 0.5) = 30
        result = _calc(weight_today_g=33.6, weight_baseline_g=32.0)
        assert result["weight_score"] == 30.0

    def test_post_growth_gain_not_penalized(self):
        # post_growth는 min(WCI, 0)만 감점 → 증가는 만점 유지
        result = _calc(growth_stage="post_growth", weight_today_g=33.6, weight_baseline_g=32.0)
        assert result["weight_score"] == 60.0

    def test_baseline_none_defaults_to_full_score(self):
        result = _calc(weight_baseline_g=None)
        assert result["weight_score"] == 60.0

    def test_baseline_zero_defaults_to_full_score(self):
        result = _calc(weight_baseline_g=0.0)
        assert result["weight_score"] == 60.0


class TestRapidGrowthRamp:
    """rapid_growth: 증가율 0→10%에 비례해 0→60점 램프."""

    @pytest.mark.parametrize(
        "today,expected",
        [
            (30.0, 0.0),    # 증가 없음 → 0
            (31.5, 30.0),   # +5% → 30
            (33.0, 60.0),   # +10% → 60 (만점)
            (34.5, 60.0),   # +15% → min(WCI, 0.1) 캡 → 60
            (29.0, 0.0),    # 감소 → 0
        ],
    )
    def test_gain_ramp(self, today, expected):
        result = _calc(growth_stage="rapid_growth", weight_today_g=today, weight_baseline_g=30.0)
        assert result["weight_score"] == expected


class TestFoodScore:
    def test_half_of_target_is_zero(self):
        # Δf = -0.5 → /0.50 완화 분모 기준 정확히 경계 → 0점
        result = _calc(food_total_g=5.0, food_target_g=10.0)
        assert result["food_score"] == 0.0

    def test_partial_intake(self):
        # Δf = -0.2 → 25 * (1 - 0.4) = 15
        result = _calc(food_total_g=8.0, food_target_g=10.0)
        assert result["food_score"] == 15.0

    def test_over_target_not_penalized(self):
        # min(Δf, 0) → 초과 섭취는 감점 없음
        result = _calc(food_total_g=15.0, food_target_g=10.0)
        assert result["food_score"] == 25.0


class TestWaterScore:
    def test_over_target_penalized(self):
        # water는 |Δd| → 과음수도 감점: Δd = +0.3 → 15 * (1 - 0.5) = 7.5
        result = _calc(water_total_ml=7.8, water_target_ml=6.0)
        assert result["water_score"] == 7.5

    def test_under_target_penalized(self):
        # Δd = -0.3 → 7.5
        result = _calc(water_total_ml=4.2, water_target_ml=6.0)
        assert result["water_score"] == 7.5


class TestZeroTargets:
    def test_zero_food_target_is_zero_score(self):
        result = _calc(food_total_g=10.0, food_target_g=0.0)
        assert result["food_score"] == 0.0

    def test_zero_water_target_is_zero_score(self):
        result = _calc(water_total_ml=6.0, water_target_ml=0.0)
        assert result["water_score"] == 0.0

    def test_zero_targets_with_baseline_none(self):
        # weight 60 + food 0 + water 0 = 60 → level 3
        result = _calc(weight_baseline_g=None, food_target_g=0.0, water_target_ml=0.0)
        assert result["bhi_score"] == 60.0
        assert result["wci_level"] == 3


class TestWciLevelBands:
    @pytest.mark.parametrize(
        "bhi,expected",
        [
            (-1.0, 0),
            (0.0, 0),
            (0.1, 1),
            (20.0, 1),
            (20.1, 2),
            (40.0, 2),
            (40.1, 3),
            (60.0, 3),
            (60.1, 4),
            (80.0, 4),
            (80.1, 5),
            (100.0, 5),
        ],
    )
    def test_band_edges(self, bhi, expected):
        assert _bhi_to_wci_level(bhi) == expected


class TestRounding:
    def test_scores_rounded_to_one_decimal(self):
        # WCI = -0.0333... → 60 * (1 - 0.3334...) = 39.99375 → 40.0 / Δf = -0.13 → 25 * (1 - 0.26) = 18.5
        result = _calc(weight_today_g=30.933, weight_baseline_g=32.0, food_total_g=8.7, food_target_g=10.0)
        assert result["weight_score"] == 40.0
        assert result["food_score"] == 18.5
        assert result["bhi_score"] == 73.5
        assert result["wci_level"] == 4
