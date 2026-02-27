"""add ai_encyclopedia_logs and device_tokens tables

Revision ID: 003
Revises: 002
Create Date: 2026-02-27
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '003'
down_revision: Union[str, None] = '002'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ai_encyclopedia_logs table
    op.create_table(
        'ai_encyclopedia_logs',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('pet_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('pets.id', ondelete='SET NULL'), nullable=True),
        sa.Column('query_length', sa.Integer, nullable=False),
        sa.Column('response_length', sa.Integer, nullable=False),
        sa.Column('response_time_ms', sa.Integer, nullable=False),
        sa.Column('model', sa.String(50), nullable=False),
        sa.Column('tokens_used', sa.Integer, nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    )
    op.create_index('ix_ai_encyclopedia_logs_user_id', 'ai_encyclopedia_logs', ['user_id'])
    op.create_index('ix_ai_encyclopedia_logs_created_at', 'ai_encyclopedia_logs', ['created_at'])

    # device_tokens table
    op.create_table(
        'device_tokens',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('token', sa.Text, nullable=False),
        sa.Column('platform', sa.String(10), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    )
    op.create_index('ix_device_tokens_user_id', 'device_tokens', ['user_id'])
    op.create_index('uq_device_token', 'device_tokens', ['user_id', 'token'], unique=True)


def downgrade() -> None:
    op.drop_table('device_tokens')
    op.drop_table('ai_encyclopedia_logs')
