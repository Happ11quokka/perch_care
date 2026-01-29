from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.schemas.user import ProfileResponse, ProfileUpdateRequest, SocialAccountResponse, SocialAccountLinkRequest
from app.services import user_service

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me/profile", response_model=ProfileResponse)
async def get_my_profile(current_user: User = Depends(get_current_user)):
    return current_user


@router.put("/me/profile", response_model=ProfileResponse)
async def update_my_profile(
    request: ProfileUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await user_service.update_profile(db, current_user.id, request.nickname, request.avatar_url)


@router.post("/me/social-accounts", response_model=SocialAccountResponse)
async def link_social_account(
    request: SocialAccountLinkRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await user_service.link_social_account(
        db,
        user_id=current_user.id,
        provider=request.provider,
        provider_id=request.provider_id,
        provider_email=request.provider_email,
    )


@router.get("/me/social-accounts", response_model=list[SocialAccountResponse])
async def get_social_accounts(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await user_service.get_social_accounts(db, current_user.id)


@router.delete("/me/social-accounts/{provider}", status_code=204)
async def unlink_social_account(
    provider: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await user_service.unlink_social_account(db, current_user.id, provider)
