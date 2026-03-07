import logging
from datetime import datetime, timezone, timedelta

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user_tier import UserTier
from app.models.ai_health_check import AiHealthCheck

logger = logging.getLogger(__name__)

IMAGE_RETENTION_DAYS = 90


async def get_cleanup_candidates(db: AsyncSession) -> list[UserTier]:
    """프리미엄 만료 후 90일이 경과하고 아직 정리되지 않은 유저를 반환한다."""
    cutoff = datetime.now(timezone.utc) - timedelta(days=IMAGE_RETENTION_DAYS)
    result = await db.execute(
        select(UserTier).where(
            UserTier.tier == "free",
            UserTier.premium_expires_at != None,  # noqa: E711
            UserTier.premium_expires_at < cutoff,
            UserTier.image_cleanup_completed_at == None,  # noqa: E711
        )
    )
    return list(result.scalars().all())


async def process_cleanups(db: AsyncSession, batch_size: int = 50) -> int:
    """이미지 정리 대상 유저의 건강체크 이미지를 일괄 삭제한다."""
    candidates = await get_cleanup_candidates(db)
    if not candidates:
        return 0

    processed = 0
    for tier in candidates[:batch_size]:
        try:
            # 해당 유저의 모든 펫의 건강체크에서 image_url을 NULL로 설정
            from app.models.pet import Pet

            pet_result = await db.execute(
                select(Pet.id).where(Pet.user_id == tier.user_id)
            )
            pet_ids = [row[0] for row in pet_result.all()]

            if pet_ids:
                await db.execute(
                    update(AiHealthCheck)
                    .where(
                        AiHealthCheck.pet_id.in_(pet_ids),
                        AiHealthCheck.image_url != None,  # noqa: E711
                    )
                    .values(image_url=None)
                )

            # Mark cleanup as completed
            tier.image_cleanup_completed_at = datetime.now(timezone.utc)
            processed += 1
            logger.info(f"Image cleanup completed for user {tier.user_id}")
        except Exception as e:
            logger.error(f"Image cleanup failed for user {tier.user_id}: {e}")

    await db.commit()
    return processed
