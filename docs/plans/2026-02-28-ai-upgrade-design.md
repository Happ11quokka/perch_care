# 앵박사 AI 업그레이드 설계 문서

**작성일:** 2026-02-28
**상태:** 설계 완료, 구현 대기

---

## 1. 배경 및 목적

### 현재 상태
- GPT-4o-mini 기반 텍스트 전용 채팅 (앵박사 AI 백과사전)
- 응답 전체 대기 후 표시 (스트리밍 없음)
- 최대 512 토큰 (약 5줄) 응답
- 최근 7일 건강 데이터 RAG
- AI 이미지 건강체크 미구현 (백엔드 엔드포인트만 존재)

### 업그레이드 목표
앵박사를 **프리미엄 AI 서비스**로 전환하여 사용자 가치를 극대화하고, 추후 유료화 기반을 마련한다.

### 핵심 변경사항
1. **SSE 스트리밍** — ChatGPT처럼 실시간 토큰별 응답 표시
2. **GPT-4o 업그레이드** — 더 정확하고 상세한 답변
3. **AI Vision 건강체크** — 사진 촬영으로 앵무새 건강 분석
4. **RAG 강화** — 30일 데이터 + 건강체크 이력 컨텍스트
5. **Free/Premium 티어** — 과금 시스템 기반 구축

---

## 2. 티어 시스템

| 기능 | 무료 (Free) | 프리미엄 (Premium) |
|------|------------|-------------------|
| AI 모델 | GPT-4o-mini | GPT-4o |
| 응답 토큰 | 1024 | 2048 |
| SSE 스트리밍 | O | O |
| AI 건강체크 | X (잠금) | O |
| RAG 범위 | 7일 | 30일 + 건강이력 |
| 시스템 프롬프트 | 기본 | 강화 (전문 수의사 AI) |
| 사용 횟수 | 무제한 | 무제한 |
| 과금 | - | 추후 결정 |

### 데이터 모델: `user_tiers`
```
id (UUID PK)
user_id (FK → users, UNIQUE)
tier ("free" | "premium")
premium_started_at (nullable)
premium_expires_at (nullable)
created_at, updated_at
```

---

## 3. SSE 스트리밍 아키텍처

### 데이터 흐름
```
[Flutter] POST /ai/encyclopedia/stream
    ↓
[FastAPI] StreamingResponse (text/event-stream)
    ↓
[OpenAI] stream=True → async for chunk
    ↓
[SSE] data: {"token": "앵"}\n\n
      data: {"token": "무"}\n\n
      ...
      data: {"done": true}\n\n
    ↓
[Flutter] http.Client.send() → response.stream
    ↓
[UI] setState() per token → 실시간 텍스트 업데이트
```

### SSE 이벤트 포맷
```
data: {"token": "text_chunk"}\n\n      // 토큰 전달
data: {"done": true}\n\n               // 스트림 완료
data: {"error": "error_message"}\n\n   // 에러 발생 시
```

### Fallback 전략
SSE 실패 시 → 기존 `POST /ai/encyclopedia` (동기) 엔드포인트로 자동 전환

---

## 4. AI Vision 건강체크

### 분석 모드

**전체 외형 (full_body):**
- 사진 1장으로 전반적 건강 상태 판단
- 분석 항목: 깃털 상태, 자세/균형, 눈 상태, 부리 상태, 발/발톱, 전체 체형

**부위별 (part_specific):**
- 사용자가 부위 선택 후 근접 촬영
- 지원 부위: 눈(eye), 부리(beak), 깃털(feather), 발(foot), 배변(droppings)
- 부위별 특화된 분석 기준 적용

### 응답 구조 (JSON)
```json
{
  "findings": [
    {"area": "feather", "observation": "깃털 윤기가 양호합니다", "severity": "normal"}
  ],
  "overall_status": "normal",
  "confidence_score": 85.5,
  "recommendations": ["정기적인 수욕을 권장합니다"],
  "summary": "전반적으로 건강한 상태입니다"
}
```

### 화면 플로우
```
[홈 화면] AI 건강체크 카드 탭
    ↓
[건강체크 메인] 전체 외형 / 부위 선택
    ↓ (무료 사용자: 프리미엄 안내)
[카메라 화면] 촬영 또는 갤러리 선택
    ↓
[분석 중] 로딩 애니메이션
    ↓
[결과 화면] 상태 배지 + 발견사항 + 추천사항
```

### 이미지 처리 전략

#### 결정: 패스스루 (서버 저장 안 함)

이미지를 서버에 영구 저장하지 않고, 메모리에서 바로 OpenAI Vision API로 전송한 뒤 **분석 결과 텍스트만 DB에 저장**한다.

#### 데이터 흐름
```
[Flutter] 사진 촬영/갤러리 선택
    ↓
POST /api/v1/pets/{pet_id}/health-checks/analyze (multipart/form-data)
    ↓
[FastAPI] 메모리에서 base64 인코딩 (디스크 저장 없음)
    ↓
[OpenAI GPT-4o Vision API] 이미지 + 분석 프롬프트 전송
    ↓
[LangChain → LangSmith] 트레이스 자동 기록 (이미지 + 입출력 포함)
    ↓
[DB] 분석 결과(JSON)만 저장 → 앱에서 결과 텍스트로 이력 표시
```

#### 선택 근거

| 항목 | 패스스루 (선택) | 서버 저장 |
|------|----------------|----------|
| 서버 저장 비용 | **$0** | 사용자 1,000명 기준 ~$1-2/월 |
| 이미지 재확인 (개발자) | **LangSmith 트레이스에서 확인 가능** | 서버에서 직접 확인 |
| 이미지 재확인 (사용자) | X (결과 텍스트만 표시) | O (과거 사진 열람 가능) |
| 재분석 가능 여부 | X | O |
| 구현 복잡도 | **단순** (업로드 저장 로직 불필요) | 파일 저장 + 정리 로직 필요 |
| 개인정보 리스크 | **낮음** (이미지 미보관) | 이미지 보관에 따른 관리 필요 |

#### LangSmith 활용

LangChain을 통해 OpenAI Vision API를 호출하면, LangSmith에 다음이 자동 기록된다:
- **입력:** base64 이미지 + 분석 프롬프트
- **출력:** AI 분석 결과 JSON
- **메타데이터:** 레이턴시, 토큰 수, 비용

개발자/관리자는 LangSmith 대시보드에서 과거 이미지와 분석 결과를 모두 확인할 수 있으므로, 디버깅/품질 관리 목적의 이미지 보관은 별도 저장 없이 충족된다.

> **참고:** LangSmith 데이터 보관 기간은 플랜에 따라 다름 (Free: 14일, Plus: 400일)

#### 향후 확장 (사용자 이미지 열람이 필요해질 경우)

사용자에게 과거 건강체크 사진을 보여줘야 하는 기능이 추가될 경우, Cloudflare R2로 전환한다:

| 서비스 | 저장 비용 | 전송 비용 | 비고 |
|--------|----------|----------|------|
| Cloudflare R2 | $0.015/GB/월 | **무료** | 가장 저렴, 추천 |
| AWS S3 | $0.023/GB/월 | $0.09/GB | 가장 보편적 |

사용자 1,000명 × 월 8회 × 2MB = ~16GB/월 → R2 기준 **월 $0.24**

---

## 5. RAG 컨텍스트 강화

### 5-1. 구조화된 데이터 RAG (기존 방식 확장)

#### 무료 (현행 유지)
- 최근 7일 체중, 사료, 음수량

#### 프리미엄 (신규)
- 최근 30일 체중/사료/음수량
- 최근 AI 건강체크 결과 (최대 5건)
- BHI 점수 이력
- daily_records (기분, 활동 수준)
- 반려동물 성장 단계 정보

### 5-2. 벡터 검색 기반 RAG (신규)

앵무새 질병, 영양, 행동 등 **비정형 지식 데이터**를 벡터 임베딩으로 저장하고, 사용자 질문과 의미적으로 유사한 문서를 검색하여 LLM 컨텍스트에 주입한다.

#### 기술 선택: pgvector (PostgreSQL 확장)

| 항목 | 선택 | 이유 |
|------|------|------|
| 벡터DB | pgvector (PostgreSQL 확장) | 별도 인프라 불필요, Railway PostgreSQL 지원, 기존 DB 활용 |
| 임베딩 모델 | text-embedding-3-small (1536차원) | 저비용 ($0.02/1M tokens), 충분한 성능 |
| 검색 알고리즘 | IVFFlat (코사인 유사도) | 10만 건 이하 규모에 적합, 설정 간단 |
| 청크 크기 | 500자 | 앵무새 의학 정보 단위에 적합한 크기 |

#### 전체 아키텍처

```
[지식 데이터 적재 — 1회성]
앵무새 질병 백과 / 영양 가이드 / 종별 특성 문서
    ↓
텍스트 청킹 (500자 단위)
    ↓
OpenAI Embedding API (text-embedding-3-small)
    ↓
pgvector 테이블에 저장

[질의 시 — 매 요청]
사용자 질문: "앵무새가 깃털을 뽑아요"
    ↓
질문 임베딩 생성
    ↓
pgvector 코사인 유사도 검색 (top 3~5)
    ↓
검색된 문서 + 구조화된 건강 데이터 → LLM 프롬프트에 주입
    ↓
GPT-4o가 컨텍스트 기반 답변 생성
```

#### Railway 환경 구축 방법

**Step 1. Docker 이미지 변경**

기존 `postgres:16-alpine`을 pgvector 지원 이미지로 교체한다.

```yaml
# docker-compose.yml
services:
  db:
    image: pgvector/pgvector:pg16    # 기존: postgres:16-alpine
    # 나머지 설정 동일
```

Railway 배포 시에는 Railway PostgreSQL 플러그인에서 직접 pgvector 확장을 활성화한다:

```sql
-- Railway PostgreSQL 콘솔에서 실행
CREATE EXTENSION IF NOT EXISTS vector;
```

**Step 2. 데이터 모델**

```
knowledge_chunks 테이블:
├── id (UUID PK)
├── content (TEXT, NOT NULL)          -- 원본 텍스트 청크
├── embedding (VECTOR(1536))          -- 임베딩 벡터
├── source (VARCHAR)                  -- 출처 (예: "avian_diseases", "nutrition_guide")
├── category (VARCHAR)                -- 카테고리 (예: "질병", "영양", "행동")
├── metadata (JSONB)                  -- 추가 메타데이터 (종, 태그 등)
└── created_at (TIMESTAMPTZ)
```

**Step 3. Alembic 마이그레이션**

```python
# backend/alembic/versions/XXX_add_pgvector_knowledge.py

from alembic import op
import sqlalchemy as sa
from pgvector.sqlalchemy import Vector

def upgrade():
    # pgvector 확장 활성화
    op.execute("CREATE EXTENSION IF NOT EXISTS vector")

    # 지식 청크 테이블 생성
    op.create_table(
        "knowledge_chunks",
        sa.Column("id", sa.UUID, primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("content", sa.Text, nullable=False),
        sa.Column("embedding", Vector(1536)),
        sa.Column("source", sa.String(100)),
        sa.Column("category", sa.String(50)),
        sa.Column("metadata", sa.JSON, nullable=True),
        sa.Column("created_at", sa.DateTime, server_default=sa.func.now()),
    )

    # IVFFlat 인덱스 (코사인 유사도)
    op.execute("""
        CREATE INDEX ix_knowledge_chunks_embedding
        ON knowledge_chunks
        USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100)
    """)

    # 카테고리 검색용 인덱스
    op.create_index("ix_knowledge_chunks_category", "knowledge_chunks", ["category"])

def downgrade():
    op.drop_table("knowledge_chunks")
    op.execute("DROP EXTENSION IF EXISTS vector")
```

**Step 4. 임베딩 서비스**

```python
# backend/app/services/embedding_service.py

from openai import AsyncOpenAI

client = AsyncOpenAI()

EMBEDDING_MODEL = "text-embedding-3-small"  # 1536차원, $0.02/1M tokens

async def create_embedding(text: str) -> list[float]:
    """텍스트를 1536차원 벡터로 변환"""
    response = await client.embeddings.create(
        model=EMBEDDING_MODEL,
        input=text
    )
    return response.data[0].embedding

def chunk_text(text: str, chunk_size: int = 500) -> list[str]:
    """문서를 의미 단위로 청킹 (문장 경계 존중)"""
    sentences = text.replace("\n", " ").split(". ")
    chunks = []
    current = ""

    for sentence in sentences:
        if len(current) + len(sentence) > chunk_size and current:
            chunks.append(current.strip())
            current = sentence
        else:
            current += (". " if current else "") + sentence

    if current.strip():
        chunks.append(current.strip())

    return chunks
```

**Step 5. 벡터 검색 서비스**

```python
# backend/app/services/vector_search_service.py

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

async def search_similar_knowledge(
    db: AsyncSession,
    query: str,
    top_k: int = 3,
    category: str = None,
    min_similarity: float = 0.7
) -> list[dict]:
    """질문과 유사한 지식 청크를 코사인 유사도로 검색"""
    query_embedding = await create_embedding(query)

    sql = text("""
        SELECT content, source, category,
               1 - (embedding <=> :embedding::vector) AS similarity
        FROM knowledge_chunks
        WHERE (:category IS NULL OR category = :category)
        HAVING 1 - (embedding <=> :embedding::vector) >= :min_similarity
        ORDER BY embedding <=> :embedding::vector
        LIMIT :top_k
    """)

    result = await db.execute(sql, {
        "embedding": str(query_embedding),
        "category": category,
        "min_similarity": min_similarity,
        "top_k": top_k,
    })

    return [
        {"content": r.content, "source": r.source, "similarity": r.similarity}
        for r in result.fetchall()
    ]
```

**Step 6. 기존 RAG 통합 (ai_service.py 수정)**

```python
# 기존 build_context 함수에 벡터 검색 추가

async def build_rag_context(pet_id, user_question, tier, db):
    # 1. 구조화된 건강 데이터 (기존)
    health_context = await get_health_data_context(pet_id, tier, db)

    # 2. 벡터 검색 지식 데이터 (프리미엄만)
    knowledge_context = ""
    if tier == "premium":
        docs = await search_similar_knowledge(db, user_question, top_k=3)
        if docs:
            knowledge_context = "\n\n[참고 의학 자료]\n" + "\n---\n".join(
                f"({d['source']}) {d['content']}" for d in docs
            )

    # 3. 합쳐서 시스템 프롬프트에 주입
    return health_context + knowledge_context
```

**Step 7. 지식 데이터 적재 스크립트**

```python
# backend/scripts/load_knowledge.py

"""앵무새 지식 데이터를 벡터DB에 적재 (1회성)"""

SOURCES = [
    {"file": "data/avian_diseases.txt",     "source": "avian_diseases",     "category": "질병"},
    {"file": "data/parrot_nutrition.txt",    "source": "parrot_nutrition",   "category": "영양"},
    {"file": "data/species_guide.txt",       "source": "species_guide",      "category": "종별특성"},
    {"file": "data/behavior_patterns.txt",   "source": "behavior_patterns",  "category": "행동"},
]

async def load_all(db: AsyncSession):
    for src in SOURCES:
        text_content = open(src["file"], encoding="utf-8").read()
        chunks = chunk_text(text_content, chunk_size=500)

        for chunk in chunks:
            embedding = await create_embedding(chunk)
            await db.execute(
                insert(KnowledgeChunk).values(
                    content=chunk,
                    embedding=embedding,
                    source=src["source"],
                    category=src["category"],
                )
            )
    await db.commit()
    print(f"총 {count}개 청크 적재 완료")
```

#### 추가 패키지

```txt
# requirements.txt 추가
pgvector==0.3.6
```

#### 비용 분석

| 항목 | 비용 |
|------|------|
| text-embedding-3-small | $0.02 / 1M tokens |
| 지식 문서 1,000개 임베딩 (1회) | ~$0.01 미만 |
| 질문당 임베딩 (검색 시) | ~$0.000002 |
| pgvector 인프라 | 무료 (PostgreSQL 확장) |
| **총 추가 비용** | **사실상 무시 가능** |

#### 지식 데이터 소스 (확보 필요)

| 카테고리 | 내용 | 예상 문서 수 |
|----------|------|-------------|
| 질병 | 앵무새 주요 질병 증상/원인/대응 | ~100건 |
| 영양 | 종별 영양 요구량, 금지 식품 | ~50건 |
| 종별 특성 | 종별 수명, 크기, 성격, 관리법 | ~30건 |
| 행동 | 행동 패턴, 스트레스 징후, 훈련법 | ~50건 |

### 5-3. 프리미엄 시스템 프롬프트

```
"You are Dr. Parrot (앵박사), a board-certified avian veterinarian AI
with extensive knowledge of parrot species, diseases, nutrition, and behavior.
You have access to this pet's detailed health records.
Provide structured, evidence-based answers.
If evidence is uncertain, recommend consulting a veterinarian.
Always respond in the SAME language as the user's message."
```

---

## 6. 구현 순서

| Phase | 내용 | 새 파일 | 수정 파일 |
|-------|------|---------|----------|
| 1 | DB + Tier 시스템 | 4 | 4 |
| 2 | 백엔드 SSE 스트리밍 | 0 | 3 |
| 3 | 프론트엔드 SSE 스트리밍 | 1 | 3 |
| 4 | 백엔드 Vision API | 1 | 3 |
| 5 | 프론트엔드 건강체크 화면 | 4 | 6 |
| 6-1 | 구조화된 데이터 RAG 강화 | 0 | 1 |
| 6-2 | pgvector 설정 + 벡터 검색 RAG | 3 | 3 |
| 6-3 | 지식 데이터 확보 및 적재 | 5+ | 0 |
| 7 | 다국어 & 마무리 | 0 | 3 |
| **합계** | | **14+** | **23** |

### Phase 6-2 상세 (벡터 검색 RAG)

| 작업 | 파일 | 유형 |
|------|------|------|
| pgvector 마이그레이션 | `alembic/versions/XXX_add_pgvector_knowledge.py` | 새 파일 |
| 임베딩 서비스 | `app/services/embedding_service.py` | 새 파일 |
| 벡터 검색 서비스 | `app/services/vector_search_service.py` | 새 파일 |
| AI 서비스 RAG 통합 | `app/services/ai_service.py` | 수정 |
| Docker 이미지 변경 | `docker-compose.yml` | 수정 |
| 패키지 추가 | `requirements.txt` | 수정 |

---

## 7. 기술 결정 사항

| 결정 | 선택 | 이유 |
|------|------|------|
| 스트리밍 방식 | SSE (Server-Sent Events) | 단방향 통신에 적합, FastAPI StreamingResponse 네이티브 지원, 추가 패키지 불필요 |
| AI 모델 | GPT-4o (프리미엄) | Vision 지원, 최고 품질, OpenAI 생태계 유지 |
| Tier 저장 | 별도 테이블 | User 테이블 분리, 향후 과금 이력/시험 기간 확장 용이 |
| Vision 엔드포인트 | 업로드+분석 통합 | 레이턴시 감소, 클라이언트 로직 단순화 |
| SSE 파싱 | 직접 구현 | ~15줄 코드, 별도 패키지 의존성 불필요 |
| 건강체크 라우팅 | home 브랜치 중첩 | 하단 네비게이션 변경 없이 접근 가능 |
| 건강체크 이미지 | 패스스루 (서버 미저장) | 저장 비용 $0, LangSmith에서 이미지 확인 가능, 개인정보 리스크 최소화 |
| 이미지 확장 전략 | Cloudflare R2 (필요 시) | 전송 비용 무료, 저장 $0.015/GB/월, 가장 저렴 |
| 벡터DB | pgvector (PostgreSQL 확장) | 별도 인프라/비용 없음, Railway PostgreSQL 지원, 기존 DB에서 바로 사용 |
| 임베딩 모델 | text-embedding-3-small | 1536차원, $0.02/1M tokens 저비용, 한국어 성능 양호 |
| 벡터 인덱스 | IVFFlat | 10만 건 이하 규모에 적합, HNSW 대비 메모리 효율적 |
| 청크 전략 | 문장 경계 기준 500자 | 의학 정보 단위 보존, 검색 정확도 최적화 |
