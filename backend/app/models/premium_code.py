import uuid
from datetime import datetime, timezone

from sqlalchemy import String, Boolean, Integer, DateTime, ForeignKey, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class PremiumCode(Base):
    __tablename__ = "premium_codes"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    code: Mapped[str] = mapped_column(String(20), unique=True, nullable=False)  # "PERCH-XXXX-XXXX"
    duration_days: Mapped[int] = mapped_column(Integer, nullable=False, default=30)
    is_used: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("false"), default=False)
    used_by: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
