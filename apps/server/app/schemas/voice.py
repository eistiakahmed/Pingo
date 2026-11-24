from datetime import datetime
from typing import Any, Literal, Optional
from pydantic import BaseModel, Field

from app.models.voice_assistant import TaskCategory, TaskLifecycleState


class StagedAttachmentPreview(BaseModel):
    staging_id: str = Field(..., description="Opaque staging token bound strictly to caller tenant")
    filename: str
    mime_type: str
    size_bytes: int = Field(ge=1)
    sha256: str
    state: Literal["staged_uncommitted"] = "staged_uncommitted"
    expires_at: datetime


class StagedAttachmentPreviewResponse(BaseModel):
    status: Literal["staged_preview"] = "staged_preview"
    tenant_scope: Literal["authenticated", "ephemeral"]
    staged: list[StagedAttachmentPreview]


class PipelineTelemetry(BaseModel):
    request_id: str
    tenant_scope: Literal["authenticated", "ephemeral"]
    classified_category: TaskCategory = TaskCategory.GENERAL
    bundled_attachments_count: int = Field(default=0, ge=0)
    stt_ms: float = Field(default=0.0, ge=0.0)
    llm_ms: float = Field(default=0.0, ge=0.0)
    tts_ms: float = Field(default=0.0, ge=0.0)
    total_ms: float = Field(default=0.0, ge=0.0)


class ExecutedToolAction(BaseModel):
    tool: str = Field(..., description="Executed autonomous tool name (set_reminder | save_documentation)")
    arguments: dict[str, Any] = Field(default_factory=dict)
    record_id: Optional[str] = None
    category: TaskCategory = TaskCategory.GENERAL
    lifecycle_state: Optional[TaskLifecycleState] = None


class VoiceCommandResponse(BaseModel):
    status: Literal["completed_turn", "staged_preview"] = "completed_turn"
    user_said: str = Field(default="", description="Transcribed speech or submitted message text")
    ai_reply: str = Field(default="", description="Conversational response")
    audio_url: str = Field(default="", description="Relative URL to generated Edge-TTS MP3 under /static/audio")
    actions: list[ExecutedToolAction] = Field(default_factory=list)
    staged_attachments: list[StagedAttachmentPreview] = Field(
        default_factory=list,
        description="Uncommitted preview attachments when called in decoupled staging mode",
    )
    bundled_attachments: list[dict[str, Any]] = Field(
        default_factory=list,
        description="Attachments atomically bundled and committed with this message turn",
    )
    telemetry: Optional[PipelineTelemetry] = None


class AssistantMessageRequest(BaseModel):
    message: str = Field(min_length=1, max_length=5000)
    staging_ids: Optional[list[str]] = Field(
        default=None,
        max_length=10,
        description="Optional list of staged attachment IDs to bundle atomically; defaults to all staged in session",
    )
    synthesize_tts: bool = Field(default=False)


class ReminderRecordDTO(BaseModel):
    id: str
    task_title: str
    category: TaskCategory
    reminder_time: datetime
    state: TaskLifecycleState
    completed_at: Optional[datetime] = None
    attachments_meta: list[dict[str, Any]] = Field(default_factory=list)
    created_at: datetime
