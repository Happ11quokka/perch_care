"""_select_model 회귀 테스트 — 폐기된 OpenAI 모델이 다시 라우팅되지 않도록 고정."""

import pytest

from app.services import ai_service

# OpenAI에서 폐기되어 404(model_not_found)를 내는 모델
DEPRECATED_MODELS = {"gpt-4.1-nano"}


@pytest.mark.parametrize(
    "category", [None, "disease", "nutrition", "behavior", "species", "general"]
)
def test_select_model_never_returns_deprecated(category):
    model, max_tokens = ai_service._select_model("free", category)
    assert model not in DEPRECATED_MODELS
    assert model == "gpt-4o-mini"
    assert max_tokens == 2048
