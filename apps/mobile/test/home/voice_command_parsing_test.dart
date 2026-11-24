import 'package:flutter_test/flutter_test.dart';
import 'package:pingo_mobile/core/network/api_config.dart';
import 'package:pingo_mobile/features/home/domain/chat_message.dart';
import 'package:pingo_mobile/features/voice_capture/data/voice_command_api_service.dart';

void main() {
  group('VoiceCommandResult & WhatsApp Voice Chat models', () {
    test('parses /api/voice-command JSON, resolves audio_url, and extracts set_reminder action', () {
      ApiConfig.baseUrl = 'http://98.84.163.177';

      final payload = {
        'user_said': 'আজকে রাত ১০টায় ওষুধ খাওয়ার রিমাইন্ডার দাও',
        'ai_reply': 'ঠিক আছে, আজকে রাত ১০টায় ওষুধ খাওয়ার রিমাইন্ডার সেট করা হয়েছে।',
        'audio_url': '/static/audio/9f8e7d6c.mp3',
        'actions': [
          {
            'tool': 'set_reminder',
            'record_id': 'rem-uuid-1',
            'arguments': {
              'task_title': 'ওষুধ খাওয়া',
              'reminder_time': '2026-11-24T22:00:00+06:00',
            },
          },
        ],
      };

      final result = VoiceCommandResult.fromJson(payload);

      expect(result.userSaid, contains('ওষুধ'));
      expect(result.aiReply, contains('রাত ১০টায়'));
      expect(result.fullAudioUrl, 'http://98.84.163.177/static/audio/9f8e7d6c.mp3');
      expect(result.actions.length, 1);
      expect(result.actions.first.tool, 'set_reminder');
      expect(result.actions.first.arguments['task_title'], 'ওষুধ খাওয়া');

      final parsedDue =
          DateTime.parse(result.actions.first.arguments['reminder_time'] as String);
      expect(parsedDue.toUtc().hour, 16); // 22:00 +06:00 == 16:00 UTC
      expect(parsedDue.toUtc().minute, 0);
    });

    test('ChatMessage serializes audioUrl and isAlarmTriggeredAlert cleanly', () {
      final aiVoiceBubble = ChatMessage(
        id: 'ai-1',
        text: 'রিমাইন্ডার সেট হয়েছে।',
        isUser: false,
        timestamp: DateTime(2026, 11, 24, 19, 15),
        audioUrl: 'http://98.84.163.177/static/audio/sample.mp3',
        isAlarmTriggeredAlert: true,
        reminderTitle: 'Server Deployment',
        reminderDueAt: DateTime(2026, 11, 24, 22, 0),
      );

      expect(aiVoiceBubble.hasAudio, isTrue);

      final roundTrip = ChatMessage.fromJson(aiVoiceBubble.toJson());
      expect(roundTrip.audioUrl, 'http://98.84.163.177/static/audio/sample.mp3');
      expect(roundTrip.isAlarmTriggeredAlert, isTrue);
      expect(roundTrip.reminderTitle, 'Server Deployment');
    });
  });
}
