"""demo_quota_service.hash_ip 단위 테스트 (DB 불필요)."""

import hashlib
import hmac
import string
from types import SimpleNamespace

from app.services import demo_quota_service
from app.services.demo_quota_service import hash_ip


def _settings(salt: str = "", api_key: str = "") -> SimpleNamespace:
    return SimpleNamespace(demo_ip_hash_salt=salt, demo_api_key=api_key)


def test_hash_ip_deterministic():
    assert hash_ip("203.0.113.7") == hash_ip("203.0.113.7")


def test_hash_ip_is_64_hex_chars():
    hashed = hash_ip("203.0.113.7")
    assert len(hashed) == 64
    assert all(c in string.hexdigits for c in hashed)


def test_hash_ip_differs_by_ip():
    assert hash_ip("203.0.113.7") != hash_ip("203.0.113.8")


def test_hash_ip_differs_by_salt(monkeypatch):
    monkeypatch.setattr(demo_quota_service, "get_settings", lambda: _settings(salt="salt-a"))
    hashed_a = hash_ip("203.0.113.7")
    monkeypatch.setattr(demo_quota_service, "get_settings", lambda: _settings(salt="salt-b"))
    hashed_b = hash_ip("203.0.113.7")
    assert hashed_a != hashed_b


def test_hash_ip_is_hmac_sha256(monkeypatch):
    monkeypatch.setattr(demo_quota_service, "get_settings", lambda: _settings(salt="salt-a"))
    expected = hmac.new(b"salt-a", b"203.0.113.7", hashlib.sha256).hexdigest()
    assert hash_ip("203.0.113.7") == expected


def test_hash_ip_falls_back_to_demo_api_key(monkeypatch):
    # 전용 솔트 미설정 시 demo_api_key를 솔트로 사용 (기존 배포 호환)
    monkeypatch.setattr(demo_quota_service, "get_settings", lambda: _settings(salt="", api_key="key-x"))
    fallback = hash_ip("203.0.113.7")
    monkeypatch.setattr(demo_quota_service, "get_settings", lambda: _settings(salt="key-x"))
    assert fallback == hash_ip("203.0.113.7")
