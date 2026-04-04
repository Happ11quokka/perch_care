"""AI 기능 사용량 쿼터 관리 서비스.

Free 사용자의 AI 백과사전·Vision 건강체크 월간 한도를 관리한다.
한도 값은 환경변수(FREE_ENCYCLOPEDIA_MONTHLY_LIMIT, FREE_VISION_MONTHLY_LIMIT)로 설정 가능.
별도 quota 테이블 없이 기존 로그 테이블(AiEncyclopediaLog, AiVisionLog) 집계 방식.

Quota 체크 시 pg_advisory_xact_lock으로 사용자별 직렬화하여 동시 요청에 의한
한도 초과를 방지한다. Advisory lock은 트랜잭션 종료(commit/rollback) 시 자동 해제.
"""

import logging
from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy import func, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.models.ai_encyclopedia_log import AiEncyclopediaLog
from app.models.ai_vision_log import AiVisionLog

logger = logging.getLogger(__name__)


def _get_encyclopedia_limit() -> int:
    return get_settings().free_encyclopedia_monthly_limit


def _get_vision_limit() -> int:
    return get_settings().free_vision_monthly_limit

# Advisory lock namespaces (pg_advisory_xact_lock 첫 번째 인자)
_LOCK_NS_ENCYCLOPEDIA = 100
_LOCK_NS_VISION = 101


def _user_lock_key(user_id: UUID) -> int:
    """UUID → 31-bit positive int (advisory lock 키용)."""
    return user_id.int & 0x7FFFFFFF


async def get_encyclopedia_usage_this_month(db: AsyncSession, user_id: UUID) -> int:
    """이번 달(UTC 기준) AI 백과사전 사용 횟수를 반환한다."""
    now = datetime.now(timezone.utc)
    month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)

    result = await db.execute(
        select(func.count())
        .select_from(AiEncyclopediaLog)
        .where(
            AiEncyclopediaLog.user_id == user_id,
            AiEncyclopediaLog.created_at >= month_start,
        )
    )
    return result.scalar() or 0


async def check_encyclopedia_quota(
    db: AsyncSession, user_id: UUID, tier: str
) -> dict:
    """AI 백과사전 쿼터를 확인한다 (읽기 전용 — GET /premium/tier, GET /ai/quota 등에서 사용).

    Returns:
        {
            "allowed": bool,
            "monthly_limit": int,   # -1 = 무제한
            "monthly_used": int,
            "remaining": int,       # -1 = 무제한
        }
    """
    if tier == "premium":
        return {
            "allowed": True,
            "monthly_limit": -1,
            "monthly_used": 0,
            "remaining": -1,
        }

    used = await get_encyclopedia_usage_this_month(db, user_id)
    remaining = max(0, _get_encyclopedia_limit() - used)

    return {
        "allowed": used < _get_encyclopedia_limit(),
        "monthly_limit": _get_encyclopedia_limit(),
        "monthly_used": used,
        "remaining": remaining,
    }


async def check_and_reserve_encyclopedia(
    db: AsyncSession,
    user_id: UUID,
    tier: str,
    pet_id: UUID | None,
    query_length: int,
    model: str,
) -> tuple[dict, AiEncyclopediaLog | None]:
    """쿼터 체크 + 슬롯 예약을 원자적으로 수행한다.

    pg_advisory_xact_lock으로 사용자별 직렬화하여 동시 요청에 의한 한도 초과를 방지.
    Premium 사용자는 잠금/예약 없이 통과.

    Returns:
        (quota_info, reservation_or_None)
        - reservation이 반환되면, 호출자가 AI 완료 후 response_length/response_time_ms를 업데이트.
        - AI 실패 시 트랜잭션 rollback으로 예약 자동 삭제 (Depends(get_db) 패턴).
          별도 세션에서 사용할 경우 호출자가 명시적으로 삭제해야 한다.
    """
    if tier == "premium":
        return {
            "allowed": True,
            "monthly_limit": -1,
            "monthly_used": 0,
            "remaining": -1,
        }, None

    # 사용자별 advisory lock 획득 (트랜잭션 종료 시 자동 해제)
    await db.execute(
        text("SELECT pg_advisory_xact_lock(:ns, :key)"),
        {"ns": _LOCK_NS_ENCYCLOPEDIA, "key": _user_lock_key(user_id)},
    )

    used = await get_encyclopedia_usage_this_month(db, user_id)
    if used >= _get_encyclopedia_limit():
        return {
            "allowed": False,
            "monthly_limit": _get_encyclopedia_limit(),
            "monthly_used": used,
            "remaining": 0,
        }, None

    # 슬롯 예약 (placeholder 값으로 생성)
    reservation = AiEncyclopediaLog(
        user_id=user_id,
        pet_id=pet_id,
        query_length=query_length,
        response_length=0,
        response_time_ms=0,
        model=model,
    )
    db.add(reservation)
    await db.flush()

    return {
        "allowed": True,
        "monthly_limit": _get_encyclopedia_limit(),
        "monthly_used": used + 1,
        "remaining": max(0, _get_encyclopedia_limit() - used - 1),
    }, reservation


async def get_vision_usage_this_month(db: AsyncSession, user_id: UUID) -> int:
    """이번 달(UTC 기준) Vision 건강체크 사용 횟수를 반환한다."""
    now = datetime.now(timezone.utc)
    month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)

    result = await db.execute(
        select(func.count())
        .select_from(AiVisionLog)
        .where(
            AiVisionLog.user_id == user_id,
            AiVisionLog.created_at >= month_start,
        )
    )
    return result.scalar() or 0


async def get_vision_remaining(db: AsyncSession, user_id: UUID) -> int:
    """Vision 건강체크 이번 달 남은 횟수를 반환한다."""
    used = await get_vision_usage_this_month(db, user_id)
    return max(0, _get_vision_limit() - used)


async def check_vision_access(
    db: AsyncSession, user_id: UUID, tier: str
) -> dict:
    """Vision 건강체크 접근 권한을 확인한다 (읽기 전용).

    Returns:
        {
            "allowed": bool,
            "monthly_limit": int,   # -1 = 무제한
            "monthly_used": int,
            "remaining": int,       # -1 = 무제한
        }
    """
    if tier == "premium":
        return {
            "allowed": True,
            "monthly_limit": -1,
            "monthly_used": 0,
            "remaining": -1,
        }

    used = await get_vision_usage_this_month(db, user_id)
    remaining = max(0, _get_vision_limit() - used)

    return {
        "allowed": remaining > 0,
        "monthly_limit": _get_vision_limit(),
        "monthly_used": used,
        "remaining": remaining,
    }


async def check_and_reserve_vision(
    db: AsyncSession,
    user_id: UUID,
    tier: str,
    pet_id: UUID | None,
    mode: str,
    part: str | None,
    image_size_bytes: int,
) -> tuple[dict, AiVisionLog | None]:
    """Vision 접근 권한 체크 + 슬롯 예약을 원자적으로 수행한다.

    Returns:
        (access_info, reservation_or_None)
        - reservation이 반환되면, 호출자가 AI 완료 후 response_time_ms 등을 업데이트.
    """
    if tier == "premium":
        return {
            "allowed": True,
            "monthly_limit": -1,
            "monthly_used": 0,
            "remaining": -1,
        }, None

    await db.execute(
        text("SELECT pg_advisory_xact_lock(:ns, :key)"),
        {"ns": _LOCK_NS_VISION, "key": _user_lock_key(user_id)},
    )

    remaining = await get_vision_remaining(db, user_id)
    if remaining <= 0:
        return {
            "allowed": False,
            "monthly_limit": _get_vision_limit(),
            "monthly_used": _get_vision_limit(),
            "remaining": 0,
        }, None

    # 슬롯 예약
    reservation = AiVisionLog(
        user_id=user_id,
        pet_id=pet_id,
        mode=mode,
        part=part,
        image_size_bytes=image_size_bytes,
        response_time_ms=0,
        model="gpt-4o",
        tier=tier,
    )
    db.add(reservation)
    await db.flush()

    used = await get_vision_usage_this_month(db, user_id)
    return {
        "allowed": True,
        "monthly_limit": _get_vision_limit(),
        "monthly_used": used + 1,
        "remaining": remaining - 1,
    }, reservation
