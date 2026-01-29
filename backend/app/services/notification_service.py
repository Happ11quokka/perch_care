from uuid import UUID
from sqlalchemy import select, update, delete, func
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import HTTPException, status
from app.models.notification import Notification
from app.schemas.notification import NotificationCreate


async def create_notification(db: AsyncSession, user_id: UUID, data: NotificationCreate) -> Notification:
    notification = Notification(user_id=user_id, **data.model_dump())
    db.add(notification)
    await db.flush()
    return notification


async def get_notifications(db: AsyncSession, user_id: UUID, unread_only: bool = False, limit: int = 50) -> list[Notification]:
    query = select(Notification).where(Notification.user_id == user_id)
    if unread_only:
        query = query.where(Notification.is_read == False)
    result = await db.execute(query.order_by(Notification.created_at.desc()).limit(limit))
    return list(result.scalars().all())


async def get_unread_count(db: AsyncSession, user_id: UUID) -> int:
    result = await db.execute(
        select(func.count()).select_from(Notification).where(Notification.user_id == user_id, Notification.is_read == False)
    )
    return result.scalar() or 0


async def mark_as_read(db: AsyncSession, notification_id: UUID, user_id: UUID) -> Notification:
    result = await db.execute(
        select(Notification).where(Notification.id == notification_id, Notification.user_id == user_id)
    )
    notification = result.scalar_one_or_none()
    if not notification:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Notification not found")
    notification.is_read = True
    await db.flush()
    return notification


async def mark_all_as_read(db: AsyncSession, user_id: UUID) -> None:
    await db.execute(
        update(Notification).where(Notification.user_id == user_id, Notification.is_read == False).values(is_read=True)
    )


async def delete_notification(db: AsyncSession, notification_id: UUID, user_id: UUID) -> None:
    result = await db.execute(
        select(Notification).where(Notification.id == notification_id, Notification.user_id == user_id)
    )
    notification = result.scalar_one_or_none()
    if not notification:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Notification not found")
    await db.delete(notification)


async def delete_all_notifications(db: AsyncSession, user_id: UUID) -> None:
    await db.execute(delete(Notification).where(Notification.user_id == user_id))


async def delete_notifications_by_pet(db: AsyncSession, pet_id: UUID, user_id: UUID) -> None:
    await db.execute(
        delete(Notification).where(Notification.pet_id == pet_id, Notification.user_id == user_id)
    )
