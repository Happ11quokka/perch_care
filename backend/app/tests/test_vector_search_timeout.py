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
