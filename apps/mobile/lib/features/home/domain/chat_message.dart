import 'dart:convert';

/// Immutable model representing a single conversational interaction in Pingo's chat stream.
/// Supports inline reminders, punctual alarm triggers, and encrypted document attachments.
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

  // Integrated document attachment fields
  final String? documentTitle;
  final String? documentCategory;
  final String? documentExpiry;
  final String? documentIdentifier;
  final String? filePath;
  final int? fileSize;

  // Confirmation gate for zero false-alarm reminders
  final bool isPendingConfirmation;
  final String? pendingReminderCategory;
  final String? pendingReminderPriority;

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
    this.documentTitle,
    this.documentCategory,
    this.documentExpiry,
    this.documentIdentifier,
    this.filePath,
    this.fileSize,
    this.isPendingConfirmation = false,
    this.pendingReminderCategory,
    this.pendingReminderPriority,
  });

  bool get hasReminder => reminderTitle != null && reminderDueAt != null;
  bool get hasPendingReminder => isPendingConfirmation && hasReminder;
  bool get hasDocument => documentTitle != null && documentTitle!.isNotEmpty;

  ChatMessage copyWith({
    String? id,
    String? text,
    bool? isUser,
    DateTime? timestamp,
    String? reminderId,
    String? reminderTitle,
    DateTime? reminderDueAt,
    bool clearReminder = false,
    bool? isDone,
    List<String>? suggestedActions,
    String? documentTitle,
    String? documentCategory,
    String? documentExpiry,
    String? documentIdentifier,
    String? filePath,
    int? fileSize,
    bool? isPendingConfirmation,
    String? pendingReminderCategory,
    String? pendingReminderPriority,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      reminderId: clearReminder ? null : (reminderId ?? this.reminderId),
      reminderTitle: clearReminder ? null : (reminderTitle ?? this.reminderTitle),
      reminderDueAt: clearReminder ? null : (reminderDueAt ?? this.reminderDueAt),
      isDone: isDone ?? this.isDone,
      suggestedActions: suggestedActions ?? this.suggestedActions,
      documentTitle: documentTitle ?? this.documentTitle,
      documentCategory: documentCategory ?? this.documentCategory,
      documentExpiry: documentExpiry ?? this.documentExpiry,
      documentIdentifier: documentIdentifier ?? this.documentIdentifier,
      filePath: filePath ?? this.filePath,
      fileSize: fileSize ?? this.fileSize,
      isPendingConfirmation: isPendingConfirmation ?? this.isPendingConfirmation,
      pendingReminderCategory: clearReminder
          ? null
          : (pendingReminderCategory ?? this.pendingReminderCategory),
      pendingReminderPriority: clearReminder
          ? null
          : (pendingReminderPriority ?? this.pendingReminderPriority),
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
      'documentTitle': documentTitle,
      'documentCategory': documentCategory,
      'documentExpiry': documentExpiry,
      'documentIdentifier': documentIdentifier,
      'filePath': filePath,
      'fileSize': fileSize,
      'isPendingConfirmation': isPendingConfirmation,
      'pendingReminderCategory': pendingReminderCategory,
      'pendingReminderPriority': pendingReminderPriority,
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
      documentTitle: map['documentTitle'] as String?,
      documentCategory: map['documentCategory'] as String?,
      documentExpiry: map['documentExpiry'] as String?,
      documentIdentifier: map['documentIdentifier'] as String?,
      filePath: map['filePath'] as String?,
      fileSize: map['fileSize'] as int?,
      isPendingConfirmation: map['isPendingConfirmation'] as bool? ?? false,
      pendingReminderCategory: map['pendingReminderCategory'] as String?,
      pendingReminderPriority: map['pendingReminderPriority'] as String?,
    );
  }

  String toJson() => json.encode(toMap());

  factory ChatMessage.fromJson(String source) =>
      ChatMessage.fromMap(json.decode(source) as Map<String, dynamic>);
}
