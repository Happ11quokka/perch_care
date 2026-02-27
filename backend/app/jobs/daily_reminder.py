"""Daily reminder job — sends push notifications to users who haven't recorded today.

Run via Railway Cron Job: python -m app.jobs.daily_reminder
Schedule: 0 8 * * * (UTC 08:00 = KST 17:00)
"""
import asyncio
import logging
from datetime import date, timezone, timedelta

from sqlalchemy import select, exists, delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import async_session_factory
from app.models.pet import Pet
from app.models.user import User
from app.models.weight_record import WeightRecord
from app.models.food_record import FoodRecord
from app.models.water_record import WaterRecord
from app.models.device_token import DeviceToken
from app.models.notification import Notification
from app.services.push_service import send_push_notifications_batch

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)

# KST = UTC+9
KST = timezone(timedelta(hours=9))

# Multi-language messages
MESSAGES = {
    "zh": {
        "title": "今天还没有记录哦 🐦",
        "body": "经常输入数据，鹦鹉博士才能为您提供更准确的健康分析哦～",
    },
    "ko": {
        "title": "오늘 아직 기록이 없어요 🐦",
        "body": "자주 데이터를 입력할수록 앵박사가 더 정확한 건강 분석을 해드릴 수 있어요~",
    },
    "en": {
        "title": "No records yet today 🐦",
        "body": "The more data you log, the better health insights Parrot Doctor can provide!",
    },
}

# Default to Chinese since 90%+ users are Chinese-speaking
DEFAULT_LANG = "zh"


async def get_users_without_records_today(db: AsyncSession) -> list[User]:
    """Find users who have pets but no weight/food/water records today."""
    today = date.today()

    # Subqueries: users who HAVE records today (via their pets)
    has_weight = (
        select(Pet.user_id)
        .join(WeightRecord, WeightRecord.pet_id == Pet.id)
        .where(WeightRecord.recorded_date == today)
    )
    has_food = (
        select(Pet.user_id)
        .join(FoodRecord, FoodRecord.pet_id == Pet.id)
        .where(FoodRecord.recorded_date == today)
    )
    has_water = (
        select(Pet.user_id)
        .join(WaterRecord, WaterRecord.pet_id == Pet.id)
        .where(WaterRecord.recorded_date == today)
    )

    # Users who have at least one pet but NO records today
    query = (
        select(User)
        .where(
            exists(select(Pet.id).where(Pet.user_id == User.id)),  # has pets
            ~User.id.in_(has_weight),
            ~User.id.in_(has_food),
            ~User.id.in_(has_water),
        )
    )
    result = await db.execute(query)
    return list(result.scalars().all())


async def run():
    logger.info("=== Daily reminder job started ===")

    async with async_session_factory() as db:
        # 1. Find target users
        users = await get_users_without_records_today(db)
        logger.info(f"Users without records today: {len(users)}")

        if not users:
            logger.info("No users to notify. Exiting.")
            return

        user_ids = [u.id for u in users]

        # 2. Get device tokens for these users
        result = await db.execute(
            select(DeviceToken).where(DeviceToken.user_id.in_(user_ids))
        )
        device_tokens = list(result.scalars().all())
        tokens = [dt.token for dt in device_tokens]
        logger.info(f"Device tokens to notify: {len(tokens)}")

        # 3. Send FCM push (use default language)
        msg = MESSAGES[DEFAULT_LANG]
        if tokens:
            success, failure, invalid = send_push_notifications_batch(
                tokens=tokens,
                title=msg["title"],
                body=msg["body"],
                data={"type": "daily_reminder"},
            )
            logger.info(f"Push sent — success: {success}, failure: {failure}, invalid: {len(invalid)}")

            # Remove invalid tokens
            if invalid:
                await db.execute(
                    delete(DeviceToken).where(DeviceToken.token.in_(invalid))
                )
                logger.info(f"Removed {len(invalid)} invalid tokens")

        # 4. Create in-app notifications for ALL target users (even without device tokens)
        for user_id in user_ids:
            db.add(Notification(
                user_id=user_id,
                type="reminder",
                title=msg["title"],
                message=msg["body"],
            ))
        logger.info(f"Created {len(user_ids)} in-app notifications")

        await db.commit()

    logger.info("=== Daily reminder job completed ===")


if __name__ == "__main__":
    asyncio.run(run())
