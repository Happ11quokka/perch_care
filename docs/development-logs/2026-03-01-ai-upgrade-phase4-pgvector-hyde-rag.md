# pgvector + HyDE 벡터 검색 RAG — Phase 4 구현, 코드 리뷰 및 수정 (2026-03-01)

**날짜**: 2026-03-01
**작성자**: Claude Code
**상태**: 완료

---

## 개요

Phase 4에서 PostgreSQL pgvector 확장을 도입하여 지식 베이스 벡터 검색 RAG 파이프라인을 구축하고, HyDE(Hypothetical Document Embeddings)를 적용하여 크로스링구얼 검색 품질을 확보했다.

Phase 2(에이전트 모듈)에서 로컬 ChromaDB로 검증한 HyDE + text-embedding-3-large 설정을 프로덕션 PostgreSQL pgvector 환경에 적용한 것이다. 코드 리뷰를 통해 P0 1건 / P1 3건 / P2 3건의 이슈를 발견하고 수정했다.

---

## 1. Phase 4 구현 내용

### 수정/신규 파일

| 파일 | 변경 유형 | 설명 |
|------|----------|------|
| `backend/docker-compose.yml` | **수정** | DB 이미지 `postgres:16-alpine` → `pgvector/pgvector:pg16` |
| `backend/requirements.txt` | **수정** | `pgvector==0.3.6` 추가 |
| `backend/app/config.py` | **수정** | 임베딩/벡터 검색 설정 4개 추가 |
| `backend/app/models/__init__.py` | **수정** | `KnowledgeChunk` import 추가 |
| `backend/app/models/knowledge_chunk.py` | **신규** | KnowledgeChunk 모델 (Vector(3072), chunk_hash unique) |
| `backend/alembic/versions/007_add_pgvector_knowledge.py` | **신규** | pgvector 확장 + knowledge_chunks 테이블 + HNSW 인덱스 |
| `backend/app/services/embedding_service.py` | **신규** | OpenAI 임베딩 + HyDE 가상 문서 생성 |
| `backend/app/services/vector_search_service.py` | **신규** | HyDE + pgvector 코사인 유사도 검색, graceful degradation |
| `backend/scripts/load_knowledge.py` | **신규** | 지식 마크다운 → 청킹 → 임베딩 → pgvector 적재 |
| `backend/app/main.py` | **수정** | lifespan에 pgvector 확장 활성화 + 벡터 검색 가용성 체크 |
| `backend/app/services/ai_service.py` | **수정** | `_build_system_message()`에 knowledge_context 파라미터 추가, `prepare_system_message()` 서비스 함수 신설 |
| `backend/app/routers/ai.py` | **수정** | SSE 엔드포인트에서 벡터 검색 통합, DB 세션 분리 |

### 핵심 아키텍처

#### 벡터 검색 RAG 데이터 흐름

```
[사용자 질문] "앵무새가 깃털을 뽑아요"
    │
    ├── [HyDE] GPT-4o-mini로 가상 영문 참고 문서 생성 (150~300단어)
    │       "Feather plucking (pterotillomania) in parrots is a common
    │        behavioral disorder characterized by..."
    │
    ├── [임베딩] text-embedding-3-large → 3072차원 벡터
    │
    ├── [pgvector] 코사인 유사도 검색 (HNSW 인덱스)
    │       SELECT ... FROM knowledge_chunks
    │       WHERE (embedding <=> :embedding::vector) < :max_distance
    │       ORDER BY embedding <=> :embedding::vector
    │       LIMIT 5
    │
    ├── [컨텍스트] 검색 결과를 시스템 메시지에 주입
    │       "[Avian Care Knowledge Base]
    │        --- health > feather-plucking (Overview) [relevance: 0.87] ---
    │        Feather plucking can be caused by..."
    │
    └── [응답] GPT-4o-mini/GPT-4.1-nano가 지식 베이스 기반 답변 생성
```

#### HyDE가 해결하는 문제

| 문제 | 해결 |
|------|------|
| 한국어 질문 ↔ 영어 지식 베이스 | HyDE가 질문을 영문 참고 문서로 변환 후 임베딩 |
| 짧은 질문 ↔ 긴 지식 문서 | 가상 문서가 실제 지식과 유사한 길이/구조 생성 |
| 구어체 질문 ↔ 학술적 지식 | "깃털 뽑아요" → "pterotillomania in parrots" 변환 |

Phase 2 에이전트 벤치마크에서 HyDE 유무에 따른 검색 품질:

| 시나리오 | HyDE 없음 (유사도) | HyDE 적용 (유사도) |
|---------|-------------------|-------------------|
| 한국어 → 영어 지식 | 0.17~0.24 | 0.82~0.87 |
| 중국어 → 영어 지식 | 0.15~0.22 | 0.70~0.85 |

#### knowledge_chunks 테이블 스키마

```sql
CREATE TABLE knowledge_chunks (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content     TEXT NOT NULL,
    embedding   vector(3072) NOT NULL,      -- text-embedding-3-large
    source      VARCHAR(500) NOT NULL,       -- "health/feather-plucking.md"
    category    VARCHAR(100) NOT NULL,       -- "health", "nutrition", etc.
    language    VARCHAR(10) NOT NULL,        -- "en", "zh"
    section_title VARCHAR(500) NOT NULL DEFAULT '',
    chunk_hash  VARCHAR(64) NOT NULL UNIQUE, -- SHA256(language:source:content)
    created_at  TIMESTAMPTZ DEFAULT now()
);

-- HNSW 벡터 인덱스 (코사인 유사도)
CREATE INDEX ix_knowledge_chunks_embedding_hnsw
    ON knowledge_chunks
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 128);
```

#### 설정 파라미터 (`config.py`)

| 설정 | 기본값 | 설명 |
|------|--------|------|
| `embedding_model` | `text-embedding-3-large` | 임베딩 모델 (3072차원) |
| `hyde_model` | `gpt-4o-mini` | HyDE 가상 문서 생성 모델 |
| `vector_search_top_k` | `5` | 최대 검색 결과 수 |
| `vector_search_min_similarity` | `0.3` | 최소 유사도 임계값 |

#### 지식 적재 파이프라인

```
knowledge/          knowledge-zh/
  ├── health/         ├── health/
  ├── nutrition/      ├── nutrition/
  └── ...             └── ...
       │                    │
       └──── chunker.py (H2/H3 섹션 기반 분할) ────┘
                    │
                    ├── 청크 해시 계산: SHA256(language:source:content)
                    ├── 배치 임베딩: text-embedding-3-large (100개씩)
                    └── 배치 INSERT: ON CONFLICT (chunk_hash) DO UPDATE (50개씩)
```

사용법:
```bash
cd backend
python -m scripts.load_knowledge              # 신규 청크만 적재
python -m scripts.load_knowledge --reset       # 전체 초기화 후 재적재
```

#### Graceful Degradation 전략

벡터 검색은 선택적 기능이며, 실패해도 AI 서비스는 정상 동작한다:

```
벡터 검색 시도
  ├─ 성공 → 지식 컨텍스트를 시스템 프롬프트에 주입
  └─ 실패 (pgvector 미설치, 빈 테이블, 타임아웃 등)
       └─ 빈 리스트 반환 → 기존 SYSTEM_PROMPT + RAG 컨텍스트만으로 응답
```

- 앱 시작 시 `check_vector_search_available()`로 가용성 확인
- `False` 상태일 때 60초마다 TTL 기반 재확인 (데이터 적재 후 자동 활성화)
- 검색 타임아웃 5초 초과 시 빈 결과 반환

---

## 2. 코드 리뷰 결과

Phase 4 구현 후 코드 리뷰를 진행하여 7건의 이슈를 발견했다.

### 이슈 요약

| 심각도 | 건수 | 내용 |
|--------|------|------|
| P0 | 1건 | vector 확장 생성 전 테이블 생성 시도 → 앱 기동 실패 |
| P1 | 3건 | 벡터 검색 영구 비활성화, chunk_hash 충돌, SSE 커넥션 풀 압박 |
| P2 | 3건 | 배치 삽입 비효율, 로그 민감정보 노출, 라우터 책임 혼재 |

---

### P0: vector 확장 미생성 상태에서 테이블 생성 시도

**파일**: `backend/app/main.py` — `lifespan()`

**문제**:
`Base.metadata.create_all()`이 `knowledge_chunks` 테이블의 `Vector(3072)` 타입을 생성하려고 할 때, pgvector 확장이 아직 활성화되지 않은 상태면 `type "vector" does not exist` 에러로 앱 시작이 실패한다.

```
[앱 시작]
  → Base.metadata.create_all()
    → CREATE TABLE knowledge_chunks (..., embedding vector(3072), ...)
      → ERROR: type "vector" does not exist  ← pgvector 확장 미설치
```

마이그레이션 007에서는 `CREATE EXTENSION IF NOT EXISTS vector`가 포함되어 있지만, `create_all()`은 Alembic과 별개로 실행된다.

**수정**:

```python
async with engine.begin() as conn:
    # pgvector 확장을 테이블 생성 전에 활성화 (Vector 타입 의존)
    await conn.execute(text("CREATE EXTENSION IF NOT EXISTS vector"))
    await conn.run_sync(Base.metadata.create_all)
```

**해결 원리**: `create_all` 직전에 동일 트랜잭션에서 `CREATE EXTENSION IF NOT EXISTS vector`를 실행하여, Vector 타입이 항상 사용 가능한 상태에서 테이블이 생성된다.

---

### P1-1: 벡터 검색 영구 비활성화 — 시작 시 1회 확인 후 재확인 없음

**파일**: `backend/app/services/vector_search_service.py`

**문제**:
`VECTOR_SEARCH_AVAILABLE` 전역 플래그가 시작 시 1회만 설정되었다. 시작 시점에 `knowledge_chunks` 테이블이 비어 있거나 일시 오류가 발생하면, 이후 데이터가 적재되어도 재시작 전까지 검색이 영구 비활성화되었다.

```
시간  상태
──────────────────────────────────
T0   앱 시작 → check() → 테이블 비어있음 → AVAILABLE=False
T1   python -m scripts.load_knowledge → 2,843 청크 적재
T2   사용자 질문 → AVAILABLE=False → 빈 결과 반환  ← 데이터 있는데 검색 안 됨
T3   앱 재시작 → check() → AVAILABLE=True ← 재시작해야만 활성화
```

**수정 전**:
```python
VECTOR_SEARCH_AVAILABLE: bool = False  # 전역 플래그, 시작 시 1회 설정

async def search_knowledge(...):
    if not VECTOR_SEARCH_AVAILABLE:  # 한번 False면 영구
        return []
```

**수정 후**:
```python
_vector_search_available: bool = False
_last_check_time: float = 0.0
_RECHECK_INTERVAL_SECONDS: float = 60.0

async def _is_vector_search_available(db: AsyncSession) -> bool:
    """Return cached availability, re-checking with TTL if currently False."""
    if _vector_search_available:
        return True  # True면 즉시 반환 (재확인 불필요)
    # False 상태일 때만 60초마다 재확인
    now = time.monotonic()
    if now - _last_check_time >= _RECHECK_INTERVAL_SECONDS:
        await check_vector_search_available(db)
    return _vector_search_available
```

**해결 원리**: `True` 상태에서는 추가 DB 호출 없이 즉시 반환하여 성능 영향이 없다. `False` 상태에서만 60초 TTL로 재확인하여, 데이터 적재 후 최대 60초 내에 자동 활성화된다. `check_vector_search_available()`의 쿼리도 `SELECT COUNT(*)` → `SELECT 1 ... LIMIT 1`로 경량화했다.

---

### P1-2: chunk_hash 충돌 — 동일 본문의 메타데이터 손실

**파일**: `backend/scripts/load_knowledge.py`

**문제**:
`chunk_hash`가 `content`만으로 계산되어, 서로 다른 문서/언어에서 동일한 본문이 나오면 `ON CONFLICT (chunk_hash) DO UPDATE`로 나중 것이 덮어써 출처/메타데이터가 손실된다.

```
en/health/diet.md → chunk: "Pellets should be 70% of diet" → hash=abc123
zh/health/diet.md → chunk: "Pellets should be 70% of diet" → hash=abc123 (동일!)
  → ON CONFLICT → en 청크의 source/language가 zh로 덮어쓰여짐
```

**수정 전**:
```python
chunk["chunk_hash"] = hashlib.sha256(chunk["content"].encode("utf-8")).hexdigest()
```

**수정 후**:
```python
hash_input = f"{chunk['language']}:{chunk['source']}:{chunk['content']}"
chunk["chunk_hash"] = hashlib.sha256(hash_input.encode("utf-8")).hexdigest()
```

**해결 원리**: 해시 입력에 `language`와 `source`를 포함하여, 동일 본문이라도 출처/언어가 다르면 별도 청크로 저장된다.

---

### P1-3: SSE 엔드포인트 DB 커넥션 풀 압박

**파일**: `backend/app/routers/ai.py` — `encyclopedia_stream()`

**문제**:
SSE 엔드포인트가 `Depends(get_db)` 세션을 받아 사전 조회(벡터 검색 + RAG)를 수행했다. `get_db`의 세션 수명은 요청이 완료될 때까지이므로, 스트리밍이 끝날 때까지(수 초~수십 초) DB 커넥션을 점유한다.

Phase 2에서 제너레이터 내부의 DB 사용을 분리했지만, `Depends(get_db)` 자체가 요청 수명 의존성이므로 커넥션 반환이 스트리밍 종료 후에야 이루어졌다.

```
시간  요청A                요청B               커넥션 풀 (max=5)
──────────────────────────────────────────────────────────────
T0   Depends(get_db)      -                   [1/5] ← 세션 생성
T1   벡터 검색 + RAG 완료  -                  [1/5]
T2   스트리밍 시작...      Depends(get_db)    [2/5] ← A 세션 미반환!
T3   토큰 yield...         스트리밍 시작...   [2/5]
...  (수 초간)
T10  스트리밍 완료          -                  [1/5] ← 이제야 A 세션 반환
```

**수정 전**:
```python
async def encyclopedia_stream(
    ...,
    db: AsyncSession = Depends(get_db),  # 요청 수명 세션
):
    knowledge_results = await search_knowledge(db, body.query)
    rag_context = await ai_service._build_rag_context(db, ...)
    system_message = ai_service._build_system_message(rag_context, ...)
```

**수정 후**:
```python
async def encyclopedia_stream(
    ...,
    # db 의존성 제거
):
    # 짧은 세션으로 사전 조회 후 즉시 반환
    async with async_session_factory() as prefetch_db:
        system_message = await ai_service.prepare_system_message(
            db=prefetch_db,
            query=body.query,
            pet_id=body.pet_id,
            pet_profile_context=body.pet_profile_context,
            user_id=current_user.id,
        )
    # prefetch_db 세션은 여기서 해제 — 스트리밍 중 커넥션 미점유
```

**해결 원리**: `Depends(get_db)` 대신 `async with async_session_factory()`로 수동 세션을 생성하여, 사전 조회 완료 즉시 커넥션을 반환한다. 스트리밍 중에는 DB 커넥션을 점유하지 않는다.

---

### P2-1: 배치 삽입 비효율 — row-by-row execute

**파일**: `backend/scripts/load_knowledge.py`

**문제**:
배치 단위로 순회하면서도 내부에서 row-by-row `await db.execute()`를 호출하여, 50건 배치에 50회의 DB 라운드트립이 발생했다.

**수정 전**:
```python
for chunk, embedding in zip(batch, batch_embs):
    await db.execute(text("""INSERT ..."""), {
        "content": chunk["content"],
        # ... 개별 파라미터
    })
    inserted += 1
```

**수정 후**:
```python
params_list = [
    {
        "content": chunk["content"],
        "embedding": str(embedding),
        # ... 배치 파라미터
    }
    for chunk, embedding in zip(batch, batch_embs)
]
await db.execute(text("""INSERT ..."""), params_list)  # 1회 호출로 배치 처리
inserted += len(params_list)
```

**해결 원리**: SQLAlchemy의 `execute(text, list[dict])` 호출 시 내부적으로 `executemany`로 변환되어 단일 라운드트립으로 배치가 처리된다.

---

### P2-2: 타임아웃 로그에 쿼리 원문 노출

**파일**: `backend/app/services/vector_search_service.py`

**문제**:
벡터 검색 타임아웃 시 사용자 질문의 앞 100자를 로그에 기록하여, 건강 관련 민감 정보가 서버 로그에 남을 수 있다.

```python
# 수정 전
logger.warning(f"Vector search timed out ... for query: {query[:100]}")

# 수정 후
logger.warning(f"Vector search timed out ... (query_len={len(query)})")
```

**해결 원리**: 쿼리 원문 대신 길이만 기록하여 디버깅에 필요한 최소 정보만 유지한다.

---

### P2-3: 라우터에서 RAG 조립 로직 직접 수행

**파일**: `backend/app/routers/ai.py`, `backend/app/services/ai_service.py`

**문제**:
SSE 엔드포인트 라우터에서 `search_knowledge()`, `format_knowledge_context()`, `_build_rag_context()`, `_build_system_message()`를 직접 호출하여, 서비스 레이어의 `ask()` 함수와 동일한 로직이 중복되었다. 이 패턴은 프로젝트의 기존 관례(라우터는 입출력/인증만 담당)와 불일치하며, 향후 RAG 로직 변경 시 수정 지점이 분산된다.

**수정**: `prepare_system_message()` 서비스 함수를 신설하여 RAG 조립 로직을 일원화.

```python
# ai_service.py — 신규 함수
async def prepare_system_message(
    db: AsyncSession,
    query: str,
    pet_id: str | None = None,
    pet_profile_context: str | None = None,
    user_id: UUID | None = None,
) -> str:
    """벡터 검색 + RAG 컨텍스트 조회 후 시스템 메시지를 반환한다."""
    knowledge_results = await search_knowledge(db, query)
    knowledge_context = format_knowledge_context(knowledge_results)
    rag_context = await _build_rag_context(db, pet_id, user_id=user_id)
    return _build_system_message(rag_context, pet_profile_context, knowledge_context)
```

`ask()`, `ask_stream()`, SSE 라우터 모두 이 함수를 호출하도록 통일:

```python
# ask() 내부
system_message = await prepare_system_message(db, query, pet_id, pet_profile_context, user_id)

# SSE 라우터 내부
async with async_session_factory() as prefetch_db:
    system_message = await ai_service.prepare_system_message(db=prefetch_db, ...)
```

---

## 3. 수정된 파일 목록 (코드 리뷰 반영)

| 파일 | 이슈 | 변경 유형 |
|------|------|----------|
| `backend/app/main.py` | P0 | 수정 |
| `backend/app/services/vector_search_service.py` | P1-1, P2-2 | 수정 |
| `backend/scripts/load_knowledge.py` | P1-2, P2-1 | 수정 |
| `backend/app/routers/ai.py` | P1-3, P2-3 | 수정 |
| `backend/app/services/ai_service.py` | P2-3 | 수정 |

---

## 4. 검증 체크리스트

- [ ] `docker compose up -d` — pgvector/pgvector:pg16 이미지 정상 기동
- [ ] `alembic upgrade head` — 마이그레이션 007 정상 실행 (CREATE EXTENSION + CREATE TABLE)
- [ ] `python -m scripts.load_knowledge --reset` — 지식 데이터 정상 적재
- [ ] 벡터 검색 가용성 — 앱 시작 로그에 "Vector search available" 출력
- [ ] HyDE 검색 — 한국어 질문으로 영어 지식 베이스 매칭 확인 (유사도 0.7+)
- [ ] 시스템 메시지에 `[Avian Care Knowledge Base]` 컨텍스트 포함 확인
- [ ] 빈 테이블 상태에서 앱 시작 → 검색 비활성화 → 데이터 적재 후 60초 내 자동 활성화
- [ ] SSE 스트리밍 중 DB 커넥션 풀 점유 없음 확인
- [ ] 중복 본문/다른 언어 청크 → 별도 저장 (chunk_hash 비충돌)
- [ ] pgvector 미설치 환경 → graceful degradation (검색 비활성, AI 정상 동작)
- [ ] `py_compile` 5개 파일 통과

---

## 5. 교훈 및 패턴 정리

### pgvector 확장과 create_all 순서

SQLAlchemy `Base.metadata.create_all()`은 Alembic 마이그레이션과 독립적으로 실행된다. `Vector` 타입 컬럼이 포함된 모델이 있으면, `create_all` 전에 반드시 `CREATE EXTENSION IF NOT EXISTS vector`를 실행해야 한다. 마이그레이션과 `create_all`을 병행하는 환경에서는 양쪽 모두에서 확장을 활성화하는 것이 안전하다.

### 전역 플래그의 상태 고착 방지 — TTL 패턴

시작 시 1회만 계산하는 전역 플래그는 일시적 오류나 데이터 미적재 상태를 영구적으로 캐시할 위험이 있다. `True`면 즉시 반환(비용 0), `False`일 때만 TTL 간격으로 재확인하는 비대칭 TTL 패턴을 사용하면, 정상 경로의 성능 영향 없이 상태 고착을 방지할 수 있다.

### chunk_hash 설계 — 고유성 범위 결정

해시 기반 멱등성에서 "동일"의 정의를 신중히 결정해야 한다. `content`만으로 해싱하면 서로 다른 문서/언어의 동일 본문이 충돌한다. 비즈니스 요구에 따라 해시 입력에 `language`, `source` 등 컨텍스트 정보를 포함하여 고유성 범위를 명확히 해야 한다.

### RAG 로직 일원화 — prepare_system_message 패턴

벡터 검색 + DB RAG + 시스템 프롬프트 조립이 여러 호출 경로(동기 ask, 스트리밍 ask_stream, SSE 엔드포인트)에서 반복될 때, 단일 서비스 함수로 추상화해야 한다. 이 함수가 DB 세션을 인자로 받으면, 호출자가 세션 수명을 제어할 수 있어 SSE 같은 장기 연결 시나리오에서도 유연하게 대응 가능하다.

### executemany와 SQLAlchemy text()

SQLAlchemy의 `session.execute(text(...), list[dict])`는 내부적으로 DBAPI `executemany`로 변환된다. row-by-row 호출 대비 라운드트립이 N → 1로 줄어들어, 대량 데이터 적재 시 유의미한 성능 향상을 얻을 수 있다.

---

## 6. Railway 벡터 DB 분리 배포 및 운영 수정

### 배경

Phase 4 코드(commit `b32a93a`)를 Railway staging에 배포했을 때, 메인 Postgres에 `CREATE EXTENSION IF NOT EXISTS vector`를 실행하면서 크래시가 발생했다. Railway 기본 Postgres에는 pgvector 확장이 설치되어 있지 않기 때문이다.

별도의 **pgVector-Railway** 서비스(pgvector 지원 Postgres 인스턴스)를 추가하고, knowledge_chunks 테이블을 해당 DB로 분리하여 해결했다.

### Railway 인프라 구성

```
┌──────────────┐     ┌─────────────────────┐
│   Postgres   │     │  pgVector-Railway    │
│  (메인 DB)   │     │  (벡터 전용 DB)      │
│  users, pets │     │  knowledge_chunks    │
│  weights,... │     │  pgvector extension  │
└──────┬───────┘     └──────────┬───────────┘
       │                        │
       │  DATABASE_URL          │  VECTOR_DATABASE_URL
       │                        │  (${{pgVector-Railway.DATABASE_URL}})
       └────────┬───────────────┘
            ┌───┴────┐
            │perch_  │
            │ care   │
            └────────┘
```

### 코드 변경 (벡터 DB 분리)

| 파일 | 변경 내용 |
|------|----------|
| `backend/app/config.py` | `vector_database_url: str = ""` 설정 추가 |
| `backend/app/database.py` | `vector_engine`, `vector_session_factory` 별도 생성 (조건부) |
| `backend/app/main.py` | 메인 DB에서 pgvector 제거, 벡터 DB 조건부 초기화 |
| `backend/app/models/knowledge_chunk.py` | 별도 `VectorBase(DeclarativeBase)` 사용 (메인 `Base`와 분리) |
| `backend/app/models/__init__.py` | `KnowledgeChunk` import 제거 (메인 Base.metadata에 포함 안 됨) |
| `backend/app/services/vector_search_service.py` | 자체 `vector_session_factory` 세션 사용, `db` 파라미터 제거 |
| `backend/app/services/ai_service.py` | `search_knowledge(query)` — db 파라미터 없이 호출 |
| `backend/alembic/versions/007_add_pgvector_knowledge.py` | no-op으로 변경 (벡터 DB 스키마는 lifespan에서 관리) |

#### 핵심 설계: 2-Base 분리

```python
# backend/app/models/base.py — 메인 DB
class Base(DeclarativeBase): ...

# backend/app/models/knowledge_chunk.py — 벡터 DB
class VectorBase(DeclarativeBase): ...
class KnowledgeChunk(VectorBase): ...
```

`MainBase.metadata.create_all()`은 메인 DB에만, `VectorBase.metadata.create_all()`은 벡터 DB에만 실행된다. VECTOR_DATABASE_URL이 미설정이면 벡터 관련 초기화를 전부 건너뛴다.

### load_knowledge.py asyncpg 호환 수정

Railway pgVector에 지식 데이터를 적재하면서 3건의 asyncpg 호환 이슈를 발견하고 수정했다.

#### 이슈 1: `::vector` 캐스트와 named parameter 충돌

```python
# 수정 전 — asyncpg가 :embedding과 :vector를 모두 bind parameter로 해석
VALUES (:content, :embedding::vector, ...)

# 수정 후 — CAST 구문으로 변경
VALUES (:content, CAST(:embedding AS vector), ...)
```

#### 이슈 2: executemany와 named parameter 비호환

P2-1에서 `execute(text, list[dict])` 배치 삽입으로 수정했으나, asyncpg의 `executemany`가 SQLAlchemy named parameter(`:param`)를 지원하지 않아 실패. row-by-row execute로 변경.

```python
# 수정 전 — asyncpg executemany 비호환
await db.execute(sql, params_list)

# 수정 후 — 개별 execute
for chunk, embedding in zip(batch, batch_embs):
    await db.execute(sql, {...})
```

> **교훈**: SQLAlchemy `text()` + asyncpg 조합에서는 `executemany`가 named parameter를 지원하지 않는다. 배치 삽입이 필요하면 SQLAlchemy Core `insert()`를 사용하거나, row-by-row로 처리해야 한다.

#### 이슈 3: 서버 default 미적용 (id, created_at)

ORM 모델의 `default=uuid.uuid4`, `default=lambda: datetime.now()`는 Python-side default이며, raw SQL `INSERT`에서는 적용되지 않는다.

```python
# 수정 전 — id, created_at 누락 → NOT NULL 에러
INSERT INTO knowledge_chunks (content, embedding, ...)

# 수정 후 — 서버 함수로 명시
INSERT INTO knowledge_chunks (id, ..., created_at)
VALUES (gen_random_uuid(), ..., now())
```

### 적재 결과

```
로컬 → Railway pgVector (외부 URL)
  Files:          274 (영어 232 + 중국어 42)
  Chunks:         2,843
  Embedding time: 16.5s
  Insert time:    922.7s (로컬↔Railway 네트워크 지연 포함)
  Total time:     939.2s
```

### Railway 벡터 검색 벤치마크

로컬에서 Railway pgVector에 직접 쿼리하여 검증:

| 쿼리 | 언어 | HyDE | Direct | 향상 |
|------|------|------|--------|------|
| feather plucking | EN | **0.803** | 0.692 | +16% |
| Can parrots eat avocado? | EN | **0.884** | 0.663 | +33% |
| symptoms of psittacosis | EN | **0.813** | 0.671 | +21% |
| 앵무새가 깃털을 뽑아요 | KO | **0.828** | 0.450 | +84% |
| 앵무새에게 아보카도를 줘도 되나요? | KO | **0.868** | 0.418 | +108% |
| 我的鹦鹉拔自己的羽毛怎么办 | ZH | **0.762** | 0.635 | +20% |
| 鹦鹉可以吃牛油果吗 | ZH | **0.868** | 0.627 | +38% |
| 虎皮鹦鹉怎么训练上手 | ZH | **0.712** | 0.651 | +9% |

한국어 쿼리에서 HyDE 효과가 가장 극적 (직접 검색 0.4대 → HyDE 0.8대, +84~108%).

### API 통합 테스트 (LangSmith 트레이스 확인)

```bash
curl -X POST "https://perchcare-staging.up.railway.app/api/v1/ai/encyclopedia/stream" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"query":"我的鹦鹉拔自己的羽毛怎么办","history":[]}'
```

- SSE 스트리밍 정상 동작, 토큰 단위 응답
- LangSmith 트레이스: `ai_encyclopedia_ask_stream_core`, 2.32초 응답
- 벡터 검색 → HyDE → 시스템 프롬프트 주입 → GPT 응답 파이프라인 동작 확인

---

## 7. max_tokens 티어 라우팅 버그 수정

### 문제

`AiEncyclopediaRequest` 스키마의 `max_tokens` 기본값이 512로 설정되어 있어, 클라이언트가 값을 명시하지 않으면 `min(512, tier_max)` 로직에 의해 항상 512로 고정되었다.

```
_select_model("free")    → ("gpt-4o-mini", 1024)
_select_model("premium") → ("gpt-4.1-nano", 2048)

effective = min(body.max_tokens=512, tier_max)
  free:    min(512, 1024) = 512  ← 설계상 1024이어야 함
  premium: min(512, 2048) = 512  ← 설계상 2048이어야 함
```

LangSmith 트레이스에서 `max_tokens: 512`로 확인하여 발견.

### 수정

| 파일 | 변경 |
|------|------|
| `backend/app/schemas/ai.py` | `max_tokens` 기본값 512 → 2048 |
| `backend/app/services/ai_service.py` | `ask()` 함수 `max_tokens` 기본값 512 → 2048 |

수정 후 `min(request, tier_max)` 로직이 정상 동작:
- **free**: min(2048, 1024) = **1024**
- **premium**: min(2048, 2048) = **2048**

---

## 8. 검증 체크리스트 (업데이트)

- [x] Railway pgVector-Railway 서비스 Online
- [x] `VECTOR_DATABASE_URL` 참조 변수 설정 (`${{pgVector-Railway.DATABASE_URL}}`)
- [x] perch_care → pgVector-Railway 서비스 연결선 확인
- [x] knowledge_chunks 2,843건 적재 확인 (`SELECT count(*) FROM knowledge_chunks`)
- [x] 벡터 검색 벤치마크 — 한/영/중 모두 HyDE 유사도 0.7+ 확인
- [x] SSE 스트리밍 API 호출 → LangSmith 트레이스 정상 기록
- [x] max_tokens 티어별 적용 수정 (512 → 1024/2048)
- [ ] LangSmith에서 수정 후 max_tokens 1024 확인 (재배포 후)
