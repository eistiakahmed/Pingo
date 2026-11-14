/// AI Natural Language Parsed Reminder Entity
class ParsedReminderData {
  final String title;
  final DateTime? dueAt;
  final String category;
  final String priority;
  final double confidence;

  ParsedReminderData({
    required this.title,
    this.dueAt,
    required this.category,
    required this.priority,
    required this.confidence,
  });

  factory ParsedReminderData.fromJson(Map<String, dynamic> json) {
    return ParsedReminderData(
      title: json['title'] as String? ?? '',
      dueAt: json['due_at'] != null ? DateTime.parse(json['due_at'] as String) : null,
      category: json['category'] as String? ?? 'GENERAL',
      priority: json['priority'] as String? ?? 'NORMAL',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'due_at': dueAt?.toIso8601String(),
        'category': category,
        'priority': priority,
        'confidence': confidence,
      };
}

