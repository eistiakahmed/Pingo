import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/notification_service.dart';
import '../../../vault/presentation/screens/pingo_vault_screen.dart';
import '../../../voice_capture/presentation/screens/pingo_voice_screen.dart';
import '../state/pingo_chat_provider.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/penguin_mascot_widget.dart';
import '../widgets/typing_indicator_widget.dart';

/// Flagship Conversational Interface for Pingo.
/// Minimalist dark-mode conversational thread with cute animated mascot onboarding,
/// rounded message bubbles, dynamic typing indicator, and haptic voice activation.
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

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(pingoChatProvider);
    final isBangla = chatState.language == 'bn';

    return Scaffold(
      backgroundColor: const Color(0xFF080B11), // Deep Antarctic Midnight
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation & Bilingual Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  // Cute Mini Penguin Mascot Badge
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF131B2A),
                      border: Border.all(color: const Color(0xFF1E293B), width: 1.2),
                    ),
                    child: const Center(
                      child: Text('🐧', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Brand & Engine Status Dot
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pingo',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFF8FAFC),
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
                            isBangla ? 'সক্রিয় · প্রস্তুত' : 'Online · Ready',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Bilingual Switcher Pill: [ EN | বাং ]
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
                  const SizedBox(width: 8),

                  // New Session / Archive Button
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

                  // Vault Shortcut
                  IconButton(
                    tooltip: isBangla ? 'ডকুমেন্ট ভল্ট' : 'Document Vault',
                    icon: const Icon(
                      Icons.folder_outlined,
                      color: Color(0xFF94A3B8),
                      size: 20,
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PingoVaultScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),

            const Divider(color: Color(0xFF172033), height: 1),

            // Conversational Stream / Onboarding Canvas
            Expanded(
              child: chatState.messages.isEmpty
                  ? Center(
                      child: PenguinMascotWidget(
                        language: chatState.language,
                        onPromptSelected: (prompt) {
                          _handleSend(prompt);
                        },
                      ),
                    )
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

            // Bottom Input Dock: Sleek Floating Bar
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Row(
                  children: [
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
                              ? 'পিঙ্গোকে কিছু বলুন বা লিখুন...'
                              : 'Ask or tell Pingo anything...',
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
                        padding: const EdgeInsets.all(9),
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
                        padding: const EdgeInsets.all(9),
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
