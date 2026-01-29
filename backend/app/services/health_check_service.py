from uuid import UUID
from datetime import datetime
from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import HTTPException, status
from app.models.ai_health_check import AiHealthCheck
from app.schemas.health_check import HealthCheckCreate


async def get_all_checks(db: AsyncSession, pet_id: UUID) -> list[AiHealthCheck]:
    result = await db.execute(
        select(AiHealthCheck).where(AiHealthCheck.pet_id == pet_id).order_by(AiHealthCheck.checked_at.desc())
    )
    return list(result.scalars().all())


async def get_recent_checks(db: AsyncSession, pet_id: UUID, limit: int = 10) -> list[AiHealthCheck]:
    result = await db.execute(
        select(AiHealthCheck).where(AiHealthCheck.pet_id == pet_id).order_by(AiHealthCheck.checked_at.desc()).limit(limit)
    )
    return list(result.scalars().all())


async def get_checks_by_type(db: AsyncSession, pet_id: UUID, check_type: str) -> list[AiHealthCheck]:
    result = await db.execute(
        select(AiHealthCheck)
        .where(AiHealthCheck.pet_id == pet_id, AiHealthCheck.check_type == check_type)
        .order_by(AiHealthCheck.checked_at.desc())
    )
    return list(result.scalars().all())


async def get_checks_by_status(db: AsyncSession, pet_id: UUID, check_status: str) -> list[AiHealthCheck]:
    result = await db.execute(
        select(AiHealthCheck)
        .where(AiHealthCheck.pet_id == pet_id, AiHealthCheck.status == check_status)
        .order_by(AiHealthCheck.checked_at.desc())
    )
    return list(result.scalars().all())


async def get_abnormal_checks(db: AsyncSession, pet_id: UUID, limit: int = 10) -> list[AiHealthCheck]:
    result = await db.execute(
        select(AiHealthCheck)
        .where(AiHealthCheck.pet_id == pet_id, AiHealthCheck.status != "normal")
        .order_by(AiHealthCheck.checked_at.desc())
        .limit(limit)
    )
    return list(result.scalars().all())


async def get_checks_by_date_range(db: AsyncSession, pet_id: UUID, start: datetime, end: datetime) -> list[AiHealthCheck]:
    result = await db.execute(
        select(AiHealthCheck)
        .where(AiHealthCheck.pet_id == pet_id, AiHealthCheck.checked_at >= start, AiHealthCheck.checked_at <= end)
        .order_by(AiHealthCheck.checked_at.desc())
    )
    return list(result.scalars().all())


async def get_check_by_id(db: AsyncSession, check_id: UUID) -> AiHealthCheck:
    result = await db.execute(select(AiHealthCheck).where(AiHealthCheck.id == check_id))
    check = result.scalar_one_or_none()
    if not check:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Health check not found")
    return check


async def create_check(db: AsyncSession, pet_id: UUID, data: HealthCheckCreate) -> AiHealthCheck:
    check = AiHealthCheck(pet_id=pet_id, **data.model_dump())
    db.add(check)
    await db.flush()
    return check


async def delete_check(db: AsyncSession, check_id: UUID) -> None:
    check = await get_check_by_id(db, check_id)
    await db.delete(check)
