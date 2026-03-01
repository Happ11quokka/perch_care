import logging
from datetime import datetime, timedelta, timezone
from typing import Literal
from uuid import UUID

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.dialects.postgresql import insert

from app.models.user_tier import UserTier
from app.models.premium_code import PremiumCode

logger = logging.getLogger(__name__)


class PremiumActivationError(Exception):
    """프리미엄 코드 활성화 실패."""

    def __init__(self, detail: str = "유효하지 않거나 이미 사용된 코드입니다"):
        self.detail = detail
        super().__init__(detail)


async def get_user_tier(db: AsyncSession, user_id: UUID) -> Literal["free", "premium"]:
    """사용자 티어 조회. 없으면 'free' 반환. 만료된 프리미엄은 DB도 갱신 후 'free' 반환.

    P1-1 Fix: 조건부 원자적 UPDATE로 lost update 방지.
    WHERE 절에 만료 조건 포함 → activate_premium_code가 만료일을 연장했다면 조건 불일치로 UPDATE 안 됨.
    """
    result = await db.execute(
        select(UserTier).where(UserTier.user_id == user_id)
    )
    tier = result.scalar_one_or_none()
    if not tier:
        return "free"
    if tier.tier == "premium" and tier.premium_expires_at:
        if tier.premium_expires_at < datetime.now(timezone.utc):
            now = datetime.now(timezone.utc)
            await db.execute(
                update(UserTier)
                .where(
                    UserTier.user_id == user_id,
                    UserTier.tier == "premium",
                    UserTier.premium_expires_at < now,
                )
                .values(tier="free", updated_at=now)
            )
            await db.flush()
            return "free"
    return tier.tier


async def get_user_tier_info(db: AsyncSession, user_id: UUID) -> dict:
    """사용자 티어 + 만료일을 한번에 반환. 이중 조회 방지용.

    P1-1 Fix: 조건부 원자적 UPDATE로 lost update 방지.
    """
    result = await db.execute(
        select(UserTier).where(UserTier.user_id == user_id)
    )
    tier_row = result.scalar_one_or_none()
    if not tier_row:
        return {"tier": "free", "premium_expires_at": None}
    # 만료 체크
    if tier_row.tier == "premium" and tier_row.premium_expires_at:
        if tier_row.premium_expires_at < datetime.now(timezone.utc):
            now = datetime.now(timezone.utc)
            await db.execute(
                update(UserTier)
                .where(
                    UserTier.user_id == user_id,
                    UserTier.tier == "premium",
                    UserTier.premium_expires_at < now,
                )
                .values(tier="free", updated_at=now)
            )
            await db.flush()
            return {"tier": "free", "premium_expires_at": None}
    return {
        "tier": tier_row.tier,
        "premium_expires_at": tier_row.premium_expires_at,
    }


async def activate_premium_code(db: AsyncSession, user_id: UUID, code: str) -> UserTier:
    """프리미엄 코드 입력 -> 프리미엄 활성화.

    보안 정책:
    - SELECT ... FOR UPDATE로 레이스 컨디션 방지 (PremiumCode + UserTier)
    - 에러 메시지 단일화 (코드 존재 여부 노출 방지)
    - 같은 사용자가 같은 코드로 재시도 시 멱등 성공 처리

    Raises:
        PremiumActivationError: 코드가 유효하지 않거나 이미 사용된 경우
    """
    # 1. 코드 조회 -- SELECT ... FOR UPDATE (레이스 컨디션 방지)
    result = await db.execute(
        select(PremiumCode)
        .where(PremiumCode.code == code)
        .with_for_update()
    )
    premium_code = result.scalar_one_or_none()

    if not premium_code:
        logger.warning("Premium activation failed: user=%s, code_prefix=%s***", user_id, code[:5])
        raise PremiumActivationError()

    # 멱등성: 같은 사용자가 이미 사용한 코드로 재시도 시 기존 결과 반환
    if premium_code.is_used:
        if premium_code.used_by == user_id:
            tier_result = await db.execute(
                select(UserTier).where(UserTier.user_id == user_id)
            )
            user_tier = tier_result.scalar_one_or_none()
            if user_tier:
                logger.info("Premium idempotent hit: user=%s, code_prefix=%s***", user_id, code[:5])
                return user_tier
        logger.warning("Premium activation failed: user=%s, code_prefix=%s***", user_id, code[:5])
        raise PremiumActivationError()

    # 2. 코드 사용 처리
    now = datetime.now(timezone.utc)
    premium_code.is_used = True
    premium_code.used_by = user_id
    premium_code.used_at = now

    # 3. user_tiers 업서트 (코드의 duration_days 사용)
    # P1-2 Fix: INSERT ... ON CONFLICT DO UPDATE로 first-time insert race 방지.
    # FOR UPDATE는 row가 없으면 lock 불가 → 동시 INSERT 시 unique 충돌.
    # 업서트 패턴으로 원자적 처리 (기존 weight_service 패턴 재사용).
    expires_at = now + timedelta(days=premium_code.duration_days)

    stmt = insert(UserTier).values(
        user_id=user_id,
        tier="premium",
        premium_started_at=now,
        premium_expires_at=expires_at,
        activated_code=code,
        created_at=now,
        updated_at=now,
    )
    stmt = stmt.on_conflict_do_update(
        constraint="user_tiers_user_id_key",
        set_={
            "tier": "premium",
            "premium_started_at": now,
            "premium_expires_at": expires_at,
            "activated_code": code,
            "updated_at": now,
        },
    )
    await db.execute(stmt)
    await db.flush()

    # 반환용 재조회
    result = await db.execute(
        select(UserTier).where(UserTier.user_id == user_id)
    )
    user_tier = result.scalar_one()

    logger.info("Premium activated: user=%s, code_prefix=%s***, expires=%s", user_id, code[:5], expires_at)
    return user_tier
