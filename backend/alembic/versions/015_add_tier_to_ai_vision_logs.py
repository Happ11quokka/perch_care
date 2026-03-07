"""Add tier column to ai_vision_logs

Revision ID: 015
Revises: 014
Create Date: 2026-03-07
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = '015'
down_revision: Union[str, None] = '014'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        'ai_vision_logs',
        sa.Column('tier', sa.String(10), nullable=False, server_default='free'),
    )


def downgrade() -> None:
    op.drop_column('ai_vision_logs', 'tier')
