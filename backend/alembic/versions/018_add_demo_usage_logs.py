"""Add demo_usage_logs table for web demo IP quota tracking

Revision ID: 018
Revises: 017
Create Date: 2026-06-11
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

revision: str = '018'
down_revision: Union[str, None] = '017'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'demo_usage_logs',
        sa.Column('id', UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('ip_hash', sa.String(64), nullable=False),
        sa.Column('kind', sa.String(10), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
    )
    op.create_index(
        'ix_demo_usage_logs_ip_kind_created', 'demo_usage_logs', ['ip_hash', 'kind', 'created_at'],
    )
    op.create_index('ix_demo_usage_logs_created_at', 'demo_usage_logs', ['created_at'])


def downgrade() -> None:
    op.drop_index('ix_demo_usage_logs_created_at', table_name='demo_usage_logs')
    op.drop_index('ix_demo_usage_logs_ip_kind_created', table_name='demo_usage_logs')
    op.drop_table('demo_usage_logs')
