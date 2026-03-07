import uuid
from datetime import datetime, timezone

from sqlalchemy import Boolean, String, DateTime, ForeignKey, CheckConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class UserTier(Base):
    __tablename__ = "user_tiers"
    __table_args__ = (
        CheckConstraint("tier IN ('free', 'premium')", name="ck_user_tiers_tier"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False)
    tier: Mapped[str] = mapped_column(String(20), nullable=False, default="free")  # "free" | "premium"
    premium_started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    premium_expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    activated_code: Mapped[str | None] = mapped_column(String(20), nullable=True)

    # Store subscription fields (Migration 013)
    source: Mapped[str] = mapped_column(String(20), nullable=False, server_default="free")  # free/promo_code/app_store/play_store/admin
    store_product_id: Mapped[str | None] = mapped_column(String(100), nullable=True)
    store_original_transaction_id: Mapped[str | None] = mapped_column(String(200), nullable=True)
    auto_renew_status: Mapped[bool | None] = mapped_column(Boolean, nullable=True)
    grace_period_expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    last_verified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    image_cleanup_scheduled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    image_cleanup_completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))

    user = relationship("User", back_populates="tier_info")
