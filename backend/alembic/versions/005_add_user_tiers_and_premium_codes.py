"""add user_tiers and premium_codes tables

Revision ID: 005
Revises: 004
Create Date: 2026-03-01
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

# revision identifiers, used by Alembic.
revision: str = '005'
down_revision: Union[str, None] = '004'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'user_tiers',
        sa.Column('id', UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), unique=True, nullable=False),
        sa.Column('tier', sa.String(20), nullable=False, server_default='free'),
        sa.Column('premium_started_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('premium_expires_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('activated_code', sa.String(20), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_check_constraint('ck_user_tiers_tier', 'user_tiers', "tier IN ('free', 'premium')")

    op.create_table(
        'premium_codes',
        sa.Column('id', UUID(as_uuid=True), primary_key=True),
        sa.Column('code', sa.String(20), unique=True, nullable=False),
        sa.Column('duration_days', sa.Integer(), nullable=False, server_default='30'),
        sa.Column('is_used', sa.Boolean(), server_default='false'),
        sa.Column('used_by', UUID(as_uuid=True), sa.ForeignKey('users.id'), nullable=True),
        sa.Column('used_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    op.create_index('ix_premium_codes_code', 'premium_codes', ['code'])
    op.create_index('ix_premium_codes_used_by', 'premium_codes', ['used_by'])


def downgrade() -> None:
    op.drop_index('ix_premium_codes_used_by', table_name='premium_codes')
    op.drop_index('ix_premium_codes_code', table_name='premium_codes')
    op.drop_table('premium_codes')
    op.drop_constraint('ck_user_tiers_tier', 'user_tiers', type_='check')
    op.drop_table('user_tiers')
