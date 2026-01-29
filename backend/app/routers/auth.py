from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db
from app.schemas.auth import SignUpRequest, LoginRequest, TokenResponse, RefreshRequest, OAuthRequest, OAuthLoginResponse
from app.services import auth_service

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
    # In production, verify id_token or exchange authorization_code with the provider
    # For now, this endpoint expects the frontend to handle OAuth and send the verified user info
    # TODO: Implement provider-specific token verification (Google, Apple, Kakao)
    return await auth_service.oauth_login(
        db,
        provider=provider,
        provider_id=request.id_token or request.authorization_code or "",
        email=request.email,
        nickname=None,
    )
