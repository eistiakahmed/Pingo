import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/reminder_item.dart';

/// State model for Home Screen reminder lists.
class HomeReminderState {
  final List<ReminderItem> reminders;
  final bool isLoading;

  const HomeReminderState({
    required this.reminders,
    this.isLoading = false,
  });

  List<ReminderItem> get todayReminders =>
      reminders.where((r) => !r.isDone && !r.isOverdue).toList();

  List<ReminderItem> get overdueReminders =>
      reminders.where((r) => !r.isDone && r.isOverdue).toList();

  List<ReminderItem> get completedReminders =>
      reminders.where((r) => r.isDone).toList();

  HomeReminderState copyWith({
    List<ReminderItem>? reminders,
    bool? isLoading,
  }) {
    return HomeReminderState(
      reminders: reminders ?? this.reminders,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// State notifier managing home reminders with realistic bilingual sample data.
class HomeReminderNotifier extends StateNotifier<HomeReminderState> {
  HomeReminderNotifier()
      : super(
          HomeReminderState(
            reminders: [
              ReminderItem(
                id: '1',
                title: 'ব্লাড প্রেশারের ওষুধ গ্রহণ',
                notes: 'খাওয়ার পর কুসুম গরম পানি দিয়ে',
                dueAt: DateTime.now().subtract(const Duration(minutes: 45)),
                category: ReminderCategory.medicine,
                priority: ReminderPriority.important,
                repeatRule: 'প্রতিদিন সকাল ৮:০০',
                isOverdue: true,
              ),
              ReminderItem(
                id: '2',
                title: 'Doctor appointment with Mom',
                notes: 'Specialist consultation at Square Hospital',
                dueAt: DateTime.now().add(const Duration(hours: 3)),
                category: ReminderCategory.personal,
                priority: ReminderPriority.important,
              ),
              ReminderItem(
                id: '3',
                title: 'বিদ্যুৎ ও ইন্টারনেট বিল পরিশোধ',
                dueAt: DateTime.now().add(const Duration(hours: 5)),
                category: ReminderCategory.bill,
                repeatRule: 'প্রতি মাসের ১০ তারিখ',
              ),
              ReminderItem(
                id: '4',
                title: 'Q4 Product Roadmap Sync with Team',
                dueAt: DateTime.now().add(const Duration(hours: 7)),
                category: ReminderCategory.work,
                repeatRule: 'Weekly on Friday',
              ),
            ],
          ),
        );

  void toggleDone(String id) {
    state = state.copyWith(
      reminders: state.reminders.map((r) {
        if (r.id == id) {
          return r.copyWith(isDone: !r.isDone, isOverdue: false);
        }
        return r;
      }).toList(),
    );
  }

  void snooze(String id, Duration duration) {
    state = state.copyWith(
      reminders: state.reminders.map((r) {
        if (r.id == id) {
          return r.copyWith(
            dueAt: DateTime.now().add(duration),
            isOverdue: false,
          );
        }
        return r;
      }).toList(),
    );
  }

  void addReminder(ReminderItem item) {
    state = state.copyWith(
      reminders: [item, ...state.reminders],
    );
  }
}

final homeReminderProvider =
    StateNotifierProvider<HomeReminderNotifier, HomeReminderState>((ref) {
  return HomeReminderNotifier();
});

