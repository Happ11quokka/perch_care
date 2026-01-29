from uuid import UUID
from datetime import date, datetime
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.schemas.schedule import ScheduleCreate, ScheduleUpdate, ScheduleResponse
from app.services import schedule_service

router = APIRouter(prefix="/pets/{pet_id}/schedules", tags=["schedules"])


@router.get("/", response_model=list[ScheduleResponse])
async def list_schedules(
    pet_id: UUID,
    start: datetime | None = Query(None),
    end: datetime | None = Query(None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await schedule_service.get_schedules(db, pet_id, start, end)


@router.get("/by-month", response_model=list[ScheduleResponse])
async def get_by_month(
    pet_id: UUID,
    year: int = Query(...),
    month: int = Query(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await schedule_service.get_schedules_by_month(db, pet_id, year, month)


@router.get("/by-date/{target_date}", response_model=list[ScheduleResponse])
async def get_by_date(
    pet_id: UUID,
    target_date: date,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await schedule_service.get_schedules_by_date(db, pet_id, target_date)


@router.get("/today", response_model=list[ScheduleResponse])
async def get_today(
    pet_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await schedule_service.get_today_schedules(db, pet_id)


@router.post("/", response_model=ScheduleResponse, status_code=201)
async def create_schedule(
    pet_id: UUID,
    request: ScheduleCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await schedule_service.create_schedule(db, pet_id, request)


@router.put("/{schedule_id}", response_model=ScheduleResponse)
async def update_schedule(
    pet_id: UUID,
    schedule_id: UUID,
    request: ScheduleUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await schedule_service.update_schedule(db, schedule_id, request)


@router.delete("/{schedule_id}", status_code=204)
async def delete_schedule(
    pet_id: UUID,
    schedule_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await schedule_service.delete_schedule(db, schedule_id)


@router.delete("/", status_code=204)
async def delete_all_schedules(
    pet_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await schedule_service.delete_schedules_by_pet(db, pet_id)
