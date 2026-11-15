import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/notification_service.dart';
import '../../../voice_capture/presentation/screens/pingo_voice_screen.dart';
import '../state/context_suggestion_service.dart';
import '../state/home_reminder_provider.dart';
import '../state/pingo_chat_provider.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/tech_canvas_background.dart';
import '../widgets/typing_indicator_widget.dart';

/// Flagship Tech-Minimalist Conversational Interface for Pingo.
/// Features a subtle animated tech canvas (circuits, AI nodes, reminder motifs),
/// streamlined header with live status only, dynamic context-aware suggestions,
/// and direct inline document & reminder management.
class PingoHomeScreen extends ConsumerStatefulWidget {
  const PingoHomeScreen({super.key});

  @override
  ConsumerState<PingoHomeScreen> createState() => _PingoHomeScreenState();
}

class _PingoHomeScreenState extends ConsumerState<PingoHomeScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.requestPermissions();
    });
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

  void _triggerVoiceInput() {
    // Tactile haptic feedback on microphone activation
    HapticFeedback.mediumImpact();

    PingoVoiceScreen.show(
      context,
      onSpeechFinished: (speechText) {
        if (speechText.trim().isNotEmpty) {
          ref.read(pingoChatProvider.notifier).sendMessage(speechText);
          _scrollToBottom();
        }
      },
    );
  }

  void _openDocumentAttachmentSheet() {
    HapticFeedback.lightImpact();
    final isBangla = ref.read(pingoChatProvider).language == 'bn';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        side: BorderSide(color: Color(0xFF1E293B), width: 1.2),
      ),
      builder: (ctx) {
        final options = [
          {'title': isBangla ? 'পাসপোর্ট (Passport)' : 'Passport', 'category': 'Identity', 'expiry': 'Oct 2031'},
          {'title': isBangla ? 'জাতীয় পরিচয়পত্র (NID)' : 'National ID Card', 'category': 'Identity', 'expiry': 'Permanent'},
          {'title': isBangla ? 'ড্রাইভিং লাইসেন্স' : "Driver's License", 'category': 'Identity', 'expiry': 'May 2028'},
          {'title': isBangla ? 'স্বাস্থ্য ও বীমা কার্ড' : 'Health & Insurance Card', 'category': 'Health', 'expiry': 'Jan 2026'},
          {'title': isBangla ? 'কাস্টম ডকুমেন্ট' : 'Custom Document', 'category': 'General', 'expiry': 'Dec 2029'},
        ];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isBangla ? 'ডকুমেন্ট সংরক্ষণ করুন' : 'Attach Document to Memory',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 20),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  isBangla
                      ? 'ডকুমেন্টটি ডিভাইস এনক্রিপশনের মাধ্যমে সুরক্ষিত সংরক্ষণ করা হবে।'
                      : 'Documents are encrypted on-device and managed directly in your conversation.',
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 14),
                ...options.map((opt) {
                  return InkWell(
                    onTap: () {
                      Navigator.of(ctx).pop();
                      ref.read(pingoChatProvider.notifier).attachDocument(
                            title: opt['title']!,
                            category: opt['category']!,
                            expiry: opt['expiry'],
                          );
                      _scrollToBottom();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF334155), width: 1),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.description_outlined, color: Color(0xFF38BDF8), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              opt['title']!,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Text(
                            opt['category']!,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(pingoChatProvider);
    final reminders = ref.watch(homeReminderProvider).reminders;
    final isBangla = chatState.language == 'bn';

    final pendingCount = reminders.where((r) => !r.isDone).length;
    final storedDocsCount = chatState.messages.where((m) => m.hasDocument).length;

    // Dynamic Context-Aware Suggestions (computed from ambient signals)
    final suggestions = ContextSuggestionService.instance.getSuggestions(
      language: chatState.language,
      pendingTasksCount: pendingCount,
      storedDocsCount: storedDocsCount,
    );

    final timeGreeting = ContextSuggestionService.instance.getGreetingHeader(language: chatState.language);

    return Scaffold(
      backgroundColor: const Color(0xFF080B11),
      body: TechCanvasBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Top Streamlined Header: Brand & Live App Status ONLY (No external vault shortcuts)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Row(
                  children: [
                    // Faint Tech Emblem Dot
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF10B981),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF10B981),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // App Title & Live Operational Status
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pingo',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFF8FAFC),
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          isBangla ? 'সক্রিয় · প্রস্তুত' : 'Online · Ready',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Bilingual Toggle Pill: [ EN | বাং ]
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
                    const SizedBox(width: 6),

                    // Reset Session Icon
                    IconButton(
                      tooltip: isBangla ? 'নতুন সেশন' : 'New Session',
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Color(0xFF94A3B8),
                        size: 20,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        ref.read(pingoChatProvider.notifier).startNewSession();
                      },
                    ),
                  ],
                ),
              ),

              const Divider(color: Color(0xFF172033), height: 1),

              // Main Area: Dynamic Context Canvas or Active Message Stream
              Expanded(
                child: chatState.messages.isEmpty
                    ? _buildTechIdleState(timeGreeting, isBangla, suggestions)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: chatState.messages.length + (chatState.isThinking ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index < chatState.messages.length) {
                            final msg = chatState.messages[index];
                            return ChatMessageBubble(
                              message: msg,
                              onActionSelected: (action) {
                                _handleSend(action);
                              },
                            );
                          } else {
                            // Dynamic 3-dot typing indicator
                            return TypingIndicatorWidget(
                              statusText: isBangla ? 'পিঙ্গো ভাবছে...' : 'Pingo is thinking...',
                            );
                          }
                        },
                      ),
              ),

              // Bottom Input Dock: Document Attachment + Text Input + Voice + Send
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: Container(
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Row(
                    children: [
                      // Prominent Document Attachment Trigger
                      InkWell(
                        onTap: _openDocumentAttachmentSheet,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF1E293B),
                            border: Border.all(color: const Color(0xFF334155), width: 1),
                          ),
                          child: const Icon(
                            Icons.attach_file_rounded,
                            color: Color(0xFF38BDF8),
                            size: 19,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Text Input Field
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          onSubmitted: _handleSend,
                          style: const TextStyle(
                            color: Color(0xFFF8FAFC),
                            fontSize: 14.5,
                          ),
                          decoration: InputDecoration(
                            hintText: isBangla
                                ? 'বার্তা বা কমান্ড লিখুন...'
                                : 'Message or command...',
                            hintStyle: TextStyle(
                              color: const Color(0xFF94A3B8).withValues(alpha: 0.65),
                              fontSize: 13.5,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                          ),
                        ),
                      ),

                      // Voice Microphone Trigger with Haptic Feedback
                      InkWell(
                        onTap: _triggerVoiceInput,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF1E293B),
                            border: Border.all(color: const Color(0xFF334155), width: 1),
                          ),
                          child: const Icon(
                            Icons.mic_none_rounded,
                            color: Color(0xFF38BDF8),
                            size: 19,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Send Button
                      InkWell(
                        onTap: () => _handleSend(_inputController.text),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF2563EB),
                                Color(0xFF1D4ED8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_upward_rounded,
                            color: Colors.white,
                            size: 19,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTechIdleState(String timeGreeting, bool isBangla, List<String> suggestions) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Tech Emblem Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF131B2A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1E293B), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.memory_rounded, color: Color(0xFF38BDF8), size: 14),
                  const SizedBox(width: 6),
                  Text(
                    isBangla ? 'পিঙ্গো ইন্টেলিজেন্স // সক্রিয়' : 'PINGO AI // ACTIVE',
                    style: const TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF38BDF8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Time Greeting & Prompt
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
                height: 1.4,
              ),
            ),

            const SizedBox(height: 28),

            // Dynamic Context-Aware Suggestions Header
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

            // Dynamic Suggestion Cards
            ...suggestions.map((suggestion) {
              return InkWell(
                onTap: () => _handleSend(suggestion),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131B2A).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF1E293B), width: 1.1),
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
