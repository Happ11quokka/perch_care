from typing import Literal
from uuid import UUID
from fastapi import Depends, Header, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db
from app.models.user import User
from app.utils.security import decode_token
from app.services.tier_service import get_user_tier
from app.models.pet import Pet
from app.config import get_settings

security = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db),
) -> User:
    token = credentials.credentials
    payload = decode_token(token)

    if not payload or payload.get("type") != "access":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired token")

    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token payload")

    result = await db.execute(select(User).where(User.id == UUID(user_id)))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")

    return user


async def verify_pet_ownership(
    pet_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Pet:
    """pet_id가 현재 사용자 소유인지 검증. IDOR 방지."""
    result = await db.execute(
        select(Pet).where(Pet.id == pet_id, Pet.user_id == current_user.id)
    )
    pet = result.scalar_one_or_none()
    if not pet:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Pet not found")
    return pet


async def verify_admin_api_key(
    x_admin_api_key: str = Header(..., alias="X-Admin-API-Key"),
) -> None:
    """관리자 API 키 검증. X-Admin-API-Key 헤더 필수."""
    settings = get_settings()
    if not settings.admin_api_key:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Admin API not configured")
    if x_admin_api_key != settings.admin_api_key:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Invalid admin API key")


async def get_current_tier(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Literal["free", "premium"]:
    """현재 사용자의 티어 반환 ('free' 또는 'premium')."""
    return await get_user_tier(db, current_user.id)
