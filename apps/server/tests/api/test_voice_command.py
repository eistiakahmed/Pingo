from datetime import datetime
import json
import os
import time
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch
from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient

from app.core.security import get_current_user_optional
from app.db.session import get_db
from app.main import app
from app.models.user import PlanTier, User
from app.models.voice_assistant import AssistantInboxMessage, Documentation, Reminder
from app.services.voice_assistant_service import (
    STATIC_AUDIO_DIR,
    cleanup_old_tts_files,
    normalize_bd_iso8601,
    strip_markdown_for_tts,
)


def test_strip_markdown_for_tts_removes_formatting_symbols():
    raw = "**আজকে** রাত *১০টায়* `#মিটিং` এবং _ডকুমেন্টেশন_ [লিংক](https://example.com) সেভ হয়েছে!"
    cleaned = strip_markdown_for_tts(raw)
    assert "*" not in cleaned
    assert "#" not in cleaned
    assert "_" not in cleaned
    assert "`" not in cleaned
    assert "আজকে রাত ১০টায় মিটিং এবং ডকুমেন্টেশন লিংক সেভ হয়েছে!" == cleaned


def test_cleanup_old_tts_files_deletes_only_expired_mp3(tmp_path):
    stale = tmp_path / "old.mp3"
    fresh = tmp_path / "fresh.mp3"
    stale.write_bytes(b"old-mp3")
    fresh.write_bytes(b"fresh-mp3")

    two_days_ago = time.time() - (48 * 3600)
    os.utime(stale, (two_days_ago, two_days_ago))

    deleted = cleanup_old_tts_files(audio_dir=tmp_path, max_age_seconds=24 * 3600)
    assert deleted == 1
    assert not stale.exists()
    assert fresh.exists()


def test_normalize_bd_iso8601_preserves_plus_06_offset():
    now_bd = datetime.fromisoformat("2026-11-24T18:30:00+06:00")
    dt, iso_str = normalize_bd_iso8601("2026-11-24T22:00:00+06:00", now_bd)
    assert iso_str == "2026-11-24T22:00:00+06:00"
    assert dt.utcoffset().total_seconds() == 6 * 3600


@pytest.mark.asyncio
async def test_voice_command_authenticated_tenant_persists_streamlined_records_and_serves_audio(monkeypatch):
    monkeypatch.setenv("GROQ_API_KEY", "test-groq-key")
    monkeypatch.setenv("DEEPSEEK_API_KEY", "test-deepseek-key")

    auth_user = User(
        id=uuid4(),
        email="tenant_owner@pingo.app",
        password_hash="argon2id$hashed",
        plan_tier=PlanTier.PRO,
        client_salt="salt_tenant_1",
    )

    added_records = []

    class FakeSession:
        def add(self, obj):
            if getattr(obj, "id", None) is None:
                obj.id = uuid4()
            added_records.append(obj)

        async def flush(self):
            return None

        async def rollback(self):
            return None

        async def execute(self, _stmt):
            res = MagicMock()
            res.scalar_one_or_none.return_value = None
            return res

    async def override_get_db():
        yield FakeSession()

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_current_user_optional] = lambda: auth_user

    fake_groq_instance = MagicMock()
    fake_groq_instance.audio.transcriptions.create = AsyncMock(
        return_value=SimpleNamespace(
            text="আগামীকাল রাত ১০টায় সার্ভার ডিপ্লয়মেন্টের রিমাইন্ডার সেট করো আর FastAPI নোট সেভ করো"
        )
    )

    tc_reminder = SimpleNamespace(
        id="call_1",
        type="function",
        function=SimpleNamespace(
            name="set_reminder",
            arguments=json.dumps(
                {
                    "task_title": "Server Deployment",
                    "reminder_time": "2027-11-25T22:00:00+06:00",
                    "category": "WORK",
                }
            ),
        ),
    )
    tc_doc = SimpleNamespace(
        id="call_2",
        type="function",
        function=SimpleNamespace(
            name="save_documentation",
            arguments=json.dumps(
                {
                    "title": "FastAPI Architecture Note",
                    "content": "Voice pipeline integrated with Groq Whisper and DeepSeek.",
                    "category": "DOCUMENT",
                }
            ),
        ),
    )

    first_msg = MagicMock()
    first_msg.tool_calls = [tc_reminder, tc_doc]
    first_msg.content = None
    first_msg.model_dump.return_value = {
        "role": "assistant",
        "tool_calls": [
            {
                "id": "call_1",
                "type": "function",
                "function": {
                    "name": "set_reminder",
                    "arguments": tc_reminder.function.arguments,
                },
            },
            {
                "id": "call_2",
                "type": "function",
                "function": {
                    "name": "save_documentation",
                    "arguments": tc_doc.function.arguments,
                },
            },
        ],
    }

    second_msg = SimpleNamespace(
        tool_calls=None,
        content="**ঠিক আছে!** আগামীকাল রাত ১০টায় _Server Deployment_ রিমাইন্ডার এবং #FastAPI নোট সেভ করা হয়েছে।",
    )

    fake_openai_instance = MagicMock()
    fake_openai_instance.chat.completions.create = AsyncMock(
        side_effect=[
            SimpleNamespace(choices=[SimpleNamespace(message=first_msg)]),
            SimpleNamespace(choices=[SimpleNamespace(message=second_msg)]),
        ]
    )

    tts_captured = {}

    class FakeCommunicate:
        def __init__(self, text: str, voice: str):
            tts_captured["text"] = text
            tts_captured["voice"] = voice

        async def save(self, out_path: str):
            with open(out_path, "wb") as f:
                f.write(b"ID3-FAKE-BANGLA-MP3-DATA")

    created_mp3_path = None
    try:
        with (
            patch("app.services.voice_assistant_service.AsyncGroq", return_value=fake_groq_instance),
            patch("app.services.voice_assistant_service.AsyncOpenAI", return_value=fake_openai_instance) as mock_openai_cls,
            patch("app.services.voice_assistant_service.edge_tts.Communicate", FakeCommunicate),
        ):
            async with AsyncClient(
                transport=ASGITransport(app=app), base_url="http://test"
            ) as ac:
                resp = await ac.post(
                    "/api/voice-command",
                    data={"user_id": str(auth_user.id)},
                    files={"audio": ("voice_note.m4a", b"fake-m4a-audio-bytes", "audio/mp4")},
                )

                assert resp.status_code == 200, resp.text
                body = resp.json()

                assert body["status"] == "completed_turn"
                assert body["telemetry"]["tenant_scope"] == "authenticated"
                assert "সার্ভার ডিপ্লয়মেন্টের" in body["user_said"]
                assert body["audio_url"].startswith("/static/audio/")
                assert len(body["actions"]) == 2

                assert body["actions"][0]["tool"] == "set_reminder"
                assert body["actions"][0]["category"] == "WORK"
                assert body["actions"][0]["lifecycle_state"] == "scheduled"
                assert body["actions"][1]["tool"] == "save_documentation"
                assert body["actions"][1]["category"] == "DOCUMENT"

                whisper_kwargs = fake_groq_instance.audio.transcriptions.create.call_args.kwargs
                assert whisper_kwargs["model"] == "whisper-large-v3"
                assert whisper_kwargs["temperature"] == 0.0
                assert "language" not in whisper_kwargs

                mock_openai_cls.assert_called_once_with(
                    api_key="test-deepseek-key", base_url="https://api.deepseek.com"
                )

                assert tts_captured["voice"] == "bn-BD-NabanitaNeural"
                assert "*" not in tts_captured["text"]
                assert "_" not in tts_captured["text"]
                assert "#" not in tts_captured["text"]

                expected_tenant = f"user:{auth_user.id}"
                assert any(
                    isinstance(r, Reminder)
                    and r.tenant_id == expected_tenant
                    and r.state == "scheduled"
                    and r.category == "WORK"
                    for r in added_records
                )
                assert any(
                    isinstance(r, Documentation)
                    and r.tenant_id == expected_tenant
                    and r.title == "FastAPI Architecture Note"
                    for r in added_records
                )
                assert any(
                    isinstance(r, AssistantInboxMessage)
                    and r.tenant_id == expected_tenant
                    for r in added_records
                )

                audio_resp = await ac.get(body["audio_url"])
                assert audio_resp.status_code == 200
                assert audio_resp.content == b"ID3-FAKE-BANGLA-MP3-DATA"

                created_mp3_path = STATIC_AUDIO_DIR / body["audio_url"].split("/")[-1]
    finally:
        app.dependency_overrides.clear()
        if created_mp3_path and created_mp3_path.exists():
            created_mp3_path.unlink(missing_ok=True)
