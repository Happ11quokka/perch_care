"""건강 리포트 HTML 생성 서비스.

Jinja2 HTML 템플릿 렌더링 → 웹 링크 공유용.
"""
import logging
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from uuid import UUID

from fastapi import HTTPException, status
from jinja2 import Environment, FileSystemLoader
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.pet import Pet
from app.services import (
    bhi_service,
    daily_record_service,
    food_record_service,
    health_check_service,
    water_record_service,
    weight_service,
)

logger = logging.getLogger(__name__)

_TEMPLATE_DIR = Path(__file__).resolve().parent.parent / "templates" / "reports"
_jinja_env = Environment(
    loader=FileSystemLoader(str(_TEMPLATE_DIR)),
    autoescape=True,
)


async def _get_pet_with_owner_check(
    db: AsyncSession, pet_id: UUID, user_id: UUID
) -> Pet:
    result = await db.execute(
        select(Pet).where(Pet.id == pet_id, Pet.user_id == user_id)
    )
    pet = result.scalar_one_or_none()
    if not pet:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pet not found",
        )
    return pet


async def generate_health_html(
    db: AsyncSession,
    pet_id: UUID,
    user_id: UUID,
    date_from: date,
    date_to: date,
    language: str = "ko",
) -> str:
    """건강 리포트 HTML 생성 (date_from ~ date_to)."""
    pet = await _get_pet_with_owner_check(db, pet_id, user_id)

    weights = await weight_service.get_records_by_range(db, pet_id, date_from, date_to)
    foods = await food_record_service.get_records_by_range(db, pet_id, date_from, date_to)
    waters = await water_record_service.get_records_by_range(db, pet_id, date_from, date_to)
    dailies = await daily_record_service.get_records_by_range(db, pet_id, date_from, date_to)

    dt_from = datetime.combine(date_from, datetime.min.time(), tzinfo=timezone.utc)
    dt_to = datetime.combine(date_to, datetime.max.time(), tzinfo=timezone.utc)
    health_checks = await health_check_service.get_checks_by_date_range(
        db, pet_id, dt_from, dt_to
    )

    bhi = None
    try:
        bhi = await bhi_service.calculate_bhi(db, pet_id, date_to)
    except Exception:
        logger.warning("BHI calculation failed for health report, skipping")

    template = _jinja_env.get_template("health_report.html")
    return template.render(
        pet=pet,
        date_from=date_from,
        date_to=date_to,
        weights=weights,
        foods=foods,
        waters=waters,
        dailies=dailies,
        health_checks=health_checks,
        bhi=bhi,
        generated_at=datetime.now(timezone.utc),
        lang=language,
    )


async def generate_vet_summary_html(
    db: AsyncSession,
    pet_id: UUID,
    user_id: UUID,
    language: str = "ko",
    date_from: date | None = None,
    date_to: date | None = None,
) -> str:
    """병원 방문용 요약 리포트 HTML.

    date_from/date_to가 지정되면 해당 기간 사용, 없으면 최근 30일.
    """
    if date_to is None:
        date_to = date.today()
    if date_from is None:
        date_from = date_to - timedelta(days=30)

    pet = await _get_pet_with_owner_check(db, pet_id, user_id)

    weights = await weight_service.get_records_by_range(db, pet_id, date_from, date_to)

    dt_from = datetime.combine(date_from, datetime.min.time(), tzinfo=timezone.utc)
    dt_to = datetime.combine(date_to, datetime.max.time(), tzinfo=timezone.utc)
    health_checks = await health_check_service.get_checks_by_date_range(
        db, pet_id, dt_from, dt_to
    )
    abnormal_checks = [c for c in health_checks if c.status != "normal"]

    bhi = None
    try:
        bhi = await bhi_service.calculate_bhi(db, pet_id, date_to)
    except Exception:
        logger.warning("BHI calculation failed for vet summary, skipping")

    dailies = await daily_record_service.get_records_by_range(db, pet_id, date_from, date_to)

    template = _jinja_env.get_template("vet_summary.html")
    return template.render(
        pet=pet,
        date_from=date_from,
        date_to=date_to,
        weights=weights,
        health_checks=health_checks,
        abnormal_checks=abnormal_checks,
        bhi=bhi,
        dailies=dailies,
        generated_at=datetime.now(timezone.utc),
        lang=language,
    )
