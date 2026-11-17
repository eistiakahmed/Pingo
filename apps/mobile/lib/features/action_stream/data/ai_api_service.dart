import 'package:pingo_mobile/core/network/api_client.dart';
import 'package:pingo_mobile/core/network/api_config.dart';
import 'package:pingo_mobile/features/action_stream/domain/ai_models.dart';

/// Natural Language AI Parsing API Service
class AiApiService {
  final ApiClient _client;

  AiApiService({ApiClient? client}) : _client = client ?? ApiClient();

  /// Sends raw user utterance (English / Bangla / Banglish) to server AI endpoint.
  /// reference_date defaults to the DEVICE'S LOCAL now (with explicit UTC
  /// offset) so relative phrases like "in five minutes" resolve correctly.
  Future<ParsedReminderData> parseReminder({
    required String text,
    String timezone = 'UTC',
    DateTime? referenceDate,
  }) async {
    final now = referenceDate ?? DateTime.now();
    final payload = {
      'text': text,
      'timezone': timezone,
      'reference_date': _isoWithOffset(now),
    };

    final response = await _client.post(ApiConfig.aiParseReminder, body: payload);
    return ParsedReminderData.fromJson(response as Map<String, dynamic>);
  }

  /// ISO8601 with explicit UTC offset for local DateTimes
  /// (Dart omits the offset for non-UTC timestamps by default).
  String _isoWithOffset(DateTime dt) {
    if (dt.isUtc) return dt.toIso8601String();
    final diff = dt.timeZoneOffset;
    final sign = diff.isNegative ? '-' : '+';
    final h = diff.inHours.abs().toString().padLeft(2, '0');
    final m = diff.inMinutes.remainder(60).toString().padLeft(2, '0');
    return '${dt.toIso8601String()}$sign$h:$m';
  }
}

