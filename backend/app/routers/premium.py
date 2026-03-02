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
    GenerateCodesRequest, GenerateCodesResponse, GeneratedCodeItem,
    PremiumCodeListItem, AdminUserPremiumInfo, RevokeResponse, DeleteCodeResponse,
    UsageSummaryResponse, DailyUsageItem, UserUsageItem, ModelUsageItem,
)
from app.models.user_tier import UserTier
from app.services.tier_service import activate_premium_code, get_user_tier_info, PremiumActivationError
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
    """현재 사용자의 티어 조회."""
    info = await get_user_tier_info(db, current_user.id)
    return TierResponse(tier=info["tier"], premium_expires_at=info["premium_expires_at"])


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
