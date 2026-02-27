"""add language column to device_tokens

Revision ID: 004
Revises: 003
Create Date: 2026-02-27
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = '004'
down_revision: Union[str, None] = '003'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('device_tokens', sa.Column('language', sa.String(5), nullable=False, server_default='zh'))


def downgrade() -> None:
    op.drop_column('device_tokens', 'language')
