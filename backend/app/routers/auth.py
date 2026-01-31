from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db
from app.schemas.auth import (
    SignUpRequest, LoginRequest, TokenResponse, RefreshRequest,
    OAuthRequest, OAuthLoginResponse,
    ResetPasswordRequest, VerifyResetCodeRequest, UpdatePasswordRequest,
)
from app.services import auth_service
from app.utils.security import verify_google_id_token, verify_kakao_access_token

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/signup", response_model=TokenResponse)
async def signup(request: SignUpRequest, db: AsyncSession = Depends(get_db)):
    return await auth_service.signup(db, request.email, request.password, request.nickname)


@router.post("/login", response_model=TokenResponse)
async def login(request: LoginRequest, db: AsyncSession = Depends(get_db)):
    return await auth_service.login(db, request.email, request.password)


@router.post("/refresh", response_model=TokenResponse)
async def refresh(request: RefreshRequest, db: AsyncSession = Depends(get_db)):
    return await auth_service.refresh_tokens(db, request.refresh_token)


@router.post("/oauth/{provider}", response_model=OAuthLoginResponse)
async def oauth_login(provider: str, request: OAuthRequest, db: AsyncSession = Depends(get_db)):
    provider_id: str | None = None
    email = request.email

    if provider == "google" and request.id_token:
        google_info = verify_google_id_token(request.id_token)
        if not google_info:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid Google ID token")
        provider_id = google_info["sub"]
        email = email or google_info.get("email")
    elif provider == "kakao" and request.access_token:
        kakao_info = verify_kakao_access_token(request.access_token)
        if not kakao_info:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid Kakao access token")
        provider_id = kakao_info["sub"]
        email = email or kakao_info.get("email")
    else:
        provider_id = request.authorization_code or ""

    if not provider_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Missing provider credentials")

    return await auth_service.oauth_login(
        db,
        provider=provider,
        provider_id=provider_id,
        email=email,
        nickname=None,
    )


@router.post("/reset-password")
async def reset_password(request: ResetPasswordRequest, db: AsyncSession = Depends(get_db)):
    return await auth_service.request_password_reset(db, request.email)


@router.post("/verify-reset-code")
async def verify_reset_code(request: VerifyResetCodeRequest, db: AsyncSession = Depends(get_db)):
    if not request.email:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email is required")
    return await auth_service.verify_reset_code(db, request.email, request.code)


@router.post("/update-password")
async def update_password(request: UpdatePasswordRequest, db: AsyncSession = Depends(get_db)):
    if not request.email:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email is required")
    return await auth_service.update_password(db, request.email, request.code, request.new_password)
