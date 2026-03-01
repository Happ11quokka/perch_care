"""fix premium_codes constraints

- P1-4: used_by FK에 ondelete='SET NULL' 추가
- P2-1: is_used를 NOT NULL로 변경
- P2-2: 중복 인덱스 ix_premium_codes_code 제거

Revision ID: 006
Revises: 005
Create Date: 2026-03-01
"""
from typing import Sequence, Union

from alembic import op

revision: str = '006'
down_revision: Union[str, None] = '005'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # P1-4: used_by FK에 ondelete='SET NULL' 추가
    op.drop_constraint('premium_codes_used_by_fkey', 'premium_codes', type_='foreignkey')
    op.create_foreign_key(
        'premium_codes_used_by_fkey',
        'premium_codes',
        'users',
        ['used_by'],
        ['id'],
        ondelete='SET NULL',
    )

    # P2-1: is_used NOT NULL (기존 데이터는 server_default='false'로 이미 값 존재)
    op.alter_column('premium_codes', 'is_used', nullable=False)

    # P2-2: unique=True가 이미 인덱스 생성하므로 중복 인덱스 제거
    op.drop_index('ix_premium_codes_code', table_name='premium_codes')


def downgrade() -> None:
    op.create_index('ix_premium_codes_code', 'premium_codes', ['code'])
    op.alter_column('premium_codes', 'is_used', nullable=True)
    op.drop_constraint('premium_codes_used_by_fkey', 'premium_codes', type_='foreignkey')
    op.create_foreign_key(
        'premium_codes_used_by_fkey',
        'premium_codes',
        'users',
        ['used_by'],
        ['id'],
    )
