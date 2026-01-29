from uuid import UUID
from datetime import datetime
from fastapi import APIRouter, Depends, Query, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.schemas.health_check import HealthCheckCreate, HealthCheckResponse
from app.services import health_check_service
from app.utils.file_storage import save_upload_file

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
