from typing import Any
from pydantic import BaseModel, Field


class ExecutedToolAction(BaseModel):
    tool: str = Field(..., description="Name of the executed tool (e.g. set_reminder, save_documentation)")
    arguments: dict[str, Any] = Field(default_factory=dict, description="Normalized arguments passed to the tool")
    record_id: str | None = Field(default=None, description="Database UUID of the persisted record")


class VoiceCommandResponse(BaseModel):
    user_said: str = Field(..., description="Transcribed text from Groq Whisper large-v3")
    ai_reply: str = Field(..., description="Conversational Bangla response from DeepSeek")
    audio_url: str = Field(..., description="Relative URL to generated Edge-TTS MP3 under /static/audio")
    actions: list[ExecutedToolAction] = Field(
        default_factory=list,
        description="List of executed tools and arguments so the mobile app can schedule local alarms",
    )
