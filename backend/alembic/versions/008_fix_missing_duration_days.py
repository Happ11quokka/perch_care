"""fix missing duration_days column in premium_codes

만약 create_all이 먼저 실행되어 duration_days 컬럼 없이 테이블이 생성된 경우,
이 마이그레이션이 컬럼을 추가합니다.

Revision ID: 008
Revises: 007
Create Date: 2026-03-02
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


revision: str = '008'
down_revision: Union[str, None] = '007'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = inspect(conn)

    if inspector.has_table('premium_codes'):
        columns = [c['name'] for c in inspector.get_columns('premium_codes')]
        if 'duration_days' not in columns:
            op.add_column(
                'premium_codes',
                sa.Column('duration_days', sa.Integer(), nullable=False, server_default='30'),
            )


def downgrade() -> None:
    conn = op.get_bind()
    inspector = inspect(conn)

    if inspector.has_table('premium_codes'):
        columns = [c['name'] for c in inspector.get_columns('premium_codes')]
        if 'duration_days' in columns:
            op.drop_column('premium_codes', 'duration_days')
