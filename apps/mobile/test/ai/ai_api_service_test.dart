import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pingo_mobile/core/network/api_client.dart';
import 'package:pingo_mobile/features/action_stream/data/ai_api_service.dart';

void main() {
  group('AiApiService Tests', () {
    test('parseReminder() sends natural language text and returns structured entity', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/ai/parse-reminder');
        final body = jsonDecode(request.body);
        expect(body['text'], 'ডাক্তারের প্রেসক্রিপশন ও ওষুধ কেনা কাল সকাল ১০টায়');
        expect(body['timezone'], 'Asia/Dhaka');

        final responseJson = jsonEncode({
          'title': 'ডাক্তারের প্রেসক্রিপশন ও ওষুধ কেনা',
          'due_at': '2026-11-08T04:00:00Z',
          'category': 'MEDICINE',
          'priority': 'HIGH',
          'confidence': 0.95,
        });

        return http.Response.bytes(
          utf8.encode(responseJson),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final apiClient = ApiClient(client: mockClient);
      final aiService = AiApiService(client: apiClient);

      final result = await aiService.parseReminder(
        text: 'ডাক্তারের প্রেসক্রিপশন ও ওষুধ কেনা কাল সকাল ১০টায়',
        timezone: 'Asia/Dhaka',
      );

      expect(result.title, 'ডাক্তারের প্রেসক্রিপশন ও ওষুধ কেনা');
      expect(result.category, 'MEDICINE');
      expect(result.priority, 'HIGH');
      expect(result.confidence, 0.95);
      expect(result.dueAt, DateTime.parse('2026-11-08T04:00:00Z'));
    });
  });
}
