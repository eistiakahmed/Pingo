import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:pingo_mobile/core/network/providers.dart';
import 'package:pingo_mobile/core/services/notification_service.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';
import 'package:pingo_mobile/features/home/domain/reminder_item.dart';
import 'package:pingo_mobile/features/home/presentation/state/home_reminder_provider.dart';
import 'package:pingo_mobile/features/voice_capture/presentation/screens/pingo_voice_screen.dart';

enum FlowScenario {
  autoSaved,
  askAboutToday,
  askQuestion,
}

/// Screen implementing conversational flows powered by AI with local fallback and punctual alerts.
class PingoFlowScreen extends ConsumerStatefulWidget {
  final FlowScenario scenario;
  final String initialPrompt;

  const PingoFlowScreen({
    super.key,
    required this.scenario,
    required this.initialPrompt,
  });

  static void open(BuildContext context,
      {required FlowScenario scenario, required String prompt}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PingoFlowScreen(scenario: scenario, initialPrompt: prompt),
      ),
    );
  }

  @override
  ConsumerState<PingoFlowScreen> createState() => _PingoFlowScreenState();
}

class _PingoFlowScreenState extends ConsumerState<PingoFlowScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Dynamic state for auto-saved reminder
  late FlowScenario _activeScenario;
  late String _taskTitle;
  late String _taskDate;
  late String _taskTime;
  bool _hasFollowUpUpdate = false;
  String _followUpTime = '6:00 PM';
  final String _reminderAlert = 'At time of event';
  bool _hasSavedInitial = false;
  bool _isLoadingAi = false;
  String? _lastCreatedReminderId;

  // Follow-up conversation bubbles: List of Map<String, dynamic> { 'isUser': bool, 'text': String, 'isLoading'?: bool }
  final List<Map<String, dynamic>> _conversationHistory = [];

  // State for Ask Question scenario
  String? _selectedTime;

  @override
  void initState() {
    super.initState();
    _activeScenario = widget.scenario;
    _parseInitialPrompt();

    // Trigger AI parsing for reminder creation
    if (widget.scenario != FlowScenario.askAboutToday) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _processPromptWithAi(widget.initialPrompt);
      });
    }
  }

  Future<void> _processPromptWithAi(String prompt) async {
    if (_hasSavedInitial) return;

    final lowerPrompt = prompt.toLowerCase();
    if (lowerPrompt.contains('test') ||
        lowerPrompt.contains('চেক') ||
        lowerPrompt.contains('check alert')) {
      await NotificationService.instance.showInstantTestNotification();
      final isPermitted =
          await NotificationService.instance.areNotificationsEnabled();
      if (mounted) {
        setState(() {
          _activeScenario = FlowScenario.autoSaved;
          _taskTitle = 'Instant Test Alert 🔔';
          _taskDate = 'Today';
          _taskTime = DateFormat.jm().format(DateTime.now());
          _isLoadingAi = false;
          _hasSavedInitial = true;
          _conversationHistory.add({
            'isUser': false,
            'text': isPermitted
                ? '🔔 Triggered an instant test notification on your screen right now!\n\nIf you see the notification banner and hear the sound, notifications are working 100%.'
                : '⚠️ Notifications are currently BLOCKED in your phone settings.\n\nPlease open your phone\'s Settings > Apps > Pingo > Notifications and turn on:\n• Allow notifications\n• Floating notifications\n• Lock screen notifications',
          });
        });
      }
      return;
    }

    setState(() => _isLoadingAi = true);

    try {
      final aiService = ref.read(aiApiServiceProvider);
      final parsed = await aiService.parseReminder(
        text: prompt,
        timezone: 'Asia/Dhaka',
      );

      final bool hasHeuristicTime = _hasTimeHeuristic(prompt);

      if (parsed.dueAt != null) {
        _hasSavedInitial = true;
        final localDue = parsed.dueAt!.toLocal();
        final newId = const Uuid().v4();
        final finalTitle = parsed.title.isNotEmpty ? parsed.title : prompt;

        final item = ReminderItem(
          id: newId,
          title: finalTitle,
          dueAt: localDue,
          category: _mapAiCategory(parsed.category),
          priority: parsed.priority == 'HIGH' || parsed.priority == 'URGENT'
              ? ReminderPriority.important
              : ReminderPriority.normal,
        );

        ref.read(homeReminderProvider.notifier).addReminder(item);
        _lastCreatedReminderId = newId;

        if (mounted) {
          setState(() {
            _activeScenario = FlowScenario.autoSaved;
            _taskTitle = finalTitle;
            _taskDate = _formatAiDate(localDue);
            _taskTime = DateFormat.jm().format(localDue);
            _isLoadingAi = false;
          });
        }
        return;
      } else if (hasHeuristicTime) {
        // AI returned due_at as null, but user explicitly mentioned a date/time (e.g. 9 AM, 12 AM, kalke)!
        // Save automatically using our reliable local scheduler without confusing the user!
        _hasSavedInitial = true;
        final localDue = _calculateDueAt(_taskDate, _taskTime);
        final newId = const Uuid().v4();
        final finalTitle = parsed.title.isNotEmpty ? parsed.title : prompt;

        final item = ReminderItem(
          id: newId,
          title: finalTitle,
          dueAt: localDue,
          category: _mapAiCategory(parsed.category),
          priority: ReminderPriority.normal,
        );

        ref.read(homeReminderProvider.notifier).addReminder(item);
        _lastCreatedReminderId = newId;

        if (mounted) {
          setState(() {
            _activeScenario = FlowScenario.autoSaved;
            _taskTitle = finalTitle;
            _taskDate = _formatAiDate(localDue);
            _taskTime = DateFormat.jm().format(localDue);
            _isLoadingAi = false;
          });
        }
        return;
      } else {
        // Genuine case: No time mentioned anywhere (e.g. "Buy groceries")
        if (mounted) {
          setState(() {
            _activeScenario = FlowScenario.askQuestion;
            _taskTitle = parsed.title.isNotEmpty ? parsed.title : prompt;
            _isLoadingAi = false;
          });
        }
        return;
      }
    } catch (e) {
      debugPrint('[PingoFlowScreen] AI parsing error, falling back to local: $e');
    }

    // Local fallback if AI fails or network unavailable
    _persistLocalAutoSavedReminder();
    if (mounted) {
      setState(() => _isLoadingAi = false);
    }
  }

  bool _hasTimeHeuristic(String text) {
    final lower = text.toLowerCase();
    final hasNumber = RegExp(r'[0-9০-৯]').hasMatch(lower);
    final hasDate = lower.contains('tomorrow') ||
        lower.contains('today') ||
        lower.contains('tonight') ||
        lower.contains('কাল') ||
        lower.contains('আগামীকাল') ||
        lower.contains('পরশু') ||
        lower.contains('kalke');
    final hasTime = lower.contains('am') ||
        lower.contains('pm') ||
        lower.contains('সকাল') ||
        lower.contains('রাত') ||
        lower.contains('সন্ধ্যা') ||
        lower.contains('বিকাল') ||
        lower.contains('টা') ||
        lower.contains('tar') ||
        lower.contains('hour') ||
        lower.contains('somoy') ||
        lower.contains('সময়');
    return (hasNumber && (hasTime || hasDate)) || (hasDate && hasTime);
  }

  void _persistLocalAutoSavedReminder() {
    if (_hasSavedInitial) return;
    _hasSavedInitial = true;

    final dueAt = _calculateDueAt(_taskDate, _taskTime);
    final newId = const Uuid().v4();
    final item = ReminderItem(
      id: newId,
      title: _taskTitle,
      dueAt: dueAt,
      category: _inferCategory(_taskTitle),
    );
    ref.read(homeReminderProvider.notifier).addReminder(item);
    _lastCreatedReminderId = newId;
  }

  ReminderCategory _mapAiCategory(String cat) {
    switch (cat.toUpperCase()) {
      case 'MEDICINE':
        return ReminderCategory.medicine;
      case 'BILL':
        return ReminderCategory.bill;
      case 'WORK':
        return ReminderCategory.work;
      case 'PERSONAL':
        return ReminderCategory.personal;
      case 'BIRTHDAY':
        return ReminderCategory.birthday;
      default:
        return ReminderCategory.other;
    }
  }

  String _formatAiDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);
    final diff = target.difference(today).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == 2) return 'Day after tomorrow';
    return DateFormat('EEEE, MMM d').format(dt);
  }

  ReminderCategory _inferCategory(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('medicine') ||
        lower.contains('ঔষধ') ||
        lower.contains('doctor') ||
        lower.contains('ডাক্তার')) {
      return ReminderCategory.medicine;
    }
    if (lower.contains('bill') ||
        lower.contains('বিল') ||
        lower.contains('pay') ||
        lower.contains('টাকা')) {
      return ReminderCategory.bill;
    }
    if (lower.contains('meeting') ||
        lower.contains('মিটিং') ||
        lower.contains('work') ||
        lower.contains('office')) {
      return ReminderCategory.work;
    }
    if (lower.contains('birthday') || lower.contains('জন্মদিন')) {
      return ReminderCategory.birthday;
    }
    return ReminderCategory.other;
  }

  DateTime _calculateDueAt(String dateStr, String timeStr) {
    final now = DateTime.now();
    DateTime baseDate = now;
    if (dateStr == 'Tomorrow') {
      baseDate = now.add(const Duration(days: 1));
    } else if (dateStr == 'Day after tomorrow') {
      baseDate = now.add(const Duration(days: 2));
    }

    int hour = 9;
    int minute = 0;
    final cleanTime = timeStr.toUpperCase();
    final match =
        RegExp(r'(\d{1,2}):?(\d{2})?\s*(AM|PM)?').firstMatch(cleanTime);
    if (match != null) {
      hour = int.tryParse(match.group(1) ?? '9') ?? 9;
      minute = int.tryParse(match.group(2) ?? '0') ?? 0;
      final period = match.group(3);
      if (period == 'PM' && hour < 12) {
        hour += 12;
      } else if (period == 'AM' && hour == 12) {
        hour = 0;
      }
    }

    final target =
        DateTime(baseDate.year, baseDate.month, baseDate.day, hour, minute);
    // If set for 'Today' but that time has already passed today (e.g., 12 AM midnight, or 9 AM in afternoon),
    // roll over to the upcoming occurrence (tonight / tomorrow)!
    if (dateStr == 'Today' &&
        target.isBefore(now.subtract(const Duration(minutes: 1)))) {
      return target.add(const Duration(days: 1));
    }
    return target;
  }

  void _parseInitialPrompt() {
    final prompt = widget.initialPrompt.trim();
    if (prompt.isEmpty) {
      _taskTitle = 'New Reminder';
    } else {
      _taskTitle = prompt;
    }
    _taskDate = 'Today';
    _taskTime = '9:00 AM';

    // Normalize Bangla digits to standard numerals
    final Map<String, String> bnDigits = {
      '১': '1',
      '২': '2',
      '৩': '3',
      '৪': '4',
      '৫': '5',
      '৬': '6',
      '৭': '7',
      '৮': '8',
      '৯': '9',
      '০': '0'
    };
    String normalized = prompt;
    bnDigits.forEach((k, v) => normalized = normalized.replaceAll(k, v));
    final lower = normalized.toLowerCase();

    // Dates
    if (lower.contains('tomorrow') ||
        lower.contains('কাল') ||
        lower.contains('আগামীকাল') ||
        lower.contains('kalke')) {
      _taskDate = 'Tomorrow';
    } else if (lower.contains('পরশু')) {
      _taskDate = 'Day after tomorrow';
    } else if (lower.contains('10th')) {
      _taskDate = '10th of this month';
    }

    // Dynamic Time Matcher (e.g. 9:00 a.m., 9 am, 9:00, ৯টা, 9 tar)
    final timeMatch = RegExp(
            r'(\d{1,2}(:\d{2})?\s*(am|pm|a\.m\.|p\.m\.)|\b\d{1,2}(:\d{2})?\b(?=\s*(টা|tar|টার)))',
            caseSensitive: false)
        .firstMatch(lower);
    if (timeMatch != null) {
      String raw = timeMatch.group(0)!.replaceAll('.', '').toUpperCase().trim();
      if (raw.contains('PM') || raw.contains('AM')) {
        _taskTime = raw;
      } else if (lower.contains('সকাল') || lower.contains('morning')) {
        _taskTime = raw.contains(':') ? '$raw AM' : '$raw:00 AM';
      } else if (lower.contains('রাত') ||
          lower.contains('সন্ধ্যা') ||
          lower.contains('বিকাল') ||
          lower.contains('night') ||
          lower.contains('evening')) {
        _taskTime = raw.contains(':') ? '$raw PM' : '$raw:00 PM';
      } else {
        _taskTime = raw.contains(':') ? '$raw AM' : '$raw:00 AM';
      }
    } else if (lower.contains('5 pm') || lower.contains('5:00')) {
      _taskTime = '5:00 PM';
    } else if (lower.contains('9 pm') || lower.contains('9:00')) {
      _taskTime = '9:00 PM';
    } else if (lower.contains('8 am') || lower.contains('8:00')) {
      _taskTime = '8:00 AM';
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _handleSend(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _inputController.clear();

    final lower = trimmed.toLowerCase();

    // 0. Instant Alert Test Command (e.g. "test alert", "নোটিফিকেশন এলার্ট চেক", "check notification")
    final isTestAlert = lower.contains('test') ||
        lower.contains('চেক') ||
        lower.contains('check alert') ||
        lower.contains('check notification');
    if (isTestAlert) {
      await NotificationService.instance.showInstantTestNotification(
        title: 'Pingo Test Alert 🔔',
        body: 'Alarms & notifications are active and punctually working!',
      );
      final isPermitted =
          await NotificationService.instance.areNotificationsEnabled();
      final isExactAllowed =
          await NotificationService.instance.canScheduleExactAlarms();

      setState(() {
        _conversationHistory.add({
          'isUser': true,
          'text': trimmed,
        });
        if (isPermitted && isExactAllowed) {
          _conversationHistory.add({
            'isUser': false,
            'text':
                '🔔 Instant test alert sent!\n\nAll notification and exact alarm permissions are active. Your punctual reminders will fire on time.',
          });
        } else if (!isPermitted) {
          _conversationHistory.add({
            'isUser': false,
            'text':
                '⚠️ Notifications are currently BLOCKED in your phone settings.\n\nPlease open Settings > Apps > Pingo > Notifications and turn on:\n• Allow notifications\n• Floating notifications (heads-up banners)\n• Lock screen notifications',
          });
        } else {
          _conversationHistory.add({
            'isUser': false,
            'text':
                '⚠️ Exact Alarms permission is restricted on your device.\n\nPlease open Settings > Apps > Pingo > Alarms & reminders and allow "Setting alarms and reminders" for exact timing.',
          });
        }
      });
      _scrollToBottom();
      return;
    }

    // 1. Cancellation command
    final isCancel = lower.contains('cancel') ||
        lower.contains('delete') ||
        lower.contains('remove') ||
        lower.contains('বাতিল') ||
        lower.contains('ক্যান্সেল') ||
        lower.contains('মুছে') ||
        lower.contains('বাদ');
    if (isCancel) {
      String? toDeleteId = _lastCreatedReminderId;
      if (toDeleteId == null) {
        final currentReminders = ref.read(homeReminderProvider).reminders;
        if (currentReminders.isNotEmpty) {
          toDeleteId = currentReminders.first.id;
        }
      }

      if (toDeleteId != null) {
        ref.read(homeReminderProvider.notifier).deleteReminder(toDeleteId);
        _lastCreatedReminderId = null;
        setState(() {
          _conversationHistory.add({
            'isUser': true,
            'text': trimmed,
          });
          _conversationHistory.add({
            'isUser': false,
            'text': 'Cancelled this reminder for you.',
          });
        });
      } else {
        setState(() {
          _conversationHistory.add({
            'isUser': true,
            'text': trimmed,
          });
          _conversationHistory.add({
            'isUser': false,
            'text': 'There are no active reminders to cancel.',
          });
        });
      }
      _scrollToBottom();
      return;
    }

    // 2. Querying tasks
    final isQueryTasks = lower.contains('what') ||
        lower.contains('task') ||
        lower.contains('tasks') ||
        lower.contains('schedule') ||
        lower.contains('show') ||
        lower.contains('কাল') ||
        lower.contains('টাস্ক');
    if (isQueryTasks) {
      final isTomorrow = lower.contains('tomorrow') ||
          lower.contains('কাল') ||
          lower.contains('আগামীকাল') ||
          lower.contains('kalke');
      final targetDate = isTomorrow
          ? DateTime.now().add(const Duration(days: 1))
          : DateTime.now();
      final label = isTomorrow ? 'tomorrow' : 'today';

      final allReminders = ref.read(homeReminderProvider).reminders;
      final matching = allReminders.where((r) {
        return r.dueAt.year == targetDate.year &&
            r.dueAt.month == targetDate.month &&
            r.dueAt.day == targetDate.day;
      }).toList();

      setState(() {
        _conversationHistory.add({
          'isUser': true,
          'text': trimmed,
        });
        if (matching.isEmpty) {
          _conversationHistory.add({
            'isUser': false,
            'text': 'You have no tasks scheduled for $label!',
          });
        } else {
          final summary = matching
              .map((t) =>
                  '• ${t.title} at ${DateFormat.jm().format(t.dueAt)}${t.isDone ? " (Done)" : ""}')
              .join('\n');
          _conversationHistory.add({
            'isUser': false,
            'text': 'Here are your tasks for $label:\n$summary',
          });
        }
      });
      _scrollToBottom();
      return;
    }

    // 3. User answering "What time should I remind you?" when in askQuestion mode
    if (_activeScenario == FlowScenario.askQuestion) {
      if (_hasTimeHeuristic(trimmed)) {
        final dueAt = _calculateDueAt('Today', trimmed);
        final newId = const Uuid().v4();
        final item = ReminderItem(
          id: newId,
          title: _taskTitle,
          dueAt: dueAt,
          category: _inferCategory(_taskTitle),
        );
        ref.read(homeReminderProvider.notifier).addReminder(item);
        _lastCreatedReminderId = newId;

        setState(() {
          _activeScenario = FlowScenario.autoSaved;
          _taskTime = DateFormat.jm().format(dueAt);
          _conversationHistory.add({
            'isUser': true,
            'text': trimmed,
          });
          _conversationHistory.add({
            'isUser': false,
            'text':
                'Saved: "$_taskTitle" at ${DateFormat.jm().format(dueAt)} (${_formatAiDate(dueAt)}).',
          });
        });
        _scrollToBottom();
        return;
      }
    }

    // 4. Time or date modification requests (e.g. "move to 5 pm", "modify date")
    final isTimeOrDateUpdate = lower.contains('hour') ||
        lower.contains('make it') ||
        lower.contains('pm') ||
        lower.contains('am') ||
        lower.contains('move to') ||
        lower.contains('modify') ||
        lower.contains('change') ||
        lower.contains('update');
    if (isTimeOrDateUpdate) {
      final hasTime = RegExp(r'(\d{1,2}(:\d{2})?\s*(am|pm|a\.m\.|p\.m\.)|\b\d{1,2}(:\d{2})?\b(?=\s*(টা|tar|টার)))', caseSensitive: false).hasMatch(lower);
      if (hasTime || lower.contains('tomorrow') || lower.contains('কাল') || lower.contains('today')) {
        setState(() {
          _hasFollowUpUpdate = true;
          _followUpTime = trimmed;
          _conversationHistory.add({
            'isUser': true,
            'text': trimmed,
          });
          _conversationHistory.add({
            'isUser': false,
            'text': 'Got it! I updated the reminder time to $trimmed.',
          });
        });
      } else {
        setState(() {
          _conversationHistory.add({
            'isUser': true,
            'text': trimmed,
          });
          _conversationHistory.add({
            'isUser': false,
            'text': 'What new time or date should I set for this reminder?',
          });
        });
      }
      _scrollToBottom();
      return;
    }

    // 5. Natural language reminder parsing
    setState(() {
      _conversationHistory.add({
        'isUser': true,
        'text': trimmed,
      });
      _conversationHistory.add({
        'isUser': false,
        'text': 'Organizing...',
        'isLoading': true,
      });
    });
    _scrollToBottom();

    try {
      final aiService = ref.read(aiApiServiceProvider);
      final parsed = await aiService.parseReminder(
        text: trimmed,
        timezone: 'Asia/Dhaka',
      );

      final finalTitle = parsed.title.isNotEmpty ? parsed.title : trimmed;
      if (parsed.dueAt != null) {
        final localDue = parsed.dueAt!.toLocal();
        final newId = const Uuid().v4();
        final item = ReminderItem(
          id: newId,
          title: finalTitle,
          dueAt: localDue,
          category: _mapAiCategory(parsed.category),
          priority: parsed.priority == 'HIGH' || parsed.priority == 'URGENT'
              ? ReminderPriority.important
              : ReminderPriority.normal,
        );
        ref.read(homeReminderProvider.notifier).addReminder(item);
        _lastCreatedReminderId = newId;

        if (mounted) {
          setState(() {
            _conversationHistory.removeLast();
            _conversationHistory.add({
              'isUser': false,
              'text':
                  'Saved: "$finalTitle" at ${DateFormat.jm().format(localDue)} (${_formatAiDate(localDue)}).',
            });
          });
        }
      } else if (_hasTimeHeuristic(trimmed)) {
        // Fallback with local time calculation
        final localDue = _calculateDueAt('Today', trimmed);
        final newId = const Uuid().v4();
        final item = ReminderItem(
          id: newId,
          title: finalTitle,
          dueAt: localDue,
          category: _mapAiCategory(parsed.category),
          priority: ReminderPriority.normal,
        );
        ref.read(homeReminderProvider.notifier).addReminder(item);
        _lastCreatedReminderId = newId;

        if (mounted) {
          setState(() {
            _conversationHistory.removeLast();
            _conversationHistory.add({
              'isUser': false,
              'text':
                  'Saved: "$finalTitle" at ${DateFormat.jm().format(localDue)} (${_formatAiDate(localDue)}).',
            });
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _conversationHistory.removeLast();
            _conversationHistory.add({
              'isUser': false,
              'text': 'What time should I remind you about "$finalTitle"?',
            });
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _conversationHistory.removeLast();
          _conversationHistory.add({
            'isUser': false,
            'text': 'Could not parse reminder. Please specify a time or date.',
          });
        });
      }
    }

    _scrollToBottom();
  }

  void _saveQuestionTime(String time) {
    setState(() => _selectedTime = time);
    final dueAt = _calculateDueAt('Today', time);
    final newId = const Uuid().v4();
    final item = ReminderItem(
      id: newId,
      title: _taskTitle,
      dueAt: dueAt,
      category: _inferCategory(_taskTitle),
    );
    ref.read(homeReminderProvider.notifier).addReminder(item);
    _lastCreatedReminderId = newId;
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.pingoBackground;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.pingoSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.pingoBorder;
    final textColor = isDark ? Colors.white : AppColors.pingoDark;
    final mutedColor =
        isDark ? AppColors.darkTextSecondary : AppColors.pingoMuted;

    String hintText = 'Reply to Pingo...';
    if (_activeScenario == FlowScenario.askAboutToday) {
      hintText = 'Ask about tomorrow, next week, or add...';
    } else if (_activeScenario == FlowScenario.askQuestion) {
      hintText = 'Or say the time';
    }

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: textColor,
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Pingo 🐧',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),

            // Conversation Stream
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                children: [
                  if (_activeScenario == FlowScenario.autoSaved) ...[
                    _buildAutoSavedContent(
                        isDark, cardBg, borderColor, textColor, mutedColor),
                  ] else if (_activeScenario ==
                      FlowScenario.askAboutToday) ...[
                    _buildAskAboutTodayContent(
                        isDark, cardBg, borderColor, textColor, mutedColor),
                  ] else if (_activeScenario == FlowScenario.askQuestion) ...[
                    _buildAskQuestionContent(
                        isDark, cardBg, borderColor, textColor, mutedColor),
                  ],

                  // Follow up messages stream
                  for (final msg in _conversationHistory) ...[
                    const SizedBox(height: 14),
                    if (msg['isUser'] == true) ...[
                      _userBubble(msg['text'] as String),
                    ] else ...[
                      _botHeader(),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: borderColor, width: 1.2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (msg['isLoading'] == true) ...[
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.penguinBeak),
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            Flexible(
                              child: Text(
                                msg['text'] as String,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: textColor,
                                  height: 1.4,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),

            // Bottom Input Dock
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
              child: _buildBottomInputDock(
                  isDark, cardBg, borderColor, textColor, hintText),
            ),
          ],
        ),
      ),
    );
  }

  // --- 1. Scenario: Auto Saved (Dynamic based on user prompt) ---
  Widget _buildAutoSavedContent(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color mutedColor,
  ) {
    if (_isLoadingAi) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _userBubble(widget.initialPrompt),
          const SizedBox(height: 14),
          _botHeader(),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: borderColor, width: 1.2),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.penguinBeak),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  'Pingo is remembering...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _userBubble(widget.initialPrompt),
        const SizedBox(height: 14),

        _botHeader(),
        const SizedBox(height: 8),

        // Auto Saved Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.check_circle, color: AppColors.success, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Saved automatically',
                    style: TextStyle(
                      color: Color(0xFF047857),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _taskTitle,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 16, color: mutedColor),
                  const SizedBox(width: 6),
                  Text(_taskDate,
                      style: TextStyle(
                          fontSize: 14,
                          color: textColor,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(width: 14),
                  Icon(Icons.access_time_rounded, size: 16, color: mutedColor),
                  const SizedBox(width: 6),
                  Text(_taskTime,
                      style: TextStyle(
                          fontSize: 14,
                          color: textColor,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
        ),

        // Follow up Update (if user made adjustments)
        if (_hasFollowUpUpdate) ...[
          const SizedBox(height: 16),
          _userBubble('Updated reminder time: $_followUpTime'),
          const SizedBox(height: 14),
          _botHeader(),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: borderColor, width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.check_circle,
                        color: AppColors.success, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Time updated',
                      style: TextStyle(
                        color: Color(0xFF047857),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _taskTitle,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 16, color: mutedColor),
                    const SizedBox(width: 6),
                    Text(_taskDate,
                        style: TextStyle(
                            fontSize: 14,
                            color: textColor,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(width: 14),
                    Icon(Icons.access_time_rounded,
                        size: 16, color: mutedColor),
                    const SizedBox(width: 6),
                    Text(_followUpTime,
                        style: TextStyle(
                            fontSize: 14,
                            color: textColor,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: borderColor, height: 1),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Alert',
                      style: TextStyle(fontSize: 14, color: mutedColor),
                    ),
                    Text(
                      _reminderAlert,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: () {
                    setState(() {
                      _hasFollowUpUpdate = false;
                    });
                  },
                  child: const Text(
                    'Undo this change',
                    style: TextStyle(
                      color: AppColors.penguinBeak,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),

        // Contextual action chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip('🔄 Repeat weekly', cardBg, borderColor, textColor, () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Set to repeat weekly')),
              );
            }),
            _chip('☀️ Move to tomorrow', cardBg, borderColor, textColor, () {
              setState(() => _taskDate = 'Tomorrow');
              _handleSend('Move to tomorrow');
            }),
            _chip('🔔 Test alert now', cardBg, borderColor, textColor, () {
              _handleSend('test alert');
            }),
            _chip('❌ Cancel reminder', cardBg, borderColor, textColor, () {
              _handleSend('Cancel this reminder');
            }),
          ],
        ),
      ],
    );
  }

  // --- 2. Scenario: Ask About Today / Tomorrow (Zero fake items) ---
  Widget _buildAskAboutTodayContent(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color mutedColor,
  ) {
    final promptLower = widget.initialPrompt.toLowerCase();
    final isTomorrow = promptLower.contains('tomorrow') ||
        promptLower.contains('কাল') ||
        promptLower.contains('আগামীকাল') ||
        promptLower.contains('kalke');

    final targetName = isTomorrow ? 'tomorrow' : 'today';

    final now = DateTime.now();
    final targetDate = isTomorrow ? now.add(const Duration(days: 1)) : now;

    final reminders = ref.watch(homeReminderProvider).reminders;
    final matchingTasks = reminders.where((r) {
      return r.dueAt.year == targetDate.year &&
          r.dueAt.month == targetDate.month &&
          r.dueAt.day == targetDate.day;
    }).toList();

    final userQuestion = widget.initialPrompt.isNotEmpty
        ? widget.initialPrompt
        : 'What do I have $targetName?';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _userBubble(userQuestion),
        const SizedBox(height: 14),
        _botHeader(),
        const SizedBox(height: 8),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: matchingTasks.isEmpty
              ? Column(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded,
                        color: AppColors.success, size: 36),
                    const SizedBox(height: 12),
                    Text(
                      'No tasks left for $targetName!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'You are all caught up. Say or type below to create a new reminder.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: mutedColor,
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You have ${matchingTasks.where((t) => !t.isDone).length} things scheduled for $targetName.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Divider(color: borderColor, height: 1),
                    ...matchingTasks.map((task) => _checklistItem(
                          title: task.title,
                          time: DateFormat.jm().format(task.dueAt),
                          isCompleted: task.isDone,
                          onToggle: () {
                            ref
                                .read(homeReminderProvider.notifier)
                                .toggleDone(task.id);
                          },
                          textColor: textColor,
                          mutedColor: mutedColor,
                          borderColor: borderColor,
                        )),
                  ],
                ),
        ),

        const SizedBox(height: 20),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (!isTomorrow)
              _chip('☀️ What about tomorrow?', cardBg, borderColor, textColor, () {
                _handleSend('What do I have tomorrow?');
              }),
            if (isTomorrow)
              _chip('📋 What about today?', cardBg, borderColor, textColor, () {
                _handleSend('What do I have today?');
              }),
            _chip('🔔 Test alert sound', cardBg, borderColor, textColor, () {
              _handleSend('test alert');
            }),
            _chip('📑 Show all tasks', cardBg, borderColor, textColor, () {
              _handleSend('Show all tasks');
            }),
          ],
        ),
      ],
    );
  }

  // --- 3. Scenario: Ask Question (Clarification for user prompt) ---
  Widget _buildAskQuestionContent(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color mutedColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _userBubble(widget.initialPrompt.isNotEmpty
            ? widget.initialPrompt
            : _taskTitle),
        const SizedBox(height: 14),

        _botHeader(),
        const SizedBox(height: 8),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Not saved yet',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFD97706),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'What time should I remind you?',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 16),

              _timeOptionPill('Morning, 9:00 AM', textColor, borderColor),
              const SizedBox(height: 10),
              _timeOptionPill('Afternoon, 2:00 PM', textColor, borderColor),
              const SizedBox(height: 10),
              _timeOptionPill('Evening, 6:00 PM', textColor, borderColor),

              const SizedBox(height: 14),
              InkWell(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: const TimeOfDay(hour: 9, minute: 0),
                  );
                  if (picked != null) {
                    final formatted = picked.format(context);
                    _saveQuestionTime(formatted);
                  }
                },
                child: const Text(
                  'Pick another time',
                  style: TextStyle(
                    color: AppColors.penguinBeak,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),

        if (_selectedTime != null) ...[
          const SizedBox(height: 16),
          _userBubble(_selectedTime!),
          const SizedBox(height: 14),
          _botHeader(),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: borderColor, width: 1.2),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle,
                    color: AppColors.success, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Saved! Reminding you at $_selectedTime',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // --- Helpers ---
  Widget _userBubble(String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              AppColors.penguinBeak,
              AppColors.penguinOrange,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppColors.penguinBeak.withValues(alpha: 0.30),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _botHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.penguinBeak.withValues(alpha: 0.16),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.penguinBeak.withValues(alpha: 0.35),
              width: 1.2,
            ),
          ),
          child: const Center(
            child: Text(
              '🐧',
              style: TextStyle(fontSize: 15),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Pingo',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.penguinSnow : AppColors.pingoDark,
          ),
        ),
      ],
    );
  }

  Widget _checklistItem({
    required String title,
    required String time,
    required bool isCompleted,
    required VoidCallback onToggle,
    required Color textColor,
    required Color mutedColor,
    required Color borderColor,
  }) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isCompleted
              ? Colors.transparent
              : AppColors.penguinBeak.withValues(alpha: 0.04),
          border: Border.all(
            color: isCompleted ? borderColor.withValues(alpha: 0.5) : borderColor,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            isCompleted
                ? const Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 22)
                : Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.penguinBeak,
                        width: 2,
                      ),
                    ),
                  ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isCompleted ? mutedColor : textColor,
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppColors.penguinGlacier.withValues(alpha: 0.12),
              ),
              child: Text(
                time,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.penguinGlacier,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeOptionPill(String timeText, Color textColor, Color borderColor) {
    final isSelected = _selectedTime == timeText;
    return InkWell(
      onTap: () {
        _saveQuestionTime(timeText);
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? AppColors.penguinBeak : borderColor,
            width: isSelected ? 2 : 1.2,
          ),
          color: isSelected
              ? AppColors.penguinBeak.withValues(alpha: 0.12)
              : Colors.transparent,
        ),
        child: Text(
          timeText,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.penguinBeak : textColor,
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, Color bg, Color border, Color textColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border, width: 1.2),
          color: bg,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomInputDock(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textColor,
    String hintText,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              onSubmitted: _handleSend,
              style: TextStyle(color: textColor, fontSize: 15),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle:
                    const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14.5),
                border: InputBorder.none,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              PingoVoiceScreen.show(context, onSpeechFinished: (speech) {
                _handleSend(speech);
              });
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.penguinBeak,
                    AppColors.penguinOrange,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Center(
                child: Icon(Icons.mic_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
