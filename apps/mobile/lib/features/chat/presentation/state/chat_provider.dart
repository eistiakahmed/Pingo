import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pingo_mobile/features/home/domain/reminder_item.dart';
import '../../domain/chat_message.dart';

/// State of the conversational chat thread.
class ChatState {
  final List<ChatMessage> messages;
  final bool isThinking;

  const ChatState({
    required this.messages,
    this.isThinking = false,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isThinking,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isThinking: isThinking ?? this.isThinking,
    );
  }
}

/// State notifier driving Pingo's conversational WhatsApp bot interface.
class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier()
      : super(
          ChatState(
            messages: [
              // Welcome from Pingo Bot
              ChatMessage(
                id: '1',
                text: "Hi Ishtiak! 👋\nI'm your personal memory assistant. Just message or send a voice note — I'll remember everything, schedule reminders, and create documents for you.",
                sender: ChatMessageSender.pingo,
                timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
              ),

              // Sample previous user reminder
              ChatMessage(
                id: '2',
                text: "Remind me to visit Square Hospital with Mom tomorrow at 5 PM",
                sender: ChatMessageSender.user,
                timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
              ),

              // Pingo response with memory capsule
              ChatMessage(
                id: '3',
                text: "Got it! I've saved this reminder to your memory vault.",
                sender: ChatMessageSender.pingo,
                type: ChatMessageType.memoryReminder,
                reminder: ReminderItem(
                  id: 'rem_1',
                  title: 'Doctor appointment with Mom',
                  dueAt: DateTime.now().add(const Duration(days: 1, hours: 2)),
                  category: ReminderCategory.personal,
                  priority: ReminderPriority.important,
                ),
                timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
              ),

              // Sample previous documentation request
              ChatMessage(
                id: '4',
                text: "Create a summary document from today's client sync meeting",
                sender: ChatMessageSender.user,
                timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
              ),

              // Pingo response with structured Document Note
              ChatMessage(
                id: '5',
                text: "Here is your generated document. It has been indexed in your vault.",
                sender: ChatMessageSender.pingo,
                type: ChatMessageType.documentNote,
                document: const DocumentPayload(
                  title: 'Client Sync & Deliverables (Q4)',
                  category: 'Work & Projects',
                  summary: 'Sprint planning and core milestone agreement for the mobile app launch.',
                  bulletPoints: [
                    'Sprint velocity locked for Phase 1 MVP release',
                    'Figma design tokens approved for Flutter client',
                    'Backend API contracts finalized with authentication specs',
                  ],
                  tags: ['Meeting', 'Client', 'Q4 Roadmap'],
                ),
                timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
              ),
            ],
          ),
        );

  /// Send a user message and simulate natural Pingo Bot response.
  Future<void> sendUserMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text.trim(),
      sender: ChatMessageSender.user,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isThinking: true,
    );

    // Simulate smart AI intent processing
    await Future.delayed(const Duration(milliseconds: 700));

    final lower = text.toLowerCase();
    ChatMessage pingoReply;

    if (lower.contains('remind') || lower.contains('doctor') || lower.contains('meeting') || lower.contains('রিমাইন্ডার') || lower.contains('মনে')) {
      pingoReply = ChatMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        text: "Understood! I've scheduled your reminder and saved it to memory.",
        sender: ChatMessageSender.pingo,
        type: ChatMessageType.memoryReminder,
        reminder: ReminderItem(
          id: 'rem_${DateTime.now().millisecondsSinceEpoch}',
          title: text.length > 36 ? '${text.substring(0, 36)}...' : text,
          dueAt: DateTime.now().add(const Duration(hours: 4)),
          category: ReminderCategory.personal,
          priority: ReminderPriority.important,
        ),
        timestamp: DateTime.now(),
      );
    } else if (lower.contains('doc') || lower.contains('note') || lower.contains('summary') || lower.contains('ডকুমেন্ট') || lower.contains('নোট')) {
      pingoReply = ChatMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        text: "I've drafted and indexed this document in your vault:",
        sender: ChatMessageSender.pingo,
        type: ChatMessageType.documentNote,
        document: DocumentPayload(
          title: 'Document: ${text.length > 25 ? text.substring(0, 25) : text}',
          category: 'General Notes',
          summary: 'Auto-structured document note generated from conversation.',
          bulletPoints: const [
            'Generated from voice/chat context',
            'Full text indexed for semantic search',
            'Available offline in your encrypted vault',
          ],
          tags: const ['Draft', 'Auto-Saved'],
        ),
        timestamp: DateTime.now(),
      );
    } else {
      pingoReply = ChatMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        text: "Got it! I've recorded this in your memory vault. You can ask me about it anytime, or ask me to turn it into a document.",
        sender: ChatMessageSender.pingo,
        timestamp: DateTime.now(),
      );
    }

    state = state.copyWith(
      messages: [...state.messages, pingoReply],
      isThinking: false,
    );
  }

  void clearChat() {
    state = state.copyWith(messages: []);
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier();
});
