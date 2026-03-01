from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.models.user_tier import UserTier
from app.schemas.premium import PremiumCodeRequest, PremiumCodeResponse, TierResponse
from app.services.tier_service import activate_premium_code, get_user_tier

router = APIRouter(prefix="/premium", tags=["premium"])


@router.get("/tier", response_model=TierResponse)
async def get_my_tier(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """현재 사용자의 티어 조회."""
    tier = await get_user_tier(db, current_user.id)
    expires_at = None
    if tier == "premium":
        result = await db.execute(
            select(UserTier).where(UserTier.user_id == current_user.id)
        )
        user_tier = result.scalar_one_or_none()
        if user_tier and user_tier.premium_expires_at:
            expires_at = user_tier.premium_expires_at.isoformat()
    return TierResponse(tier=tier, premium_expires_at=expires_at)


@router.post("/activate", response_model=PremiumCodeResponse)
async def activate_premium(
    request: PremiumCodeRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """프리미엄 코드 활성화. 사용자당 5회/분 rate limit 권장."""
    result = await activate_premium_code(db, current_user.id, request.code)
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result["error"])
    return PremiumCodeResponse(success=True, expires_at=result.get("expires_at"))
