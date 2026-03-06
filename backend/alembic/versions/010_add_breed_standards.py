"""add breed_standards table and breed_id to pets for species-specific weight assessment

Revision ID: 010
Revises: 009
Create Date: 2026-03-06
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID


revision: str = '010'
down_revision: Union[str, None] = '009'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Create breed_standards table
    op.create_table(
        'breed_standards',
        sa.Column('id', UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('species_category', sa.String(50), nullable=False),
        sa.Column('breed_name_en', sa.String(100), nullable=False),
        sa.Column('breed_name_ko', sa.String(100), nullable=False),
        sa.Column('breed_name_zh', sa.String(100), nullable=False),
        sa.Column('breed_variant', sa.String(50), nullable=True),
        sa.Column('weight_min_g', sa.Float(), nullable=False),
        sa.Column('weight_ideal_min_g', sa.Float(), nullable=False),
        sa.Column('weight_ideal_max_g', sa.Float(), nullable=False),
        sa.Column('weight_max_g', sa.Float(), nullable=False),
        sa.Column('environment', sa.String(20), nullable=False, server_default='pet'),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index('ix_breed_standards_species', 'breed_standards', ['species_category'])
    op.create_index('ix_breed_standards_active', 'breed_standards', ['is_active'])

    # 2. Add breed_id FK to pets table
    op.add_column('pets', sa.Column('breed_id', UUID(as_uuid=True), nullable=True))
    op.create_foreign_key(
        'fk_pets_breed_id',
        'pets', 'breed_standards',
        ['breed_id'], ['id'],
        ondelete='SET NULL',
    )
    op.create_index('ix_pets_breed_id', 'pets', ['breed_id'])

    # 3. Seed common pet parrot breeds (pet environment weights in grams)
    op.execute("""
        INSERT INTO breed_standards
            (species_category, breed_name_en, breed_name_ko, breed_name_zh, breed_variant,
             weight_min_g, weight_ideal_min_g, weight_ideal_max_g, weight_max_g, environment)
        VALUES
            ('parrot', 'Budgerigar', '사랑앵무', '虎皮鹦鹉', 'standard',
             30.0, 35.0, 45.0, 50.0, 'pet'),
            ('parrot', 'Budgerigar', '사랑앵무', '虎皮鹦鹉', 'exhibition',
             40.0, 45.0, 65.0, 70.0, 'pet'),
            ('parrot', 'Cockatiel', '왕관앵무', '玄凤鹦鹉', NULL,
             70.0, 80.0, 110.0, 125.0, 'pet'),
            ('parrot', 'Lovebird', '모란앵무', '牡丹鹦鹉', NULL,
             35.0, 42.0, 58.0, 65.0, 'pet'),
            ('parrot', 'Green-cheeked Conure', '녹색볼코뉴어', '绿颊锥尾鹦鹉', NULL,
             55.0, 60.0, 80.0, 90.0, 'pet'),
            ('parrot', 'Sun Conure', '태양코뉴어', '太阳锥尾鹦鹉', NULL,
             95.0, 100.0, 130.0, 140.0, 'pet'),
            ('parrot', 'Monk Parakeet', '퀘이커앵무', '和尚鹦鹉', NULL,
             85.0, 90.0, 120.0, 130.0, 'pet'),
            ('parrot', 'Indian Ringneck', '인디안린넥', '环颈鹦鹉', NULL,
             105.0, 115.0, 140.0, 155.0, 'pet'),
            ('parrot', 'Senegal Parrot', '세네갈앵무', '塞内加尔鹦鹉', NULL,
             110.0, 120.0, 170.0, 180.0, 'pet'),
            ('parrot', 'Caique', '카이크', '凯克鹦鹉', NULL,
             140.0, 150.0, 170.0, 185.0, 'pet'),
            ('parrot', 'African Grey', '아프리칸그레이', '非洲灰鹦鹉', NULL,
             380.0, 400.0, 550.0, 600.0, 'pet'),
            ('parrot', 'Eclectus', '에클렉투스', '折衷鹦鹉', NULL,
             330.0, 350.0, 450.0, 480.0, 'pet'),
            ('parrot', 'Alexandrine Parakeet', '알렉산드린', '亚历山大鹦鹉', NULL,
             190.0, 200.0, 260.0, 280.0, 'pet'),
            ('parrot', 'Bourke''s Parakeet', '버크앵무', '伯克鹦鹉', NULL,
             40.0, 45.0, 55.0, 60.0, 'pet'),
            ('parrot', 'Lineolated Parakeet', '줄무늬앵무', '横斑鹦鹉', NULL,
             38.0, 42.0, 55.0, 60.0, 'pet')
    """)


def downgrade() -> None:
    op.drop_index('ix_pets_breed_id', table_name='pets')
    op.drop_constraint('fk_pets_breed_id', 'pets', type_='foreignkey')
    op.drop_column('pets', 'breed_id')
    op.drop_index('ix_breed_standards_active', table_name='breed_standards')
    op.drop_index('ix_breed_standards_species', table_name='breed_standards')
    op.drop_table('breed_standards')
