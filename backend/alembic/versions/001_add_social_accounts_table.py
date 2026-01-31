"""add social_accounts table and remove oauth columns from users

Revision ID: 001
Revises:
Create Date: 2026-01-29
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '001'
down_revision: Union[str, None] = '000'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Create social_accounts table
    op.create_table(
        'social_accounts',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('provider', sa.String(50), nullable=False),
        sa.Column('provider_id', sa.String(255), nullable=False),
        sa.Column('provider_email', sa.String(255), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.UniqueConstraint('provider', 'provider_id', name='uq_social_provider_id'),
    )

    # Migrate existing OAuth data from users to social_accounts
    op.execute("""
        INSERT INTO social_accounts (id, user_id, provider, provider_id, created_at)
        SELECT gen_random_uuid(), id, oauth_provider, oauth_provider_id, created_at
        FROM users
        WHERE oauth_provider IS NOT NULL AND oauth_provider_id IS NOT NULL
    """)

    # Remove oauth columns from users table
    op.drop_column('users', 'oauth_provider')
    op.drop_column('users', 'oauth_provider_id')


def downgrade() -> None:
    # Add oauth columns back to users table
    op.add_column('users', sa.Column('oauth_provider', sa.String(50), nullable=True))
    op.add_column('users', sa.Column('oauth_provider_id', sa.String(255), nullable=True))

    # Migrate data back (only first social account per user)
    op.execute("""
        UPDATE users u
        SET oauth_provider = sa.provider, oauth_provider_id = sa.provider_id
        FROM (
            SELECT DISTINCT ON (user_id) user_id, provider, provider_id
            FROM social_accounts
            ORDER BY user_id, created_at ASC
        ) sa
        WHERE u.id = sa.user_id
    """)

    # Drop social_accounts table
    op.drop_table('social_accounts')
