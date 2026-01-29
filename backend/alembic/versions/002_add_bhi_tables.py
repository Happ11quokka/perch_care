"""add growth_stage to pets, create food_records and water_records tables

Revision ID: 002
Revises: 001
Create Date: 2026-01-29
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '002'
down_revision: Union[str, None] = '001'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add growth_stage column to pets table
    op.add_column('pets', sa.Column('growth_stage', sa.String(30), nullable=True))

    # Create food_records table
    op.create_table(
        'food_records',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('pet_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('pets.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('recorded_date', sa.Date, nullable=False),
        sa.Column('total_grams', sa.Float, nullable=False),
        sa.Column('target_grams', sa.Float, nullable=False),
        sa.Column('count', sa.Integer, nullable=False, server_default='1'),
        sa.Column('entries_json', sa.Text, nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.UniqueConstraint('pet_id', 'recorded_date', name='uq_food_pet_date'),
    )

    # Create water_records table
    op.create_table(
        'water_records',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('pet_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('pets.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('recorded_date', sa.Date, nullable=False),
        sa.Column('total_ml', sa.Float, nullable=False),
        sa.Column('target_ml', sa.Float, nullable=False),
        sa.Column('count', sa.Integer, nullable=False, server_default='1'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.UniqueConstraint('pet_id', 'recorded_date', name='uq_water_pet_date'),
    )


def downgrade() -> None:
    op.drop_table('water_records')
    op.drop_table('food_records')
    op.drop_column('pets', 'growth_stage')
