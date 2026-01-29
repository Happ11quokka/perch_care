from uuid import UUID
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import HTTPException, status
from app.models.user import User
from app.models.social_account import SocialAccount


async def get_profile(db: AsyncSession, user_id: UUID) -> User:
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return user


async def update_profile(db: AsyncSession, user_id: UUID, nickname: str | None = None, avatar_url: str | None = None) -> User:
    user = await get_profile(db, user_id)
    if nickname is not None:
        user.nickname = nickname
    if avatar_url is not None:
        user.avatar_url = avatar_url
    await db.flush()
    return user


async def link_social_account(
    db: AsyncSession,
    user_id: UUID,
    provider: str,
    provider_id: str,
    provider_email: str | None = None,
) -> SocialAccount:
    # Check if this social account is already linked to any user
    result = await db.execute(
        select(SocialAccount).where(
            SocialAccount.provider == provider,
            SocialAccount.provider_id == provider_id,
        )
    )
    existing = result.scalar_one_or_none()
    if existing:
        if existing.user_id == user_id:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="This social account is already linked to your account",
            )
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This social account is already linked to another user",
        )

    social_account = SocialAccount(
        user_id=user_id,
        provider=provider,
        provider_id=provider_id,
        provider_email=provider_email,
    )
    db.add(social_account)
    await db.flush()
    return social_account


async def get_social_accounts(db: AsyncSession, user_id: UUID) -> list[SocialAccount]:
    result = await db.execute(
        select(SocialAccount).where(SocialAccount.user_id == user_id)
    )
    return list(result.scalars().all())


async def unlink_social_account(db: AsyncSession, user_id: UUID, provider: str) -> None:
    result = await db.execute(
        select(SocialAccount).where(
            SocialAccount.user_id == user_id,
            SocialAccount.provider == provider,
        )
    )
    social_account = result.scalar_one_or_none()
    if not social_account:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"No linked {provider} account found",
        )
    await db.delete(social_account)
    await db.flush()
