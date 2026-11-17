# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What Pingo Is

A bilingual (English / Bengali / Banglish) offline-first mobile memory assistant: reminders via natural-language chat and voice, plus an encrypted document vault with expiry OCR. The master product/technical plan lives in `🔔 Pingo.md`; numbered feature specs live in `docs/features/NN_*.md` — new feature work typically starts as a spec there.

## Repo Layout

Monorepo ("DokaanDigit-style"):
- `apps/mobile/` — Flutter client (Android/iOS), the primary app
- `apps/server/` — FastAPI backend: AI gateway + zero-knowledge sync + FCM push
- `packages/e2ee_py/` — Python mirror of the AES-256-GCM envelope crypto engine (reference implementation + tests)
- `docs/` — architecture specs, feature specs, API contracts (`docs/references/api_contracts.md`)

## Commands

### Mobile (run from `apps/mobile/`)
```bash
flutter pub get
flutter run                        # device/simulator
flutter analyze --no-fatal-infos   # CI gate; warnings fail CI
flutter test                       # all tests
flutter test test/sync             # one directory
flutter test test/sync/sync_api_test.dart              # one file
flutter test --plain-name "some test name"             # one test
```
CI also runs `flutter test` and `flutter analyze --no-fatal-infos` (see `.github/workflows/ci.yml`).

### Server (from repo root)
```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r apps/server/requirements.txt

# Tests (root pyproject.toml sets testpaths to apps/server/tests and packages/e2ee_py/tests)
pytest -v
pytest apps/server/tests/test_sync.py -v                      # one file
pytest apps/server/tests/test_sync.py::test_push_envelope -v  # one test

# Dev server (needs DATABASE_URL + AI provider key in env)
cd apps/server && uvicorn app.main:app --reload --port 8000
```
Swagger at `http://localhost:8000/docs`. Postgres is expected (dockerized or local).

### Docker
```bash
docker compose up                  # dev: api on :8000, runs alembic upgrade head on start
docker compose -f docker-compose.prod.yml up -d   # prod (AWS Lightsail; see deploy/setup-aws-lightsail.sh)
```

## Architecture

### Mobile — Clean Architecture per feature
Each feature under `apps/mobile/lib/features/<name>/` is split into `presentation/` (widgets + Riverpod state in `state/`), `domain/` (models), `data/` (API/local services). State management is **flutter_riverpod** (`presentation/state/*_provider.dart`). Don't put business logic in widgets or screen classes.

- `lib/core/services/` — platform engines: `notification_service.dart` (exact local alarms, boot persistence, snooze actions), `fcm_service.dart` (push), `voice_recognition_service.dart` (speech-to-text). Initialized in `main.dart` *after* `runApp` so the first frame is never blocked.
- `lib/core/crypto/crypto_helper.dart` — client-side AES-256-GCM; encrypts everything before sync.
- `lib/core/network/api_config.dart` — all endpoint paths; base URL defaults to `http://10.0.2.2:8000` (Android emulator → host).
- `lib/shared/` — cross-feature widgets; `lib/core/theme|typography/` — design system.

### Server — zero-knowledge envelope store
`apps/server/app/` : `api/v1/endpoints/` (auth, ai, sync, devices, health) → `services/` (`sync_service`, `ai_service`, `fcm_service`, `reminder_scheduler`) → `models/` (SQLAlchemy 2.0 async). Schema changes go through **Alembic** migrations in `apps/server/alembic/versions/` (numbered `001_...`, `002_...`).

Core invariant: the database holds **only crypto envelopes** (`ciphertext`, `iv`, `auth_tag`, `key_version`, `algorithm`) — never plaintext reminders or vault items. The client encrypts; the server must stay zero-knowledge. `packages/e2ee_py` is the canonical Python reference for the envelope format.

AI extraction (`services/ai_service.py`) parses natural-language reminders via a pluggable provider set by `AI_PROVIDER` env var (`deepseek` default, `gemini`/`gemini-2.0-flash` supported) in structured JSON mode.

Errors use RFC 7807 problem details via centralized exception handlers in `app/core/`.

## Conventions & Constraints

- **Branching**: `main` is production-only (PRs only); `develop` is integration; `feature/<name>`, `fix/<name>`, `docs/<name>` branches. Never commit directly to `main` or `develop`.
- **Conventional Commits** required: `feat(scope):`, `fix(scope):`, `ui(scope):`, `docs(scope):`, `refactor(scope):`.
- **Reminder times serialize in UTC** (`due_at`) — the client schedules local alarms by converting back to local time. Don't break this.
- **Bangla typography**: any UI rendering Bengali text needs ~1.45x line height and proper Bengali unicode support (font: Hind Siliguri).
- **Language policy** (from GEMINI.md): always respond in English, even when the user writes in Banglish/Bengali; direct, concise, technical tone.
- Defensive engineering at system boundaries: validate API schemas strictly; no hardcoded credentials or magic numbers.
