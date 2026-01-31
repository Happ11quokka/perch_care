"""
AI 백과사전 서비스 — OpenAI gpt-5-nano + LangSmith tracing + 간단 RAG
"""
import os
from uuid import UUID
from datetime import date, timedelta

from openai import AsyncOpenAI
from langsmith import traceable
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.models.pet import Pet
from app.models.weight_record import WeightRecord
from app.models.food_record import FoodRecord
from app.models.water_record import WaterRecord

settings = get_settings()

# LangSmith 환경변수 설정 (트레이싱 자동 활성화)
os.environ.setdefault("LANGCHAIN_TRACING_V2", "true")
if settings.langsmith_api_key:
    os.environ.setdefault("LANGCHAIN_API_KEY", settings.langsmith_api_key)
if settings.langsmith_project:
    os.environ.setdefault("LANGCHAIN_PROJECT", settings.langsmith_project)

_openai_client = AsyncOpenAI(api_key=settings.openai_api_key)

MODEL = "gpt-4o-mini"

SYSTEM_PROMPT = (
    "너는 앵무새(반려조) 케어 전문가야. "
    "사용자의 질문에 친절하고 정확하게 답변해. "
    "근거가 불확실하면 수의사 상담을 권장해. "
    "답변은 5줄 이내로 간결하게 해줘."
)


async def _build_rag_context(db: AsyncSession, pet_id: str | None) -> str | None:
    """펫 ID 기반으로 DB에서 최근 건강 데이터를 조회하여 RAG context 텍스트를 구성한다."""
    if not pet_id:
        return None

    try:
        pid = UUID(pet_id)
    except (ValueError, AttributeError):
        return None

    # 펫 프로필 조회
    result = await db.execute(select(Pet).where(Pet.id == pid))
    pet = result.scalar_one_or_none()
    if pet is None:
        return None

    today = date.today()
    week_ago = today - timedelta(days=7)

    # 최근 7일 체중
    weight_result = await db.execute(
        select(WeightRecord.recorded_date, WeightRecord.weight)
        .where(WeightRecord.pet_id == pid, WeightRecord.recorded_date >= week_ago)
        .order_by(WeightRecord.recorded_date.desc())
    )
    weights = weight_result.all()

    # 최근 7일 사료
    food_result = await db.execute(
        select(FoodRecord.recorded_date, FoodRecord.total_grams, FoodRecord.target_grams)
        .where(FoodRecord.pet_id == pid, FoodRecord.recorded_date >= week_ago)
        .order_by(FoodRecord.recorded_date.desc())
    )
    foods = food_result.all()

    # 최근 7일 음수량
    water_result = await db.execute(
        select(WaterRecord.recorded_date, WaterRecord.total_ml, WaterRecord.target_ml)
        .where(WaterRecord.pet_id == pid, WaterRecord.recorded_date >= week_ago)
        .order_by(WaterRecord.recorded_date.desc())
    )
    waters = water_result.all()

    # context 텍스트 구성
    lines = ["[현재 앵무새 건강 데이터]"]

    # 프로필
    lines.append(f"이름: {pet.name}")
    lines.append(f"종: {pet.species}")
    if pet.breed:
        lines.append(f"품종: {pet.breed}")
    if pet.birth_date:
        age_days = (today - pet.birth_date).days
        years, months = divmod(age_days // 30, 12)
        age_str = f"{years}세 {months}개월" if years > 0 else f"{months}개월"
        lines.append(f"나이: {age_str}")
    if pet.gender:
        gender_map = {"male": "수컷", "female": "암컷", "unknown": "미상"}
        lines.append(f"성별: {gender_map.get(pet.gender, pet.gender)}")
    if pet.growth_stage:
        stage_map = {"adult": "성체", "rapid_growth": "빠른성장기", "post_growth": "후성장기"}
        lines.append(f"성장단계: {stage_map.get(pet.growth_stage, pet.growth_stage)}")

    # 체중
    if weights:
        lines.append("\n최근 7일 체중(g):")
        for w in weights:
            lines.append(f"  {w.recorded_date}: {w.weight}g")
    else:
        lines.append("\n최근 7일 체중 기록 없음")

    # 사료
    if foods:
        lines.append("\n최근 7일 사료 섭취:")
        for f in foods:
            lines.append(f"  {f.recorded_date}: {f.total_grams}g / 목표 {f.target_grams}g")
    else:
        lines.append("\n최근 7일 사료 기록 없음")

    # 음수량
    if waters:
        lines.append("\n최근 7일 음수량:")
        for w in waters:
            lines.append(f"  {w.recorded_date}: {w.total_ml}ml / 목표 {w.target_ml}ml")
    else:
        lines.append("\n최근 7일 음수 기록 없음")

    return "\n".join(lines)


@traceable(name="ai_encyclopedia_ask", run_type="chain")
async def ask(
    db: AsyncSession,
    query: str,
    history: list[dict[str, str]],
    pet_id: str | None = None,
    pet_profile_context: str | None = None,
    temperature: float = 0.2,
    max_tokens: int = 512,
) -> str:
    """사용자 질문에 대해 OpenAI gpt-5-nano로 답변을 생성한다."""

    # RAG: DB에서 펫 데이터 조회
    rag_context = await _build_rag_context(db, pet_id)

    # system prompt 구성
    system_parts = [SYSTEM_PROMPT]
    if rag_context:
        system_parts.append(f"\n\n{rag_context}\n\n위 데이터를 참고하여 이 앵무새에 맞는 맞춤 답변을 제공해.")
    elif pet_profile_context:
        # pet_id가 없으면 프론트엔드에서 보낸 프로필 컨텍스트 사용
        system_parts.append(f"\n\n{pet_profile_context}")

    system_message = "".join(system_parts)

    # 메시지 구성
    messages = [{"role": "system", "content": system_message}]
    for h in history:
        role = h.get("role", "user")
        content = h.get("content", "")
        if role in ("user", "assistant") and content:
            messages.append({"role": role, "content": content})
    messages.append({"role": "user", "content": query})

    import logging
    logger = logging.getLogger(__name__)

    response = await _openai_client.chat.completions.create(
        model=MODEL,
        messages=messages,
    )

    choice = response.choices[0]
    logger.warning(f"[AI DEBUG] finish_reason={choice.finish_reason}, content={choice.message.content!r}, refusal={getattr(choice.message, 'refusal', None)!r}")

    if choice.message.content:
        return choice.message.content

    return "답변을 생성하지 못했습니다."
