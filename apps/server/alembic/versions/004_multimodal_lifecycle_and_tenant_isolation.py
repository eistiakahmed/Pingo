"""streamline reminder lifecycle, add multimodal inbox staging & tenant isolation

Revision ID: 004_multimodal_lifecycle
Revises: 003_voice_assistant_tables
Create Date: 2026-11-24 23:00:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


revision: str = "004_multimodal_lifecycle"
down_revision: Union[str, None] = "003_voice_assistant_tables"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Align `reminders` table: rename user_id -> tenant_id, replace boolean flags with irreversible state + completed_at
    op.drop_index("ix_reminders_user_time", table_name="reminders")
    op.drop_index(op.f("ix_reminders_user_id"), table_name="reminders")

    op.alter_column("reminders", "user_id", new_column_name="tenant_id")
    op.add_column(
        "reminders",
        sa.Column("category", sa.String(length=32), server_default="GENERAL", nullable=False),
    )
    op.add_column(
        "reminders",
        sa.Column("state", sa.String(length=16), server_default="scheduled", nullable=False),
    )
    op.add_column(
        "reminders",
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "reminders",
        sa.Column("attachments_meta", sa.JSON(), server_default="[]", nullable=False),
    )

    # Backfill existing completed rows before dropping legacy boolean/updated_at columns
    op.execute(
        "UPDATE reminders SET state = 'completed', completed_at = updated_at WHERE is_completed = true"
    )
    op.execute(
        "UPDATE reminders SET tenant_id = 'ephem:' || tenant_id WHERE tenant_id NOT LIKE 'user:%' AND tenant_id NOT LIKE 'ephem:%'"
    )

    op.drop_column("reminders", "is_completed")
    op.drop_column("reminders", "updated_at")

    op.create_check_constraint(
        "ck_reminders_valid_lifecycle_state",
        "reminders",
        "state IN ('scheduled', 'completed')",
    )
    op.create_index(op.f("ix_reminders_tenant_id"), "reminders", ["tenant_id"], unique=False)
    op.create_index(op.f("ix_reminders_category"), "reminders", ["category"], unique=False)
    op.create_index(op.f("ix_reminders_state"), "reminders", ["state"], unique=False)
    op.create_index(
        "ix_reminders_tenant_state_time",
        "reminders",
        ["tenant_id", "state", "reminder_time"],
        unique=False,
    )

    # 2. Align `documentations` table: rename user_id -> tenant_id, add category & attachments_meta, drop updated_at
    op.drop_index("ix_documentations_user_created", table_name="documentations")
    op.drop_index(op.f("ix_documentations_user_id"), table_name="documentations")

    op.alter_column("documentations", "user_id", new_column_name="tenant_id")
    op.execute(
        "UPDATE documentations SET tenant_id = 'ephem:' || tenant_id WHERE tenant_id NOT LIKE 'user:%' AND tenant_id NOT LIKE 'ephem:%'"
    )
    op.add_column(
        "documentations",
        sa.Column("category", sa.String(length=32), server_default="DOCUMENT", nullable=False),
    )
    op.add_column(
        "documentations",
        sa.Column("attachments_meta", sa.JSON(), server_default="[]", nullable=False),
    )
    op.drop_column("documentations", "updated_at")

    op.create_index(op.f("ix_documentations_tenant_id"), "documentations", ["tenant_id"], unique=False)
    op.create_index(
        "ix_documentations_tenant_created",
        "documentations",
        ["tenant_id", "created_at"],
        unique=False,
    )

    # 3. Create `assistant_inbox_messages` table for atomic bundled multimodal turns
    op.create_table(
        "assistant_inbox_messages",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("tenant_id", sa.String(length=128), nullable=False),
        sa.Column("modality", sa.String(length=16), nullable=False),
        sa.Column("user_text", sa.Text(), nullable=False),
        sa.Column("assistant_reply", sa.Text(), nullable=False),
        sa.Column("category", sa.String(length=32), server_default="GENERAL", nullable=False),
        sa.Column("attachments_meta", sa.JSON(), server_default="[]", nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_assistant_inbox_messages_tenant_id"),
        "assistant_inbox_messages",
        ["tenant_id"],
        unique=False,
    )
    op.create_index(
        "ix_inbox_messages_tenant_created",
        "assistant_inbox_messages",
        ["tenant_id", "created_at"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_inbox_messages_tenant_created", table_name="assistant_inbox_messages")
    op.drop_index(op.f("ix_assistant_inbox_messages_tenant_id"), table_name="assistant_inbox_messages")
    op.drop_table("assistant_inbox_messages")

    op.drop_index("ix_documentations_tenant_created", table_name="documentations")
    op.drop_index(op.f("ix_documentations_tenant_id"), table_name="documentations")
    op.add_column(
        "documentations",
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.drop_column("documentations", "attachments_meta")
    op.drop_column("documentations", "category")
    op.alter_column("documentations", "tenant_id", new_column_name="user_id")
    op.create_index(op.f("ix_documentations_user_id"), "documentations", ["user_id"], unique=False)
    op.create_index("ix_documentations_user_created", "documentations", ["user_id", "created_at"], unique=False)

    op.drop_index("ix_reminders_tenant_state_time", table_name="reminders")
    op.drop_index(op.f("ix_reminders_state"), table_name="reminders")
    op.drop_index(op.f("ix_reminders_category"), table_name="reminders")
    op.drop_index(op.f("ix_reminders_tenant_id"), table_name="reminders")
    op.drop_constraint("ck_reminders_valid_lifecycle_state", "reminders", type_="check")
    op.add_column(
        "reminders",
        sa.Column("is_completed", sa.Boolean(), server_default=sa.text("false"), nullable=False),
    )
    op.add_column(
        "reminders",
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.drop_column("reminders", "attachments_meta")
    op.drop_column("reminders", "completed_at")
    op.drop_column("reminders", "state")
    op.drop_column("reminders", "category")
    op.alter_column("reminders", "tenant_id", new_column_name="user_id")
    op.create_index(op.f("ix_reminders_user_id"), "reminders", ["user_id"], unique=False)
    op.create_index("ix_reminders_user_time", "reminders", ["user_id", "reminder_time"], unique=False)
