from uuid import UUID
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user, get_current_tier
from app.models.user import User
from app.schemas.pet import PetCreate, PetUpdate, PetResponse
from app.schemas.health_summary import HealthSummaryResponse
from app.schemas.pet_insight import PetInsightResponse
from app.services import pet_service
from app.services.health_summary_service import get_health_summary
from app.services.insights_service import get_latest_insight

router = APIRouter(prefix="/pets", tags=["pets"])


@router.get("/", response_model=list[PetResponse])
async def list_pets(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await pet_service.get_my_pets(db, current_user.id)


@router.get("/active", response_model=PetResponse | None)
async def get_active_pet(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await pet_service.get_active_pet(db, current_user.id)


@router.get("/{pet_id}", response_model=PetResponse)
async def get_pet(
    pet_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await pet_service.get_pet_by_id(db, pet_id, current_user.id)


@router.post("/", response_model=PetResponse, status_code=201)
async def create_pet(
    request: PetCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await pet_service.create_pet(db, current_user.id, request)


@router.put("/{pet_id}", response_model=PetResponse)
async def update_pet(
    pet_id: UUID,
    request: PetUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await pet_service.update_pet(db, pet_id, current_user.id, request)


@router.delete("/{pet_id}", status_code=204)
async def delete_pet(
    pet_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await pet_service.delete_pet(db, pet_id, current_user.id)


@router.put("/{pet_id}/activate", response_model=PetResponse)
async def activate_pet(
    pet_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await pet_service.set_active_pet(db, pet_id, current_user.id)


@router.get("/{pet_id}/health-summary", response_model=HealthSummaryResponse)
async def get_pet_health_summary(
    pet_id: UUID,
    target_date: date = Query(default_factory=date.today),
    current_user: User = Depends(get_current_user),
    tier: str = Depends(get_current_tier),
    db: AsyncSession = Depends(get_db),
):
    """건강 변화 요약 카드 데이터. Free: 기본 요약, Premium: 상세 카드."""
    # 소유권 확인
    await pet_service.get_pet_by_id(db, pet_id, current_user.id)
    return await get_health_summary(db, pet_id, tier, target_date)


@router.get(
    "/{pet_id}/insights",
    response_model=PetInsightResponse | None,
    responses={403: {"description": "Premium only"}},
)
async def get_pet_insights(
    pet_id: UUID,
    type: str = Query(default="weekly", pattern="^(weekly)$"),
    current_user: User = Depends(get_current_user),
    tier: str = Depends(get_current_tier),
    db: AsyncSession = Depends(get_db),
):
    """주간 건강 인사이트. Premium 전용."""
    if tier != "premium":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="프리미엄 전용 기능입니다",
        )
    await pet_service.get_pet_by_id(db, pet_id, current_user.id)
    return await get_latest_insight(db, pet_id, type)
