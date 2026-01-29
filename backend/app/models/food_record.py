import uuid
from datetime import date, datetime, timezone
from sqlalchemy import Date, DateTime, Float, Integer, Text, ForeignKey, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.models.base import Base


class FoodRecord(Base):
    __tablename__ = "food_records"
    __table_args__ = (UniqueConstraint("pet_id", "recorded_date", name="uq_food_pet_date"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    pet_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("pets.id", ondelete="CASCADE"), nullable=False, index=True)
    recorded_date: Mapped[date] = mapped_column(Date, nullable=False)
    total_grams: Mapped[float] = mapped_column(Float, nullable=False)
    target_grams: Mapped[float] = mapped_column(Float, nullable=False)
    count: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    entries_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))

    pet = relationship("Pet", back_populates="food_records")
