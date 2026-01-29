from uuid import UUID
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from fastapi import HTTPException, status
from app.models.user import User
from app.models.social_account import SocialAccount
from app.utils.security import hash_password, verify_password, create_access_token, create_refresh_token, decode_token


async def signup(db: AsyncSession, email: str, password: str, nickname: str | None = None) -> dict:
    existing = await db.execute(select(User).where(User.email == email))
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email already registered")

    user = User(email=email, hashed_password=hash_password(password), nickname=nickname)
    db.add(user)
    await db.flush()

    return {
        "access_token": create_access_token(str(user.id)),
        "refresh_token": create_refresh_token(str(user.id)),
        "token_type": "bearer",
    }


async def login(db: AsyncSession, email: str, password: str) -> dict:
    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()

    if not user or not user.hashed_password or not verify_password(password, user.hashed_password):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password")

    return {
        "access_token": create_access_token(str(user.id)),
        "refresh_token": create_refresh_token(str(user.id)),
        "token_type": "bearer",
    }


async def refresh_tokens(db: AsyncSession, refresh_token: str) -> dict:
    payload = decode_token(refresh_token)
    if not payload or payload.get("type") != "refresh":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token")

    user_id = payload.get("sub")
    result = await db.execute(select(User).where(User.id == UUID(user_id)))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")

    return {
        "access_token": create_access_token(str(user.id)),
        "refresh_token": create_refresh_token(str(user.id)),
        "token_type": "bearer",
    }


async def oauth_login(db: AsyncSession, provider: str, provider_id: str, email: str | None = None, nickname: str | None = None) -> dict:
    # Look up by social account
    result = await db.execute(
        select(SocialAccount).where(
            SocialAccount.provider == provider,
            SocialAccount.provider_id == provider_id,
        )
    )
    social_account = result.scalar_one_or_none()

    if social_account:
        # Social account found - get user and return tokens
        result = await db.execute(select(User).where(User.id == social_account.user_id))
        user = result.scalar_one_or_none()
        if not user:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")

        return {
            "status": "authenticated",
            "access_token": create_access_token(str(user.id)),
            "refresh_token": create_refresh_token(str(user.id)),
            "token_type": "bearer",
        }

    # Social account not found - return signup_required
    return {
        "status": "signup_required",
        "provider": provider,
        "provider_id": provider_id,
        "provider_email": email,
    }
