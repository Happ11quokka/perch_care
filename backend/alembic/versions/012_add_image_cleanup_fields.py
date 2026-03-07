"""Add image cleanup fields to user_tiers

Revision ID: 012
Revises: 011
Create Date: 2026-03-07
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = '012'
down_revision: Union[str, None] = '011'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("user_tiers", sa.Column("image_cleanup_scheduled_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("user_tiers", sa.Column("image_cleanup_completed_at", sa.DateTime(timezone=True), nullable=True))


def downgrade() -> None:
    op.drop_column("user_tiers", "image_cleanup_completed_at")
    op.drop_column("user_tiers", "image_cleanup_scheduled_at")
