# Feature Specification: Punctual Alarm Hardening & Zero-AI UI Branding

**Specification ID**: `SPEC-21-PUNCTUAL-ALARM-ZERO-AI`  
**Version**: `2.1.0` (APPROVED & HARDENED)  
**Date**: November 23, 2026  
**Scope**: Mobile Core Services (`NotificationService`, `FcmService`, `HomeReminderNotifier`), Backend (`SyncService`, `FcmPushService`, `ReminderScheduler`)  

---

## 0. v2.1 Notification Pipeline Hardening Fixes

1. **Eliminated 15-Second Premature Fallback Alarm (`notification_service.dart`)**:
   - All three priority tiers (`alarmClock` → `exactAllowWhileIdle` → `inexactAllowWhileIdle`) now strictly schedule at `targetTz` rather than falling back to `tzNow.add(const Duration(seconds: 15))`, and reminders more than 30 seconds in the past are skipped.
2. **Serialized Android Permission Mutex (`notification_service.dart` & `fcm_service.dart`)**:
   - Permission requests are serialized through `_permissionFuture` in `NotificationService.ensureReminderPermissions()`, preventing Android's `"Can request only one set of permissions at a time"` cancellation when `FcmService` and `NotificationService` initialize concurrently.
3. **Preserved `notification_sent` Across Cloud Syncs (`sync_service.py`)**:
   - `SyncService.apply_push` only resets `notification_sent = False` when `due_at` moves forward into the future, preventing repeat push notification storms for already-fired reminders.
4. **Automatic Pruning of Unregistered FCM Tokens (`fcm_service.py`)**:
   - `_remove_stale_token` deletes dead tokens from PostgreSQL `device_tokens` immediately upon `messaging.UnregisteredError`.
5. **Authenticated FCM Token Binding & Startup Re-Arming (`home_reminder_provider.dart`)**:
   - Device FCM token registration runs after device auth token registration completes so the token binds to the right `user_id`, and active future reminders are re-armed in local `AlarmManager` on startup and sync pull.

---

## 1. Problem Statement & Root Cause

1. **Immediate False-Positive Alarm Triggering**:
   - `NotificationService.scheduleReminder()` previously contained short-circuit checks that invoked `_notificationsPlugin.show(...)` immediately if a reminder was scheduled within 15 seconds or if a timezone comparison fell within a small window.
   - When users set reminders for times close to current time (e.g. 1:35 AM when the clock was 1:33:50 AM), the alert fired instantly in the user's face at creation time, returned early, and never registered with Android's native `AlarmManager`.
   - On Android 12–14 (and Xiaomi HyperOS), `exactAllowWhileIdle` threw an `ExactAlarmPermissionException` when exact alarms were not yet toggled on in OS settings. The previous fallback caught this and displayed the alert immediately rather than scheduling via safe inexact fallback.

2. **Conversational Intent Collisions**:
   - In `PingoFlowScreen`, follow-up utterances such as `"please cancel this reminder"` or `"all new modification date"` were routed directly into the reminder creation pipeline, creating unwanted reminders instead of canceling active reminders.

3. **Exposed Technical "AI" Branding**:
   - The UI displayed an `"AI"` spinner in the top bar and `"Scheduling with AI..."` loading text. For a consumer-grade companion app, internal implementation details (LLM, AI, APIs) must be abstracted into a delightful, personal assistant experience.

---

## 2. Technical Implementation

### 2.1 Punctual Alarm & AlarmManager Hardening (`NotificationService.dart`)
- **Zero Immediate Alerts**: Completely removed all `_notificationsPlugin.show(...)` invocations from `scheduleReminder()`. Reminders are *exclusively* scheduled for future execution.
- **Future-Proof Timestamp Guarantee**: If `targetTz` is within 10 seconds of `now` or slightly in the past (due to the current minute ticking away), it is automatically pushed forward to at least 15 seconds in the future (`tzNow.add(const Duration(seconds: 15))`), preventing `validateDateIsInTheFuture` from throwing.
- **Dynamic Permission Detection**:
  - Uses `canScheduleExactNotifications()` on Android.
  - If exact alarms are permitted: schedules with `AndroidScheduleMode.exactAllowWhileIdle`.
  - If exact alarms are not permitted: schedules with `AndroidScheduleMode.inexactAllowWhileIdle` and proactively prompts the user via `requestExactAlarmsPermission()`.
- **Xiaomi HyperOS & Android Audio Priority**:
  - Set `category: AndroidNotificationCategory.alarm`.
  - Set `audioAttributesUsage: AudioAttributesUsage.alarm`.
  - This ensures Android routes audio through the Alarm stream, bypassing normal ringtone muting and aggressive Doze battery optimization.

### 2.2 Conversational Flow Intent Prioritization (`PingoFlowScreen.dart`)
- **Priority Routing**:
  1. **Instant Test Alerts**: Handled first. Triggers test alert and provides complete diagnostic reports on both notification banner and exact alarm permissions.
  2. **Cancellations & Deletions**: Checked before any other scenario (`cancel`, `delete`, `remove`, `বাতিল`, `ক্যান্সেল`, `মুছে`, `বাদ`).
  3. **Task Queries**: Checked before new reminder parsing (`what do I have`, `tasks`, `আজকে কি আছে`, `কালকে কি আছে`).
  4. **Question Mode Protection**: Only valid time utterances update the question state; non-time utterances do not create accidental reminders.

### 2.3 Zero-AI Branding
- Removed the top-bar `"AI"` badge and progress indicator.
- Updated loading state from `"Scheduling with AI..."` to `"Pingo is remembering..."`.
- Updated bot state from `"Pingo is thinking..."` to `"Organizing..."`.
- Sanitized user-facing UI labels across the app.

---

## 3. Verification & Quality Gates

- `flutter analyze`: **0 errors**.
- `flutter test`: **14/14 tests passing** (100% green).
- `flutter build apk --release`: Successfully generated production APK (`app-release.apk`).

