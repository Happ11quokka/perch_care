from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.schemas.user import ProfileResponse, ProfileUpdateRequest, SocialAccountResponse, SocialAccountLinkRequest
from app.services import user_service
from app.utils.security import verify_google_id_token, verify_kakao_access_token

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me/profile", response_model=ProfileResponse)
async def get_my_profile(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(User)
        .where(User.id == current_user.id)
        .options(selectinload(User.social_accounts))
    )
    return result.scalar_one()


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
    provider_id = request.provider_id
    provider_email = request.provider_email

    if request.provider == "google" and request.id_token:
        google_info = verify_google_id_token(request.id_token)
        if not google_info:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid Google ID token")
        provider_id = google_info["sub"]
        provider_email = provider_email or google_info.get("email")
    elif request.provider == "kakao" and request.access_token:
        kakao_info = verify_kakao_access_token(request.access_token)
        if not kakao_info:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid Kakao access token")
        provider_id = kakao_info["sub"]
        provider_email = provider_email or kakao_info.get("email")

    if not provider_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Missing provider_id or id_token")

    return await user_service.link_social_account(
        db,
        user_id=current_user.id,
        provider=request.provider,
        provider_id=provider_id,
        provider_email=provider_email,
    )


@router.get("/me/social-accounts", response_model=list[SocialAccountResponse])
async def get_social_accounts(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await user_service.get_social_accounts(db, current_user.id)


@router.delete("/me", status_code=204)
async def delete_my_account(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await user_service.delete_user(db, current_user.id)


@router.delete("/me/social-accounts/{provider}", status_code=204)
async def unlink_social_account(
    provider: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await user_service.unlink_social_account(db, current_user.id, provider)
