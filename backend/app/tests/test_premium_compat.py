"""GET /premium/tier 호환 스텁 테스트 (구버전 앱 대응).

app/tests/ 의 기존 테스트는 전부 DB 없는 순수 함수 단위 테스트라 FastAPI
TestClient + dependency_overrides 패턴이 아직 없다. 이 테스트는 인증
(get_current_user_id)과 DB 세션(get_db)을 dependency_overrides로 대체하고,
quota 조회 함수는 monkeypatch로 대체해 실제 DB 없이 라우터 계층만 검증한다.

TestClient는 `with` 블록 밖에서 사용해 FastAPI lifespan(실 DB 연결/테이블 생성)이
트리거되지 않도록 한다 — 이 앱의 lifespan은 실제 Postgres 연결을 요구한다.
"""

import uuid

from fastapi.testclient import TestClient

from app.database import get_db
from app.dependencies import get_current_user_id
from app.main import app
from app.routers import premium_compat


def _override_current_user_id():
    return uuid.uuid4()


async def _override_get_db():
    yield None  # quota 함수를 monkeypatch로 대체하므로 실제 세션은 쓰이지 않음


def test_get_tier_compat_returns_free_tier_with_real_usage(monkeypatch):
    async def fake_check_encyclopedia_quota(db, user_id):
        return {"allowed": True, "monthly_limit": 30, "monthly_used": 5, "remaining": 25}

    async def fake_check_vision_access(db, user_id):
        return {"allowed": True, "monthly_limit": 10, "monthly_used": 2, "remaining": 8}

    monkeypatch.setattr(premium_compat, "check_encyclopedia_quota", fake_check_encyclopedia_quota)
    monkeypatch.setattr(premium_compat, "check_vision_access", fake_check_vision_access)

    app.dependency_overrides[get_current_user_id] = _override_current_user_id
    app.dependency_overrides[get_db] = _override_get_db
    try:
        client = TestClient(app)
        response = client.get("/api/v1/premium/tier", headers={"Authorization": "Bearer dummy"})
    finally:
        app.dependency_overrides.pop(get_current_user_id, None)
        app.dependency_overrides.pop(get_db, None)

    assert response.status_code == 200
    data = response.json()

    # 구 클라이언트 PremiumStatus.fromJson이 읽는 top-level 키가 전부 존재해야 한다.
    # 미래 수정으로 필드가 빠지면 여기서 실패한다.
    assert set(data.keys()) == {
        "tier",
        "premium_expires_at",
        "source",
        "store_product_id",
        "auto_renew_status",
        "quota",
    }

    assert data["tier"] == "free"
    assert data["premium_expires_at"] is None
    assert data["source"] is None
    assert data["store_product_id"] is None
    assert data["auto_renew_status"] is None

    assert data["quota"]["ai_encyclopedia"] == {
        "monthly_limit": 30,
        "monthly_used": 5,
        "remaining": 25,
    }
    assert data["quota"]["vision"] == {
        "monthly_limit": 10,
        "monthly_used": 2,
        "remaining": 8,
    }
