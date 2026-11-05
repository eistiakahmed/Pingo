enum ReminderCategory {
  medicine,
  bill,
  work,
  personal,
  birthday,
  other,
}

enum ReminderPriority {
  normal,
  important,
}

/// Domain entity representing a scheduled reminder.
class ReminderItem {
  final String id;
  final String title;
  final String? notes;
  final DateTime dueAt;
  final ReminderCategory category;
  final ReminderPriority priority;
  final String? repeatRule; // e.g., 'Daily', 'Weekly', 'Monthly'
  final bool isDone;
  final bool isOverdue;

  const ReminderItem({
    required this.id,
    required this.title,
    this.notes,
    required this.dueAt,
    this.category = ReminderCategory.other,
    this.priority = ReminderPriority.normal,
    this.repeatRule,
    this.isDone = false,
    this.isOverdue = false,
  });

  ReminderItem copyWith({
    String? id,
    String? title,
    String? notes,
    DateTime? dueAt,
    ReminderCategory? category,
    ReminderPriority? priority,
    String? repeatRule,
    bool? isDone,
    bool? isOverdue,
  }) {
    return ReminderItem(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      dueAt: dueAt ?? this.dueAt,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      repeatRule: repeatRule ?? this.repeatRule,
      isDone: isDone ?? this.isDone,
      isOverdue: isOverdue ?? this.isOverdue,
    );
  }
}
