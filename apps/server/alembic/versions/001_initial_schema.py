"""initial schema

Revision ID: 001_initial_schema
Revises:
Create Date: 2026-11-07 01:30:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "001_initial_schema"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Create Users Table
    op.create_table(
        "users",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("email", sa.String(length=255), nullable=False),
        sa.Column("password_hash", sa.String(length=255), nullable=False),
        sa.Column("plan_tier", sa.Enum("FREE", "PRO", name="plantier"), nullable=False),
        sa.Column("client_salt", sa.String(length=128), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_users_email"), "users", ["email"], unique=True)

    # 2. Create Encrypted Reminders Table
    op.create_table(
        "encrypted_reminders",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("ciphertext", sa.Text(), nullable=False),
        sa.Column("iv", sa.String(length=64), nullable=False),
        sa.Column("auth_tag", sa.String(length=64), nullable=False),
        sa.Column("key_version", sa.Integer(), nullable=False),
        sa.Column("algorithm", sa.String(length=32), nullable=False),
        sa.Column("due_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("is_completed", sa.Boolean(), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_encrypted_reminders_user_id", "encrypted_reminders", ["user_id"], unique=False)
    op.create_index("ix_encrypted_reminders_user_updated", "encrypted_reminders", ["user_id", "updated_at"], unique=False)
    op.create_index("ix_encrypted_reminders_due_active", "encrypted_reminders", ["due_at", "is_completed"], unique=False)

    # 3. Create Encrypted Vault Items Table
    op.create_table(
        "encrypted_vault_items",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("item_type", sa.String(length=32), nullable=False),
        sa.Column("ciphertext", sa.Text(), nullable=False),
        sa.Column("iv", sa.String(length=64), nullable=False),
        sa.Column("auth_tag", sa.String(length=64), nullable=False),
        sa.Column("key_version", sa.Integer(), nullable=False),
        sa.Column("algorithm", sa.String(length=32), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_encrypted_vault_user_id", "encrypted_vault_items", ["user_id"], unique=False)
    op.create_index("ix_encrypted_vault_user_updated", "encrypted_vault_items", ["user_id", "updated_at"], unique=False)


def downgrade() -> None:
    op.drop_table("encrypted_vault_items")
    op.drop_table("encrypted_reminders")
    op.drop_table("users")
    op.execute("DROP TYPE plantier")

