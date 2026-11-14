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
    title: str = Field(description="Actionable, concise title of the reminder")
    due_at: Optional[datetime] = Field(
        default=None,
        description="Resolved ISO 8601 UTC timestamp for when the reminder is due",
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

