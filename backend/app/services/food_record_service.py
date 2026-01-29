from uuid import UUID
from datetime import date
from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.dialects.postgresql import insert
from fastapi import HTTPException, status
from app.models.food_record import FoodRecord
from app.schemas.food_record import FoodRecordCreate


async def get_all_records(db: AsyncSession, pet_id: UUID) -> list[FoodRecord]:
    result = await db.execute(
        select(FoodRecord).where(FoodRecord.pet_id == pet_id).order_by(FoodRecord.recorded_date.desc())
    )
    return list(result.scalars().all())


async def get_record_by_date(db: AsyncSession, pet_id: UUID, recorded_date: date) -> FoodRecord | None:
    result = await db.execute(
        select(FoodRecord).where(FoodRecord.pet_id == pet_id, FoodRecord.recorded_date == recorded_date)
    )
    return result.scalar_one_or_none()


async def get_records_by_range(db: AsyncSession, pet_id: UUID, start: date, end: date) -> list[FoodRecord]:
    result = await db.execute(
        select(FoodRecord)
        .where(FoodRecord.pet_id == pet_id, FoodRecord.recorded_date >= start, FoodRecord.recorded_date <= end)
        .order_by(FoodRecord.recorded_date)
    )
    return list(result.scalars().all())


async def upsert_record(db: AsyncSession, pet_id: UUID, data: FoodRecordCreate) -> FoodRecord:
    stmt = insert(FoodRecord).values(
        pet_id=pet_id,
        recorded_date=data.recorded_date,
        total_grams=data.total_grams,
        target_grams=data.target_grams,
        count=data.count,
        entries_json=data.entries_json,
    )
    stmt = stmt.on_conflict_do_update(
        constraint="uq_food_pet_date",
        set_={
            "total_grams": data.total_grams,
            "target_grams": data.target_grams,
            "count": data.count,
            "entries_json": data.entries_json,
        },
    )
    await db.execute(stmt)
    await db.flush()

    result = await db.execute(
        select(FoodRecord).where(FoodRecord.pet_id == pet_id, FoodRecord.recorded_date == data.recorded_date)
    )
    return result.scalar_one()


async def delete_record_by_date(db: AsyncSession, pet_id: UUID, recorded_date: date) -> None:
    result = await db.execute(
        delete(FoodRecord).where(FoodRecord.pet_id == pet_id, FoodRecord.recorded_date == recorded_date)
    )
    if result.rowcount == 0:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Food record not found")
