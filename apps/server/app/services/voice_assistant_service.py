import base64
from datetime import datetime, timedelta, timezone
import json
import logging
import os
from pathlib import Path
import re
import tempfile
import time
from typing import Any, Optional
from uuid import UUID, uuid4
from zoneinfo import ZoneInfo

import edge_tts
from fastapi import UploadFile, status
from groq import AsyncGroq
from openai import AsyncOpenAI
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.exceptions import AppException
from app.core.tenant import TenantContext, ephemeral_tenant_store
from app.models.reminder import EncryptedReminder
from app.models.user import User
from app.models.voice_assistant import (
    AssistantInboxMessage,
    Documentation,
    Reminder,
    TaskCategory,
    TaskLifecycleState,
)
from app.schemas.voice import (
    ExecutedToolAction,
    PipelineTelemetry,
    ReminderRecordDTO,
    StagedAttachmentPreview,
    VoiceCommandResponse,
)
from app.services.staging_service import StagedAttachmentItem, attachment_staging_service

logger = logging.getLogger(__name__)

BD_TZ = ZoneInfo("Asia/Dhaka")
BD_OFFSET = timezone(timedelta(hours=6))

WHISPER_CONTEXT_PROMPT = (
    "বাংলা, English, Banglish voice assistant Pingo. "
    "রিমাইন্ডার, অ্যালার্ম, আজকে, আগামীকাল, পরশু, সকাল, দুপুর, বিকাল, রাত, ডকুমেন্টেশন, প্রজেক্ট নোট, "
    "মিটিং, ওষুধ, বিল, ডাক্তার, FastAPI, Flutter, PostgreSQL, Docker, API, endpoint, deployment, "
    "database, bug fix, sprint, GitHub, server, remind me, save note, documentation."
)

VALID_CATEGORIES = [c.value for c in TaskCategory]

DEEPSEEK_TOOLS: list[dict[str, Any]] = [
    {
        "type": "function",
        "function": {
            "name": "set_reminder",
            "description": (
                "Autonomously schedules a user reminder/alarm, assigns an appropriate category "
                "without manual user input, and converts the target time to ISO 8601 (+06:00). "
                "Note: Manual edit, delete, and manual completion workflows are deprecated; "
                "reminders follow an automated scheduled -> completed lifecycle."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "task_title": {
                        "type": "string",
                        "description": "Concise, clear title of the reminder task.",
                    },
                    "reminder_time": {
                        "type": "string",
                        "description": "Target reminder timestamp in ISO 8601 format with +06:00 offset (e.g. '2026-11-24T22:00:00+06:00').",
                    },
                    "category": {
                        "type": "string",
                        "enum": VALID_CATEGORIES,
                        "description": "Autonomously inferred task category (MEDICINE, BILL, WORK, PERSONAL, BIRTHDAY, DOCUMENT, GENERAL).",
                    },
                },
                "required": ["task_title", "reminder_time", "category"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "save_documentation",
            "description": (
                "Autonomously formats, categorizes, and saves project notes, attachments, "
                "or technical documentation."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "title": {
                        "type": "string",
                        "description": "Short descriptive title for the documentation or project note.",
                    },
                    "content": {
                        "type": "string",
                        "description": "Well-structured, formatted documentation or note content.",
                    },
                    "category": {
                        "type": "string",
                        "enum": VALID_CATEGORIES,
                        "description": "Autonomously inferred category (DOCUMENT, WORK, BILL, MEDICINE, PERSONAL, GENERAL).",
                    },
                },
                "required": ["title", "content", "category"],
            },
        },
    },
]

EDGE_TTS_VOICE = "bn-BD-NabanitaNeural"
AUDIO_TTL_SECONDS = 24 * 3600
MAX_AUDIO_BYTES = 25 * 1024 * 1024

STATIC_AUDIO_DIR = Path(__file__).resolve().parent.parent / "static" / "audio"


def strip_markdown_for_tts(text: str) -> str:
    """Strips markdown formatting characters (*, #, _, `, ~) so Edge-TTS reads cleanly."""
    cleaned = re.sub(r"[*#_`~]+", "", text)
    cleaned = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", cleaned)
    cleaned = re.sub(r"\s+", " ", cleaned).strip()
    return cleaned or "ঠিক আছে।"


def cleanup_old_tts_files(
    audio_dir: Path = STATIC_AUDIO_DIR, max_age_seconds: int = AUDIO_TTL_SECONDS
) -> int:
    """Deletes .mp3 files in app/static/audio older than max_age_seconds (default 24h)."""
    if not audio_dir.exists():
        return 0
    cutoff = time.time() - max_age_seconds
    removed = 0
    for mp3_file in audio_dir.glob("*.mp3"):
        try:
            if mp3_file.stat().st_mtime < cutoff:
                mp3_file.unlink(missing_ok=True)
                removed += 1
        except OSError as exc:
            logger.warning("[VoiceAssistant] Could not remove stale audio %s: %s", mp3_file, exc)
    return removed


def normalize_bd_iso8601(raw_time: str, now_bd: datetime) -> tuple[datetime, str]:
    """Parses ISO 8601 string and normalizes it to Bangladesh time (+06:00)."""
    candidate = raw_time.strip()
    if candidate.endswith("Z"):
        candidate = candidate[:-1] + "+00:00"
    try:
        dt = datetime.fromisoformat(candidate)
    except ValueError:
        dt = now_bd + timedelta(hours=1)

    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=BD_OFFSET)
    else:
        dt = dt.astimezone(BD_OFFSET)

    return dt, dt.isoformat(timespec="seconds")


def coerce_task_category(raw_cat: Any, fallback: TaskCategory = TaskCategory.GENERAL) -> TaskCategory:
    if isinstance(raw_cat, TaskCategory):
        return raw_cat
    val = str(raw_cat or "").strip().upper()
    for member in TaskCategory:
        if member.value == val:
            return member
    return fallback


def infer_category_heuristic(text: str) -> TaskCategory:
    lower = text.lower()
    if any(k in lower for k in ("med", "pill", "doctor", "ওষুধ", "ডাক্তার", "prescription")):
        return TaskCategory.MEDICINE
    if any(k in lower for k in ("bill", "invoice", "bank", "electricity", "বিল", "টাকা", "ব্যাংক")):
        return TaskCategory.BILL
    if any(k in lower for k in ("deploy", "api", "meeting", "sprint", "server", "মিটিং", "প্রজেক্ট")):
        return TaskCategory.WORK
    if any(k in lower for k in ("birthday", "anniversary", "জন্মদিন")):
        return TaskCategory.BIRTHDAY
    if any(k in lower for k in ("passport", "nid", "document", "license", "ডকুমেন্ট", "নোট")):
        return TaskCategory.DOCUMENT
    return TaskCategory.GENERAL


def build_deepseek_system_prompt(
    now_bd: datetime, staged_attachments: list[StagedAttachmentItem]
) -> str:
    formatted_now = now_bd.strftime("%Y-%m-%d %H:%M:%S %A (UTC+06:00)")
    iso_now = now_bd.isoformat(timespec="seconds")

    attachment_context = ""
    if staged_attachments:
        summary = ", ".join(
            f"{it.filename} ({it.mime_type}, {it.size_bytes} bytes)"
            for it in staged_attachments
        )
        attachment_context = (
            f"\nসংযুক্ত ফাইল/ইমেজ (Staged Attachments bundled with this message): [{summary}]।\n"
            "ইউজার যদি এই সংযুক্ত ফাইলের মেয়াদ বা রিমাইন্ডার চায় তবে `set_reminder` (category='DOCUMENT' বা উপযুক্ত ক্যাটাগরি) "
            "অথবা নোট হিসেবে রাখতে বললে `save_documentation` কল করো।\n"
        )

    return (
        "তুমি পিঙ্গো (Pingo) — একটি বুদ্ধিমান, স্বয়ংক্রিয় এবং নির্ভুল ভয়েস ও মাল্টিমোডাল এআই সহকারী।\n"
        f"বর্তমান বাংলাদেশ সময় (Asia/Dhaka, UTC+06:00): {formatted_now} (ISO: {iso_now})।\n"
        f"{attachment_context}\n"
        "নির্দেশনাবলী:\n"
        "১. ইউজার বাংলা, ইংরেজি (English), অথবা বাংলিশ (Banglish) — যেকোনো ভাষায় কথা বলতে পারে। ট্রান্সক্রিপশনের ছোটখাটো বানান/উচ্চারণগত ভুল স্বয়ংক্রিয়ভাবে ঠিক করে বোঝো।\n"
        "২. স্বয়ংক্রিয় ক্যাটাগরিকরণ (Autonomous Categorization): ইউজারকে ক্যাটাগরি জিজ্ঞেস না করে নিজেই বার্তার অর্থ বুঝে "
        "`MEDICINE`, `BILL`, `WORK`, `PERSONAL`, `BIRTHDAY`, `DOCUMENT`, অথবা `GENERAL` ক্যাটাগরি নির্ধারণ করো।\n"
        "৩. রিমাইন্ডার বা অ্যালার্মের জন্য `set_reminder(task_title, reminder_time, category)` টুল কল করো (`+06:00` ISO 8601 ফরম্যাটে)।\n"
        "৪. ম্যানুয়াল রিমাইন্ডার ডিলিট, এডিট বা ম্যানুয়াল কমপ্লিট ওয়ার্কফ্লো বাতিল করা হয়েছে — নির্ধারিত সময় হলে সিস্টেম নিজে থেকেই রিমাইন্ডার `completed` করে দেয়।\n"
        "৫. প্রজেক্ট নোট বা ডকুমেন্টেশন সংরক্ষণের জন্য `save_documentation(title, content, category)` কল করো।\n"
        "৬. সবসময় স্বাভাবিক, সংক্ষিপ্ত এবং প্রাঞ্জল কথ্য বাংলায় উত্তর দেবে।"
    )


class VoiceAssistantService:
    @classmethod
    async def stage_attachments_only(
        cls,
        *,
        tenant: TenantContext,
        uploads: list[UploadFile],
    ) -> VoiceCommandResponse:
        """Decoupled Inbox Staging: stages file/image attachments without auto-sending any message."""
        for upload in uploads:
            await attachment_staging_service.stage_upload(tenant=tenant, upload=upload)

        all_staged = await attachment_staging_service.list_staged_for_tenant(tenant)
        previews = [StagedAttachmentPreview(**it.to_preview_dict()) for it in all_staged]
        return VoiceCommandResponse(
            status="staged_preview",
            staged_attachments=previews,
            telemetry=PipelineTelemetry(
                request_id=uuid4().hex,
                tenant_scope="ephemeral" if tenant.is_ephemeral else "authenticated",
                bundled_attachments_count=0,
            ),
        )

    @classmethod
    async def process_multimodal_turn(
        cls,
        *,
        tenant: TenantContext,
        db: AsyncSession,
        audio: Optional[UploadFile] = None,
        message_text: Optional[str] = None,
        inline_attachments: Optional[list[UploadFile]] = None,
        staging_ids: Optional[list[str]] = None,
        synthesize_tts: bool = True,
    ) -> VoiceCommandResponse:
        """Executes decoupled staging OR atomic bundled multimodal command execution."""
        t0 = time.perf_counter()
        request_id = uuid4().hex

        # Stage any newly attached files included in this multipart call first
        if inline_attachments:
            for att in inline_attachments:
                if att and att.filename:
                    await attachment_staging_service.stage_upload(tenant=tenant, upload=att)

        has_audio = audio is not None and bool((audio.filename or "").strip())
        has_text = bool(message_text and message_text.strip())

        # Directive 1: If caller uploaded attachment(s) WITHOUT audio or text command,
        # stage in uncommitted composer preview state and return immediately without auto-sending!
        if not has_audio and not has_text:
            all_staged = await attachment_staging_service.list_staged_for_tenant(tenant)
            if not all_staged:
                raise AppException(
                    title="Empty Turn Payload",
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Provide an audio recording, text message, or attachment to stage.",
                    type_url="https://api.pingo.app/errors/empty-turn",
                )
            return VoiceCommandResponse(
                status="staged_preview",
                staged_attachments=[
                    StagedAttachmentPreview(**it.to_preview_dict()) for it in all_staged
                ],
                telemetry=PipelineTelemetry(
                    request_id=request_id,
                    tenant_scope="ephemeral" if tenant.is_ephemeral else "authenticated",
                    total_ms=round((time.perf_counter() - t0) * 1000, 2),
                ),
            )

        settings = get_settings()
        groq_key = (settings.GROQ_API_KEY or os.getenv("GROQ_API_KEY", "")).strip()
        deepseek_key = (settings.DEEPSEEK_API_KEY or os.getenv("DEEPSEEK_API_KEY", "")).strip()

        if has_audio and not groq_key:
            raise AppException(
                title="Voice Service Unconfigured",
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="GROQ_API_KEY is not configured in environment.",
                type_url="https://api.pingo.app/errors/groq-unconfigured",
            )
        if not deepseek_key:
            raise AppException(
                title="AI Brain Unconfigured",
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="DEEPSEEK_API_KEY is not configured in environment.",
                type_url="https://api.pingo.app/errors/deepseek-unconfigured",
            )

        STATIC_AUDIO_DIR.mkdir(parents=True, exist_ok=True)
        cleanup_old_tts_files(STATIC_AUDIO_DIR)

        # Claim staged attachments belonging strictly to this tenant for atomic bundling
        claimed_staged = await attachment_staging_service.claim_for_bundle(
            tenant=tenant, staging_ids=staging_ids
        )

        stt_ms = 0.0
        llm_ms = 0.0
        tts_ms = 0.0

        try:
            # 1. Resolve user utterance via Groq Whisper STT (if voice) or text input
            if has_audio and audio is not None:
                stt_start = time.perf_counter()
                user_said = await cls._read_and_transcribe_upload(audio, groq_key)
                stt_ms = round((time.perf_counter() - stt_start) * 1000, 2)
                if has_text and message_text:
                    user_said = f"{user_said}\n{message_text.strip()}".strip()
                modality = "voice"
            else:
                user_said = (message_text or "").strip()
                modality = "text"

            if not user_said:
                raise AppException(
                    title="No Speech Detected",
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail="Could not detect clear speech in the uploaded audio.",
                )

            # Prepare attachment metadata preview for atomic DB write
            pending_bundle_meta = [
                it.to_committed_meta(
                    committed_url=(
                        None
                        if tenant.is_ephemeral
                        else f"/static/attachments/{tenant.storage_bucket_key}/{it.staging_id}_{it.filename}"
                    )
                )
                for it in claimed_staged
            ]

            # 2. DeepSeek Autonomous Classification + Tool Calling + Atomic Persistence
            llm_start = time.perf_counter()
            ai_reply, actions, dominant_category = await cls._run_atomic_brain_and_persist(
                tenant=tenant,
                modality=modality,
                user_said=user_said,
                staged_items=claimed_staged,
                bundle_meta=pending_bundle_meta,
                deepseek_key=deepseek_key,
                base_url=settings.DEEPSEEK_BASE_URL,
                model_name=settings.DEEPSEEK_MODEL,
                db=db,
            )
            llm_ms = round((time.perf_counter() - llm_start) * 1000, 2)

            # Commit staged files only AFTER DB / ephemeral transaction succeeded
            committed_attachments = await attachment_staging_service.finalize_commit(
                tenant=tenant, claimed_items=claimed_staged
            )
        except Exception:
            await attachment_staging_service.rollback_claim(
                tenant=tenant, claimed_items=claimed_staged
            )
            raise

        # 3. Optional Edge-TTS Bangla synthesis
        audio_url = ""
        if synthesize_tts:
            tts_start = time.perf_counter()
            audio_url = await cls._synthesize_bangla_tts(ai_reply)
            tts_ms = round((time.perf_counter() - tts_start) * 1000, 2)

        total_ms = round((time.perf_counter() - t0) * 1000, 2)

        return VoiceCommandResponse(
            status="completed_turn",
            user_said=user_said,
            ai_reply=ai_reply,
            audio_url=audio_url,
            actions=actions,
            staged_attachments=[],
            bundled_attachments=committed_attachments,
            telemetry=PipelineTelemetry(
                request_id=request_id,
                tenant_scope="ephemeral" if tenant.is_ephemeral else "authenticated",
                classified_category=dominant_category,
                bundled_attachments_count=len(committed_attachments),
                stt_ms=stt_ms,
                llm_ms=llm_ms,
                tts_ms=tts_ms,
                total_ms=total_ms,
            ),
        )

    @classmethod
    async def list_tenant_reminders(
        cls, *, tenant: TenantContext, db: AsyncSession
    ) -> list[ReminderRecordDTO]:
        """Strictly tenant-scoped reminder query (`WHERE tenant_id = :tenant_id`)."""
        if tenant.is_ephemeral:
            ephemeral_tenant_store.auto_complete_due_reminders(tenant)
            rows = ephemeral_tenant_store.list_records(tenant, kind="reminder")
            return [
                ReminderRecordDTO(
                    id=r["id"],
                    task_title=r["task_title"],
                    category=coerce_task_category(r.get("category")),
                    reminder_time=datetime.fromisoformat(r["reminder_time"]),
                    state=TaskLifecycleState(r.get("state", "scheduled")),
                    completed_at=(
                        datetime.fromisoformat(r["completed_at"])
                        if r.get("completed_at")
                        else None
                    ),
                    attachments_meta=r.get("attachments_meta", []),
                    created_at=datetime.fromisoformat(r["created_at"]),
                )
                for r in rows
            ]

        stmt = (
            select(Reminder)
            .where(Reminder.tenant_id == tenant.tenant_id)
            .order_by(Reminder.reminder_time.asc())
        )
        res = await db.execute(stmt)
        items = res.scalars().all()
        return [
            ReminderRecordDTO(
                id=str(r.id),
                task_title=r.task_title,
                category=coerce_task_category(r.category),
                reminder_time=r.reminder_time,
                state=TaskLifecycleState(r.state),
                completed_at=r.completed_at,
                attachments_meta=r.attachments_meta or [],
                created_at=r.created_at,
            )
            for r in items
        ]

    @classmethod
    async def _read_and_transcribe_upload(cls, audio: UploadFile, groq_key: str) -> str:
        suffix = Path(audio.filename or "voice.m4a").suffix.lower() or ".m4a"
        tmp_path: Optional[Path] = None
        try:
            raw_bytes = await audio.read()
            if not raw_bytes:
                raise AppException(
                    title="Empty Audio File",
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Uploaded audio file is empty.",
                )
            if len(raw_bytes) > MAX_AUDIO_BYTES:
                raise AppException(
                    title="Audio File Too Large",
                    status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                    detail="Audio file exceeds the 25 MB limit.",
                )

            with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp_file:
                tmp_file.write(raw_bytes)
                tmp_path = Path(tmp_file.name)

            return await cls._transcribe_audio(tmp_path, groq_key)
        finally:
            if tmp_path is not None and tmp_path.exists():
                try:
                    tmp_path.unlink(missing_ok=True)
                except OSError as exc:
                    logger.warning("[VoiceAssistant] Temp audio cleanup warning: %s", exc)

    @classmethod
    async def _transcribe_audio(cls, audio_path: Path, groq_key: str) -> str:
        groq_client = AsyncGroq(api_key=groq_key)
        try:
            with audio_path.open("rb") as audio_stream:
                transcription = await groq_client.audio.transcriptions.create(
                    file=(audio_path.name, audio_stream),
                    model="whisper-large-v3",
                    temperature=0.0,
                    prompt=WHISPER_CONTEXT_PROMPT,
                )
            text = getattr(transcription, "text", "") or ""
            return text.strip()
        except Exception as exc:
            logger.error("[VoiceAssistant] Groq Whisper STT failed: %s", exc, exc_info=True)
            raise AppException(
                title="Speech-to-Text Failed",
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Failed to transcribe audio with Groq Whisper.",
                type_url="https://api.pingo.app/errors/stt-failed",
            ) from exc

    @classmethod
    async def _run_atomic_brain_and_persist(
        cls,
        *,
        tenant: TenantContext,
        modality: str,
        user_said: str,
        staged_items: list[StagedAttachmentItem],
        bundle_meta: list[dict[str, Any]],
        deepseek_key: str,
        base_url: str,
        model_name: str,
        db: AsyncSession,
    ) -> tuple[str, list[ExecutedToolAction], TaskCategory]:
        now_bd = datetime.now(BD_TZ).astimezone(BD_OFFSET)
        client = AsyncOpenAI(api_key=deepseek_key, base_url=base_url)

        user_content = user_said
        if bundle_meta:
            att_names = ", ".join(m["filename"] for m in bundle_meta)
            user_content = f"{user_said}\n[Attached files: {att_names}]"

        messages: list[dict[str, Any]] = [
            {
                "role": "system",
                "content": build_deepseek_system_prompt(now_bd, staged_items),
            },
            {"role": "user", "content": user_content},
        ]

        try:
            response = await client.chat.completions.create(
                model=model_name,
                messages=messages,  # type: ignore[arg-type]
                tools=DEEPSEEK_TOOLS,  # type: ignore[arg-type]
                tool_choice="auto",
                temperature=0.2,
            )
        except Exception as exc:
            logger.error("[VoiceAssistant] DeepSeek processing failed: %s", exc, exc_info=True)
            raise AppException(
                title="AI Brain Processing Failed",
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Failed to process command with DeepSeek.",
                type_url="https://api.pingo.app/errors/deepseek-failed",
            ) from exc

        assistant_msg = response.choices[0].message
        tool_calls = assistant_msg.tool_calls or []

        parsed_tool_Specs: list[tuple[str, str, dict[str, Any]]] = []
        for tc in tool_calls:
            try:
                raw_args = json.loads(tc.function.arguments or "{}")
            except json.JSONDecodeError:
                raw_args = {}
            parsed_tool_Specs.append((tc.id, tc.function.name, raw_args))

        # Execute tool persistence + bundled InboxMessage inside ONE atomic unit of work
        executed_actions: list[ExecutedToolAction] = []
        dominant_category = (
            TaskCategory.DOCUMENT if bundle_meta else infer_category_heuristic(user_said)
        )

        try:
            if parsed_tool_Specs:
                messages.append(assistant_msg.model_dump(exclude_none=True))

                for tc_id, fn_name, raw_args in parsed_tool_Specs:
                    tool_result, action = await cls._persist_tool_action(
                        tenant=tenant,
                        fn_name=fn_name,
                        raw_args=raw_args,
                        bundle_meta=bundle_meta,
                        now_bd=now_bd,
                        db=db,
                    )
                    if action is not None:
                        executed_actions.append(action)
                        dominant_category = action.category

                    messages.append(
                        {
                            "role": "tool",
                            "tool_call_id": tc_id,
                            "content": json.dumps(tool_result, ensure_ascii=False),
                        }
                    )

                followup = await client.chat.completions.create(
                    model=model_name,
                    messages=messages,  # type: ignore[arg-type]
                    temperature=0.3,
                )
                final_reply = (followup.choices[0].message.content or "").strip()
            else:
                final_reply = (assistant_msg.content or "").strip()

            if not final_reply:
                final_reply = "আপনার অনুরোধটি সম্পন্ন হয়েছে।"

            # Persist atomic bundled turn (message + attachment metadata)
            if tenant.is_ephemeral:
                ephemeral_tenant_store.add_record(
                    tenant,
                    kind="message",
                    payload={
                        "modality": modality,
                        "user_text": user_said,
                        "assistant_reply": final_reply,
                        "category": dominant_category.value,
                        "attachments_meta": bundle_meta,
                    },
                )
            else:
                inbox_row = AssistantInboxMessage(
                    tenant_id=tenant.tenant_id,
                    modality=modality,
                    user_text=user_said,
                    assistant_reply=final_reply,
                    category=dominant_category.value,
                    attachments_meta=bundle_meta,
                )
                db.add(inbox_row)
                await db.flush()

            return final_reply, executed_actions, dominant_category
        except AppException:
            if not tenant.is_ephemeral:
                await db.rollback()
            raise
        except Exception as exc:
            if not tenant.is_ephemeral:
                await db.rollback()
            logger.error("[VoiceAssistant] Atomic bundle persistence failed: %s", exc, exc_info=True)
            raise AppException(
                title="AI Brain Processing Failed",
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Failed to complete bundled assistant transaction.",
                type_url="https://api.pingo.app/errors/atomic-bundle-failed",
            ) from exc

    @classmethod
    async def _persist_tool_action(
        cls,
        *,
        tenant: TenantContext,
        fn_name: str,
        raw_args: dict[str, Any],
        bundle_meta: list[dict[str, Any]],
        now_bd: datetime,
        db: AsyncSession,
    ) -> tuple[dict[str, Any], Optional[ExecutedToolAction]]:
        if fn_name == "set_reminder":
            task_title = str(raw_args.get("task_title") or "Reminder").strip()
            raw_time = str(raw_args.get("reminder_time") or "").strip()
            category = coerce_task_category(
                raw_args.get("category"),
                fallback=infer_category_heuristic(task_title),
            )
            due_dt, normalized_iso = normalize_bd_iso8601(raw_time, now_bd)

            # Zero-touch auto-completion: if scheduled time is already at/before now, mark completed immediately
            now_utc = datetime.now(timezone.utc)
            initial_state = (
                TaskLifecycleState.COMPLETED
                if due_dt.astimezone(timezone.utc) <= now_utc
                else TaskLifecycleState.SCHEDULED
            )
            completed_at = now_utc if initial_state == TaskLifecycleState.COMPLETED else None

            if tenant.is_ephemeral:
                rec_id = ephemeral_tenant_store.add_record(
                    tenant,
                    kind="reminder",
                    payload={
                        "task_title": task_title,
                        "category": category.value,
                        "reminder_time": normalized_iso,
                        "state": initial_state.value,
                        "completed_at": completed_at.isoformat() if completed_at else None,
                        "attachments_meta": bundle_meta,
                    },
                )
            else:
                reminder = Reminder(
                    tenant_id=tenant.tenant_id,
                    task_title=task_title,
                    category=category.value,
                    reminder_time=due_dt,
                    state=initial_state.value,
                    completed_at=completed_at,
                    attachments_meta=bundle_meta,
                )
                db.add(reminder)
                await db.flush()
                rec_id = str(reminder.id)

                if tenant.authenticated_user_id is not None:
                    await cls._mirror_to_encrypted_reminders(
                        db=db,
                        user_id=tenant.authenticated_user_id,
                        reminder_id=reminder.id,
                        task_title=task_title,
                        due_dt=due_dt,
                        is_completed=(initial_state == TaskLifecycleState.COMPLETED),
                    )

            normalized_args = {
                "task_title": task_title,
                "reminder_time": normalized_iso,
                "category": category.value,
            }
            action = ExecutedToolAction(
                tool="set_reminder",
                arguments=normalized_args,
                record_id=rec_id,
                category=category,
                lifecycle_state=initial_state,
            )
            return {
                "status": initial_state.value,
                "id": rec_id,
                **normalized_args,
            }, action

        if fn_name == "save_documentation":
            title = str(raw_args.get("title") or "Project Note").strip()
            content = str(raw_args.get("content") or "").strip()
            category = coerce_task_category(
                raw_args.get("category"), fallback=TaskCategory.DOCUMENT
            )

            if tenant.is_ephemeral:
                rec_id = ephemeral_tenant_store.add_record(
                    tenant,
                    kind="documentation",
                    payload={
                        "title": title,
                        "content": content,
                        "category": category.value,
                        "attachments_meta": bundle_meta,
                    },
                )
            else:
                doc = Documentation(
                    tenant_id=tenant.tenant_id,
                    category=category.value,
                    title=title,
                    content=content,
                    attachments_meta=bundle_meta,
                )
                db.add(doc)
                await db.flush()
                rec_id = str(doc.id)

            normalized_args = {
                "title": title,
                "content": content,
                "category": category.value,
            }
            action = ExecutedToolAction(
                tool="save_documentation",
                arguments=normalized_args,
                record_id=rec_id,
                category=category,
            )
            return {"status": "saved", "id": rec_id, "title": title, "category": category.value}, action

        return {"status": "ignored", "reason": f"Deprecated or unknown tool: {fn_name}"}, None

    @classmethod
    async def _mirror_to_encrypted_reminders(
        cls,
        *,
        db: AsyncSession,
        user_id: UUID,
        reminder_id: UUID,
        task_title: str,
        due_dt: datetime,
        is_completed: bool,
    ) -> None:
        res = await db.execute(select(User.id).where(User.id == user_id))
        if res.scalar_one_or_none() is None:
            return

        mirrored = EncryptedReminder(
            id=reminder_id,
            user_id=user_id,
            ciphertext=base64.b64encode(task_title.encode("utf-8")).decode("ascii"),
            iv=base64.b64encode(b"0123456789ab").decode("ascii"),
            auth_tag=base64.b64encode(b"abcdefghijklmnop").decode("ascii"),
            due_at=due_dt.astimezone(timezone.utc),
            is_completed=is_completed,
            notification_sent=is_completed,
            version=1,
        )
        db.add(mirrored)

    @classmethod
    async def _synthesize_bangla_tts(cls, ai_reply: str) -> str:
        clean_speech_text = strip_markdown_for_tts(ai_reply)
        filename = f"{uuid4().hex}.mp3"
        output_path = STATIC_AUDIO_DIR / filename

        try:
            communicate = edge_tts.Communicate(text=clean_speech_text, voice=EDGE_TTS_VOICE)
            await communicate.save(str(output_path))
        except Exception as exc:
            logger.error("[VoiceAssistant] Edge-TTS synthesis failed: %s", exc, exc_info=True)
            raise AppException(
                title="Text-to-Speech Failed",
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Failed to synthesize Bangla speech audio.",
                type_url="https://api.pingo.app/errors/tts-failed",
            ) from exc

        return f"/static/audio/{filename}"
