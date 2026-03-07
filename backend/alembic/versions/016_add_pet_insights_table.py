"""Add pet_insights table for weekly/monthly health insights

Revision ID: 016
Revises: 015
Create Date: 2026-03-08
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID, JSONB

revision: str = '016'
down_revision: Union[str, None] = '015'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'pet_insights',
        sa.Column('id', UUID(as_uuid=True), primary_key=True),
        sa.Column('pet_id', UUID(as_uuid=True), sa.ForeignKey('pets.id', ondelete='CASCADE'), nullable=False),
        sa.Column('user_id', UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('insight_type', sa.String(20), nullable=False),
        sa.Column('period_start', sa.Date, nullable=False),
        sa.Column('period_end', sa.Date, nullable=False),
        sa.Column('summary', sa.Text, nullable=False),
        sa.Column('key_metrics', JSONB, nullable=False, server_default='{}'),
        sa.Column('recommendations', JSONB, nullable=False, server_default='[]'),
        sa.Column('language', sa.String(5), nullable=False, server_default='zh'),
        sa.Column('generated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
    )
    op.create_index(
        'ix_pet_insights_lookup',
        'pet_insights',
        ['pet_id', 'insight_type', 'period_end'],
    )


def downgrade() -> None:
    op.drop_index('ix_pet_insights_lookup', table_name='pet_insights')
    op.drop_table('pet_insights')
