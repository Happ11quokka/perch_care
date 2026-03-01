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
    "You are an expert in parrot (companion bird) care. "
    "IMPORTANT: Always respond in the SAME language as the user's message. "
    "If the user writes in Korean, reply in Korean. "
    "If the user writes in Chinese, reply in Chinese. "
    "If the user writes in English, reply in English. "
    "Match the user's language exactly.\n\n"
    "Answer kindly and accurately. "
    "If evidence is uncertain, recommend consulting a veterinarian. "
    "Keep answers concise, within 5 lines."
)


async def _build_rag_context(db: AsyncSession, pet_id: str | None, user_id: UUID | None = None) -> str | None:
    """펫 ID 기반으로 DB에서 최근 건강 데이터를 조회하여 RAG context 텍스트를 구성한다."""
    if not pet_id:
        return None

    try:
        pid = UUID(pet_id)
    except (ValueError, AttributeError):
        return None

    # 펫 프로필 조회 (소유자 검증 포함 — IDOR 방지)
    query = select(Pet).where(Pet.id == pid)
    if user_id is not None:
        query = query.where(Pet.user_id == user_id)
    result = await db.execute(query)
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


def _build_system_message(
    rag_context: str | None,
    pet_profile_context: str | None,
    knowledge_context: str | None = None,
) -> str:
    """시스템 프롬프트 + 지식 베이스 + RAG 컨텍스트를 결합한 시스템 메시지를 구성한다."""
    system_parts = [SYSTEM_PROMPT]
    if knowledge_context:
        system_parts.append(
            f"\n\n{knowledge_context}\n\n"
            "Use the knowledge base information above to provide accurate, evidence-based answers. "
            "Cite specific details from the knowledge base when relevant. "
            "Do not make up information not supported by the knowledge base."
        )
    if rag_context:
        system_parts.append(
            f"\n\n{rag_context}\n\n"
            "CRITICAL: You MUST reference the health data above in your answer. "
            "When the user asks about weight, diet, or water intake, cite the specific numbers from the data. "
            "Always personalize your advice based on this parrot's actual records. "
            "Do not give generic answers when specific data is available."
        )
    elif pet_profile_context:
        system_parts.append(f"\n\n{pet_profile_context}")
    return "".join(system_parts)


async def prepare_system_message(
    db: AsyncSession,
    query: str,
    pet_id: str | None = None,
    pet_profile_context: str | None = None,
    user_id: UUID | None = None,
) -> str:
    """벡터 검색 + RAG 컨텍스트 조회 후 시스템 메시지를 반환한다. 라우터에서 호출용."""
    from app.services.vector_search_service import search_knowledge, format_knowledge_context

    knowledge_results = await search_knowledge(query)
    knowledge_context = format_knowledge_context(knowledge_results)
    rag_context = await _build_rag_context(db, pet_id, user_id=user_id)
    return _build_system_message(rag_context, pet_profile_context, knowledge_context)


def _select_model(tier: str) -> tuple[str, int]:
    """티어별 모델과 최대 토큰 수를 반환한다."""
    if tier == "premium":
        return "gpt-4.1-nano", 2048
    return MODEL, 1024


async def ask(
    db: AsyncSession,
    query: str,
    history: list[dict[str, str]],
    tier: str = "free",
    pet_id: str | None = None,
    pet_profile_context: str | None = None,
    temperature: float = 0.2,
    max_tokens: int = 2048,
    user_id: UUID | None = None,
) -> str:
    """사용자 질문에 대해 티어별 모델로 답변을 생성한다."""
    system_message = await prepare_system_message(db, query, pet_id, pet_profile_context, user_id)

    # 티어별 모델 선택
    model, tier_max_tokens = _select_model(tier)
    effective_max_tokens = min(max_tokens, tier_max_tokens)

    return await _ask_core(
        system_message=system_message,
        query=query,
        history=history,
        model=model,
        temperature=temperature,
        effective_max_tokens=effective_max_tokens,
    )


@traceable(name="ai_encyclopedia_ask", run_type="chain")
async def _ask_core(
    system_message: str,
    query: str,
    history: list[dict[str, str]],
    model: str,
    temperature: float,
    effective_max_tokens: int,
) -> str:
    """LangSmith에 model/effective_max_tokens가 기록되는 실제 LLM 호출."""
    # 메시지 구성
    messages = [{"role": "system", "content": system_message}]
    for h in history:
        role = h.get("role", "user")
        content = h.get("content", "")
        if role in ("user", "assistant") and content:
            messages.append({"role": role, "content": content})
    messages.append({"role": "user", "content": query})

    response = await _openai_client.chat.completions.create(
        model=model,
        messages=messages,
        temperature=temperature,
        max_tokens=effective_max_tokens,
    )

    choice = response.choices[0]
    if choice.message.content:
        return choice.message.content

    return "답변을 생성하지 못했습니다."


async def ask_stream(
    db: AsyncSession,
    query: str,
    history: list[dict[str, str]],
    tier: str,
    pet_id: str | None = None,
    pet_profile_context: str | None = None,
    temperature: float = 0.2,
    max_tokens: int = 1024,
    user_id: UUID | None = None,
):
    """SSE 스트리밍 응답 생성기. DB에서 RAG 컨텍스트를 조회 후 토큰 단위로 yield한다."""
    system_message = await prepare_system_message(db, query, pet_id, pet_profile_context, user_id)

    # 티어별 모델 선택 (LangSmith에 기록되도록 미리 계산)
    model, tier_max_tokens = _select_model(tier)
    effective_max_tokens = min(max_tokens, tier_max_tokens)

    async for token in ask_stream_with_message(
        system_message=system_message,
        query=query,
        history=history,
        model=model,
        temperature=temperature,
        effective_max_tokens=effective_max_tokens,
    ):
        yield token


@traceable(name="ai_encyclopedia_ask_stream_core", run_type="chain")
async def ask_stream_with_message(
    system_message: str,
    query: str,
    history: list[dict[str, str]],
    model: str,
    temperature: float = 0.2,
    effective_max_tokens: int = 1024,
):
    """사전 구성된 시스템 메시지로 스트리밍. DB 세션 불필요. model/effective_max_tokens가 LangSmith에 기록된다."""
    messages = [{"role": "system", "content": system_message}]
    for h in history:
        role = h.get("role", "user")
        content = h.get("content", "")
        if role in ("user", "assistant") and content:
            messages.append({"role": role, "content": content})
    messages.append({"role": "user", "content": query})

    stream = await _openai_client.chat.completions.create(
        model=model,
        messages=messages,
        temperature=temperature,
        max_tokens=effective_max_tokens,
        stream=True,
    )

    async for chunk in stream:
        if chunk.choices and chunk.choices[0].delta.content:
            yield chunk.choices[0].delta.content
