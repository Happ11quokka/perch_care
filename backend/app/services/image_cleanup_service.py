import logging
from datetime import datetime, timezone, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user_tier import UserTier
from app.models.ai_health_check import AiHealthCheck

logger = logging.getLogger(__name__)

IMAGE_RETENTION_DAYS = 90
HEALTH_CHECK_IMAGE_RETENTION_DAYS = 30


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
    from app.models.pet import Pet
    from app.utils.file_storage import delete_upload_file

    candidates = await get_cleanup_candidates(db)
    if not candidates:
        return 0

    processed = 0
    for tier in candidates[:batch_size]:
        try:
            pet_result = await db.execute(
                select(Pet.id).where(Pet.user_id == tier.user_id)
            )
            pet_ids = [row[0] for row in pet_result.all()]

            if pet_ids:
                check_result = await db.execute(
                    select(AiHealthCheck).where(
                        AiHealthCheck.pet_id.in_(pet_ids),
                        AiHealthCheck.image_url != None,  # noqa: E711
                    )
                )
                checks = list(check_result.scalars().all())

                for check in checks:
                    try:
                        delete_upload_file(check.image_url)
                    except Exception as e:
                        logger.warning(
                            f"Failed to delete file {check.image_url} "
                            f"for user {tier.user_id}: {e}"
                        )
                    check.image_url = None

            tier.image_cleanup_completed_at = datetime.now(timezone.utc)
            processed += 1
            logger.info(f"Image cleanup completed for user {tier.user_id}")
        except Exception as e:
            logger.error(f"Image cleanup failed for user {tier.user_id}: {e}")

    await db.commit()
    return processed


async def cleanup_expired_health_check_images(db: AsyncSession) -> int:
    """30일 이상 된 건강체크 이미지 파일을 삭제하고 image_url을 NULL로 설정한다.

    ⚠️ Production 배포 시: file_storage.delete_upload_file()을
    외부 오브젝트 스토리지(S3/R2) 삭제로 교체해야 함.
    """
    from app.utils.file_storage import delete_upload_file

    cutoff = datetime.now(timezone.utc) - timedelta(days=HEALTH_CHECK_IMAGE_RETENTION_DAYS)
    result = await db.execute(
        select(AiHealthCheck).where(
            AiHealthCheck.image_url != None,  # noqa: E711
            AiHealthCheck.checked_at < cutoff,
        )
    )
    checks = list(result.scalars().all())
    if not checks:
        return 0

    deleted = 0
    skipped = 0
    for check in checks:
        try:
            file_deleted = delete_upload_file(check.image_url)
            if not file_deleted:
                logger.debug(
                    f"File not found or invalid URL, clearing image_url: {check.image_url}"
                )
            check.image_url = None
            deleted += 1
        except Exception as e:
            logger.warning(
                f"Failed to delete image file {check.image_url}, "
                f"skipping to retry next run: {e}"
            )
            skipped += 1

    await db.commit()
    logger.info(
        f"Expired health check images cleaned: {deleted} records "
        f"(skipped {skipped} due to errors)"
    )
    return deleted
