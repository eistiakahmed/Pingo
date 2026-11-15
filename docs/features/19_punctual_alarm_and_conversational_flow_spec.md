# Feature Spec: Punctual Alarms & Conversational Flow Hardening

**Document ID**: `docs/features/19_punctual_alarm_and_conversational_flow_spec.md`  
**Status**: Implemented & Verified  
**Target Release**: Pingo Mobile v1.0.0-rc3  

---

## 1. Executive Summary & Root Cause Analysis

### 1.1 Root Causes of Reported Issues
1. **Missed 12:00 AM Notification / Midnight Rollover**:
   - When a user scheduled a reminder for "12 AM", Dart's `DateTime` parser treated 12:00 AM as `00:00:00` of the current calendar day.
   - If scheduled in the evening or afternoon, `scheduledDate.isBefore(DateTime.now())` evaluated to `true` (referencing 23 hours in the past), causing `NotificationService` to skip alarm registration.
   - **Resolution**: Implemented automatic date rollover in `_calculateDueAt()`: any target scheduled for "Today" that has already passed rolls over to the upcoming occurrence (`target.add(const Duration(days: 1))`). If a notification timestamp is within 1 minute or in the past, an instant heads-up alert is triggered immediately rather than dropped.

2. **Timezone Misalignment**:
   - `tz.initializeTimeZones()` in package `timezone` defaults `tz.local` to UTC unless explicitly configured.
   - Converting local device timestamps via `tz.TZDateTime.from(scheduledDate, tz.local)` resulted in alarms firing 6 hours off or getting discarded.
   - **Resolution**: Integrated `flutter_timezone: ^5.1.1` to detect device IANA identifier (`TimezoneInfo.identifier`), setting `tz.setLocalLocation(tz.getLocation(tzInfo.identifier))` with automatic fallback to `'Asia/Dhaka'`.

3. **Android 13/14+ and MIUI / HyperOS Restrictions**:
   - Android 13+ requires `POST_NOTIFICATIONS` runtime permission.
   - Android 14+ requires `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` permissions.
   - Missing `ScheduledNotificationReceiver` and `ScheduledNotificationBootReceiver` in `AndroidManifest.xml` prevented background alarms from triggering when the app is closed or across device reboots.
   - **Resolution**: Declared receivers in `AndroidManifest.xml`, requested permissions on home screen post-frame callback, and created high-importance notification channels (`Importance.max`, `Priority.max`, `visibility: NotificationVisibility.public`, `category: AndroidNotificationCategory.alarm`).

4. **Conversational Flow & Heuristic Fallback**:
   - When AI returned `due_at: null` or faced network hiccups, `PingoFlowScreen` erroneously downgraded to `FlowScenario.askQuestion`, displaying "Not saved yet / What time should I remind you?" even when the user explicitly said "9 AM tomorrow" or "kalke 9 tar somoy".
   - Follow-up conversational text like "please cancel this reminder" or "all new modification date" previously fell through into new task creation.
   - **Resolution**:
     - Added `_hasTimeHeuristic()` to detect explicit time/date cues. If AI fails to return `due_at`, Pingo automatically schedules the reminder locally without confusing the user.
     - Hardened command router in `_handleSend()`: "cancel" / "delete" commands delete the active reminder or most recent reminder; "modify" / "change" commands prompt for the desired time adjustment without creating junk reminders.

---

## 2. Affected System Components

| File | Change Description |
| :--- | :--- |
| `apps/mobile/android/app/src/main/AndroidManifest.xml` | Added `ScheduledNotificationReceiver` and `ScheduledNotificationBootReceiver`. |
| `apps/mobile/lib/core/services/notification_service.dart` | Fixed `TimezoneInfo.identifier`, heads-up notification channels, safe 31-bit IDs, instant alert fallback. |
| `apps/mobile/lib/features/home/presentation/screens/pingo_home_screen.dart` | Permission request hook on app initialization. |
| `apps/mobile/lib/features/session_chat/presentation/screens/pingo_flow_screen.dart` | Date rollover, heuristic auto-save fallback, safe cancellation routing, question answering router. |
| `apps/mobile/lib/features/home/presentation/state/home_reminder_provider.dart` | Cleaned unused imports and unified reminder mutations. |

---

## 3. Verification & Test Evidence

- `flutter analyze`: **0 errors**.
- `flutter test`: **14 unit and integration tests passed** (100% green).
- `flutter build apk --release`: Successfully generated `app-release.apk` (57.0MB).

