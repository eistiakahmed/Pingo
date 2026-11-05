import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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

/// State notifier driving Pingo's conversational memory & documentation engine.
class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier()
      : super(
          ChatState(
            messages: [
              // Welcome from Pingo
              ChatMessage(
                id: '1',
                text: 'হ্যালো ইশতিয়াক! 👋\nআমি আপনার ব্যক্তিগত মেমোরি ও ডকুমেন্ট অ্যাসিস্ট্যান্ট।\n\nআপনি শুধু ভয়েসে বলুন বা টাইপ করুন — আমি সবকিছু মনে রাখব এবং যেকোনো সময় আপনার প্রয়োজনে ডকুমেন্ট বানিয়ে দেব।',
                sender: ChatMessageSender.pingo,
                timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
              ),

              // Sample previous user reminder
              ChatMessage(
                id: '2',
                text: 'কাল বিকাল ৫টায় মায়ের সাথে ডাক্তারের অ্যাপয়েন্টমেন্ট মনে রেখো',
                sender: ChatMessageSender.user,
                timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
              ),

              // Pingo response with memory capsule
              ChatMessage(
                id: '3',
                text: 'মনে রাখলাম! আপনার ডাক্তারের অ্যাপয়েন্টমেন্টের মেমোরি সংরক্ষণ করা হয়েছে। সঠিক সময়ে আপনাকে অ্যালার্ট দেব।',
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

              // Sample previous document request
              ChatMessage(
                id: '4',
                text: 'আজকের ক্লায়েন্ট মিটিংয়ের একটা প্রজেক্ট ডকুমেন্ট নোট বানিয়ে দাও',
                sender: ChatMessageSender.user,
                timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
              ),

              // Pingo generated document note
              ChatMessage(
                id: '5',
                text: 'আপনার মিটিংয়ের আলাপের ভিত্তিতে একটি নতুন ডকুমেন্ট তৈরি করে মেমোরিতে সংরক্ষণ করেছি:',
                sender: ChatMessageSender.pingo,
                type: ChatMessageType.documentNote,
                document: const DocumentPayload(
                  title: 'Pingo Client Sync & Architecture Note',
                  category: 'Meeting Minutes & Specs',
                  summary: 'ক্লায়েন্টের সাথে চ্যাট-ফার্স্ট মেমোরি অ্যাসিস্ট্যান্টের ইউজার ইন্টারফেস এবং আর্কিটেকচার চূড়ান্ত করা হয়েছে।',
                  bulletPoints: [
                    'কোনো জটিল ফর্ম ছাড়াই ন্যাচারাল চ্যাট ও ভয়েস ইন্টারফেস থাকবে।',
                    'মেমোরি ব্যাকগ্রাউন্ডে স্বয়ংক্রিয়ভাবে এক্স্যাক্ট অ্যালার্ম শিডিউল করবে।',
                    'প্রয়োজন অনুযায়ী ইনস্ট্যান্ট ডকুমেন্টেশন তৈরি ও সংরক্ষণ করা যাবে।',
                  ],
                  tags: ['Pingo', 'Monorepo', 'Flutter', 'ClientMeeting'],
                ),
                timestamp: DateTime.now().subtract(const Duration(minutes: 4)),
              ),
            ],
          ),
        );

  void sendUserMessage(String text) {
    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      sender: ChatMessageSender.user,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isThinking: true,
    );

    // Conversational Intelligence Handler
    Future.delayed(const Duration(milliseconds: 700), () {
      final reply = _generatePingoResponse(text);
      state = state.copyWith(
        messages: [...state.messages, reply],
        isThinking: false,
      );
    });
  }

  ChatMessage _generatePingoResponse(String input) {
    final lower = input.toLowerCase();
    final now = DateTime.now();

    // 1. Documentation generation intent
    if (lower.contains('ডকুমেন্ট') ||
        lower.contains('নোট') ||
        lower.contains('সামারি') ||
        lower.contains('doc') ||
        lower.contains('note') ||
        lower.contains('summary')) {
      return ChatMessage(
        id: (now.millisecondsSinceEpoch + 1).toString(),
        text: 'আপনার অনুরোধ অনুযায়ী ডকুমেন্টেশন প্রস্তুত করা হয়েছে:',
        sender: ChatMessageSender.pingo,
        type: ChatMessageType.documentNote,
        document: DocumentPayload(
          title: input.length > 25 ? '${input.substring(0, 25)}...' : input,
          category: 'Personal Documentation',
          summary: 'আপনার প্রদত্ত তথ্যের ওপর ভিত্তি করে এই ডকুমেন্টটি তৈরি করা হয়েছে।',
          bulletPoints: [
            'তথ্য সংগৃহীত: ${DateFormat('d MMMM, hh:mm a').format(now)}',
            'মেমোরি ভল্টে সুরক্ষিতভাবে সংরক্ষিত হয়েছে।',
          ],
          tags: ['PersonalDoc', 'Memory'],
        ),
        timestamp: now,
      );
    }

    // 2. Retrieval intent (recall memory)
    if (lower.contains('পাসপোর্ট') || lower.contains('passport') || lower.contains('কবে')) {
      return ChatMessage(
        id: (now.millisecondsSinceEpoch + 1).toString(),
        text: 'আপনার মেমোরি চেক করলাম 📄:\nআপনার পাসপোর্ট নম্বর A01234567, মেয়াদ শেষ হবে ১৪ আগস্ট ২০২৯ তারিখে। আমি মেয়াদ শেষের ৯০ দিন আগেই আপনাকে নোটিফিকেশন পাঠাব।',
        sender: ChatMessageSender.pingo,
        timestamp: now,
      );
    }

    // 3. Reminder intent (default for time/task phrases)
    final isMedicine = lower.contains('ওষুধ') || lower.contains('medicine');
    final isBill = lower.contains('বিল') || lower.contains('bill');
    final category = isMedicine
        ? ReminderCategory.medicine
        : (isBill ? ReminderCategory.bill : ReminderCategory.personal);

    return ChatMessage(
      id: (now.millisecondsSinceEpoch + 1).toString(),
      text: 'মনে রাখলাম! আমি ব্যাকগ্রাউন্ডে অ্যালার্ম সেট করেছি। আপনার আর মনে রাখার চিন্তা নেই।',
      sender: ChatMessageSender.pingo,
      type: ChatMessageType.memoryReminder,
      reminder: ReminderItem(
        id: (now.millisecondsSinceEpoch + 2).toString(),
        title: input,
        dueAt: now.add(const Duration(hours: 4)),
        category: category,
        priority: isMedicine ? ReminderPriority.important : ReminderPriority.normal,
      ),
      timestamp: now,
    );
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier();
});
