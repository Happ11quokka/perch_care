import uuid
from datetime import date, datetime, timezone
from sqlalchemy import String, Date, DateTime, Boolean, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.models.base import Base


class Pet(Base):
    __tablename__ = "pets"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    species: Mapped[str] = mapped_column(String(50), nullable=False)
    breed: Mapped[str | None] = mapped_column(String(100), nullable=True)
    birth_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    gender: Mapped[str | None] = mapped_column(String(20), nullable=True)
    profile_image_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    growth_stage: Mapped[str | None] = mapped_column(String(30), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))

    user = relationship("User", back_populates="pets")
    weight_records = relationship("WeightRecord", back_populates="pet", cascade="all, delete-orphan")
    daily_records = relationship("DailyRecord", back_populates="pet", cascade="all, delete-orphan")
    health_checks = relationship("AiHealthCheck", back_populates="pet", cascade="all, delete-orphan")
    food_records = relationship("FoodRecord", back_populates="pet", cascade="all, delete-orphan")
    water_records = relationship("WaterRecord", back_populates="pet", cascade="all, delete-orphan")
    schedules = relationship("Schedule", back_populates="pet", cascade="all, delete-orphan")
