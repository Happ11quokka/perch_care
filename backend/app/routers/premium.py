import logging
import random
import string
from datetime import datetime, timedelta, timezone
from uuid import UUID as PyUUID

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy import func, select, union_all, literal_column, cast, Date
from sqlalchemy.ext.asyncio import AsyncSession
from slowapi import Limiter
from slowapi.util import get_remote_address

from app.database import get_db
from app.dependencies import get_current_user, verify_admin_api_key
from app.models.user import User
from app.models.premium_code import PremiumCode
from app.models.ai_encyclopedia_log import AiEncyclopediaLog
from app.models.ai_vision_log import AiVisionLog
from app.schemas.premium import (
    PremiumCodeRequest, PremiumCodeResponse, TierResponse,
    AiEncyclopediaQuota, VisionQuota, QuotaInfo,
    GenerateCodesRequest, GenerateCodesResponse, GeneratedCodeItem,
    PremiumCodeListItem, AdminUserPremiumInfo, RevokeResponse, DeleteCodeResponse,
    UsageSummaryResponse, DailyUsageItem, UserUsageItem, ModelUsageItem,
    PurchaseVerifyRequest, PurchaseVerifyResponse, PurchaseRestoreRequest,
    SubscriptionTransactionItem, SubscriptionStatsResponse,
    SubscriptionSummaryResponse, ConversionFunnelResponse, AiCostAnalysisResponse,
)
from app.models.subscription_transaction import SubscriptionTransaction
from app.models.user_tier import UserTier
from app.services.tier_service import (
    activate_premium_code, get_user_tier_info, PremiumActivationError,
    activate_store_subscription, restore_store_subscription,
)
from app.services.store_verification_service import verify_store_transaction, StoreVerificationError
from app.utils.security import decode_token

logger = logging.getLogger(__name__)


def _get_user_rate_limit_key(request: Request) -> str:
    """JWT에서 사용자 ID 추출하여 rate limit 키로 사용. 실패 시 IP fallback."""
    auth_header = request.headers.get("Authorization", "")
    if auth_header.startswith("Bearer "):
        payload = decode_token(auth_header[7:])
        if payload and payload.get("sub"):
            return f"user:{payload['sub']}"
    return f"ip:{get_remote_address(request)}"


limiter = Limiter(key_func=_get_user_rate_limit_key)
router = APIRouter(prefix="/premium", tags=["premium"])


@router.get("/tier", response_model=TierResponse)
async def get_my_tier(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """현재 사용자의 티어 + 쿼터 조회."""
    info = await get_user_tier_info(db, current_user.id)
    quota_data = info.get("quota")
    quota = None
    if quota_data:
        quota = QuotaInfo(
            ai_encyclopedia=AiEncyclopediaQuota(**quota_data["ai_encyclopedia"]),
            vision=VisionQuota(**quota_data["vision"]),
        )
    return TierResponse(
        tier=info["tier"],
        premium_expires_at=info["premium_expires_at"],
        source=info.get("source"),
        store_product_id=info.get("store_product_id"),
        auto_renew_status=info.get("auto_renew_status"),
        quota=quota,
    )


@router.post("/activate", response_model=PremiumCodeResponse)
@limiter.limit("5/minute")
async def activate_premium(
    request_obj: PremiumCodeRequest,
    request: Request,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """프리미엄 코드 활성화. 사용자당 5회/분 rate limit."""
    try:
        user_tier = await activate_premium_code(db, current_user.id, request_obj.code)
        return PremiumCodeResponse(success=True, expires_at=user_tier.premium_expires_at)
    except PremiumActivationError as e:
        raise HTTPException(status_code=400, detail=e.detail)


@router.post("/purchases/verify", response_model=PurchaseVerifyResponse)
async def verify_purchase(
    request_obj: PurchaseVerifyRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """스토어 구매 검증 → entitlement 반영."""
    try:
        # 1. 스토어 API로 거래 검증
        verified = await verify_store_transaction(
            store=request_obj.store,
            product_id=request_obj.product_id,
            transaction_id=request_obj.transaction_id,
        )

        # 2. tier_service로 프리미엄 활성화
        import json
        user_tier = await activate_store_subscription(
            db=db,
            user_id=current_user.id,
            store=request_obj.store,
            product_id=verified["product_id"],
            transaction_id=request_obj.transaction_id,
            original_transaction_id=verified["original_transaction_id"],
            expires_at=verified["expires_date"],
            auto_renew=verified["auto_renew_status"],
            raw_payload=json.dumps(verified, default=str),
            purchased_at=verified.get("purchased_at"),
        )
        await db.commit()

        source = "app_store" if request_obj.store == "apple" else "play_store"
        return PurchaseVerifyResponse(
            success=True,
            tier=user_tier.tier,
            premium_expires_at=user_tier.premium_expires_at,
            source=source,
        )

    except StoreVerificationError as e:
        logger.warning("Purchase verification failed: user=%s, store=%s, error=%s", current_user.id, e.store, e.detail)
        raise HTTPException(status_code=400, detail=e.detail)


@router.post("/purchases/restore", response_model=PurchaseVerifyResponse)
async def restore_purchase(
    request_obj: PurchaseRestoreRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """구매 복원 (재설치 후 등)."""
    try:
        # 스토어에서 product_id를 모를 수 있으므로 검증 결과에서 가져옴
        verified = await verify_store_transaction(
            store=request_obj.store,
            product_id="",  # Apple은 transactionId로 조회 가능
            transaction_id=request_obj.transaction_id,
        )

        # 만료된 구독인지 확인
        if verified["expires_date"] and verified["expires_date"] < datetime.now(timezone.utc):
            return PurchaseVerifyResponse(
                success=False,
                tier="free",
                premium_expires_at=verified["expires_date"],
                source="expired",
            )

        import json
        user_tier = await restore_store_subscription(
            db=db,
            user_id=current_user.id,
            store=request_obj.store,
            product_id=verified["product_id"],
            transaction_id=request_obj.transaction_id,
            original_transaction_id=verified["original_transaction_id"],
            expires_at=verified["expires_date"],
            auto_renew=verified["auto_renew_status"],
            raw_payload=json.dumps(verified, default=str),
            purchased_at=verified.get("purchased_at"),
        )
        await db.commit()

        source = "app_store" if request_obj.store == "apple" else "play_store"
        return PurchaseVerifyResponse(
            success=True,
            tier=user_tier.tier,
            premium_expires_at=user_tier.premium_expires_at,
            source=source,
        )

    except StoreVerificationError as e:
        logger.warning("Purchase restore failed: user=%s, store=%s, error=%s", current_user.id, e.store, e.detail)
        raise HTTPException(status_code=400, detail=e.detail)


def _generate_code() -> str:
    """PERCH-XXXX-XXXX 형식의 랜덤 코드 생성."""
    chars = string.ascii_uppercase + string.digits
    part1 = "".join(random.choices(chars, k=4))
    part2 = "".join(random.choices(chars, k=4))
    return f"PERCH-{part1}-{part2}"


@router.post(
    "/admin/generate",
    response_model=GenerateCodesResponse,
    dependencies=[Depends(verify_admin_api_key)],
)
async def generate_premium_codes(
    request_obj: GenerateCodesRequest,
    db: AsyncSession = Depends(get_db),
):
    """프리미엄 코드 생성 (관리자 전용). X-Admin-API-Key 헤더 필수."""
    generated = []
    for _ in range(request_obj.count):
        # 중복 방지: 최대 10회 재시도
        for _ in range(10):
            code = _generate_code()
            existing = await db.execute(
                select(PremiumCode).where(PremiumCode.code == code)
            )
            if existing.scalar_one_or_none() is None:
                break
        else:
            raise HTTPException(status_code=500, detail="코드 생성에 실패했습니다")

        premium_code = PremiumCode(
            code=code,
            duration_days=request_obj.duration_days,
        )
        db.add(premium_code)
        generated.append(GeneratedCodeItem(
            code=code,
            duration_days=request_obj.duration_days,
        ))

    await db.commit()
    return GenerateCodesResponse(codes=generated)


@router.get(
    "/admin/codes",
    response_model=list[PremiumCodeListItem],
    dependencies=[Depends(verify_admin_api_key)],
)
async def list_premium_codes(
    used: bool | None = None,
    db: AsyncSession = Depends(get_db),
):
    """프리미엄 코드 목록 조회 (관리자 전용). ?used=false로 미사용 코드만 필터."""
    query = (
        select(PremiumCode, User.email, User.nickname)
        .outerjoin(User, PremiumCode.used_by == User.id)
        .order_by(PremiumCode.created_at.desc())
    )
    if used is not None:
        query = query.where(PremiumCode.is_used == used)

    result = await db.execute(query)
    rows = result.all()
    return [
        PremiumCodeListItem(
            code=c.code,
            duration_days=c.duration_days,
            is_used=c.is_used,
            used_by_email=email,
            used_by_nickname=nickname,
            used_at=c.used_at,
            created_at=c.created_at,
        )
        for c, email, nickname in rows
    ]


@router.get(
    "/admin/users",
    response_model=list[AdminUserPremiumInfo],
    dependencies=[Depends(verify_admin_api_key)],
)
async def list_premium_users(
    email: str | None = None,
    tier: str | None = None,
    db: AsyncSession = Depends(get_db),
):
    """프리미엄 사용자 목록 조회. ?email=검색어 또는 ?tier=premium 으로 필터."""
    query = (
        select(User, UserTier)
        .outerjoin(UserTier, User.id == UserTier.user_id)
    )
    if email:
        query = query.where(User.email.ilike(f"%{email}%"))
    if tier:
        if tier == "premium":
            query = query.where(UserTier.tier == "premium")
        elif tier == "free":
            query = query.where(
                (UserTier.tier == "free") | (UserTier.user_id.is_(None))
            )
    query = query.order_by(User.created_at.desc())

    result = await db.execute(query)
    rows = result.all()
    return [
        AdminUserPremiumInfo(
            user_id=str(user.id),
            email=user.email,
            nickname=user.nickname,
            tier=ut.tier if ut else "free",
            premium_started_at=ut.premium_started_at if ut else None,
            premium_expires_at=ut.premium_expires_at if ut else None,
            activated_code=ut.activated_code if ut else None,
        )
        for user, ut in rows
    ]


@router.post(
    "/admin/users/{user_id}/revoke",
    response_model=RevokeResponse,
    dependencies=[Depends(verify_admin_api_key)],
)
async def revoke_user_premium(
    user_id: str,
    db: AsyncSession = Depends(get_db),
):
    """특정 사용자의 프리미엄 해지 (관리자 전용)."""
    try:
        uid = PyUUID(user_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="유효하지 않은 user_id 형식입니다")

    result = await db.execute(
        select(UserTier).where(UserTier.user_id == uid)
    )
    user_tier = result.scalar_one_or_none()
    if not user_tier:
        raise HTTPException(status_code=404, detail="해당 사용자의 티어 정보가 없습니다")
    if user_tier.tier == "free":
        raise HTTPException(status_code=400, detail="이미 무료 사용자입니다")

    now = datetime.now(timezone.utc)
    user_tier.tier = "free"
    user_tier.premium_expires_at = now
    user_tier.updated_at = now
    await db.commit()

    return RevokeResponse(success=True, message="프리미엄이 해지되었습니다")


@router.delete(
    "/admin/codes/{code}",
    response_model=DeleteCodeResponse,
    dependencies=[Depends(verify_admin_api_key)],
)
async def delete_premium_code(
    code: str,
    db: AsyncSession = Depends(get_db),
):
    """미사용 프리미엄 코드 삭제 (관리자 전용). 사용된 코드는 삭제 불가."""
    result = await db.execute(
        select(PremiumCode).where(PremiumCode.code == code.upper())
    )
    premium_code = result.scalar_one_or_none()
    if not premium_code:
        raise HTTPException(status_code=404, detail="코드를 찾을 수 없습니다")
    if premium_code.is_used:
        raise HTTPException(status_code=400, detail="이미 사용된 코드는 삭제할 수 없습니다")

    await db.delete(premium_code)
    await db.commit()
    return DeleteCodeResponse(success=True, message=f"코드 {premium_code.code}가 삭제되었습니다")


# ── Admin: 사용 분석 ──

# 모델별 예상 비용 (USD per 1K tokens, input+output 평균)
_MODEL_COST_PER_1K = {
    "gpt-4o-mini": 0.00015,
    "gpt-4.1-nano": 0.00010,
    "gpt-4o": 0.00250,
    "deepseek-chat": 0.00014,
}
# 모델별 평균 토큰 추정 (로그에 tokens_used 없을 때 사용)
_MODEL_AVG_TOKENS = {
    "gpt-4o-mini": 800,
    "gpt-4.1-nano": 1200,
    "gpt-4o": 1500,
    "deepseek-chat": 500,
}

# Premium 모델 목록 (이 모델을 사용하면 premium 사용자로 간주)
_PREMIUM_MODELS = {"gpt-4.1-nano", "gpt-4o"}


@router.get(
    "/admin/usage/summary",
    response_model=UsageSummaryResponse,
    dependencies=[Depends(verify_admin_api_key)],
)
async def get_usage_summary(
    days: int = Query(30, ge=1, le=365),
    db: AsyncSession = Depends(get_db),
):
    """기간별 AI 기능 사용 요약 (관리자 전용)."""
    since = datetime.now(timezone.utc) - timedelta(days=days)

    # Encyclopedia 집계
    enc_result = await db.execute(
        select(
            func.count().label("total"),
            func.count().filter(AiEncyclopediaLog.model.notin_(_PREMIUM_MODELS)).label("free_count"),
            func.count().filter(AiEncyclopediaLog.model.in_(_PREMIUM_MODELS)).label("premium_count"),
        ).where(AiEncyclopediaLog.created_at >= since)
    )
    enc_row = enc_result.one()

    # Vision 집계 (모드별)
    vision_result = await db.execute(
        select(AiVisionLog.mode, func.count().label("cnt"))
        .where(AiVisionLog.created_at >= since)
        .group_by(AiVisionLog.mode)
    )
    vision_rows = vision_result.all()
    vision_by_mode = {row.mode: row.cnt for row in vision_rows}
    vision_total = sum(vision_by_mode.values())

    # 활성 사용자 수 (encyclopedia + vision에서 DISTINCT user_id)
    enc_users = (
        select(AiEncyclopediaLog.user_id)
        .where(AiEncyclopediaLog.created_at >= since)
    )
    vis_users = (
        select(AiVisionLog.user_id)
        .where(AiVisionLog.created_at >= since)
    )
    combined = union_all(enc_users, vis_users).subquery()
    active_result = await db.execute(
        select(func.count(func.distinct(combined.c.user_id)))
    )
    active_users = active_result.scalar() or 0

    return UsageSummaryResponse(
        period_days=days,
        encyclopedia_total=enc_row.total,
        encyclopedia_free=enc_row.free_count,
        encyclopedia_premium=enc_row.premium_count,
        vision_total=vision_total,
        vision_by_mode=vision_by_mode,
        active_users=active_users,
    )


@router.get(
    "/admin/usage/daily",
    response_model=list[DailyUsageItem],
    dependencies=[Depends(verify_admin_api_key)],
)
async def get_daily_usage(
    days: int = Query(30, ge=1, le=365),
    db: AsyncSession = Depends(get_db),
):
    """일별 AI 기능 사용 추이 (관리자 전용)."""
    since = datetime.now(timezone.utc) - timedelta(days=days)

    # Encyclopedia 일별
    enc_daily = await db.execute(
        select(
            cast(AiEncyclopediaLog.created_at, Date).label("date"),
            func.count().label("cnt"),
        )
        .where(AiEncyclopediaLog.created_at >= since)
        .group_by(literal_column("date"))
        .order_by(literal_column("date"))
    )
    enc_map = {str(row.date): row.cnt for row in enc_daily.all()}

    # Vision 일별
    vis_daily = await db.execute(
        select(
            cast(AiVisionLog.created_at, Date).label("date"),
            func.count().label("cnt"),
        )
        .where(AiVisionLog.created_at >= since)
        .group_by(literal_column("date"))
        .order_by(literal_column("date"))
    )
    vis_map = {str(row.date): row.cnt for row in vis_daily.all()}

    # 날짜 범위 채우기
    all_dates = set(enc_map.keys()) | set(vis_map.keys())
    result = []
    for d in sorted(all_dates):
        result.append(DailyUsageItem(
            date=d,
            encyclopedia_count=enc_map.get(d, 0),
            vision_count=vis_map.get(d, 0),
        ))
    return result


@router.get(
    "/admin/usage/users",
    response_model=list[UserUsageItem],
    dependencies=[Depends(verify_admin_api_key)],
)
async def get_user_usage(
    days: int = Query(30, ge=1, le=365),
    limit: int = Query(50, ge=1, le=200),
    db: AsyncSession = Depends(get_db),
):
    """사용자별 AI 기능 사용 횟수 (관리자 전용)."""
    since = datetime.now(timezone.utc) - timedelta(days=days)

    # Encyclopedia 사용자별 집계
    enc_sub = (
        select(
            AiEncyclopediaLog.user_id,
            func.count().label("enc_count"),
            func.max(AiEncyclopediaLog.created_at).label("enc_last"),
        )
        .where(AiEncyclopediaLog.created_at >= since)
        .group_by(AiEncyclopediaLog.user_id)
        .subquery()
    )

    # Vision 사용자별 집계
    vis_sub = (
        select(
            AiVisionLog.user_id,
            func.count().label("vis_count"),
            func.max(AiVisionLog.created_at).label("vis_last"),
        )
        .where(AiVisionLog.created_at >= since)
        .group_by(AiVisionLog.user_id)
        .subquery()
    )

    # 사용자 정보 JOIN
    query = (
        select(
            User.id,
            User.email,
            User.nickname,
            UserTier.tier,
            func.coalesce(enc_sub.c.enc_count, 0).label("enc_count"),
            func.coalesce(vis_sub.c.vis_count, 0).label("vis_count"),
            func.greatest(enc_sub.c.enc_last, vis_sub.c.vis_last).label("last_used"),
        )
        .outerjoin(enc_sub, User.id == enc_sub.c.user_id)
        .outerjoin(vis_sub, User.id == vis_sub.c.user_id)
        .outerjoin(UserTier, User.id == UserTier.user_id)
        .where(
            (enc_sub.c.enc_count.isnot(None)) | (vis_sub.c.vis_count.isnot(None))
        )
        .order_by(
            (func.coalesce(enc_sub.c.enc_count, 0) + func.coalesce(vis_sub.c.vis_count, 0)).desc()
        )
        .limit(limit)
    )

    result = await db.execute(query)
    rows = result.all()
    return [
        UserUsageItem(
            user_id=str(row.id),
            email=row.email,
            nickname=row.nickname,
            tier=row.tier or "free",
            encyclopedia_count=row.enc_count,
            vision_count=row.vis_count,
            last_used_at=row.last_used,
        )
        for row in rows
    ]


@router.get(
    "/admin/usage/models",
    response_model=list[ModelUsageItem],
    dependencies=[Depends(verify_admin_api_key)],
)
async def get_model_usage(
    days: int = Query(30, ge=1, le=365),
    db: AsyncSession = Depends(get_db),
):
    """모델별 사용 통계 및 예상 비용 (관리자 전용)."""
    since = datetime.now(timezone.utc) - timedelta(days=days)

    # Encyclopedia 모델별
    enc_result = await db.execute(
        select(
            AiEncyclopediaLog.model,
            func.count().label("cnt"),
            func.avg(AiEncyclopediaLog.response_time_ms).label("avg_ms"),
        )
        .where(AiEncyclopediaLog.created_at >= since)
        .group_by(AiEncyclopediaLog.model)
    )

    # Vision 모델별
    vis_result = await db.execute(
        select(
            AiVisionLog.model,
            func.count().label("cnt"),
            func.avg(AiVisionLog.response_time_ms).label("avg_ms"),
        )
        .where(AiVisionLog.created_at >= since)
        .group_by(AiVisionLog.model)
    )

    # 합산
    model_stats: dict[str, dict] = {}
    for row in enc_result.all():
        model_stats[row.model] = {
            "count": row.cnt,
            "total_ms": row.avg_ms * row.cnt if row.avg_ms else 0,
        }
    for row in vis_result.all():
        if row.model in model_stats:
            existing = model_stats[row.model]
            new_total = existing["total_ms"] + (row.avg_ms * row.cnt if row.avg_ms else 0)
            new_count = existing["count"] + row.cnt
            model_stats[row.model] = {"count": new_count, "total_ms": new_total}
        else:
            model_stats[row.model] = {
                "count": row.cnt,
                "total_ms": row.avg_ms * row.cnt if row.avg_ms else 0,
            }

    result = []
    for model, stats in sorted(model_stats.items(), key=lambda x: x[1]["count"], reverse=True):
        count = stats["count"]
        avg_ms = int(stats["total_ms"] / count) if count > 0 else 0
        avg_tokens = _MODEL_AVG_TOKENS.get(model, 1000)
        cost_per_1k = _MODEL_COST_PER_1K.get(model, 0.001)
        estimated_cost = round(count * avg_tokens / 1000 * cost_per_1k, 4)
        result.append(ModelUsageItem(
            model=model,
            call_count=count,
            avg_response_ms=avg_ms,
            estimated_cost_usd=estimated_cost,
        ))
    return result


# ── Admin: 구독 거래 조회 ──


@router.get(
    "/admin/subscriptions/stats",
    response_model=SubscriptionStatsResponse,
    dependencies=[Depends(verify_admin_api_key)],
)
async def get_subscription_stats(
    db: AsyncSession = Depends(get_db),
):
    """활성 구독자 통계 (관리자 전용)."""
    now = datetime.now(timezone.utc)
    base = (
        select(UserTier)
        .where(UserTier.tier == "premium")
        .where(UserTier.source.in_(["app_store", "play_store"]))
        .where(UserTier.premium_expires_at.isnot(None))
        .where(UserTier.premium_expires_at >= now)
    )

    total_result = await db.execute(select(func.count()).select_from(base.subquery()))
    total = total_result.scalar() or 0

    apple_result = await db.execute(
        select(func.count()).select_from(
            base.where(UserTier.source == "app_store").subquery()
        )
    )
    apple = apple_result.scalar() or 0

    google_result = await db.execute(
        select(func.count()).select_from(
            base.where(UserTier.source == "play_store").subquery()
        )
    )
    google = google_result.scalar() or 0

    product_result = await db.execute(
        select(UserTier.store_product_id, func.count())
        .where(UserTier.tier == "premium")
        .where(UserTier.source.in_(["app_store", "play_store"]))
        .where(UserTier.premium_expires_at.isnot(None))
        .where(UserTier.premium_expires_at >= now)
        .where(UserTier.store_product_id.isnot(None))
        .group_by(UserTier.store_product_id)
    )
    by_product = {row[0]: row[1] for row in product_result.all()}

    return SubscriptionStatsResponse(
        total_subscribers=total,
        apple_subscribers=apple,
        google_subscribers=google,
        by_product=by_product,
    )


@router.get(
    "/admin/subscriptions/transactions",
    response_model=list[SubscriptionTransactionItem],
    dependencies=[Depends(verify_admin_api_key)],
)
async def list_subscription_transactions(
    store: str | None = None,
    event_type: str | None = None,
    days: int = Query(30, ge=1, le=365),
    limit: int = Query(50, ge=1, le=500),
    db: AsyncSession = Depends(get_db),
):
    """구독 거래 로그 조회 (관리자 전용)."""
    since = datetime.now(timezone.utc) - timedelta(days=days)

    query = (
        select(SubscriptionTransaction, User.email)
        .outerjoin(User, SubscriptionTransaction.user_id == User.id)
        .where(SubscriptionTransaction.created_at >= since)
    )
    if store:
        query = query.where(SubscriptionTransaction.store == store)
    if event_type:
        query = query.where(SubscriptionTransaction.event_type == event_type)

    query = query.order_by(SubscriptionTransaction.created_at.desc()).limit(limit)

    result = await db.execute(query)
    rows = result.all()
    return [
        SubscriptionTransactionItem(
            id=str(tx.id),
            user_id=str(tx.user_id),
            user_email=email,
            store=tx.store,
            product_id=tx.product_id,
            transaction_id=tx.transaction_id,
            original_transaction_id=tx.original_transaction_id,
            event_type=tx.event_type,
            purchased_at=tx.purchased_at,
            expires_at=tx.expires_at,
            created_at=tx.created_at,
        )
        for tx, email in rows
    ]


# ── Admin: Phase 2 KPI ──


@router.get(
    "/admin/subscriptions/summary",
    response_model=SubscriptionSummaryResponse,
    dependencies=[Depends(verify_admin_api_key)],
)
async def get_subscription_summary(
    days: int = Query(30, ge=1, le=365),
    db: AsyncSession = Depends(get_db),
):
    """구독 소스별 프리미엄 사용자 수 + 기간 내 이벤트 통계 (관리자 전용)."""
    now = datetime.now(timezone.utc)
    since = now - timedelta(days=days)

    # 1. 활성 프리미엄 사용자 수
    total_result = await db.execute(
        select(func.count())
        .select_from(UserTier)
        .where(
            UserTier.tier == "premium",
            UserTier.premium_expires_at.isnot(None),
            UserTier.premium_expires_at >= now,
        )
    )
    total_premium = total_result.scalar() or 0

    # 2. 소스별 분류
    source_result = await db.execute(
        select(UserTier.source, func.count())
        .where(
            UserTier.tier == "premium",
            UserTier.premium_expires_at.isnot(None),
            UserTier.premium_expires_at >= now,
        )
        .group_by(UserTier.source)
    )
    by_source = {row[0] or "unknown": row[1] for row in source_result.all()}

    # 3. 기간 내 신규 구독 (purchase 이벤트)
    new_result = await db.execute(
        select(func.count())
        .select_from(SubscriptionTransaction)
        .where(
            SubscriptionTransaction.created_at >= since,
            SubscriptionTransaction.event_type == "purchase",
        )
    )
    daily_new = new_result.scalar() or 0

    # 4. 기간 내 복원 (restore 이벤트)
    restore_result = await db.execute(
        select(func.count())
        .select_from(SubscriptionTransaction)
        .where(
            SubscriptionTransaction.created_at >= since,
            SubscriptionTransaction.event_type == "restore",
        )
    )
    daily_restores = restore_result.scalar() or 0

    # 5. 기간 내 만료 (downgrade 여부 무관 — premium_expires_at 기준)
    exp_result = await db.execute(
        select(func.count())
        .select_from(UserTier)
        .where(
            UserTier.premium_expires_at >= since,
            UserTier.premium_expires_at < now,
        )
    )
    daily_exp = exp_result.scalar() or 0

    # 6. 기간 내 자동갱신 취소
    cancel_result = await db.execute(
        select(func.count())
        .select_from(UserTier)
        .where(
            UserTier.updated_at >= since,
            UserTier.auto_renew_status == False,  # noqa: E712
            UserTier.tier == "premium",
        )
    )
    daily_cancel = cancel_result.scalar() or 0

    return SubscriptionSummaryResponse(
        total_premium_users=total_premium,
        by_source=by_source,
        daily_new_subscriptions=daily_new,
        daily_restores=daily_restores,
        daily_expirations=daily_exp,
        daily_cancellations=daily_cancel,
    )


@router.get(
    "/admin/conversion/funnel",
    response_model=ConversionFunnelResponse,
    dependencies=[Depends(verify_admin_api_key)],
)
async def get_conversion_funnel(
    db: AsyncSession = Depends(get_db),
):
    """전환율 퍼널 분석 (관리자 전용)."""
    now = datetime.now(timezone.utc)

    # 전체 사용자
    total_result = await db.execute(select(func.count()).select_from(User))
    total_users = total_result.scalar() or 0

    # 활성 프리미엄 사용자
    premium_result = await db.execute(
        select(func.count())
        .select_from(UserTier)
        .where(
            UserTier.tier == "premium",
            UserTier.premium_expires_at.isnot(None),
            UserTier.premium_expires_at >= now,
        )
    )
    premium_users = premium_result.scalar() or 0
    free_users = total_users - premium_users

    # 소스별 전환
    source_result = await db.execute(
        select(UserTier.source, func.count())
        .where(
            UserTier.tier == "premium",
            UserTier.premium_expires_at.isnot(None),
            UserTier.premium_expires_at >= now,
        )
        .group_by(UserTier.source)
    )
    by_source_conversion = {}
    for source, count in source_result.all():
        ratio = count / total_users if total_users > 0 else 0
        by_source_conversion[source or "unknown"] = {
            "count": count,
            "ratio": round(ratio, 4),
        }

    # 평균 전환 소요일 (가입 → 프리미엄 시작)
    from sqlalchemy import extract

    avg_days_result = await db.execute(
        select(
            func.avg(
                extract(
                    "epoch",
                    UserTier.premium_started_at - User.created_at,
                )
                / 86400
            )
        )
        .select_from(UserTier)
        .join(User, UserTier.user_id == User.id)
        .where(UserTier.premium_started_at.isnot(None))
    )
    avg_days = avg_days_result.scalar()
    avg_days = round(avg_days, 2) if avg_days else None

    return ConversionFunnelResponse(
        total_users=total_users,
        free_users=free_users,
        premium_users=premium_users,
        by_source_conversion=by_source_conversion,
        avg_days_to_conversion=avg_days,
    )


@router.get(
    "/admin/ai-cost",
    response_model=AiCostAnalysisResponse,
    dependencies=[Depends(verify_admin_api_key)],
)
async def get_ai_cost_analysis(
    days: int = Query(30, ge=1, le=365),
    db: AsyncSession = Depends(get_db),
):
    """AI 비용 vs 수익 분석 (관리자 전용)."""
    now = datetime.now(timezone.utc)
    since = now - timedelta(days=days)

    # Free vs Premium 모델별 AI 호출 수
    enc_result = await db.execute(
        select(AiEncyclopediaLog.model, func.count())
        .where(AiEncyclopediaLog.created_at >= since)
        .group_by(AiEncyclopediaLog.model)
    )
    free_calls = 0
    premium_calls = 0
    free_cost = 0.0
    premium_cost = 0.0
    for model, count in enc_result.all():
        avg_tokens = _MODEL_AVG_TOKENS.get(model, 1000)
        cost_per_1k = _MODEL_COST_PER_1K.get(model, 0.0002)
        model_cost = count * (avg_tokens / 1000) * cost_per_1k
        if model in _PREMIUM_MODELS:
            premium_calls += count
            premium_cost += model_cost
        else:
            free_calls += count
            free_cost += model_cost

    # Vision 호출: 요청 시점의 tier 기록 기준으로 free/premium 분리
    vision_avg_tokens = _MODEL_AVG_TOKENS.get("gpt-4o", 1500)
    vision_cost_per_1k = _MODEL_COST_PER_1K.get("gpt-4o", 0.0025)
    vis_by_tier = await db.execute(
        select(
            AiVisionLog.tier.label("tier"),
            func.count().label("cnt"),
        )
        .where(AiVisionLog.created_at >= since)
        .group_by(AiVisionLog.tier)
    )
    for tier_label, cnt in vis_by_tier.all():
        vis_cost = cnt * (vision_avg_tokens / 1000) * vision_cost_per_1k
        if tier_label == "premium":
            premium_calls += cnt
            premium_cost += vis_cost
        else:
            free_calls += cnt
            free_cost += vis_cost

    total_cost = free_cost + premium_cost

    # 고유 사용자 수 (Encyclopedia + Vision 통합, 티어별)
    # Free 사용자: free-model encyclopedia + free-tier vision
    free_enc_users = await db.execute(
        select(AiEncyclopediaLog.user_id)
        .where(
            AiEncyclopediaLog.created_at >= since,
            AiEncyclopediaLog.model.notin_(_PREMIUM_MODELS),
        )
        .distinct()
    )
    free_vis_users = await db.execute(
        select(AiVisionLog.user_id)
        .where(
            AiVisionLog.created_at >= since,
            AiVisionLog.tier != "premium",
        )
        .distinct()
    )
    free_user_ids = {r[0] for r in free_enc_users.all()} | {r[0] for r in free_vis_users.all()}
    free_user_count = len(free_user_ids)

    # Premium 사용자: premium-model encyclopedia + premium-tier vision
    premium_enc_users = await db.execute(
        select(AiEncyclopediaLog.user_id)
        .where(
            AiEncyclopediaLog.created_at >= since,
            AiEncyclopediaLog.model.in_(_PREMIUM_MODELS),
        )
        .distinct()
    )
    premium_vis_users = await db.execute(
        select(AiVisionLog.user_id)
        .where(
            AiVisionLog.created_at >= since,
            AiVisionLog.tier == "premium",
        )
        .distinct()
    )
    premium_user_ids = {r[0] for r in premium_enc_users.all()} | {r[0] for r in premium_vis_users.all()}
    premium_user_count = len(premium_user_ids)

    cost_per_free = free_cost / free_user_count if free_user_count > 0 else 0
    cost_per_premium = premium_cost / premium_user_count if premium_user_count > 0 else 0

    # 매출 추정 (활성 스토어 구독자 * $4.99/월 * days/30)
    active_subs_result = await db.execute(
        select(func.count())
        .select_from(UserTier)
        .where(
            UserTier.tier == "premium",
            UserTier.source.in_(["app_store", "play_store"]),
            UserTier.premium_expires_at >= now,
        )
    )
    active_subs = active_subs_result.scalar() or 0
    estimated_revenue = active_subs * 4.99 * (days / 30)

    cost_to_revenue = total_cost / estimated_revenue if estimated_revenue > 0 else None

    return AiCostAnalysisResponse(
        period_days=days,
        free_tier_ai_calls=free_calls,
        premium_tier_ai_calls=premium_calls,
        estimated_cost_per_free_user_usd=round(cost_per_free, 4),
        estimated_cost_per_premium_user_usd=round(cost_per_premium, 4),
        total_estimated_cost_usd=round(total_cost, 2),
        total_estimated_revenue_usd=round(estimated_revenue, 2),
        cost_to_revenue_ratio=round(cost_to_revenue, 4) if cost_to_revenue else None,
    )
