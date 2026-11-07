from datetime import datetime, timezone
import json
from typing import Optional
from fastapi import status
import httpx
from app.core.config import get_settings
from app.core.exceptions import AppException
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
        ref_date = request.reference_date or datetime.now(timezone.utc)
        user_prompt = (
            f"User Utterance: \"{request.text}\"\n"
            f"User Timezone: {request.timezone}\n"
            f"Reference Datetime (UTC): {ref_date.isoformat()}\n"
        )

        provider = settings.AI_PROVIDER.lower().strip()

        if provider == "deepseek":
            return await cls._parse_with_deepseek(settings, user_prompt)
        elif provider == "gemini":
            return await cls._parse_with_gemini(settings, user_prompt)
        else:
            raise AppException(
                title="Unsupported AI Provider",
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"AI provider '{settings.AI_PROVIDER}' is not supported.",
                type_url="https://api.pingo.app/errors/unsupported-ai-provider",
            )

    @classmethod
    async def _parse_with_deepseek(
        cls, settings, user_prompt: str
    ) -> ParsedReminderData:
        """Parses reminder utterance using DeepSeek Chat Completions API with JSON mode."""
        if not settings.DEEPSEEK_API_KEY or settings.DEEPSEEK_API_KEY.strip() == "":
            raise AppException(
                title="AI Service Unavailable",
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="DEEPSEEK_API_KEY is not configured on the server.",
                type_url="https://api.pingo.app/errors/ai-unconfigured",
            )

        deepseek_system = (
            f"{SYSTEM_PROMPT}\n"
            "Return strictly a valid JSON object matching this schema:\n"
            "{\n"
            '  "title": "string",\n'
            '  "due_at": "ISO-8601 string or null",\n'
            '  "category": "GENERAL" | "MEDICINE" | "BILL" | "WORK" | "PERSONAL" | "BIRTHDAY",\n'
            '  "priority": "NORMAL" | "HIGH" | "URGENT",\n'
            '  "confidence": 0.0 to 1.0\n'
            "}"
        )

        url = f"{settings.DEEPSEEK_BASE_URL.rstrip('/')}/chat/completions"
        headers = {
            "Authorization": f"Bearer {settings.DEEPSEEK_API_KEY}",
            "Content-Type": "application/json",
        }
        payload = {
            "model": settings.DEEPSEEK_MODEL,
            "messages": [
                {"role": "system", "content": deepseek_system},
                {"role": "user", "content": user_prompt},
            ],
            "response_format": {"type": "json_object"},
            "temperature": 0.1,
        }

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(url, headers=headers, json=payload)

            if response.status_code != 200:
                raise AppException(
                    title="DeepSeek API Error",
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail=f"DeepSeek returned status {response.status_code}: {response.text}",
                    type_url="https://api.pingo.app/errors/deepseek-error",
                )

            data = response.json()
            content = data["choices"][0]["message"]["content"]
            parsed_dict = json.loads(content)
            return ParsedReminderData(**parsed_dict)
        except AppException:
            rethrow = True
            raise
        except Exception as e:
            raise AppException(
                title="AI Processing Failed",
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Failed to parse reminder with DeepSeek: {str(e)}",
                type_url="https://api.pingo.app/errors/ai-processing-failed",
            )

    @classmethod
    async def _parse_with_gemini(
        cls, settings, user_prompt: str
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
