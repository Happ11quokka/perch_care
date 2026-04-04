"""
Vector search service — HyDE + pgvector cosine similarity search.

Uses a SEPARATE vector database (vector_session_factory) from the main app DB.
Graceful degradation: returns empty list on any failure.
The AI service continues to work normally without knowledge context.
"""
import asyncio
import logging
import time

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.services.embedding_service import create_embedding, generate_hypothetical_document

logger = logging.getLogger(__name__)

settings = get_settings()

# Module-level availability state with TTL-based re-check
_vector_search_available: bool = False
_last_check_time: float = 0.0
_RECHECK_INTERVAL_SECONDS: float = 60.0  # False 상태에서 60초마다 재확인


def _get_vector_session_factory():
    """Lazy import to avoid circular dependency at module load time."""
    from app.database import vector_session_factory
    return vector_session_factory


async def check_vector_search_available(db: AsyncSession) -> bool:
    """Check if knowledge_chunks table exists and has data."""
    global _vector_search_available, _last_check_time
    try:
        result = await db.execute(text("SELECT 1 FROM knowledge_chunks LIMIT 1"))
        row = result.first()
        _vector_search_available = row is not None
        _last_check_time = time.monotonic()
        if _vector_search_available:
            logger.info("Vector search available: knowledge chunks detected")
        else:
            logger.warning("Vector search: knowledge_chunks table is empty")
    except Exception as e:
        _vector_search_available = False
        _last_check_time = time.monotonic()
        logger.warning(f"Vector search unavailable: {e}")
    return _vector_search_available


async def _ensure_available() -> bool:
    """Return cached availability, re-checking with TTL if currently False."""
    global _vector_search_available, _last_check_time

    factory = _get_vector_session_factory()
    if factory is None:
        return False

    if _vector_search_available:
        return True

    # False 상태일 때만 TTL 기반 재확인
    now = time.monotonic()
    if now - _last_check_time >= _RECHECK_INTERVAL_SECONDS:
        async with factory() as vdb:
            await check_vector_search_available(vdb)
    return _vector_search_available


async def search_knowledge(
    query: str,
    top_k: int | None = None,
    category: str | None = None,
    language: str | None = None,
    use_hyde: bool = True,
    timeout_seconds: float = 15.0,
) -> list[dict]:
    """Search knowledge base using HyDE + pgvector cosine similarity.

    Uses its own vector DB session internally — no external db parameter needed.
    Returns empty list on any failure (graceful degradation).
    """
    if not await _ensure_available():
        return []

    if top_k is None:
        top_k = settings.vector_search_top_k

    try:
        return await asyncio.wait_for(
            _search_knowledge_impl(query, top_k, category, language, use_hyde),
            timeout=timeout_seconds,
        )
    except asyncio.TimeoutError:
        logger.warning(f"Vector search timed out after {timeout_seconds}s (query_len={len(query)})")
        return []
    except Exception as e:
        logger.warning(f"Vector search failed: {e}")
        return []


async def _search_knowledge_impl(
    query: str,
    top_k: int,
    category: str | None,
    language: str | None,
    use_hyde: bool,
) -> list[dict]:
    """Internal implementation of knowledge search."""
    # Step 1: HyDE — generate hypothetical document, then embed it
    if use_hyde:
        hypothetical_doc = await generate_hypothetical_document(query)
        query_embedding = await create_embedding(hypothetical_doc)
    else:
        query_embedding = await create_embedding(query)

    # Step 2: pgvector cosine distance search
    max_distance = 1.0 - settings.vector_search_min_similarity

    where_clauses = []
    params: dict = {
        "embedding": str(query_embedding),
        "top_k": top_k,
        "max_distance": max_distance,
    }

    if category:
        where_clauses.append("category = :category")
        params["category"] = category
    if language:
        where_clauses.append("language = :language")
        params["language"] = language

    where_sql = ""
    if where_clauses:
        where_sql = "AND " + " AND ".join(where_clauses)

    sql = text(f"""
        SELECT content, source, category, language, section_title,
               1 - (embedding <=> CAST(:embedding AS vector)) AS similarity
        FROM knowledge_chunks
        WHERE (embedding <=> CAST(:embedding AS vector)) < :max_distance
        {where_sql}
        ORDER BY embedding <=> CAST(:embedding AS vector)
        LIMIT :top_k
    """)

    factory = _get_vector_session_factory()
    async with factory() as vdb:
        result = await vdb.execute(sql, params)
        rows = result.all()

    results = [
        {
            "content": row.content,
            "source": row.source,
            "category": row.category,
            "language": row.language,
            "section_title": row.section_title,
            "similarity": round(float(row.similarity), 4),
        }
        for row in rows
    ]

    # CB-9: Lightweight re-ranking — boost results with query keyword overlap
    return _rerank_results(query, results)


def _rerank_results(query: str, results: list[dict]) -> list[dict]:
    """CB-9: Re-rank vector search results by combining embedding similarity with keyword overlap.

    Adds a keyword overlap bonus to the similarity score to surface results that
    contain exact query terms. No external dependencies required.
    """
    if not results:
        return results

    query_terms = set(query.lower().split())
    for r in results:
        content_lower = r["content"].lower()
        overlap = sum(1 for term in query_terms if term in content_lower)
        overlap_ratio = overlap / max(len(query_terms), 1)
        # Blend: 80% embedding similarity + 20% keyword overlap
        r["_combined_score"] = r["similarity"] * 0.8 + overlap_ratio * 0.2

    results.sort(key=lambda x: x["_combined_score"], reverse=True)

    # Clean up internal scoring field
    for r in results:
        r.pop("_combined_score", None)

    return results


def format_knowledge_context(results: list[dict]) -> str | None:
    """Format search results into a knowledge context string for the system prompt.

    Returns None if no results.
    """
    if not results:
        return None

    parts = ["[Avian Care Knowledge Base]"]
    for r in results:
        source_label = r["source"].replace("/", " > ").replace("-", " ").replace(".md", "")
        title = r["section_title"] or "General"
        parts.append(
            f"\n--- {source_label} ({title}) [relevance: {r['similarity']:.2f}] ---"
        )
        parts.append(r["content"])

    return "\n".join(parts)
