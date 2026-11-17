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


class ReminderPriority(str, enum.Enum):
    NORMAL = "NORMAL"
    HIGH = "HIGH"
    URGENT = "URGENT"


class ParseIntent(str, enum.Enum):
    """Single intent the parser may return. 'set an alarm' == 'set a reminder'."""
    CREATE_REMINDER = "create_reminder"
    LIST_REMINDERS = "list_reminders"
    DELETE_REMINDER = "delete_reminder"
    UPDATE_REMINDER = "update_reminder"
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
    """Parser output. date/time are the model's structured fields (user's words kept);
    due_at is computed server-side by deterministic resolver logic, never by the model."""
    intent: ParseIntent = Field(
        default=ParseIntent.CREATE_REMINDER,
        description="create_reminder | list_reminders | delete_reminder | update_reminder | chat",
    )
    title: Optional[str] = Field(
        default=None,
        description="Title built from the user's own words, never corrected or translated",
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
        description="Exactly one short follow-up question when time/date is unclear; otherwise null",
    )
    due_at: Optional[datetime] = Field(
        default=None,
        description="Resolved ISO 8601 UTC timestamp (server-computed from date+time+timezone)",
    )
    category: ReminderCategory = Field(
        default=ReminderCategory.GENERAL,
        description="Classified category for the reminder",
    )
    priority: ReminderPriority = Field(
        default=ReminderPriority.NORMAL,
        description="Urgency/Priority rating",
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

