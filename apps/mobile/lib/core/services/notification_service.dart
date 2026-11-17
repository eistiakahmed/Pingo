import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
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
  /// Alarms are always scheduled for the future in Android AlarmManager and NEVER trigger immediately at creation time.
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

    final String timeStr = DateFormat.jm().format(scheduledDate);
    final String dateStr = DateFormat.MMMd().format(scheduledDate);

    final displayBody = (body.isNotEmpty && body != 'Scheduled alert from Pingo')
        ? body
        : '⏰ $timeStr · $dateStr';

    final styleInfo = BigTextStyleInformation(
      displayBody,
      htmlFormatBigText: false,
      contentTitle: title,
      htmlFormatContentTitle: false,
      summaryText: 'Pingo Reminder',
    );

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
      styleInformation: styleInfo,
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

    try {
      final tz.TZDateTime tzNow = tz.TZDateTime.now(tz.local);
      tz.TZDateTime targetTz = tz.TZDateTime.from(scheduledDate, tz.local);

      // If scheduled time is within 10 seconds of now or in the past (e.g. current minute ticking away),
      // push it forward to at least 15 seconds from now so it is guaranteed to be in the future
      // and satisfies Android AlarmManager requirements.
      if (targetTz.isBefore(tzNow.add(const Duration(seconds: 10)))) {
        targetTz = tzNow.add(const Duration(seconds: 15));
        debugPrint(
            '[NotificationService] Target date was too close to current time. Pushed forward to: $targetTz');
      }

      // Check whether exact alarms are permitted on this device
      bool canExact = true;
      if (!kIsWeb && Platform.isAndroid) {
        final androidPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        canExact = await androidPlugin?.canScheduleExactNotifications() ?? true;
        if (!canExact) {
          debugPrint(
              '[NotificationService] Exact alarms not permitted by OS. Prompting user...');
          await androidPlugin?.requestExactAlarmsPermission();
        }
      }

      // Priority 1: Schedule as a native system AlarmClock (highest Android OS priority, exempt from Doze & Xiaomi killers)
      try {
        await _notificationsPlugin.zonedSchedule(
          safeId,
          title,
          displayBody,
          targetTz,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.alarmClock,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'reminder_$safeId',
        );
        debugPrint(
            '[NotificationService] Successfully scheduled reminder #$safeId as native AlarmClock for $targetTz');
        return;
      } catch (alarmClockErr) {
        debugPrint(
            '[NotificationService] AlarmClock schedule error ($alarmClockErr). Falling back to exactAllowWhileIdle...');
      }

      // Priority 2: Schedule with exactAllowWhileIdle or inexactAllowWhileIdle
      final scheduleMode = canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      await _notificationsPlugin.zonedSchedule(
        safeId,
        title,
        displayBody,
        targetTz,
        notificationDetails,
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'reminder_$safeId',
      );

      debugPrint(
          '[NotificationService] Successfully scheduled reminder #$safeId for $targetTz with mode $scheduleMode');
    } catch (e) {
      debugPrint('[NotificationService] Primary schedule failed: $e. Retrying with safe fallback...');
      try {
        final tz.TZDateTime tzNow = tz.TZDateTime.now(tz.local);
        final fallbackTz = tzNow.add(const Duration(seconds: 15));
        await _notificationsPlugin.zonedSchedule(
          safeId,
          title,
          displayBody,
          fallbackTz,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'reminder_$safeId',
        );
        debugPrint('[NotificationService] Fallback scheduled for $fallbackTz');
      } catch (fallbackError) {
        debugPrint('[NotificationService] Fatal: could not register alarm with AlarmManager: $fallbackError');
      }
    }
  }

  /// Checks if exact alarms are permitted on Android.
  Future<bool> canScheduleExactAlarms() async {
    if (!kIsWeb && Platform.isAndroid) {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        final canExact =
            await androidImplementation.canScheduleExactNotifications();
        return canExact ?? false;
      }
    }
    return true;
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

  /// Shows an instant test notification styled with dynamic user title and body.
  Future<bool> showInstantTestNotification({
    String title = 'Pingo Test Alert',
    String body = 'Alarms and notification engine are fully operational.',
  }) async {
    if (!_isInitialized) await initialize();
    final styleInfo = BigTextStyleInformation(
      body,
      htmlFormatBigText: false,
      contentTitle: title,
      htmlFormatContentTitle: false,
      summaryText: 'Pingo Test',
    );
    final androidDetails = AndroidNotificationDetails(
      _urgentChannelId,
      _urgentChannelName,
      channelDescription: _urgentChannelDesc,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.reminder,
      ticker: title,
      styleInformation: styleInfo,
    );
    final details = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(999999, title, body, details);
    return true;
  }

  /// Displays an incoming FCM Push Notification directly as a high-priority heads-up banner.
  Future<void> showPushNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) await initialize();
    final safeId = id.abs() % 2147483647;

    final styleInfo = BigTextStyleInformation(
      body,
      htmlFormatBigText: false,
      contentTitle: title,
      htmlFormatContentTitle: false,
      summaryText: 'Pingo Alert',
    );

    final androidDetails = AndroidNotificationDetails(
      _urgentChannelId,
      _urgentChannelName,
      channelDescription: _urgentChannelDesc,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.reminder,
      ticker: title,
      styleInformation: styleInfo,
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
    );

    try {
      await _notificationsPlugin.show(
        safeId,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
      debugPrint('[NotificationService] Displayed push notification #$safeId: "$title"');
    } catch (e) {
      debugPrint('[NotificationService] Error displaying push notification: $e');
    }
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
