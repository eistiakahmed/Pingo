import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/voice_recognition_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/chat_message.dart';
import '../state/pingo_chat_provider.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/date_separator_chip.dart';
import '../widgets/tech_canvas_background.dart';
import '../widgets/typing_indicator_widget.dart';
import 'my_reminders_screen.dart';

/// Conversational Ledger Home Screen — Unslop 9-Pass Craft Edition.
/// - Quiet Ink neutral ramp (#0B0D14 background, #07080D header, #11141C surfaces).
/// - 4px spatial rhythm, 18px uniform line icons, weights 400–600.
/// - Structured 16px desk composer with nested 12px action keycap.
class PingoHomeScreen extends ConsumerStatefulWidget {
  const PingoHomeScreen({super.key});

  @override
  ConsumerState<PingoHomeScreen> createState() => _PingoHomeScreenState();
}

class _PingoHomeScreenState extends ConsumerState<PingoHomeScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _hasInputText = false;
  bool _isVoiceRecording = false;
  String _transcribedVoiceText = '';
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.initialize();
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
    _pulseController.dispose();
    _inputController.removeListener(_onInputChanged);
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      ref.read(pingoChatProvider.notifier).suspendServices();
      VoiceRecognitionService.instance.cancelListening();
      _resetRecordingState();
    }
  }

  void _resetRecordingState() {
    _recTimer?.cancel();
    _recTimer = null;
    _pulseController.stop();
    if (mounted && (_isVoiceRecording || _transcribedVoiceText.isNotEmpty)) {
      setState(() {
        _isVoiceRecording = false;
        _transcribedVoiceText = '';
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
    _inputController.clear();
    ref.read(pingoChatProvider.notifier).sendMessage(trimmed);
    _scrollToBottom();
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

  // ───── Tap-to-record voice capture ─────

  Future<void> _toggleVoiceCapture() async {
    if (_isVoiceRecording) {
      await _stopVoiceAndSend();
    } else {
      await _startVoiceCapture();
    }
  }

  Future<void> _startVoiceCapture() async {
    HapticFeedback.mediumImpact();
    final ready = await VoiceRecognitionService.instance.initialize();
    if (!ready) {
      _resetRecordingState();
      return;
    }

    final langCode = ref.read(pingoChatProvider).language;
    final localeId = VoiceRecognitionService.instance.findBestLocale(langCode);

    if (!mounted) return;
    setState(() {
      _isVoiceRecording = true;
      _transcribedVoiceText = '';
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

    final started = await VoiceRecognitionService.instance.startListening(
      localeId: localeId,
      onResult: (words) {
        if (mounted) {
          setState(() {
            _transcribedVoiceText = words;
          });
        }
      },
    );
    if (!started) {
      _resetRecordingState();
    }
  }

  Future<void> _stopVoiceAndSend() async {
    HapticFeedback.lightImpact();
    _recTimer?.cancel();
    _recTimer = null;
    _pulseController.stop();
    await VoiceRecognitionService.instance.stopListening();

    final transcript = _transcribedVoiceText.trim();
    final isBangla = ref.read(pingoChatProvider).language == 'bn';

    setState(() {
      _isVoiceRecording = false;
      _transcribedVoiceText = '';
      _recElapsed = Duration.zero;
    });

    if (transcript.isNotEmpty) {
      _handleSend(transcript);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isBangla
                ? 'কোনো কথা ধরা পড়েনি, আবার চেষ্টা করুন'
                : 'Nothing captured, try again',
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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

  // ─────────────────────────────── BUILD ───────────────────────────────

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(pingoChatProvider);
    final isBangla = chatState.language == 'bn';

    final messageItems = _buildMessageItems(chatState.messages, isBangla);

    return Scaffold(
      backgroundColor: AppColors.inkBlack,
      body: TechCanvasBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(isBangla),

              Expanded(
                child: chatState.messages.isEmpty && !chatState.isThinking
                    ? const SizedBox.expand()
                    : ListView(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        children: [
                          ...messageItems,
                          if (chatState.isThinking)
                            TypingIndicatorWidget(
                              statusText: isBangla
                                  ? 'পিঙ্গো ভাবছে'
                                  : 'Pingo is thinking',
                            ),
                        ],
                      ),
              ),

              _buildComposer(isBangla, _hasInputText),
            ],
          ),
        ),
      ),
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

  Widget _buildTopBar(bool isBangla) {
    return Container(
      height: 56,
      padding: const EdgeInsets.only(left: 16, right: 8),
      decoration: const BoxDecoration(
        color: AppColors.inkDeep,
        border: Border(bottom: BorderSide(color: AppColors.inkBorder, width: 1)),
      ),
      child: Row(
        children: [
          // Flat horological glyph mark in a quiet 32x32 bordered keycap
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.inkCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.inkBorder, width: 1),
            ),
            child: const Icon(
              Icons.schedule_rounded,
              color: AppColors.paperWhite,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                const Text(
                  'Pingo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.paperWhite,
                  ),
                ),
                const SizedBox(width: 8),
                // Signature 6px live status dot
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isBangla ? 'বাংলা' : 'EN',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.paperSubtle,
                  ),
                ),
              ],
            ),
          ),

          // Menu: New chat / My reminders / Language
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
                value: 'new_chat',
                child: _menuItem(
                  Icons.chat_bubble_outline_rounded,
                  isBangla ? 'নতুন চ্যাট' : 'New chat',
                ),
              ),
              PopupMenuItem(
                value: 'my_reminders',
                child: _menuItem(
                  Icons.list_alt_rounded,
                  isBangla ? 'আমার রিমাইন্ডার' : 'My reminders',
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'lang_bn',
                child: _menuItem(
                  isBangla
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  'বাংলা',
                ),
              ),
              PopupMenuItem(
                value: 'lang_en',
                child: _menuItem(
                  !isBangla
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  'English',
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'new_chat') {
                HapticFeedback.selectionClick();
                ref.read(pingoChatProvider.notifier).startNewChat();
              } else if (value == 'my_reminders') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MyRemindersScreen(),
                  ),
                );
              } else if (value == 'lang_bn' || value == 'lang_en') {
                HapticFeedback.selectionClick();
                ref
                    .read(pingoChatProvider.notifier)
                    .setLanguage(value == 'lang_bn' ? 'bn' : 'en');
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

  Widget _buildComposer(bool isBangla, bool hasInputText) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: _isVoiceRecording
          ? _buildRecordingBar(isBangla)
          : _buildInputBar(isBangla, hasInputText),
    );
  }

  /// Active recording bar: nested radius 16px outer / 12px inner keycap,
  /// subtle opacity indicator on the 6px recording dot, tabular timer.
  Widget _buildRecordingBar(bool isBangla) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inkBorderActive, width: 1),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.inkSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.mic_rounded,
              color: AppColors.overdue,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          FadeTransition(
            opacity: Tween<double>(begin: 0.35, end: 1.0).animate(
              CurvedAnimation(
                parent: _pulseController,
                curve: Curves.easeOutCubic,
              ),
            ),
            child: Container(
              width: 6,
              height: 6,
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
              fontSize: 13,
              fontWeight: FontWeight.w500,
              fontFeatures: [FontFeature.tabularFigures()],
              color: AppColors.paperWhite,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _transcribedVoiceText.isNotEmpty
                  ? _transcribedVoiceText
                  : (isBangla ? 'কথা বলুন' : 'Listening'),
              style: TextStyle(
                color: _transcribedVoiceText.isNotEmpty
                    ? AppColors.paperWhite
                    : AppColors.paperSubtle,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.45,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _toggleVoiceCapture,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.paperWhite,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.stop_rounded,
                color: AppColors.inkBlack,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Idle composer: outer radius 16px, 4px padding, inner 36x36 button radius 12px.
  Widget _buildInputBar(bool isBangla, bool hasInputText) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inkBorder, width: 1),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          InkWell(
            onTap: _pickNativeDocument,
            borderRadius: BorderRadius.circular(12),
            child: const SizedBox(
              width: 36,
              height: 36,
              child: Icon(
                Icons.attach_file_rounded,
                color: AppColors.paperMuted,
                size: 18,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _inputController,
              onSubmitted: _handleSend,
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.newline,
              style: const TextStyle(
                color: AppColors.paperWhite,
                fontSize: 15,
                fontWeight: FontWeight.w400,
                height: 1.45,
              ),
              decoration: InputDecoration(
                filled: false,
                hintText: isBangla
                    ? 'রিমাইন্ডার লিখুন'
                    : 'Write a reminder',
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
          const SizedBox(width: 4),
          GestureDetector(
            onTap: hasInputText
                ? () => _handleSend(_inputController.text)
                : _toggleVoiceCapture,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: hasInputText
                    ? AppColors.paperWhite
                    : AppColors.inkSurface,
                border: Border.all(
                  color: hasInputText
                      ? AppColors.paperWhite
                      : AppColors.inkBorder,
                  width: 1,
                ),
              ),
              child: Icon(
                hasInputText ? Icons.arrow_upward_rounded : Icons.mic_none_rounded,
                color: hasInputText
                    ? AppColors.inkBlack
                    : AppColors.paperWhite,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
