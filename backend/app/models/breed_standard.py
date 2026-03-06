import uuid
from datetime import datetime, timezone
from sqlalchemy import String, Float, Boolean, DateTime
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from app.models.base import Base


class BreedStandard(Base):
    __tablename__ = "breed_standards"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    species_category: Mapped[str] = mapped_column(String(50), nullable=False)
    breed_name_en: Mapped[str] = mapped_column(String(100), nullable=False)
    breed_name_ko: Mapped[str] = mapped_column(String(100), nullable=False)
    breed_name_zh: Mapped[str] = mapped_column(String(100), nullable=False)
    breed_variant: Mapped[str | None] = mapped_column(String(50), nullable=True)
    weight_min_g: Mapped[float] = mapped_column(Float, nullable=False)
    weight_ideal_min_g: Mapped[float] = mapped_column(Float, nullable=False)
    weight_ideal_max_g: Mapped[float] = mapped_column(Float, nullable=False)
    weight_max_g: Mapped[float] = mapped_column(Float, nullable=False)
    environment: Mapped[str] = mapped_column(String(20), nullable=False, default='pet')
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
