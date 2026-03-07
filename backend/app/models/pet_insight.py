import uuid
from datetime import date, datetime, timezone

from sqlalchemy import Date, DateTime, Index, String, Text, ForeignKey
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class PetInsight(Base):
    __tablename__ = "pet_insights"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4,
    )
    pet_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("pets.id", ondelete="CASCADE"),
        nullable=False,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    insight_type: Mapped[str] = mapped_column(String(20), nullable=False)  # weekly / monthly
    period_start: Mapped[date] = mapped_column(Date, nullable=False)
    period_end: Mapped[date] = mapped_column(Date, nullable=False)
    summary: Mapped[str] = mapped_column(Text, nullable=False)
    key_metrics: Mapped[dict] = mapped_column(JSONB, nullable=False, default=dict)
    recommendations: Mapped[list] = mapped_column(JSONB, nullable=False, default=list)
    language: Mapped[str] = mapped_column(String(5), nullable=False, default="zh")
    generated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc),
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc),
    )

    pet = relationship("Pet")
    user = relationship("User")

    __table_args__ = (
        Index("ix_pet_insights_lookup", "pet_id", "insight_type", "period_end"),
    )
