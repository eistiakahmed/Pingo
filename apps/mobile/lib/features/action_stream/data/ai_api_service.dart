import 'package:pingo_mobile/core/network/api_client.dart';
import 'package:pingo_mobile/core/network/api_config.dart';
import 'package:pingo_mobile/features/action_stream/domain/ai_models.dart';

/// Natural Language AI Parsing API Service
class AiApiService {
  final ApiClient _client;

  AiApiService({ApiClient? client}) : _client = client ?? ApiClient();

  /// Sends raw user utterance (English / Bangla / Banglish) to server AI endpoint
  Future<ParsedReminderData> parseReminder({
    required String text,
    String timezone = 'UTC',
    DateTime? referenceDate,
  }) async {
    final payload = {
      'text': text,
      'timezone': timezone,
      'reference_date': (referenceDate ?? DateTime.now().toUtc()).toIso8601String(),
    };

    final response = await _client.post(ApiConfig.aiParseReminder, body: payload);
    return ParsedReminderData.fromJson(response as Map<String, dynamic>);
  }
}

