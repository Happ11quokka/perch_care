import json
import logging
from datetime import datetime, timedelta, timezone
from typing import Literal
from uuid import UUID

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.dialects.postgresql import insert

from app.models.user_tier import UserTier
from app.models.premium_code import PremiumCode
from app.models.subscription_transaction import SubscriptionTransaction

logger = logging.getLogger(__name__)


class PremiumActivationError(Exception):
    """프리미엄 코드 활성화 실패."""

    def __init__(self, detail: str = "유효하지 않거나 이미 사용된 코드입니다"):
        self.detail = detail
        super().__init__(detail)


async def _get_free_quotas_combined(db: AsyncSession, user_id: UUID) -> tuple[dict, dict]:
    """Free 사용자의 encyclopedia + vision quota dict를 단일 SQL로 조회.

    `get_user_tier_info` 응답 시간 단축용. 두 count 쿼리를 한 번의 round-trip으로 통합.
    Premium 분기에서는 사용 안 함 (즉시 무제한 dict 반환).
    """
    from app.services.quota_service import (
        get_combined_free_usage_this_month,
        _get_encyclopedia_limit,
        _get_vision_limit,
    )

    enc_used, vis_used = await get_combined_free_usage_this_month(db, user_id)
    enc_limit = _get_encyclopedia_limit()
    vis_limit = _get_vision_limit()
    enc = {
        "monthly_limit": enc_limit,
        "monthly_used": enc_used,
        "remaining": max(0, enc_limit - enc_used),
    }
    vis = {
        "monthly_limit": vis_limit,
        "monthly_used": vis_used,
        "remaining": max(0, vis_limit - vis_used),
    }
    return enc, vis


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
    """사용자 티어 + 만료일 + 쿼터를 한번에 반환. 이중 조회 방지용.

    P1-1 Fix: 조건부 원자적 UPDATE로 lost update 방지.
    P2: quota 정보 포함.
    """
    from app.services.quota_service import check_encyclopedia_quota, check_vision_access

    result = await db.execute(
        select(UserTier).where(UserTier.user_id == user_id)
    )
    tier_row = result.scalar_one_or_none()
    if not tier_row:
        enc, vis = await _get_free_quotas_combined(db, user_id)
        return {
            "tier": "free",
            "premium_expires_at": None,
            "source": None,
            "store_product_id": None,
            "auto_renew_status": None,
            "quota": {
                "ai_encyclopedia": {
                    "monthly_limit": enc["monthly_limit"],
                    "monthly_used": enc["monthly_used"],
                    "remaining": enc["remaining"],
                },
                "vision": {
                    "monthly_limit": vis["monthly_limit"],
                    "monthly_used": vis["monthly_used"],
                    "remaining": vis["remaining"],
                },
            },
        }
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
            enc, vis = await _get_free_quotas_combined(db, user_id)
            return {
                "tier": "free",
                "premium_expires_at": None,
                "source": None,
                "store_product_id": None,
                "auto_renew_status": None,
                "quota": {
                    "ai_encyclopedia": {
                        "monthly_limit": enc["monthly_limit"],
                        "monthly_used": enc["monthly_used"],
                        "remaining": enc["remaining"],
                    },
                    "vision": {
                        "monthly_limit": vis["monthly_limit"],
                        "monthly_used": vis["monthly_used"],
                        "remaining": vis["remaining"],
                    },
                },
            }

    tier = tier_row.tier
    if tier == "premium":
        enc = await check_encyclopedia_quota(db, user_id, tier)
        vis = await check_vision_access(db, user_id, tier)
    else:
        enc, vis = await _get_free_quotas_combined(db, user_id)
    return {
        "tier": tier,
        "premium_expires_at": tier_row.premium_expires_at,
        "source": tier_row.source,
        "store_product_id": tier_row.store_product_id,
        "auto_renew_status": tier_row.auto_renew_status,
        "quota": {
            "ai_encyclopedia": {
                "monthly_limit": enc["monthly_limit"],
                "monthly_used": enc["monthly_used"],
                "remaining": enc["remaining"],
            },
            "vision": {
                "monthly_limit": vis["monthly_limit"],
                "monthly_used": vis["monthly_used"],
                "remaining": vis["remaining"],
            },
        },
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
        source="promo_code",
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
            "source": "promo_code",
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


async def activate_store_subscription(
    db: AsyncSession,
    user_id: UUID,
    store: str,
    product_id: str,
    transaction_id: str,
    original_transaction_id: str,
    expires_at: datetime,
    auto_renew: bool,
    raw_payload: str | None = None,
    purchased_at: datetime | None = None,
) -> UserTier:
    """스토어 구독 구매 검증 후 프리미엄 활성화.

    기존 activate_premium_code() 패턴(INSERT ON CONFLICT) 재사용.
    프로모 코드와 동시 활성화 시 만료일이 더 긴 쪽 유지.
    """
    now = datetime.now(timezone.utc)
    source = "app_store" if store == "apple" else "play_store"

    # 1. subscription_transactions에 거래 로그 기록
    tx = SubscriptionTransaction(
        user_id=user_id,
        store=store,
        product_id=product_id,
        transaction_id=transaction_id,
        original_transaction_id=original_transaction_id,
        event_type="purchase",
        purchased_at=purchased_at or now,
        expires_at=expires_at,
        payload_json=raw_payload,
    )
    db.add(tx)

    # 2. 기존 tier 조회하여 만료일 비교
    result = await db.execute(
        select(UserTier).where(UserTier.user_id == user_id).with_for_update()
    )
    existing_tier = result.scalar_one_or_none()

    # 기존 만료일이 더 긴 경우(예: 프로모 코드) 더 긴 쪽 유지
    final_expires_at = expires_at
    if existing_tier and existing_tier.premium_expires_at:
        if existing_tier.premium_expires_at > expires_at:
            final_expires_at = existing_tier.premium_expires_at

    # 3. user_tiers UPSERT
    stmt = insert(UserTier).values(
        user_id=user_id,
        tier="premium",
        premium_started_at=now,
        premium_expires_at=final_expires_at,
        source=source,
        store_product_id=product_id,
        store_original_transaction_id=original_transaction_id,
        auto_renew_status=auto_renew,
        last_verified_at=now,
        created_at=now,
        updated_at=now,
    )
    stmt = stmt.on_conflict_do_update(
        constraint="user_tiers_user_id_key",
        set_={
            "tier": "premium",
            "premium_started_at": now,
            "premium_expires_at": final_expires_at,
            "source": source,
            "store_product_id": product_id,
            "store_original_transaction_id": original_transaction_id,
            "auto_renew_status": auto_renew,
            "last_verified_at": now,
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

    logger.info(
        "Store subscription activated: user=%s, store=%s, product=%s, expires=%s",
        user_id, store, product_id, final_expires_at,
    )
    return user_tier


async def restore_store_subscription(
    db: AsyncSession,
    user_id: UUID,
    store: str,
    product_id: str,
    transaction_id: str,
    original_transaction_id: str,
    expires_at: datetime,
    auto_renew: bool,
    raw_payload: str | None = None,
    purchased_at: datetime | None = None,
) -> UserTier:
    """구매 복원 처리. activate_store_subscription과 동일 로직, event_type='restore'."""
    now = datetime.now(timezone.utc)
    source = "app_store" if store == "apple" else "play_store"

    # 1. 거래 로그 (event_type='restore')
    tx = SubscriptionTransaction(
        user_id=user_id,
        store=store,
        product_id=product_id,
        transaction_id=transaction_id,
        original_transaction_id=original_transaction_id,
        event_type="restore",
        purchased_at=purchased_at or now,
        expires_at=expires_at,
        payload_json=raw_payload,
    )
    db.add(tx)

    # 2. 만료일 비교
    result = await db.execute(
        select(UserTier).where(UserTier.user_id == user_id).with_for_update()
    )
    existing_tier = result.scalar_one_or_none()

    final_expires_at = expires_at
    if existing_tier and existing_tier.premium_expires_at:
        if existing_tier.premium_expires_at > expires_at:
            final_expires_at = existing_tier.premium_expires_at

    # 3. UPSERT
    stmt = insert(UserTier).values(
        user_id=user_id,
        tier="premium",
        premium_started_at=now,
        premium_expires_at=final_expires_at,
        source=source,
        store_product_id=product_id,
        store_original_transaction_id=original_transaction_id,
        auto_renew_status=auto_renew,
        last_verified_at=now,
        created_at=now,
        updated_at=now,
    )
    stmt = stmt.on_conflict_do_update(
        constraint="user_tiers_user_id_key",
        set_={
            "tier": "premium",
            "premium_started_at": now,
            "premium_expires_at": final_expires_at,
            "source": source,
            "store_product_id": product_id,
            "store_original_transaction_id": original_transaction_id,
            "auto_renew_status": auto_renew,
            "last_verified_at": now,
            "updated_at": now,
        },
    )
    await db.execute(stmt)
    await db.flush()

    result = await db.execute(
        select(UserTier).where(UserTier.user_id == user_id)
    )
    user_tier = result.scalar_one()

    logger.info(
        "Store subscription restored: user=%s, store=%s, product=%s, expires=%s",
        user_id, store, product_id, final_expires_at,
    )
    return user_tier
