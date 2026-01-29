from uuid import UUID
from datetime import date
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.schemas.weight import WeightRecordCreate, WeightRecordResponse, MonthlyAverage, WeeklyData
from app.services import weight_service

router = APIRouter(prefix="/pets/{pet_id}/weights", tags=["weights"])


@router.get("/", response_model=list[WeightRecordResponse])
async def list_weights(
    pet_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await weight_service.get_all_records(db, pet_id)


@router.get("/by-date/{recorded_date}", response_model=WeightRecordResponse | None)
async def get_weight_by_date(
    pet_id: UUID,
    recorded_date: date,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await weight_service.get_record_by_date(db, pet_id, recorded_date)


@router.get("/range", response_model=list[WeightRecordResponse])
async def get_weights_by_range(
    pet_id: UUID,
    start: date = Query(...),
    end: date = Query(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await weight_service.get_records_by_range(db, pet_id, start, end)


@router.post("/", response_model=WeightRecordResponse, status_code=201)
async def upsert_weight(
    pet_id: UUID,
    request: WeightRecordCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await weight_service.upsert_record(db, pet_id, request)


@router.delete("/by-date/{recorded_date}", status_code=204)
async def delete_weight_by_date(
    pet_id: UUID,
    recorded_date: date,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await weight_service.delete_record_by_date(db, pet_id, recorded_date)


@router.get("/monthly-averages", response_model=list[MonthlyAverage])
async def get_monthly_averages(
    pet_id: UUID,
    year: int = Query(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await weight_service.get_monthly_averages(db, pet_id, year)


@router.get("/weekly-data", response_model=list[WeeklyData])
async def get_weekly_data(
    pet_id: UUID,
    year: int = Query(...),
    month: int = Query(...),
    week: int = Query(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await weight_service.get_weekly_data(db, pet_id, year, month, week)
