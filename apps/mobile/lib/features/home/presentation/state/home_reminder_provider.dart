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

/// State notifier managing home reminders with clean, dynamic data.
class HomeReminderNotifier extends StateNotifier<HomeReminderState> {
  HomeReminderNotifier()
      : super(
          const HomeReminderState(
            reminders: [], // Zero demo data: Starts pristine and clean
            isLoading: false,
          ),
        );

  /// Add a newly captured reminder
  void addReminder(ReminderItem item) {
    state = state.copyWith(
      reminders: [...state.reminders, item],
    );
  }

  /// Update an existing reminder
  void updateReminder(ReminderItem item) {
    state = state.copyWith(
      reminders: state.reminders.map((r) => r.id == item.id ? item : r).toList(),
    );
  }

  /// Snooze reminder by given duration
  void snooze(String id, Duration duration) {
    state = state.copyWith(
      reminders: state.reminders.map((r) {
        if (r.id == id) {
          return r.copyWith(
            dueAt: r.dueAt.add(duration),
            isOverdue: false,
          );
        }
        return r;
      }).toList(),
    );
  }

  /// Toggle task completion status
  void toggleDone(String id) {
    state = state.copyWith(
      reminders: state.reminders.map((r) {
        if (r.id == id) {
          return r.copyWith(isDone: !r.isDone);
        }
        return r;
      }).toList(),
    );
  }

  /// Delete a reminder
  void deleteReminder(String id) {
    state = state.copyWith(
      reminders: state.reminders.where((r) => r.id != id).toList(),
    );
  }

  /// Clear all reminders
  void clearAll() {
    state = state.copyWith(reminders: []);
  }
}

/// Riverpod provider for Home reminders
final homeReminderProvider =
    StateNotifierProvider<HomeReminderNotifier, HomeReminderState>((ref) {
  return HomeReminderNotifier();
});
