"""리포트 공유 링크 엔드포인트(app/routers/reports.py) 테스트.

app/tests/ 의 기존 라우터 계층 테스트 패턴(test_premium_compat.py)을 따른다:
- `get_current_user`/`get_db`를 dependency_overrides로 대체해 실제 DB 없이 검증.
- 서비스 함수(generate_health_html/generate_vet_summary_html)는 monkeypatch로 대체.
- TestClient는 `with` 블록 밖에서 사용해 FastAPI lifespan(실 Postgres 연결)을
  트리거하지 않는다.

커버 범위:
- POST /reports/share/health/{pet_id}: happy path, date_to < date_from(400),
  90일 초과 범위(400), 정확히 90일(경계, 200).
- POST /reports/share/vet-summary/{pet_id}: happy path (최근 30일 스냅샷).
- GET /reports/view/{token}: health/vet_summary 정상 렌더링(monkeypatch로 서비스
  응답 고정).

커버하지 않은 것 / 발견한 버그:
- share/health, share/vet-summary 엔드포인트는 pet 소유권을 자체적으로 검증하지
  않는다(실제 소유권 검증은 view_report가 호출하는 report_service 내부에서
  DB 조회로 수행됨) — 이 서비스 내부 DB 조회 로직 자체는 실제 Postgres 없이는
  검증할 수 없으므로 이 테스트 파일의 범위 밖이다(DB fixture 인프라는 별도
  스코프로 명시적으로 제외됨).
- rate limiter(10/minute) 자체의 카운팅/윈도우 동작은 slowapi 라이브러리 내부
  구현이므로 별도로 검증하지 않는다. 다만 테스트마다 서로 다른 sub 클레임을
  가진 Authorization 토큰을 사용해 rate-limit 키(`user:{sub}`)를 분리함으로써
  테스트 간 카운터 간섭(우발적 429)을 방지한다.
- **버그 발견 (미수정, 범위 밖)**: GET /reports/view/{token}의 모든 에러 분기
  (만료 410 / 변조·서명불일치 400 / 알 수 없는 report_type 400 /
  서비스 HTTPException 404 매핑 / 예상치 못한 예외 500 매핑)는
  `_ERROR_HTML.format(title=..., message=...)`를 호출하는데, `_ERROR_HTML`
  템플릿 안의 인라인 CSS가 이스케이프되지 않은 중괄호(`body{font-family:...}`
  등)를 포함하고 있어 `str.format()`이 이를 치환 필드로 오인해
  `KeyError: 'font-family'`를 던진다. 즉 이 5개 에러 분기는 전부 의도한
  안내 HTML을 반환하지 못하고 예외를 던진다 — production(debug=False)에서는
  Starlette 기본 핸들러가 이를 잡아 일반 500으로 변환하므로, 사용자는 만료/
  잘못된 링크/404 등 원래 의도된 세분화된 응답 대신 항상 뭉뚱그려진 500을 보게
  된다. 이 파일의 테스트는 **의도된 동작이 아니라 이 현재(버그) 동작을
  그대로 특성화(characterize)**해 회귀를 감지한다 — 실제 수정은 이번 스코프
  밖이라 손대지 않았다(`backend/app/routers/reports.py`, task 지시상 새 테스트
  파일 추가만 허용). 수정 시에는 `_ERROR_HTML.format(...)` 호출을
  `.replace("{title}", title).replace("{message}", message)` 같은 non-format
  렌더링으로 교체하고, 이 파일의 해당 테스트들을 410/400/404 등 의도된 상태
  코드를 검증하도록 업데이트해야 한다.
"""

import uuid
from datetime import date, datetime, timedelta, timezone

import jwt as pyjwt
import pytest
from fastapi.testclient import TestClient

from app.config import get_settings
from app.database import get_db
from app.dependencies import get_current_user
from app.main import app
from app.models.user import User
from app.routers import reports

settings = get_settings()


def _auth_header() -> dict:
    """`_get_user_rate_limit_key`가 서로 다른 rate-limit 버킷을 쓰도록 매 호출마다
    다른 sub 클레임을 가진 access 토큰을 발급한다 (테스트 간 429 간섭 방지)."""
    payload = {
        "sub": str(uuid.uuid4()),
        "type": "access",
        "exp": datetime.now(timezone.utc) + timedelta(minutes=15),
    }
    token = pyjwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)
    return {"Authorization": f"Bearer {token}"}


def _override_get_current_user():
    return User(id=uuid.uuid4(), email="tester@example.com")


async def _override_get_db():
    yield None  # 서비스 함수를 monkeypatch로 대체하므로 실제 세션은 쓰이지 않음


def _client(raise_server_exceptions: bool = True) -> TestClient:
    # `with` 블록 밖에서 사용해 lifespan(실 Postgres 연결)을 트리거하지 않는다.
    return TestClient(app, raise_server_exceptions=raise_server_exceptions)


def _apply_auth_override():
    app.dependency_overrides[get_current_user] = _override_get_current_user


def _apply_db_override():
    app.dependency_overrides[get_db] = _override_get_db


def _clear_overrides():
    app.dependency_overrides.pop(get_current_user, None)
    app.dependency_overrides.pop(get_db, None)


# ─────────────────────────────────────────────────────────────────────────
# POST /reports/share/health/{pet_id}
# ─────────────────────────────────────────────────────────────────────────


def test_share_health_report_happy_path():
    pet_id = uuid.uuid4()
    _apply_auth_override()
    try:
        client = _client()
        response = client.post(
            f"/api/v1/reports/share/health/{pet_id}",
            params={"date_from": "2026-06-01", "date_to": "2026-06-30"},
            headers=_auth_header(),
        )
    finally:
        _clear_overrides()

    assert response.status_code == 200
    data = response.json()
    assert set(data.keys()) == {"share_url"}
    share_url = data["share_url"]
    assert isinstance(share_url, str) and share_url
    assert "/api/v1/reports/view/" in share_url

    token = share_url.rsplit("/", 1)[-1]
    payload = pyjwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
    assert payload["type"] == "report_share"
    assert payload["report_type"] == "health"
    assert payload["pet_id"] == str(pet_id)
    assert payload["date_from"] == "2026-06-01"
    assert payload["date_to"] == "2026-06-30"


def test_share_health_report_date_to_before_date_from_rejected():
    pet_id = uuid.uuid4()
    _apply_auth_override()
    try:
        client = _client()
        response = client.post(
            f"/api/v1/reports/share/health/{pet_id}",
            params={"date_from": "2026-06-30", "date_to": "2026-06-01"},
            headers=_auth_header(),
        )
    finally:
        _clear_overrides()

    assert response.status_code == 400
    assert "date_to must be >= date_from" in response.json()["detail"]


def test_share_health_report_over_90_day_span_rejected():
    pet_id = uuid.uuid4()
    _apply_auth_override()
    try:
        client = _client()
        response = client.post(
            f"/api/v1/reports/share/health/{pet_id}",
            params={"date_from": "2026-01-01", "date_to": "2026-04-15"},  # 104 days
            headers=_auth_header(),
        )
    finally:
        _clear_overrides()

    assert response.status_code == 400
    assert "90 days" in response.json()["detail"]


def test_share_health_report_exactly_90_days_allowed():
    pet_id = uuid.uuid4()
    date_from = date(2026, 1, 1)
    date_to = date_from + timedelta(days=90)  # boundary: not > 90, so allowed
    _apply_auth_override()
    try:
        client = _client()
        response = client.post(
            f"/api/v1/reports/share/health/{pet_id}",
            params={"date_from": date_from.isoformat(), "date_to": date_to.isoformat()},
            headers=_auth_header(),
        )
    finally:
        _clear_overrides()

    assert response.status_code == 200
    assert "share_url" in response.json()


# ─────────────────────────────────────────────────────────────────────────
# POST /reports/share/vet-summary/{pet_id}
# ─────────────────────────────────────────────────────────────────────────


def test_share_vet_summary_happy_path():
    pet_id = uuid.uuid4()
    _apply_auth_override()
    try:
        client = _client()
        response = client.post(
            f"/api/v1/reports/share/vet-summary/{pet_id}",
            headers=_auth_header(),
        )
    finally:
        _clear_overrides()

    assert response.status_code == 200
    data = response.json()
    share_url = data["share_url"]
    assert isinstance(share_url, str) and share_url
    assert "/api/v1/reports/view/" in share_url

    token = share_url.rsplit("/", 1)[-1]
    payload = pyjwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
    assert payload["type"] == "report_share"
    assert payload["report_type"] == "vet_summary"
    assert payload["pet_id"] == str(pet_id)

    snapshot_to = date.fromisoformat(payload["date_to"])
    snapshot_from = date.fromisoformat(payload["date_from"])
    assert snapshot_to == date.today()
    assert snapshot_from == snapshot_to - timedelta(days=30)


# ─────────────────────────────────────────────────────────────────────────
# GET /reports/view/{token}
# ─────────────────────────────────────────────────────────────────────────


def test_view_report_health_renders_html(monkeypatch):
    pet_id = uuid.uuid4()
    user_id = uuid.uuid4()
    token = reports._create_share_token(
        pet_id=pet_id,
        user_id=user_id,
        report_type="health",
        lang="ko",
        date_from=date(2026, 6, 1),
        date_to=date(2026, 6, 30),
    )

    async def fake_generate_health_html(**kwargs):
        assert kwargs["pet_id"] == pet_id
        assert kwargs["user_id"] == user_id
        assert kwargs["date_from"] == date(2026, 6, 1)
        assert kwargs["date_to"] == date(2026, 6, 30)
        assert kwargs["language"] == "ko"
        return "<html><body>health report</body></html>"

    monkeypatch.setattr(reports, "generate_health_html", fake_generate_health_html)

    _apply_db_override()
    try:
        client = _client()
        response = client.get(f"/api/v1/reports/view/{token}")
    finally:
        _clear_overrides()

    assert response.status_code == 200
    assert "health report" in response.text
    assert response.headers["content-type"].startswith("text/html")


def test_view_report_vet_summary_renders_html(monkeypatch):
    pet_id = uuid.uuid4()
    user_id = uuid.uuid4()
    token = reports._create_share_token(
        pet_id=pet_id,
        user_id=user_id,
        report_type="vet_summary",
        lang="en",
    )

    async def fake_generate_vet_summary_html(**kwargs):
        assert kwargs["pet_id"] == pet_id
        assert kwargs["user_id"] == user_id
        assert kwargs["language"] == "en"
        return "<html><body>vet summary</body></html>"

    monkeypatch.setattr(reports, "generate_vet_summary_html", fake_generate_vet_summary_html)

    _apply_db_override()
    try:
        client = _client()
        response = client.get(f"/api/v1/reports/view/{token}")
    finally:
        _clear_overrides()

    assert response.status_code == 200
    assert "vet summary" in response.text


# ─────────────────────────────────────────────────────────────────────────
# GET /reports/view/{token} — error branches
#
# KNOWN BUG (documented, not fixed — see module docstring): every error
# branch below calls `_ERROR_HTML.format(title=..., message=...)`, and the
# template's inline CSS contains unescaped `{...}` (e.g. `body{font-family:
# ...}`), so `str.format()` raises `KeyError: 'font-family'` before a
# response can be built. These tests characterize the CURRENT (buggy)
# behavior — a real client sees a generic 500 for every one of these cases,
# not the intended 410/400/404. `raise_server_exceptions=False` is used so
# TestClient behaves like a real deployment (Starlette's default handler
# converts the unhandled KeyError into a 500 response) instead of re-raising
# the exception into the test process.
# ─────────────────────────────────────────────────────────────────────────


def test_view_report_expired_token_currently_500s_instead_of_410():
    payload = {
        "type": "report_share",
        "pet_id": str(uuid.uuid4()),
        "user_id": str(uuid.uuid4()),
        "report_type": "health",
        "lang": "ko",
        "date_from": "2026-01-01",
        "date_to": "2026-01-10",
        "exp": datetime.now(timezone.utc) - timedelta(days=1),  # already expired
    }
    token = pyjwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)

    _apply_db_override()
    try:
        client = _client(raise_server_exceptions=False)
        response = client.get(f"/api/v1/reports/view/{token}")
    finally:
        _clear_overrides()

    # Intended behavior would be 410 + "Link Expired" in the body; see bug note above.
    assert response.status_code == 500


def test_view_report_invalid_token_currently_500s_instead_of_400():
    _apply_db_override()
    try:
        client = _client(raise_server_exceptions=False)
        response = client.get("/api/v1/reports/view/not-a-real-token")
    finally:
        _clear_overrides()

    # Intended behavior would be 400 + "Invalid Link" in the body; see bug note above.
    assert response.status_code == 500


def test_view_report_wrong_signature_currently_500s_instead_of_400():
    payload = {
        "type": "report_share",
        "pet_id": str(uuid.uuid4()),
        "user_id": str(uuid.uuid4()),
        "report_type": "health",
        "lang": "ko",
        "exp": datetime.now(timezone.utc) + timedelta(days=7),
    }
    token = pyjwt.encode(payload, "wrong-secret", algorithm=settings.jwt_algorithm)

    _apply_db_override()
    try:
        client = _client(raise_server_exceptions=False)
        response = client.get(f"/api/v1/reports/view/{token}")
    finally:
        _clear_overrides()

    assert response.status_code == 500


def test_view_report_unknown_report_type_currently_500s_instead_of_400():
    payload = {
        "type": "report_share",
        "pet_id": str(uuid.uuid4()),
        "user_id": str(uuid.uuid4()),
        "report_type": "something_else",
        "lang": "ko",
        "exp": datetime.now(timezone.utc) + timedelta(days=7),
    }
    token = pyjwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)

    _apply_db_override()
    try:
        client = _client(raise_server_exceptions=False)
        response = client.get(f"/api/v1/reports/view/{token}")
    finally:
        _clear_overrides()

    assert response.status_code == 500


def test_view_report_service_not_found_currently_500s_instead_of_404(monkeypatch):
    from fastapi import HTTPException

    token = reports._create_share_token(
        pet_id=uuid.uuid4(),
        user_id=uuid.uuid4(),
        report_type="health",
        lang="ko",
        date_from=date(2026, 6, 1),
        date_to=date(2026, 6, 30),
    )

    async def fake_generate_health_html(**kwargs):
        raise HTTPException(status_code=404, detail="Pet not found")

    monkeypatch.setattr(reports, "generate_health_html", fake_generate_health_html)

    _apply_db_override()
    try:
        client = _client(raise_server_exceptions=False)
        response = client.get(f"/api/v1/reports/view/{token}")
    finally:
        _clear_overrides()

    # Intended behavior would be 404 + "Not Found" in the body; see bug note above.
    assert response.status_code == 500


def test_view_report_service_unexpected_error_currently_500s_with_masked_cause(monkeypatch):
    token = reports._create_share_token(
        pet_id=uuid.uuid4(),
        user_id=uuid.uuid4(),
        report_type="health",
        lang="ko",
        date_from=date(2026, 6, 1),
        date_to=date(2026, 6, 30),
    )

    async def fake_generate_health_html(**kwargs):
        raise RuntimeError("boom")

    monkeypatch.setattr(reports, "generate_health_html", fake_generate_health_html)

    _apply_db_override()
    try:
        client = _client(raise_server_exceptions=False)
        response = client.get(f"/api/v1/reports/view/{token}")
    finally:
        _clear_overrides()

    # Still 500 as intended here, but for the wrong reason: the KeyError from
    # `_ERROR_HTML.format()` masks the original RuntimeError entirely.
    assert response.status_code == 500
