from uuid import UUID
from datetime import date
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.schemas.food_record import FoodRecordCreate, FoodRecordResponse
from app.services import food_record_service

router = APIRouter(prefix="/pets/{pet_id}/food-records", tags=["food-records"])


@router.get("/", response_model=list[FoodRecordResponse])
async def list_food_records(
    pet_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await food_record_service.get_all_records(db, pet_id)


@router.get("/by-date/{recorded_date}", response_model=FoodRecordResponse | None)
async def get_food_by_date(
    pet_id: UUID,
    recorded_date: date,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await food_record_service.get_record_by_date(db, pet_id, recorded_date)


@router.get("/range", response_model=list[FoodRecordResponse])
async def get_food_by_range(
    pet_id: UUID,
    start: date = Query(...),
    end: date = Query(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await food_record_service.get_records_by_range(db, pet_id, start, end)


@router.post("/", response_model=FoodRecordResponse, status_code=201)
async def upsert_food(
    pet_id: UUID,
    request: FoodRecordCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await food_record_service.upsert_record(db, pet_id, request)


@router.delete("/by-date/{recorded_date}", status_code=204)
async def delete_food_by_date(
    pet_id: UUID,
    recorded_date: date,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await food_record_service.delete_record_by_date(db, pet_id, recorded_date)
