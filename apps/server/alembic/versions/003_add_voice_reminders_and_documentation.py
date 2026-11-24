"""add reminders and documentations tables for Voice AI Assistant

Revision ID: 003_voice_assistant_tables
Revises: 002_device_tokens
Create Date: 2026-11-24 18:50:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


revision: str = "003_voice_assistant_tables"
down_revision: Union[str, None] = "002_device_tokens"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "reminders",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("user_id", sa.String(length=128), nullable=False),
        sa.Column("task_title", sa.String(length=500), nullable=False),
        sa.Column("reminder_time", sa.DateTime(timezone=True), nullable=False),
        sa.Column("is_completed", sa.Boolean(), server_default=sa.text("false"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_reminders_user_id"), "reminders", ["user_id"], unique=False)
    op.create_index(op.f("ix_reminders_reminder_time"), "reminders", ["reminder_time"], unique=False)
    op.create_index("ix_reminders_user_time", "reminders", ["user_id", "reminder_time"], unique=False)

    op.create_table(
        "documentations",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("user_id", sa.String(length=128), nullable=False),
        sa.Column("title", sa.String(length=300), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_documentations_user_id"), "documentations", ["user_id"], unique=False)
    op.create_index("ix_documentations_user_created", "documentations", ["user_id", "created_at"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_documentations_user_created", table_name="documentations")
    op.drop_index(op.f("ix_documentations_user_id"), table_name="documentations")
    op.drop_table("documentations")

    op.drop_index("ix_reminders_user_time", table_name="reminders")
    op.drop_index(op.f("ix_reminders_reminder_time"), table_name="reminders")
    op.drop_index(op.f("ix_reminders_user_id"), table_name="reminders")
    op.drop_table("reminders")
