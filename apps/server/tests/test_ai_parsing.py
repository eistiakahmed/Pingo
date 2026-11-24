"""Pingo AI parsing eval (Part 2.6).

Offline contract tests ALWAYS run: prompt rules, schema validation, few-shot
coverage, deterministic resolver behaviour, and the no-key guard.

Live parser tests run the real Anthropic provider against 24 sample messages
(Bangla / English / Banglish) with a FIXED reference time so expectations are
deterministic. They are skipped unless ANTHROPIC_API_KEY is set:

    ANTHROPIC_API_KEY=sk-ant-... pytest tests/test_ai_parsing.py -v

Reference time for all cases: 2026-11-18 21:30 Asia/Dhaka (after 17:00 and
21:00, so the "past time → tomorrow" rule is exercised).
"""
import json
import os
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

import pytest

from app.core.exceptions import AppException
from app.schemas.ai import ParseIntent, ParsedReminderData
from app.services.ai_service import (
    PARSING_JSON_SCHEMA,
    PARSER_SYSTEM_PROMPT,
    AIService,
    resolve_due_at,
)

REF_TZ = "Asia/Dhaka"
REF_LOCAL = datetime(2026, 11, 18, 21, 30, tzinfo=ZoneInfo(REF_TZ))

# ───────────────────────── The 24-case eval set ─────────────────────────
# Each case: text, intent, and (for create) expected local date offset from
# the reference date + expected HH:MM (tolerance in minutes for relative
# times). title_contains asserts the user's words are kept verbatim.

CASES = [
    # ── English ──
    {"id": "en-relative-5min", "text": "set a reminder in five minutes",
     "intent": "create_reminder", "day_offset": 0, "time": "21:35", "tol": 3},
    {"id": "en-alarm-1027pm", "text": "set an alarm 10:27 PM today",
     "intent": "create_reminder", "day_offset": 0, "time": "22:27"},
    {"id": "en-tomorrow-time", "text": "remind me to water the plants tomorrow at 7:30 am",
     "intent": "create_reminder", "day_offset": 1, "time": "07:30",
     "title_contains": "water the plants"},
    {"id": "en-tomorrow-notime", "text": "pay electricity bill tomorrow",
     "intent": "create_reminder", "day_offset": 1, "time": "09:00",
     "title_contains": "electricity bill"},
    {"id": "en-tonight", "text": "meds tonight",
     "intent": "create_reminder", "day_offset": 0, "time": "20:00"},
    {"id": "en-past-time-rolls", "text": "team standup at 10am",
     "intent": "create_reminder", "day_offset": 1, "time": "10:00"},
    {"id": "en-list", "text": "what are my reminders for today?",
     "intent": "list_reminders"},
    {"id": "en-delete", "text": "delete my electricity bill reminder",
     "intent": "delete_reminder", "title_contains": "electricity"},
    {"id": "en-chat", "text": "hey thanks, you are great",
     "intent": "chat"},
    {"id": "en-unclear-asks", "text": "remind me sometime to call mom",
     "intent": "create_reminder", "expect_clarifying": True},

    # ── Bangla ──
    {"id": "bn-tomorrow-8am", "text": "কাল সকাল ৮টায় ওষুধ কিনতে হবে",
     "intent": "create_reminder", "day_offset": 1, "time": "08:00"},
    {"id": "bn-today-10pm", "text": "আজ রাত ১০টায় ঘুমানোর ওষুধ",
     "intent": "create_reminder", "day_offset": 0, "time": "22:00"},
    {"id": "bn-dayafter-bank", "text": "পরশু দুপুর ২টায় ব্যাংকে যাব",
     "intent": "create_reminder", "day_offset": 2, "time": "14:00"},
    {"id": "bn-past-bikel-rolls", "text": "বিকাল ৫টায় মায়ের সাথে ডাক্তার",
     "intent": "create_reminder", "day_offset": 1, "time": "17:00"},
    {"id": "bn-tomorrow-fajr", "text": "কাল ভোর ৬টায় ফজরের নামাজ",
     "intent": "create_reminder", "day_offset": 1, "time": "06:00"},
    {"id": "bn-list", "text": "আজকের কাজগুলো দেখাও",
     "intent": "list_reminders"},
    {"id": "bn-chat", "text": "কেমন আছো?",
     "intent": "chat"},

    # ── Banglish ──
    {"id": "bl-kal-bikel-5tay", "text": "kal bikel 5tay mayer sathe doctor",
     "intent": "create_reminder", "day_offset": 1, "time": "17:00",
     "title_contains": "mayer sathe doctor"},
    {"id": "bl-kalke-sokal-9", "text": "kalke sokal 9 tay garor dawai",
     "intent": "create_reminder", "day_offset": 1, "time": "09:00",
     "title_contains": "garor dawai"},
    {"id": "bl-ajke-raat-8", "text": "ajke raat 8tay bati bondho korbo",
     "intent": "create_reminder", "day_offset": 0, "time": "20:00"},
    {"id": "bl-relative-5min", "text": "5 minute por ekta reminder dao",
     "intent": "create_reminder", "day_offset": 0, "time": "21:35", "tol": 3},
    {"id": "bl-list", "text": "ajke amar kaj ki ki ache",
     "intent": "list_reminders"},
    {"id": "bl-alarm-kal-7", "text": "ekta alarm set koro kal sokal 7tay",
     "intent": "create_reminder", "day_offset": 1, "time": "07:00"},
    {"id": "bl-update", "text": "doctor er reminder ta kal bikel 6tay kore dao",
     "intent": "update_reminder", "day_offset": 1, "time": "18:00"},
]


# ───────────────────────── Offline contract tests ─────────────────────────


def test_prompt_contains_all_rules():
    for fragment in [
        "Autonomously classify",
        "Banglish",
        "current local date",
        "use tomorrow",
        "neutral title",
        "clarifying question",
        "create_reminder",
        "deprecated",
    ]:
        assert fragment.lower() in PARSER_SYSTEM_PROMPT.lower(), fragment


def test_prompt_has_at_least_eight_examples():
    user_lines = [l for l in PARSER_SYSTEM_PROMPT.splitlines() if l.startswith("User:")]
    json_lines = [l for l in PARSER_SYSTEM_PROMPT.splitlines() if l.startswith("JSON:")]
    assert len(user_lines) >= 8
    assert len(user_lines) == len(json_lines)


def test_schema_is_strict_and_complete():
    props = set(PARSING_JSON_SCHEMA["properties"])
    assert props == {
        "intent", "title", "date", "time", "category", "priority", "clarifying_question", "confidence",
    }
    assert set(PARSING_JSON_SCHEMA["required"]) == props
    assert PARSING_JSON_SCHEMA["additionalProperties"] is False
    assert set(PARSING_JSON_SCHEMA["properties"]["intent"]["enum"]) == {
        "create_reminder", "list_reminders", "save_documentation", "chat",
    }


def test_every_prompt_example_validates_against_response_schema():
    """Each few-shot JSON line must validate through the real Pydantic model."""
    for line in PARSER_SYSTEM_PROMPT.splitlines():
        if line.startswith("JSON:"):
            payload = json.loads(line[len("JSON:"):].strip())
            data = ParsedReminderData(**payload)
            assert data.intent in ParseIntent


def test_resolver_date_and_time():
    due = resolve_due_at("2026-11-19", "07:30", REF_TZ, REF_LOCAL)
    assert due is not None
    local = due.astimezone(ZoneInfo(REF_TZ))
    assert (local.year, local.month, local.day) == (2026, 11, 19)
    assert (local.hour, local.minute) == (7, 30)


def test_resolver_date_only_defaults_0900():
    due = resolve_due_at("2026-11-19", None, REF_TZ, REF_LOCAL)
    local = due.astimezone(ZoneInfo(REF_TZ))
    assert (local.hour, local.minute) == (9, 0)


def test_resolver_time_only_past_rolls_to_tomorrow():
    # 22:27 is still ahead of 21:30 → today
    due = resolve_due_at(None, "22:27", REF_TZ, REF_LOCAL)
    local = due.astimezone(ZoneInfo(REF_TZ))
    assert local.day == 18
    # 17:00 already passed → tomorrow
    due = resolve_due_at(None, "17:00", REF_TZ, REF_LOCAL)
    local = due.astimezone(ZoneInfo(REF_TZ))
    assert local.day == 19


def test_resolver_nothing_returns_none():
    assert resolve_due_at(None, None, REF_TZ, REF_LOCAL) is None


def test_resolver_bad_timezone_falls_back_utc():
    due = resolve_due_at(None, "22:27", "Not/AZone", REF_LOCAL)
    assert due is not None


def test_anthropic_provider_requires_key(monkeypatch):
    monkeypatch.setenv("AI_PROVIDER", "anthropic")
    monkeypatch.setenv("ANTHROPIC_API_KEY", "")
    from app.core import config
    config.get_settings.cache_clear()
    req = _make_request("set a reminder tomorrow at 5pm")
    with pytest.raises(AppException) as exc:
        import asyncio
        asyncio.run(AIService.parse_reminder(req))
    assert exc.value.status_code == 503
    config.get_settings.cache_clear()


def _make_request(text: str):
    from app.schemas.ai import ParseReminderRequest
    return ParseReminderRequest(
        text=text, timezone=REF_TZ, reference_date=REF_LOCAL
    )


# ───────────────────────── Live parser eval ─────────────────────────


def _live_provider_and_key():
    """Returns (provider, key) for the actively configured AI provider."""
    from app.core.config import get_settings
    settings = get_settings()
    provider = settings.AI_PROVIDER.lower().strip()
    keys = {
        "deepseek": settings.DEEPSEEK_API_KEY,
        "anthropic": settings.ANTHROPIC_API_KEY,
    }
    return provider, keys.get(provider, "").strip()


def _check_case(case, parsed: ParsedReminderData):
    failures = []

    if parsed.intent.value != case["intent"]:
        failures.append(
            f"intent: expected {case['intent']}, got {parsed.intent.value}"
        )

    if case.get("expect_clarifying"):
        if parsed.clarifying_question is None:
            failures.append("expected a clarifying question, got none")

    if "day_offset" in case:
        if parsed.due_at is None:
            failures.append("due_at is None but a time was expected")
        else:
            local = parsed.due_at.astimezone(ZoneInfo(REF_TZ))
            expected_day = REF_LOCAL.date() + timedelta(days=case["day_offset"])
            if local.date() != expected_day:
                failures.append(
                    f"date: expected {expected_day}, got {local.date()}"
                )
            expected_h, expected_m = map(int, case["time"].split(":"))
            expected_min = expected_h * 60 + expected_m
            actual_min = local.hour * 60 + local.minute
            tol = case.get("tol", 0)
            if abs(actual_min - expected_min) > tol:
                failures.append(
                    f"time: expected ~{case['time']}, got {local.strftime('%H:%M')}"
                )

    if "title_contains" in case:
        got = (parsed.title or "").casefold()
        if case["title_contains"].casefold() not in got:
            failures.append(
                f"title: expected to contain {case['title_contains']!r}, got {parsed.title!r}"
            )

    return failures


_LIVE_PROVIDER, _LIVE_KEY = _live_provider_and_key()

_LIVE_SKIP_REASON = (
    f"live eval skipped: AI_PROVIDER='{_LIVE_PROVIDER}' has no API key — "
    f"set DEEPSEEK_API_KEY (or ANTHROPIC_API_KEY with AI_PROVIDER=anthropic) "
    f"in apps/server/.env or the environment"
)

# Gemini keeps the legacy (pre-intent) prompt, so the live eval is only
# meaningful for deepseek / anthropic providers.
if _LIVE_PROVIDER == "gemini":
    _LIVE_SKIP_REASON = "live eval skipped: gemini uses the legacy (pre-intent) prompt"


@pytest.mark.skipif(not _LIVE_KEY, reason=_LIVE_SKIP_REASON)
@pytest.mark.parametrize("case", CASES, ids=[c["id"] for c in CASES])
def test_live_parser_case(case):
    from app.core import config
    config.get_settings.cache_clear()

    import asyncio

    parsed = asyncio.run(AIService.parse_reminder(_make_request(case["text"])))
    config.get_settings.cache_clear()

    failures = _check_case(case, parsed)
    assert not failures, " | ".join(failures)
