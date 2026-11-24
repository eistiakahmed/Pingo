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

/// Pingo Home Screen — Streamlined Zero-Touch Dashboard & WhatsApp Multimodal Chat:
/// 1. Stage 1 (Home Dashboard):
///    - Clean greeting header (no Cloud Synced badge clutter)
///    - Circular Progress Ring visualization in *Task & usage progress*
///    - Read-only active task cards with autonomous LLM category badges (no checkboxes/edit/quick actions)
/// 2. Stage 2 (WhatsApp-Style Chat & Staged Multimodal Composer):
///    - Decoupled attachment staging (`📎` File Picker + `📷` Direct Camera Capture -> `POST /api/attachments/stage`)
///    - Uncommitted preview thumbnail/chip strip inside composer (no auto-send)
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

  // ───── Directive 3: Decoupled File & Direct Camera Staging (`POST /api/attachments/stage`) ─────

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
              content: Text('Could not stage attachment. Check connection and file type.'),
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

  // ───── WhatsApp-Style Hold-to-Record (.m4a -> /api/voice-command) ─────

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
        backgroundColor: AppColors.inkBlack,
        body: TechCanvasBackground(
          child: SafeArea(
            child: Column(
              children: [
                _buildTopBar(isHomeDashboard: isHomeDashboard),

                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: isHomeDashboard
                        ? _buildHomeDashboard(reminderState)
                        : _buildChatStream(chatState, messageItems),
                  ),
                ),

                _buildComposer(chatState),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────── STAGE 1: STREAMLINED HOME DASHBOARD (DIRECTIVES 1 & 2) ─────────

  Widget _buildHomeDashboard(HomeReminderState reminderState) {
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
        // ── 1. Clean Header (Cloud synced badge completely removed) ──
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
          _greetingTitle(),
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w700,
            color: AppColors.paperWhite,
            letterSpacing: -0.4,
          ),
        ),

        const SizedBox(height: 18),

        // ── 2. Circular Progress Ring Chart in "Task & usage progress" ──
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.inkCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.inkBorder, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Task & usage progress',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.paperMuted,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  // Modern Circular Progress Ring Chart
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
                            backgroundColor: AppColors.inkSurface,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.success,
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$progressPercent%',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                fontFeatures: [FontFeature.tabularFigures()],
                                color: AppColors.paperWhite,
                              ),
                            ),
                            const Text(
                              'done',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: AppColors.paperSubtle,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),

                  // Streamlined Scheduled vs Completed Metric Tiles
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildMetricTile(
                            label: 'Scheduled',
                            count: scheduledList.length,
                            dotColor: AppColors.signalAmber,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMetricTile(
                            label: 'Completed',
                            count: completedList.length,
                            dotColor: AppColors.success,
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

        const SizedBox(height: 22),

        // ── 3. Read-Only Autonomous Active Tasks Section (No checkboxes / No Quick Actions) ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Remaining tasks',
              style: TextStyle(
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
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  'See all →',
                  style: TextStyle(
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

        if (visibleActiveTasks.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            decoration: BoxDecoration(
              color: AppColors.inkCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.inkBorder, width: 1),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 26,
                  color: AppColors.success,
                ),
                SizedBox(height: 8),
                Text(
                  'All caught up',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.paperWhite,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Send a message, attach a file, or hold the mic below to schedule a new task.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.paperSubtle,
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

  // ───────── STAGE 2: WHATSAPP-STYLE CHAT STREAM ─────────

  Widget _buildChatStream(
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
                  border: Border.all(color: AppColors.inkBorderActive, width: 1),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/images/penguin_avatar.png',
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Send a message, stage an attachment, or hold the mic to speak',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.paperMuted,
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

  Widget _buildTopBar({required bool isHomeDashboard}) {
    return Container(
      height: 58,
      padding: const EdgeInsets.only(left: 16, right: 8),
      decoration: const BoxDecoration(
        color: AppColors.inkDeep,
        border: Border(bottom: BorderSide(color: AppColors.inkBorder, width: 1)),
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
                  isHomeDashboard ? 'Pingo' : 'Pingo Chat',
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
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 14,
                      color: AppColors.paperWhite,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Chat',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.paperWhite,
                      ),
                    ),
                  ],
                ),
              ),
            ),

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
                child: _menuItem(Icons.dashboard_outlined, 'Home dashboard'),
              ),
              PopupMenuItem(
                value: 'my_reminders',
                child: _menuItem(Icons.list_alt_rounded, 'All tasks'),
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

  // ───────── MULTIMODAL COMPOSER (STAGED PREVIEW + CAMERA + CLIP + MIC) ─────────

  Widget _buildComposer(PingoChatState chatState) {
    final canSend =
        (_hasInputText || chatState.stagedAttachments.isNotEmpty) &&
            !_isVoiceRecording;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.inkCard,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: _isVoiceRecording
                ? AppColors.overdue
                : AppColors.inkBorderActive,
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Uncommitted Staged Attachment Preview Strip (Decoupled — does NOT auto-send)
            if (chatState.stagedAttachments.isNotEmpty ||
                chatState.isStagingAttachment)
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ...chatState.stagedAttachments.map(
                        (item) => _buildStagedPreviewChip(item),
                      ),
                      if (chatState.isStagingAttachment)
                        Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.inkSurface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.inkBorder,
                              width: 1,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.signalAmber,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Staging...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.paperMuted,
                                ),
                              ),
                            ],
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
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Recording... release to send',
                      style: TextStyle(
                        color: AppColors.paperMuted,
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
                    child: const SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        Icons.attach_file_rounded,
                        color: AppColors.paperMuted,
                        size: 19,
                      ),
                    ),
                  ),
                  // Dedicated Direct Camera Capture Button (`ImageSource.camera` -> `/api/attachments/stage`)
                  InkWell(
                    onTap: _capturePhotoAndStage,
                    borderRadius: BorderRadius.circular(999),
                    child: const SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        Icons.camera_alt_outlined,
                        color: AppColors.paperMuted,
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
                      style: const TextStyle(
                        color: AppColors.paperWhite,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                      ),
                      decoration: InputDecoration(
                        filled: false,
                        hintText: chatState.stagedAttachments.isNotEmpty
                            ? 'Add instructions or hold mic...'
                            : 'Message or hold mic...',
                        hintStyle: const TextStyle(
                          color: AppColors.paperSubtle,
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
                        color: _isVoiceRecording
                            ? AppColors.overdue
                            : AppColors.success,
                      ),
                      child: Icon(
                        Icons.mic_rounded,
                        color: _isVoiceRecording
                            ? AppColors.paperWhite
                            : AppColors.inkBlack,
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

  Widget _buildStagedPreviewChip(StagedAttachmentPreviewItem item) {
    final hasLocalImage = item.isImage &&
        item.localPath != null &&
        File(item.localPath!).existsSync();

    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.inkSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.inkBorderActive, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasLocalImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.file(
                File(item.localPath!),
                width: 32,
                height: 32,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.inkCard,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.insert_drive_file_outlined,
                size: 16,
                color: AppColors.signalAmber,
              ),
            ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 130),
            child: Text(
              item.filename,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.paperWhite,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () {
              ref
                  .read(pingoChatProvider.notifier)
                  .removeStagedPreview(item.stagingId);
            },
            borderRadius: BorderRadius.circular(999),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(
                Icons.close_rounded,
                size: 15,
                color: AppColors.paperMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
