import logging
from datetime import datetime, timezone, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.ai_health_check import AiHealthCheck

logger = logging.getLogger(__name__)

HEALTH_CHECK_IMAGE_RETENTION_DAYS = 30


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
