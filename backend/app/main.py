from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
import os

from app.config import get_settings
from app.routers import auth, users, pets, weights, daily_records, food_records, water_records, health_checks, schedules, notifications, bhi, ai, premium

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Ensure upload directory exists
    os.makedirs(settings.upload_dir, exist_ok=True)
    # Create all tables on startup (if not exist)
    from app.database import engine
    from app.models import Base
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield


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

# Rate limiting error handler (slowapi)
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)


@app.get("/health")
async def health_check():
    return {"status": "ok"}
