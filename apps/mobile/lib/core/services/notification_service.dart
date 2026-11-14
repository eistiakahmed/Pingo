import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Production-grade Local Notification & Alarm Service for Pingo.
/// Provides offline-first, zero-knowledge punctual alerts via Android AlarmManager.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  static const String _defaultChannelId = 'pingo_reminders_channel_v2';
  static const String _defaultChannelName = 'Pingo Reminders';
  static const String _defaultChannelDesc =
      'Punctual alarms and task notifications from Pingo';

  static const String _urgentChannelId = 'pingo_urgent_channel_v2';
  static const String _urgentChannelName = 'Urgent Reminders';
  static const String _urgentChannelDesc =
      'High-priority alarms for medicine and critical deadlines';

  /// Initializes the local notification plugin, creates channels, and detects device timezone.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Initialize timezone database and detect device's actual native timezone
      tz.initializeTimeZones();
      try {
        final TimezoneInfo tzInfo = await FlutterTimezone.getLocalTimezone();
        final String currentTimeZone = tzInfo.identifier;
        tz.setLocalLocation(tz.getLocation(currentTimeZone));
        debugPrint(
            '[NotificationService] Configured local timezone: $currentTimeZone');
      } catch (tzError) {
        debugPrint(
            '[NotificationService] Could not auto-detect timezone ($tzError). Falling back to Asia/Dhaka.');
        try {
          tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));
        } catch (_) {}
      }

      // 2. Android platform settings
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // 3. iOS / macOS settings
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      // 4. Linux settings
      final linuxSettings = LinuxInitializationSettings(
        defaultActionName: 'Open Pingo',
      );

      final initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
        linux: linuxSettings,
      );

      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint(
              '[NotificationService] Notification tapped: ${response.payload}');
        },
      );

      // 5. Create Android Notification Channels with Max Importance (Heads-Up Popup + Sound)
      if (!kIsWeb && Platform.isAndroid) {
        final androidImplementation = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        if (androidImplementation != null) {
          const defaultChannel = AndroidNotificationChannel(
            _defaultChannelId,
            _defaultChannelName,
            description: _defaultChannelDesc,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            enableLights: true,
          );

          const urgentChannel = AndroidNotificationChannel(
            _urgentChannelId,
            _urgentChannelName,
            description: _urgentChannelDesc,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            enableLights: true,
          );

          await androidImplementation.createNotificationChannel(defaultChannel);
          await androidImplementation.createNotificationChannel(urgentChannel);
        }
      }

      _isInitialized = true;
      debugPrint('[NotificationService] Initialized successfully.');
    } catch (e, stack) {
      debugPrint('[NotificationService] Initialization failed: $e\n$stack');
    }
  }

  /// Requests Android runtime notification and exact alarm permissions.
  Future<void> requestPermissions() async {
    if (!kIsWeb && Platform.isAndroid) {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        final notifGranted =
            await androidImplementation.requestNotificationsPermission();
        final exactGranted =
            await androidImplementation.requestExactAlarmsPermission();
        debugPrint(
            '[NotificationService] Permissions -> Notifications: $notifGranted, Exact Alarms: $exactGranted');
      }
    }
  }

  /// Schedules a punctual notification at the specified [scheduledDate].
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    bool isUrgent = false,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Ensure 32-bit positive integer for Android PendingIntent
    final safeId = id.abs() % 2147483647;

    final androidDetails = AndroidNotificationDetails(
      isUrgent ? _urgentChannelId : _defaultChannelId,
      isUrgent ? _urgentChannelName : _defaultChannelName,
      channelDescription:
          isUrgent ? _urgentChannelDesc : _defaultChannelDesc,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.reminder,
      ticker: title,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    final now = DateTime.now();
    // If the scheduled date is now, in the past, or within the next 15 seconds, show the alert immediately!
    if (scheduledDate.isBefore(now.add(const Duration(seconds: 15)))) {
      debugPrint(
          '[NotificationService] Trigger date $scheduledDate is immediate or within 15s. Showing alert now!');
      await _notificationsPlugin.show(
        safeId,
        title,
        body,
        notificationDetails,
        payload: 'reminder_$safeId',
      );
      return;
    }

    try {
      final tzDateTime = tz.TZDateTime.from(scheduledDate, tz.local);
      final tzNow = tz.TZDateTime.now(tz.local);

      // If timezone converted date is within 5 seconds of now or in the past, show immediately!
      if (tzDateTime.isBefore(tzNow.add(const Duration(seconds: 5)))) {
        debugPrint(
            '[NotificationService] tzDateTime ($tzDateTime) is too close to now. Showing alert now!');
        await _notificationsPlugin.show(
          safeId,
          title,
          body,
          notificationDetails,
          payload: 'reminder_$safeId',
        );
        return;
      }

      await _notificationsPlugin.zonedSchedule(
        safeId,
        title,
        body,
        tzDateTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'reminder_$safeId',
      );

      debugPrint(
          '[NotificationService] Successfully scheduled reminder #$safeId for $tzDateTime (local epoch: ${tzDateTime.millisecondsSinceEpoch}): "$title"');
    } catch (e) {
      debugPrint('[NotificationService] Exact alarm failed, trying inexact fallback: $e');
      try {
        final tzDateTime = tz.TZDateTime.from(scheduledDate, tz.local);
        await _notificationsPlugin.zonedSchedule(
          safeId,
          title,
          body,
          tzDateTime,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'reminder_$safeId',
        );
      } catch (fallbackError) {
        debugPrint(
            '[NotificationService] Inexact schedule failed ($fallbackError). Showing alert now.');
        await _notificationsPlugin.show(
          safeId,
          title,
          body,
          notificationDetails,
          payload: 'reminder_$safeId',
        );
      }
    }
  }

  /// Checks if notifications are permitted on the device.
  Future<bool> areNotificationsEnabled() async {
    if (!kIsWeb && Platform.isAndroid) {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        final enabled = await androidImplementation.areNotificationsEnabled();
        return enabled ?? false;
      }
    }
    return true;
  }

  /// Shows an instant test notification.
  Future<bool> showInstantTestNotification({
    String title = 'Pingo Test Alert 🔔',
    String body = 'Notifications and alarms are active and working on your phone!',
  }) async {
    if (!_isInitialized) await initialize();
    const androidDetails = AndroidNotificationDetails(
      _defaultChannelId,
      _defaultChannelName,
      channelDescription: _defaultChannelDesc,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.reminder,
    );
    const details = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(999999, title, body, details);
    return true;
  }

  /// Cancels a scheduled notification by its ID.
  Future<void> cancelReminder(int id) async {
    try {
      final safeId = id.abs() % 2147483647;
      await _notificationsPlugin.cancel(safeId);
      debugPrint('[NotificationService] Cancelled reminder #$safeId');
    } catch (e) {
      debugPrint('[NotificationService] Failed to cancel reminder: $e');
    }
  }

  /// Cancels all scheduled notifications.
  Future<void> cancelAll() async {
    try {
      await _notificationsPlugin.cancelAll();
      debugPrint('[NotificationService] Cancelled all reminders.');
    } catch (e) {
      debugPrint('[NotificationService] Failed to cancel all: $e');
    }
  }
}
