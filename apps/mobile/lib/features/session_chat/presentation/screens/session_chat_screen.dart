import 'package:flutter/material.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';
import 'package:pingo_mobile/features/home/domain/reminder_item.dart';
import 'package:pingo_mobile/features/chat/domain/chat_message.dart';
import 'package:pingo_mobile/features/chat/presentation/widgets/whatsapp_bubble.dart';
import 'package:pingo_mobile/features/minimal_input/presentation/widgets/documents_vault_sheet.dart';
import 'package:pingo_mobile/features/voice_capture/presentation/widgets/voice_listening_overlay.dart';
import 'package:pingo_mobile/features/reminder_editor/presentation/screens/edit_reminder_screen.dart';
import '../widgets/sleek_input_dock.dart';

/// The central Session-Based AI Chatbot Screen.
/// Starts every session in a pristine, clean state.
/// Transitions to an active conversation thread upon user interaction.
/// Provides a one-tap 'New Chat' (+) button to reset the session.
class SessionChatScreen extends StatefulWidget {
  const SessionChatScreen({super.key});

  @override
  State<SessionChatScreen> createState() => _SessionChatScreenState();
}

class _SessionChatScreenState extends State<SessionChatScreen> {
  final List<ChatMessage> _sessionMessages = [];
  bool _isThinking = false;
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

  void _startNewChat() {
    setState(() {
      _sessionMessages.clear();
      _isThinking = false;
    });
  }

  Future<void> _handleUserSubmission(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: trimmed,
      sender: ChatMessageSender.user,
      timestamp: DateTime.now(),
    );

    setState(() {
      _sessionMessages.add(userMessage);
      _isThinking = true;
    });
    _scrollToBottom();

    // Simulate intelligent AI parsing
    await Future.delayed(const Duration(milliseconds: 650));

    final lower = trimmed.toLowerCase();
    ChatMessage pingoReply;

    if (lower.contains('remind') ||
        lower.contains('doctor') ||
        lower.contains('meeting') ||
        lower.contains('alarm') ||
        lower.contains('মনে')) {
      pingoReply = ChatMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        text: "I've scheduled this reminder and saved it to your memory vault.",
        sender: ChatMessageSender.pingo,
        type: ChatMessageType.memoryReminder,
        reminder: ReminderItem(
          id: 'rem_${DateTime.now().millisecondsSinceEpoch}',
          title: trimmed.length > 36 ? '${trimmed.substring(0, 36)}...' : trimmed,
          dueAt: DateTime.now().add(const Duration(hours: 4)),
          category: ReminderCategory.personal,
          priority: ReminderPriority.important,
        ),
        timestamp: DateTime.now(),
      );
    } else if (lower.contains('doc') ||
        lower.contains('note') ||
        lower.contains('summary') ||
        lower.contains('paper') ||
        lower.contains('ডকুমেন্ট')) {
      pingoReply = ChatMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        text: "Here is your generated document, ready in your vault:",
        sender: ChatMessageSender.pingo,
        type: ChatMessageType.documentNote,
        document: DocumentPayload(
          title: 'Document: ${trimmed.length > 24 ? trimmed.substring(0, 24) : trimmed}',
          category: 'Notes & Documentation',
          summary: 'Auto-structured document created from your session context.',
          bulletPoints: const [
            'Indexed for semantic search & recall',
            'Full markdown format stored in vault',
            'Exportable to PDF or plain text',
          ],
          tags: const ['Draft', 'Auto-Saved'],
        ),
        timestamp: DateTime.now(),
      );
    } else {
      pingoReply = ChatMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        text: "Recorded in your memory vault! You can ask me about this anytime or ask me to turn it into a document.",
        sender: ChatMessageSender.pingo,
        timestamp: DateTime.now(),
      );
    }

    if (mounted) {
      setState(() {
        _sessionMessages.add(pingoReply);
        _isThinking = false;
      });
      _scrollToBottom();
    }
  }

  void _openVoice() {
    VoiceListeningOverlay.show(
      context: context,
      onSpeechFinished: (recognizedText) {
        if (recognizedText.trim().isNotEmpty) {
          _handleUserSubmission(recognizedText);
        }
      },
    );
  }

  void _openUploadSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E242B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Upload to Pingo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _uploadOption(
                    icon: Icons.upload_file_rounded,
                    label: 'Upload Doc/PDF',
                    color: const Color(0xFF4F46E5),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _handleUserSubmission('Uploaded PDF document: Contract Agreement');
                    },
                  ),
                  _uploadOption(
                    icon: Icons.document_scanner_rounded,
                    label: 'Scan (OCR)',
                    color: const Color(0xFF00A884),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _handleUserSubmission('Scanned new physical paper document');
                    },
                  ),
                  _uploadOption(
                    icon: Icons.image_rounded,
                    label: 'Photo / Media',
                    color: const Color(0xFFE11D48),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _handleUserSubmission('Uploaded image receipt for expense logging');
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

  Widget _uploadOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canvasBg = isDark ? const Color(0xFF0F141A) : const Color(0xFFF9FAFB);
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final subColor = isDark ? Colors.white54 : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: canvasBg,
      appBar: AppBar(
        backgroundColor: canvasBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Pingo',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            color: AppColors.brandPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.folder_special_outlined,
              color: isDark ? Colors.white70 : const Color(0xFF4B5563),
              size: 22,
            ),
            tooltip: 'Document Vault',
            onPressed: () => DocumentsVaultSheet.show(context),
          ),
          IconButton(
            icon: Icon(
              Icons.add_comment_outlined,
              color: AppColors.brandPrimary,
              size: 22,
            ),
            tooltip: 'New Chat',
            onPressed: _startNewChat,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Body: Empty Fresh Session vs Active Chat Thread
            Expanded(
              child: _sessionMessages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.brandPrimary.withValues(alpha: 0.9),
                                    AppColors.brandSecondary.withValues(alpha: 0.85),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.brandPrimary.withValues(alpha: 0.25),
                                    blurRadius: 28,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(Icons.blur_on_rounded, color: Colors.white, size: 34),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              "What's on your mind?",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: titleColor,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Ask, schedule reminders, or create documents',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14.5,
                                color: subColor,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      itemCount: _sessionMessages.length,
                      itemBuilder: (context, index) {
                        final msg = _sessionMessages[index];
                        return WhatsAppBubble(
                          message: msg,
                          onReminderTap: () {
                            if (msg.reminder != null) {
                              EditReminderScreen.show(
                                context: context,
                                initialItem: msg.reminder,
                                onSave: (updated) {
                                  _handleUserSubmission('Updated reminder: ${updated.title}');
                                },
                              );
                            }
                          },
                        );
                      },
                    ),
            ),

            // Thinking Indicator (active session)
            if (_isThinking) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E242B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text('Pingo is thinking...', style: TextStyle(fontSize: 12.5, color: Colors.grey)),
                        SizedBox(width: 8),
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            // Single Sleek Input Dock
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: SleekInputDock(
                onSubmitText: _handleUserSubmission,
                onVoiceTap: _openVoice,
                onUploadTap: _openUploadSheet,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

