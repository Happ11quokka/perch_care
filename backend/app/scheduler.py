import logging

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger

logger = logging.getLogger(__name__)

scheduler = AsyncIOScheduler()


async def daily_image_cleanup_job():
    """매일 03:00 UTC에 실행: 30일 초과 건강체크 이미지를 정리한다 (전체 사용자 동일 보존 정책)."""
    from app.database import async_session_factory
    from app.services.image_cleanup_service import cleanup_expired_health_check_images

    logger.info("Starting daily image cleanup job")
    try:
        async with async_session_factory() as db:
            expired = await cleanup_expired_health_check_images(db)
            logger.info(f"Health check image cleanup completed: {expired} expired images deleted")
    except Exception as e:
        logger.error(f"Health check image cleanup failed: {e}", exc_info=True)


def start_scheduler():
    """스케줄러 시작."""
    scheduler.add_job(
        daily_image_cleanup_job,
        trigger=CronTrigger(hour=3, minute=0),  # 매일 03:00 UTC
        id="daily_image_cleanup",
        replace_existing=True,
    )
    scheduler.start()
    logger.info("Scheduler started with daily image cleanup (03:00 UTC)")


def stop_scheduler():
    """스케줄러 종료."""
    if scheduler.running:
        scheduler.shutdown(wait=False)
        logger.info("Scheduler stopped")
