/// AI Natural Language Parsed Result
///
/// The server returns ONE structured JSON object — the AI never writes
/// free-form replies. `dueAt` is computed server-side (deterministic resolver);
/// `clarifyingQuestion` is set instead of a guess when time/date is unclear.
class ParsedReminderData {
  static const String intentCreate = 'create_reminder';
  static const String intentList = 'list_reminders';
  static const String intentDelete = 'delete_reminder';
  static const String intentUpdate = 'update_reminder';
  static const String intentChat = 'chat';

  final String intent;
  final String title;
  final String? date; // YYYY-MM-DD local
  final String? time; // HH:MM 24h local
  final String? clarifyingQuestion;
  final DateTime? dueAt;
  final String category;
  final String priority;
  final double confidence;

  ParsedReminderData({
    this.intent = intentCreate,
    required this.title,
    this.date,
    this.time,
    this.clarifyingQuestion,
    this.dueAt,
    required this.category,
    required this.priority,
    required this.confidence,
  });

  bool get needsClarification =>
      clarifyingQuestion != null && clarifyingQuestion!.trim().isNotEmpty;

  factory ParsedReminderData.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> data = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : json;
    return ParsedReminderData(
      intent: data['intent'] as String? ?? intentCreate,
      title: data['title'] as String? ?? '',
      date: data['date'] as String?,
      time: data['time'] as String?,
      clarifyingQuestion: data['clarifying_question'] as String?,
      dueAt: data['due_at'] != null ? DateTime.parse(data['due_at'] as String) : null,
      category: data['category'] as String? ?? 'GENERAL',
      priority: data['priority'] as String? ?? 'NORMAL',
      confidence: (data['confidence'] as num?)?.toDouble() ?? 1.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'intent': intent,
        'title': title,
        'date': date,
        'time': time,
        'clarifying_question': clarifyingQuestion,
        'due_at': dueAt?.toIso8601String(),
        'category': category,
        'priority': priority,
        'confidence': confidence,
      };
}
