"""add ai_chat_sessions and ai_chat_messages tables for chat history

Revision ID: 011
Revises: 010
Create Date: 2026-03-07
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID, JSONB


revision: str = '011'
down_revision: Union[str, None] = '010'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Create ai_chat_sessions table
    op.create_table(
        'ai_chat_sessions',
        sa.Column('id', UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('user_id', UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('pet_id', UUID(as_uuid=True), sa.ForeignKey('pets.id', ondelete='SET NULL'), nullable=True),
        sa.Column('title', sa.String(200), nullable=False),
        sa.Column('started_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('last_message_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('message_count', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index('ix_ai_chat_sessions_user_id', 'ai_chat_sessions', ['user_id'])
    op.create_index('ix_ai_chat_sessions_pet_id', 'ai_chat_sessions', ['pet_id'])
    op.create_index('ix_ai_chat_sessions_last_message_at', 'ai_chat_sessions', [sa.text('last_message_at DESC')])

    # 2. Create ai_chat_messages table
    op.create_table(
        'ai_chat_messages',
        sa.Column('id', UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('session_id', UUID(as_uuid=True), sa.ForeignKey('ai_chat_sessions.id', ondelete='CASCADE'), nullable=False),
        sa.Column('role', sa.String(20), nullable=False),
        sa.Column('content', sa.Text(), nullable=False),
        sa.Column('metadata', JSONB, nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.CheckConstraint("role IN ('user', 'assistant')", name='ck_chat_message_role'),
    )
    op.create_index('ix_ai_chat_messages_session_id', 'ai_chat_messages', ['session_id'])
    op.create_index('ix_ai_chat_messages_created_at', 'ai_chat_messages', ['created_at'])


def downgrade() -> None:
    op.drop_index('ix_ai_chat_messages_created_at', table_name='ai_chat_messages')
    op.drop_index('ix_ai_chat_messages_session_id', table_name='ai_chat_messages')
    op.drop_table('ai_chat_messages')
    op.drop_index('ix_ai_chat_sessions_last_message_at', table_name='ai_chat_sessions')
    op.drop_index('ix_ai_chat_sessions_pet_id', table_name='ai_chat_sessions')
    op.drop_index('ix_ai_chat_sessions_user_id', table_name='ai_chat_sessions')
    op.drop_table('ai_chat_sessions')
