import 'dart:io';

/// Application API Gateway Configuration and Endpoints
class ApiConfig {
  ApiConfig._();

  /// Default API Base URL based on runtime platform
  static String get defaultBaseUrl {
    const fromEnv = String.fromEnvironment('PINGO_API_URL');
    if (fromEnv.isNotEmpty) return fromEnv;

    try {
      if (Platform.isAndroid) {
        // Android emulator localhost alias
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
}

