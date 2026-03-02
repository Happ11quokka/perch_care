import random
import string
from datetime import datetime, timezone
from uuid import UUID as PyUUID

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from slowapi import Limiter
from slowapi.util import get_remote_address

from app.database import get_db
from app.dependencies import get_current_user, verify_admin_api_key
from app.models.user import User
from app.models.premium_code import PremiumCode
from app.schemas.premium import (
    PremiumCodeRequest, PremiumCodeResponse, TierResponse,
    GenerateCodesRequest, GenerateCodesResponse, GeneratedCodeItem,
    PremiumCodeListItem, AdminUserPremiumInfo, RevokeResponse, DeleteCodeResponse,
)
from app.models.user_tier import UserTier
from app.services.tier_service import activate_premium_code, get_user_tier_info, PremiumActivationError
from app.utils.security import decode_token


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
