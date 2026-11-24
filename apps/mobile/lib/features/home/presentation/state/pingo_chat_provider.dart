import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/network/providers.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/voice_audio_player_service.dart';
import '../../../../core/storage/local_storage_service.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import '../../../action_stream/domain/ai_models.dart';
import '../../../auth/presentation/state/auth_provider.dart';
import '../../../voice_capture/data/voice_command_api_service.dart';
import '../../../../core/services/voice_recognition_service.dart';
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
    this.language = 'en',
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
  StreamSubscription<TriggeredAlarmEvent>? _alarmSub;
  final Set<int> _shownTriggerIds = {};

  PingoChatNotifier(this._ref)
      : super(PingoChatState(sessionId: const Uuid().v4())) {
    // Fresh start on every launch: the chat screen is intentionally empty.
    // Saved reminders live in HomeReminderNotifier + local storage and are untouched.
    ChatArchiveService.instance.clearActiveMessages();
    _loadDeviceTimezone();
    _listenForTriggeredAlarms();
  }

  void _listenForTriggeredAlarms() {
    _alarmSub = NotificationService.instance.onAlarmTriggered.listen((event) {
      if (_shownTriggerIds.contains(event.id)) return;
      _shownTriggerIds.add(event.id);

      final timeStr = DateFormat.jm().format(event.scheduledDate);
      final alertBubble = ChatMessage(
        id: const Uuid().v4(),
        text: 'Reminder due now ($timeStr): ${event.title}',
        isUser: false,
        timestamp: DateTime.now(),
        isAlarmTriggeredAlert: true,
        reminderTitle: event.title,
        reminderDueAt: event.scheduledDate,
      );
      _appendBotMessage(alertBubble);
    });
  }

  /// Checks if any active reminder reached its scheduled time while the app was backgrounded/closed,
  /// and inserts its reminder bubble into the chat stream on resume.
  void reconcileTriggeredRemindersOnResume() {
    final now = DateTime.now();
    final dueItems = _ref
        .read(homeReminderProvider)
        .reminders
        .where((r) => !r.isDone && !r.dueAt.isAfter(now))
        .toList();

    for (final item in dueItems) {
      final safeId = item.id.hashCode.abs() % 2147483647;
      if (_shownTriggerIds.contains(safeId)) continue;
      // Only surface recently triggered reminders (within the last 2 hours)
      if (now.difference(item.dueAt).inHours <= 2) {
        _shownTriggerIds.add(safeId);
        final timeStr = DateFormat.jm().format(item.dueAt);
        _appendBotMessage(
          ChatMessage(
            id: const Uuid().v4(),
            text: 'Reminder due ($timeStr): ${item.title}',
            isUser: false,
            timestamp: DateTime.now(),
            isAlarmTriggeredAlert: true,
            reminderId: item.id,
            reminderTitle: item.title,
            reminderDueAt: item.dueAt,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _alarmSub?.cancel();
    super.dispose();
  }

  /// Device IANA timezone (e.g. 'Asia/Dhaka') sent with every parse request
  /// so the backend can resolve "in five minutes" / "kal bikel 5tay" locally.
  String _deviceTimezone = 'Asia/Dhaka';

  Future<void> _loadDeviceTimezone() async {
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      if (tzInfo.identifier.isNotEmpty) {
        _deviceTimezone = tzInfo.identifier;
      }
    } catch (e) {
      debugPrint('[PingoChat] Timezone lookup failed, keeping Asia/Dhaka: $e');
    }
  }

  void setLanguage(String lang) {
    if (state.language == lang) return;
    state = state.copyWith(language: lang);
  }

  ///Suspends ongoing voice capture and audio playback when backgrounded.
  void suspendServices() {
    debugPrint('[PingoChat] Suspending voice and audio playback services...');
    VoiceRecognitionService.instance.cancelListening();
    VoiceAudioPlayerService.instance.stop();
  }

  /// Uploads a recorded `.m4a` voice note to `POST /api/voice-command`,
  /// appends `user_said` (right) + `ai_reply` with Play/Pause voice note bar (left),
  /// auto-plays `$baseUrl$audioUrl` via `just_audio`, and schedules exact local alarms
  /// for every `set_reminder` tool action.
  Future<void> sendVoiceCommandFile(String m4aPath) async {
    state = state.copyWith(isThinking: true);

    try {
      final authState = _ref.read(authProvider);
      final userId = (authState.userEmail != null &&
              authState.userEmail!.trim().isNotEmpty)
          ? authState.userEmail!.trim()
          : await LocalStorageService.instance.getOrCreateDeviceId();

      final result = await VoiceCommandApiService.instance.uploadVoiceCommand(
        filePath: m4aPath,
        userId: userId,
      );

      // 1. User message bubble on the right (`user_said`)
      final userBubble = ChatMessage(
        id: const Uuid().v4(),
        text: result.userSaid.isNotEmpty ? result.userSaid : '🎤 Voice message',
        isUser: true,
        timestamp: DateTime.now(),
      );

      // 2. Inspect `actions` array for `set_reminder` and `save_documentation`
      String? scheduledReminderId;
      String? scheduledTitle;
      DateTime? scheduledDueAt;
      String? savedDocTitle;

      for (final action in result.actions) {
        if (action.tool == 'set_reminder') {
          final rawTitle =
              (action.arguments['task_title']?.toString() ?? 'Reminder').trim();
          final rawTime =
              (action.arguments['reminder_time']?.toString() ?? '').trim();
          final parsedDue = DateTime.tryParse(rawTime)?.toLocal() ??
              DateTime.now().add(const Duration(hours: 1));

          final remId = action.recordId ?? const Uuid().v4();
          final item = ReminderItem(
            id: remId,
            title: rawTitle.isNotEmpty ? rawTitle : 'Reminder',
            dueAt: parsedDue,
            category: _mapAiCategory(rawTitle),
            priority: ReminderPriority.important,
          );

          // Persist & schedule exact alarm (`zonedSchedule` with `exactAllowWhileIdle`, sound & vibration)
          _ref.read(homeReminderProvider.notifier).addReminder(item);

          scheduledReminderId = remId;
          scheduledTitle = item.title;
          scheduledDueAt = parsedDue;
        } else if (action.tool == 'save_documentation') {
          savedDocTitle =
              (action.arguments['title']?.toString() ?? 'Project Note').trim();
        }
      }

      // 3. AI reply bubble on the left (`ai_reply` + `$baseUrl$audioUrl`)
      final aiMsgId = const Uuid().v4();
      final resolvedAudioUrl = result.fullAudioUrl;

      final aiBubble = ChatMessage(
        id: aiMsgId,
        text: result.aiReply,
        isUser: false,
        timestamp: DateTime.now(),
        audioUrl: resolvedAudioUrl.isNotEmpty ? resolvedAudioUrl : null,
        reminderId: scheduledReminderId,
        reminderTitle: scheduledTitle,
        reminderDueAt: scheduledDueAt,
        isPendingConfirmation: false,
        documentTitle: savedDocTitle,
        documentCategory: savedDocTitle != null ? 'Documentation' : null,
      );

      state = state.copyWith(
        messages: [...state.messages, userBubble, aiBubble],
        isThinking: false,
      );

      // 4. Auto-play `$baseUrl$audioUrl` immediately via `just_audio`
      if (resolvedAudioUrl.isNotEmpty) {
        await VoiceAudioPlayerService.instance.playUrl(
          messageId: aiMsgId,
          audioUrl: resolvedAudioUrl,
        );
      }
    } catch (e) {
      debugPrint('[PingoChat] Voice command error: $e');
      final errBubble = ChatMessage(
        id: const Uuid().v4(),
        text: 'Could not process voice note right now. Please check your connection and try again.',
        isUser: false,
        timestamp: DateTime.now(),
      );
      state = state.copyWith(
        messages: [...state.messages, errBubble],
        isThinking: false,
      );
    }
  }

  /// 'New chat' menu action: clears the on-screen conversation.
  /// Chat history is not stored between launches; saved reminders are untouched.
  void startNewChat() {
    state = state.copyWith(
      messages: [],
      sessionId: const Uuid().v4(),
      isThinking: false,
    );
    ChatArchiveService.instance.clearActiveMessages();
  }

  /// Attaches a native file picked by the user and securely integrates it into conversational memory.
  Future<void> attachNativeFile({
    required String name,
    required String? path,
    required int size,
  }) async {
    final isBangla = state.language == 'bn';

    final userAttachmentMsg = ChatMessage(
      id: const Uuid().v4(),
      text: isBangla ? 'ডকুমেন্ট সংযুক্ত করা হলো: $name' : 'Attached document: $name',
      isUser: true,
      timestamp: DateTime.now(),
      documentTitle: name,
      filePath: path,
      fileSize: size,
    );

    final botConfirmationMsg = ChatMessage(
      id: const Uuid().v4(),
      text: isBangla
          ? 'ডকুমেন্ট এনক্রিপ্ট করে সংরক্ষণ করা হয়েছে। মেয়াদ এলার্ট সেট করতে কার্ডে ট্যাপ করুন।'
          : 'Document encrypted and stored. Tap the card to set an expiry alert.',
      isUser: false,
      timestamp: DateTime.now(),
      documentTitle: name,
      documentCategory: _inferCategoryFromFilename(name),
      filePath: path,
      fileSize: size,
    );

    final nextList = [...state.messages, userAttachmentMsg, botConfirmationMsg];
    state = state.copyWith(messages: nextList, isThinking: false);
  }

  /// Sets an expiry reminder alert for an attached document.
  Future<void> setDocumentExpiryReminder({
    required String documentTitle,
    required DateTime expiryDate,
  }) async {
    final isBangla = state.language == 'bn';
    final reminderId = const Uuid().v4();
    final reminderTitle = isBangla
        ? 'ডকুমেন্টের মেয়াদ উত্তীর্ণ: $documentTitle'
        : 'Document Expiry: $documentTitle';

    final reminderItem = ReminderItem(
      id: reminderId,
      title: reminderTitle,
      dueAt: expiryDate,
      category: ReminderCategory.bill,
      priority: ReminderPriority.important,
    );

    // Register alarm directly on user-confirmed date picker
    _ref.read(homeReminderProvider.notifier).addReminder(reminderItem);

    final replyMsg = ChatMessage(
      id: const Uuid().v4(),
      text: '',
      isUser: false,
      timestamp: DateTime.now(),
      reminderId: reminderId,
      reminderTitle: reminderTitle,
      reminderDueAt: expiryDate,
    );

    _appendBotMessage(replyMsg);
  }

  /// Mandatory Confirmation: Explicitly schedules the proposed reminder into system alarms.
  Future<void> confirmReminder(String messageId) async {
    final index = state.messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;

    final targetMsg = state.messages[index];
    if (targetMsg.reminderTitle == null || targetMsg.reminderDueAt == null) return;

    final reminderId = const Uuid().v4();
    final reminderItem = ReminderItem(
      id: reminderId,
      title: targetMsg.reminderTitle!,
      dueAt: targetMsg.reminderDueAt!,
      category: _mapAiCategory(targetMsg.pendingReminderCategory),
      priority: targetMsg.pendingReminderPriority == 'HIGH' ||
              targetMsg.pendingReminderPriority == 'URGENT'
          ? ReminderPriority.important
          : ReminderPriority.normal,
    );

    // Commit to the reminder engine & register exact alarm
    _ref.read(homeReminderProvider.notifier).addReminder(reminderItem);

    // Update the message state from pending to confirmed (compact confirmation bubble)
    final updatedMsg = targetMsg.copyWith(
      isPendingConfirmation: false,
      reminderId: reminderId,
      text: '',
      suggestedActions: const [],
    );

    final updatedList = List<ChatMessage>.from(state.messages);
    updatedList[index] = updatedMsg;
    state = state.copyWith(messages: updatedList);
  }

  /// Undoes an auto-saved reminder (or discards a pending one) and cancels its system alarm.
  Future<void> discardReminder(String messageId) async {
    final index = state.messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;

    final targetMsg = state.messages[index];
    if (targetMsg.reminderId != null) {
      _ref.read(homeReminderProvider.notifier).deleteReminder(targetMsg.reminderId!);
    }

    final updatedMsg = targetMsg.copyWith(
      isPendingConfirmation: false,
      clearReminder: true,
      text: 'Reminder removed',
      suggestedActions: const [],
    );

    final updatedList = List<ChatMessage>.from(state.messages);
    updatedList[index] = updatedMsg;
    state = state.copyWith(messages: updatedList);
  }

  /// Sends a message and orchestrates intent filtering, conversational commentary, and mandatory confirmation reminder proposals.
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

    final lower = trimmed.toLowerCase();
    final isBangla = state.language == 'bn' || _containsBangla(trimmed);

    // 1. Conversational pre-filter: greetings handled locally, no API call
    if (_isConversationalCommentary(lower)) {
      _appendBotMessage(_botMsg(_generateConversationalResponse(lower, isBangla)));
      return;
    }

    // 2. Intent-aware parsing through the backend AI gateway.
    //    The model returns ONE structured JSON object — never free-form replies.
    try {
      final aiService = _ref.read(aiApiServiceProvider);
      final parsed = await aiService.parseReminder(
        text: trimmed,
        timezone: _deviceTimezone,
      );

      if (parsed.needsClarification) {
        _appendBotMessage(_botMsg(parsed.clarifyingQuestion!));
        return;
      }

      if (parsed.intent == ParsedReminderData.intentList) {
        _handleListIntent(isBangla);
        return;
      } else if (parsed.intent == ParsedReminderData.intentDelete) {
        await _handleDeleteIntent(parsed, isBangla);
        return;
      } else if (parsed.intent == ParsedReminderData.intentUpdate) {
        await _handleUpdateIntent(parsed, isBangla);
        return;
      } else if (parsed.intent == ParsedReminderData.intentCreate) {
        await _handleCreateIntent(trimmed, parsed, isBangla);
        return;
      }

      // chat intent → local canned responses (AI never writes free-form replies)
      _appendBotMessage(_botMsg(_generateConversationalResponse(lower, false)));
    } catch (e) {
      // Fallback: local heuristic parse auto-saved immediately with Undo support
      final fallbackDue = _heuristicDueAt(trimmed);
      final reminderId = const Uuid().v4();
      final reminderItem = ReminderItem(
        id: reminderId,
        title: trimmed,
        dueAt: fallbackDue,
        category: ReminderCategory.personal,
        priority: ReminderPriority.normal,
      );
      _ref.read(homeReminderProvider.notifier).addReminder(reminderItem);

      final replyMsg = ChatMessage(
        id: const Uuid().v4(),
        text: '',
        isUser: false,
        timestamp: DateTime.now(),
        reminderId: reminderId,
        reminderTitle: trimmed,
        reminderDueAt: fallbackDue,
        isPendingConfirmation: false,
        pendingReminderCategory: 'personal',
      );
      _appendBotMessage(replyMsg);
    }
  }

  /// create_reminder: auto-saves and schedules immediately (no manual confirmation gate),
  /// while exposing a 1-tap Undo action on the confirmed card.
  Future<void> _handleCreateIntent(
      String userText, ParsedReminderData parsed, bool isBangla) async {
    if (parsed.needsClarification) {
      _appendBotMessage(_botMsg(parsed.clarifyingQuestion!));
      return;
    }

    final effectiveTitle = parsed.title.trim().isNotEmpty
        ? parsed.title.trim()
        : 'Reminder';
    final effectiveDueAt = parsed.dueAt?.toLocal() ?? _heuristicDueAt(userText);
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

    // Auto-save & schedule exact alarm immediately
    _ref.read(homeReminderProvider.notifier).addReminder(reminderItem);

    _appendBotMessage(ChatMessage(
      id: const Uuid().v4(),
      text: '',
      isUser: false,
      timestamp: DateTime.now(),
      reminderId: reminderId,
      reminderTitle: effectiveTitle,
      reminderDueAt: effectiveDueAt,
      isPendingConfirmation: false,
      pendingReminderCategory: parsed.category,
      pendingReminderPriority: parsed.priority,
    ));
  }

  /// list_reminders: agenda text built in app code from saved reminders.
  void _handleListIntent(bool isBangla) {
    final upcoming = _ref.read(homeReminderProvider).reminders
        .where((r) => !r.isDone)
        .toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));

    if (upcoming.isEmpty) {
      _appendBotMessage(_botMsg(isBangla
          ? 'এখন কোনো আসন্ন রিমাইন্ডার নেই।'
          : 'You have no upcoming reminders right now.'));
      return;
    }

    final lines = upcoming.map((t) {
      final timeStr = DateFormat.jm().format(t.dueAt);
      final dateStr = DateFormat.MMMd().format(t.dueAt);
      return '• ${t.title} — $timeStr, $dateStr';
    }).join('\n');

    _appendBotMessage(_botMsg(isBangla
        ? 'আপনার আসন্ন রিমাইন্ডারগুলো:\n\n$lines'
        : 'Here are your upcoming reminders:\n\n$lines'));
  }

  /// delete_reminder: one unambiguous match → remove; ambiguous → list & ask.
  Future<void> _handleDeleteIntent(ParsedReminderData parsed, bool isBangla) async {
    final active = _ref.read(homeReminderProvider).reminders
        .where((r) => !r.isDone)
        .toList();

    final query = parsed.title.trim().toLowerCase();
    final matches = query.isEmpty
        ? active
        : active.where((r) => r.title.toLowerCase().contains(query)).toList();

    if (matches.length == 1) {
      final target = matches.first;
      _ref.read(homeReminderProvider.notifier).deleteReminder(target.id);
      _appendBotMessage(_botMsg(isBangla
          ? 'মুছে ফেলা হয়েছে: "${target.title}"'
          : 'Removed: "${target.title}".'));
      return;
    }

    if (matches.length > 1) {
      final lines = matches
          .map((t) => '• ${t.title} — ${DateFormat.jm().format(t.dueAt)}')
          .join('\n');
      _appendBotMessage(_botMsg(isBangla
          ? 'একাধিক রিমাইন্ডার মিলেছে। কোনটি মুছবেন?\n\n$lines'
          : 'Multiple reminders matched. Which one should I remove?\n\n$lines'));
      return;
    }

    _appendBotMessage(_botMsg(isBangla
        ? 'মুছতে হবে এমন কোনো রিমাইন্ডার খুঁজে পাইনি।'
        : 'I could not find a matching reminder to delete.'));
  }

  /// update_reminder: title match + new time → reschedule; otherwise ask.
  Future<void> _handleUpdateIntent(ParsedReminderData parsed, bool isBangla) async {
    if (parsed.needsClarification || parsed.dueAt == null) {
      _appendBotMessage(_botMsg(parsed.clarifyingQuestion ??
          (isBangla
              ? 'নতুন সময়টা কী হবে?'
              : 'What should the new time be?')));
      return;
    }

    final active = _ref.read(homeReminderProvider).reminders
        .where((r) => !r.isDone)
        .toList();
    final query = parsed.title.trim().toLowerCase();
    final matches = query.isEmpty
        ? <ReminderItem>[]
        : active.where((r) => r.title.toLowerCase().contains(query)).toList();

    if (matches.length == 1) {
      final target = matches.first;
      final newDue = parsed.dueAt!.toLocal();
      final updated = target.copyWith(dueAt: newDue);
      _ref.read(homeReminderProvider.notifier).updateReminder(updated);
      final timeStr = DateFormat.jm().format(newDue);
      final dateStr = DateFormat.MMMd().format(newDue);
      _appendBotMessage(_botMsg(isBangla
          ? 'আপডেট হয়েছে: "${target.title}" এখন $timeStr, $dateStr।'
          : 'Updated: "${target.title}" rescheduled to $timeStr, $dateStr.'));
      return;
    }

    if (matches.length > 1) {
      final lines = matches
          .map((t) => '• ${t.title} — ${DateFormat.jm().format(t.dueAt)}')
          .join('\n');
      _appendBotMessage(_botMsg(isBangla
          ? 'একাধিক রিমাইন্ডার মিলেছে। কোনটি আপডেট করবেন?\n\n$lines'
          : 'Multiple reminders matched. Which one should I update?\n\n$lines'));
      return;
    }

    _appendBotMessage(_botMsg(isBangla
        ? 'আপডেট করার মতো কোনো রিমাইন্ডার খুঁজে পাইনি।'
        : 'I could not find a matching reminder to update.'));
  }

  ChatMessage _botMsg(String text) => ChatMessage(
        id: const Uuid().v4(),
        text: text,
        isUser: false,
        timestamp: DateTime.now(),
      );

  void _appendBotMessage(ChatMessage botMsg) {
    final nextList = [...state.messages, botMsg];
    state = state.copyWith(messages: nextList, isThinking: false);
  }

  bool _isConversationalCommentary(String lower) {
    // Pure conversational greetings or chatter
    const conversationalTokens = [
      'hello', 'hi', 'hey', 'good morning', 'good evening', 'good night',
      'how are you', 'what are you', 'who are you', 'thanks', 'thank you',
      'welcome', 'bye', 'goodbye', 'okay', 'ok', 'great', 'awesome', 'nice',
      'হাই', 'হ্যালো', 'কেমন আছো', 'কেমন আছেন', 'ধন্যবাদ', 'থ্যাংকস',
      'শুভ সকাল', 'শুভ রাত্রি', 'ঠিক আছে', 'আচ্ছা', 'বিদায়', 'কে তুমি',
    ];

    final cleaned = lower.replaceAll(RegExp(r'[^\w\s\u0980-\u09FF]'), '').trim();
    for (final token in conversationalTokens) {
      if (cleaned == token || cleaned.startsWith('$token ') || cleaned.endsWith(' $token')) {
        // Ensure no scheduling keywords like 'at', 'pm', 'am', 'tomorrow', 'কাল'
        final hasSchedulingToken = cleaned.contains('pm') ||
            cleaned.contains('am') ||
            cleaned.contains('কাল') ||
            cleaned.contains('আজ') ||
            cleaned.contains('tomorrow') ||
            cleaned.contains('remind') ||
            cleaned.contains('রিমাইন্ডার') ||
            cleaned.contains('alarm');
        if (!hasSchedulingToken) {
          return true;
        }
      }
    }
    return false;
  }

  String _generateConversationalResponse(String lower, bool isBangla) {
    if (lower.contains('thank') || lower.contains('ধন্যবাদ')) {
      return isBangla
          ? 'স্বাগতম। নতুন কোনো রিমাইন্ডার বা নোট থাকলে জানান।'
          : 'You are welcome. Tell me whenever you want to set an alarm or note.';
    }
    if (lower.contains('how are you') || lower.contains('কেমন আছো')) {
      return isBangla
          ? 'সব ঠিকঠাক চলছে। আজ কী মনে করিয়ে দিতে হবে?'
          : 'Ready when you are. What should I remind you about today?';
    }
    if (lower.contains('who are you') || lower.contains('কে তুমি')) {
      return isBangla
          ? 'আমি পিঙ্গো, আপনার ব্যক্তিগত রিমাইন্ডার এবং ডকুমেন্ট সহকারী।'
          : 'I am Pingo, your personal reminder and document ledger.';
    }
    return isBangla
        ? 'রিমাইন্ডার লিখুন বা বলুন, অথবা ডকুমেন্ট যুক্ত করুন।'
        : 'Type or speak a reminder, or attach a document.';
  }

  String _inferCategoryFromFilename(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('passport') || lower.contains('nid') || lower.contains('license') || lower.contains('id')) {
      return 'Identity';
    }
    if (lower.contains('bill') || lower.contains('invoice') || lower.contains('receipt') || lower.contains('tax')) {
      return 'Finance';
    }
    if (lower.contains('health') || lower.contains('medical') || lower.contains('prescription')) {
      return 'Health';
    }
    return 'General';
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
