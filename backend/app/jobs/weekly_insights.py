"""Weekly insights job — generates AI health insights for premium users' pets.

Run via Railway Cron Job: python -m app.jobs.weekly_insights
Schedule: 0 0 * * 1 (UTC 00:00 Monday = KST 09:00 Monday)
"""
import asyncio
import logging
from collections import defaultdict

from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import async_session_factory
import app.models  # noqa: F401 — register all ORM mappers
from app.models.pet import Pet
from app.models.user import User
from app.models.user_tier import UserTier
from app.models.device_token import DeviceToken
from app.models.notification import Notification
from app.services.insights_service import generate_weekly_insight
from app.services.push_service import send_push_notifications_batch

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)

MESSAGES = {
    "zh": {
        "title": "本周健康洞察已生成 🐦",
        "body": "查看{pet_name}的每周健康变化分析吧～",
    },
    "ko": {
        "title": "이번 주 건강 인사이트가 도착했어요 🐦",
        "body": "{pet_name}의 주간 건강 변화를 확인해보세요~",
    },
    "en": {
        "title": "Weekly health insights ready 🐦",
        "body": "Check {pet_name}'s weekly health analysis!",
    },
}

DEFAULT_LANG = "zh"


async def _get_premium_users_with_pets(db: AsyncSession) -> list[tuple[User, list[Pet]]]:
    """Premium 사용자와 그 사용자의 활성 펫 목록을 반환."""
    from datetime import datetime, timezone

    now = datetime.now(timezone.utc)

    # Premium 사용자 ID 조회
    tier_result = await db.execute(
        select(UserTier.user_id).where(
            UserTier.tier == "premium",
            UserTier.premium_expires_at > now,
        )
    )
    premium_user_ids = [row for row in tier_result.scalars().all()]

    if not premium_user_ids:
        return []

    # 사용자 + 펫 조회
    user_result = await db.execute(
        select(User).where(User.id.in_(premium_user_ids))
    )
    users = list(user_result.scalars().all())

    result = []
    for user in users:
        pet_result = await db.execute(
            select(Pet).where(Pet.user_id == user.id)
        )
        pets = list(pet_result.scalars().all())
        if pets:
            result.append((user, pets))

    return result


async def run():
    logger.info("=== Weekly insights job started ===")

    async with async_session_factory() as db:
        # 1. Premium 사용자 + 펫 조회
        user_pets = await _get_premium_users_with_pets(db)
        logger.info(f"Premium users with pets: {len(user_pets)}")

        if not user_pets:
            logger.info("No premium users to generate insights for. Exiting.")
            return

        insights_count = 0
        user_ids_notified = []

        # 2. 각 펫에 대해 인사이트 생성
        for user, pets in user_pets:
            # 사용자 언어 결정 (DeviceToken에서)
            dt_result = await db.execute(
                select(DeviceToken.language)
                .where(DeviceToken.user_id == user.id)
                .limit(1)
            )
            lang = dt_result.scalar_one_or_none() or DEFAULT_LANG
            if lang not in MESSAGES:
                lang = DEFAULT_LANG

            pet_names = []
            for pet in pets:
                try:
                    await generate_weekly_insight(db, pet.id, user.id, lang)
                    insights_count += 1
                    pet_names.append(pet.name)
                    logger.info(f"Generated insight for pet {pet.name} (user {user.id})")
                except Exception as e:
                    logger.error(f"Failed to generate insight for pet {pet.id}: {e}")

            if pet_names:
                user_ids_notified.append((user.id, pet_names, lang))

        await db.commit()
        logger.info(f"Generated {insights_count} insights total")

        # 3. FCM 푸시 발송
        total_success = 0
        total_failure = 0
        all_invalid: list[str] = []

        for user_id, pet_names, lang in user_ids_notified:
            dt_result = await db.execute(
                select(DeviceToken).where(DeviceToken.user_id == user_id)
            )
            device_tokens = list(dt_result.scalars().all())

            if not device_tokens:
                continue

            msg = MESSAGES[lang]
            pet_name_str = pet_names[0] if pet_names else ""
            title = msg["title"]
            body = msg["body"].format(pet_name=pet_name_str)

            tokens = [dt.token for dt in device_tokens]
            success, failure, invalid = send_push_notifications_batch(
                tokens=tokens, title=title, body=body,
                data={"type": "weekly_insight"},
            )
            total_success += success
            total_failure += failure
            all_invalid.extend(invalid)

            # 인앱 알림 생성
            db.add(Notification(
                user_id=user_id,
                type="insight",
                title=title,
                message=body,
            ))

        if all_invalid:
            await db.execute(
                delete(DeviceToken).where(DeviceToken.token.in_(all_invalid))
            )
            logger.info(f"Removed {len(all_invalid)} invalid tokens")

        await db.commit()
        logger.info(f"Push total — success: {total_success}, failure: {total_failure}")
        logger.info(f"Created {len(user_ids_notified)} in-app notifications")

    logger.info("=== Weekly insights job completed ===")


if __name__ == "__main__":
    asyncio.run(run())
