"""Add store subscription fields to user_tiers

Revision ID: 013
Revises: 012
Create Date: 2026-03-07
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = '013'
down_revision: Union[str, None] = '012'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("user_tiers", sa.Column("source", sa.String(20), nullable=False, server_default="free"))
    op.add_column("user_tiers", sa.Column("store_product_id", sa.String(100), nullable=True))
    op.add_column("user_tiers", sa.Column("store_original_transaction_id", sa.String(200), nullable=True))
    op.add_column("user_tiers", sa.Column("auto_renew_status", sa.Boolean(), nullable=True))
    op.add_column("user_tiers", sa.Column("grace_period_expires_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("user_tiers", sa.Column("last_verified_at", sa.DateTime(timezone=True), nullable=True))

    # Backfill: activated_code가 있으면 promo_code로 설정
    op.execute("UPDATE user_tiers SET source = 'promo_code' WHERE activated_code IS NOT NULL AND source = 'free'")


def downgrade() -> None:
    op.drop_column("user_tiers", "last_verified_at")
    op.drop_column("user_tiers", "grace_period_expires_at")
    op.drop_column("user_tiers", "auto_renew_status")
    op.drop_column("user_tiers", "store_original_transaction_id")
    op.drop_column("user_tiers", "store_product_id")
    op.drop_column("user_tiers", "source")
