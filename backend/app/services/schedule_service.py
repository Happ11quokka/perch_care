from uuid import UUID
from datetime import date, datetime, time, timezone
from sqlalchemy import select, delete, extract
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import HTTPException, status
from app.models.schedule import Schedule
from app.schemas.schedule import ScheduleCreate, ScheduleUpdate


async def get_schedules(db: AsyncSession, pet_id: UUID, start: datetime | None = None, end: datetime | None = None) -> list[Schedule]:
    query = select(Schedule).where(Schedule.pet_id == pet_id)
    if start:
        query = query.where(Schedule.start_time >= start)
    if end:
        query = query.where(Schedule.end_time <= end)
    result = await db.execute(query.order_by(Schedule.start_time))
    return list(result.scalars().all())


async def get_schedules_by_month(db: AsyncSession, pet_id: UUID, year: int, month: int) -> list[Schedule]:
    result = await db.execute(
        select(Schedule)
        .where(
            Schedule.pet_id == pet_id,
            extract("year", Schedule.start_time) == year,
            extract("month", Schedule.start_time) == month,
        )
        .order_by(Schedule.start_time)
    )
    return list(result.scalars().all())


async def get_schedules_by_date(db: AsyncSession, pet_id: UUID, target_date: date) -> list[Schedule]:
    start = datetime.combine(target_date, time.min, tzinfo=timezone.utc)
    end = datetime.combine(target_date, time.max, tzinfo=timezone.utc)
    result = await db.execute(
        select(Schedule)
        .where(Schedule.pet_id == pet_id, Schedule.start_time >= start, Schedule.start_time <= end)
        .order_by(Schedule.start_time)
    )
    return list(result.scalars().all())


async def get_today_schedules(db: AsyncSession, pet_id: UUID) -> list[Schedule]:
    today = date.today()
    return await get_schedules_by_date(db, pet_id, today)


async def create_schedule(db: AsyncSession, pet_id: UUID, data: ScheduleCreate) -> Schedule:
    schedule = Schedule(pet_id=pet_id, **data.model_dump())
    db.add(schedule)
    await db.flush()
    return schedule


async def update_schedule(db: AsyncSession, schedule_id: UUID, data: ScheduleUpdate) -> Schedule:
    result = await db.execute(select(Schedule).where(Schedule.id == schedule_id))
    schedule = result.scalar_one_or_none()
    if not schedule:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Schedule not found")

    update_data = data.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(schedule, key, value)
    await db.flush()
    return schedule


async def delete_schedule(db: AsyncSession, schedule_id: UUID) -> None:
    result = await db.execute(select(Schedule).where(Schedule.id == schedule_id))
    schedule = result.scalar_one_or_none()
    if not schedule:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Schedule not found")
    await db.delete(schedule)


async def delete_schedules_by_pet(db: AsyncSession, pet_id: UUID) -> None:
    await db.execute(delete(Schedule).where(Schedule.pet_id == pet_id))
