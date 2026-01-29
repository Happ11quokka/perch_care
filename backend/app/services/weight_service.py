from uuid import UUID
from datetime import date
from sqlalchemy import select, delete, func, extract
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.dialects.postgresql import insert
from fastapi import HTTPException, status
from app.models.weight_record import WeightRecord
from app.schemas.weight import WeightRecordCreate


async def get_all_records(db: AsyncSession, pet_id: UUID) -> list[WeightRecord]:
    result = await db.execute(
        select(WeightRecord).where(WeightRecord.pet_id == pet_id).order_by(WeightRecord.recorded_date.desc())
    )
    return list(result.scalars().all())


async def get_record_by_date(db: AsyncSession, pet_id: UUID, recorded_date: date) -> WeightRecord | None:
    result = await db.execute(
        select(WeightRecord).where(WeightRecord.pet_id == pet_id, WeightRecord.recorded_date == recorded_date)
    )
    return result.scalar_one_or_none()


async def get_records_by_range(db: AsyncSession, pet_id: UUID, start: date, end: date) -> list[WeightRecord]:
    result = await db.execute(
        select(WeightRecord)
        .where(WeightRecord.pet_id == pet_id, WeightRecord.recorded_date >= start, WeightRecord.recorded_date <= end)
        .order_by(WeightRecord.recorded_date)
    )
    return list(result.scalars().all())


async def upsert_record(db: AsyncSession, pet_id: UUID, data: WeightRecordCreate) -> WeightRecord:
    stmt = insert(WeightRecord).values(
        pet_id=pet_id,
        recorded_date=data.recorded_date,
        weight=data.weight,
        memo=data.memo,
    )
    stmt = stmt.on_conflict_do_update(
        constraint="uq_weight_pet_date",
        set_={"weight": data.weight, "memo": data.memo},
    )
    await db.execute(stmt)
    await db.flush()

    result = await db.execute(
        select(WeightRecord).where(WeightRecord.pet_id == pet_id, WeightRecord.recorded_date == data.recorded_date)
    )
    return result.scalar_one()


async def delete_record_by_date(db: AsyncSession, pet_id: UUID, recorded_date: date) -> None:
    result = await db.execute(
        delete(WeightRecord).where(WeightRecord.pet_id == pet_id, WeightRecord.recorded_date == recorded_date)
    )
    if result.rowcount == 0:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Weight record not found")


async def get_monthly_averages(db: AsyncSession, pet_id: UUID, year: int) -> list[dict]:
    result = await db.execute(
        select(
            extract("month", WeightRecord.recorded_date).label("month"),
            func.avg(WeightRecord.weight).label("avg_weight"),
        )
        .where(WeightRecord.pet_id == pet_id, extract("year", WeightRecord.recorded_date) == year)
        .group_by(extract("month", WeightRecord.recorded_date))
        .order_by(extract("month", WeightRecord.recorded_date))
    )
    return [{"month": int(row.month), "avg_weight": float(row.avg_weight)} for row in result.all()]


async def get_weekly_data(db: AsyncSession, pet_id: UUID, year: int, month: int, week: int) -> list[dict]:
    result = await db.execute(
        select(WeightRecord.recorded_date, WeightRecord.weight)
        .where(
            WeightRecord.pet_id == pet_id,
            extract("year", WeightRecord.recorded_date) == year,
            extract("month", WeightRecord.recorded_date) == month,
            extract("week", WeightRecord.recorded_date) == week,
        )
        .order_by(WeightRecord.recorded_date)
    )
    return [{"recorded_date": row.recorded_date, "weight": float(row.weight)} for row in result.all()]
