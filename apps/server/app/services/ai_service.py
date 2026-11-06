from datetime import datetime, timezone
import json
from typing import Optional
from app.core.config import get_settings
from app.schemas.ai import (
    ParsedReminderData,
    ParseReminderRequest,
    ReminderCategory,
    ReminderPriority,
)

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


class AIService:
    @classmethod
    async def parse_reminder(
        cls, request: ParseReminderRequest
    ) -> ParsedReminderData:
        settings = get_settings()
        if not settings.GEMINI_API_KEY or settings.GEMINI_API_KEY.strip() == "":
            raise RuntimeError("GEMINI_API_KEY is not configured")

        from google import genai
        from google.genai import types

        client = genai.Client(api_key=settings.GEMINI_API_KEY)

        ref_date = request.reference_date or datetime.now(timezone.utc)
        user_prompt = (
            f"User Utterance: \"{request.text}\"\n"
            f"User Timezone: {request.timezone}\n"
            f"Reference Datetime (UTC): {ref_date.isoformat()}\n"
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
            raise ValueError("Empty response received from Gemini API")

        parsed_dict = json.loads(response.text)
        return ParsedReminderData(**parsed_dict)

