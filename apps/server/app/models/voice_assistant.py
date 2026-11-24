from datetime import datetime, timezone
import enum
from typing import Any, Optional
from uuid import UUID, uuid4

from sqlalchemy import CheckConstraint, DateTime, Index, JSON, String, Text, event
from sqlalchemy.orm import Mapped, mapped_column
from app.db.base import Base


class TaskLifecycleState(str, enum.Enum):
    """Streamlined, strictly one-way task lifecycle: scheduled -> completed."""

    SCHEDULED = "scheduled"
    COMPLETED = "completed"


class TaskCategory(str, enum.Enum):
    """Autonomous LLM-assigned task & note categories."""

    MEDICINE = "MEDICINE"
    BILL = "BILL"
    WORK = "WORK"
    PERSONAL = "PERSONAL"
    BIRTHDAY = "BIRTHDAY"
    DOCUMENT = "DOCUMENT"
    GENERAL = "GENERAL"


class Reminder(Base):
    """Streamlined assistant reminder model with irreversible scheduled -> completed lifecycle.

    Removes redundant boolean status flags (`is_completed`, `updated_at`) while
    preserving exact `created_at` and `completed_at` historical tracking.
    """

    __tablename__ = "reminders"

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    tenant_id: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    task_title: Mapped[str] = mapped_column(String(500), nullable=False)
    category: Mapped[str] = mapped_column(
        String(32), default=TaskCategory.GENERAL.value, nullable=False, index=True
    )
    reminder_time: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, index=True
    )
    state: Mapped[str] = mapped_column(
        String(16), default=TaskLifecycleState.SCHEDULED.value, nullable=False, index=True
    )
    completed_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    attachments_meta: Mapped[list[dict[str, Any]]] = mapped_column(
        JSON, default=list, nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    __table_args__ = (
        CheckConstraint(
            "state IN ('scheduled', 'completed')",
            name="ck_reminders_valid_lifecycle_state",
        ),
        Index("ix_reminders_tenant_state_time", "tenant_id", "state", "reminder_time"),
    )

    def mark_completed(self, when: Optional[datetime] = None) -> None:
        """Irreversibly transitions the reminder into `completed`."""
        if self.state == TaskLifecycleState.COMPLETED.value:
            return
        self.state = TaskLifecycleState.COMPLETED.value
        self.completed_at = when or datetime.now(timezone.utc)


@event.listens_for(Reminder.state, "set")
def _guard_irreversible_reminder_state(
    target: Reminder, value: str, oldvalue: Any, _initiator: Any
) -> None:
    """ORM-level guard: once `state == 'completed'`, any attempt to revert raises ValueError."""
    if (
        oldvalue == TaskLifecycleState.COMPLETED.value
        and value != TaskLifecycleState.COMPLETED.value
    ):
        raise ValueError("Irreversible lifecycle violation: completed reminder cannot transition back.")


class Documentation(Base):
    """Streamlined documentation & project note model scoped strictly by `tenant_id`."""

    __tablename__ = "documentations"

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    tenant_id: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    category: Mapped[str] = mapped_column(
        String(32), default=TaskCategory.DOCUMENT.value, nullable=False
    )
    title: Mapped[str] = mapped_column(String(300), nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    attachments_meta: Mapped[list[dict[str, Any]]] = mapped_column(
        JSON, default=list, nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    __table_args__ = (
        Index("ix_documentations_tenant_created", "tenant_id", "created_at"),
    )


class AssistantInboxMessage(Base):
    """Atomic bundled message record tying user command + committed staged attachments."""

    __tablename__ = "assistant_inbox_messages"

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    tenant_id: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    modality: Mapped[str] = mapped_column(String(16), nullable=False)  # "voice" | "text"
    user_text: Mapped[str] = mapped_column(Text, nullable=False)
    assistant_reply: Mapped[str] = mapped_column(Text, nullable=False)
    category: Mapped[str] = mapped_column(
        String(32), default=TaskCategory.GENERAL.value, nullable=False
    )
    attachments_meta: Mapped[list[dict[str, Any]]] = mapped_column(
        JSON, default=list, nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    __table_args__ = (
        Index("ix_inbox_messages_tenant_created", "tenant_id", "created_at"),
    )
