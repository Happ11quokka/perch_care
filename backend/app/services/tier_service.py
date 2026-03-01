from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user_tier import UserTier
from app.models.premium_code import PremiumCode


async def get_user_tier(db: AsyncSession, user_id) -> str:
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
            await db.commit()
            return "free"
    return tier.tier


async def activate_premium_code(db: AsyncSession, user_id, code: str) -> dict:
    """프리미엄 코드 입력 -> 30일 프리미엄 활성화.

    보안 정책:
    - SELECT ... FOR UPDATE로 레이스 컨디션 방지
    - 에러 메시지 단일화 (코드 존재 여부 노출 방지)
    - 같은 사용자가 같은 코드로 재시도 시 멱등 성공 처리
    """
    # 1. 코드 조회 -- SELECT ... FOR UPDATE (레이스 컨디션 방지)
    result = await db.execute(
        select(PremiumCode)
        .where(PremiumCode.code == code)
        .with_for_update()
    )
    premium_code = result.scalar_one_or_none()

    if not premium_code:
        return {"success": False, "error": "유효하지 않거나 이미 사용된 코드입니다"}

    # 멱등성: 같은 사용자가 이미 사용한 코드로 재시도 시 기존 결과 반환
    if premium_code.is_used:
        if premium_code.used_by == user_id:
            tier_result = await db.execute(
                select(UserTier).where(UserTier.user_id == user_id)
            )
            user_tier = tier_result.scalar_one_or_none()
            if user_tier and user_tier.premium_expires_at:
                return {"success": True, "expires_at": user_tier.premium_expires_at.isoformat()}
        return {"success": False, "error": "유효하지 않거나 이미 사용된 코드입니다"}

    # 2. 코드 사용 처리
    now = datetime.now(timezone.utc)
    premium_code.is_used = True
    premium_code.used_by = user_id
    premium_code.used_at = now

    # 3. user_tiers 업서트 (입력일 기준 30일)
    expires_at = now + timedelta(days=30)

    result = await db.execute(
        select(UserTier).where(UserTier.user_id == user_id)
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

    await db.commit()

    return {"success": True, "expires_at": expires_at.isoformat()}
