"""웹 데모(perch.ai.kr) IP 기반 일일 쿼터 서비스.

X-Demo-Key 인증된 공개 데모 요청의 IP별·글로벌 일일(UTC) 한도를 관리한다.
IP는 HMAC-SHA256(salt, ip) 단방향 해시로만 저장하여 원본을 보존하지 않는다.
quota_service.py와 동일하게 pg_advisory_xact_lock으로 동시 요청을 직렬화한다.
"""

import hashlib
import hmac
import logging
from datetime import datetime, timezone

from sqlalchemy import func, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.models.demo_usage_log import DemoUsageLog

logger = logging.getLogger(__name__)

# Advisory lock namespace (quota_service의 100/101과 구분)
_LOCK_NS_DEMO = 102
_LOCK_NS_DEMO_GLOBAL = 103  # kind 단위 글로벌 캡 직렬화용


def _get_limits(kind: str) -> tuple[int, int | None]:
    """kind별 (IP 일일 한도, 글로벌 일일 한도 또는 None)을 반환한다. bhi는 글로벌 캡 없음."""
    settings = get_settings()
    if kind == "chat":
        return settings.demo_chat_daily_limit, settings.demo_chat_global_daily_limit
    if kind == "vision":
        return settings.demo_vision_daily_limit, settings.demo_vision_global_daily_limit
    return settings.demo_bhi_daily_limit, None


def hash_ip(ip: str) -> str:
    """HMAC-SHA256(salt, ip). 원본 IP를 저장하지 않기 위한 단방향 해시.

    솔트는 DEMO_IP_HASH_SALT 전용 설정을 사용하고, 미설정 시 demo_api_key로
    fallback한다 (기존 배포 호환).
    """
    settings = get_settings()
    salt = settings.demo_ip_hash_salt or settings.demo_api_key
    return hmac.new(salt.encode(), ip.encode(), hashlib.sha256).hexdigest()


def _demo_lock_key(ip_hash: str, kind: str) -> int:
    """ip_hash + kind → 31-bit positive int (advisory lock 키용)."""
    digest = hashlib.sha256(f"{ip_hash}:{kind}".encode()).digest()
    return int.from_bytes(digest[:8], "big") & 0x7FFFFFFF


def _global_lock_key(kind: str) -> int:
    """"global:" + kind → 31-bit positive int (글로벌 캡 advisory lock 키용)."""
    digest = hashlib.sha256(f"global:{kind}".encode()).digest()
    return int.from_bytes(digest[:8], "big") & 0x7FFFFFFF


async def check_and_reserve(db: AsyncSession, ip: str, kind: str) -> dict:
    """쿼터 체크 + 슬롯 예약을 원자적으로 수행한다.

    pg_advisory_xact_lock으로 (ip_hash, kind)별 직렬화하여 동시 요청에 의한
    한도 초과를 방지. 한도 내면 DemoUsageLog 1행을 insert+flush로 예약한다.
    호출자가 commit해야 예약이 확정된다 (rollback 시 슬롯 자동 반환).

    Returns:
        {
            "allowed": bool,
            "reason": None | "ip_quota" | "global_cap",
            "limit": int,        # IP 일일 한도
            "remaining": int,    # 예약 반영 후 남은 횟수
            "reservation_id": uuid.UUID,  # allowed=True일 때 예약 행 id (환불용)
        }
    """
    ip_limit, global_limit = _get_limits(kind)
    ip_hashed = hash_ip(ip)

    # (ip_hash, kind)별 advisory lock 획득 (트랜잭션 종료 시 자동 해제)
    await db.execute(
        text("SELECT pg_advisory_xact_lock(:ns, :key)"),
        {"ns": _LOCK_NS_DEMO, "key": _demo_lock_key(ip_hashed, kind)},
    )

    # 글로벌 캡이 있는 kind는 kind 단위 두 번째 lock으로 집계~예약을 직렬화
    # (서로 다른 IP의 동시 요청이 캡을 초과 예약하는 레이스 방지)
    if global_limit is not None:
        await db.execute(
            text("SELECT pg_advisory_xact_lock(:ns, :key)"),
            {"ns": _LOCK_NS_DEMO_GLOBAL, "key": _global_lock_key(kind)},
        )

    now = datetime.now(timezone.utc)
    day_start = now.replace(hour=0, minute=0, second=0, microsecond=0)

    # IP 사용량 + 글로벌 사용량을 단일 SQL round-trip으로 집계
    ip_used_subq = (
        select(func.count())
        .select_from(DemoUsageLog)
        .where(
            DemoUsageLog.ip_hash == ip_hashed,
            DemoUsageLog.kind == kind,
            DemoUsageLog.created_at >= day_start,
        )
        .scalar_subquery()
    )
    global_used_subq = (
        select(func.count())
        .select_from(DemoUsageLog)
        .where(
            DemoUsageLog.kind == kind,
            DemoUsageLog.created_at >= day_start,
        )
        .scalar_subquery()
    )
    result = await db.execute(select(ip_used_subq, global_used_subq))
    ip_used, global_used = result.one()
    ip_used, global_used = int(ip_used or 0), int(global_used or 0)

    if ip_used >= ip_limit:
        return {"allowed": False, "reason": "ip_quota", "limit": ip_limit, "remaining": 0}

    if global_limit is not None and global_used >= global_limit:
        logger.warning("Demo global cap reached: kind=%s used=%d cap=%d", kind, global_used, global_limit)
        return {"allowed": False, "reason": "global_cap", "limit": ip_limit, "remaining": 0}

    # 슬롯 예약
    reservation = DemoUsageLog(ip_hash=ip_hashed, kind=kind)
    db.add(reservation)
    await db.flush()

    return {
        "allowed": True,
        "reason": None,
        "limit": ip_limit,
        "remaining": max(0, ip_limit - ip_used - 1),
        "reservation_id": reservation.id,
    }
