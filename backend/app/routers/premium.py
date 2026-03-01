from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.ext.asyncio import AsyncSession
from slowapi import Limiter
from slowapi.util import get_remote_address

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.schemas.premium import PremiumCodeRequest, PremiumCodeResponse, TierResponse
from app.services.tier_service import activate_premium_code, get_user_tier_info, PremiumActivationError

limiter = Limiter(key_func=get_remote_address)
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
