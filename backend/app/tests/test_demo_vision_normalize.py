"""demo 라우터 normalize_droppings_result 단위 테스트 (DB 불필요)."""

from app.routers.demo import normalize_droppings_result


def _droppings_result(**overrides) -> dict:
    """프롬프트 스키마 형태의 droppings 결과를 만드는 헬퍼."""
    result = {
        "mode": "droppings",
        "findings": [
            {
                "component": "feces",
                "color": "green",
                "texture": "firm",
                "status": "normal",
                "diet_related": False,
            }
        ],
        "overall_status": "normal",
        "possible_conditions": ["none"],
        "recommendations": [],
    }
    result.update(overrides)
    return result


class TestComponentFindingNormalized:
    def test_component_rewritten_to_client_contract(self):
        result = normalize_droppings_result(_droppings_result())
        finding = result["findings"][0]
        assert finding == {
            "area": "feces",
            "observation": "green, firm",
            "severity": "normal",
            "possible_causes": ["none"],
        }

    def test_diet_related_appends_note(self):
        result = normalize_droppings_result(
            _droppings_result(
                findings=[
                    {
                        "component": "feces",
                        "color": "red",
                        "texture": "soft",
                        "status": "caution",
                        "diet_related": True,
                    }
                ],
            )
        )
        assert result["findings"][0]["observation"] == "red, soft. 식이와 관련된 변화일 수 있어요."

    def test_diet_related_note_localized_by_language(self):
        finding = {
            "component": "feces",
            "color": "red",
            "texture": "soft",
            "status": "caution",
            "diet_related": True,
        }
        en = normalize_droppings_result(_droppings_result(findings=[dict(finding)]), language="en")
        zh = normalize_droppings_result(_droppings_result(findings=[dict(finding)]), language="zh")
        assert en["findings"][0]["observation"].endswith("May be diet-related.")
        assert zh["findings"][0]["observation"].endswith("可能与饮食有关。")

    def test_empty_color_texture_skipped_in_observation(self):
        result = normalize_droppings_result(
            _droppings_result(
                findings=[{"component": "urine", "color": "", "texture": "watery", "status": "caution"}],
            )
        )
        assert result["findings"][0]["observation"] == "watery"

    def test_missing_status_defaults_to_not_visible(self):
        result = normalize_droppings_result(
            _droppings_result(findings=[{"component": "urates", "color": "white"}])
        )
        assert result["findings"][0]["severity"] == "not_visible"


class TestConformingFindingUntouched:
    def test_contract_shaped_finding_passes_through(self):
        conforming = {
            "area": "feces",
            "observation": "green, firm",
            "severity": "normal",
            "possible_causes": [],
        }
        result = normalize_droppings_result(_droppings_result(findings=[conforming]))
        assert result["findings"][0] is conforming

    def test_findings_missing_returns_result_unchanged(self):
        result = _droppings_result()
        del result["findings"]
        assert normalize_droppings_result(result) == result


class TestUnknownStatusCoercedToCaution:
    def test_unknown_status_becomes_caution(self):
        result = normalize_droppings_result(
            _droppings_result(
                findings=[{"component": "feces", "color": "green", "texture": "firm", "status": "weird"}],
            )
        )
        assert result["findings"][0]["severity"] == "caution"
