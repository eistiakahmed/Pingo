import 'dart:convert';

/// Immutable model representing a single conversational interaction in Pingo's chat stream.
class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? reminderId;
  final String? reminderTitle;
  final DateTime? reminderDueAt;
  final bool isDone;
  final List<String> suggestedActions;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.reminderId,
    this.reminderTitle,
    this.reminderDueAt,
    this.isDone = false,
    this.suggestedActions = const [],
  });

  bool get hasReminder => reminderTitle != null && reminderDueAt != null;

  ChatMessage copyWith({
    String? id,
    String? text,
    bool? isUser,
    DateTime? timestamp,
    String? reminderId,
    String? reminderTitle,
    DateTime? reminderDueAt,
    bool? isDone,
    List<String>? suggestedActions,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      reminderId: reminderId ?? this.reminderId,
      reminderTitle: reminderTitle ?? this.reminderTitle,
      reminderDueAt: reminderDueAt ?? this.reminderDueAt,
      isDone: isDone ?? this.isDone,
      suggestedActions: suggestedActions ?? this.suggestedActions,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'reminderId': reminderId,
      'reminderTitle': reminderTitle,
      'reminderDueAt': reminderDueAt?.toIso8601String(),
      'isDone': isDone,
      'suggestedActions': suggestedActions,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String,
      text: map['text'] as String,
      isUser: map['isUser'] as bool? ?? false,
      timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now(),
      reminderId: map['reminderId'] as String?,
      reminderTitle: map['reminderTitle'] as String?,
      reminderDueAt: map['reminderDueAt'] != null
          ? DateTime.tryParse(map['reminderDueAt'] as String)
          : null,
      isDone: map['isDone'] as bool? ?? false,
      suggestedActions: (map['suggestedActions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  String toJson() => json.encode(toMap());

  factory ChatMessage.fromJson(String source) =>
      ChatMessage.fromMap(json.decode(source) as Map<String, dynamic>);
}
