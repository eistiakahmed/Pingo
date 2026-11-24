# Feature Specification: Streamlined Zero-Touch Flutter Dashboard, Staged Multimodal Composer & Strict Tenant Headers

**Specification ID**: `SPEC-32-FLUTTER-ZERO-TOUCH-MULTIMODAL`  
**Date**: November 24, 2026  
**Scope**: Flutter Mobile App (`ApiClient`, `LocalStorageService`, `FcmService`, `AuthNotifier`, `ReminderItem`, `HomeReminderNotifier`, `VoiceCommandApiService`, `PingoChatNotifier`, `PingoHomeScreen`, `MyRemindersScreen`, `ChatMessageBubble`)  

---

## 1. Dashboard & Home Screen Simplification
- **Circular Progress Ring Chart**: Replaced the numerical linear progress bar in *Task & usage progress* with a clean `CircularProgressIndicator` ring visualization paired with the Upcoming & Completed usage counters.
- **Header Cleanup**: Removed the `Cloud synced` status badge from the top-right header.
- **Quick Actions Removal**: Removed the *Quick actions* chip section from the Home Dashboard.

## 2. Read-Only, Zero-Touch Task Lifecycle
- **Deprecated Manual Controls**: Removed `EditReminderScreen`, manual edit/delete actions, swipe-to-delete, and interactive completion checkboxes.
- **Autonomous LLM Category Badges**: Active and completed tasks render read-only cards displaying uppercase LLM-classified category badges (`MEDICINE`, `BILL`, `WORK`, `PERSONAL`, `BIRTHDAY`, `DOCUMENT`, `GENERAL`).
- **Automatic Completion Sync**: `HomeReminderNotifier` transitions tasks irreversibly from `scheduled` → `completed` upon reaching their due time, receiving an alarm/FCM push trigger, or pulling updated state from `/sync/pull`.

## 3. WhatsApp-Style Chat & Multimodal Attachment Composer
- **Decoupled Staging (`POST /api/attachments/stage`)**: Selecting a file/image (`📎`) or capturing a photo via the dedicated **Camera button (`📷`)** (`image_picker`) uploads to `/api/attachments/stage` and renders uncommitted preview chips/thumbnails inside the composer bar without auto-sending.
- **Atomic Bundled Transmission**: Tapping Send (`POST /api/assistant/message`) or releasing Hold-to-Record (`POST /api/voice-command`) sends `staging_ids` so the backend commits the message + staged attachments atomically, then clears the composer preview strip.

## 4. Session & Tenant Header Alignment
- **Authenticated (`Authorization: Bearer <JWT>`)**: Attached strictly when an explicit user session is active; enables `/sync` and `/devices`.
- **Unauthenticated Ephemeral (`X-Session-ID: <UUID>`)**: Persisted locally via `LocalStorageService.getOrCreateGuestSessionId()`, attached on every request via `ApiClient` and `VoiceCommandApiService`, with `/sync` and `/devices` calls strictly disabled when unauthenticated.
