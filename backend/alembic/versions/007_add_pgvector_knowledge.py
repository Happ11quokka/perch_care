"""add pgvector extension and knowledge_chunks table

Revision ID: 007
Revises: 006
Create Date: 2026-03-01
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID
from pgvector.sqlalchemy import Vector

revision: str = '007'
down_revision: Union[str, None] = '006'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Enable pgvector extension (works on Railway managed PostgreSQL and local pgvector/pgvector:pg16)
    op.execute("CREATE EXTENSION IF NOT EXISTS vector")

    op.create_table(
        'knowledge_chunks',
        sa.Column('id', UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('content', sa.Text(), nullable=False),
        sa.Column('embedding', Vector(3072), nullable=False),
        sa.Column('source', sa.String(500), nullable=False),
        sa.Column('category', sa.String(100), nullable=False),
        sa.Column('language', sa.String(10), nullable=False),
        sa.Column('section_title', sa.String(500), nullable=False, server_default=''),
        sa.Column('chunk_hash', sa.String(64), nullable=False, unique=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    # Metadata indexes for filtering
    op.create_index('ix_knowledge_chunks_source', 'knowledge_chunks', ['source'])
    op.create_index('ix_knowledge_chunks_category', 'knowledge_chunks', ['category'])
    op.create_index('ix_knowledge_chunks_language', 'knowledge_chunks', ['language'])

    # HNSW vector index for cosine similarity search
    op.execute("""
        CREATE INDEX ix_knowledge_chunks_embedding_hnsw
        ON knowledge_chunks
        USING hnsw (embedding vector_cosine_ops)
        WITH (m = 16, ef_construction = 128)
    """)


def downgrade() -> None:
    op.drop_index('ix_knowledge_chunks_embedding_hnsw', table_name='knowledge_chunks')
    op.drop_index('ix_knowledge_chunks_language', table_name='knowledge_chunks')
    op.drop_index('ix_knowledge_chunks_category', table_name='knowledge_chunks')
    op.drop_index('ix_knowledge_chunks_source', table_name='knowledge_chunks')
    op.drop_table('knowledge_chunks')
    # Note: We do NOT drop the vector extension in downgrade, as other tables might use it
