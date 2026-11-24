import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/network/providers.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/voice_audio_player_service.dart';
import '../../../action_stream/domain/ai_models.dart';
import '../../../voice_capture/data/voice_command_api_service.dart';
import '../../domain/chat_message.dart';
import '../../domain/reminder_item.dart';
import 'chat_archive_service.dart';
import 'home_reminder_provider.dart';

class PingoChatState {
  final List<ChatMessage> messages;
  final List<StagedAttachmentPreviewItem> stagedAttachments;
  final bool isStagingAttachment;
  final bool isThinking;
  final String language;
  final String sessionId;

  const PingoChatState({
    this.messages = const [],
    this.stagedAttachments = const [],
    this.isStagingAttachment = false,
    this.isThinking = false,
    this.language = 'en',
    required this.sessionId,
  });

  PingoChatState copyWith({
    List<ChatMessage>? messages,
    List<StagedAttachmentPreviewItem>? stagedAttachments,
    bool? isStagingAttachment,
    bool? isThinking,
    String? language,
    String? sessionId,
  }) {
    return PingoChatState(
      messages: messages ?? this.messages,
      stagedAttachments: stagedAttachments ?? this.stagedAttachments,
      isStagingAttachment: isStagingAttachment ?? this.isStagingAttachment,
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
    ChatArchiveService.instance.clearActiveMessages();
    _loadDeviceTimezone();
    _listenForTriggeredAlarms();
  }

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

  void _listenForTriggeredAlarms() {
    _alarmSub = NotificationService.instance.onAlarmTriggered.listen((event) {
      if (_shownTriggerIds.contains(event.id)) return;
      _shownTriggerIds.add(event.id);

      // Ensure zero-touch auto-completion runs immediately
      _ref
          .read(homeReminderProvider.notifier)
          .autoCompleteDueTasks(triggeredSafeId: event.id);

      final timeStr = DateFormat.jm().format(event.scheduledDate);
      final alertBubble = ChatMessage(
        id: const Uuid().v4(),
        text: 'Reminder completed ($timeStr): ${event.title}',
        isUser: false,
        timestamp: DateTime.now(),
        isAlarmTriggeredAlert: true,
        reminderTitle: event.title,
        reminderDueAt: event.scheduledDate,
      );
      _appendBotMessage(alertBubble);
    });
  }

  void reconcileTriggeredRemindersOnResume() {
    _ref.read(homeReminderProvider.notifier).autoCompleteDueTasks();
    final now = DateTime.now();
    final completedRecent = _ref
        .read(homeReminderProvider)
        .completedReminders
        .where((r) => now.difference(r.dueAt).inHours <= 2 && !r.dueAt.isAfter(now))
        .toList();

    for (final item in completedRecent) {
      final safeId = item.id.hashCode.abs() % 2147483647;
      if (_shownTriggerIds.contains(safeId)) continue;
      _shownTriggerIds.add(safeId);
      final timeStr = DateFormat.jm().format(item.dueAt);
      _appendBotMessage(
        ChatMessage(
          id: const Uuid().v4(),
          text: 'Reminder completed ($timeStr): ${item.title}',
          isUser: false,
          timestamp: DateTime.now(),
          isAlarmTriggeredAlert: true,
          reminderId: item.id,
          reminderTitle: item.title,
          reminderDueAt: item.dueAt,
          reminderCategory: item.category.badgeLabel,
        ),
      );
    }
  }

  @override
  void dispose() {
    _alarmSub?.cancel();
    super.dispose();
  }

  void setLanguage(String lang) {
    if (state.language == lang) return;
    state = state.copyWith(language: lang);
  }

  void suspendServices() {
    VoiceAudioPlayerService.instance.stop();
  }

  void startNewChat() {
    state = state.copyWith(
      messages: [],
      sessionId: const Uuid().v4(),
      isThinking: false,
    );
    ChatArchiveService.instance.clearActiveMessages();
  }

  // ───── Directive 3: Decoupled Attachment Staging (Composer Preview) ─────

  /// Uploads an image or document to `POST /api/attachments/stage` and places it in
  /// the uncommitted composer preview strip WITHOUT auto-sending.
  Future<bool> stageAttachmentForComposer(String filePath) async {
    state = state.copyWith(isStagingAttachment: true);
    try {
      final staged = await VoiceCommandApiService.instance.stageAttachment(
        filePath: filePath,
      );
      state = state.copyWith(
        stagedAttachments: [...state.stagedAttachments, staged],
        isStagingAttachment: false,
      );
      return true;
    } catch (e) {
      debugPrint('[PingoChat] Attachment staging error: $e');
      state = state.copyWith(isStagingAttachment: false);
      return false;
    }
  }

  void removeStagedPreview(String stagingId) {
    state = state.copyWith(
      stagedAttachments: state.stagedAttachments
          .where((s) => s.stagingId != stagingId)
          .toList(),
    );
  }

  // ───── Bundled Voice Transmission (`POST /api/voice-command`) ─────

  Future<void> sendVoiceCommandFile(String m4aPath) async {
    final pendingStaged = List<StagedAttachmentPreviewItem>.from(
      state.stagedAttachments,
    );
    final stagingIds = pendingStaged.map((s) => s.stagingId).toList();

    state = state.copyWith(
      isThinking: true,
      stagedAttachments: const [], // Clear composer preview immediately on send
    );

    try {
      final result = await VoiceCommandApiService.instance.uploadVoiceCommand(
        filePath: m4aPath,
        stagingIds: stagingIds.isEmpty ? null : stagingIds,
      );

      _applyAssistantTurnResult(
        result: result,
        fallbackAttachmentNames: pendingStaged.map((e) => e.filename).toList(),
        autoPlayVoice: true,
      );
    } catch (e) {
      debugPrint('[PingoChat] Voice command error: $e');
      // Restore staged preview items so user doesn't lose staged attachments on network hiccup
      final errBubble = ChatMessage(
        id: const Uuid().v4(),
        text: 'Could not process voice note right now. Please check your connection and try again.',
        isUser: false,
        timestamp: DateTime.now(),
      );
      state = state.copyWith(
        stagedAttachments: pendingStaged,
        messages: [...state.messages, errBubble],
        isThinking: false,
      );
    }
  }

  // ───── Text & Bundled Attachment Transmission ─────

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    final pendingStaged = List<StagedAttachmentPreviewItem>.from(
      state.stagedAttachments,
    );
    if (trimmed.isEmpty && pendingStaged.isEmpty) return;

    final effectiveText =
        trimmed.isNotEmpty ? trimmed : 'Save and review attached document';

    // When staged attachments are present, route through `/api/assistant/message`
    // so the backend bundles the staged attachment metadata in one atomic transaction!
    if (pendingStaged.isNotEmpty) {
      final stagingIds = pendingStaged.map((s) => s.stagingId).toList();
      state = state.copyWith(
        isThinking: true,
        stagedAttachments: const [],
      );
      try {
        final result =
            await VoiceCommandApiService.instance.sendBundledTextMessage(
          message: effectiveText,
          stagingIds: stagingIds,
          synthesizeTts: false,
        );
        _applyAssistantTurnResult(
          result: result,
          fallbackAttachmentNames:
              pendingStaged.map((e) => e.filename).toList(),
          autoPlayVoice: false,
        );
      } catch (e) {
        debugPrint('[PingoChat] Bundled text message error: $e');
        state = state.copyWith(
          stagedAttachments: pendingStaged,
          messages: [
            ...state.messages,
            ChatMessage(
              id: const Uuid().v4(),
              text: 'Could not send bundled message right now. Please try again.',
              isUser: false,
              timestamp: DateTime.now(),
            ),
          ],
          isThinking: false,
        );
      }
      return;
    }

    // Standard text message flow
    final userMsg = ChatMessage(
      id: const Uuid().v4(),
      text: effectiveText,
      isUser: true,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isThinking: true,
    );

    final lower = effectiveText.toLowerCase();
    if (_isConversationalCommentary(lower)) {
      _appendBotMessage(_botMsg(_generateConversationalResponse(lower)));
      return;
    }

    try {
      final aiService = _ref.read(aiApiServiceProvider);
      final parsed = await aiService.parseReminder(
        text: effectiveText,
        timezone: _deviceTimezone,
      );

      if (parsed.needsClarification) {
        _appendBotMessage(_botMsg(parsed.clarifyingQuestion!));
        return;
      }

      if (parsed.intent == ParsedReminderData.intentList) {
        _handleListIntent();
        return;
      } else if (parsed.intent == ParsedReminderData.intentCreate) {
        await _handleCreateIntent(effectiveText, parsed);
        return;
      }

      _appendBotMessage(_botMsg(_generateConversationalResponse(lower)));
    } catch (_) {
      final fallbackDue = _heuristicDueAt(effectiveText);
      final reminderId = const Uuid().v4();
      final reminderItem = ReminderItem(
        id: reminderId,
        title: effectiveText,
        dueAt: fallbackDue,
        category: ReminderCategory.general,
        priority: ReminderPriority.normal,
      );
      _ref.read(homeReminderProvider.notifier).addReminder(reminderItem);

      _appendBotMessage(
        ChatMessage(
          id: const Uuid().v4(),
          text: '',
          isUser: false,
          timestamp: DateTime.now(),
          reminderId: reminderId,
          reminderTitle: effectiveText,
          reminderDueAt: fallbackDue,
          reminderCategory: ReminderCategory.general.badgeLabel,
        ),
      );
    }
  }

  void _applyAssistantTurnResult({
    required VoiceCommandResult result,
    required List<String> fallbackAttachmentNames,
    required bool autoPlayVoice,
  }) {
    final bundledNames = result.bundledAttachments.isNotEmpty
        ? result.bundledAttachments
            .map((m) => (m['filename']?.toString() ?? 'attachment').trim())
            .toList()
        : fallbackAttachmentNames;

    final userBubble = ChatMessage(
      id: const Uuid().v4(),
      text: result.userSaid.isNotEmpty ? result.userSaid : '🎤 Voice note',
      isUser: true,
      timestamp: DateTime.now(),
      bundledAttachments: bundledNames,
    );

    String? scheduledReminderId;
    String? scheduledTitle;
    DateTime? scheduledDueAt;
    String? scheduledCategoryBadge;
    String? savedDocTitle;
    String? savedDocCategory;

    for (final action in result.actions) {
      if (action.tool == 'set_reminder') {
        final rawTitle =
            (action.arguments['task_title']?.toString() ?? 'Reminder').trim();
        final rawTime =
            (action.arguments['reminder_time']?.toString() ?? '').trim();
        final parsedDue = DateTime.tryParse(rawTime)?.toLocal() ??
            DateTime.now().add(const Duration(hours: 1));
        final cat = ReminderCategory.fromBackendString(action.category);

        final remId = action.recordId ?? const Uuid().v4();
        final item = ReminderItem(
          id: remId,
          title: rawTitle.isNotEmpty ? rawTitle : 'Reminder',
          dueAt: parsedDue,
          category: cat,
          priority: ReminderPriority.important,
        );

        _ref.read(homeReminderProvider.notifier).addReminder(item);

        scheduledReminderId = remId;
        scheduledTitle = item.title;
        scheduledDueAt = parsedDue;
        scheduledCategoryBadge = cat.badgeLabel;
      } else if (action.tool == 'save_documentation') {
        savedDocTitle =
            (action.arguments['title']?.toString() ?? 'Project Note').trim();
        savedDocCategory = action.category;
      }
    }

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
      reminderCategory: scheduledCategoryBadge,
      documentTitle: savedDocTitle,
      documentCategory: savedDocCategory,
    );

    state = state.copyWith(
      messages: [...state.messages, userBubble, aiBubble],
      isThinking: false,
    );

    if (autoPlayVoice && resolvedAudioUrl.isNotEmpty) {
      VoiceAudioPlayerService.instance.playUrl(
        messageId: aiMsgId,
        audioUrl: resolvedAudioUrl,
      );
    }
  }

  Future<void> _handleCreateIntent(
    String userText,
    ParsedReminderData parsed,
  ) async {
    if (parsed.needsClarification) {
      _appendBotMessage(_botMsg(parsed.clarifyingQuestion!));
      return;
    }

    final effectiveTitle =
        parsed.title.trim().isNotEmpty ? parsed.title.trim() : 'Reminder';
    final effectiveDueAt = parsed.dueAt?.toLocal() ?? _heuristicDueAt(userText);
    final reminderId = const Uuid().v4();
    final category = ReminderCategory.fromBackendString(parsed.category);

    final reminderItem = ReminderItem(
      id: reminderId,
      title: effectiveTitle,
      dueAt: effectiveDueAt,
      category: category,
      priority: parsed.priority == 'HIGH' || parsed.priority == 'URGENT'
          ? ReminderPriority.important
          : ReminderPriority.normal,
    );

    _ref.read(homeReminderProvider.notifier).addReminder(reminderItem);

    _appendBotMessage(
      ChatMessage(
        id: const Uuid().v4(),
        text: '',
        isUser: false,
        timestamp: DateTime.now(),
        reminderId: reminderId,
        reminderTitle: effectiveTitle,
        reminderDueAt: effectiveDueAt,
        reminderCategory: category.badgeLabel,
      ),
    );
  }

  void _handleListIntent() {
    final upcoming = _ref.read(homeReminderProvider).scheduledReminders
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));

    if (upcoming.isEmpty) {
      _appendBotMessage(_botMsg('You have no scheduled tasks right now.'));
      return;
    }

    final lines = upcoming.map((t) {
      final timeStr = DateFormat.jm().format(t.dueAt);
      final dateStr = DateFormat.MMMd().format(t.dueAt);
      return '• [${t.category.badgeLabel}] ${t.title} — $timeStr, $dateStr';
    }).join('\n');

    _appendBotMessage(_botMsg('Scheduled tasks:\n\n$lines'));
  }

  ChatMessage _botMsg(String text) => ChatMessage(
        id: const Uuid().v4(),
        text: text,
        isUser: false,
        timestamp: DateTime.now(),
      );

  void _appendBotMessage(ChatMessage botMsg) {
    state = state.copyWith(
      messages: [...state.messages, botMsg],
      isThinking: false,
    );
  }

  bool _isConversationalCommentary(String lower) {
    const conversationalTokens = [
      'hello',
      'hi',
      'hey',
      'good morning',
      'good evening',
      'good night',
      'how are you',
      'who are you',
      'thanks',
      'thank you',
      'bye',
      'goodbye',
      'okay',
      'ok',
    ];

    final cleaned =
        lower.replaceAll(RegExp(r'[^\w\s\u0980-\u09FF]'), '').trim();
    for (final token in conversationalTokens) {
      if (cleaned == token ||
          cleaned.startsWith('$token ') ||
          cleaned.endsWith(' $token')) {
        final hasSchedulingToken = cleaned.contains('pm') ||
            cleaned.contains('am') ||
            cleaned.contains('tomorrow') ||
            cleaned.contains('remind') ||
            cleaned.contains('alarm');
        if (!hasSchedulingToken) {
          return true;
        }
      }
    }
    return false;
  }

  String _generateConversationalResponse(String lower) {
    if (lower.contains('thank')) {
      return 'You are welcome. Send a voice note or message anytime.';
    }
    if (lower.contains('who are you')) {
      return 'I am Pingo, your autonomous voice and task assistant.';
    }
    return 'Send a message, attach a document, or hold the mic to speak.';
  }

  DateTime _heuristicDueAt(String text) {
    final now = DateTime.now();
    final lower = text.toLowerCase();
    if (lower.contains('tomorrow') ||
        lower.contains('কাল') ||
        lower.contains('kalke')) {
      final t = now.add(const Duration(days: 1));
      return DateTime(t.year, t.month, t.day, 9, 0);
    }
    return now.add(const Duration(hours: 1));
  }
}

final pingoChatProvider =
    StateNotifierProvider<PingoChatNotifier, PingoChatState>((ref) {
  return PingoChatNotifier(ref);
});
