# Vector Search 15s 타임아웃 노이즈 수정 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `Vector search timed out after 15.0s` 로그 노이즈의 근본 원인(단일 15초 예산 안에 HyDE LLM 호출 + 임베딩 + DB 쿼리가 전부 묶여 있고, OpenAI 클라이언트의 transport 타임아웃이 기본값 600초인 구조)을 제거한다 — HyDE에 개별 타임아웃 + 원본 쿼리 폴백을 넣고, 단건 임베딩 호출에 짧은 transport 타임아웃을 준다.

**Architecture:** `search_knowledge()`의 15초 `asyncio.wait_for`는 최후 방어선(backstop)으로 유지한다. 그 안의 가장 느린 단계인 HyDE(gpt-4o-mini, ≤400 tokens)는 5초를 넘으면 가설 문서 없이 **원본 쿼리를 그대로 임베딩**하도록 폴백한다(HyDE는 검색 정확도 향상용 최적화일 뿐, 없어도 검색은 동작). 단건 임베딩 호출은 `client.with_options(timeout=10, max_retries=1)`로 transport 레벨에서 fail-fast 시킨다. **배치 임베딩(`create_embeddings_batch`)은 건드리지 않는다** — `scripts/load_knowledge.py`가 대량 배치를 보내므로 10초 제한이 정당한 호출을 죽일 수 있다.

**Tech Stack:** Python 3.10 / FastAPI / openai AsyncOpenAI / pytest + pytest-asyncio (requirements는 0.24 핀, 로컬 설치는 1.3.0 — 둘 다 strict mode 기본이라 async 테스트에 `@pytest.mark.asyncio` 마커 필수. DeprecationWarning은 버전에 따라 안 나올 수 있음)

---

## 배경 (조사 결과, 2026-07-13)

- production 로그에서 `Vector search timed out after 15.0s (query_len=17)` 관측.
- 타임아웃 블록: [vector_search_service.py:92-95](../../../backend/app/services/vector_search_service.py) — `asyncio.wait_for(_search_knowledge_impl(...), timeout=15.0)`이 **HyDE LLM 호출 → OpenAI 임베딩 → pgvector 쿼리 전체**를 감싼다.
- DB는 병목이 아님: `knowledge_chunks` 2,946행, 시퀀셜 스캔이어도 밀리초 단위 (벡터 인덱스 없음 — 현재 규모에선 불필요).
- `AsyncOpenAI` 기본 transport 타임아웃은 600초, 기본 재시도 2회 → 커넥션이 한 번 매달리면 15초 예산을 통째로 소진.
- `generate_hypothetical_document()`는 **예외**에는 원본 쿼리로 폴백하지만 **느림**에는 폴백하지 않음 — 이 비대칭이 핵심 결함.
- 타임아웃 발생 시 `search_knowledge`는 빈 리스트 반환(graceful degradation) → AI 답변에서 지식 컨텍스트만 빠짐. 단, 호출부 `prepare_system_message`의 `asyncio.gather`가 전체 완료를 기다리므로 **사용자 채팅 응답도 최대 15초 지연**됨.

## File Structure

| 파일 | 작업 | 책임 |
|------|------|------|
| `backend/app/config.py` | Modify (41-44행 부근) | `hyde_timeout_seconds`, `openai_timeout_seconds` 설정 추가 |
| `backend/app/services/embedding_service.py` | Modify | HyDE 개별 타임아웃 + 폴백, 단건 임베딩용 fast 클라이언트 |
| `backend/app/tests/test_vector_search_timeout.py` | Create | 타임아웃 폴백 단위 테스트 3건 (외부 API·DB 불필요) |

`vector_search_service.py`는 수정하지 않는다 — 15초 backstop과 graceful degradation은 그대로 옳다.

---

### Task 1: 타임아웃 설정 추가 (config.py)

**Files:**
- Modify: `backend/app/config.py` (42행 `hyde_model` 아래)

- [ ] **Step 1: 설정 필드 2개 추가**

`hyde_model: str = "gpt-4o-mini"` 바로 아래에:

```python
    hyde_timeout_seconds: float = 5.0
    openai_timeout_seconds: float = 10.0
```

(pydantic Settings 기본값이 있으므로 env 미설정이어도 안전 — Railway 환경변수 추가 불필요.)

- [ ] **Step 2: import 확인**

Run: `cd /Users/imdonghyeon/perch_care/backend && python -c "from app.config import get_settings; s=get_settings(); print(s.hyde_timeout_seconds, s.openai_timeout_seconds)"`
Expected: `5.0 10.0`

> 주의: 이 명령은 `.env`가 필요할 수 있음. 실패 시 `python -c` 검증은 생략하고 Task 3의 pytest로 검증 (테스트는 이미 로컬에서 도는 것이 확인됨 — 61개 수집).

### Task 2: 실패하는 테스트 작성 (TDD)

**Files:**
- Create: `backend/app/tests/test_vector_search_timeout.py`

- [ ] **Step 1: 테스트 파일 작성**

```python
"""HyDE/벡터 검색 타임아웃 폴백 테스트 (외부 API·DB 불필요)."""
import asyncio

import pytest

from app.services import embedding_service, vector_search_service


@pytest.mark.asyncio
async def test_hyde_timeout_falls_back_to_original_query(monkeypatch):
    """HyDE LLM 호출이 느리면 가설 문서 없이 원본 쿼리를 반환한다."""

    async def slow_create(**kwargs):
        await asyncio.sleep(5)

    monkeypatch.setattr(
        embedding_service._openai_client.chat.completions, "create", slow_create
    )
    result = await embedding_service.generate_hypothetical_document(
        "앵무새 깃털 빠짐", timeout_seconds=0.05
    )
    assert result == "앵무새 깃털 빠짐"


@pytest.mark.asyncio
async def test_hyde_api_error_falls_back_to_original_query(monkeypatch):
    """기존 계약 회귀 테스트: API 예외 시에도 원본 쿼리로 폴백."""

    async def failing_create(**kwargs):
        raise RuntimeError("api down")

    monkeypatch.setattr(
        embedding_service._openai_client.chat.completions, "create", failing_create
    )
    result = await embedding_service.generate_hypothetical_document("query")
    assert result == "query"


@pytest.mark.asyncio
async def test_search_knowledge_backstop_timeout_returns_empty(monkeypatch):
    """전체 파이프라인이 backstop을 넘기면 빈 리스트 반환 (graceful degradation)."""

    async def hang(*args, **kwargs):
        await asyncio.sleep(5)

    monkeypatch.setattr(vector_search_service, "_search_knowledge_impl", hang)
    monkeypatch.setattr(vector_search_service, "_vector_search_available", True)
    monkeypatch.setattr(
        vector_search_service, "_get_vector_session_factory", lambda: object()
    )
    results = await vector_search_service.search_knowledge("q", timeout_seconds=0.05)
    assert results == []
```

- [ ] **Step 2: 실패 확인**

Run: `cd /Users/imdonghyeon/perch_care/backend && python -m pytest app/tests/test_vector_search_timeout.py -v`
Expected:
- `test_hyde_timeout_falls_back_to_original_query` **FAIL** (현재 `generate_hypothetical_document`는 `timeout_seconds` 파라미터가 없음 → TypeError)
- `test_hyde_api_error_falls_back_to_original_query` PASS (기존 동작)
- `test_search_knowledge_backstop_timeout_returns_empty` PASS (기존 동작)

> `@pytest.mark.asyncio` 마커가 없으면 strict mode에서 skip/경고 처리되므로 반드시 확인. `asyncio_default_fixture_loop_scope` DeprecationWarning은 무시해도 된다.

### Task 3: embedding_service 구현

**Files:**
- Modify: `backend/app/services/embedding_service.py`

- [ ] **Step 1: 구현**

```python
"""
Embedding service — OpenAI text-embedding-3-large + HyDE hypothetical document generation.

Reuses proven HyDE prompt from agent/vector_store.py.
"""
import asyncio
import logging

from openai import AsyncOpenAI

from app.config import get_settings

logger = logging.getLogger(__name__)

settings = get_settings()

_openai_client = AsyncOpenAI(api_key=settings.openai_api_key)
# 단건 호출용 fail-fast 클라이언트 — 배치 임베딩(load_knowledge)은 기본 클라이언트 유지
_fast_openai_client = _openai_client.with_options(
    timeout=settings.openai_timeout_seconds, max_retries=1
)
```

`create_embedding`: `_openai_client` → `_fast_openai_client`로 교체 (본문 동일).
`create_embeddings_batch`: **수정 금지** (기본 클라이언트 그대로).

`generate_hypothetical_document`:

```python
async def generate_hypothetical_document(
    query: str, timeout_seconds: float | None = None
) -> str:
    """HyDE: Generate a hypothetical English reference document for the query.

    Used to improve cross-lingual vector search accuracy.
    Falls back to original query on failure or timeout.
    """
    if timeout_seconds is None:
        timeout_seconds = settings.hyde_timeout_seconds
    try:
        response = await asyncio.wait_for(
            _openai_client.chat.completions.create(
                model=settings.hyde_model,
                messages=[
                    {"role": "user", "content": HYDE_PROMPT.format(query=query)},
                ],
                temperature=0.0,
                max_tokens=400,
            ),
            timeout=timeout_seconds,
        )
        result = response.choices[0].message.content
        return result if result else query
    except asyncio.TimeoutError:
        logger.warning(
            f"HyDE generation timed out after {timeout_seconds}s — falling back to original query"
        )
        return query
    except Exception as e:
        logger.warning(f"HyDE generation failed, falling back to original query: {e}")
        return query
```

주의사항:
- HyDE 호출은 `_openai_client`(기본) + `asyncio.wait_for` 조합 — wait_for가 취소를 보장하므로 transport 타임아웃 이중화 불필요. 테스트도 `_openai_client.chat.completions.create`를 patch하므로 이 조합이어야 통과한다.
- `except asyncio.TimeoutError`는 반드시 `except Exception`보다 **먼저** 온다 (`asyncio.TimeoutError`는 설치된 Python 3.10에서도 `Exception`의 서브클래스이므로, 순서가 바뀌면 타임아웃 전용 로그 메시지가 절대 실행되지 않는다).
- `HYDE_PROMPT` 상수는 그대로 유지한다 — `generate_hypothetical_document`가 참조하므로 삭제 금지.

- [ ] **Step 2: 테스트 통과 확인**

Run: `cd /Users/imdonghyeon/perch_care/backend && python -m pytest app/tests/test_vector_search_timeout.py -v`
Expected: 3 passed

- [ ] **Step 3: 전체 회귀 확인**

Run: `cd /Users/imdonghyeon/perch_care/backend && python -m pytest app/tests -q`
Expected: 64 passed (기존 61 + 신규 3)

### Task 4: 커밋

- [ ] **Step 1: 코드 커밋 (docs 제외)**

```bash
cd /Users/imdonghyeon/perch_care
git add backend/app/config.py backend/app/services/embedding_service.py backend/app/tests/test_vector_search_timeout.py
git commit -m "|FIX| 벡터 검색 15s 타임아웃 노이즈 수정 — HyDE 개별 타임아웃+원쿼리 폴백, 단건 임베딩 fail-fast"
```

**push 금지** — main push는 Railway production 자동 배포를 트리거하므로 사용자 확인 필수.

---

## 검증 기준 (완료 정의)

1. `python -m pytest app/tests -q` → 64 passed
2. `generate_hypothetical_document`가 느린 LLM 호출에서 `timeout_seconds` 내에 원본 쿼리를 반환
3. `create_embeddings_batch`는 변경 없음 (diff에 나타나지 않아야 함)
4. `vector_search_service.py` 변경 없음
5. push하지 않음
