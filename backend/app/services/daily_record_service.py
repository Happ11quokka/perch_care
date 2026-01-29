from uuid import UUID
from datetime import date
from sqlalchemy import select, delete, extract
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.dialects.postgresql import insert
from fastapi import HTTPException, status
from app.models.daily_record import DailyRecord
from app.schemas.daily_record import DailyRecordCreate


async def get_all_records(db: AsyncSession, pet_id: UUID) -> list[DailyRecord]:
    result = await db.execute(
        select(DailyRecord).where(DailyRecord.pet_id == pet_id).order_by(DailyRecord.recorded_date.desc())
    )
    return list(result.scalars().all())


async def get_record_by_date(db: AsyncSession, pet_id: UUID, recorded_date: date) -> DailyRecord | None:
    result = await db.execute(
        select(DailyRecord).where(DailyRecord.pet_id == pet_id, DailyRecord.recorded_date == recorded_date)
    )
    return result.scalar_one_or_none()


async def get_records_by_month(db: AsyncSession, pet_id: UUID, year: int, month: int) -> list[DailyRecord]:
    result = await db.execute(
        select(DailyRecord)
        .where(
            DailyRecord.pet_id == pet_id,
            extract("year", DailyRecord.recorded_date) == year,
            extract("month", DailyRecord.recorded_date) == month,
        )
        .order_by(DailyRecord.recorded_date)
    )
    return list(result.scalars().all())


async def get_records_by_range(db: AsyncSession, pet_id: UUID, start: date, end: date) -> list[DailyRecord]:
    result = await db.execute(
        select(DailyRecord)
        .where(DailyRecord.pet_id == pet_id, DailyRecord.recorded_date >= start, DailyRecord.recorded_date <= end)
        .order_by(DailyRecord.recorded_date)
    )
    return list(result.scalars().all())


async def upsert_record(db: AsyncSession, pet_id: UUID, data: DailyRecordCreate) -> DailyRecord:
    stmt = insert(DailyRecord).values(
        pet_id=pet_id,
        recorded_date=data.recorded_date,
        notes=data.notes,
        mood=data.mood,
        activity_level=data.activity_level,
    )
    stmt = stmt.on_conflict_do_update(
        constraint="uq_daily_pet_date",
        set_={"notes": data.notes, "mood": data.mood, "activity_level": data.activity_level},
    )
    await db.execute(stmt)
    await db.flush()

    result = await db.execute(
        select(DailyRecord).where(DailyRecord.pet_id == pet_id, DailyRecord.recorded_date == data.recorded_date)
    )
    return result.scalar_one()


async def delete_record(db: AsyncSession, record_id: UUID) -> None:
    result = await db.execute(select(DailyRecord).where(DailyRecord.id == record_id))
    record = result.scalar_one_or_none()
    if not record:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Daily record not found")
    await db.delete(record)


async def delete_record_by_date(db: AsyncSession, pet_id: UUID, recorded_date: date) -> None:
    result = await db.execute(
        delete(DailyRecord).where(DailyRecord.pet_id == pet_id, DailyRecord.recorded_date == recorded_date)
    )
    if result.rowcount == 0:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Daily record not found")
