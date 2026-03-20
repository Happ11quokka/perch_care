from uuid import UUID
from datetime import date
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db
from app.dependencies import verify_pet_ownership
from app.models.pet import Pet
from app.schemas.water_record import WaterRecordCreate, WaterRecordResponse
from app.services import water_record_service

router = APIRouter(prefix="/pets/{pet_id}/water-records", tags=["water-records"])


@router.get("/", response_model=list[WaterRecordResponse])
async def list_water_records(
    pet_id: UUID,
    pet: Pet = Depends(verify_pet_ownership),
    db: AsyncSession = Depends(get_db),
):
    return await water_record_service.get_all_records(db, pet_id)


@router.get("/by-date/{recorded_date}", response_model=WaterRecordResponse | None)
async def get_water_by_date(
    pet_id: UUID,
    recorded_date: date,
    pet: Pet = Depends(verify_pet_ownership),
    db: AsyncSession = Depends(get_db),
):
    return await water_record_service.get_record_by_date(db, pet_id, recorded_date)


@router.get("/range", response_model=list[WaterRecordResponse])
async def get_water_by_range(
    pet_id: UUID,
    start: date = Query(...),
    end: date = Query(...),
    pet: Pet = Depends(verify_pet_ownership),
    db: AsyncSession = Depends(get_db),
):
    return await water_record_service.get_records_by_range(db, pet_id, start, end)


@router.post("/", response_model=WaterRecordResponse, status_code=201)
async def upsert_water(
    pet_id: UUID,
    request: WaterRecordCreate,
    pet: Pet = Depends(verify_pet_ownership),
    db: AsyncSession = Depends(get_db),
):
    return await water_record_service.upsert_record(db, pet_id, request)


@router.delete("/by-date/{recorded_date}", status_code=204)
async def delete_water_by_date(
    pet_id: UUID,
    recorded_date: date,
    pet: Pet = Depends(verify_pet_ownership),
    db: AsyncSession = Depends(get_db),
):
    await water_record_service.delete_record_by_date(db, pet_id, recorded_date)
