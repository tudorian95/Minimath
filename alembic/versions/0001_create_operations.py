"""create operations table

Revision ID: 0001_create_operations
Revises: 
Create Date: 2024-05-01 00:00:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "0001_create_operations"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "operations",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("op", sa.String(), nullable=False),
        sa.Column("a", sa.Integer(), nullable=False),
        sa.Column("b", sa.Integer(), nullable=True),
        sa.Column("result", sa.String(), nullable=True),
        sa.Column("status", sa.String(), nullable=False, server_default="pending"),
        sa.Column("timestamp", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_operations_id", "operations", ["id"], unique=True)


def downgrade() -> None:
    op.drop_index("ix_operations_id", table_name="operations")
    op.drop_table("operations")
