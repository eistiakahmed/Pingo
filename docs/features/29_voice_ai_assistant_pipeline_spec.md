# Feature Specification: FastAPI Voice AI Assistant Pipeline

**Specification ID**: `SPEC-29-VOICE-AI-ASSISTANT`  
**Date**: November 24, 2026  
**Scope**: FastAPI Backend (`/api/voice-command`, Groq Whisper STT, DeepSeek Function Calling, Edge-TTS `bn-BD-NabanitaNeural`, PostgreSQL `reminders` & `documentations`)  

---

## 1. Architecture & Data Flow

1. **`POST /api/voice-command` (`multipart/form-data`)**:
   - Fields: `audio: UploadFile = File(...)` (strictly `audio`) and `user_id: str = Form(...)`.
2. **Speech-to-Text (`Groq` `whisper-large-v3`)**:
   - `temperature=0.0`, no hardcoded `language` parameter (auto-detects Bangla, English, and Banglish), with a bilingual technical/scheduling context prompt.
   - Temporary uploaded audio file is deleted in a `finally:` block immediately after STT finishes.
3. **AI Brain & Tool Calling (`OpenAI` SDK -> `https://api.deepseek.com`, `model="deepseek-chat"`)**:
   - System prompt injects live Bangladesh time (`Asia/Dhaka`, `UTC+06:00`), instructs phonetic STT error correction across Bangla/English/Banglish, and replies in natural conversational Bangla.
   - Tools:
     - `set_reminder(task_title: str, reminder_time: str)` -> normalizes ISO 8601 `+06:00` timestamp and inserts into `reminders` (plus mirrors to `encrypted_reminders` if `user_id` matches an existing `users.id` UUID).
     - `save_documentation(title: str, content: str)` -> saves formatted notes into `documentations`.
4. **Text-to-Speech (`edge-tts` `bn-BD-NabanitaNeural`) & Disk Hygiene**:
   - Strips markdown symbols (`*`, `#`, `_`, `` ` ``) from `ai_reply` before passing to `edge-tts` so spoken Bangla audio reads cleanly.
   - Cleans up `.mp3` files in `app/static/audio` older than 24 hours (`86400s`).
   - Serves generated `.mp3` files from `/static/audio/{filename}.mp3` and returns `{ user_said, ai_reply, audio_url, actions }`.
