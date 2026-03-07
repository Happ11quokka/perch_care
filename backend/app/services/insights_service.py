"""주간/월간 건강 인사이트 생성 서비스 — GPT 기반 자연어 요약."""
import json
import logging
from uuid import UUID
from datetime import date, timedelta

from openai import AsyncOpenAI
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.models.pet import Pet
from app.models.weight_record import WeightRecord
from app.models.food_record import FoodRecord
from app.models.water_record import WaterRecord
from app.models.ai_health_check import AiHealthCheck
from app.models.daily_record import DailyRecord
from app.models.pet_insight import PetInsight
from app.services.bhi_service import calculate_bhi

logger = logging.getLogger(__name__)

settings = get_settings()
_openai_client = AsyncOpenAI(api_key=settings.openai_api_key)

MODEL = "gpt-4o-mini"

_LANG_LABELS = {
    "ko": "한국어",
    "en": "English",
    "zh": "中文",
}

_SYSTEM_PROMPT = (
    "You are '앵박사', an expert AI assistant specializing in parrot and companion bird health analysis.\n\n"
    "TASK: Generate a concise weekly health insight report for a pet bird based on the provided data.\n\n"
    "LANGUAGE RULE: Respond ONLY in {language}.\n\n"
    "OUTPUT FORMAT (JSON):\n"
    '{{\n'
    '  "summary": "2-3 sentence natural language summary of health changes this week",\n'
    '  "recommendations": ["recommendation 1", "recommendation 2", "recommendation 3"]\n'
    '}}\n\n'
    "GUIDELINES:\n"
    "- Focus on notable changes and trends, not just listing numbers\n"
    "- If data is insufficient, acknowledge it and give general care tips\n"
    "- Recommendations should be specific and actionable\n"
    "- Keep summary under 100 words\n"
    "- Return valid JSON only, no markdown"
)


async def _aggregate_weekly_data(
    db: AsyncSession, pet_id: UUID, period_start: date, period_end: date,
) -> dict:
    """주간 데이터 집계."""
    # 체중 기록
    weight_result = await db.execute(
        select(WeightRecord.recorded_date, WeightRecord.weight)
        .where(
            WeightRecord.pet_id == pet_id,
            WeightRecord.recorded_date >= period_start,
            WeightRecord.recorded_date <= period_end,
        )
        .order_by(WeightRecord.recorded_date)
    )
    weights = [(str(r.recorded_date), float(r.weight)) for r in weight_result.all()]

    # 급여 기록
    food_result = await db.execute(
        select(
            func.count().label("days"),
            func.avg(FoodRecord.total_grams).label("avg_grams"),
        ).where(
            FoodRecord.pet_id == pet_id,
            FoodRecord.recorded_date >= period_start,
            FoodRecord.recorded_date <= period_end,
        )
    )
    food_row = food_result.one()
    food_days = food_row.days or 0
    food_avg = round(float(food_row.avg_grams), 1) if food_row.avg_grams else None

    # 음수 기록
    water_result = await db.execute(
        select(
            func.count().label("days"),
            func.avg(WaterRecord.total_ml).label("avg_ml"),
        ).where(
            WaterRecord.pet_id == pet_id,
            WaterRecord.recorded_date >= period_start,
            WaterRecord.recorded_date <= period_end,
        )
    )
    water_row = water_result.one()
    water_days = water_row.days or 0
    water_avg = round(float(water_row.avg_ml), 1) if water_row.avg_ml else None

    # 건강체크
    hc_result = await db.execute(
        select(
            func.count().label("total"),
            func.count().filter(AiHealthCheck.status != "normal").label("abnormal"),
        ).where(
            AiHealthCheck.pet_id == pet_id,
            AiHealthCheck.checked_at >= period_start,
            AiHealthCheck.checked_at < period_end + timedelta(days=1),
        )
    )
    hc_row = hc_result.one()

    # 일상 기록 (mood, activity)
    daily_result = await db.execute(
        select(DailyRecord.mood, DailyRecord.activity_level)
        .where(
            DailyRecord.pet_id == pet_id,
            DailyRecord.recorded_date >= period_start,
            DailyRecord.recorded_date <= period_end,
        )
    )
    dailies = daily_result.all()
    moods = [d.mood for d in dailies if d.mood]
    activities = [d.activity_level for d in dailies if d.activity_level]

    # BHI (기간 종료일 기준)
    try:
        bhi = await calculate_bhi(db, pet_id, period_end)
        bhi_score = bhi.bhi_score
        wci_level = bhi.wci_level
    except Exception:
        bhi_score = None
        wci_level = None

    return {
        "weights": weights,
        "weight_change": (
            round(weights[-1][1] - weights[0][1], 1) if len(weights) >= 2 else None
        ),
        "food_recorded_days": food_days,
        "food_avg_grams": food_avg,
        "water_recorded_days": water_days,
        "water_avg_ml": water_avg,
        "health_check_total": hc_row.total or 0,
        "health_check_abnormal": hc_row.abnormal or 0,
        "moods": moods,
        "activities": activities,
        "bhi_score": bhi_score,
        "wci_level": wci_level,
    }


async def generate_weekly_insight(
    db: AsyncSession, pet_id: UUID, user_id: UUID, language: str = "zh",
) -> PetInsight:
    """주간 건강 인사이트 생성 (GPT)."""
    today = date.today()
    # 지난 주 월~일
    period_end = today - timedelta(days=today.weekday() + 1)  # 지난 일요일
    period_start = period_end - timedelta(days=6)  # 지난 월요일

    # 이미 생성된 인사이트가 있는지 확인
    existing = await db.execute(
        select(PetInsight).where(
            PetInsight.pet_id == pet_id,
            PetInsight.insight_type == "weekly",
            PetInsight.period_end == period_end,
        )
    )
    if found := existing.scalar_one_or_none():
        return found

    # 펫 정보
    pet_result = await db.execute(select(Pet).where(Pet.id == pet_id))
    pet = pet_result.scalar_one_or_none()
    if not pet:
        raise ValueError(f"Pet {pet_id} not found")

    # 데이터 집계
    metrics = await _aggregate_weekly_data(db, pet_id, period_start, period_end)

    # GPT 프롬프트 구성
    lang_label = _LANG_LABELS.get(language, "中文")
    system = _SYSTEM_PROMPT.format(language=lang_label)

    user_prompt = (
        f"Pet name: {pet.name}\n"
        f"Species: {pet.species or 'parrot'}\n"
        f"Breed: {pet.breed or 'unknown'}\n"
        f"Period: {period_start} ~ {period_end}\n\n"
        f"Data:\n{json.dumps(metrics, ensure_ascii=False, indent=2)}"
    )

    try:
        response = await _openai_client.chat.completions.create(
            model=MODEL,
            messages=[
                {"role": "system", "content": system},
                {"role": "user", "content": user_prompt},
            ],
            temperature=0.7,
            max_tokens=500,
        )
        raw = response.choices[0].message.content.strip()
        # JSON 파싱
        parsed = json.loads(raw)
        summary = parsed.get("summary", "")
        recommendations = parsed.get("recommendations", [])
    except Exception as e:
        logger.error(f"GPT insight generation failed for pet {pet_id}: {e}")
        summary = ""
        recommendations = []

    insight = PetInsight(
        pet_id=pet_id,
        user_id=user_id,
        insight_type="weekly",
        period_start=period_start,
        period_end=period_end,
        summary=summary,
        key_metrics=metrics,
        recommendations=recommendations,
        language=language,
    )
    db.add(insight)
    await db.flush()
    return insight


async def get_latest_insight(
    db: AsyncSession, pet_id: UUID, insight_type: str = "weekly",
) -> PetInsight | None:
    """가장 최근 인사이트 반환."""
    result = await db.execute(
        select(PetInsight)
        .where(
            PetInsight.pet_id == pet_id,
            PetInsight.insight_type == insight_type,
        )
        .order_by(PetInsight.period_end.desc())
        .limit(1)
    )
    return result.scalar_one_or_none()
