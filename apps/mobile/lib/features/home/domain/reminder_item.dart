enum ReminderCategory {
  medicine,
  bill,
  work,
  personal,
  birthday,
  document,
  general;

  /// Uppercase LLM category badge label (`MEDICINE`, `BILL`, `WORK`, `PERSONAL`, `BIRTHDAY`, `DOCUMENT`, `GENERAL`).
  String get badgeLabel => name.toUpperCase();

  static ReminderCategory fromBackendString(String? raw) {
    if (raw == null || raw.trim().isEmpty) return ReminderCategory.general;
    final norm = raw.trim().toUpperCase();
    switch (norm) {
      case 'MEDICINE':
      case 'HEALTH':
        return ReminderCategory.medicine;
      case 'BILL':
      case 'FINANCE':
        return ReminderCategory.bill;
      case 'WORK':
        return ReminderCategory.work;
      case 'PERSONAL':
        return ReminderCategory.personal;
      case 'BIRTHDAY':
        return ReminderCategory.birthday;
      case 'DOCUMENT':
      case 'DOCUMENTATION':
        return ReminderCategory.document;
      default:
        // Legacy lowercase compatibility ('other' -> 'general')
        final lower = raw.trim().toLowerCase();
        for (final c in ReminderCategory.values) {
          if (c.name == lower) return c;
        }
        return ReminderCategory.general;
    }
  }
}

enum ReminderPriority {
  normal,
  important,
}

enum TaskLifecycleState {
  scheduled,
  completed,
}

/// Read-only, zero-touch domain entity representing an autonomous reminder task.
/// Once `state == TaskLifecycleState.completed`, it cannot revert to `scheduled`.
class ReminderItem {
  final String id;
  final String title;
  final String? notes;
  final DateTime dueAt;
  final ReminderCategory category;
  final ReminderPriority priority;
  final TaskLifecycleState state;
  final DateTime? completedAt;

  const ReminderItem({
    required this.id,
    required this.title,
    this.notes,
    required this.dueAt,
    this.category = ReminderCategory.general,
    this.priority = ReminderPriority.normal,
    this.state = TaskLifecycleState.scheduled,
    this.completedAt,
  });

  bool get isDone => state == TaskLifecycleState.completed;

  ReminderItem markCompleted([DateTime? when]) {
    if (state == TaskLifecycleState.completed) return this;
    return ReminderItem(
      id: id,
      title: title,
      notes: notes,
      dueAt: dueAt,
      category: category,
      priority: priority,
      state: TaskLifecycleState.completed,
      completedAt: when ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'notes': notes,
        'dueAt': dueAt.toIso8601String(),
        'category': category.badgeLabel,
        'priority': priority.name,
        'state': state.name,
        'isDone': isDone,
        'completedAt': completedAt?.toIso8601String(),
      };

  factory ReminderItem.fromJson(Map<String, dynamic> json) {
    final rawState = json['state'] as String?;
    final legacyDone = json['isDone'] as bool? ?? false;
    final parsedState = (rawState == 'completed' || legacyDone)
        ? TaskLifecycleState.completed
        : TaskLifecycleState.scheduled;

    return ReminderItem(
      id: json['id'] as String,
      title: json['title'] as String,
      notes: json['notes'] as String?,
      dueAt: DateTime.parse(json['dueAt'] as String),
      category: ReminderCategory.fromBackendString(json['category'] as String?),
      priority: ReminderPriority.values.firstWhere(
        (p) => p.name == json['priority'],
        orElse: () => ReminderPriority.normal,
      ),
      state: parsedState,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
    );
  }
}
