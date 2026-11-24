import 'dart:convert';

/// Streamlined, immutable WhatsApp-style conversational message model.
/// Supports voice reply playback (`audioUrl`), autonomous LLM-classified reminder cards
/// (`reminderCategory`), triggered alarm notifications (`isAlarmTriggeredAlert`),
/// and bundled multimodal attachment metadata (`bundledAttachments`).
class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? audioUrl;
  final bool isAlarmTriggeredAlert;

  final String? reminderId;
  final String? reminderTitle;
  final DateTime? reminderDueAt;
  final String? reminderCategory;

  final String? documentTitle;
  final String? documentCategory;
  final List<String> bundledAttachments;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.audioUrl,
    this.isAlarmTriggeredAlert = false,
    this.reminderId,
    this.reminderTitle,
    this.reminderDueAt,
    this.reminderCategory,
    this.documentTitle,
    this.documentCategory,
    this.bundledAttachments = const [],
  });

  bool get hasAudio => audioUrl != null && audioUrl!.trim().isNotEmpty;
  bool get hasReminder => reminderTitle != null && reminderDueAt != null;
  bool get hasDocument => documentTitle != null && documentTitle!.isNotEmpty;
  bool get hasBundledAttachments => bundledAttachments.isNotEmpty;

  ChatMessage copyWith({
    String? id,
    String? text,
    bool? isUser,
    DateTime? timestamp,
    String? audioUrl,
    bool? isAlarmTriggeredAlert,
    String? reminderId,
    String? reminderTitle,
    DateTime? reminderDueAt,
    String? reminderCategory,
    bool clearReminder = false,
    String? documentTitle,
    String? documentCategory,
    List<String>? bundledAttachments,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      audioUrl: audioUrl ?? this.audioUrl,
      isAlarmTriggeredAlert:
          isAlarmTriggeredAlert ?? this.isAlarmTriggeredAlert,
      reminderId: clearReminder ? null : (reminderId ?? this.reminderId),
      reminderTitle:
          clearReminder ? null : (reminderTitle ?? this.reminderTitle),
      reminderDueAt:
          clearReminder ? null : (reminderDueAt ?? this.reminderDueAt),
      reminderCategory:
          clearReminder ? null : (reminderCategory ?? this.reminderCategory),
      documentTitle: documentTitle ?? this.documentTitle,
      documentCategory: documentCategory ?? this.documentCategory,
      bundledAttachments: bundledAttachments ?? this.bundledAttachments,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'audioUrl': audioUrl,
      'isAlarmTriggeredAlert': isAlarmTriggeredAlert,
      'reminderId': reminderId,
      'reminderTitle': reminderTitle,
      'reminderDueAt': reminderDueAt?.toIso8601String(),
      'reminderCategory': reminderCategory,
      'documentTitle': documentTitle,
      'documentCategory': documentCategory,
      'bundledAttachments': bundledAttachments,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String,
      text: map['text'] as String,
      isUser: map['isUser'] as bool? ?? false,
      timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ??
          DateTime.now(),
      audioUrl: map['audioUrl'] as String?,
      isAlarmTriggeredAlert: map['isAlarmTriggeredAlert'] as bool? ?? false,
      reminderId: map['reminderId'] as String?,
      reminderTitle: map['reminderTitle'] as String?,
      reminderDueAt: map['reminderDueAt'] != null
          ? DateTime.tryParse(map['reminderDueAt'] as String)
          : null,
      reminderCategory: map['reminderCategory'] as String?,
      documentTitle: map['documentTitle'] as String?,
      documentCategory: map['documentCategory'] as String?,
      bundledAttachments: (map['bundledAttachments'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  String toJson() => json.encode(toMap());

  factory ChatMessage.fromJson(String source) =>
      ChatMessage.fromMap(json.decode(source) as Map<String, dynamic>);
}
