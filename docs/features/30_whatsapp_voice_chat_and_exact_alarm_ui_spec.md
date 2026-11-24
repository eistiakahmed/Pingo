# Feature Specification: WhatsApp-Style Voice Chat & Exact Alarm UI

**Specification ID**: `SPEC-30-WHATSAPP-VOICE-CHAT-UI`  
**Date**: November 24, 2026  
**Scope**: Flutter Mobile App (`record` `.m4a` hold-to-record, `MultipartRequest` to `POST /api/voice-command`, `just_audio` Play/Pause voice note bubble + auto-play, `flutter_local_notifications` `exactAllowWhileIdle` alarm + triggered chat bubble)  

---

## 1. Architecture & Components

1. **Permissions & Network (`AndroidManifest.xml` & `ApiConfig`)**:
   - `RECORD_AUDIO`, `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`, `POST_NOTIFICATIONS`, `VIBRATE`, `WAKE_LOCK`, and `android:usesCleartextTraffic="true"`.
   - `ApiConfig.voiceCommand` -> `$baseUrl/api/voice-command` and `ApiConfig.resolveMediaUrl(audioUrl)` -> `$baseUrl$audioUrl`.
2. **Hold-to-Record `.m4a` & Multipart Upload (`PingoHomeScreen` + `VoiceCommandApiService`)**:
   - Bottom composer microphone uses `GestureDetector(onLongPressStart, onLongPressEnd, onLongPressCancel)` to record AAC-LC `.m4a` audio via `AudioRecorder` (`record` package).
   - Uploads via `http.MultipartRequest('POST', Uri.parse(ApiConfig.voiceCommand))` with fields `user_id` and `audio` (file), then deletes the temporary `.m4a` file.
3. **WhatsApp-Style Voice Bubble & Auto-Play (`VoiceAudioPlayerService` + `ChatMessageBubble`)**:
   - Displays `user_said` on the right and `ai_reply` on the left with an interactive Play/Pause audio bar, seek slider, and duration counter powered by `just_audio`, auto-playing `$baseUrl$audioUrl` immediately on arrival.
4. **Exact Scheduled Alarm & Triggered Chat Bubble (`NotificationService` + `PingoChatNotifier`)**:
   - Parses every `action["tool"] == "set_reminder"` (`task_title`, ISO 8601 `reminder_time`), saves to `HomeReminderNotifier`, and schedules via `flutter_local_notifications` (`zonedSchedule` with `AndroidScheduleMode.exactAllowWhileIdle`, sound, and vibration).
   - Emits `NotificationService.instance.onAlarmTriggered` when the scheduled time arrives (and reconciles on app resume if triggered while backgrounded) so a `🔔 Reminder: <task_title>` bubble is automatically inserted into the chat UI.
