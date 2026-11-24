import 'dart:io';
import 'package:flutter/foundation.dart';

/// Application API Gateway Configuration and Endpoints
class ApiConfig {
  ApiConfig._();

  /// Production AWS API Gateway URL
  static const String productionBaseUrl = 'http://98.84.163.177';

  /// Default API Base URL based on runtime build mode and platform
  static String get defaultBaseUrl {
    const fromEnv = String.fromEnvironment('PINGO_API_URL');
    if (fromEnv.isNotEmpty) return fromEnv;

    if (kReleaseMode) {
      return productionBaseUrl;
    }

    try {
      if (Platform.isAndroid) {
        // Android emulator localhost alias in debug mode
        return 'http://10.0.2.2:8000';
      }
    } catch (_) {
      // Non-io environment or web fallback
    }
    return 'http://127.0.0.1:8000';
  }

  static String baseUrl = defaultBaseUrl;

  // Endpoint routes
  static const String prefixV1 = '/api/v1';

  static String get health => '$baseUrl/health';
  static String get authRegister => '$baseUrl$prefixV1/auth/register';
  static String get authLogin => '$baseUrl$prefixV1/auth/login';
  static String get authMe => '$baseUrl$prefixV1/auth/me';
  static String get aiParseReminder => '$baseUrl$prefixV1/ai/parse-reminder';
  static String get syncPush => '$baseUrl$prefixV1/sync/push';
  static String get syncPull => '$baseUrl$prefixV1/sync/pull';
  static String get registerDeviceToken => '$baseUrl$prefixV1/devices/register-token';
  static String get testPush => '$baseUrl$prefixV1/devices/test-push';
  static String get voiceCommand => '$baseUrl/api/voice-command';
  static String get attachmentsStage => '$baseUrl/api/attachments/stage';
  static String get attachmentsStaged => '$baseUrl/api/attachments/staged';
  static String get assistantMessage => '$baseUrl/api/assistant/message';
  static String get assistantReminders => '$baseUrl/api/assistant/reminders';

  /// Resolves relative backend audio paths (e.g. '/static/audio/abc.mp3') to full URLs.
  static String resolveMediaUrl(String urlOrPath) {
    final trimmed = urlOrPath.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final cleanPath = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '$cleanBase$cleanPath';
  }
}
