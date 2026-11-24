from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo
import json
from typing import Optional

from fastapi import status
import httpx
from pydantic import ValidationError

from app.core.config import get_settings
from app.core.exceptions import AppException
from app.schemas.ai import (
    ParseIntent,
    ParsedReminderData,
    ParseReminderRequest,
    ReminderCategory,
    ReminderPriority,
)

# ───────────────────────── Legacy prompt (deepseek / gemini providers) ─────────────────────────

SYSTEM_PROMPT = """You are Pingo's Executive Natural Language Parser.
Your objective is to convert user natural language utterances into structured reminder entities.
Supported languages: English, Bengali (বাংলা), and Banglish (Romanized Bengali).

Rules:
1. title: Extract a concise, executive-level summary of the action (e.g., 'ডাক্তারের প্রেসক্রিপশন ও ওষুধ কেনা', 'Team Standup', 'Pay Electric Bill').
2. due_at: Resolve relative dates/times ('কাল', 'পরশু', 'আগামীকাল', 'next Monday', 'in 2 hours') relative to the provided reference date and timezone. Return an ISO 8601 UTC timestamp string, or null if no time is mentioned.
3. category: Map to one of GENERAL, MEDICINE, BILL, WORK, PERSONAL, BIRTHDAY.
4. priority: Map to NORMAL, HIGH, or URGENT based on the tone, words like 'emergency', 'জরুরি', 'আজকের মধ্যেই', or explicit deadlines.
5. confidence: A float between 0.0 and 1.0 representing how clearly the user stated their intention.
"""


# ───────────────────────── Anthropic provider (default) ─────────────────────────

PARSING_JSON_SCHEMA = {
    "type": "object",
    "properties": {
        "intent": {
            "type": "string",
            "enum": [
                "create_reminder",
                "list_reminders",
                "save_documentation",
                "chat",
            ],
        },
        "title": {"type": ["string", "null"], "maxLength": 200},
        "date": {"type": ["string", "null"], "pattern": r"^\d{4}-\d{2}-\d{2}$"},
        "time": {"type": ["string", "null"], "pattern": r"^\d{2}:\d{2}$"},
        "category": {
            "type": "string",
            "enum": ["GENERAL", "MEDICINE", "BILL", "WORK", "PERSONAL", "BIRTHDAY", "DOCUMENT"],
        },
        "priority": {
            "type": "string",
            "enum": ["NORMAL", "HIGH", "URGENT"],
        },
        "clarifying_question": {"type": ["string", "null"], "maxLength": 200},
        "confidence": {"type": "number", "minimum": 0, "maximum": 1},
    },
    "required": [
        "intent",
        "title",
        "date",
        "time",
        "category",
        "priority",
        "clarifying_question",
        "confidence",
    ],
    "additionalProperties": False,
}

PARSER_SYSTEM_PROMPT = """You are Pingo's autonomous reminder & documentation parser. Convert the user's message into ONE JSON object and nothing else.
Supported languages: English, Bengali (বাংলা), Banglish (romanized Bengali), possibly mixed in one message.

Rules:
1. Build "title" concisely from the user's words.
2. Autonomously classify "category" into one of: GENERAL, MEDICINE, BILL, WORK, PERSONAL, BIRTHDAY, DOCUMENT without asking the user.
3. Autonomously classify "priority" into NORMAL, HIGH, or URGENT.
4. Manual delete and manual update workflows are deprecated. Only classify "intent" into: "create_reminder", "list_reminders", "save_documentation", or "chat".
5. Use the provided current local date, time and timezone to resolve relative phrases: "in five minutes", "tonight", "tomorrow morning", "today 10:27 PM", "এখন থেকে পাঁচ মিনিট পরে", "আজ রাত ১০টা", "kal bikel 5tay".
6. If the time has already passed today and no date is given, use tomorrow.
7. If the title is missing, use a short neutral title in the same language the user used (e.g. "Reminder" or "রিমাইন্ডার") and still create the reminder.
8. If anything important is unclear (time or date for create_reminder), put one short clarifying question in "clarifying_question" and leave date/time null instead of guessing.
9. "date" is YYYY-MM-DD and "time" is 24-hour HH:MM in the user's local timezone. When no exact time is given: "tonight" = 20:00, "morning/সকাল/sokal" = 08:00, "afternoon/দুপুর" = 14:00, "evening/বিকাল/bikel" = 17:00, "night/রাত/raat" = 21:00. "in N minutes/hours" = current time + N. If the user gives a date but no time, leave time null (the app schedules it at 09:00).

Examples (assume Current local date/time: 2026-11-18 21:30, timezone: Asia/Dhaka):

User: Remind me to water the plants tomorrow at 7:30 in the morning
JSON: {"intent": "create_reminder", "title": "water the plants", "date": "2026-11-19", "time": "07:30", "category": "PERSONAL", "priority": "NORMAL", "clarifying_question": null, "confidence": 0.98}

User: কাল সকাল ৮টায় ওষুধ কিনতে হবে
JSON: {"intent": "create_reminder", "title": "ওষুধ কিনতে হবে", "date": "2026-11-19", "time": "08:00", "category": "MEDICINE", "priority": "HIGH", "clarifying_question": null, "confidence": 0.97}

User: kal bikel 5tay mayer sathe doctor
JSON: {"intent": "create_reminder", "title": "mayer sathe doctor", "date": "2026-11-19", "time": "17:00", "category": "MEDICINE", "priority": "HIGH", "clarifying_question": null, "confidence": 0.96}

User: set a reminder in five minutes
JSON: {"intent": "create_reminder", "title": "Reminder", "date": "2026-11-18", "time": "21:35", "category": "GENERAL", "priority": "NORMAL", "clarifying_question": null, "confidence": 0.95}

User: pay electricity bill tomorrow
JSON: {"intent": "create_reminder", "title": "pay electricity bill", "date": "2026-11-19", "time": null, "category": "BILL", "priority": "NORMAL", "clarifying_question": null, "confidence": 0.95}

User: set an alarm 10:27 PM today
JSON: {"intent": "create_reminder", "title": "Reminder", "date": "2026-11-18", "time": "22:27", "category": "GENERAL", "priority": "NORMAL", "clarifying_question": null, "confidence": 0.94}

User: save project note FastAPI Redis architecture
JSON: {"intent": "save_documentation", "title": "FastAPI Redis architecture", "date": null, "time": null, "category": "DOCUMENT", "priority": "NORMAL", "clarifying_question": null, "confidence": 0.96}

User: what are my reminders for today?
JSON: {"intent": "list_reminders", "title": null, "date": null, "time": null, "category": "GENERAL", "priority": "NORMAL", "clarifying_question": null, "confidence": 0.99}

User: hello!
JSON: {"intent": "chat", "title": null, "date": null, "time": null, "category": "GENERAL", "priority": "NORMAL", "clarifying_question": null, "confidence": 0.99}
"""


def resolve_due_at(
    date_str: Optional[str],
    time_str: Optional[str],
    tz_name: str,
    ref_local: datetime,
) -> Optional[datetime]:
    """Deterministically resolves (date, time) in the user's timezone to a UTC timestamp.

    Rules (matching the system prompt):
    - date + time  → compose as given.
    - date only    → 09:00 that day.
    - time only    → today; if already past, tomorrow (rule 4).
    - neither      → None (caller must ask a clarifying question, never guess).
    """
    try:
        tz = ZoneInfo(tz_name)
    except Exception:
        tz = timezone.utc

    now_local = ref_local.astimezone(tz)
    due_local: Optional[datetime] = None

    if date_str and time_str:
        try:
            due_local = datetime.strptime(
                f"{date_str} {time_str}", "%Y-%m-%d %H:%M"
            ).replace(tzinfo=tz)
        except ValueError:
            return None
    elif date_str:
        try:
            d = datetime.strptime(date_str, "%Y-%m-%d").date()
        except ValueError:
            return None
        due_local = datetime(d.year, d.month, d.day, 9, 0, tzinfo=tz)
    elif time_str:
        try:
            h, m = map(int, time_str.split(":"))
        except (ValueError, AttributeError):
            return None
        due_local = now_local.replace(hour=h, minute=m, second=0, microsecond=0)
        if due_local <= now_local:
            due_local += timedelta(days=1)
    else:
        return None

    return due_local.astimezone(timezone.utc)


# ───────────────────────── Service ─────────────────────────


class AIService:
    @classmethod
    async def parse_reminder(
        cls, request: ParseReminderRequest
    ) -> ParsedReminderData:
        settings = get_settings()
        ref_date = request.reference_date or datetime.now(timezone.utc)

        # A naive reference_date is device-local time by definition —
        # attribute it to the request's timezone, not the server's clock.
        if ref_date.tzinfo is None:
            try:
                ref_date = ref_date.replace(tzinfo=ZoneInfo(request.timezone))
            except Exception:
                ref_date = ref_date.replace(tzinfo=timezone.utc)

        provider = settings.AI_PROVIDER.lower().strip()

        if provider == "anthropic":
            parsed = await cls._parse_with_anthropic(settings, request, ref_date)
        elif provider == "deepseek":
            parsed = await cls._parse_with_deepseek(settings, request, ref_date)
        elif provider == "gemini":
            parsed = await cls._parse_with_gemini(settings, request, ref_date)
        else:
            raise AppException(
                title="Unsupported AI Provider",
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"AI provider '{settings.AI_PROVIDER}' is not supported.",
                type_url="https://api.pingo.app/errors/unsupported-ai-provider",
            )

        # Server-side deterministic resolution: the model never computes the
        # final scheduling timestamp, and a missing time becomes a question —
        # never a silently wrong alarm.
        if parsed.intent == ParseIntent.CREATE_REMINDER and parsed.clarifying_question is None:
            parsed.due_at = resolve_due_at(
                parsed.date, parsed.time, request.timezone, ref_date
            )
            if parsed.due_at is None:
                parsed.clarifying_question = (
                    "When should I set this reminder? (date & time)"
                )

        return parsed

    # ── Anthropic (default provider) ──

    @classmethod
    async def _parse_with_anthropic(
        cls, settings, request: ParseReminderRequest, ref_date: datetime
    ) -> ParsedReminderData:
        """Structured extraction via Anthropic Messages API (Haiku class).

        - Structured outputs (json_schema) constrain the reply to exactly one
          JSON object with the required fields.
        - effort 'low' replaces temperature tuning (temperature is not a valid
          parameter on current API versions — it is rejected with a 400).
        - Invalid/incomplete output is retried once; a second failure returns a
          clarifying-question payload — never a silently wrong reminder.
        - The API key lives only on this server; the mobile app never sees it.
        """
        try:
            from anthropic import AsyncAnthropic, APIConnectionError, APIStatusError
        except ImportError as e:
            raise AppException(
                title="AI Service Unavailable",
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="The 'anthropic' package is not installed on the server.",
                type_url="https://api.pingo.app/errors/ai-unconfigured",
            ) from e

        if not settings.ANTHROPIC_API_KEY.strip():
            raise AppException(
                title="AI Service Unavailable",
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="ANTHROPIC_API_KEY is not configured on the server.",
                type_url="https://api.pingo.app/errors/ai-unconfigured",
            )

        client = AsyncAnthropic(api_key=settings.ANTHROPIC_API_KEY)

        try:
            local_now = ref_date.astimezone(ZoneInfo(request.timezone))
        except Exception:
            local_now = ref_date.astimezone(timezone.utc)

        user_prompt = (
            f"Current local date/time: {local_now.strftime('%Y-%m-%d %H:%M')}\n"
            f"Timezone: {request.timezone}\n"
            f'User message: "{request.text}"\n'
            "JSON:"
        )

        for _attempt in range(2):  # invalid/incomplete output → retry once
            try:
                response = await client.messages.create(
                    model=settings.ANTHROPIC_MODEL,
                    max_tokens=1024,
                    output_config={
                        "effort": "low",
                        "format": {
                            "type": "json_schema",
                            "schema": PARSING_JSON_SCHEMA,
                        },
                    },
                    system=[
                        {
                            "type": "text",
                            "text": PARSER_SYSTEM_PROMPT,
                            "cache_control": {"type": "ephemeral"},
                        }
                    ],
                    messages=[{"role": "user", "content": user_prompt}],
                )

                if response.stop_reason == "refusal":
                    raise AppException(
                        title="AI Request Refused",
                        status_code=status.HTTP_502_BAD_GATEWAY,
                        detail="The parser declined this request.",
                        type_url="https://api.pingo.app/errors/ai-refused",
                    )

                content = next(
                    (b.text for b in response.content if b.type == "text"), ""
                )
                data = json.loads(content)
                return ParsedReminderData(**data)
            except (json.JSONDecodeError, ValidationError):
                continue
            except AppException:
                raise
            except APIConnectionError as e:
                raise AppException(
                    title="AI Service Unavailable",
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    detail="Could not reach the Anthropic API.",
                    type_url="https://api.pingo.app/errors/ai-unreachable",
                ) from e
            except APIStatusError as e:
                raise AppException(
                    title="Anthropic API Error",
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail=f"Anthropic API returned status {getattr(e, 'status_code', '?')}.",
                    type_url="https://api.pingo.app/errors/anthropic-error",
                ) from e

        # Both attempts produced invalid output → ask, never guess.
        return ParsedReminderData(
            intent=ParseIntent.CHAT,
            clarifying_question="Could you repeat the reminder with a clear time?",
            confidence=0.0,
        )

    # ── DeepSeek (default active provider) ──

    @classmethod
    async def _parse_with_deepseek(
        cls, settings, request: ParseReminderRequest, ref_date: datetime
    ) -> ParsedReminderData:
        """Structured extraction via DeepSeek Chat Completions API (JSON mode).

        Uses the SAME parser prompt, schema, retry-once and clarifying-question
        fallback as the Anthropic provider, so the mobile intent routing works
        identically regardless of which provider is active.
        """
        if not settings.DEEPSEEK_API_KEY or settings.DEEPSEEK_API_KEY.strip() == "":
            raise AppException(
                title="AI Service Unavailable",
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="DEEPSEEK_API_KEY is not configured on the server.",
                type_url="https://api.pingo.app/errors/ai-unconfigured",
            )

        try:
            local_now = ref_date.astimezone(ZoneInfo(request.timezone))
        except Exception:
            local_now = ref_date.astimezone(timezone.utc)

        user_prompt = (
            f"Current local date/time: {local_now.strftime('%Y-%m-%d %H:%M')}\n"
            f"Timezone: {request.timezone}\n"
            f'User message: "{request.text}"\n'
            "JSON:"
        )

        url = f"{settings.DEEPSEEK_BASE_URL.rstrip('/')}/chat/completions"
        headers = {
            "Authorization": f"Bearer {settings.DEEPSEEK_API_KEY}",
            "Content-Type": "application/json",
        }
        payload = {
            "model": settings.DEEPSEEK_MODEL,
            "messages": [
                {"role": "system", "content": PARSER_SYSTEM_PROMPT},
                {"role": "user", "content": user_prompt},
            ],
            "response_format": {"type": "json_object"},
            "temperature": 0.1,
        }

        try:
            for _attempt in range(2):  # invalid/incomplete output → retry once
                async with httpx.AsyncClient(timeout=30.0) as http_client:
                    response = await http_client.post(
                        url, headers=headers, json=payload
                    )

                if response.status_code != 200:
                    raise AppException(
                        title="DeepSeek API Error",
                        status_code=status.HTTP_502_BAD_GATEWAY,
                        detail=f"DeepSeek returned status {response.status_code}.",
                        type_url="https://api.pingo.app/errors/deepseek-error",
                    )

                data = response.json()
                content = data["choices"][0]["message"]["content"]
                try:
                    parsed_dict = json.loads(content)
                    return ParsedReminderData(**parsed_dict)
                except (json.JSONDecodeError, ValidationError):
                    continue  # retry once

            # Both attempts produced invalid output → ask, never guess.
            return ParsedReminderData(
                intent=ParseIntent.CHAT,
                clarifying_question="Could you repeat the reminder with a clear time?",
                confidence=0.0,
            )
        except AppException:
            raise
        except Exception as e:
            raise AppException(
                title="AI Processing Failed",
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Failed to parse reminder with DeepSeek.",
                type_url="https://api.pingo.app/errors/ai-processing-failed",
            ) from e

    @classmethod
    async def _parse_with_gemini(
        cls, settings, request: ParseReminderRequest, ref_date: datetime
    ) -> ParsedReminderData:
        """Parses reminder utterance using Google Gemini API."""
        if not settings.GEMINI_API_KEY or settings.GEMINI_API_KEY.strip() == "":
            raise AppException(
                title="AI Service Unavailable",
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="GEMINI_API_KEY is not configured on the server.",
                type_url="https://api.pingo.app/errors/ai-unconfigured",
            )

        from google import genai
        from google.genai import types

        client = genai.Client(api_key=settings.GEMINI_API_KEY)

        ref_local = ref_date.astimezone(ZoneInfo(request.timezone))
        user_prompt = (
            f'User Utterance: "{request.text}"\n'
            f"User Timezone: {request.timezone}\n"
            f"Reference Datetime (Local): {ref_local.isoformat()}\n"
        )

        response = await client.aio.models.generate_content(
            model="gemini-2.0-flash",
            contents=user_prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                response_schema=ParsedReminderData,
                system_instruction=SYSTEM_PROMPT,
                temperature=0.1,
            ),
        )

        if not response.text:
            raise AppException(
                title="Empty AI Response",
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Empty response received from Gemini API",
                type_url="https://api.pingo.app/errors/gemini-empty",
            )

        parsed_dict = json.loads(response.text)
        return ParsedReminderData(**parsed_dict)
