import logging
from datetime import datetime, timedelta, timezone
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user_tier import UserTier
from app.models.premium_code import PremiumCode

logger = logging.getLogger(__name__)


class PremiumActivationError(Exception):
    """프리미엄 코드 활성화 실패."""

    def __init__(self, detail: str = "유효하지 않거나 이미 사용된 코드입니다"):
        self.detail = detail
        super().__init__(detail)


async def get_user_tier(db: AsyncSession, user_id: UUID) -> str:
    """사용자 티어 조회. 없으면 'free' 반환. 만료된 프리미엄은 DB도 갱신 후 'free' 반환."""
    result = await db.execute(
        select(UserTier).where(UserTier.user_id == user_id)
    )
    tier = result.scalar_one_or_none()
    if not tier:
        return "free"
    if tier.tier == "premium" and tier.premium_expires_at:
        if tier.premium_expires_at < datetime.now(timezone.utc):
            tier.tier = "free"
            tier.updated_at = datetime.now(timezone.utc)
            await db.flush()
            return "free"
    return tier.tier


async def get_user_tier_info(db: AsyncSession, user_id: UUID) -> dict:
    """사용자 티어 + 만료일을 한번에 반환. 이중 조회 방지용."""
    result = await db.execute(
        select(UserTier).where(UserTier.user_id == user_id)
    )
    tier_row = result.scalar_one_or_none()
    if not tier_row:
        return {"tier": "free", "premium_expires_at": None}
    # 만료 체크
    if tier_row.tier == "premium" and tier_row.premium_expires_at:
        if tier_row.premium_expires_at < datetime.now(timezone.utc):
            tier_row.tier = "free"
            tier_row.updated_at = datetime.now(timezone.utc)
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
    expires_at = now + timedelta(days=premium_code.duration_days)

    # UserTier도 FOR UPDATE로 잠금
    result = await db.execute(
        select(UserTier)
        .where(UserTier.user_id == user_id)
        .with_for_update()
    )
    user_tier = result.scalar_one_or_none()

    if user_tier:
        user_tier.tier = "premium"
        user_tier.premium_started_at = now
        user_tier.premium_expires_at = expires_at
        user_tier.activated_code = code
        user_tier.updated_at = now
    else:
        user_tier = UserTier(
            user_id=user_id,
            tier="premium",
            premium_started_at=now,
            premium_expires_at=expires_at,
            activated_code=code,
        )
        db.add(user_tier)

    await db.flush()

    logger.info("Premium activated: user=%s, code_prefix=%s***, expires=%s", user_id, code[:5], expires_at)
    return user_tier
