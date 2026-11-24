from datetime import datetime, timedelta, timezone
import json
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch
from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient

from app.core.security import get_current_user_optional
from app.core.tenant import ephemeral_tenant_store
from app.db.session import get_db
from app.main import app
from app.models.user import PlanTier, User
from app.models.voice_assistant import Reminder, TaskLifecycleState
from app.services.staging_service import attachment_staging_service


@pytest.fixture(autouse=True)
def reset_in_memory_stores():
    ephemeral_tenant_store.clear_all_for_testing()
    attachment_staging_service.clear_all_for_testing()
    app.dependency_overrides.clear()
    yield
    ephemeral_tenant_store.clear_all_for_testing()
    attachment_staging_service.clear_all_for_testing()
    app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_decoupled_attachment_staging_and_atomic_bundled_commit(monkeypatch):
    """Verifies Directive 1:
    1) Uploading an attachment without text/audio stages an uncommitted preview without calling LLM.
    2) Subsequent command bundles the staged attachment metadata atomically and clears staging.
    """
    monkeypatch.setenv("DEEPSEEK_API_KEY", "test-deepseek-key")

    auth_user = User(
        id=uuid4(),
        email="alice@pingo.app",
        password_hash="argon2id$hashed",
        plan_tier=PlanTier.FREE,
        client_salt="salt_alice",
    )
    persisted_db_rows = []

    class FakeSession:
        def add(self, obj):
            if getattr(obj, "id", None) is None:
                obj.id = uuid4()
            persisted_db_rows.append(obj)

        async def flush(self):
            return None

        async def rollback(self):
            persisted_db_rows.clear()

        async def execute(self, _stmt):
            res = MagicMock()
            res.scalar_one_or_none.return_value = None
            return res

    async def override_db():
        yield FakeSession()

    app.dependency_overrides[get_db] = override_db
    app.dependency_overrides[get_current_user_optional] = lambda: auth_user

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        # Step A: Stage image attachment ONLY (no auto-send!)
        stage_resp = await ac.post(
            "/api/attachments/stage",
            files={"attachment": ("prescription.png", b"\x89PNG\r\n\x1a\nFAKEIMAGE", "image/png")},
        )
        assert stage_resp.status_code == 201, stage_resp.text
        stage_body = stage_resp.json()
        assert stage_body["status"] == "staged_preview"
        assert stage_body["tenant_scope"] == "authenticated"
        assert len(stage_body["staged"]) == 1
        staging_id = stage_body["staged"][0]["staging_id"]
        assert stage_body["staged"][0]["state"] == "staged_uncommitted"
        assert len(persisted_db_rows) == 0  # Nothing persisted yet!

        # Step B: Subsequent text command bundles the staged attachment atomically
        tc_rem = SimpleNamespace(
            id="call_rx",
            type="function",
            function=SimpleNamespace(
                name="set_reminder",
                arguments=json.dumps(
                    {
                        "task_title": "Buy prescription medicine",
                        "reminder_time": "2027-12-01T21:00:00+06:00",
                        "category": "MEDICINE",
                    }
                ),
            ),
        )
        msg_1 = MagicMock()
        msg_1.tool_calls = [tc_rem]
        msg_1.content = None
        msg_1.model_dump.return_value = {
            "role": "assistant",
            "tool_calls": [
                {
                    "id": "call_rx",
                    "type": "function",
                    "function": {
                        "name": "set_reminder",
                        "arguments": tc_rem.function.arguments,
                    },
                }
            ],
        }
        msg_2 = SimpleNamespace(
            tool_calls=None,
            content="প্রেসক্রিপশন ফাইলসহ ওষুধ কেনার রিমাইন্ডার সেট করা হয়েছে।",
        )
        fake_openai = MagicMock()
        fake_openai.chat.completions.create = AsyncMock(
            side_effect=[
                SimpleNamespace(choices=[SimpleNamespace(message=msg_1)]),
                SimpleNamespace(choices=[SimpleNamespace(message=msg_2)]),
            ]
        )

        with patch("app.services.voice_assistant_service.AsyncOpenAI", return_value=fake_openai):
            bundle_resp = await ac.post(
                "/api/assistant/message",
                json={
                    "message": "Remind me to buy this prescription medicine on Dec 1 at 9 PM",
                    "staging_ids": [staging_id],
                    "synthesize_tts": False,
                },
            )

        assert bundle_resp.status_code == 200, bundle_resp.text
        bundle_data = bundle_resp.json()
        assert bundle_data["status"] == "completed_turn"
        assert bundle_data["telemetry"]["bundled_attachments_count"] == 1
        assert bundle_data["telemetry"]["classified_category"] == "MEDICINE"
        assert len(bundle_data["bundled_attachments"]) == 1
        assert bundle_data["bundled_attachments"][0]["staging_id"] == staging_id

        # Verify Reminder row atomically received bundled attachment metadata
        saved_rem = next(r for r in persisted_db_rows if isinstance(r, Reminder))
        assert saved_rem.category == "MEDICINE"
        assert len(saved_rem.attachments_meta) == 1
        assert saved_rem.attachments_meta[0]["filename"] == "prescription.png"

        # Step C: Staging inbox for tenant is now empty
        after_staged = await ac.get("/api/attachments/staged")
        assert after_staged.status_code == 200
        assert after_staged.json()["staged"] == []


def test_irreversible_reminder_lifecycle_guard():
    """Verifies Directive 2: Reminder transitions strictly scheduled -> completed and cannot revert."""
    rem = Reminder(
        tenant_id="user:123",
        task_title="Pay utility bill",
        category="BILL",
        reminder_time=datetime.now(timezone.utc) + timedelta(hours=2),
        state=TaskLifecycleState.SCHEDULED.value,
    )
    assert rem.state == "scheduled"
    assert rem.completed_at is None

    rem.mark_completed()
    assert rem.state == "completed"
    assert rem.completed_at is not None

    with pytest.raises(ValueError, match="Irreversible lifecycle violation"):
        rem.state = TaskLifecycleState.SCHEDULED.value


@pytest.mark.asyncio
async def test_strict_tenant_and_ephemeral_session_isolation(monkeypatch):
    """Verifies Directive 4:
    - Unauthenticated sessions write ONLY to segregated EphemeralTenantStore (zero DB rows).
    - Session A cannot see or claim Session B's staged attachments or reminders.
    - Authenticated user cannot spoof another user's UUID in form `user_id` (403 Forbidden).
    """
    monkeypatch.setenv("DEEPSEEK_API_KEY", "test-deepseek-key")

    db_writes = []

    class ZeroTouchDBSession:
        def add(self, obj):
            db_writes.append(obj)

        async def flush(self):
            return None

        async def rollback(self):
            return None

    async def override_db():
        yield ZeroTouchDBSession()

    app.dependency_overrides[get_db] = override_db

    tc_rem = SimpleNamespace(
        id="call_ephem",
        type="function",
        function=SimpleNamespace(
            name="set_reminder",
            arguments=json.dumps(
                {
                    "task_title": "Past due ephemeral task",
                    "reminder_time": "2020-01-01T10:00:00+06:00",
                    "category": "PERSONAL",
                }
            ),
        ),
    )
    msg_1 = MagicMock()
    msg_1.tool_calls = [tc_rem]
    msg_1.content = None
    msg_1.model_dump.return_value = {
        "role": "assistant",
        "tool_calls": [
            {
                "id": "call_ephem",
                "type": "function",
                "function": {
                    "name": "set_reminder",
                    "arguments": tc_rem.function.arguments,
                },
            }
        ],
    }
    msg_2 = SimpleNamespace(tool_calls=None, content="রিমাইন্ডার সম্পন্ন হয়েছে।")
    fake_openai = MagicMock()
    fake_openai.chat.completions.create = AsyncMock(
        side_effect=[
            SimpleNamespace(choices=[SimpleNamespace(message=msg_1)]),
            SimpleNamespace(choices=[SimpleNamespace(message=msg_2)]),
        ]
    )

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        # 1. Unauthenticated Session A stages an attachment and creates a due reminder
        s_resp = await ac.post(
            "/api/attachments/stage",
            headers={"X-Session-ID": "anon_session_alpha"},
            files={"attachment": ("note.txt", b"ephemeral secret", "text/plain")},
        )
        assert s_resp.status_code == 201
        alpha_staging_id = s_resp.json()["staged"][0]["staging_id"]

        # 2. Unauthenticated Session B tries to claim Session A's staging_id -> 404 Not Found
        with patch("app.services.voice_assistant_service.AsyncOpenAI", return_value=fake_openai):
            cross_claim = await ac.post(
                "/api/assistant/message",
                headers={"X-Session-ID": "anon_session_beta"},
                json={
                    "message": "Steal attachment",
                    "staging_ids": [alpha_staging_id],
                    "synthesize_tts": False,
                },
            )
        assert cross_claim.status_code == 404

        # 3. Session A executes its own turn -> writes to ephemeral store, ZERO PostgreSQL rows!
        with patch("app.services.voice_assistant_service.AsyncOpenAI", return_value=fake_openai):
            ok_resp = await ac.post(
                "/api/assistant/message",
                headers={"X-Session-ID": "anon_session_alpha"},
                json={
                    "message": "Set reminder",
                    "staging_ids": [alpha_staging_id],
                    "synthesize_tts": False,
                },
            )
        assert ok_resp.status_code == 200
        assert ok_resp.json()["telemetry"]["tenant_scope"] == "ephemeral"
        # Past-due reminder auto-completed immediately via zero-touch lifecycle!
        assert ok_resp.json()["actions"][0]["lifecycle_state"] == "completed"
        assert len(db_writes) == 0

        # 4. Session B lists reminders -> sees [], while Session A sees its 1 completed reminder
        beta_list = await ac.get(
            "/api/assistant/reminders",
            headers={"X-Session-ID": "anon_session_beta"},
        )
        alpha_list = await ac.get(
            "/api/assistant/reminders",
            headers={"X-Session-ID": "anon_session_alpha"},
        )
        assert beta_list.json() == []
        assert len(alpha_list.json()) == 1
        assert alpha_list.json()[0]["state"] == "completed"

        # 5. Authenticated user spoofing another tenant's UUID in form `user_id` -> 403 Forbidden
        auth_user = User(
            id=uuid4(),
            email="real_tenant@pingo.app",
            password_hash="argon2id$hashed",
            plan_tier=PlanTier.FREE,
            client_salt="salt",
        )
        app.dependency_overrides[get_current_user_optional] = lambda: auth_user
        spoof_resp = await ac.post(
            "/api/attachments/stage",
            data={"user_id": str(uuid4())},
            files={"attachment": ("doc.txt", b"hello", "text/plain")},
        )
        assert spoof_resp.status_code == 403
