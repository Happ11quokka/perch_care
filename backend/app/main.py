from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from pathlib import Path
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from app.limiter import limiter
import os

from sqlalchemy import text
from app.config import get_settings
from app.routers import auth, users, pets, weights, daily_records, food_records, water_records, health_checks, schedules, notifications, bhi, ai, premium, breed_standards, chat, reports

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    import logging
    _logger = logging.getLogger(__name__)

    # JWT Secret 기본값 사용 차단
    if settings.jwt_secret == "change-this-secret-in-production":
        raise RuntimeError(
            "CRITICAL: JWT_SECRET is set to the default value. "
            "Set a secure JWT_SECRET in .env before starting the server."
        )

    # Ensure upload directory exists
    os.makedirs(settings.upload_dir, exist_ok=True)

    # ── Main DB: create tables (KnowledgeChunk 제외) ──
    from app.database import engine, vector_engine, vector_session_factory
    from app.models.base import Base as MainBase
    async with engine.begin() as conn:
        await conn.run_sync(MainBase.metadata.create_all)

    # ── Vector DB: pgvector 확장 + knowledge_chunks 테이블 ──
    if vector_engine is not None:
        try:
            from app.models.knowledge_chunk import KnowledgeChunk
            async with vector_engine.begin() as conn:
                await conn.execute(text("CREATE EXTENSION IF NOT EXISTS vector"))
                await conn.run_sync(KnowledgeChunk.metadata.create_all)
            _logger.info("Vector DB initialized (pgvector extension + knowledge_chunks)")

            # 벡터 검색 가용성 확인
            from app.services.vector_search_service import check_vector_search_available
            async with vector_session_factory() as vdb:
                await check_vector_search_available(vdb)
        except Exception as e:
            _logger.warning(f"Vector DB init skipped: {e}")
    else:
        _logger.info("Vector DB not configured — vector search disabled")

    # Start scheduler
    from app.scheduler import start_scheduler
    start_scheduler()

    yield

    # Cleanup
    from app.scheduler import stop_scheduler
    stop_scheduler()


app = FastAPI(
    title="Perch Care API",
    description="Pet health management backend API",
    version="1.0.0",
    lifespan=lifespan,
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Static files for uploads
app.mount("/uploads", StaticFiles(directory=settings.upload_dir), name="uploads")

# Routers
app.include_router(auth.router, prefix=settings.api_v1_prefix)
app.include_router(users.router, prefix=settings.api_v1_prefix)
app.include_router(pets.router, prefix=settings.api_v1_prefix)
app.include_router(weights.router, prefix=settings.api_v1_prefix)
app.include_router(daily_records.router, prefix=settings.api_v1_prefix)
app.include_router(food_records.router, prefix=settings.api_v1_prefix)
app.include_router(water_records.router, prefix=settings.api_v1_prefix)
app.include_router(health_checks.router, prefix=settings.api_v1_prefix)
app.include_router(bhi.router, prefix=settings.api_v1_prefix)
app.include_router(schedules.router, prefix=settings.api_v1_prefix)
app.include_router(notifications.router, prefix=settings.api_v1_prefix)
app.include_router(ai.router, prefix=settings.api_v1_prefix)
app.include_router(premium.router, prefix=settings.api_v1_prefix)
app.include_router(breed_standards.router, prefix=settings.api_v1_prefix)
app.include_router(chat.router, prefix=settings.api_v1_prefix)
app.include_router(reports.router, prefix=settings.api_v1_prefix)

# Rate limiting
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)


@app.get("/health")
async def health_check():
    return {"status": "ok"}


@app.get("/admin", response_class=HTMLResponse)
async def admin_page():
    """관리자 대시보드 페이지."""
    html_path = Path(__file__).parent / "templates" / "admin.html"
    return HTMLResponse(content=html_path.read_text(encoding="utf-8"))
