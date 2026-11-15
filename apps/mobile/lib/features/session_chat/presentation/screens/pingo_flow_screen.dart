import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:pingo_mobile/core/network/providers.dart';
import 'package:pingo_mobile/core/services/fcm_service.dart';
import 'package:pingo_mobile/core/services/notification_service.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';
import 'package:pingo_mobile/core/typography/app_typography.dart';
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
      FcmService.instance.triggerBackendTestPush();
      final isPermitted =
          await NotificationService.instance.areNotificationsEnabled();
      if (mounted) {
        setState(() {
          _activeScenario = FlowScenario.autoSaved;
          _taskTitle = 'Instant Test Alert';
          _taskDate = 'Today';
          _taskTime = DateFormat.jm().format(DateTime.now());
          _isLoadingAi = false;
          _hasSavedInitial = true;
          _conversationHistory.add({
            'isUser': false,
            'text': isPermitted
                ? 'Triggered an instant test notification on your screen.\n\nIf you see the notification banner and hear the sound, alerts are operational.'
                : 'Notifications are currently disabled in device settings.\n\nPlease open your phone\'s Settings > Apps > Pingo > Notifications and turn on:\n• Allow notifications\n• Floating notifications\n• Lock screen notifications',
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
        title: 'Pingo Test Alert',
        body: 'Alarms and notifications are active and punctually working.',
      );
      FcmService.instance.triggerBackendTestPush();
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
                'Instant test alert sent.\n\nAll notification and exact alarm permissions are active.\n\nXiaomi (HyperOS / MIUI) Notice:\nTo ensure alarms ring when screen is off or app is closed:\n1. Open Settings > Apps > Manage Apps > Pingo\n2. Turn ON "Autostart"\n3. Change Battery Saver to "No restrictions"',
          });
        } else if (!isPermitted) {
          _conversationHistory.add({
            'isUser': false,
            'text':
                'Notifications are currently disabled in device settings.\n\nPlease open Settings > Apps > Pingo > Notifications and turn on:\n• Allow notifications\n• Floating notifications (heads-up banners)\n• Lock screen notifications',
          });
        } else {
          _conversationHistory.add({
            'isUser': false,
            'text':
                'Exact Alarms permission is restricted on your device.\n\nPlease open Settings > Apps > Pingo > Alarms & reminders and allow "Setting alarms and reminders" for exact timing.',
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
    String hintText = 'Reply or enter instruction...';
    if (_activeScenario == FlowScenario.askAboutToday) {
      hintText = 'Ask about tomorrow or add new task...';
    } else if (_activeScenario == FlowScenario.askQuestion) {
      hintText = 'Enter time (e.g. 10:30 AM)...';
    }

    return Scaffold(
      backgroundColor: AppColors.inkBlack,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Architectural Minimalist Masthead
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.inkBorder, width: 1),
                        color: AppColors.inkSurface,
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: AppColors.paperWhite,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PINGO',
                        style: AppTypography.masthead().copyWith(
                          fontSize: 16,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'SESSION // ACTIVE',
                            style: AppTypography.monoLabel().copyWith(
                              fontSize: 10,
                              color: AppColors.paperMuted,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(color: AppColors.inkBorder, height: 1),

            // Conversation Stream
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  if (_activeScenario == FlowScenario.autoSaved) ...[
                    _buildAutoSavedContent(),
                  ] else if (_activeScenario == FlowScenario.askAboutToday) ...[
                    _buildAskAboutTodayContent(),
                  ] else if (_activeScenario == FlowScenario.askQuestion) ...[
                    _buildAskQuestionContent(),
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
                          color: AppColors.inkSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.inkBorder, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (msg['isLoading'] == true) ...[
                              const Padding(
                                padding: EdgeInsets.only(top: 2, right: 10),
                                child: SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.paperWhite),
                                  ),
                                ),
                              ),
                            ],
                            Flexible(
                              child: Text(
                                msg['text'] as String,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  color: AppColors.paperWhite,
                                  height: 1.45,
                                  fontWeight: FontWeight.w400,
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
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: _buildBottomInputDock(hintText),
            ),
          ],
        ),
      ),
    );
  }

  // --- 1. Scenario: Auto Saved (Dynamic based on user prompt) ---
  Widget _buildAutoSavedContent() {
    if (_isLoadingAi) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _userBubble(widget.initialPrompt),
          const SizedBox(height: 14),
          _botHeader(),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.inkSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.inkBorder, width: 1),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.paperWhite),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'PROCESSING TEMPORAL INTENT...',
                  style: AppTypography.monoLabel().copyWith(
                    color: AppColors.paperWhite,
                    letterSpacing: 1.2,
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

        // Auto Saved Card (Architectural Left-Bordered Block)
        Container(
          decoration: BoxDecoration(
            color: AppColors.inkSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.inkBorder, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.inkBorder, width: 1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'COMMITTED TO AGENDA',
                          style: AppTypography.monoLabel().copyWith(
                            color: const Color(0xFF10B981),
                            fontSize: 10.5,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'EXACT ALARM',
                      style: AppTypography.monoLabel().copyWith(
                        color: AppColors.paperMuted,
                        fontSize: 10.5,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _taskTitle,
                      style: TextStyle(
                        fontFamily: AppTypography.displayFont,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.paperWhite,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Clean Tabular Metadata
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SCHEDULED DATE',
                                style: AppTypography.monoLabel().copyWith(
                                  color: AppColors.paperMuted,
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _taskDate.toUpperCase(),
                                style: AppTypography.monoLabel().copyWith(
                                  color: AppColors.paperWhite,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'EXECUTION TIME',
                                style: AppTypography.monoLabel().copyWith(
                                  color: AppColors.paperMuted,
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _taskTime.toUpperCase(),
                                style: AppTypography.monoLabel().copyWith(
                                  color: AppColors.paperWhite,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Follow up Update (if user made adjustments)
        if (_hasFollowUpUpdate) ...[
          const SizedBox(height: 14),
          _userBubble('Updated reminder time: $_followUpTime'),
          const SizedBox(height: 14),
          _botHeader(),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.inkSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.inkBorder, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'SCHEDULE RECONFIGURED',
                      style: AppTypography.monoLabel().copyWith(
                        color: const Color(0xFF10B981),
                        fontSize: 10.5,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _taskTitle,
                  style: TextStyle(
                    fontFamily: AppTypography.displayFont,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: AppColors.paperWhite,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text('NEW TIME: ', style: AppTypography.monoLabel().copyWith(color: AppColors.paperMuted, fontSize: 11)),
                    Text(_followUpTime, style: AppTypography.monoLabel().copyWith(color: AppColors.paperWhite, fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () {
                    setState(() {
                      _hasFollowUpUpdate = false;
                    });
                  },
                  child: Text(
                    '[ REVERT CHANGE ]',
                    style: AppTypography.monoLabel().copyWith(
                      color: AppColors.paperMuted,
                      fontSize: 11,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Contextual action chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip('REPEAT WEEKLY', () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Set to repeat weekly')),
              );
            }),
            _chip('MOVE TO TOMORROW', () {
              setState(() => _taskDate = 'Tomorrow');
              _handleSend('Move to tomorrow');
            }),
            _chip('TEST ALERT', () {
              _handleSend('test alert');
            }),
            _chip('CANCEL REMINDER', () {
              _handleSend('Cancel this reminder');
            }),
          ],
        ),
      ],
    );
  }

  // --- 2. Scenario: Ask About Today / Tomorrow ---
  Widget _buildAskAboutTodayContent() {
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
          decoration: BoxDecoration(
            color: AppColors.inkSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.inkBorder, width: 1),
          ),
          child: matchingTasks.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    children: [
                      Text(
                        'ZERO SCHEDULED ITEMS',
                        style: AppTypography.monoLabel().copyWith(
                          fontSize: 12,
                          color: AppColors.paperWhite,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Agenda is completely clear for $targetName.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.paperMuted,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'AGENDA // ${matchingTasks.length} COMMITMENT${matchingTasks.length == 1 ? '' : 'S'}',
                        style: AppTypography.monoLabel().copyWith(
                          fontSize: 11,
                          color: AppColors.paperMuted,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const Divider(color: AppColors.inkBorder, height: 1),
                    ...matchingTasks.map((task) => _checklistItem(
                          title: task.title,
                          time: DateFormat.jm().format(task.dueAt),
                          isCompleted: task.isDone,
                          onToggle: () {
                            ref
                                .read(homeReminderProvider.notifier)
                                .toggleDone(task.id);
                          },
                        )),
                  ],
                ),
        ),

        const SizedBox(height: 16),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (!isTomorrow)
              _chip('WHAT ABOUT TOMORROW?', () {
                _handleSend('What do I have tomorrow?');
              }),
            if (isTomorrow)
              _chip('WHAT ABOUT TODAY?', () {
                _handleSend('What do I have today?');
              }),
            _chip('TEST ALERT', () {
              _handleSend('test alert');
            }),
            _chip('SHOW ALL TASKS', () {
              _handleSend('Show all tasks');
            }),
          ],
        ),
      ],
    );
  }

  // --- 3. Scenario: Ask Question (Clarification for user prompt) ---
  Widget _buildAskQuestionContent() {
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
            color: AppColors.inkSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.inkBorder, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SPECIFY DUE TIME',
                style: AppTypography.monoLabel().copyWith(
                  fontSize: 10.5,
                  color: AppColors.paperMuted,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'When should this alert fire?',
                style: TextStyle(
                  fontFamily: AppTypography.displayFont,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.paperWhite,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 16),

              _timeOptionPill('09:00 AM · MORNING'),
              const SizedBox(height: 8),
              _timeOptionPill('02:00 PM · AFTERNOON'),
              const SizedBox(height: 8),
              _timeOptionPill('06:00 PM · EVENING'),

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
                child: Text(
                  '[ SELECT CUSTOM TIME ]',
                  style: AppTypography.monoLabel().copyWith(
                    color: AppColors.paperWhite,
                    fontSize: 11,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),

        if (_selectedTime != null) ...[
          const SizedBox(height: 14),
          _userBubble(_selectedTime!),
          const SizedBox(height: 14),
          _botHeader(),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.inkSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.inkBorder, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'CONFIRMED // REMINDING AT $_selectedTime',
                  style: AppTypography.monoLabel().copyWith(
                    color: AppColors.paperWhite,
                    fontSize: 11,
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
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.inkCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.inkBorder, width: 1),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.paperWhite,
            fontSize: 14.5,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _botHeader() {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'PINGO ENGINE',
          style: AppTypography.monoLabel().copyWith(
            fontSize: 10.5,
            color: AppColors.paperMuted,
            letterSpacing: 1.2,
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
  }) {
    return InkWell(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.inkBorder, width: 1)),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCompleted ? const Color(0xFF10B981) : AppColors.inkBorder,
                  width: 1.5,
                ),
                color: isCompleted ? const Color(0xFF10B981) : Colors.transparent,
              ),
              child: isCompleted
                  ? const Icon(Icons.check, size: 12, color: AppColors.inkBlack)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: isCompleted ? AppColors.paperMuted : AppColors.paperWhite,
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            Text(
              time,
              style: AppTypography.monoLabel().copyWith(
                fontSize: 11,
                color: AppColors.paperMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeOptionPill(String timeText) {
    final isSelected = _selectedTime == timeText;
    return InkWell(
      onTap: () {
        _saveQuestionTime(timeText);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.paperWhite : AppColors.inkBorder,
            width: 1,
          ),
          color: isSelected ? AppColors.inkCard : AppColors.inkSurface,
        ),
        child: Text(
          timeText,
          style: AppTypography.monoLabel().copyWith(
            fontSize: 12,
            color: isSelected ? AppColors.paperWhite : AppColors.paperMuted,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.inkBorder, width: 1),
          color: AppColors.inkSurface,
        ),
        child: Text(
          '[ $label ]',
          style: AppTypography.monoLabel().copyWith(
            fontSize: 10.5,
            color: AppColors.paperWhite,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomInputDock(String hintText) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.inkBorder, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              onSubmitted: _handleSend,
              style: const TextStyle(color: AppColors.paperWhite, fontSize: 14),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(
                  color: AppColors.paperMuted.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          InkWell(
            onTap: () {
              PingoVoiceScreen.show(context, onSpeechFinished: (speech) {
                _handleSend(speech);
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: AppColors.inkCard,
                border: Border.all(color: AppColors.inkBorder, width: 1),
              ),
              child: const Icon(
                Icons.mic_none_rounded,
                color: AppColors.paperWhite,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _handleSend(_inputController.text),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: AppColors.paperWhite,
              ),
              child: const Icon(
                Icons.arrow_upward_rounded,
                color: AppColors.inkBlack,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
