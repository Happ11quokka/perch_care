from fastapi import APIRouter, Depends, HTTPException, Request, status
from slowapi import Limiter
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db
from app.schemas.auth import (
    SignUpRequest, LoginRequest, TokenResponse, RefreshRequest,
    OAuthRequest, OAuthLoginResponse,
    ResetPasswordRequest, VerifyResetCodeRequest, UpdatePasswordRequest,
)
from app.services import auth_service
from app.utils.security import verify_google_id_token, verify_kakao_access_token, verify_apple_id_token, decode_token


def _get_auth_rate_limit_key(request: Request) -> str:
    """IP 기반 rate limit 키. 인증 전이므로 JWT 없이 IP만 사용."""
    from slowapi.util import get_remote_address
    return f"ip:{get_remote_address(request)}"


limiter = Limiter(key_func=_get_auth_rate_limit_key)

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/signup", response_model=TokenResponse)
@limiter.limit("5/minute")
async def signup(request: SignUpRequest, req: Request, db: AsyncSession = Depends(get_db)):
    return await auth_service.signup(db, request.email, request.password, request.nickname)


@router.post("/login", response_model=TokenResponse)
@limiter.limit("10/minute")
async def login(request: LoginRequest, req: Request, db: AsyncSession = Depends(get_db)):
    return await auth_service.login(db, request.email, request.password)


@router.post("/refresh", response_model=TokenResponse)
async def refresh(request: RefreshRequest, db: AsyncSession = Depends(get_db)):
    return await auth_service.refresh_tokens(db, request.refresh_token)


@router.post("/oauth/{provider}", response_model=OAuthLoginResponse)
@limiter.limit("10/minute")
async def oauth_login(provider: str, request: OAuthRequest, req: Request, db: AsyncSession = Depends(get_db)):
    provider_id: str | None = None
    email = request.email
    nickname = request.full_name  # Apple provides full_name on first login

    if provider == "google" and request.id_token:
        google_info = verify_google_id_token(request.id_token)
        if not google_info:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid Google ID token")
        provider_id = google_info["sub"]
        email = email or google_info.get("email")
        nickname = nickname or google_info.get("name")  # Extract name from Google ID token
    elif provider == "apple" and request.id_token:
        apple_info = verify_apple_id_token(request.id_token)
        if not apple_info:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid Apple ID token")
        provider_id = apple_info["sub"]
        email = email or apple_info.get("email")
        # nickname already set from request.full_name for Apple
    elif provider == "kakao" and request.access_token:
        kakao_info = verify_kakao_access_token(request.access_token)
        if not kakao_info:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid Kakao access token")
        provider_id = kakao_info["sub"]
        email = email or kakao_info.get("email")
        nickname = nickname or kakao_info.get("nickname")  # Extract nickname from Kakao
    else:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Unsupported provider or missing credentials")

    if not provider_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Missing provider credentials")

    return await auth_service.oauth_login(
        db,
        provider=provider,
        provider_id=provider_id,
        email=email,
        nickname=nickname,
    )


@router.post("/reset-password")
@limiter.limit("3/minute")
async def reset_password(request: ResetPasswordRequest, req: Request, db: AsyncSession = Depends(get_db)):
    return await auth_service.request_password_reset(db, request.email)


@router.post("/verify-reset-code")
@limiter.limit("5/minute")
async def verify_reset_code(request: VerifyResetCodeRequest, req: Request, db: AsyncSession = Depends(get_db)):
    if not request.email:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email is required")
    return await auth_service.verify_reset_code(db, request.email, request.code)


@router.post("/update-password")
@limiter.limit("5/minute")
async def update_password(request: UpdatePasswordRequest, req: Request, db: AsyncSession = Depends(get_db)):
    if not request.email:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email is required")
    return await auth_service.update_password(db, request.email, request.code, request.new_password)
