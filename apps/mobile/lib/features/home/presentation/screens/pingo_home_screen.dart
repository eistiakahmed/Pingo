import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/voice_recognition_service.dart';
import '../../domain/chat_message.dart';
import '../state/context_suggestion_service.dart';
import '../state/home_reminder_provider.dart';
import '../state/pingo_chat_provider.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/date_separator_chip.dart';
import '../widgets/tech_canvas_background.dart';
import '../widgets/typing_indicator_widget.dart';
import 'my_reminders_screen.dart';

/// WhatsApp-style conversational home screen:
/// 1. Fresh, empty chat on every launch (reminders stay saved separately).
/// 2. Single screen: message list with centred date chips + a compact
///    composer with a large, obvious microphone button.
/// 3. Tap-to-record voice capture: pulsing mic, visible timer, tap again to
///    stop & send — the transcript becomes the user's own bubble.
/// 4. Top-bar menu: "New chat" (clears the screen) and "My reminders"
///    (dedicated screen to edit/delete saved reminders).
/// 5. Reminders render as ONE small confirmation bubble, never big cards.
class PingoHomeScreen extends ConsumerStatefulWidget {
  const PingoHomeScreen({super.key});

  @override
  ConsumerState<PingoHomeScreen> createState() => _PingoHomeScreenState();
}

class _PingoHomeScreenState extends ConsumerState<PingoHomeScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isVoiceRecording = false;
  String _transcribedVoiceText = '';
  Timer? _recTimer;
  Duration _recElapsed = Duration.zero;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _inputController.addListener(() {
      if (mounted) setState(() {});
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.requestPermissions();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recTimer?.cancel();
    _pulseController.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Strict background suspension: cancel speech & audio services when app is paused
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

  /// Native File Picker invocation — eliminates preset menus
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

  // ───── Tap-to-record voice capture (WhatsApp voice-note style) ─────

  Future<void> _toggleVoiceCapture() async {
    if (_isVoiceRecording) {
      await _stopVoiceAndSend();
    } else {
      await _startVoiceCapture();
    }
  }

  Future<void> _startVoiceCapture() async {
    HapticFeedback.mediumImpact();
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

    final langCode = ref.read(pingoChatProvider).language;
    final localeId = VoiceRecognitionService.instance.findBestLocale(langCode);

    await VoiceRecognitionService.instance.startListening(
      localeId: localeId,
      onResult: (words) {
        if (mounted) {
          setState(() {
            _transcribedVoiceText = words;
          });
        }
      },
    );
  }

  /// Tap again to stop: the transcribed text becomes the user's bubble
  /// and is submitted for parsing.
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
                ? 'কোনো কথা ধরা পড়েনি। আবার চেষ্টা করুন।'
                : 'Nothing captured. Try again.',
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Document expiry alert configuration via native date picker
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
              primary: Color(0xFF0284C7),
              onPrimary: Colors.white,
              surface: Color(0xFF0F172A),
              onSurface: Colors.white,
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
    final hasInputText = _inputController.text.trim().isNotEmpty;

    final messageItems = _buildMessageItems(chatState.messages, isBangla);

    return Scaffold(
      backgroundColor: const Color(0xFF0B141A),
      body: TechCanvasBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(isBangla),

              const Divider(color: Color(0xFF172033), height: 1),

              // Main Area: greeting canvas when empty, chat stream otherwise
              Expanded(
                child: chatState.messages.isEmpty && !chatState.isThinking
                    ? _buildIdleState(isBangla)
                    : ListView(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        children: [
                          ...messageItems,
                          if (chatState.isThinking)
                            TypingIndicatorWidget(
                              statusText: isBangla
                                  ? 'পিঙ্গো ভাবছে...'
                                  : 'Pingo is thinking...',
                            ),
                        ],
                      ),
              ),

              _buildComposer(isBangla, hasInputText),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // App identity + operational status (WhatsApp-header feel)
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF131B2A),
                    border: Border.all(
                        color: const Color(0xFF1E293B), width: 1.2),
                  ),
                  child: const Icon(
                    Icons.smart_toy_outlined,
                    color: Color(0xFF38BDF8),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pingo',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFF1F5F9),
                        letterSpacing: -0.2,
                      ),
                    ),
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
                        const SizedBox(width: 5),
                        Text(
                          isBangla ? 'সক্রিয় — প্রস্তুত' : 'Online — Ready',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Bilingual Toggle Pill: [ বাং | EN ]
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF131B2A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF1E293B), width: 1),
            ),
            padding: const EdgeInsets.all(2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _langPill('বাং', 'bn', isBangla),
                _langPill('EN', 'en', !isBangla),
              ],
            ),
          ),

          // Menu: New chat / My reminders
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: Color(0xFF94A3B8),
            ),
            color: const Color(0xFF131B2A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFF1E293B)),
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
        Icon(icon, size: 18, color: const Color(0xFF38BDF8)),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFFF1F5F9),
          ),
        ),
      ],
    );
  }

  // ──────────────────────────── COMPOSER ────────────────────────────

  Widget _buildComposer(bool isBangla, bool hasInputText) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: _isVoiceRecording
          ? _buildRecordingBar(isBangla)
          : _buildInputBar(isBangla, hasInputText),
    );
  }

  /// Active recording: pulsing mic, visible timer, live transcript preview.
  Widget _buildRecordingBar(bool isBangla) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1118),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          // Pulsing microphone
          ScaleTransition(
            scale: Tween<double>(begin: 1.0, end: 1.18).animate(
              CurvedAnimation(
                parent: _pulseController,
                curve: Curves.easeInOut,
              ),
            ),
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFEF4444),
              ),
              child: const Icon(
                Icons.mic_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Recording indicator + timer
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isBangla ? 'রেকর্ড হচ্ছে' : 'Recording',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: Color(0xFFFCA5A5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 1),
              Text(
                _formatRecTimer(_recElapsed),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                  color: Color(0xFFE2E8F0),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),

          // Live transcript preview
          Expanded(
            child: Text(
              _transcribedVoiceText.isNotEmpty
                  ? _transcribedVoiceText
                  : (isBangla ? 'কথা বলুন…' : 'Speak now…'),
              style: TextStyle(
                color: _transcribedVoiceText.isNotEmpty
                    ? const Color(0xFFF1F5F9)
                    : const Color(0xFF94A3B8),
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(width: 8),

          // Tap again to stop & send
          GestureDetector(
            onTap: _toggleVoiceCapture,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEF4444),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35), width: 1.5),
              ),
              child: const Icon(
                Icons.stop_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Idle composer: [attach] [text field] [large mic → send when typing]
  Widget _buildInputBar(bool isBangla, bool hasInputText) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111726),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF1D263B), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Document attachment
          InkWell(
            onTap: _pickNativeDocument,
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(9),
              child: Icon(
                Icons.attach_file_rounded,
                color: Color(0xFF38BDF8),
                size: 21,
              ),
            ),
          ),

          // Text field
          Expanded(
            child: TextField(
              controller: _inputController,
              onSubmitted: _handleSend,
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.newline,
              style: const TextStyle(
                color: Color(0xFFF8FAFC),
                fontSize: 15,
                height: 1.45,
              ),
              decoration: InputDecoration(
                hintText: isBangla
                    ? 'বার্তা বা রিমাইন্ডার লিখুন…'
                    : 'Message or reminder…',
                hintStyle: TextStyle(
                  color: const Color(0xFF94A3B8).withValues(alpha: 0.65),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              ),
            ),
          ),

          const SizedBox(width: 4),

          // Large, obvious mic — swaps to send while typing (WhatsApp-style)
          GestureDetector(
            onTap: hasInputText
                ? () => _handleSend(_inputController.text)
                : _toggleVoiceCapture,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: hasInputText
                    ? const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: hasInputText ? null : const Color(0xFF1E293B),
                border: Border.all(
                  color: hasInputText
                      ? const Color(0xFF3B82F6)
                      : const Color(0xFF334155),
                  width: 1,
                ),
                boxShadow: hasInputText
                    ? [
                        BoxShadow(
                          color:
                              const Color(0xFF2563EB).withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                hasInputText ? Icons.arrow_upward_rounded : Icons.mic_rounded,
                color: hasInputText ? Colors.white : const Color(0xFF38BDF8),
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────── IDLE STATE ────────────────────────────

  Widget _buildIdleState(bool isBangla) {
    final reminders = ref.watch(homeReminderProvider).reminders;
    final storedDocsCount = ref
        .watch(pingoChatProvider)
        .messages
        .where((m) => m.hasDocument)
        .length;
    final pendingCount = reminders.where((r) => !r.isDone).length;

    final suggestions = ContextSuggestionService.instance.getSuggestions(
      language: isBangla ? 'bn' : 'en',
      pendingTasksCount: pendingCount,
      storedDocsCount: storedDocsCount,
    );
    final timeGreeting = ContextSuggestionService.instance
        .getGreetingHeader(language: isBangla ? 'bn' : 'en');

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF131B2A),
                border: Border.all(color: const Color(0xFF1E293B), width: 1.2),
              ),
              child: const Icon(
                Icons.memory_rounded,
                color: Color(0xFF38BDF8),
                size: 26,
              ),
            ),
            const SizedBox(height: 18),

            Text(
              timeGreeting,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFFF8FAFC),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isBangla
                  ? 'আপনার শিডিউল, রিমাইন্ডার এবং ডকুমেন্টের জন্য আমি প্রস্তুত।'
                  : 'Ready to coordinate your schedule, reminders, and documents.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF94A3B8),
                height: 1.45, // Bangla-safe line height
              ),
            ),

            const SizedBox(height: 28),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                isBangla ? 'প্রাসঙ্গিক প্রস্তাবনা' : 'CONTEXT SUGGESTIONS',
                style: const TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
            const SizedBox(height: 10),

            ...suggestions.map((suggestion) {
              return InkWell(
                onTap: () => _handleSend(suggestion),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131B2A).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: const Color(0xFF1E293B), width: 1.1),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.bolt_rounded,
                        size: 15,
                        color: Color(0xFF38BDF8),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          suggestion,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: Color(0xFFE2E8F0),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: Color(0xFF64748B),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _langPill(String label, String langCode, bool isSelected) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        ref.read(pingoChatProvider.notifier).setLanguage(langCode);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }
}
