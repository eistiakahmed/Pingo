import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:pingo_mobile/core/network/api_config.dart';
import 'package:pingo_mobile/core/services/notification_service.dart';
import 'package:pingo_mobile/core/storage/local_storage_service.dart';

/// Top-level background message handler for Firebase Cloud Messaging.
/// Must be annotated with `@pragma('vm:entry-point')` for native Android isolate dispatch.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();
    await NotificationService.instance.initialize();

    debugPrint('[FCM Background] Received message: ${message.messageId}');
    final notification = message.notification;
    final data = message.data;

    final String title = notification?.title ?? data['title'] ?? 'Pingo';
    final String body = notification?.body ??
        data['body'] ??
        'You have a scheduled reminder right now.';

    await NotificationService.instance.showPushNotification(
      id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title: title,
      body: body,
      payload: jsonEncode(data),
    );
  } catch (e, stack) {
    debugPrint('[FCM Background] Handler error: $e\n$stack');
  }
}

/// Production-grade Firebase Cloud Messaging (FCM) Service for Pingo.
/// Dispatches high-priority push notifications to wake Xiaomi HyperOS / Android devices.
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  bool _isInitialized = false;
  String? _fcmToken;

  String? get fcmToken => _fcmToken;

  /// Initializes Firebase and configures notification streams.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await Firebase.initializeApp();
      debugPrint('[FcmService] Firebase app initialized.');

      // 1. Request notification permissions with critical alert support
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: true,
        provisional: false,
        sound: true,
      );

      debugPrint(
          '[FcmService] Authorization status: ${settings.authorizationStatus}');

      // 2. Set foreground presentation options (alert, badge, sound)
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 3. Register background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 4. Retrieve initial device token
      _fcmToken = await messaging.getToken();
      debugPrint('[FcmService] Retrieved FCM Device Token: $_fcmToken');

      if (_fcmToken != null) {
        await _registerTokenWithBackend(_fcmToken!);
      }

      // 5. Listen to token refresh events
      messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('[FcmService] FCM token refreshed: $newToken');
        _fcmToken = newToken;
        await _registerTokenWithBackend(newToken);
      });

      // 6. Foreground message listener (App is open on screen)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        try {
          debugPrint(
              '[FcmService] Foreground message arrived: ${message.messageId}');
          final notification = message.notification;
          final data = message.data;

          final String title = notification?.title ?? data['title'] ?? 'Pingo';
          final String body = notification?.body ??
              data['body'] ??
              'You have a scheduled reminder right now.';

          await NotificationService.instance.showPushNotification(
            id: message.messageId?.hashCode ??
                DateTime.now().millisecondsSinceEpoch,
            title: title,
            body: body,
            payload: jsonEncode(data),
          );
        } catch (e, stack) {
          debugPrint('[FcmService] Foreground push processing error: $e\n$stack');
        }
      });

      // 7. Notification clicked while app was in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint(
            '[FcmService] User tapped notification from background: ${message.data}');
      });

      // 8. Notification opened app from terminated state
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint(
            '[FcmService] App launched from terminated state via notification: ${initialMessage.data}');
      }

      _isInitialized = true;
      debugPrint('[FcmService] Initialized successfully.');
    } catch (e, stack) {
      debugPrint('[FcmService] Initialization error: $e\n$stack');
    }
  }

  /// Sends the FCM device token to the FastAPI backend.
  Future<bool> registerActiveToken() async {
    if (_fcmToken == null) {
      try {
        _fcmToken = await FirebaseMessaging.instance.getToken();
      } catch (_) {}
    }
    if (_fcmToken != null) {
      return await _registerTokenWithBackend(_fcmToken!);
    }
    return false;
  }

  Future<bool> _registerTokenWithBackend(String token) async {
    try {
      final authToken = await LocalStorageService.instance.getAuthToken();
      final url = Uri.parse(ApiConfig.registerDeviceToken);

      final headers = <String, String>{
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
      };
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      final response = await http
          .post(
            url,
            headers: headers,
            body: jsonEncode({
              'token': token,
              'platform': 'android',
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[FcmService] Registered device token with backend.');
        return true;
      } else {
        debugPrint(
            '[FcmService] Device token registration returned ${response.statusCode}: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint(
          '[FcmService] Non-fatal: could not send FCM token to backend ($e). Will retry on next sync.');
      return false;
    }
  }

  /// Dispatches a real-time test push notification from the FastAPI backend to this device.
  Future<bool> triggerBackendTestPush() async {
    try {
      final token = _fcmToken ?? await FirebaseMessaging.instance.getToken();
      if (token == null) return false;
      final authToken = await LocalStorageService.instance.getAuthToken();
      final url = Uri.parse(ApiConfig.testPush);

      final headers = <String, String>{
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
      };
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      final response = await http
          .post(
            url,
            headers: headers,
            body: jsonEncode({
              'token': token,
              'title': 'Pingo Test Alert',
              'body': 'Backend push notification is working perfectly!',
            }),
          )
          .timeout(const Duration(seconds: 10));

      debugPrint(
          '[FcmService] Backend test push response: ${response.statusCode} - ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[FcmService] Backend test push request failed: $e');
      return false;
    }
  }
}
