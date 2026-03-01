# 앵박사 AI 업그레이드 구현 계획

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 앵박사 AI를 멀티 모델 라우팅 + HyDE 벡터 검색 + Vision 건강체크 + DeepSeek 중국어 보충 + 구조화 응답 시스템으로 업그레이드한다.

**Architecture:** FastAPI 백엔드에 pgvector 확장 추가, 모델 라우팅 레이어 도입, SSE 스트리밍 구현, GPT-4o Vision 건강체크 파이프라인 구축. 검증 완료된 HyDE + text-embedding-3-large 설정을 프로덕션에 적용.

**Tech Stack:** FastAPI, PostgreSQL + pgvector, OpenAI API (GPT-4.1-nano, GPT-4o-mini, GPT-4o Vision), DeepSeek API, text-embedding-3-large, SSE, Flutter (http), LangSmith

**설계 문서:** `docs/plans/2026-03-01-ai-upgrade-final-design.md`

---

## Phase 0: Railway Staging 환경 설정

### Task 0-1: Railway staging 환경 생성

**Files:**
- Modify: `backend/.env.example` (새 환경변수 추가)

**Step 1: Railway 대시보드에서 Staging 환경 생성**

Railway Dashboard → Project → Environments → New Environment → "staging"
- `dev` 브랜치에 연결
- DB 서비스 복제 확인

**Step 2: staging 환경변수 설정**

Railway staging 환경에 다음 변수 추가:
```
OPENAI_API_KEY=<staging 전용 키>
DEEPSEEK_API_KEY=<staging 전용 키>
EMBEDDING_MODEL=text-embedding-3-large
```

**Step 3: .env.example 업데이트**

```bash
# 기존 .env.example에 추가
DEEPSEEK_API_KEY=your_deepseek_api_key
EMBEDDING_MODEL=text-embedding-3-large
```

**Step 4: Commit**

```bash
git add backend/.env.example
git commit -m "chore: add DeepSeek and embedding model env vars"
```

---

## Phase 1: DB + Tier 시스템

### Task 1-1: user_tiers + premium_codes 테이블 마이그레이션

**Files:**
- Create: `backend/alembic/versions/005_add_user_tiers_and_premium_codes.py`
- Create: `backend/app/models/user_tier.py`
- Create: `backend/app/models/premium_code.py`
- Modify: `backend/app/models/__init__.py`

**Step 1: UserTier 모델 생성**

`backend/app/models/user_tier.py`:
```python
import uuid
from datetime import datetime

from sqlalchemy import Column, String, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.models.base import Base


class UserTier(Base):
    __tablename__ = "user_tiers"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False)
    tier = Column(String(20), nullable=False, default="free")  # "free" | "premium"
    premium_started_at = Column(DateTime(timezone=True), nullable=True)
    premium_expires_at = Column(DateTime(timezone=True), nullable=True)
    activated_code = Column(String(20), nullable=True)  # 마지막 활성화에 사용된 코드
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at = Column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)

    user = relationship("User", back_populates="tier_info")
```

**Step 2: PremiumCode 모델 생성**

`backend/app/models/premium_code.py`:
```python
import uuid
from datetime import datetime

from sqlalchemy import Column, String, Boolean, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID

from app.models.base import Base


class PremiumCode(Base):
    __tablename__ = "premium_codes"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    code = Column(String(20), unique=True, nullable=False)  # "PERCH-XXXX-XXXX"
    is_used = Column(Boolean, default=False)
    used_by = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    used_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)
```

**Step 3: __init__.py에 import 추가**

`backend/app/models/__init__.py`에 추가:
```python
from app.models.user_tier import UserTier
from app.models.premium_code import PremiumCode
```

**Step 4: Alembic 마이그레이션 생성 및 실행**

```bash
cd backend
alembic revision --autogenerate -m "add user_tiers and premium_codes tables"
alembic upgrade head
```

**Step 5: Commit**

```bash
git add backend/app/models/user_tier.py backend/app/models/premium_code.py backend/app/models/__init__.py backend/alembic/versions/005_*
git commit -m "feat: add user_tiers and premium_codes tables"
```

### Task 1-2: 티어 서비스 및 프리미엄 코드 활성화

**Files:**
- Create: `backend/app/services/tier_service.py`
- Modify: `backend/app/dependencies.py`
- Modify: `backend/app/routers/` (프리미엄 코드 엔드포인트)

**Step 1: 티어 서비스 생성 (조회 + 코드 활성화)**

`backend/app/services/tier_service.py`:
```python
from datetime import datetime, timedelta

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user_tier import UserTier
from app.models.premium_code import PremiumCode


async def get_user_tier(db: AsyncSession, user_id) -> str:
    """사용자 티어 조회. 없으면 'free' 반환. 만료된 프리미엄은 DB도 갱신 후 'free' 반환."""
    result = await db.execute(
        select(UserTier).where(UserTier.user_id == user_id)
    )
    tier = result.scalar_one_or_none()
    if not tier:
        return "free"
    if tier.tier == "premium" and tier.premium_expires_at:
        if tier.premium_expires_at < datetime.utcnow():
            # P1 만료 처리: DB 상태도 함께 갱신하여 다른 경로에서 오판 방지
            tier.tier = "free"
            tier.updated_at = datetime.utcnow()
            await db.commit()
            return "free"
    return tier.tier


async def activate_premium_code(db: AsyncSession, user_id, code: str) -> dict:
    """프리미엄 코드 입력 → 30일 프리미엄 활성화.

    보안 정책:
    - P0: SELECT ... FOR UPDATE로 레이스 컨디션 방지
    - P1: 에러 메시지 단일화 (코드 존재 여부 노출 방지)
    - P2: 같은 사용자가 같은 코드로 재시도 시 멱등 성공 처리

    Returns:
        {"success": True, "expires_at": ...} 또는 {"success": False, "error": ...}
    """
    # 1. 코드 조회 — SELECT ... FOR UPDATE (레이스 컨디션 방지)
    result = await db.execute(
        select(PremiumCode)
        .where(PremiumCode.code == code)
        .with_for_update()
    )
    premium_code = result.scalar_one_or_none()

    # P1 에러 메시지 단일화: 코드 존재 여부를 구분하지 않음
    if not premium_code:
        return {"success": False, "error": "유효하지 않거나 이미 사용된 코드입니다"}

    # P2 멱등성: 같은 사용자가 이미 사용한 코드로 재시도 시 기존 결과 반환
    if premium_code.is_used:
        if premium_code.used_by == user_id:
            tier_result = await db.execute(
                select(UserTier).where(UserTier.user_id == user_id)
            )
            user_tier = tier_result.scalar_one_or_none()
            if user_tier and user_tier.premium_expires_at:
                return {"success": True, "expires_at": user_tier.premium_expires_at.isoformat()}
        return {"success": False, "error": "유효하지 않거나 이미 사용된 코드입니다"}

    # 2. 코드 사용 처리 (트랜잭션 내 원자적 업데이트)
    now = datetime.utcnow()
    premium_code.is_used = True
    premium_code.used_by = user_id
    premium_code.used_at = now

    # 3. user_tiers 업서트 (입력일 기준 30일)
    expires_at = now + timedelta(days=30)

    result = await db.execute(
        select(UserTier).where(UserTier.user_id == user_id)
    )
    user_tier = result.scalar_one_or_none()

    if user_tier:
        user_tier.tier = "premium"
        user_tier.premium_started_at = now
        user_tier.premium_expires_at = expires_at
        user_tier.activated_code = code
        user_tier.updated_at = now
    else:
        user_tier = UserTier(
            user_id=user_id,
            tier="premium",
            premium_started_at=now,
            premium_expires_at=expires_at,
            activated_code=code,
        )
        db.add(user_tier)

    await db.commit()

    return {"success": True, "expires_at": expires_at.isoformat()}
```

**Step 2: Pydantic 요청 스키마 추가 (코드 형식 검증)**

`backend/app/schemas/premium.py`:
```python
import re
from pydantic import BaseModel, field_validator


class PremiumCodeRequest(BaseModel):
    code: str

    @field_validator("code")
    @classmethod
    def validate_code_format(cls, v: str) -> str:
        # 대문자 정규화 후 형식 검증
        v = v.strip().upper()
        if not re.match(r"^PERCH-[A-Z0-9]{4}-[A-Z0-9]{4}$", v):
            raise ValueError("코드 형식이 올바르지 않습니다")
        return v


class PremiumCodeResponse(BaseModel):
    success: bool
    expires_at: str | None = None
    error: str | None = None
```

**Step 3: 프리미엄 코드 활성화 엔드포인트 추가 (rate limit 포함)**

해당 라우터 파일에 추가:
```python
from app.services.tier_service import activate_premium_code
from app.schemas.premium import PremiumCodeRequest

# /premium/activate 전용 rate limit: 사용자당 5회/분
@router.post("/premium/activate")
async def activate_premium(
    request: PremiumCodeRequest,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await activate_premium_code(db, current_user.id, request.code)
    if not result["success"]:
        raise HTTPException(400, result["error"])
    return result
```

> **보안 참고:** `/premium/activate` 엔드포인트에 사용자당 5회/분 rate limit 적용 권장.
> FastAPI의 `slowapi` 또는 미들웨어 레벨에서 구현.

**Step 3: dependencies.py에 티어 의존성 추가**

```python
from app.services.tier_service import get_user_tier

async def get_current_tier(
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> str:
    return await get_user_tier(db, current_user.id)
```

**Step 4: Commit**

```bash
git add backend/app/services/tier_service.py backend/app/dependencies.py backend/app/routers/
git commit -m "feat: add tier service with premium code activation"
```

---

## Phase 2: 백엔드 SSE 스트리밍

### Task 2-1: SSE 스트리밍 엔드포인트

**Files:**
- Modify: `backend/app/services/ai_service.py`
- Modify: `backend/app/routers/ai.py`
- Modify: `backend/app/schemas/ai.py`

**Step 1: ai_service.py에 스트리밍 함수 추가**

```python
async def ask_stream(
    query: str,
    history: list[dict],
    pet_id: str | None,
    tier: str,
    db: AsyncSession,
    temperature: float = 0.2,
    max_tokens: int = 1024,
):
    """SSE 스트리밍 응답 생성기."""
    # RAG 컨텍스트 빌드 (기존 로직 재사용)
    context = await _build_context(pet_id, tier, db)
    system_prompt = _build_system_prompt(context, tier)

    # 티어별 모델 선택
    model = "gpt-4.1-nano" if tier == "premium" else "gpt-4o-mini"
    max_tok = 2048 if tier == "premium" else 1024

    messages = [{"role": "system", "content": system_prompt}]
    for h in history:
        if h.get("role") in ("user", "assistant") and h.get("content"):
            messages.append(h)
    messages.append({"role": "user", "content": query})

    client = AsyncOpenAI()
    stream = await client.chat.completions.create(
        model=model,
        messages=messages,
        temperature=temperature,
        max_tokens=max_tok,
        stream=True,
    )

    async for chunk in stream:
        delta = chunk.choices[0].delta
        if delta.content:
            yield delta.content
```

**Step 2: ai.py 라우터에 SSE 엔드포인트 추가**

```python
from fastapi.responses import StreamingResponse
import json

@router.post("/encyclopedia/stream")
async def ai_encyclopedia_stream(
    request: AiEncyclopediaRequest,
    current_user = Depends(get_current_user),
    tier: str = Depends(get_current_tier),
    db: AsyncSession = Depends(get_db),
):
    async def event_generator():
        try:
            async for token in ai_service.ask_stream(
                query=request.query,
                history=request.history,
                pet_id=request.pet_id,
                tier=tier,
                db=db,
                temperature=request.temperature,
            ):
                yield f"data: {json.dumps({'token': token})}\n\n"
            yield f"data: {json.dumps({'done': True})}\n\n"
        except Exception as e:
            yield f"data: {json.dumps({'error': str(e)})}\n\n"

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )
```

**Step 3: Commit**

```bash
git add backend/app/services/ai_service.py backend/app/routers/ai.py backend/app/schemas/ai.py
git commit -m "feat: add SSE streaming endpoint for AI encyclopedia"
```

---

## Phase 3: 프론트엔드 SSE 스트리밍

### Task 3-1: SSE 클라이언트 서비스

**Files:**
- Create: `lib/src/services/ai/ai_stream_service.dart`
- Modify: AI 채팅 화면 (해당 화면 파일)

**Step 1: SSE 클라이언트 구현**

`lib/src/services/ai/ai_stream_service.dart`:
```dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AiStreamService {
  final String baseUrl;
  final String accessToken;

  AiStreamService({required this.baseUrl, required this.accessToken});

  Stream<String> streamEncyclopedia({
    required String query,
    List<Map<String, String>> history = const [],
    String? petId,
  }) async* {
    final request = http.Request(
      'POST',
      Uri.parse('$baseUrl/ai/encyclopedia/stream'),
    );
    request.headers['Authorization'] = 'Bearer $accessToken';
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({
      'query': query,
      'history': history,
      'pet_id': petId,
    });

    final response = await http.Client().send(request);

    await for (final chunk in response.stream.transform(utf8.decoder)) {
      for (final line in chunk.split('\n')) {
        if (line.startsWith('data: ')) {
          final data = jsonDecode(line.substring(6));
          if (data['token'] != null) {
            yield data['token'] as String;
          } else if (data['done'] == true) {
            return;
          } else if (data['error'] != null) {
            throw Exception(data['error']);
          }
        }
      }
    }
  }
}
```

**Step 2: 채팅 화면에서 스트리밍 UI 적용**

기존 채팅 화면의 답변 표시를 `StreamBuilder` 또는 `setState` per token으로 변경.
SSE 실패 시 기존 동기 API로 fallback.

**Step 3: Commit**

```bash
git add lib/src/services/ai/ai_stream_service.dart
git commit -m "feat: add SSE streaming client for AI encyclopedia"
```

---

## Phase 4: pgvector + HyDE 벡터 검색 RAG

### Task 4-1: pgvector 설정 및 마이그레이션

**Files:**
- Modify: `backend/docker-compose.yml`
- Modify: `backend/requirements.txt`
- Create: `backend/alembic/versions/006_add_pgvector_knowledge.py`
- Create: `backend/app/models/knowledge_chunk.py`

**Step 1: Docker 이미지 변경**

`backend/docker-compose.yml`에서 db 서비스:
```yaml
db:
  image: pgvector/pgvector:pg16  # 기존: postgres:16-alpine
```

**Step 2: requirements.txt에 추가**

```
pgvector==0.3.6
```

**Step 3: 모델 생성**

`backend/app/models/knowledge_chunk.py`:
```python
import uuid
from datetime import datetime

from sqlalchemy import Column, String, Text, DateTime
from sqlalchemy.dialects.postgresql import UUID
from pgvector.sqlalchemy import Vector

from app.models.base import Base


class KnowledgeChunk(Base):
    __tablename__ = "knowledge_chunks"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    content = Column(Text, nullable=False)
    embedding = Column(Vector(3072))  # text-embedding-3-large
    source = Column(String(200))
    category = Column(String(50))
    language = Column(String(10))  # "en" | "zh"
    section_title = Column(String(300))
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)
```

**Step 4: 마이그레이션 생성 및 실행**

```bash
cd backend
alembic revision --autogenerate -m "add pgvector knowledge_chunks"
```

마이그레이션 파일의 `upgrade()` 시작에 추가:
```python
op.execute("CREATE EXTENSION IF NOT EXISTS vector")
```

그리고 인덱스 추가:
```python
op.execute("""
    CREATE INDEX ix_knowledge_chunks_embedding
    ON knowledge_chunks
    USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100)
""")
op.create_index("ix_knowledge_chunks_category", "knowledge_chunks", ["category"])
op.create_index("ix_knowledge_chunks_language", "knowledge_chunks", ["language"])
```

```bash
alembic upgrade head
```

**Step 5: Commit**

```bash
git add backend/docker-compose.yml backend/requirements.txt backend/app/models/knowledge_chunk.py backend/alembic/versions/006_*
git commit -m "feat: add pgvector extension and knowledge_chunks table"
```

### Task 4-2: 임베딩 + HyDE + 벡터 검색 서비스

**Files:**
- Create: `backend/app/services/embedding_service.py`
- Create: `backend/app/services/vector_search_service.py`

**Step 1: 임베딩 서비스 생성**

`backend/app/services/embedding_service.py`:
```python
import os

from openai import AsyncOpenAI

EMBEDDING_MODEL = os.getenv("EMBEDDING_MODEL", "text-embedding-3-large")

_client = AsyncOpenAI()


async def create_embedding(text: str) -> list[float]:
    """텍스트를 3072차원 벡터로 변환."""
    response = await _client.embeddings.create(
        model=EMBEDDING_MODEL,
        input=text,
    )
    return response.data[0].embedding


HYDE_PROMPT = (
    "You are an expert avian veterinarian. "
    "Given the following question about parrots or companion birds, "
    "write a detailed, factual answer as if it were an excerpt from a veterinary reference document. "
    "Include specific medical terms, species names, symptoms, treatments, or nutritional facts as relevant. "
    "IMPORTANT: Always write your answer in English, regardless of the question's language. "
    "Write 150-300 words.\n\n"
    "Question: {query}\n\n"
    "Detailed reference answer:"
)


async def generate_hypothetical_document(query: str) -> str:
    """HyDE: 사용자 질문에 대한 가상 참고 문서를 GPT로 생성."""
    response = await _client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[{"role": "user", "content": HYDE_PROMPT.format(query=query)}],
        temperature=0.0,
        max_tokens=400,
    )
    return response.choices[0].message.content or query
```

**Step 2: 벡터 검색 서비스 생성**

`backend/app/services/vector_search_service.py`:
```python
import asyncio

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.services.embedding_service import create_embedding, generate_hypothetical_document


async def search_knowledge(
    db: AsyncSession,
    query: str,
    top_k: int = 5,
    category: str | None = None,
    language: str | None = None,
    use_hyde: bool = True,
    hyde_timeout: float = 5.0,
) -> list[dict]:
    """HyDE + pgvector 코사인 유사도 검색."""
    # HyDE: 가상 문서 생성 (timeout 적용)
    search_text = query
    if use_hyde:
        try:
            search_text = await asyncio.wait_for(
                generate_hypothetical_document(query),
                timeout=hyde_timeout,
            )
        except asyncio.TimeoutError:
            search_text = query  # fallback: 원본 쿼리

    # 임베딩 생성
    embedding = await create_embedding(search_text)

    # pgvector 검색
    sql = text("""
        SELECT content, source, category, language, section_title,
               1 - (embedding <=> :embedding::vector) AS similarity
        FROM knowledge_chunks
        WHERE (:category IS NULL OR category = :category)
          AND (:language IS NULL OR language = :language)
        ORDER BY embedding <=> :embedding::vector
        LIMIT :top_k
    """)

    result = await db.execute(sql, {
        "embedding": str(embedding),
        "category": category,
        "language": language,
        "top_k": top_k,
    })

    return [
        {
            "content": r.content,
            "source": r.source,
            "category": r.category,
            "language": r.language,
            "section_title": r.section_title,
            "similarity": round(float(r.similarity), 4),
        }
        for r in result.fetchall()
    ]
```

**Step 3: Commit**

```bash
git add backend/app/services/embedding_service.py backend/app/services/vector_search_service.py
git commit -m "feat: add embedding and vector search services with HyDE"
```

### Task 4-3: 지식 데이터 적재 스크립트

**Files:**
- Create: `backend/scripts/load_knowledge.py`
- Reuse: `agent/chunker.py` (청킹 로직 복사)

**Step 1: 적재 스크립트 생성**

에이전트에서 검증된 `chunker.py`의 청킹 로직을 `backend/scripts/load_knowledge.py`에 통합하여 생성.
pgvector에 맞게 임베딩 생성 + DB 삽입.

```bash
cd backend
python scripts/load_knowledge.py --reset
# 예상: ~2,843 청크 적재
```

**Step 2: Commit**

```bash
git add backend/scripts/load_knowledge.py
git commit -m "feat: add knowledge data loading script for pgvector"
```

---

## Phase 5: DeepSeek 중국어 보충 모듈

### Task 5-1: DeepSeek 서비스

**Files:**
- Create: `backend/app/services/deepseek_service.py`
- Modify: `backend/app/config.py`

**Step 1: config.py에 DeepSeek 설정 추가**

```python
deepseek_api_key: str = ""
```

**Step 2: DeepSeek 서비스 생성**

`backend/app/services/deepseek_service.py`:
```python
import asyncio

import httpx

from app.config import settings

DEEPSEEK_API_URL = "https://api.deepseek.com/v1/chat/completions"

TEXT_SUPPLEMENT_PROMPT = """你是一位熟悉中国宠物鸟饲养文化的鸟类专家。

针对以下用户问题，请提供中国特有的补充背景信息，包括但不限于：
- 中国鸟友圈的常见做法和经验
- 中国市场上可获得的相关产品（药品、饲料、器具等）
- 中医/传统方法在鸟类护理中的应用（如有）
- 中国特有的鸟类品种或饲养习惯

重要：你只提供补充信息，不做最终医学诊断。最终判断将由主AI完成。
回答控制在200-400字。

用户问题：{query}"""

VISION_SUPPLEMENT_PROMPT = """你是一位熟悉中国宠物鸟饲养文化的鸟类专家。

用户上传了一张关于"{mode}"的照片。
针对这个分析类型，请补充中国特有的背景信息：

- 如果是排便(droppings)：中国鸟友判断排便健康的经验方法
- 如果是食物(food)：中国市场常见的鸟粮品牌、本地食材的安全性
- 如果是鸟的外观：中国常见品种的特征差异、本地常见疾病

重要：你只提供补充信息，不做最终诊断。
回答控制在150-300字。"""


async def get_chinese_supplement(
    query: str,
    mode: str = "text",
    timeout: float = 5.0,
) -> str | None:
    """DeepSeek API로 중국 문화 맥락 보충 정보 생성.

    실패 시 None 반환 (서비스 중단 없음).
    """
    if not settings.deepseek_api_key:
        return None

    if mode == "text":
        prompt = TEXT_SUPPLEMENT_PROMPT.format(query=query)
    else:
        prompt = VISION_SUPPLEMENT_PROMPT.format(mode=mode)

    try:
        async with httpx.AsyncClient(timeout=timeout) as client:
            response = await client.post(
                DEEPSEEK_API_URL,
                headers={
                    "Authorization": f"Bearer {settings.deepseek_api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": "deepseek-chat",
                    "messages": [{"role": "user", "content": prompt}],
                    "temperature": 0.3,
                    "max_tokens": 500,
                },
            )
            response.raise_for_status()
            data = response.json()
            return data["choices"][0]["message"]["content"]
    except Exception:
        return None  # DeepSeek 실패 시 무시하고 계속
```

**Step 3: Commit**

```bash
git add backend/app/services/deepseek_service.py backend/app/config.py
git commit -m "feat: add DeepSeek Chinese cultural supplement service"
```

---

## Phase 6: 구조화 응답 + 의사 권유 정책 + 모델 라우팅

### Task 6-1: ai_service.py 통합 리팩토링

**Files:**
- Modify: `backend/app/services/ai_service.py`

**Step 1: 시스템 프롬프트 업데이트**

기존 시스템 프롬프트를 설계 문서 섹션 8, 9에 따라 업데이트:
- 문제 유형별 구조화 응답 포맷 지시
- 의사 권유 정책 (위험 시에만)
- 언어 매칭

**Step 2: RAG 컨텍스트 빌드 통합**

`_build_context()`를 확장하여:
- 기존 건강 데이터 RAG (7일/30일 티어별)
- 벡터 검색 결과 (vector_search_service 호출)
- DeepSeek 보충 결과 (중국어 + 프리미엄)

**Step 3: 모델 라우팅 적용**

```python
def _select_model(tier: str) -> tuple[str, int]:
    if tier == "premium":
        return "gpt-4.1-nano", 2048
    return "gpt-4o-mini", 1024
```

**Step 4: Commit**

```bash
git add backend/app/services/ai_service.py
git commit -m "feat: integrate structured responses, vet policy, model routing"
```

---

## Phase 7: 백엔드 Vision API

### Task 7-1: Vision 건강체크 엔드포인트

**Files:**
- Modify: `backend/app/services/ai_service.py` (Vision 분석 함수 추가)
- Modify: `backend/app/routers/health_checks.py`
- Modify: `backend/app/schemas/` (Vision 요청/응답 스키마)

**Step 1: Vision 분석 함수**

`ai_service.py`에 추가:
```python
async def analyze_image(
    image_base64: str,
    mode: str,  # "full_body" | "part_specific" | "droppings" | "food"
    part: str | None,  # eye, beak, feather, foot (part_specific일 때)
    pet_id: str | None,
    language: str,
    db: AsyncSession,
) -> dict:
    """GPT-4o Vision으로 이미지 분석."""
    # 1. RAG 컨텍스트 (모드별 벡터 검색)
    # 2. (중국어) DeepSeek 보충
    # 3. 모드별 특화 프롬프트 구성
    # 4. GPT-4o Vision API 호출
    # 5. JSON 응답 파싱 및 반환
```

**Step 2: 엔드포인트 구현**

```python
@router.post("/pets/{pet_id}/health-checks/analyze")
async def analyze_health_check(
    pet_id: str,
    mode: str = Form(...),
    part: str | None = Form(None),
    image: UploadFile = File(...),
    current_user = Depends(get_current_user),
    tier: str = Depends(get_current_tier),
    db: AsyncSession = Depends(get_db),
):
    if tier != "premium":
        raise HTTPException(403, "프리미엄 전용 기능입니다")

    # 이미지 검증 (MIME, 크기)
    # base64 인코딩 (메모리에서)
    # ai_service.analyze_image() 호출
    # 결과 DB 저장
    # 반환
```

**Step 3: Commit**

```bash
git add backend/app/services/ai_service.py backend/app/routers/health_checks.py backend/app/schemas/
git commit -m "feat: add Vision health check analysis endpoint"
```

---

## Phase 8: 프론트엔드 건강체크 화면

### Task 8-1 ~ 8-4: Flutter 화면 구현

**Files:**
- Create: `lib/src/screens/health_check/health_check_main_screen.dart`
- Create: `lib/src/screens/health_check/health_check_camera_screen.dart`
- Create: `lib/src/screens/health_check/health_check_result_screen.dart`
- Create: `lib/src/services/ai/health_check_service.dart`
- Modify: `lib/src/router/app_router.dart` (라우트 추가)
- Modify: `lib/src/screens/home/home_screen.dart` (건강체크 카드 연결)

4개 화면 + 서비스:
1. **메인 화면**: 분석 대상 선택 (전체 외형/부위별/배변/먹이)
2. **카메라 화면**: 촬영 또는 갤러리 선택
3. **분석 중**: 로딩 애니메이션
4. **결과 화면**: findings 카드 + recommendations + severity 배지

---

## Phase 9: 통합 테스트 + 마무리

### Task 9-1: Staging 환경 통합 테스트

**체크리스트:**
- [ ] 프리미엄 코드 활성화: 유효한 코드 입력 시 30일 프리미엄 전환
- [ ] 프리미엄 코드 활성화: 이미 사용된 코드 거부
- [ ] 프리미엄 코드 활성화: 잘못된 코드 거부
- [ ] 프리미엄 만료: 30일 경과 후 Free 자동 전환
- [ ] 텍스트 채팅: Free 사용자 → GPT-4o-mini 응답
- [ ] 텍스트 채팅: Premium 사용자 → GPT-4.1-nano 응답
- [ ] SSE 스트리밍 정상 동작
- [ ] SSE 실패 시 동기 fallback
- [ ] HyDE 벡터 검색: 영/한/중 쿼리
- [ ] DeepSeek 중국어 보충: 프리미엄 중국어 쿼리
- [ ] DeepSeek 실패 시 무시하고 정상 응답
- [ ] Vision 건강체크: full_body, part_specific, droppings, food
- [ ] Vision: 무료 사용자 잠금
- [ ] 구조화 응답 포맷 (유형별)
- [ ] 의사 권유: 일반 질문에 불필요한 권유 없음
- [ ] 의사 권유: 위험 증상 시 권유 포함
- [ ] 레이트 리밋 동작 확인

### Task 9-2: Production 배포

```bash
# dev → main PR 생성
git checkout dev
git push origin dev
gh pr create --title "feat: AI 업그레이드 v2" --body "..."

# 코드 리뷰 후 머지 → Railway production 자동 배포
```

---

## 요약

| Phase | 핵심 산출물 | 예상 소요 |
|-------|-----------|----------|
| 0 | Railway staging 환경 | 설정 작업 |
| 1 | user_tiers + premium_codes 테이블 + 코드 활성화 서비스 | 백엔드 |
| 2 | SSE 스트리밍 엔드포인트 | 백엔드 |
| 3 | Flutter SSE 클라이언트 | 프론트엔드 |
| 4 | pgvector + HyDE + 적재 | 백엔드 (핵심) |
| 5 | DeepSeek 중국어 보충 | 백엔드 |
| 6 | 구조화 응답 + 라우팅 | 백엔드 |
| 7 | Vision API | 백엔드 |
| 8 | Flutter 건강체크 화면 | 프론트엔드 |
| 9 | 통합 테스트 + 배포 | 전체 |
