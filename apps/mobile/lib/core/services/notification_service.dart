import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

  static const String _defaultChannelId = 'pingo_reminders_channel';
  static const String _defaultChannelName = 'Pingo Reminders';
  static const String _defaultChannelDesc =
      'Punctual alarms and task notifications from Pingo';

  static const String _urgentChannelId = 'pingo_urgent_channel';
  static const String _urgentChannelName = 'Urgent Reminders';
  static const String _urgentChannelDesc =
      'High-priority alarms for medicine and critical deadlines';

  /// Initializes the local notification plugin, creates channels, and requests permissions.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Initialize timezone database
      tz.initializeTimeZones();

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

      // 5. Create Android Notification Channels (API 26+)
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

          // Request runtime notification permission (Android 13+)
          await androidImplementation.requestNotificationsPermission();
          // Request exact alarms permission (Android 14+)
          await androidImplementation.requestExactAlarmsPermission();
        }
      }

      _isInitialized = true;
      debugPrint('[NotificationService] Initialized successfully.');
    } catch (e, stack) {
      debugPrint('[NotificationService] Initialization failed: $e\n$stack');
    }
  }

  /// Schedules a punctual notification at the exact specified [scheduledDate].
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

    // If the scheduled date is in the past, do not schedule
    if (scheduledDate.isBefore(DateTime.now())) {
      debugPrint(
          '[NotificationService] Cannot schedule in the past: $scheduledDate');
      return;
    }

    try {
      final tzDateTime = tz.TZDateTime.from(scheduledDate, tz.local);

      final androidDetails = AndroidNotificationDetails(
        isUrgent ? _urgentChannelId : _defaultChannelId,
        isUrgent ? _urgentChannelName : _defaultChannelName,
        channelDescription:
            isUrgent ? _urgentChannelDesc : _defaultChannelDesc,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        fullScreenIntent: isUrgent,
        category: AndroidNotificationCategory.reminder,
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

      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzDateTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'reminder_$id',
      );

      debugPrint(
          '[NotificationService] Successfully scheduled reminder #$id for $tzDateTime: "$title"');
    } catch (e) {
      debugPrint('[NotificationService] Failed to schedule reminder #$id: $e');
    }
  }

  /// Cancels a scheduled notification by its ID.
  Future<void> cancelReminder(int id) async {
    try {
      await _notificationsPlugin.cancel(id);
      debugPrint('[NotificationService] Cancelled reminder #$id');
    } catch (e) {
      debugPrint('[NotificationService] Failed to cancel reminder #$id: $e');
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

