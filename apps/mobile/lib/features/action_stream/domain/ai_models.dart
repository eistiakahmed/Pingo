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
    final Map<String, dynamic> data = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : json;
    return ParsedReminderData(
      title: data['title'] as String? ?? '',
      dueAt: data['due_at'] != null ? DateTime.parse(data['due_at'] as String) : null,
      category: data['category'] as String? ?? 'GENERAL',
      priority: data['priority'] as String? ?? 'NORMAL',
      confidence: (data['confidence'] as num?)?.toDouble() ?? 1.0,
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

