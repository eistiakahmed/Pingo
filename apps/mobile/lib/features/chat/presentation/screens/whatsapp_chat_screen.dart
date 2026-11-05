import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';
import '../state/chat_provider.dart';
import '../widgets/whatsapp_app_bar.dart';
import '../widgets/whatsapp_bubble.dart';
import '../widgets/whatsapp_input_bar.dart';
import 'package:pingo_mobile/features/voice_capture/presentation/widgets/voice_listening_overlay.dart';
import 'package:pingo_mobile/features/reminder_editor/presentation/screens/edit_reminder_screen.dart';

/// Pure WhatsApp-style Chat Screen for Pingo AI Assistant.
class WhatsAppChatScreen extends ConsumerStatefulWidget {
  const WhatsAppChatScreen({super.key});

  @override
  ConsumerState<WhatsAppChatScreen> createState() => _WhatsAppChatScreenState();
}

class _WhatsAppChatScreenState extends ConsumerState<WhatsAppChatScreen> {
  final ScrollController _scrollController = ScrollController();

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _openVoiceOverlay() {
    VoiceListeningOverlay.show(
      context: context,
      onSpeechFinished: (spokenText) {
        if (spokenText.trim().isNotEmpty) {
          ref.read(chatProvider.notifier).sendUserMessage(spokenText);
          _scrollToBottom();
        }
      },
    );
  }

  void _showAttachmentSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add to Pingo Memory',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _attachmentItem(
                    icon: Icons.document_scanner_rounded,
                    label: 'Scan Doc',
                    color: const Color(0xFF5F66CD),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      ref.read(chatProvider.notifier).sendUserMessage('Scanned new passport & national ID document');
                      _scrollToBottom();
                    },
                  ),
                  _attachmentItem(
                    icon: Icons.description_rounded,
                    label: 'New Doc Note',
                    color: const Color(0xFF00A884),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      ref.read(chatProvider.notifier).sendUserMessage('Draft meeting summary notes document');
                      _scrollToBottom();
                    },
                  ),
                  _attachmentItem(
                    icon: Icons.alarm_add_rounded,
                    label: 'Reminder',
                    color: const Color(0xFFE96144),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      EditReminderScreen.show(
                        context: context,
                        onSave: (reminder) {
                          ref.read(chatProvider.notifier).sendUserMessage('Scheduled reminder: ${reminder.title}');
                          _scrollToBottom();
                        },
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attachmentItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Classic WhatsApp wallpaper background color
    final wallpaperColor = isDark ? const Color(0xFF0B141A) : const Color(0xFFEFEAE2);

    return Scaffold(
      backgroundColor: wallpaperColor,
      appBar: WhatsAppAppBar(
        onVoiceCallTap: _openVoiceOverlay,
        onClearChat: () => ref.read(chatProvider.notifier).clearChat(),
      ),
      body: Column(
        children: [
          // Security / encryption pill banner
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF182229) : const Color(0xFFFFF2C5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_rounded,
                      size: 13,
                      color: isDark ? const Color(0xFFF7CF67) : const Color(0xFF866708),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Messages & memories are saved securely in your vault',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? const Color(0xFFD1D7DB) : const Color(0xFF54656F),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Message Thread
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: chatState.messages.length,
              itemBuilder: (context, index) {
                final message = chatState.messages[index];
                return WhatsAppBubble(
                  message: message,
                  onReminderTap: () {
                    if (message.reminder != null) {
                      EditReminderScreen.show(
                        context: context,
                        initialItem: message.reminder,
                        onSave: (updated) {
                          ref.read(chatProvider.notifier).sendUserMessage('Updated reminder: ${updated.title}');
                        },
                      );
                    }
                  },
                );
              },
            ),
          ),

          // Typing / Thinking Indicator
          if (chatState.isThinking) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF202C33) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Pingo is thinking...', style: TextStyle(fontSize: 12.5, color: Colors.grey)),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isDark ? const Color(0xFF00A884) : AppColors.brandPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          // WhatsApp Bottom Input Dock
          WhatsAppInputBar(
            onSendMessage: (text) {
              ref.read(chatProvider.notifier).sendUserMessage(text);
              _scrollToBottom();
            },
            onVoiceTap: _openVoiceOverlay,
            onAttachmentTap: _showAttachmentSheet,
          ),
        ],
      ),
    );
  }
}
