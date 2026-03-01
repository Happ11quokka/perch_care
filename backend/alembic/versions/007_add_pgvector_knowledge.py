"""add pgvector extension and knowledge_chunks table

Revision ID: 007
Revises: 006
Create Date: 2026-03-01

NOTE: knowledge_chunks lives in a SEPARATE pgvector database.
This migration is a NO-OP on the main DB.
The vector DB schema is managed by main.py lifespan (VectorBase.metadata.create_all).
"""
from typing import Sequence, Union

from alembic import op

revision: str = '007'
down_revision: Union[str, None] = '006'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # knowledge_chunks table now lives in a separate pgvector database.
    # Schema creation is handled by main.py lifespan via VectorBase.metadata.create_all.
    # This migration is intentionally a no-op to keep the revision chain intact.
    pass


def downgrade() -> None:
    # No-op: vector DB schema is managed separately.
    pass
