import 'package:flutter_test/flutter_test.dart';
import 'package:pingo_mobile/core/services/notification_service.dart';
import 'package:pingo_mobile/features/home/domain/reminder_item.dart';
import 'package:pingo_mobile/features/home/presentation/state/home_reminder_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationService & HomeReminderNotifier Tests', () {
    test('NotificationService singleton initializes without crash', () async {
      final service = NotificationService.instance;
      expect(service, isNotNull);
    });

    test('HomeReminderNotifier adds reminder and maintains state', () {
      final notifier = HomeReminderNotifier();
      final item = ReminderItem(
        id: 'test-123',
        title: 'Call Doctor',
        dueAt: DateTime.now().add(const Duration(hours: 2)),
        category: ReminderCategory.medicine,
        priority: ReminderPriority.important,
      );

      notifier.addReminder(item);
      expect(notifier.state.reminders.length, 1);
      expect(notifier.state.reminders.first.title, 'Call Doctor');

      // Toggle done
      notifier.toggleDone('test-123');
      expect(notifier.state.reminders.first.isDone, true);

      // Snooze
      notifier.snooze('test-123', const Duration(minutes: 30));
      expect(notifier.state.reminders.first.dueAt.isAfter(item.dueAt), true);

      // Delete
      notifier.deleteReminder('test-123');
      expect(notifier.state.reminders.isEmpty, true);
    });
  });
}

