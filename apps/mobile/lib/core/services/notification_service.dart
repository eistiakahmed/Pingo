import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
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
  Future<void>? _initFuture;
  Future<bool>? _permissionFuture;

  static const String _defaultChannelId = 'pingo_reminders_channel_v3';
  static const String _defaultChannelName = 'Pingo Reminders';
  static const String _defaultChannelDesc =
      'Punctual alarms and task notifications from Pingo';

  static const String _urgentChannelId = 'pingo_urgent_channel_v3';
  static const String _urgentChannelName = 'Urgent Reminders';
  static const String _urgentChannelDesc =
      'High-priority alarms for medicine and critical deadlines';

  /// Initializes the local notification plugin, creates channels, and detects device timezone.
  Future<void> initialize() {
    if (_isInitialized) return Future.value();
    return _initFuture ??= _initializeInternal();
  }

  Future<void> _initializeInternal() async {
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
      const linuxSettings = LinuxInitializationSettings(
        defaultActionName: 'Open Pingo',
      );

      const initSettings = InitializationSettings(
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
            audioAttributesUsage: AudioAttributesUsage.alarm,
          );

          const urgentChannel = AndroidNotificationChannel(
            _urgentChannelId,
            _urgentChannelName,
            description: _urgentChannelDesc,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            enableLights: true,
            audioAttributesUsage: AudioAttributesUsage.alarm,
          );

          await androidImplementation.createNotificationChannel(defaultChannel);
          await androidImplementation.createNotificationChannel(urgentChannel);
        }
      }

      _isInitialized = true;
      debugPrint('[NotificationService] Initialized successfully.');
    } catch (e, stack) {
      _initFuture = null;
      debugPrint('[NotificationService] Initialization failed: $e\n$stack');
    }
  }

  /// Requests Android runtime notification and exact alarm permissions.
  Future<bool> requestPermissions() async {
    return ensureReminderPermissions();
  }

  /// Ensures notification & exact-alarm access without unnecessarily launching Settings
  /// when `USE_EXACT_ALARM` is already granted by the manifest.
  /// Serialized via [_permissionFuture] so concurrent callers never trigger Android's
  /// "Can request only one set of permissions at a time" cancellation bug.
  Future<bool> ensureReminderPermissions({bool openSettingsOnDeny = false}) {
    if (kIsWeb || !Platform.isAndroid) return Future.value(true);
    return _permissionFuture ??=
        _ensureReminderPermissionsInternal(openSettingsOnDeny: openSettingsOnDeny)
            .whenComplete(() => _permissionFuture = null);
  }

  Future<bool> _ensureReminderPermissionsInternal({
    required bool openSettingsOnDeny,
  }) async {
    if (!_isInitialized) await initialize();

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    // 1. Check / request POST_NOTIFICATIONS via one unified channel
    bool notifEnabled = await androidPlugin?.areNotificationsEnabled() ?? false;
    if (!notifEnabled) {
      if (androidPlugin != null) {
        notifEnabled =
            await androidPlugin.requestNotificationsPermission() ?? false;
      }
      if (!notifEnabled) {
        final status = await ph.Permission.notification.request();
        notifEnabled = status.isGranted || status.isLimited;
      }
      if (!notifEnabled && openSettingsOnDeny) {
        await ph.openAppSettings();
        return false;
      }
    }

    // 2. Check exact alarm capability via AlarmManager before requesting
    if (androidPlugin != null) {
      final canExact =
          await androidPlugin.canScheduleExactNotifications() ?? true;
      if (!canExact) {
        await androidPlugin.requestExactAlarmsPermission();
      }
    }

    return notifEnabled;
  }

  /// Schedules a punctual notification at the specified [scheduledDate].
  /// Never fires prematurely for future dates and skips dates that are already in the past.
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

    await ensureReminderPermissions();

    // Ensure 32-bit positive integer for Android PendingIntent
    final safeId = id.abs() % 2147483647;

    final DateTime localDate = scheduledDate.toLocal();
    final String timeStr = DateFormat.jm().format(localDate);
    final String dateStr = DateFormat.MMMd().format(localDate);

    final displayBody = (body.isNotEmpty && body != 'Scheduled alert from Pingo')
        ? body
        : '$timeStr · $dateStr';

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
      fullScreenIntent: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.alarm,
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
      tz.TZDateTime targetTz = tz.TZDateTime.from(localDate, tz.local);

      // If the reminder is more than 30 seconds in the past, do NOT schedule a false immediate alarm.
      if (targetTz.isBefore(tzNow.subtract(const Duration(seconds: 30)))) {
        debugPrint(
            '[NotificationService] Skipping alarm #$safeId because scheduledDate ($targetTz) is in the past.');
        return;
      }

      // If scheduled within the next 5 seconds (e.g. current minute boundary), nudge 5s ahead.
      if (targetTz.isBefore(tzNow.add(const Duration(seconds: 5)))) {
        targetTz = tzNow.add(const Duration(seconds: 5));
      }

      // Priority 1: Native system AlarmClock (exempt from Android Doze)
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
            '[NotificationService] Scheduled reminder #$safeId as native AlarmClock for $targetTz');
        return;
      } catch (alarmClockErr) {
        debugPrint(
            '[NotificationService] AlarmClock mode failed ($alarmClockErr). Trying exactAllowWhileIdle...');
      }

      // Priority 2: exactAllowWhileIdle at the exact targetTz
      try {
        await _notificationsPlugin.zonedSchedule(
          safeId,
          title,
          displayBody,
          targetTz,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'reminder_$safeId',
        );
        debugPrint(
            '[NotificationService] Scheduled reminder #$safeId with exactAllowWhileIdle for $targetTz');
        return;
      } catch (exactErr) {
        debugPrint(
            '[NotificationService] exactAllowWhileIdle failed ($exactErr). Falling back to inexactAllowWhileIdle at targetTz...');
      }

      // Priority 3: inexactAllowWhileIdle at targetTz (NEVER 15s from now!)
      await _notificationsPlugin.zonedSchedule(
        safeId,
        title,
        displayBody,
        targetTz,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'reminder_$safeId',
      );
      debugPrint(
          '[NotificationService] Scheduled reminder #$safeId with inexactAllowWhileIdle for $targetTz');
    } catch (e) {
      debugPrint(
          '[NotificationService] Fatal: could not register alarm #$safeId: $e');
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
    String title = 'Pingo test alert',
    String body = 'Alarms and notifications are operational',
  }) async {
    if (!_isInitialized) await initialize();
    final permitted =
        await ensureReminderPermissions(openSettingsOnDeny: true);
    if (!permitted) return false;

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
      fullScreenIntent: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.alarm,
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
    await ensureReminderPermissions();
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
      fullScreenIntent: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.alarm,
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
      debugPrint(
          '[NotificationService] Displayed push notification #$safeId: "$title"');
    } catch (e) {
      debugPrint(
          '[NotificationService] Error displaying push notification: $e');
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
