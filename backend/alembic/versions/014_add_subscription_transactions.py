"""Add subscription_transactions table

Revision ID: 014
Revises: 013
Create Date: 2026-03-07
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

revision: str = '014'
down_revision: Union[str, None] = '013'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "subscription_transactions",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("store", sa.String(10), nullable=False),
        sa.Column("product_id", sa.String(100), nullable=False),
        sa.Column("transaction_id", sa.String(200), nullable=False),
        sa.Column("original_transaction_id", sa.String(200), nullable=False),
        sa.Column("event_type", sa.String(20), nullable=False),
        sa.Column("purchased_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("payload_json", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_subscription_transactions_user_id", "subscription_transactions", ["user_id"])
    op.create_index("ix_subscription_transactions_transaction_id", "subscription_transactions", ["transaction_id"])
    op.create_index("ix_subscription_transactions_original_transaction_id", "subscription_transactions", ["original_transaction_id"])
    op.create_index("ix_subscription_transactions_created_at", "subscription_transactions", ["created_at"])


def downgrade() -> None:
    op.drop_table("subscription_transactions")
