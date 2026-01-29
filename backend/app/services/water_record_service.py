from uuid import UUID
from datetime import date
from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.dialects.postgresql import insert
from fastapi import HTTPException, status
from app.models.water_record import WaterRecord
from app.schemas.water_record import WaterRecordCreate


async def get_all_records(db: AsyncSession, pet_id: UUID) -> list[WaterRecord]:
    result = await db.execute(
        select(WaterRecord).where(WaterRecord.pet_id == pet_id).order_by(WaterRecord.recorded_date.desc())
    )
    return list(result.scalars().all())


async def get_record_by_date(db: AsyncSession, pet_id: UUID, recorded_date: date) -> WaterRecord | None:
    result = await db.execute(
        select(WaterRecord).where(WaterRecord.pet_id == pet_id, WaterRecord.recorded_date == recorded_date)
    )
    return result.scalar_one_or_none()


async def get_records_by_range(db: AsyncSession, pet_id: UUID, start: date, end: date) -> list[WaterRecord]:
    result = await db.execute(
        select(WaterRecord)
        .where(WaterRecord.pet_id == pet_id, WaterRecord.recorded_date >= start, WaterRecord.recorded_date <= end)
        .order_by(WaterRecord.recorded_date)
    )
    return list(result.scalars().all())


async def upsert_record(db: AsyncSession, pet_id: UUID, data: WaterRecordCreate) -> WaterRecord:
    stmt = insert(WaterRecord).values(
        pet_id=pet_id,
        recorded_date=data.recorded_date,
        total_ml=data.total_ml,
        target_ml=data.target_ml,
        count=data.count,
    )
    stmt = stmt.on_conflict_do_update(
        constraint="uq_water_pet_date",
        set_={
            "total_ml": data.total_ml,
            "target_ml": data.target_ml,
            "count": data.count,
        },
    )
    await db.execute(stmt)
    await db.flush()

    result = await db.execute(
        select(WaterRecord).where(WaterRecord.pet_id == pet_id, WaterRecord.recorded_date == data.recorded_date)
    )
    return result.scalar_one()


async def delete_record_by_date(db: AsyncSession, pet_id: UUID, recorded_date: date) -> None:
    result = await db.execute(
        delete(WaterRecord).where(WaterRecord.pet_id == pet_id, WaterRecord.recorded_date == recorded_date)
    )
    if result.rowcount == 0:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Water record not found")
