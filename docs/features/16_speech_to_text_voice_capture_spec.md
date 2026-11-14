# 16. Speech-to-Text Voice Capture Specification

## Overview
This specification details the real-time hardware voice recognition and speech-to-text integration for Pingo Mobile. It enables users to speak natural language reminders in Bangla (`bn_BD`) or English (`en_US`), watch their spoken words transcribed live on screen, and automatically submit the text for Zero-Knowledge AI reminder parsing.

---

## 1. Architectural Components

```
[ User Microphone (Android Audio Record) ]
                    │
                    ▼
[ SpeechRecognizer Service (speech_to_text) ]
                    │  Real-time Partial Transcription & Decibels
                    ▼
[ VoiceRecognitionService (Singleton) ]
                    │  Streams Words & Sound Level
                    ▼
[ PingoVoiceScreen (UI State) ]
                    │  Final Transcribed Text
                    ▼
[ PingoHomeScreen._submitText(speech) ]
                    │  HTTP POST /api/v1/ai/parse-reminder
                    ▼
[ AWS Cloud Server (FastAPI + DeepSeek/Gemini) ]
```

---

## 2. Platform Permissions & Queries

### AndroidManifest.xml
- `android.permission.RECORD_AUDIO`: Required for microphone access.
- `android.permission.BLUETOOTH` & `BLUETOOTH_CONNECT`: Supports Bluetooth headsets and external microphones.
- `<queries>` intent:
  ```xml
  <intent>
      <action android:name="android.speech.RecognitionService" />
  </intent>
  ```
  Essential for Android 11+ (API 30+) package visibility to bind to Google Speech recognition services.

---

## 3. Multilingual Support
- **Dual Language Toggle**:
  - `English + বাংলা`: Uses device default / multilingual fallback.
  - `বাংলা`: Enforces `bn_BD` locale for native Bengali pronunciation.
  - `English`: Enforces `en_US` locale.

---

## 4. Error Handling & Fallbacks
- Runtime permission request via `permission_handler`.
- If microphone permission is permanently denied or hardware unavailable, the user is offered the manual `"Type"` dialog fallback.
- Audio visualization scales dynamically with `_soundLevel` (decibel input).

