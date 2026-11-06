# Pingo Python FastAPI Backend & Zero-Knowledge E2EE Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a production-ready, high-performance Python FastAPI backend (`apps/server`) and cryptographic verification suite (`packages/e2ee_py`) for Pingo, providing AI natural language reminder parsing via Google Gemini API and zero-knowledge end-to-end encrypted cloud synchronization.

**Architecture:** Clean modular architecture separating routing (`app/api/v1`), domain services (`app/services`), data models (`app/models`), and schemas (`app/schemas`). Zero-knowledge guarantees ensure the server only stores encrypted envelopes (`ciphertext`, `iv`, `auth_tag`, `key_version`, `algorithm`) and never sees plaintext user reminder or vault data. Google Gemini API operates via structured JSON output mode to extract reminders from English, Bengali, and Banglish input.

**Tech Stack:** Python 3.12+, FastAPI, Uvicorn, Pydantic v2, Pydantic-Settings, SQLAlchemy 2.0 (Async), Asyncpg, Alembic, Google GenAI SDK (`google-genai`), Pytest, Pytest-Asyncio, HTTPX, Cryptography.

**Spec:** `docs/features/10_backend_architecture_spec.md` & `docs/features/11_e2ee_cryptography_spec.md`

## Global Constraints

- Python version floor: 3.12+ with strict type annotations.
- Zero plaintext storage: Reminder titles, notes, and vault items must never be stored unencrypted on the server.
- Framework: FastAPI with ASGI async handlers on all I/O bound endpoints.
- Validation: Pydantic v2 models for all request bodies, query params, and settings.
- Database: PostgreSQL via SQLAlchemy 2.0 Async (`asyncpg`), with explicit indexes, foreign keys, and audit timestamps (`created_at`, `updated_at`, `deleted_at`).
- Error Handling: Centralized RFC 7807 Problem Details for all HTTP exceptions.
- API Documentation: Auto-generated OpenAPI schema and Swagger UI active at `/docs`.

## Review Focus

1. **Gemini API Key Missing or Invalid:** Handled gracefully with 503 / 502 RFC 7807 problem details instead of an unhandled internal 500 crash.
2. **Timezone-Aware Relative Parsing:** Bangla/Banglish date strings ("কাল সকাল ৮টা", "পরশু দুপুর ২টায়") accurately converted to UTC ISO 8601 timestamps using the client's provided `timezone` and `reference_date`.
3. **Malformed Base64 Cryptographic Fields:** Sync push payloads with invalid base64 or wrong IV/authTag lengths are rejected with 422 Unprocessable Entity at the Pydantic boundary before hitting the database.
4. **Concurrent Sync Push Conflicts:** Sync push resolves version collisions using deterministic Last-Write-Wins comparison on item version and `updated_at`.
5. **Batch Size Flood Prevention:** Sync push endpoints enforce a hard upper bound of 500 items per batch to prevent memory saturation and payload denial-of-service.

---

### Task 1: Project Scaffolding, Environment Configuration & Settings

**Files:**
- Create: `apps/server/requirements.txt`
- Create: `apps/server/pyproject.toml`
- Create: `apps/server/.env.example`
- Create: `apps/server/app/__init__.py`
- Create: `apps/server/app/core/__init__.py`
- Create: `apps/server/app/core/config.py`
- Test: `apps/server/tests/__init__.py`
- Test: `apps/server/tests/core/test_config.py`

**Interfaces:**
- Consumes: Environment variables (`DATABASE_URL`, `GEMINI_API_KEY`, `APP_ENV`, `CORS_ORIGINS`).
- Produces: `get_settings() -> Settings` delivering validated configuration singleton.

- [x] **Step 1: Write the failing test for configuration loading**
- [x] **Step 2: Run test to verify it fails**
- [x] **Step 3: Implement dependencies and `Settings` in `apps/server/app/core/config.py`**
- [x] **Step 4: Run test to verify it passes**
- [x] **Step 5: Commit scaffolding**

```bash
git add apps/server/requirements.txt apps/server/pyproject.toml apps/server/.env.example apps/server/app/core/config.py apps/server/tests/core/test_config.py
git commit -m "feat(server): initialize Python FastAPI project structure and config"
```

---

### Task 2: Shared E2EE Cryptography Engine (`packages/e2ee_py`)

**Files:**
- Create: `packages/e2ee_py/pyproject.toml`
- Create: `packages/e2ee_py/e2ee/__init__.py`
- Create: `packages/e2ee_py/e2ee/envelope.py`
- Create: `packages/e2ee_py/e2ee/aes_gcm.py`
- Create: `packages/e2ee_py/e2ee/kdf.py`
- Test: `packages/e2ee_py/tests/test_crypto.py`

**Interfaces:**
- Consumes: Plaintext strings, secret keys (32 bytes), passphrases, and salts.
- Produces: 
  - `derive_key_pbkdf2(passphrase: str, salt: bytes, iterations: int = 100_000) -> bytes`
  - `encrypt_aes_gcm(plaintext: str, key: bytes, key_version: int = 1) -> EncryptedEnvelope`
  - `decrypt_aes_gcm(envelope: EncryptedEnvelope, key: bytes) -> str`

- [x] **Step 1: Write failing tests for AES-256-GCM and PBKDF2**
- [x] **Step 2: Run test to verify it fails**
- [x] **Step 3: Implement AES-256-GCM and PBKDF2 using `cryptography.hazmat`**
- [x] **Step 4: Run test to verify it passes**
- [x] **Step 5: Commit E2EE library**

```bash
git add packages/e2ee_py/
git commit -m "feat(crypto): implement shared Python E2EE AES-256-GCM and PBKDF2 engine"
```

---

### Task 3: FastAPI Application Shell, Error Handling & Health Endpoint

**Files:**
- Create: `apps/server/app/core/exceptions.py`
- Create: `apps/server/app/core/middleware.py`
- Create: `apps/server/app/api/__init__.py`
- Create: `apps/server/app/api/v1/__init__.py`
- Create: `apps/server/app/api/v1/api.py`
- Create: `apps/server/app/api/v1/endpoints/__init__.py`
- Create: `apps/server/app/api/v1/endpoints/health.py`
- Create: `apps/server/app/main.py`
- Test: `apps/server/tests/api/test_health.py`
- Test: `apps/server/tests/core/test_exceptions.py`

**Interfaces:**
- Consumes: `Settings` from `app.core.config`.
- Produces:
  - `app = FastAPI(...)` ASGI application.
  - `GET /health` returning `{"status": "healthy", "service": "pingo-backend", "version": "1.0.0"}`.
  - RFC 7807 problem details exception handler catching `AppException`, `RequestValidationError`, and unexpected exceptions.

- [x] **Step 1: Write failing tests for Health and RFC 7807 Exception Format**
- [x] **Step 2: Run test to verify it fails**
- [x] **Step 3: Implement `app.main`, CORS middleware, exception handlers, and `/health` route**
- [x] **Step 4: Run test to verify it passes**
- [x] **Step 5: Commit application shell**

```bash
git add apps/server/app/main.py apps/server/app/core/exceptions.py apps/server/app/core/middleware.py apps/server/app/api/ apps/server/tests/api/test_health.py
git commit -m "feat(server): implement FastAPI application shell, RFC 7807 error handler, and health check"
```

---

### Task 4: Database Layer (SQLAlchemy 2.0 Async Models & Session)

**Files:**
- Create: `apps/server/app/db/__init__.py`
- Create: `apps/server/app/db/base.py`
- Create: `apps/server/app/db/session.py`
- Create: `apps/server/app/models/__init__.py`
- Create: `apps/server/app/models/user.py`
- Create: `apps/server/app/models/reminder.py`
- Create: `apps/server/app/models/vault.py`
- Test: `apps/server/tests/db/test_models.py`

**Interfaces:**
- Consumes: `Settings.DATABASE_URL`.
- Produces:
  - `get_db() -> AsyncGenerator[AsyncSession, None]` dependency.
  - SQLAlchemy models: `User`, `EncryptedReminder`, `EncryptedVaultItem`.

- [x] **Step 1: Write failing test for models and session initialization**
- [x] **Step 2: Run test to verify it fails**
- [x] **Step 3: Implement `Base`, `session.py`, `User`, `EncryptedReminder`, and `EncryptedVaultItem`**
- [x] **Step 4: Run test to verify it passes**
- [x] **Step 5: Commit database layer**

```bash
git add apps/server/app/db/ apps/server/app/models/ apps/server/tests/db/
git commit -m "feat(server): define SQLAlchemy 2.0 async database models for zero-knowledge storage"
```

---

### Task 5: Gemini AI NLP Parsing Gateway Service & Endpoint

**Files:**
- Create: `apps/server/app/schemas/ai.py`
- Create: `apps/server/app/services/ai_service.py`
- Create: `apps/server/app/api/v1/endpoints/ai.py`
- Test: `apps/server/tests/services/test_ai_service.py`
- Test: `apps/server/tests/api/test_ai_endpoint.py`

**Interfaces:**
- Consumes:
  - `ParseReminderRequest(text: str, timezone: str, reference_date: Optional[datetime])`
  - `Settings.GEMINI_API_KEY`
- Produces:
  - `POST /api/v1/ai/parse-reminder` -> `ParseReminderResponse`
  - `AIService.parse_reminder(request: ParseReminderRequest) -> ParsedReminderData`

- [x] **Step 1: Write failing test for AI Parsing endpoint with mocked Gemini client**
- [x] **Step 2: Run test to verify it fails**
- [x] **Step 3: Implement `AIService` and `/api/v1/ai/parse-reminder` router**
- [x] **Step 4: Run test to verify it passes**
- [x] **Step 5: Commit AI Gateway module**

```bash
git add apps/server/app/schemas/ai.py apps/server/app/services/ai_service.py apps/server/app/api/v1/endpoints/ai.py apps/server/tests/api/test_ai_endpoint.py
git commit -m "feat(ai): implement Gemini NLP reminder extraction gateway with multilingual support"
```

---

### Task 6: Zero-Knowledge Sync Service & Endpoints (Push & Pull)

**Files:**
- Create: `apps/server/app/schemas/sync.py`
- Create: `apps/server/app/services/sync_service.py`
- Create: `apps/server/app/api/v1/endpoints/sync.py`
- Test: `apps/server/tests/schemas/test_sync_schemas.py`
- Test: `apps/server/tests/api/test_sync_endpoints.py`

**Interfaces:**
- Consumes:
  - `SyncPushRequest(reminders: List[EncryptedReminderDTO], vault_items: List[EncryptedVaultDTO])`
  - `GET /api/v1/sync/pull?since={timestamp}`
- Produces:
  - `POST /api/v1/sync/push` -> `SyncPushResponse(success: bool, applied_count: int, server_timestamp: datetime)`
  - `GET /api/v1/sync/pull` -> `SyncPullResponse(reminders: List[EncryptedReminderDTO], vault_items: List[EncryptedVaultDTO])`

- [ ] **Step 1: Write failing test for Base64 Cryptographic validation and Sync Push**

```python
# apps/server/tests/schemas/test_sync_schemas.py
import pytest
from pydantic import ValidationError
from app.schemas.sync import EncryptedReminderDTO
from uuid import uuid4

def test_valid_encrypted_envelope_dto():
    dto = EncryptedReminderDTO(
        id=uuid4(),
        ciphertext="ZXhhbXBsZWNpcGhlcnRleHQ=",
        iv="MDEyMzQ1Njc4OWFi",
        auth_tag="YWJjZGVmZ2hpamtsbW5vcA==",
        key_version=1,
        version=1
    )
    assert dto.algorithm == "AES-256-GCM"
    assert dto.is_completed is False

def test_invalid_base64_ciphertext_rejected():
    with pytest.raises(ValidationError):
        EncryptedReminderDTO(
            id=uuid4(),
            ciphertext="not-valid-base64!@#$",
            iv="MDEyMzQ1Njc4OWFi",
            auth_tag="YWJjZGVmZ2hpamtsbW5vcA==",
            key_version=1,
            version=1
        )
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m pytest apps/server/tests/schemas/test_sync_schemas.py`
Expected: FAIL (Cannot import 'EncryptedReminderDTO')

- [ ] **Step 3: Implement `app/schemas/sync.py`, `SyncService`, and `/api/v1/sync` router**

Define `EncryptedReminderDTO` and `EncryptedVaultDTO` enforcing Base64 formatting and length constraints. Implement batch upsert and Last-Write-Wins delta resolution in `SyncService`.

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m pytest apps/server/tests/schemas/test_sync_schemas.py apps/server/tests/api/test_sync_endpoints.py`
Expected: PASS

- [ ] **Step 5: Commit Zero-Knowledge Sync module**

```bash
git add apps/server/app/schemas/sync.py apps/server/app/services/sync_service.py apps/server/app/api/v1/endpoints/sync.py apps/server/tests/schemas/ apps/server/tests/api/test_sync_endpoints.py
git commit -m "feat(sync): implement zero-knowledge sync push and pull endpoints with conflict resolution"
```

---

### Task 7: End-to-End Verification & Verification Suite

**Files:**
- Create: `apps/server/tests/e2e/test_full_workflow.py`
- Modify: `apps/server/README.md`
- Test: Complete test suite execution across all packages

**Interfaces:**
- Consumes: Complete running FastAPI application.
- Produces: 100% passing tests for Health, AI parsing, and Zero-Knowledge Sync with clean reports.

- [ ] **Step 1: Write comprehensive end-to-end integration test**

```python
# apps/server/tests/e2e/test_full_workflow.py
import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app

@pytest.mark.asyncio
async def test_complete_e2e_flow():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        # 1. Health Check
        health = await ac.get("/health")
        assert health.status_code == 200

        # 2. OpenAPI Schema availability
        openapi = await ac.get("/openapi.json")
        assert openapi.status_code == 200
        assert "/api/v1/ai/parse-reminder" in openapi.json()["paths"]
        assert "/api/v1/sync/push" in openapi.json()["paths"]
```

- [ ] **Step 2: Run full test suite across server and crypto engine**

Run: `python3 -m pytest apps/server/tests packages/e2ee_py/tests -v`
Expected: ALL TESTS PASS

- [ ] **Step 3: Update `apps/server/README.md` with setup and execution instructions**

Document virtual environment creation, installation of requirements, running migrations, and launching Uvicorn (`uvicorn app.main:app --reload --port 8000`).

- [ ] **Step 4: Commit documentation and complete verification**

```bash
git add apps/server/tests/e2e/ apps/server/README.md
git commit -m "docs(server): add server execution instructions and complete e2e test suite"
```

