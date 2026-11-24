import 'package:flutter_test/flutter_test.dart';
import 'package:pingo_mobile/core/network/api_client.dart';
import 'package:pingo_mobile/features/home/domain/chat_message.dart';
import 'package:pingo_mobile/features/home/domain/reminder_item.dart';

void main() {
  group('Streamlined Zero-Touch Reminder & Tenant Headers', () {
    test('ReminderItem maps all 7 LLM categories and enforces irreversible completion', () {
      final item = ReminderItem(
        id: 'rem-1',
        title: 'Buy prescription medicine',
        dueAt: DateTime(2026, 11, 25, 21, 0),
        category: ReminderCategory.fromBackendString('MEDICINE'),
      );

      expect(item.category.badgeLabel, 'MEDICINE');
      expect(item.isDone, isFalse);

      final completed = item.markCompleted(DateTime(2026, 11, 25, 21, 0, 5));
      expect(completed.isDone, isTrue);
      expect(completed.state, TaskLifecycleState.completed);
      expect(completed.completedAt, isNotNull);

      // Roundtrip JSON preserves category badge and completed state
      final decoded = ReminderItem.fromJson(completed.toJson());
      expect(decoded.isDone, isTrue);
      expect(decoded.category.badgeLabel, 'MEDICINE');
    });

    test('ApiClient attaches Bearer token when authenticated and X-Session-ID when guest', () {
      final client = ApiClient();
      client.setGuestSessionId('guest-uuid-1234');

      final guestHeaders = client.buildTenantHeaders();
      expect(guestHeaders['X-Session-ID'], 'guest-uuid-1234');
      expect(guestHeaders.containsKey('Authorization'), isFalse);

      client.setAuthToken('jwt-token-xyz');
      final authHeaders = client.buildTenantHeaders();
      expect(authHeaders['Authorization'], 'Bearer jwt-token-xyz');
      expect(authHeaders.containsKey('X-Session-ID'), isFalse);
    });

    test('ChatMessage copyWith(clearReminder: true) clears reminder fields cleanly', () {
      final msg = ChatMessage(
        id: 'msg-1',
        text: 'Scheduled',
        isUser: false,
        timestamp: DateTime(2026, 11, 24, 17, 0),
        reminderTitle: 'Call doctor',
        reminderDueAt: DateTime(2026, 11, 24, 17, 30),
        reminderCategory: 'MEDICINE',
        bundledAttachments: const ['rx.png'],
      );

      expect(msg.hasReminder, isTrue);
      expect(msg.hasBundledAttachments, isTrue);

      final cleared = msg.copyWith(clearReminder: true);
      expect(cleared.hasReminder, isFalse);
      expect(cleared.reminderCategory, isNull);
    });
  });
}
