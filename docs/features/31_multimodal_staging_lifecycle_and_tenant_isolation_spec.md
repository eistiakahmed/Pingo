# Feature Specification: Multimodal Attachment Staging, Autonomous Task Lifecycle & Strict Multi-Tenant Isolation

**Specification ID**: `SPEC-31-MULTIMODAL-LIFECYCLE-ISOLATION`  
**Date**: November 24, 2026  
**Scope**: FastAPI Backend (`app/core/tenant.py`, `app/services/staging_service.py`, `app/models/voice_assistant.py`, `app/schemas/voice.py`, `app/schemas/ai.py`, `app/services/voice_assistant_service.py`, `app/services/reminder_scheduler.py`, `app/services/sync_service.py`, `app/api/v1/endpoints/*`)  

---

## 1. Multimodal Attachment & Inbox Staging Pipeline
- **Decoupled Preview Staging (`POST /api/attachments/stage` & preview-only ingestion on `POST /api/voice-command`)**:
  - Accepts optional file/image uploads (`UploadFile`, max 15 MB, SHA-256 checksummed, MIME-validated) without triggering LLM/TTS auto-sending when no voice/text command is included.
  - Stores uncommitted staged blobs in per-tenant isolated storage (`app/static/staged/<tenant_hash>/`) guarded by per-tenant `asyncio.Lock` and returns `StagedAttachmentPreviewResponse` (`status: "staged_preview"`, `staging_id`, `filename`, `mime_type`, `size_bytes`, `sha256`, `preview_url`, `expires_at`).
- **Atomic Bundled Transmission (`POST /api/voice-command` & `POST /api/assistant/message`)**:
  - Intercepts incoming voice (`audio`) or text (`message`) commands, drains specified `staging_ids` (or all uncommitted staged attachments for that `tenant_id`), injects attachment context into the DeepSeek prompt, and commits the message + attachments + tool records in a **single atomic transaction** (rolling back DB and preserving staged state on failure).

## 2. Autonomous Task Classification & Zero-Touch Irreversible Lifecycle
- **LLM-Driven Categorization**:
  - DeepSeek (`deepseek-chat`) autonomously classifies tasks into `TaskCategory` (`MEDICINE`, `BILL`, `WORK`, `PERSONAL`, `DOCUMENT`, `GENERAL`) without manual user input.
  - Deprecated `delete_reminder` and `update_reminder` from `ParseIntent` and assistant tools.
- **Streamlined Irreversible State Machine (`scheduled` -> `completed`)**:
  - `Reminder` drops redundant mutable status flags (`is_completed`, `updated_at`) in favor of `state: TaskLifecycleState` (`scheduled` | `completed`, guarded by PostgreSQL `CHECK (state IN ('scheduled', 'completed'))`) and `completed_at: datetime | None`.
  - `ReminderScheduler` uses `SELECT ... FOR UPDATE SKIP LOCKED` for multi-worker concurrency safety and transitions due reminders strictly and irreversibly to `completed` (`completed_at = now`).
  - `SyncService.apply_push` enforces monotonic completion (`EncryptedReminder.is_completed` cannot revert from `True` to `False`, cannot mutate `due_at`/`ciphertext` once completed, and scopes `ON CONFLICT DO UPDATE` strictly by `EncryptedReminder.user_id == request.user_id`).

## 3. Pipeline Telemetry & Strict Tenant Isolation
- **Telemetry**: `PipelineTelemetry` (`request_id`, `tenant_scope`, `stt_ms`, `llm_ms`, `tts_ms`, `total_ms`, `bundled_attachments_count`) included on assistant responses.
- **Multi-Tenant & Ephemeral Isolation**:
  - Authenticated requests (`Bearer <JWT>`) bind strictly to `tenant_id = "user:<uuid>"` (`is_ephemeral = False`), preventing IDOR via spoofed `user_id` form fields.
  - Unauthenticated requests bind strictly to segregated ephemeral session pools `tenant_id = "ephem:<sha256>"` (`is_ephemeral = True`) stored in an isolated in-memory TTL pool (`EphemeralTenantStore`) — never writing to or reading from authenticated PostgreSQL `users`, `encrypted_reminders`, or `device_tokens`.
  - Removed all cross-tenant fallbacks in `sync.py`, `devices.py`, and `reminder_scheduler.py`.
