import json
from typing import Optional

from fastapi import APIRouter, Depends, File, Form, Header, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import get_current_user_optional
from app.core.tenant import (
    TenantContext,
    get_header_tenant_context,
    resolve_tenant_context,
)
from app.db.session import get_db
from app.models.user import User
from app.schemas.voice import (
    AssistantMessageRequest,
    ReminderRecordDTO,
    StagedAttachmentPreview,
    StagedAttachmentPreviewResponse,
    VoiceCommandResponse,
)
from app.services.staging_service import attachment_staging_service
from app.services.voice_assistant_service import VoiceAssistantService

router = APIRouter(tags=["Voice & Multimodal Assistant"])


def _parse_staging_ids_form(raw: Optional[str]) -> Optional[list[str]]:
    if not raw or not raw.strip():
        return None
    trimmed = raw.strip()
    if trimmed.startswith("["):
        try:
            parsed = json.loads(trimmed)
            if isinstance(parsed, list):
                return [str(x).strip() for x in parsed if str(x).strip()]
        except json.JSONDecodeError:
            pass
    return [part.strip() for part in trimmed.split(",") if part.strip()]


@router.post(
    "/attachments/stage",
    response_model=StagedAttachmentPreviewResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Decoupled attachment staging into uncommitted composer preview state",
)
async def stage_attachment_preview(
    attachment: UploadFile = File(..., description="File or image to stage in composer preview"),
    user_id: Optional[str] = Form(default=None),
    x_session_id: Optional[str] = Header(default=None, alias="X-Session-ID"),
    current_user: Optional[User] = Depends(get_current_user_optional),
) -> StagedAttachmentPreviewResponse:
    tenant = resolve_tenant_context(
        current_user,
        form_user_id=user_id,
        header_session_id=x_session_id,
    )
    await attachment_staging_service.stage_upload(tenant=tenant, upload=attachment)
    staged_list = await attachment_staging_service.list_staged_for_tenant(tenant)
    return StagedAttachmentPreviewResponse(
        status="staged_preview",
        tenant_scope="ephemeral" if tenant.is_ephemeral else "authenticated",
        staged=[StagedAttachmentPreview(**it.to_preview_dict()) for it in staged_list],
    )


@router.get(
    "/attachments/staged",
    response_model=StagedAttachmentPreviewResponse,
    status_code=status.HTTP_200_OK,
    summary="List uncommitted staged attachments for the current tenant session",
)
async def get_staged_attachments(
    tenant: TenantContext = Depends(get_header_tenant_context),
) -> StagedAttachmentPreviewResponse:
    staged_list = await attachment_staging_service.list_staged_for_tenant(tenant)
    return StagedAttachmentPreviewResponse(
        status="staged_preview",
        tenant_scope="ephemeral" if tenant.is_ephemeral else "authenticated",
        staged=[StagedAttachmentPreview(**it.to_preview_dict()) for it in staged_list],
    )


@router.post(
    "/voice-command",
    response_model=VoiceCommandResponse,
    status_code=status.HTTP_200_OK,
    summary="Multimodal Voice & Attachment Assistant (Decoupled Staging + Atomic Bundled Execution)",
)
async def handle_voice_command(
    audio: Optional[UploadFile] = File(
        default=None,
        description="Optional voice audio file (.m4a, .wav, .mp3, .webm). Omit when staging attachment preview only.",
    ),
    attachment: Optional[UploadFile] = File(
        default=None,
        description="Optional file or image attachment. If submitted without audio/message, stages as uncommitted preview.",
    ),
    message: Optional[str] = Form(
        default=None,
        description="Optional text command to bundle with staged attachments.",
    ),
    staging_ids: Optional[str] = Form(
        default=None,
        description="Optional comma-separated or JSON list of staged attachment IDs to bundle atomically.",
    ),
    user_id: Optional[str] = Form(
        default=None,
        description="Session/User identifier (strictly validated against JWT or isolated ephemeral pool).",
    ),
    x_session_id: Optional[str] = Header(default=None, alias="X-Session-ID"),
    current_user: Optional[User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_db),
) -> VoiceCommandResponse:
    tenant = resolve_tenant_context(
        current_user,
        form_user_id=user_id,
        header_session_id=x_session_id,
    )
    inline_list = [attachment] if attachment is not None else None
    return await VoiceAssistantService.process_multimodal_turn(
        tenant=tenant,
        db=db,
        audio=audio,
        message_text=message,
        inline_attachments=inline_list,
        staging_ids=_parse_staging_ids_form(staging_ids),
        synthesize_tts=True,
    )


@router.post(
    "/assistant/message",
    response_model=VoiceCommandResponse,
    status_code=status.HTTP_200_OK,
    summary="Submit text command bundling any uncommitted staged attachments atomically",
)
async def handle_assistant_text_message(
    request: AssistantMessageRequest,
    tenant: TenantContext = Depends(get_header_tenant_context),
    db: AsyncSession = Depends(get_db),
) -> VoiceCommandResponse:
    return await VoiceAssistantService.process_multimodal_turn(
        tenant=tenant,
        db=db,
        audio=None,
        message_text=request.message,
        staging_ids=request.staging_ids,
        synthesize_tts=request.synthesize_tts,
    )


@router.get(
    "/assistant/reminders",
    response_model=list[ReminderRecordDTO],
    status_code=status.HTTP_200_OK,
    summary="List tenant-isolated reminders with streamlined scheduled/completed lifecycle",
)
async def list_assistant_reminders(
    tenant: TenantContext = Depends(get_header_tenant_context),
    db: AsyncSession = Depends(get_db),
) -> list[ReminderRecordDTO]:
    return await VoiceAssistantService.list_tenant_reminders(tenant=tenant, db=db)
