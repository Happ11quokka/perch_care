import uuid
from datetime import datetime, timezone

from sqlalchemy import DateTime, Index, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class DemoUsageLog(Base):
    """웹 데모 사용 로그. IP는 해시로만 저장한다 (원본 미보존)."""

    __tablename__ = "demo_usage_logs"
    __table_args__ = (
        # 쿼터 집계 쿼리(ip_hash, kind, created_at >= day_start)용 복합 인덱스
        Index("ix_demo_usage_logs_ip_kind_created", "ip_hash", "kind", "created_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    ip_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    kind: Mapped[str] = mapped_column(String(10), nullable=False)  # chat | vision | bhi
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False, index=True
    )
