import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/network/providers.dart';
import '../../../../core/services/fcm_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../domain/chat_message.dart';
import '../../domain/reminder_item.dart';
import 'chat_archive_service.dart';
import 'home_reminder_provider.dart';

class PingoChatState {
  final List<ChatMessage> messages;
  final bool isThinking;
  final String language; // 'bn' or 'en'
  final String sessionId;

  const PingoChatState({
    this.messages = const [],
    this.isThinking = false,
    this.language = 'bn',
    required this.sessionId,
  });

  PingoChatState copyWith({
    List<ChatMessage>? messages,
    bool? isThinking,
    String? language,
    String? sessionId,
  }) {
    return PingoChatState(
      messages: messages ?? this.messages,
      isThinking: isThinking ?? this.isThinking,
      language: language ?? this.language,
      sessionId: sessionId ?? this.sessionId,
    );
  }
}

class PingoChatNotifier extends StateNotifier<PingoChatState> {
  final Ref _ref;

  PingoChatNotifier(this._ref)
      : super(PingoChatState(sessionId: const Uuid().v4())) {
    _loadInitialMessages();
  }

  Future<void> _loadInitialMessages() async {
    final active = await ChatArchiveService.instance.loadActiveMessages();
    if (active.isNotEmpty) {
      state = state.copyWith(messages: active);
    }
  }

  void setLanguage(String lang) {
    if (state.language == lang) return;
    state = state.copyWith(language: lang);
  }

  /// Archives the current conversation thread to persistent storage and starts a clean session.
  Future<void> startNewSession() async {
    await ChatArchiveService.instance.archiveCurrentSession(state.messages);
    state = state.copyWith(
      messages: [],
      sessionId: const Uuid().v4(),
      isThinking: false,
    );
  }

  /// Sends a message and orchestrates AI parsing, reminders, and punctual notification scheduling.
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final userMsg = ChatMessage(
      id: const Uuid().v4(),
      text: trimmed,
      isUser: true,
      timestamp: DateTime.now(),
    );

    final updatedMessages = [...state.messages, userMsg];
    state = state.copyWith(messages: updatedMessages, isThinking: true);
    await ChatArchiveService.instance.saveActiveMessages(updatedMessages);

    final lower = trimmed.toLowerCase();
    final isBangla = state.language == 'bn' || _containsBangla(trimmed);

    // 1. Instant Test Alert Command
    if (lower.contains('test') ||
        lower.contains('চেক') ||
        lower.contains('check alert') ||
        lower.contains('notification')) {
      await NotificationService.instance.showInstantTestNotification(
        title: isBangla ? 'পিঙ্গো টেস্ট এলার্ট' : 'Pingo Test Alert',
        body: isBangla
            ? 'এলার্ম এবং নোটিফিকেশন ইঞ্জিন সফলভাবে সক্রিয় রয়েছে।'
            : 'Alarms and notification engine are fully operational.',
      );
      FcmService.instance.triggerBackendTestPush();

      final replyMsg = ChatMessage(
        id: const Uuid().v4(),
        text: isBangla
            ? 'আপনার ফোনে টেস্ট নোটিফিকেশন পাঠানো হয়েছে। ব্যানার এবং সাউন্ড আসলে সিস্টেম ১০০% প্রস্তুত।'
            : 'Instant test alert triggered. If you hear the chime and see the banner, notifications are operational.',
        isUser: false,
        timestamp: DateTime.now(),
      );

      _appendBotMessage(replyMsg);
      return;
    }

    // 2. Cancellation Command
    if (lower.contains('cancel') ||
        lower.contains('বাতিল') ||
        lower.contains('ক্যান্সেল') ||
        lower.contains('মুছে')) {
      final reminders = _ref.read(homeReminderProvider).reminders;
      if (reminders.isNotEmpty) {
        final toDelete = reminders.first;
        _ref.read(homeReminderProvider.notifier).deleteReminder(toDelete.id);

        final replyMsg = ChatMessage(
          id: const Uuid().v4(),
          text: isBangla
              ? 'আপনার সর্বশেষ রিমাইন্ডার "${toDelete.title}" বাতিল করা হয়েছে।'
              : 'Cancelled your latest reminder: "${toDelete.title}".',
          isUser: false,
          timestamp: DateTime.now(),
        );
        _appendBotMessage(replyMsg);
      } else {
        final replyMsg = ChatMessage(
          id: const Uuid().v4(),
          text: isBangla ? 'বাতিল করার মতো কোনো রিমাইন্ডার পাওয়া যায়নি।' : 'No active reminders found to cancel.',
          isUser: false,
          timestamp: DateTime.now(),
        );
        _appendBotMessage(replyMsg);
      }
      return;
    }

    // 3. Schedule / Agenda Query Command
    if (lower.contains('schedule') ||
        lower.contains('task') ||
        lower.contains('শিডিউল') ||
        lower.contains('কাজ') ||
        lower.contains('আজকে') ||
        lower.contains('today')) {
      final reminders = _ref.read(homeReminderProvider).reminders;
      final now = DateTime.now();
      final todayTasks = reminders.where((r) {
        return r.dueAt.year == now.year && r.dueAt.month == now.month && r.dueAt.day == now.day;
      }).toList();

      if (todayTasks.isEmpty) {
        final replyMsg = ChatMessage(
          id: const Uuid().v4(),
          text: isBangla
              ? 'আজকের জন্য কোনো শিডিউল বা কাজ পেন্ডিং নেই। আপনার দিনটি সুন্দর হোক!'
              : 'You have no scheduled tasks left for today. Everything is clear!',
          isUser: false,
          timestamp: DateTime.now(),
        );
        _appendBotMessage(replyMsg);
      } else {
        final summary = todayTasks.map((t) {
          final timeStr = DateFormat.jm().format(t.dueAt);
          final doneStr = t.isDone ? (isBangla ? ' (সম্পন্ন)' : ' (Done)') : '';
          return '• ${t.title} — $timeStr$doneStr';
        }).join('\n');

        final replyMsg = ChatMessage(
          id: const Uuid().v4(),
          text: isBangla
              ? 'আজকের আপনার শিডিউল তালিকা:\n\n$summary'
              : 'Here is your agenda for today:\n\n$summary',
          isUser: false,
          timestamp: DateTime.now(),
        );
        _appendBotMessage(replyMsg);
      }
      return;
    }

    // 4. Default: AI Parsing for Reminder Creation
    try {
      final aiService = _ref.read(aiApiServiceProvider);
      final parsed = await aiService.parseReminder(
        text: trimmed,
        timezone: 'Asia/Dhaka',
      );

      final DateTime effectiveDueAt = parsed.dueAt?.toLocal() ?? _heuristicDueAt(trimmed);
      final String effectiveTitle = parsed.title.isNotEmpty ? parsed.title : trimmed;
      final reminderId = const Uuid().v4();

      final reminderItem = ReminderItem(
        id: reminderId,
        title: effectiveTitle,
        dueAt: effectiveDueAt,
        category: _mapAiCategory(parsed.category),
        priority: parsed.priority == 'HIGH' || parsed.priority == 'URGENT'
            ? ReminderPriority.important
            : ReminderPriority.normal,
      );

      // Add to reminder engine (registers exact alarm and triggers backend sync)
      _ref.read(homeReminderProvider.notifier).addReminder(reminderItem);

      final replyMsg = ChatMessage(
        id: const Uuid().v4(),
        text: isBangla
            ? 'ঠিক আছে! আমি আপনার রিমাইন্ডার শিডিউল করেছি:'
            : 'Got it! I have scheduled your reminder:',
        isUser: false,
        timestamp: DateTime.now(),
        reminderId: reminderId,
        reminderTitle: effectiveTitle,
        reminderDueAt: effectiveDueAt,
        suggestedActions: isBangla
            ? ['মুছে ফেলুন', 'টেস্ট এলার্ট']
            : ['Cancel', 'Test Alert'],
      );

      _appendBotMessage(replyMsg);
    } catch (e) {
      // Fallback: Local heuristic parse
      final fallbackDue = _heuristicDueAt(trimmed);
      final reminderId = const Uuid().v4();
      final reminderItem = ReminderItem(
        id: reminderId,
        title: trimmed,
        dueAt: fallbackDue,
        category: ReminderCategory.personal,
      );
      _ref.read(homeReminderProvider.notifier).addReminder(reminderItem);

      final replyMsg = ChatMessage(
        id: const Uuid().v4(),
        text: isBangla
            ? 'রিমাইন্ডারটি সেভ করা হয়েছে:'
            : 'Saved your reminder:',
        isUser: false,
        timestamp: DateTime.now(),
        reminderId: reminderId,
        reminderTitle: trimmed,
        reminderDueAt: fallbackDue,
        suggestedActions: isBangla ? ['মুছে ফেলুন'] : ['Cancel'],
      );
      _appendBotMessage(replyMsg);
    }
  }

  void _appendBotMessage(ChatMessage botMsg) {
    final nextList = [...state.messages, botMsg];
    state = state.copyWith(messages: nextList, isThinking: false);
    ChatArchiveService.instance.saveActiveMessages(nextList);
  }

  DateTime _heuristicDueAt(String text) {
    final now = DateTime.now();
    final lower = text.toLowerCase();
    DateTime target = now;

    if (lower.contains('tomorrow') || lower.contains('কাল') || lower.contains('kalke')) {
      target = target.add(const Duration(days: 1));
    }

    // Default to 1 hour from now or 9 AM tomorrow
    if (target.day != now.day) {
      return DateTime(target.year, target.month, target.day, 9, 0);
    }
    return now.add(const Duration(hours: 1));
  }

  ReminderCategory _mapAiCategory(String? category) {
    if (category == null) return ReminderCategory.other;
    final lower = category.toLowerCase();
    if (lower.contains('med') || lower.contains('pill') || lower.contains('doctor')) {
      return ReminderCategory.medicine;
    }
    if (lower.contains('bill') || lower.contains('pay') || lower.contains('bank')) {
      return ReminderCategory.bill;
    }
    if (lower.contains('work') || lower.contains('meet') || lower.contains('office') || lower.contains('sync')) {
      return ReminderCategory.work;
    }
    if (lower.contains('birth') || lower.contains('party') || lower.contains('anniversary')) {
      return ReminderCategory.birthday;
    }
    if (lower.contains('personal') || lower.contains('home') || lower.contains('family')) {
      return ReminderCategory.personal;
    }
    return ReminderCategory.other;
  }

  bool _containsBangla(String text) {
    for (int i = 0; i < text.length; i++) {
      int code = text.codeUnitAt(i);
      if (code >= 0x0980 && code <= 0x09FF) return true;
    }
    return false;
  }
}

final pingoChatProvider =
    StateNotifierProvider<PingoChatNotifier, PingoChatState>((ref) {
  return PingoChatNotifier(ref);
});
