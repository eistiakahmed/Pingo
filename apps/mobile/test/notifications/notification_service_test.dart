import 'package:flutter_test/flutter_test.dart';
import 'package:pingo_mobile/core/services/notification_service.dart';
import 'package:pingo_mobile/features/home/domain/reminder_item.dart';
import 'package:pingo_mobile/features/home/presentation/state/home_reminder_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationService & Zero-Touch HomeReminderNotifier Tests', () {
    test('NotificationService singleton initializes without crash', () async {
      final service = NotificationService.instance;
      expect(service, isNotNull);
    });

    test('HomeReminderNotifier schedules future task and irreversibly auto-completes due task', () {
      final notifier = HomeReminderNotifier();
      final futureItem = ReminderItem(
        id: 'future-123',
        title: 'Call Doctor',
        dueAt: DateTime.now().add(const Duration(hours: 2)),
        category: ReminderCategory.medicine,
        priority: ReminderPriority.important,
      );

      notifier.addReminder(futureItem);
      expect(notifier.state.scheduledReminders.length, 1);
      expect(notifier.state.scheduledReminders.first.isDone, isFalse);

      // Adding an already-due reminder transitions immediately & irreversibly to completed
      final dueItem = ReminderItem(
        id: 'due-456',
        title: 'Pay Electricity Bill',
        dueAt: DateTime.now().subtract(const Duration(minutes: 1)),
        category: ReminderCategory.bill,
      );
      notifier.addReminder(dueItem);
      expect(notifier.state.completedReminders.length, 1);
      expect(notifier.state.completedReminders.first.title, 'Pay Electricity Bill');
      expect(notifier.state.completedReminders.first.isDone, isTrue);

      // Triggering alarm safeId auto-completes the scheduled task
      final safeId = futureItem.id.hashCode.abs() % 2147483647;
      notifier.autoCompleteDueTasks(triggeredSafeId: safeId);
      expect(notifier.state.scheduledReminders, isEmpty);
      expect(notifier.state.completedReminders.length, 2);

      notifier.dispose();
    });
  });
}
