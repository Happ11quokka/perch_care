import base64
import logging
from uuid import UUID
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Form, HTTPException, Query, Request, UploadFile, File, status
from slowapi import Limiter
from sqlalchemy.ext.asyncio import AsyncSession

from sqlalchemy import select

from app.config import get_settings
from app.database import get_db
from app.dependencies import get_current_user, get_current_tier
from app.models.pet import Pet
from app.models.user import User
from app.schemas.health_check import (
    HealthCheckCreate,
    HealthCheckResponse,
    VisionAnalyzeResponse,
    VisionMode,
    VisionPart,
)
from app.services import ai_service, health_check_service
from app.utils.file_storage import save_upload_file
from app.utils.security import decode_token

logger = logging.getLogger(__name__)
settings = get_settings()

_ALLOWED_MIME_TYPES = {"image/jpeg", "image/png", "image/webp"}


def _get_user_rate_limit_key(request: Request) -> str:
    """JWT에서 사용자 ID 추출하여 rate limit 키로 사용."""
    auth_header = request.headers.get("Authorization", "")
    if auth_header.startswith("Bearer "):
        payload = decode_token(auth_header[7:])
        if payload and payload.get("sub"):
            return f"user:{payload['sub']}"
    from slowapi.util import get_remote_address
    return f"ip:{get_remote_address(request)}"


limiter = Limiter(key_func=_get_user_rate_limit_key)

router = APIRouter(prefix="/pets/{pet_id}/health-checks", tags=["health-checks"])


@router.get("/", response_model=list[HealthCheckResponse])
async def list_health_checks(
    pet_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await health_check_service.get_all_checks(db, pet_id)


@router.get("/recent", response_model=list[HealthCheckResponse])
async def get_recent_checks(
    pet_id: UUID,
    limit: int = Query(10, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await health_check_service.get_recent_checks(db, pet_id, limit)


@router.get("/by-type/{check_type}", response_model=list[HealthCheckResponse])
async def get_checks_by_type(
    pet_id: UUID,
    check_type: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await health_check_service.get_checks_by_type(db, pet_id, check_type)


@router.get("/by-status/{check_status}", response_model=list[HealthCheckResponse])
async def get_checks_by_status(
    pet_id: UUID,
    check_status: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await health_check_service.get_checks_by_status(db, pet_id, check_status)


@router.get("/abnormal", response_model=list[HealthCheckResponse])
async def get_abnormal_checks(
    pet_id: UUID,
    limit: int = Query(10, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await health_check_service.get_abnormal_checks(db, pet_id, limit)


@router.get("/range", response_model=list[HealthCheckResponse])
async def get_checks_by_range(
    pet_id: UUID,
    start: datetime = Query(...),
    end: datetime = Query(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await health_check_service.get_checks_by_date_range(db, pet_id, start, end)


@router.get("/{check_id}", response_model=HealthCheckResponse)
async def get_health_check(
    pet_id: UUID,
    check_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await health_check_service.get_check_by_id(db, check_id)


@router.post("/", response_model=HealthCheckResponse, status_code=201)
async def create_health_check(
    pet_id: UUID,
    request: HealthCheckCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await health_check_service.create_check(db, pet_id, request)


@router.delete("/{check_id}", status_code=204)
async def delete_health_check(
    pet_id: UUID,
    check_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await health_check_service.delete_check(db, check_id)


@router.post("/upload-image")
async def upload_image(
    pet_id: UUID,
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
):
    url = await save_upload_file(file, str(current_user.id))
    return {"image_url": url}


@router.post("/analyze", response_model=VisionAnalyzeResponse, status_code=201)
@limiter.limit("10/minute")
async def analyze_health_check_vision(
    pet_id: UUID,
    request: Request,
    mode: str = Form(...),
    part: str | None = Form(None),
    notes: str | None = Form(None),
    image: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    tier: str = Depends(get_current_tier),
    db: AsyncSession = Depends(get_db),
):
    """GPT-4o Vision으로 이미지를 분석하여 건강 상태를 반환한다. 프리미엄 전용."""
    # 1. 티어 검증
    if tier != "premium":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="프리미엄 전용 기능입니다",
        )

    # 1-1. Pet 소유권 검증 (IDOR 방지)
    pet_result = await db.execute(
        select(Pet).where(Pet.id == pet_id, Pet.user_id == current_user.id)
    )
    if pet_result.scalar_one_or_none() is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="해당 펫을 찾을 수 없습니다",
        )

    # 2. mode 유효성 검증
    valid_modes = {m.value for m in VisionMode}
    if mode not in valid_modes:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"mode는 {', '.join(valid_modes)} 중 하나여야 합니다",
        )

    # 3. part 유효성 검증 (part_specific일 때 필수)
    valid_parts = {p.value for p in VisionPart}
    if mode == "part_specific":
        if not part or part not in valid_parts:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"part_specific 모드에서는 part가 {', '.join(valid_parts)} 중 하나여야 합니다",
            )

    # 4. 이미지 검증
    content_type = image.content_type or ""
    if content_type not in _ALLOWED_MIME_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"지원하지 않는 이미지 형식입니다. {', '.join(_ALLOWED_MIME_TYPES)}만 허용됩니다",
        )

    image_bytes = await image.read()
    if len(image_bytes) > settings.max_upload_size:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"이미지 크기가 {settings.max_upload_size // (1024 * 1024)}MB를 초과합니다",
        )

    if len(image_bytes) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="빈 이미지 파일입니다",
        )

    # 5. Base64 인코딩 (메모리에서 — 디스크 저장 없음)
    image_base64 = base64.b64encode(image_bytes).decode("utf-8")

    # 6. AI Vision 분석
    try:
        result = await ai_service.analyze_vision_health_check(
            db=db,
            pet_id=str(pet_id),
            user_id=current_user.id,
            image_base64=image_base64,
            mime_type=content_type,
            mode=mode,
            part=part,
            notes=notes,
            tier=tier,
        )
    except Exception as e:
        logger.error("Vision analysis failed: %s", e, exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="이미지 분석 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.",
        )

    # 7. DB 저장
    overall_status = result.get("overall_status", "normal")
    confidence = result.get("confidence_score")
    if isinstance(confidence, (int, float)):
        confidence = float(confidence)
    else:
        confidence = None

    check_data = HealthCheckCreate(
        check_type=mode,
        result=result,
        confidence_score=confidence,
        status=overall_status,
        checked_at=datetime.now(timezone.utc),
    )
    saved_check = await health_check_service.create_check(db, pet_id, check_data)

    return saved_check
