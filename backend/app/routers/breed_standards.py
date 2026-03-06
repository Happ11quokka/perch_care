from uuid import UUID
from fastapi import APIRouter, Depends, Header, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.schemas.breed_standard import BreedStandardResponse, BreedStandardListItem
from app.services import breed_standard_service

router = APIRouter(prefix="/breed-standards", tags=["breed-standards"])


@router.get("/", response_model=list[BreedStandardListItem])
async def list_breeds(
    accept_language: str = Header(default="en"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get all active breed standards with localized display names."""
    locale = accept_language.split(',')[0].split('-')[0]
    return await breed_standard_service.get_all_breeds(db, locale)


@router.get("/{breed_id}", response_model=BreedStandardListItem)
async def get_breed(
    breed_id: UUID,
    accept_language: str = Header(default="en"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get specific breed standard with localized display name."""
    locale = accept_language.split(',')[0].split('-')[0]
    result = await breed_standard_service.get_breed_by_id_localized(db, breed_id, locale)
    if result is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Breed not found")
    return result
