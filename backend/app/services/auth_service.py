import secrets
from uuid import UUID
from datetime import datetime, timedelta, timezone
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from fastapi import HTTPException, status
from app.models.user import User
from app.models.social_account import SocialAccount
from app.models.password_reset_code import PasswordResetCode
from app.utils.security import hash_password, verify_password, create_access_token, create_refresh_token, decode_token

_MAX_RESET_ATTEMPTS = 5


async def signup(db: AsyncSession, email: str, password: str, nickname: str | None = None) -> dict:
    existing = await db.execute(select(User).where(User.email == email))
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Signup failed")

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

    # === Auto-create user for new OAuth users ===

    # Handle missing email
    if not email:
        # Kakao requires business app for email - return signup_required
        if provider == "kakao":
            return {
                "status": "signup_required",
                "provider": provider,
                "provider_id": provider_id,
                "provider_email": None,
            }
        # Apple/Google should always provide email, but fallback just in case
        email = f"{provider}_{provider_id[:16]}@oauth.placeholder"

    # Check if user with this email already exists
    result = await db.execute(select(User).where(User.email == email))
    existing_user = result.scalar_one_or_none()

    if existing_user:
        # Link social account to existing user
        new_social = SocialAccount(
            user_id=existing_user.id,
            provider=provider,
            provider_id=provider_id,
            provider_email=email,
        )
        db.add(new_social)
        await db.flush()

        return {
            "status": "authenticated",
            "access_token": create_access_token(str(existing_user.id)),
            "refresh_token": create_refresh_token(str(existing_user.id)),
            "token_type": "bearer",
        }

    # Create new user + social account
    final_nickname = nickname or email.split('@')[0]
    new_user = User(
        email=email,
        hashed_password=None,  # OAuth users don't have password
        nickname=final_nickname,
    )
    db.add(new_user)
    await db.flush()

    new_social = SocialAccount(
        user_id=new_user.id,
        provider=provider,
        provider_id=provider_id,
        provider_email=email,
    )
    db.add(new_social)
    await db.flush()

    return {
        "status": "authenticated",
        "access_token": create_access_token(str(new_user.id)),
        "refresh_token": create_refresh_token(str(new_user.id)),
        "token_type": "bearer",
    }


async def _get_reset_code(db: AsyncSession, email: str) -> PasswordResetCode | None:
    """이메일로 유효한 리셋 코드 조회."""
    result = await db.execute(
        select(PasswordResetCode).where(PasswordResetCode.email == email)
    )
    return result.scalar_one_or_none()


async def request_password_reset(db: AsyncSession, email: str) -> dict:
    """Generate a 6-digit reset code and store it in DB (10 min expiry)."""
    email = email.strip().lower()
    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()

    if not user:
        return {"message": "If that email exists, a reset code has been sent."}

    code = f"{secrets.randbelow(1000000):06d}"

    # 기존 코드가 있으면 교체 (upsert)
    existing = await _get_reset_code(db, email)
    if existing:
        existing.code = code
        existing.expires_at = datetime.now(timezone.utc) + timedelta(minutes=10)
        existing.attempts = 0
    else:
        db.add(PasswordResetCode(
            email=email,
            code=code,
            expires_at=datetime.now(timezone.utc) + timedelta(minutes=10),
        ))
    await db.flush()

    from app.utils.email import send_reset_code_email
    try:
        send_reset_code_email(email, code)
    except Exception as e:
        print(f"[ERROR] Failed to send email to {email}: {e}")

    return {"message": "If that email exists, a reset code has been sent."}


async def verify_reset_code(db: AsyncSession, email: str, code: str) -> dict:
    """Verify the reset code is valid and not expired. Max 5 attempts."""
    email = email.strip().lower()
    stored = await _get_reset_code(db, email)

    if not stored:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired reset code")

    if datetime.now(timezone.utc) > stored.expires_at:
        await db.delete(stored)
        await db.flush()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired reset code")

    if stored.attempts >= _MAX_RESET_ATTEMPTS:
        await db.delete(stored)
        await db.flush()
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail="Too many attempts. Please request a new code.")

    if stored.code != code:
        stored.attempts += 1
        await db.flush()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired reset code")

    return {"message": "Code verified successfully"}


async def update_password(db: AsyncSession, email: str, code: str, new_password: str) -> dict:
    """Verify code again and update the user's password."""
    email = email.strip().lower()
    stored = await _get_reset_code(db, email)

    if not stored or datetime.now(timezone.utc) > stored.expires_at:
        if stored:
            await db.delete(stored)
            await db.flush()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired reset code")

    if stored.attempts >= _MAX_RESET_ATTEMPTS:
        await db.delete(stored)
        await db.flush()
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail="Too many attempts. Please request a new code.")

    if stored.code != code:
        stored.attempts += 1
        await db.flush()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired reset code")

    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    user.hashed_password = hash_password(new_password)
    await db.delete(stored)
    await db.flush()

    return {"message": "Password updated successfully"}
