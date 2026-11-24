from datetime import datetime
import enum
from typing import Optional
from pydantic import BaseModel, Field


class ReminderCategory(str, enum.Enum):
    GENERAL = "GENERAL"
    MEDICINE = "MEDICINE"
    BILL = "BILL"
    WORK = "WORK"
    PERSONAL = "PERSONAL"
    BIRTHDAY = "BIRTHDAY"
    DOCUMENT = "DOCUMENT"


class ReminderPriority(str, enum.Enum):
    NORMAL = "NORMAL"
    HIGH = "HIGH"
    URGENT = "URGENT"


class ParseIntent(str, enum.Enum):
    """Autonomous intent set — manual delete/update workflows are deprecated."""

    CREATE_REMINDER = "create_reminder"
    LIST_REMINDERS = "list_reminders"
    SAVE_DOCUMENTATION = "save_documentation"
    CHAT = "chat"


class ParseReminderRequest(BaseModel):
    text: str = Field(
        min_length=1,
        max_length=5000,
        description="User natural language utterance in English, Bengali, or Banglish",
    )
    timezone: str = Field(
        default="UTC",
        description="IANA Timezone string, e.g., 'Asia/Dhaka', 'America/New_York'",
    )
    reference_date: Optional[datetime] = Field(
        default=None,
        description="Reference anchor datetime for evaluating relative terms like 'today' or 'কাল'",
    )


class ParsedReminderData(BaseModel):
    """Autonomous parser output with LLM-driven category & priority extraction."""

    intent: ParseIntent = Field(
        default=ParseIntent.CREATE_REMINDER,
        description="create_reminder | list_reminders | save_documentation | chat",
    )
    title: Optional[str] = Field(
        default=None,
        description="Extracted task or note title",
    )
    date: Optional[str] = Field(
        default=None,
        pattern=r"^\d{4}-\d{2}-\d{2}$",
        description="Resolved date, YYYY-MM-DD in the user's local timezone",
    )
    time: Optional[str] = Field(
        default=None,
        pattern=r"^\d{2}:\d{2}$",
        description="Resolved 24-hour time, HH:MM local",
    )
    clarifying_question: Optional[str] = Field(
        default=None,
        description="Short follow-up question when time/date is unclear; otherwise null",
    )
    due_at: Optional[datetime] = Field(
        default=None,
        description="Resolved ISO 8601 UTC timestamp (server-computed from date+time+timezone)",
    )
    category: ReminderCategory = Field(
        default=ReminderCategory.GENERAL,
        description="Autonomously classified category for the reminder or document",
    )
    priority: ReminderPriority = Field(
        default=ReminderPriority.NORMAL,
        description="Autonomously classified urgency/priority rating",
    )
    confidence: float = Field(
        default=1.0,
        ge=0.0,
        le=1.0,
        description="Model confidence score in the parsed entity extraction",
    )


class ParseReminderResponse(BaseModel):
    success: bool = True
    data: ParsedReminderData
