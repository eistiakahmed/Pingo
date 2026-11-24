import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/screens/pingo_login_screen.dart';
import '../../../auth/presentation/state/auth_provider.dart';
import '../../../reminder_editor/presentation/screens/edit_reminder_screen.dart';
import '../../domain/chat_message.dart';
import '../../domain/reminder_item.dart';
import '../state/home_reminder_provider.dart';
import '../state/pingo_chat_provider.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/date_separator_chip.dart';
import '../widgets/tech_canvas_background.dart';
import '../widgets/typing_indicator_widget.dart';
import 'my_reminders_screen.dart';

/// Pingo Home Screen — Two-Stage Experience:
/// 1. Stage 1 (Home Usage & Task Progress Dashboard):
///    - Greeting + Live Cloud Sync & Task Progress header
///    - 3-Metric App Usage & Activity Row (Upcoming, Overdue, Completed + completion progress bar)
///    - Interactive Today's Tasks & Upcoming Reminders List (check off or edit right on Home)
///    - Quick Chat starter chips + Bottom 'Ask Pingo / Open Chat' bar
/// 2. Stage 2 (Conversational Chat Interface):
///    - Opens automatically when the user types, speaks, taps a quick prompt, or taps 'Open Chat'
///    - Includes a '<' back button in the top bar to return to the Home Dashboard at any time.
class PingoHomeScreen extends ConsumerStatefulWidget {
  const PingoHomeScreen({super.key});

  @override
  ConsumerState<PingoHomeScreen> createState() => _PingoHomeScreenState();
}

class _PingoHomeScreenState extends ConsumerState<PingoHomeScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AudioRecorder _audioRecorder = AudioRecorder();

  bool _isChatModeForced = false;
  bool _hasInputText = false;
  bool _isVoiceRecording = false;
  String? _activeRecordingPath;
  Timer? _recTimer;
  Duration _recElapsed = Duration.zero;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _inputController.addListener(_onInputChanged);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await NotificationService.instance.initialize();
      await NotificationService.instance.ensureReminderPermissions();
    });
  }

  void _onInputChanged() {
    final nextHasText = _inputController.text.trim().isNotEmpty;
    if (nextHasText != _hasInputText && mounted) {
      setState(() {
        _hasInputText = nextHasText;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recTimer?.cancel();
    _audioRecorder.dispose();
    _pulseController.dispose();
    _inputController.removeListener(_onInputChanged);
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(pingoChatProvider.notifier).reconcileTriggeredRemindersOnResume();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      ref.read(pingoChatProvider.notifier).suspendServices();
      _cancelHoldRecording();
    }
  }

  Future<void> _cancelHoldRecording() async {
    _recTimer?.cancel();
    _recTimer = null;
    _pulseController.stop();
    try {
      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
      }
    } catch (_) {}
    final stalePath = _activeRecordingPath;
    _activeRecordingPath = null;
    if (stalePath != null) {
      try {
        final f = File(stalePath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    if (mounted && _isVoiceRecording) {
      setState(() {
        _isVoiceRecording = false;
        _recElapsed = Duration.zero;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _handleSend(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _isChatModeForced = true;
    });
    _inputController.clear();
    ref.read(pingoChatProvider.notifier).sendMessage(trimmed);
    _scrollToBottom();
  }

  void _returnToHomeDashboard() {
    HapticFeedback.selectionClick();
    setState(() {
      _isChatModeForced = false;
    });
    ref.read(pingoChatProvider.notifier).startNewChat();
  }

  Future<void> _pickNativeDocument() async {
    HapticFeedback.lightImpact();
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _isChatModeForced = true;
        });
        await ref.read(pingoChatProvider.notifier).attachNativeFile(
              name: file.name,
              path: file.path,
              size: file.size,
            );
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('[PingoHomeScreen] File picker error: $e');
    }
  }

  // ───── WhatsApp-Style Hold-to-Record (.m4a -> /api/voice-command) ─────

  Future<void> _startHoldRecording() async {
    if (_isVoiceRecording) return;
    HapticFeedback.mediumImpact();

    final hasPerm = await _audioRecorder.hasPermission();
    if (!hasPerm) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required to record voice notes.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final outPath =
          '${tempDir.path}/pingo_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: outPath,
      );

      if (!mounted) return;
      setState(() {
        _isChatModeForced = true;
        _isVoiceRecording = true;
        _activeRecordingPath = outPath;
        _recElapsed = Duration.zero;
      });
      _pulseController.repeat(reverse: true);
      _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {
            _recElapsed += const Duration(seconds: 1);
          });
        }
      });
    } catch (e) {
      debugPrint('[PingoHomeScreen] Hold-to-record start error: $e');
      await _cancelHoldRecording();
    }
  }

  Future<void> _finishHoldRecordingAndSend() async {
    if (!_isVoiceRecording) return;
    HapticFeedback.lightImpact();

    _recTimer?.cancel();
    _recTimer = null;
    _pulseController.stop();

    String? recordedPath;
    try {
      recordedPath = await _audioRecorder.stop();
    } catch (e) {
      debugPrint('[PingoHomeScreen] Hold-to-record stop error: $e');
    }

    final finalPath = recordedPath ?? _activeRecordingPath;
    final elapsed = _recElapsed;
    _activeRecordingPath = null;

    if (mounted) {
      setState(() {
        _isVoiceRecording = false;
        _recElapsed = Duration.zero;
      });
    }

    if (finalPath == null || elapsed.inMilliseconds < 400) {
      // Too short / accidental tap: clean up file and guide user to hold
      if (finalPath != null) {
        try {
          final f = File(finalPath);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hold the microphone button to record a voice note'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    await ref.read(pingoChatProvider.notifier).sendVoiceCommandFile(finalPath);
    _scrollToBottom();
  }

  Future<void> _promptDatePickerForExpiry(ChatMessage msg) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.signalAmber,
              onPrimary: AppColors.inkBlack,
              surface: AppColors.inkCard,
              onSurface: AppColors.paperWhite,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final scheduledDate = DateTime(picked.year, picked.month, picked.day, 9, 0);
      ref.read(pingoChatProvider.notifier).setDocumentExpiryReminder(
            documentTitle: msg.documentTitle ?? 'Document',
            expiryDate: scheduledDate,
          );
      _scrollToBottom();
    }
  }

  String _formatRecTimer(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _greetingTitle(bool isBangla) {
    final hour = DateTime.now().hour;
    if (isBangla) {
      if (hour < 12) return 'শুভ সকাল';
      if (hour < 17) return 'শুভ অপরাহ্ন';
      return 'শুভ সন্ধ্যা';
    } else {
      if (hour < 12) return 'Good morning';
      if (hour < 17) return 'Good afternoon';
      return 'Good evening';
    }
  }

  // ─────────────────────────────── BUILD ───────────────────────────────

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(pingoChatProvider);
    final reminderState = ref.watch(homeReminderProvider);
    final isBangla = chatState.language == 'bn';
    final isHomeDashboard = !_isChatModeForced &&
        chatState.messages.isEmpty &&
        !chatState.isThinking;

    final messageItems = _buildMessageItems(chatState.messages, isBangla);

    return PopScope(
      canPop: isHomeDashboard,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !isHomeDashboard) {
          _returnToHomeDashboard();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.inkBlack,
        body: TechCanvasBackground(
          child: SafeArea(
            child: Column(
              children: [
                _buildTopBar(isBangla, isHomeDashboard: isHomeDashboard),

                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: isHomeDashboard
                        ? _buildHomeDashboard(isBangla, reminderState)
                        : _buildChatStream(chatState, messageItems, isBangla),
                  ),
                ),

                _buildComposer(
                  isBangla,
                  _hasInputText,
                  isHomeDashboard: isHomeDashboard,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────── STAGE 1: HOME USAGE & TASK PROGRESS DASHBOARD ─────────

  Widget _buildHomeDashboard(bool isBangla, HomeReminderState reminderState) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final dateLabel = DateFormat('EEEE, MMM d').format(now);

    final allReminders = reminderState.reminders;
    final activeReminders = allReminders
        .where((r) => !r.isDone)
        .toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));

    final overdueList = activeReminders
        .where((r) => r.dueAt.isBefore(now))
        .toList();
    final upcomingList = activeReminders
        .where((r) => !r.dueAt.isBefore(now))
        .toList();
    final completedList = allReminders
        .where((r) => r.isDone)
        .toList()
      ..sort((a, b) => b.dueAt.compareTo(a.dueAt));

    final totalCount = allReminders.length;
    final completedCount = completedList.length;
    final progressRatio =
        totalCount == 0 ? 0.0 : (completedCount / totalCount).clamp(0.0, 1.0);
    final progressPercent = (progressRatio * 100).round();

    // Priority preview list on the Home Dashboard (Overdue first, then Upcoming, then recent Done)
    final dashboardTasks = <ReminderItem>[
      ...overdueList,
      ...upcomingList,
      ...completedList.where((r) {
        final d = DateTime(r.dueAt.year, r.dueAt.month, r.dueAt.day);
        return !d.isBefore(todayStart);
      }),
    ].take(5).toList();

    final quickPrompts = isBangla
        ? <String>[
            'আজকে আমার কী কী কাজ আছে?',
            'বিকেল ৫:৩০টায় ডাক্তারকে কল',
            'প্রতিদিন রাত ৯টায় ওষুধ',
          ]
        : <String>[
            'What do I have today?',
            'Call doctor at 5:30 PM',
            'Medicine every day 9 pm',
          ];

    return ListView(
      key: const ValueKey('home_usage_dashboard'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      children: [
        // ── 1. Greeting + Cloud Sync & Progress Status Header ──
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.paperSubtle,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _greetingTitle(isBangla),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.paperWhite,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
            ),
            // Live Cloud Sync Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.inkCard,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.inkBorder, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: reminderState.isSyncing
                          ? AppColors.signalAmber
                          : AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    reminderState.isSyncing
                        ? (isBangla ? 'সিঙ্ক হচ্ছে...' : 'Syncing...')
                        : (isBangla ? 'ক্লাউড সিঙ্ক সক্রিয়' : 'Cloud synced'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.paperMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ── 2. 3-Metric App Usage & Task Progress Summary Card ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.inkCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.inkBorder, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isBangla ? 'টাস্ক ও অ্যাপ অগ্রগতি' : 'Task & usage progress',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.paperMuted,
                    ),
                  ),
                  Text(
                    isBangla
                        ? '$completedCount / $totalCount সম্পন্ন ($progressPercent%)'
                        : '$completedCount of $totalCount done ($progressPercent%)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()],
                      color: AppColors.paperWhite,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progressRatio,
                  minHeight: 6,
                  backgroundColor: AppColors.inkSurface,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.success,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 3 Metric Tiles: Upcoming | Overdue | Completed
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      label: isBangla ? 'আসন্ন' : 'Upcoming',
                      count: upcomingList.length,
                      dotColor: AppColors.signalAmber,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MyRemindersScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricTile(
                      label: isBangla ? 'সময় উত্তীর্ণ' : 'Overdue',
                      count: overdueList.length,
                      dotColor: AppColors.overdue,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MyRemindersScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricTile(
                      label: isBangla ? 'সম্পন্ন' : 'Completed',
                      count: completedList.length,
                      dotColor: AppColors.success,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MyRemindersScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── 3. Interactive Today's Tasks & Upcoming Reminders Section ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isBangla
                  ? 'আজকের ও আসন্ন রিমাইন্ডার'
                  : "Today's & upcoming tasks",
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.paperWhite,
              ),
            ),
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MyRemindersScreen(),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  isBangla ? 'সব দেখুন →' : 'See all →',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.signalAmber,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        if (dashboardTasks.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
            decoration: BoxDecoration(
              color: AppColors.inkCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.inkBorder, width: 1),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 26,
                  color: AppColors.success,
                ),
                const SizedBox(height: 8),
                Text(
                  isBangla
                      ? 'এখন কোনো পেন্ডিং রিমাইন্ডার নেই'
                      : 'No pending tasks right now',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.paperWhite,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isBangla
                      ? 'নিচে লিখে বা ভয়েসে নতুন রিমাইন্ডার সেট করুন'
                      : 'Use the bar below or tap a quick action to schedule an alarm',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.paperSubtle,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ...dashboardTasks.map(
            (task) => _buildDashboardTaskRow(task, now, isBangla),
          ),

        const SizedBox(height: 20),

        // ── 4. Quick Chat Action Chips (1-Tap jump to Chat Interface) ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isBangla ? 'দ্রুত চ্যাট কমান্ড' : 'Quick actions',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.paperMuted,
              ),
            ),
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _isChatModeForced = true;
                });
              },
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  isBangla ? 'চ্যাট খুলুন →' : 'Open chat →',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.paperSubtle,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: quickPrompts.map((prompt) {
            return InkWell(
              onTap: () => _handleSend(prompt),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: AppColors.inkCard,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.inkBorderActive,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      size: 14,
                      color: AppColors.signalAmber,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      prompt,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.paperWhite,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String label,
    required int count,
    required Color dotColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.inkSurface,
          borderRadius: BorderRadius.circular(10),
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
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.paperMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
                color: AppColors.paperWhite,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardTaskRow(
    ReminderItem r,
    DateTime now,
    bool isBangla,
  ) {
    final isOverdue = !r.isDone && r.dueAt.isBefore(now);
    final statusColor = r.isDone
        ? AppColors.success
        : (isOverdue ? AppColors.overdue : AppColors.signalAmber);
    final timeStr = DateFormat.jm().format(r.dueAt);
    final dateStr = DateFormat('d MMM').format(r.dueAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.inkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.inkBorder, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          HapticFeedback.selectionClick();
          EditReminderScreen.show(
            context: context,
            initialItem: r,
            onSave: (saved) {
              ref.read(homeReminderProvider.notifier).updateReminder(saved);
            },
            onDelete: () {
              ref.read(homeReminderProvider.notifier).deleteReminder(r.id);
            },
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Interactive Checkbox
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref.read(homeReminderProvider.notifier).toggleDone(r.id);
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: r.isDone
                          ? AppColors.success
                          : AppColors.inkBorderActive,
                      width: 1.5,
                    ),
                    color: r.isDone ? AppColors.success : Colors.transparent,
                  ),
                  child: r.isDone
                      ? const Icon(
                          Icons.check_rounded,
                          size: 15,
                          color: AppColors.inkBlack,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                        color: r.isDone
                            ? AppColors.paperSubtle
                            : AppColors.paperWhite,
                        decoration:
                            r.isDone ? TextDecoration.lineThrough : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$timeStr · $dateStr',
                          style: const TextStyle(
                            fontSize: 12,
                            fontFeatures: [FontFeature.tabularFigures()],
                            color: AppColors.paperSubtle,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.paperSubtle,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────── STAGE 2: CONVERSATIONAL CHAT INTERFACE ─────────

  Widget _buildChatStream(
    PingoChatState chatState,
    List<Widget> messageItems,
    bool isBangla,
  ) {
    if (chatState.messages.isEmpty && !chatState.isThinking) {
      return Center(
        key: const ValueKey('empty_chat_prompt'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFADEAFF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.inkBorderActive, width: 1),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/images/penguin_avatar.png',
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isBangla
                    ? 'পিঙ্গোকে রিমাইন্ডার বা প্রশ্ন লিখুন'
                    : 'Ask Pingo or type a reminder below',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.paperMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      key: const ValueKey('chat_interface_list'),
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        ...messageItems,
        if (chatState.isThinking)
          TypingIndicatorWidget(
            statusText: isBangla ? 'পিঙ্গো ভাবছে' : 'Pingo is thinking',
          ),
      ],
    );
  }

  List<Widget> _buildMessageItems(List<ChatMessage> messages, bool isBangla) {
    final items = <Widget>[];
    DateTime? lastDay;

    for (final msg in messages) {
      final day = DateTime(
          msg.timestamp.year, msg.timestamp.month, msg.timestamp.day);
      if (lastDay == null || day != lastDay) {
        items.add(DateSeparatorChip(date: msg.timestamp, isBangla: isBangla));
        lastDay = day;
      }
      items.add(ChatMessageBubble(
        message: msg,
        isBangla: isBangla,
        onConfirmReminder: () {
          ref.read(pingoChatProvider.notifier).confirmReminder(msg.id);
        },
        onDiscardReminder: () {
          ref.read(pingoChatProvider.notifier).discardReminder(msg.id);
        },
        onSetExpiryAlert: () {
          _promptDatePickerForExpiry(msg);
        },
      ));
    }
    return items;
  }

  // ───────────────────────────── TOP BAR ─────────────────────────────

  Widget _buildTopBar(bool isBangla, {required bool isHomeDashboard}) {
    return Container(
      height: 58,
      padding: const EdgeInsets.only(left: 16, right: 8),
      decoration: const BoxDecoration(
        color: AppColors.inkDeep,
        border: Border(bottom: BorderSide(color: AppColors.inkBorder, width: 1)),
      ),
      child: Row(
        children: [
          // When in Chat Interface, show '<' Back button to return to Home Dashboard
          if (!isHomeDashboard) ...[
            InkWell(
              onTap: _returnToHomeDashboard,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.inkCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.inkBorderActive, width: 1),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  size: 18,
                  color: AppColors.paperWhite,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],

          // Pingo headphone-penguin avatar inside a 32x32 bordered frame
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFADEAFF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.inkBorder, width: 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/images/penguin_avatar.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Text(
                  isHomeDashboard
                      ? 'Pingo'
                      : (isBangla ? 'পিঙ্গো চ্যাট' : 'Pingo Chat'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.paperWhite,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),

          // Toggle between Home Dashboard and Chat Interface
          if (isHomeDashboard)
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _isChatModeForced = true;
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.inkCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.inkBorderActive, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 14,
                      color: AppColors.paperWhite,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isBangla ? 'চ্যাট' : 'Chat',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.paperWhite,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Menu: Home Dashboard / My reminders / Language / Sign out
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: AppColors.paperMuted,
              size: 18,
            ),
            color: AppColors.inkCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.inkBorder, width: 1),
            ),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'home_dashboard',
                child: _menuItem(
                  Icons.dashboard_outlined,
                  'Home dashboard',
                ),
              ),
              PopupMenuItem(
                value: 'my_reminders',
                child: _menuItem(
                  Icons.list_alt_rounded,
                  'All reminders',
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'auth_action',
                child: _menuItem(
                  ref.read(authProvider).isAuthenticated
                      ? Icons.logout_rounded
                      : Icons.person_outline_rounded,
                  ref.read(authProvider).isAuthenticated
                      ? 'Sign out (${ref.read(authProvider).userEmail ?? ""})'
                      : 'Sign in / Account',
                ),
              ),
            ],
            onSelected: (value) async {
              if (value == 'home_dashboard') {
                _returnToHomeDashboard();
              } else if (value == 'my_reminders') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MyRemindersScreen(),
                  ),
                );
              } else if (value == 'auth_action') {
                HapticFeedback.selectionClick();
                await ref.read(authProvider.notifier).logout();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => const PingoLoginScreen(),
                    ),
                    (route) => false,
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _menuItem(IconData icon, String label) {
    return Row(
      children: [
        SizedBox(
          width: 18,
          child: Icon(icon, size: 18, color: AppColors.paperMuted),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.paperWhite,
          ),
        ),
      ],
    );
  }

  // ──────────────────────────── COMPOSER ────────────────────────────

  Widget _buildComposer(
    bool isBangla,
    bool hasInputText, {
    required bool isHomeDashboard,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: _buildInputBar(
        isBangla,
        hasInputText,
        isHomeDashboard: isHomeDashboard,
      ),
    );
  }

  /// WhatsApp-style bottom composer with Hold-to-Record `.m4a` microphone button
  /// (`GestureDetector` `onLongPressStart` / `onLongPressEnd` / `onLongPressCancel`).
  Widget _buildInputBar(
    bool isBangla,
    bool hasInputText, {
    required bool isHomeDashboard,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inkCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isVoiceRecording
              ? AppColors.overdue
              : AppColors.inkBorderActive,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (_isVoiceRecording) ...[
            const SizedBox(width: 8),
            FadeTransition(
              opacity: Tween<double>(begin: 0.35, end: 1.0).animate(
                CurvedAnimation(
                  parent: _pulseController,
                  curve: Curves.easeOutCubic,
                ),
              ),
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.overdue,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatRecTimer(_recElapsed),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
                color: AppColors.paperWhite,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Recording voice... release to send',
                style: TextStyle(
                  color: AppColors.paperMuted,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ] else ...[
            InkWell(
              onTap: _pickNativeDocument,
              borderRadius: BorderRadius.circular(999),
              child: const SizedBox(
                width: 38,
                height: 38,
                child: Icon(
                  Icons.attach_file_rounded,
                  color: AppColors.paperMuted,
                  size: 19,
                ),
              ),
            ),
            Expanded(
              child: TextField(
                controller: _inputController,
                onSubmitted: _handleSend,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                style: const TextStyle(
                  color: AppColors.paperWhite,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  height: 1.45,
                ),
                decoration: InputDecoration(
                  filled: false,
                  hintText: isHomeDashboard
                      ? 'Message or hold mic to speak...'
                      : 'Message or hold mic to speak...',
                  hintStyle: const TextStyle(
                    color: AppColors.paperSubtle,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
              ),
            ),
          ],
          const SizedBox(width: 6),
          if (hasInputText && !_isVoiceRecording)
            GestureDetector(
              onTap: () => _handleSend(_inputController.text),
              child: Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.paperWhite,
                ),
                child: const Icon(
                  Icons.arrow_upward_rounded,
                  color: AppColors.inkBlack,
                  size: 20,
                ),
              ),
            )
          else
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Hold the microphone button to record & send'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              onLongPressStart: (_) => _startHoldRecording(),
              onLongPressEnd: (_) => _finishHoldRecordingAndSend(),
              onLongPressCancel: () => _cancelHoldRecording(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                width: _isVoiceRecording ? 46 : 42,
                height: _isVoiceRecording ? 46 : 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isVoiceRecording
                      ? AppColors.overdue
                      : AppColors.success,
                ),
                child: Icon(
                  Icons.mic_rounded,
                  color: _isVoiceRecording
                      ? AppColors.paperWhite
                      : AppColors.inkBlack,
                  size: 21,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
