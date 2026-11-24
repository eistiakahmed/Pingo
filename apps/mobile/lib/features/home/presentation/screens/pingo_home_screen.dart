import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../../core/network/providers.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/screens/pingo_login_screen.dart';
import '../../../auth/presentation/state/auth_provider.dart';
import '../../../voice_capture/data/voice_command_api_service.dart';
import '../../domain/chat_message.dart';
import '../state/home_reminder_provider.dart';
import '../state/pingo_chat_provider.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/date_separator_chip.dart';
import '../widgets/read_only_task_card.dart';
import '../widgets/tech_canvas_background.dart';
import '../widgets/typing_indicator_widget.dart';
import 'my_reminders_screen.dart';

/// Pingo Home Screen — Device-Adaptive Penguin Dashboard & Multimodal Assistant:
/// 1. Stage 1 (Home Dashboard):
///    - Clean greeting header with solid pattern-free Light/Dark Penguin canvas
///    - Circular Progress Ring visualization in *Task & usage progress*
///    - Read-only active task cards with standardized `Icons.chevron_right_rounded` navigation
/// 2. Stage 2 (Unified Assistant Stream & Visual-Only Staged Composer):
///    - Decoupled attachment staging (`📎` File Picker + `📷` Direct Camera Capture -> `POST /api/attachments/stage`)
///    - Visual-only 56×56 rounded preview cards inside composer (zero raw filename text)
///    - Atomic bundled transmission on Send (`↑`) or Hold-to-Record release (`🎙️`).
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
  final ImagePicker _imagePicker = ImagePicker();

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
      _pullSyncOnResumeIfAuthenticated();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      ref.read(pingoChatProvider.notifier).suspendServices();
      _cancelHoldRecording();
    }
  }

  Future<void> _pullSyncOnResumeIfAuthenticated() async {
    if (await LocalStorageService.instance.isExplicitlyAuthenticated()) {
      final syncApi = ref.read(syncApiServiceProvider);
      await ref.read(homeReminderProvider.notifier).pullFromServer(syncApi);
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
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _handleSend() {
    final trimmed = _inputController.text.trim();
    final staged = ref.read(pingoChatProvider).stagedAttachments;
    if (trimmed.isEmpty && staged.isEmpty) return;

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

  // ───── Decoupled File & Direct Camera Staging (`POST /api/attachments/stage`) ─────

  Future<void> _stageDocumentOrImage() async {
    HapticFeedback.lightImpact();
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'png',
          'jpg',
          'jpeg',
          'webp',
          'gif',
          'pdf',
          'txt',
          'md',
          'csv',
          'json',
          'doc',
          'docx',
        ],
        allowMultiple: false,
      );

      if (result != null &&
          result.files.isNotEmpty &&
          result.files.first.path != null) {
        final ok = await ref
            .read(pingoChatProvider.notifier)
            .stageAttachmentForComposer(result.files.first.path!);
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not stage attachment. Check connection and file type.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[PingoHomeScreen] File staging error: $e');
    }
  }

  Future<void> _capturePhotoAndStage() async {
    HapticFeedback.lightImpact();
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (photo == null) return;

      final ok = await ref
          .read(pingoChatProvider.notifier)
          .stageAttachmentForComposer(photo.path);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not stage captured photo. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[PingoHomeScreen] Camera capture staging error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera unavailable or permission denied.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ───── Hold-to-Record (.m4a -> /api/voice-command) ─────

  Future<void> _startHoldRecording() async {
    if (_isVoiceRecording) return;
    HapticFeedback.mediumImpact();

    final hasPerm = await _audioRecorder.hasPermission();
    if (!hasPerm) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Microphone permission is required to record voice notes.',
            ),
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

  String _formatRecTimer(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _greetingTitle() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  // ─────────────────────────────── BUILD ───────────────────────────────

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final chatState = ref.watch(pingoChatProvider);
    final reminderState = ref.watch(homeReminderProvider);
    final isHomeDashboard = !_isChatModeForced &&
        chatState.messages.isEmpty &&
        !chatState.isThinking;

    final messageItems = _buildMessageItems(chatState.messages);

    return PopScope(
      canPop: isHomeDashboard,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !isHomeDashboard) {
          _returnToHomeDashboard();
        }
      },
      child: Scaffold(
        backgroundColor: p.bg,
        body: TechCanvasBackground(
          child: SafeArea(
            child: Column(
              children: [
                _buildTopBar(p: p, isHomeDashboard: isHomeDashboard),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: isHomeDashboard
                        ? _buildHomeDashboard(p, reminderState)
                        : _buildChatStream(p, chatState, messageItems),
                  ),
                ),
                _buildComposer(p, chatState),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────── STAGE 1: PENGUIN MINIMALIST HOME DASHBOARD ─────────

  Widget _buildHomeDashboard(
    PenguinPalette p,
    HomeReminderState reminderState,
  ) {
    final now = DateTime.now();
    final dateLabel = DateFormat('EEEE, MMM d').format(now);

    final scheduledList = reminderState.scheduledReminders
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    final completedList = reminderState.completedReminders
      ..sort((a, b) => b.dueAt.compareTo(a.dueAt));

    final totalCount = reminderState.reminders.length;
    final completedCount = completedList.length;
    final progressRatio =
        totalCount == 0 ? 0.0 : (completedCount / totalCount).clamp(0.0, 1.0);
    final progressPercent = (progressRatio * 100).round();

    final visibleActiveTasks = scheduledList.take(8).toList();

    return ListView(
      key: const ValueKey('home_usage_dashboard'),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      children: [
        // ── 1. Clean Greeting Header ──
        Text(
          dateLabel,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: p.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _greetingTitle(),
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w700,
            color: p.textPrimary,
            letterSpacing: -0.4,
          ),
        ),

        const SizedBox(height: 18),

        // ── 2. Circular Progress Ring Chart in "Task & usage progress" ──
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.border, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Task & usage progress',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: p.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  SizedBox(
                    width: 84,
                    height: 84,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 84,
                          height: 84,
                          child: CircularProgressIndicator(
                            value: progressRatio,
                            strokeWidth: 8,
                            strokeCap: StrokeCap.round,
                            backgroundColor: p.surface,
                            valueColor: AlwaysStoppedAnimation<Color>(p.accent),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$progressPercent%',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                                color: p.textPrimary,
                              ),
                            ),
                            Text(
                              'done',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: p.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildMetricTile(
                            p: p,
                            label: 'Scheduled',
                            count: scheduledList.length,
                            dotColor: p.accent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMetricTile(
                            p: p,
                            label: 'Completed',
                            count: completedList.length,
                            dotColor: p.success,
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

        const SizedBox(height: 20),

        // ── 3. Read-Only Tasks Section with Standardized Chevron Icon Button ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Remaining tasks',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: p.textPrimary,
              ),
            ),
            IconButton(
              key: const ValueKey('see_all_tasks_button'),
              tooltip: 'View all tasks',
              onPressed: () {
                HapticFeedback.selectionClick();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MyRemindersScreen(),
                  ),
                );
              },
              style: IconButton.styleFrom(
                backgroundColor: p.card,
                foregroundColor: p.accent,
                side: BorderSide(color: p.border, width: 1),
                minimumSize: const Size(38, 38),
                padding: EdgeInsets.zero,
              ),
              icon: const Icon(
                Icons.chevron_right_rounded,
                size: 22,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        if (visibleActiveTasks.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.border, width: 1),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 26,
                  color: p.success,
                ),
                const SizedBox(height: 8),
                Text(
                  'All caught up',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: p.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Send a message, attach a file, or hold the mic below to schedule a new task.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: p.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ...visibleActiveTasks.map((task) => ReadOnlyTaskCard(item: task)),
      ],
    );
  }

  Widget _buildMetricTile({
    required PenguinPalette p,
    required String label,
    required int count,
    required Color dotColor,
  }) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MyRemindersScreen()),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.border, width: 1),
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
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: p.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: p.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────── STAGE 2: UNIFIED ASSISTANT STREAM ─────────

  Widget _buildChatStream(
    PenguinPalette p,
    PingoChatState chatState,
    List<Widget> messageItems,
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
                  border: Border.all(color: p.borderActive, width: 1),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/images/penguin_avatar.png',
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Send a message, stage an attachment, or hold the mic to speak',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: p.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      key: const ValueKey('chat_interface_list'),
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 10),
      children: [
        ...messageItems,
        if (chatState.isThinking)
          const TypingIndicatorWidget(statusText: 'Pingo is thinking'),
      ],
    );
  }

  List<Widget> _buildMessageItems(List<ChatMessage> messages) {
    final items = <Widget>[];
    DateTime? lastDay;

    for (final msg in messages) {
      final day = DateTime(
        msg.timestamp.year,
        msg.timestamp.month,
        msg.timestamp.day,
      );
      if (lastDay == null || day != lastDay) {
        items.add(DateSeparatorChip(date: msg.timestamp, isBangla: false));
        lastDay = day;
      }
      items.add(ChatMessageBubble(message: msg));
    }
    return items;
  }

  // ───────────────────────────── TOP BAR ─────────────────────────────

  Widget _buildTopBar({
    required PenguinPalette p,
    required bool isHomeDashboard,
  }) {
    return Container(
      height: 58,
      padding: const EdgeInsets.only(left: 16, right: 8),
      decoration: BoxDecoration(
        color: p.chrome,
        border: Border(bottom: BorderSide(color: p.border, width: 1)),
      ),
      child: Row(
        children: [
          if (!isHomeDashboard) ...[
            InkWell(
              onTap: _returnToHomeDashboard,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: p.border, width: 1),
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 18,
                  color: p.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFADEAFF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: p.border, width: 1),
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
                  isHomeDashboard ? 'Pingo' : 'Assistant',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: p.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: p.accent,
                  ),
                ),
              ],
            ),
          ),
          if (isHomeDashboard)
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _isChatModeForced = true;
                });
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: p.border, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 14,
                      color: p.textPrimary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Chat',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: p.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert_rounded,
              color: p.textSecondary,
              size: 19,
            ),
            color: p.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: p.border, width: 1),
            ),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'home_dashboard',
                child: _menuItem(p, Icons.dashboard_outlined, 'Home dashboard'),
              ),
              PopupMenuItem(
                value: 'my_reminders',
                child: _menuItem(p, Icons.list_alt_rounded, 'All tasks'),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'auth_action',
                child: _menuItem(
                  p,
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

  Widget _menuItem(PenguinPalette p, IconData icon, String label) {
    return Row(
      children: [
        SizedBox(
          width: 18,
          child: Icon(icon, size: 18, color: p.textSecondary),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: p.textPrimary,
          ),
        ),
      ],
    );
  }

  // ───────── MULTIMODAL COMPOSER (VISUAL-ONLY STAGED CARDS + CAMERA + CLIP + MIC) ─────────

  Widget _buildComposer(PenguinPalette p, PingoChatState chatState) {
    final canSend =
        (_hasInputText || chatState.stagedAttachments.isNotEmpty) &&
            !_isVoiceRecording;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: Container(
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _isVoiceRecording ? p.danger : p.borderActive,
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Visual-Only Staged Attachment Strip (56×56 rounded cards, zero raw filename text)
            if (chatState.stagedAttachments.isNotEmpty ||
                chatState.isStagingAttachment)
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ...chatState.stagedAttachments.map(
                        (item) => StagedAttachmentPreviewCard(
                          key: ValueKey('staged_card_${item.stagingId}'),
                          item: item,
                          onRemove: () {
                            ref
                                .read(pingoChatProvider.notifier)
                                .removeStagedPreview(item.stagingId);
                          },
                        ),
                      ),
                      if (chatState.isStagingAttachment)
                        Container(
                          width: 56,
                          height: 56,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: p.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: p.border, width: 1),
                          ),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: p.accent,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

            Row(
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
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: p.danger,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatRecTimer(_recElapsed),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: p.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Recording... release to send',
                      style: TextStyle(
                        color: p.textSecondary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ] else ...[
                  // Attachment Clip (`POST /api/attachments/stage`)
                  InkWell(
                    onTap: _stageDocumentOrImage,
                    borderRadius: BorderRadius.circular(999),
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        Icons.attach_file_rounded,
                        color: p.textSecondary,
                        size: 19,
                      ),
                    ),
                  ),
                  // Direct Camera Capture (`ImageSource.camera` -> `/api/attachments/stage`)
                  InkWell(
                    onTap: _capturePhotoAndStage,
                    borderRadius: BorderRadius.circular(999),
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        Icons.camera_alt_outlined,
                        color: p.textSecondary,
                        size: 19,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      onSubmitted: (_) => _handleSend(),
                      maxLines: 4,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      style: TextStyle(
                        color: p.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                      ),
                      decoration: InputDecoration(
                        filled: false,
                        hintText: chatState.stagedAttachments.isNotEmpty
                            ? 'Add instructions or hold mic...'
                            : 'Message or hold mic...',
                        hintStyle: TextStyle(
                          color: p.textMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                if (canSend)
                  GestureDetector(
                    onTap: _handleSend,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: p.primaryFill,
                      ),
                      child: Icon(
                        Icons.arrow_upward_rounded,
                        color: p.onPrimaryFill,
                        size: 20,
                      ),
                    ),
                  )
                else
                  GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Hold the microphone button to record & send',
                          ),
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
                      width: _isVoiceRecording ? 44 : 40,
                      height: _isVoiceRecording ? 44 : 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isVoiceRecording ? p.danger : p.accent,
                      ),
                      child: Icon(
                        Icons.mic_rounded,
                        color: _isVoiceRecording ? Colors.white : p.onAccent,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Visual-only 56×56 rounded preview card for a staged composer attachment.
/// Displays strictly the visual thumbnail (or clean file icon) plus a corner
/// dismiss control — zero raw filename text box.
class StagedAttachmentPreviewCard extends StatelessWidget {
  final StagedAttachmentPreviewItem item;
  final VoidCallback onRemove;

  const StagedAttachmentPreviewCard({
    super.key,
    required this.item,
    required this.onRemove,
  });

  IconData _fileIconForMime(String mimeType) {
    final lower = mimeType.toLowerCase();
    if (lower.contains('pdf')) return Icons.picture_as_pdf_outlined;
    if (lower.startsWith('image/')) return Icons.image_outlined;
    return Icons.description_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    final hasLocalImage = item.isImage &&
        item.localPath != null &&
        File(item.localPath!).existsSync();

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SizedBox(
        width: 56,
        height: 56,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.borderActive, width: 1),
              ),
              clipBehavior: Clip.antiAlias,
              child: hasLocalImage
                  ? Image.file(
                      File(item.localPath!),
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    )
                  : Center(
                      child: Icon(
                        _fileIconForMime(item.mimeType),
                        size: 24,
                        color: p.accent,
                      ),
                    ),
            ),
            Positioned(
              top: -4,
              right: -4,
              child: Semantics(
                button: true,
                label: 'Remove staged attachment',
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: p.primaryFill,
                      shape: BoxShape.circle,
                      border: Border.all(color: p.card, width: 1.5),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 12,
                      color: p.onPrimaryFill,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
