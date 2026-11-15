"""add device_tokens and notification_sent column

Revision ID: 002_device_tokens
Revises: 001_initial_schema
Create Date: 2026-11-15 19:30:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


revision: str = "002_device_tokens"
down_revision: Union[str, None] = "001_initial_schema"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Add notification_sent to encrypted_reminders
    op.add_column(
        "encrypted_reminders",
        sa.Column("notification_sent", sa.Boolean(), server_default=sa.text("false"), nullable=False),
    )
    op.create_index(
        op.f("ix_encrypted_reminders_notification_sent"),
        "encrypted_reminders",
        ["notification_sent"],
        unique=False,
    )

    # 2. Create device_tokens table
    op.create_table(
        "device_tokens",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("token", sa.String(length=512), nullable=False),
        sa.Column("platform", sa.String(length=32), server_default="android", nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_device_tokens_token"), "device_tokens", ["token"], unique=True)
    op.create_index(op.f("ix_device_tokens_user_id"), "device_tokens", ["user_id"], unique=False)


def downgrade() -> None:
    op.drop_index(op.f("ix_device_tokens_user_id"), table_name="device_tokens")
    op.drop_index(op.f("ix_device_tokens_token"), table_name="device_tokens")
    op.drop_table("device_tokens")

    op.drop_index(op.f("ix_encrypted_reminders_notification_sent"), table_name="encrypted_reminders")
    op.drop_column("encrypted_reminders", "notification_sent")
