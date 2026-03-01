import logging

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from app.config import get_settings

logger = logging.getLogger(__name__)

settings = get_settings()


def _normalize_url(url: str) -> str:
    if url.startswith("postgresql://"):
        return url.replace("postgresql://", "postgresql+asyncpg://", 1)
    return url


# ── Main database (users, pets, weights, etc.) ──
engine = create_async_engine(_normalize_url(settings.database_url), echo=False)
async_session_factory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


# ── Vector database (knowledge_chunks — separate pgvector instance) ──
vector_engine = None
vector_session_factory = None

if settings.vector_database_url:
    vector_engine = create_async_engine(_normalize_url(settings.vector_database_url), echo=False)
    vector_session_factory = async_sessionmaker(vector_engine, class_=AsyncSession, expire_on_commit=False)
    logger.info("Vector database configured")
else:
    logger.warning("VECTOR_DATABASE_URL not set — vector search disabled")


async def get_db():
    async with async_session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
