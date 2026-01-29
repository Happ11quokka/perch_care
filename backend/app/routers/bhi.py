from uuid import UUID
from datetime import date
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.schemas.bhi import BHIResponse
from app.services import bhi_service

router = APIRouter(prefix="/pets/{pet_id}/bhi", tags=["bhi"])


@router.get("/", response_model=BHIResponse)
async def get_bhi(
    pet_id: UUID,
    target_date: date = Query(default_factory=date.today),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await bhi_service.calculate_bhi(db, pet_id, target_date)
