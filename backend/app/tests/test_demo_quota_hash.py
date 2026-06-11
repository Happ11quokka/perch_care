"""demo_quota_service.hash_ip 단위 테스트 (DB 불필요)."""

import string

from app.services.demo_quota_service import hash_ip


def test_hash_ip_deterministic():
    assert hash_ip("203.0.113.7") == hash_ip("203.0.113.7")


def test_hash_ip_is_64_hex_chars():
    hashed = hash_ip("203.0.113.7")
    assert len(hashed) == 64
    assert all(c in string.hexdigits for c in hashed)


def test_hash_ip_differs_by_ip():
    assert hash_ip("203.0.113.7") != hash_ip("203.0.113.8")
