import 'package:flutter_test/flutter_test.dart';
import 'package:pingo_mobile/features/home/domain/chat_message.dart';

void main() {
  group('ChatMessage confirmation gate', () {
    test('copyWith(clearReminder: true) clears pending reminder fields on discard', () {
      final pending = ChatMessage(
        id: 'msg-1',
        text: '',
        isUser: false,
        timestamp: DateTime(2026, 11, 23, 17, 0),
        reminderTitle: 'Call doctor',
        reminderDueAt: DateTime(2026, 11, 23, 17, 30),
        isPendingConfirmation: true,
        pendingReminderCategory: 'HEALTH',
        pendingReminderPriority: 'HIGH',
      );

      expect(pending.hasReminder, isTrue);
      expect(pending.hasPendingReminder, isTrue);

      final discarded = pending.copyWith(
        isPendingConfirmation: false,
        clearReminder: true,
        text: 'Proposed reminder discarded',
      );

      expect(discarded.isPendingConfirmation, isFalse);
      expect(discarded.hasPendingReminder, isFalse);
      expect(discarded.hasReminder, isFalse);
      expect(discarded.reminderTitle, isNull);
      expect(discarded.reminderDueAt, isNull);
      expect(discarded.text, 'Proposed reminder discarded');
    });
  });
}
