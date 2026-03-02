"""add ai_vision_logs table for vision health check usage tracking

Revision ID: 009
Revises: 008
Create Date: 2026-03-02
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID


revision: str = '009'
down_revision: Union[str, None] = '008'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'ai_vision_logs',
        sa.Column('id', UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('pet_id', UUID(as_uuid=True), sa.ForeignKey('pets.id', ondelete='SET NULL'), nullable=True),
        sa.Column('mode', sa.String(20), nullable=False),
        sa.Column('part', sa.String(20), nullable=True),
        sa.Column('image_size_bytes', sa.Integer(), nullable=False),
        sa.Column('response_time_ms', sa.Integer(), nullable=False),
        sa.Column('model', sa.String(50), nullable=False),
        sa.Column('confidence_score', sa.Float(), nullable=True),
        sa.Column('overall_status', sa.String(20), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index('ix_ai_vision_logs_user_id', 'ai_vision_logs', ['user_id'])
    op.create_index('ix_ai_vision_logs_created_at', 'ai_vision_logs', ['created_at'])


def downgrade() -> None:
    op.drop_index('ix_ai_vision_logs_created_at', table_name='ai_vision_logs')
    op.drop_index('ix_ai_vision_logs_user_id', table_name='ai_vision_logs')
    op.drop_table('ai_vision_logs')
