import asyncio
import logging
from uuid import UUID
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import async_session_factory, get_db
from app.dependencies import get_current_user, get_current_user_id, get_current_tier
from app.models.device_token import DeviceToken
from app.models.user import User
from app.schemas.pet import PetCreate, PetUpdate, PetResponse
from app.schemas.health_summary import HealthSummaryResponse
from app.schemas.pet_insight import PetInsightResponse
from app.services import pet_service
from app.services.health_summary_service import get_health_summary
from app.services.insights_service import generate_weekly_insight, get_latest_insight

logger = logging.getLogger(__name__)

_INSIGHT_DEFAULT_LANG = "zh"
_INSIGHT_SUPPORTED_LANGS = ("ko", "en", "zh")
_pending_insight_keys: set[tuple[UUID, str]] = set()


async def _resolve_user_insight_language(db: AsyncSession, user_id: UUID) -> str:
    result = await db.execute(
        select(DeviceToken.language).where(DeviceToken.user_id == user_id).limit(1)
    )
    lang = result.scalar_one_or_none() or _INSIGHT_DEFAULT_LANG
    return lang if lang in _INSIGHT_SUPPORTED_LANGS else _INSIGHT_DEFAULT_LANG


async def _generate_insight_in_background(
    pet_id: UUID, user_id: UUID, language: str, insight_type: str,
) -> None:
    """백그라운드로 인사이트 생성. 새 DB 세션을 사용 (요청 세션은 이미 닫힘)."""
    key = (pet_id, insight_type)
    try:
        async with async_session_factory() as db:
            await generate_weekly_insight(db, pet_id, user_id, language)
            await db.commit()
            logger.info(
                "Lazy insight generated: pet=%s, type=%s, lang=%s",
                pet_id, insight_type, language,
            )
    except Exception as e:
        logger.warning(
            "Lazy insight generation failed: pet=%s, type=%s, error=%s",
            pet_id, insight_type, e,
        )
    finally:
        _pending_insight_keys.discard(key)

router = APIRouter(prefix="/pets", tags=["pets"])


@router.get("/", response_model=list[PetResponse])
async def list_pets(
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    # 핫패스: 배포된 클라가 로그인 직후 hasPets()로 호출. SELECT users 생략하고 단일 SELECT pets만.
    return await pet_service.get_my_pets(db, user_id)


@router.get("/active", response_model=PetResponse | None)
async def get_active_pet(
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    return await pet_service.get_active_pet(db, user_id)


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
    """주간 건강 인사이트. Premium 전용.

    Lazy generation: DB에 인사이트가 없으면 백그라운드로 생성을 트리거하고 즉시 None 반환.
    다음 호출 시 결과 반환됨. cron(`weekly_insights.py`)을 기다리지 않아도 됨.
    """
    if tier != "premium":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="프리미엄 전용 기능입니다",
        )
    await pet_service.get_pet_by_id(db, pet_id, current_user.id)

    insight = await get_latest_insight(db, pet_id, type)
    if insight:
        return insight

    # 백그라운드 생성 트리거 (in-memory dedup으로 동일 펫 중복 호출 방지)
    key = (pet_id, type)
    if key not in _pending_insight_keys:
        _pending_insight_keys.add(key)
        language = await _resolve_user_insight_language(db, current_user.id)
        asyncio.create_task(
            _generate_insight_in_background(pet_id, current_user.id, language, type)
        )
    return None
