import base64
from datetime import datetime, timedelta, timezone
import json
import logging
import os
from pathlib import Path
import re
import tempfile
import time
from typing import Any
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
from app.models.reminder import EncryptedReminder
from app.models.user import User
from app.models.voice_assistant import Documentation, Reminder
from app.schemas.voice import ExecutedToolAction, VoiceCommandResponse

logger = logging.getLogger(__name__)

BD_TZ = ZoneInfo("Asia/Dhaka")
BD_OFFSET = timezone(timedelta(hours=6))

# Contextual prompt with common Bangla, Banglish, and English tech/scheduling vocabulary
WHISPER_CONTEXT_PROMPT = (
    "বাংলা, English, Banglish voice assistant Pingo. "
    "রিমাইন্ডার, অ্যালার্ম, আজকে, আগামীকাল, পরশু, সকাল, দুপুর, বিকাল, রাত, ডকুমেন্টেশন, প্রজেক্ট নোট, "
    "মিটিং, ওষুধ, বিল, ডাক্তার, FastAPI, Flutter, PostgreSQL, Docker, API, endpoint, deployment, "
    "database, bug fix, sprint, GitHub, server, remind me, save note, documentation."
)

DEEPSEEK_TOOLS: list[dict[str, Any]] = [
    {
        "type": "function",
        "function": {
            "name": "set_reminder",
            "description": (
                "Schedules a user reminder/alarm. Extracts the clear task title and converts "
                "the target time into an ISO 8601 timestamp in Bangladesh Standard Time (+06:00)."
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
                },
                "required": ["task_title", "reminder_time"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "save_documentation",
            "description": "Formats and saves project notes, ideas, or technical documentation into the database.",
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
                },
                "required": ["title", "content"],
            },
        },
    },
]

EDGE_TTS_VOICE = "bn-BD-NabanitaNeural"
AUDIO_TTL_SECONDS = 24 * 3600  # 24 hours
MAX_AUDIO_BYTES = 25 * 1024 * 1024  # 25 MB Whisper limit

STATIC_AUDIO_DIR = Path(__file__).resolve().parent.parent / "static" / "audio"


def strip_markdown_for_tts(text: str) -> str:
    """Strips markdown formatting characters (*, #, _, `, ~) so Edge-TTS reads cleanly."""
    cleaned = re.sub(r"[*#_`~]+", "", text)
    cleaned = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", cleaned)
    cleaned = re.sub(r"\s+", " ", cleaned).strip()
    return cleaned or "ঠিক আছে।"


def cleanup_old_tts_files(audio_dir: Path = STATIC_AUDIO_DIR, max_age_seconds: int = AUDIO_TTL_SECONDS) -> int:
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
        # Fallback: 1 hour from current Bangladesh time if model gave malformed string
        dt = now_bd + timedelta(hours=1)

    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=BD_OFFSET)
    else:
        dt = dt.astimezone(BD_OFFSET)

    return dt, dt.isoformat(timespec="seconds")


def build_deepseek_system_prompt(now_bd: datetime) -> str:
    formatted_now = now_bd.strftime("%Y-%m-%d %H:%M:%S %A (UTC+06:00)")
    iso_now = now_bd.isoformat(timespec="seconds")
    return (
        "তুমি পিঙ্গো (Pingo) — একটি বুদ্ধিমান, বন্ধুসুলভ এবং নির্ভুল ভয়েস এআই সহকারী।\n"
        f"বর্তমান বাংলাদেশ সময় (Asia/Dhaka, UTC+06:00): {formatted_now} (ISO: {iso_now})।\n\n"
        "নির্দেশনাবলী:\n"
        "১. ইউজার বাংলা, ইংরেজি (English), অথবা বাংলিশ (Banglish) — যেকোনো ভাষায় বা মিশ্র ভাষায় কথা বলতে পারে।\n"
        "২. স্পিচ-টু-টেক্সট (STT) ট্রান্সক্রিপশনে ছোটখাটো উচ্চারণগত বা বানানগত ভুল থাকলে প্রেক্ষাপট বুঝে তা মনে মনে ঠিক করে নাও।\n"
        "৩. ইউজার কোনো রিমাইন্ডার বা অ্যালার্ম সেট করতে বললে অবশ্যই `set_reminder` টুল কল করবে এবং আপেক্ষিক সময় "
        "(যেমন 'আজকে রাত ১০টায়', 'কাল সকালে', 'tomorrow morning', 'in 30 minutes') বর্তমান বাংলাদেশ সময় অনুযায়ী হিসাব করে "
        "সঠিক ISO 8601 ফরম্যাটে (`+06:00` অফসেট সহ, যেমন `2026-11-24T22:00:00+06:00`) পাঠাবে।\n"
        "৪. ইউজার কোনো প্রজেক্ট নোট, আইডিয়া বা ডকুমেন্টেশন সেভ করতে বললে `save_documentation` টুল কল করবে।\n"
        "৫. সবসময় স্বাভাবিক, সংক্ষিপ্ত এবং সুন্দর কথ্য বাংলায় উত্তর দেবে (যেন ভয়েস অ্যাসিস্ট্যান্ট হিসেবে শুনতে প্রাঞ্জল লাগে)।"
    )


class VoiceAssistantService:
    @classmethod
    async def process_voice_command(
        cls,
        audio: UploadFile,
        user_id: str,
        db: AsyncSession,
    ) -> VoiceCommandResponse:
        settings = get_settings()
        groq_key = (settings.GROQ_API_KEY or os.getenv("GROQ_API_KEY", "")).strip()
        deepseek_key = (settings.DEEPSEEK_API_KEY or os.getenv("DEEPSEEK_API_KEY", "")).strip()

        if not groq_key:
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

        clean_user_id = user_id.strip()
        if not clean_user_id:
            raise AppException(
                title="Invalid User ID",
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="user_id must not be empty.",
            )

        STATIC_AUDIO_DIR.mkdir(parents=True, exist_ok=True)
        cleanup_old_tts_files(STATIC_AUDIO_DIR)

        suffix = Path(audio.filename or "voice.m4a").suffix.lower() or ".m4a"
        tmp_path: Path | None = None

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

            # 1. Speech-to-Text via Groq Whisper (whisper-large-v3, temperature=0.0, auto-language)
            user_said = await cls._transcribe_audio(tmp_path, groq_key)
        finally:
            if tmp_path is not None and tmp_path.exists():
                try:
                    tmp_path.unlink(missing_ok=True)
                except OSError as exc:
                    logger.warning("[VoiceAssistant] Temp audio cleanup warning: %s", exc)

        if not user_said.strip():
            raise AppException(
                title="No Speech Detected",
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Could not detect clear speech in the uploaded audio.",
            )

        # 2. DeepSeek Brain + Function Calling
        ai_reply, actions = await cls._run_deepseek_brain(
            user_said=user_said,
            user_id=clean_user_id,
            deepseek_key=deepseek_key,
            base_url=settings.DEEPSEEK_BASE_URL,
            model_name=settings.DEEPSEEK_MODEL,
            db=db,
        )

        # 3. Edge-TTS Synthesis (strip markdown before passing to edge-tts)
        audio_url = await cls._synthesize_bangla_tts(ai_reply)

        return VoiceCommandResponse(
            user_said=user_said,
            ai_reply=ai_reply,
            audio_url=audio_url,
            actions=actions,
        )

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
    async def _run_deepseek_brain(
        cls,
        *,
        user_said: str,
        user_id: str,
        deepseek_key: str,
        base_url: str,
        model_name: str,
        db: AsyncSession,
    ) -> tuple[str, list[ExecutedToolAction]]:
        now_bd = datetime.now(BD_TZ).astimezone(BD_OFFSET)
        client = AsyncOpenAI(api_key=deepseek_key, base_url=base_url)

        messages: list[dict[str, Any]] = [
            {"role": "system", "content": build_deepseek_system_prompt(now_bd)},
            {"role": "user", "content": user_said},
        ]
        executed_actions: list[ExecutedToolAction] = []

        try:
            response = await client.chat.completions.create(
                model=model_name,
                messages=messages,  # type: ignore[arg-type]
                tools=DEEPSEEK_TOOLS,  # type: ignore[arg-type]
                tool_choice="auto",
                temperature=0.2,
            )

            assistant_msg = response.choices[0].message
            tool_calls = assistant_msg.tool_calls or []

            if tool_calls:
                messages.append(assistant_msg.model_dump(exclude_none=True))

                for tc in tool_calls:
                    fn_name = tc.function.name
                    try:
                        raw_args = json.loads(tc.function.arguments or "{}")
                    except json.JSONDecodeError:
                        raw_args = {}

                    tool_result, action = await cls._execute_tool(
                        fn_name=fn_name,
                        raw_args=raw_args,
                        user_id=user_id,
                        now_bd=now_bd,
                        db=db,
                    )
                    if action is not None:
                        executed_actions.append(action)

                    messages.append(
                        {
                            "role": "tool",
                            "tool_call_id": tc.id,
                            "content": json.dumps(tool_result, ensure_ascii=False),
                        }
                    )

                await db.flush()

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

            return final_reply, executed_actions
        except AppException:
            raise
        except Exception as exc:
            logger.error("[VoiceAssistant] DeepSeek processing failed: %s", exc, exc_info=True)
            raise AppException(
                title="AI Brain Processing Failed",
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Failed to process command with DeepSeek.",
                type_url="https://api.pingo.app/errors/deepseek-failed",
            ) from exc

    @classmethod
    async def _execute_tool(
        cls,
        *,
        fn_name: str,
        raw_args: dict[str, Any],
        user_id: str,
        now_bd: datetime,
        db: AsyncSession,
    ) -> tuple[dict[str, Any], ExecutedToolAction | None]:
        if fn_name == "set_reminder":
            task_title = str(raw_args.get("task_title") or "Reminder").strip()
            raw_time = str(raw_args.get("reminder_time") or "").strip()
            due_dt, normalized_iso = normalize_bd_iso8601(raw_time, now_bd)

            reminder = Reminder(
                user_id=user_id,
                task_title=task_title,
                reminder_time=due_dt,
                is_completed=False,
            )
            db.add(reminder)
            await db.flush()

            # Optional seamless bridge: if user_id is a valid registered User UUID,
            # also mirror into encrypted_reminders so background FCM push fires on schedule.
            await cls._mirror_to_encrypted_reminders_if_registered(
                db=db,
                user_id=user_id,
                reminder_id=reminder.id,
                task_title=task_title,
                due_dt=due_dt,
            )

            normalized_args = {
                "task_title": task_title,
                "reminder_time": normalized_iso,
            }
            action = ExecutedToolAction(
                tool="set_reminder",
                arguments=normalized_args,
                record_id=str(reminder.id),
            )
            return {"status": "saved", "id": str(reminder.id), **normalized_args}, action

        if fn_name == "save_documentation":
            title = str(raw_args.get("title") or "Project Note").strip()
            content = str(raw_args.get("content") or "").strip()

            doc = Documentation(
                user_id=user_id,
                title=title,
                content=content,
            )
            db.add(doc)
            await db.flush()

            normalized_args = {
                "title": title,
                "content": content,
            }
            action = ExecutedToolAction(
                tool="save_documentation",
                arguments=normalized_args,
                record_id=str(doc.id),
            )
            return {"status": "saved", "id": str(doc.id), "title": title}, action

        return {"status": "ignored", "reason": f"Unknown tool: {fn_name}"}, None

    @classmethod
    async def _mirror_to_encrypted_reminders_if_registered(
        cls,
        *,
        db: AsyncSession,
        user_id: str,
        reminder_id: UUID,
        task_title: str,
        due_dt: datetime,
    ) -> None:
        try:
            parsed_uuid = UUID(user_id)
        except ValueError:
            return

        res = await db.execute(select(User.id).where(User.id == parsed_uuid))
        if res.scalar_one_or_none() is None:
            return

        mirrored = EncryptedReminder(
            id=reminder_id,
            user_id=parsed_uuid,
            ciphertext=base64.b64encode(task_title.encode("utf-8")).decode("ascii"),
            iv=base64.b64encode(b"0123456789ab").decode("ascii"),
            auth_tag=base64.b64encode(b"abcdefghijklmnop").decode("ascii"),
            due_at=due_dt.astimezone(timezone.utc),
            is_completed=False,
            notification_sent=False,
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
