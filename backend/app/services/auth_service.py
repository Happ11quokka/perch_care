import secrets
from uuid import UUID
from datetime import datetime, timedelta, timezone
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from fastapi import HTTPException, status
from app.models.user import User
from app.models.social_account import SocialAccount
from app.utils.security import hash_password, verify_password, create_access_token, create_refresh_token, decode_token

# In-memory store for reset codes (in production, use Redis or DB table)
_reset_codes: dict[str, dict] = {}


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


async def request_password_reset(db: AsyncSession, email: str) -> dict:
    """Generate a 6-digit reset code and store it (10 min expiry)."""
    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()

    if not user:
        # Return success even if email not found (prevent user enumeration)
        return {"message": "If that email exists, a reset code has been sent."}

    code = f"{secrets.randbelow(10000):04d}"
    _reset_codes[email] = {
        "code": code,
        "expires_at": datetime.now(timezone.utc) + timedelta(minutes=10),
    }

    from app.utils.email import send_reset_code_email
    try:
        send_reset_code_email(email, code)
    except Exception as e:
        print(f"[ERROR] Failed to send email to {email}: {e}")

    return {"message": "If that email exists, a reset code has been sent."}


async def verify_reset_code(db: AsyncSession, email: str, code: str) -> dict:
    """Verify the reset code is valid and not expired."""
    stored = _reset_codes.get(email)
    if not stored:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired reset code")

    if datetime.now(timezone.utc) > stored["expires_at"]:
        _reset_codes.pop(email, None)
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired reset code")

    if stored["code"] != code:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired reset code")

    return {"message": "Code verified successfully"}


async def update_password(db: AsyncSession, email: str, code: str, new_password: str) -> dict:
    """Verify code again and update the user's password."""
    stored = _reset_codes.get(email)
    if not stored or datetime.now(timezone.utc) > stored["expires_at"] or stored["code"] != code:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired reset code")

    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    user.hashed_password = hash_password(new_password)
    await db.flush()

    # Remove used code
    _reset_codes.pop(email, None)

    return {"message": "Password updated successfully"}
