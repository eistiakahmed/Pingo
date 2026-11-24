import 'package:flutter_test/flutter_test.dart';
import 'package:pingo_mobile/core/network/api_config.dart';
import 'package:pingo_mobile/features/home/domain/chat_message.dart';
import 'package:pingo_mobile/features/voice_capture/data/voice_command_api_service.dart';

void main() {
  group('VoiceCommandResult & Multimodal Staging models', () {
    test('parses /api/voice-command JSON with LLM category, bundled_attachments, and audio_url', () {
      ApiConfig.baseUrl = 'http://98.84.163.177';

      final payload = {
        'status': 'completed_turn',
        'user_said': 'আজকে রাত ১০টায় ওষুধ খাওয়ার রিমাইন্ডার দাও',
        'ai_reply': 'ঠিক আছে, আজকে রাত ১০টায় ওষুধ খাওয়ার রিমাইন্ডার সেট করা হয়েছে।',
        'audio_url': '/static/audio/9f8e7d6c.mp3',
        'bundled_attachments': [
          {'staging_id': 'stg_1', 'filename': 'prescription.png'}
        ],
        'actions': [
          {
            'tool': 'set_reminder',
            'record_id': 'rem-uuid-1',
            'category': 'MEDICINE',
            'lifecycle_state': 'scheduled',
            'arguments': {
              'task_title': 'ওষুধ খাওয়া',
              'reminder_time': '2026-11-24T22:00:00+06:00',
              'category': 'MEDICINE',
            },
          },
        ],
      };

      final result = VoiceCommandResult.fromJson(payload);

      expect(result.userSaid, contains('ওষুধ'));
      expect(result.fullAudioUrl, 'http://98.84.163.177/static/audio/9f8e7d6c.mp3');
      expect(result.bundledAttachments.length, 1);
      expect(result.bundledAttachments.first['filename'], 'prescription.png');
      expect(result.actions.length, 1);
      expect(result.actions.first.tool, 'set_reminder');
      expect(result.actions.first.category, 'MEDICINE');
      expect(result.actions.first.lifecycleState, 'scheduled');
    });

    test('StagedAttachmentPreviewItem detects image attachments and ChatMessage round-trips', () {
      final preview = StagedAttachmentPreviewItem.fromJson(
        {
          'staging_id': 'stg_abc123',
          'filename': 'camera_capture.jpg',
          'mime_type': 'image/jpeg',
          'size_bytes': 42000,
        },
        localPath: '/tmp/camera_capture.jpg',
      );

      expect(preview.stagingId, 'stg_abc123');
      expect(preview.isImage, isTrue);

      final aiVoiceBubble = ChatMessage(
        id: 'ai-1',
        text: 'রিমাইন্ডার সেট হয়েছে।',
        isUser: false,
        timestamp: DateTime(2026, 11, 24, 19, 15),
        audioUrl: 'http://98.84.163.177/static/audio/sample.mp3',
        isAlarmTriggeredAlert: true,
        reminderTitle: 'Server Deployment',
        reminderDueAt: DateTime(2026, 11, 24, 22, 0),
        reminderCategory: 'WORK',
      );

      final roundTrip = ChatMessage.fromJson(aiVoiceBubble.toJson());
      expect(roundTrip.audioUrl, 'http://98.84.163.177/static/audio/sample.mp3');
      expect(roundTrip.isAlarmTriggeredAlert, isTrue);
      expect(roundTrip.reminderCategory, 'WORK');
    });
  });
}
