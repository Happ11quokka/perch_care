from uuid import UUID
from datetime import date
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.schemas.daily_record import DailyRecordCreate, DailyRecordResponse
from app.services import daily_record_service

router = APIRouter(prefix="/pets/{pet_id}/daily-records", tags=["daily-records"])


@router.get("/", response_model=list[DailyRecordResponse])
async def list_daily_records(
    pet_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await daily_record_service.get_all_records(db, pet_id)


@router.get("/by-date/{recorded_date}", response_model=DailyRecordResponse | None)
async def get_record_by_date(
    pet_id: UUID,
    recorded_date: date,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await daily_record_service.get_record_by_date(db, pet_id, recorded_date)


@router.get("/by-month", response_model=list[DailyRecordResponse])
async def get_records_by_month(
    pet_id: UUID,
    year: int = Query(...),
    month: int = Query(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await daily_record_service.get_records_by_month(db, pet_id, year, month)


@router.get("/range", response_model=list[DailyRecordResponse])
async def get_records_by_range(
    pet_id: UUID,
    start: date = Query(...),
    end: date = Query(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await daily_record_service.get_records_by_range(db, pet_id, start, end)


@router.post("/", response_model=DailyRecordResponse, status_code=201)
async def upsert_daily_record(
    pet_id: UUID,
    request: DailyRecordCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await daily_record_service.upsert_record(db, pet_id, request)


@router.delete("/{record_id}", status_code=204)
async def delete_record(
    pet_id: UUID,
    record_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await daily_record_service.delete_record(db, record_id)


@router.delete("/by-date/{recorded_date}", status_code=204)
async def delete_record_by_date(
    pet_id: UUID,
    recorded_date: date,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await daily_record_service.delete_record_by_date(db, pet_id, recorded_date)
