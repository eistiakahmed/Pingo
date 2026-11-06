import 'package:flutter/material.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';
import 'package:pingo_mobile/features/home/domain/reminder_item.dart';
import 'package:pingo_mobile/features/chat/domain/chat_message.dart';
import 'package:pingo_mobile/features/action_stream/presentation/widgets/deliverable_cards.dart';
import 'package:pingo_mobile/features/minimal_input/presentation/widgets/documents_vault_sheet.dart';
import 'package:pingo_mobile/features/session_chat/presentation/widgets/sleek_input_dock.dart';
import 'package:pingo_mobile/features/voice_capture/presentation/widgets/voice_listening_overlay.dart';
import 'package:pingo_mobile/features/reminder_editor/presentation/screens/edit_reminder_screen.dart';

/// Item representing an executive deliverable in the action stream.
class StreamDeliverable {
  final String id;
  final ChatMessageType type;
  final String text;
  final ReminderItem? reminder;
  final DocumentPayload? document;
  final DateTime timestamp;

  const StreamDeliverable({
    required this.id,
    required this.type,
    required this.text,
    this.reminder,
    this.document,
    required this.timestamp,
  });
}

/// The Non-Chatbot Executive Action Stream Screen.
/// Replaces message bubbles with direct, rich deliverable cards.
class ExecutiveStreamScreen extends StatefulWidget {
  const ExecutiveStreamScreen({super.key});

  @override
  State<ExecutiveStreamScreen> createState() => _ExecutiveStreamScreenState();
}

class _ExecutiveStreamScreenState extends State<ExecutiveStreamScreen> {
  final List<StreamDeliverable> _deliverables = [];
  bool _isProcessing = false;
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

  void _startNewSession() {
    setState(() {
      _deliverables.clear();
      _isProcessing = false;
    });
  }

  Future<void> _handleCapture(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    setState(() => _isProcessing = true);

    await Future.delayed(const Duration(milliseconds: 600));

    final lower = trimmed.toLowerCase();
    StreamDeliverable deliverable;

    if (lower.contains('remind') ||
        lower.contains('doctor') ||
        lower.contains('meeting') ||
        lower.contains('alarm') ||
        lower.contains('call') ||
        lower.contains('মনে')) {
      deliverable = StreamDeliverable(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: ChatMessageType.memoryReminder,
        text: trimmed,
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
        lower.contains('report') ||
        lower.contains('ডকুমেন্ট')) {
      deliverable = StreamDeliverable(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: ChatMessageType.documentNote,
        text: trimmed,
        document: DocumentPayload(
          title: 'Document: ${trimmed.length > 25 ? trimmed.substring(0, 25) : trimmed}',
          category: 'Notes & Documentation',
          summary: 'Executive document auto-generated from prompt input.',
          bulletPoints: const [
            'Full text structured and indexed in your encrypted vault',
            'Ready for instant PDF or markdown export',
            'Key deliverables extracted and timestamped',
          ],
          tags: const ['Executive Note', 'Auto-Saved'],
        ),
        timestamp: DateTime.now(),
      );
    } else {
      deliverable = StreamDeliverable(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: ChatMessageType.text,
        text: trimmed,
        timestamp: DateTime.now(),
      );
    }

    if (mounted) {
      setState(() {
        _deliverables.add(deliverable);
        _isProcessing = false;
      });
      _scrollToBottom();
    }
  }

  void _openVoice() {
    VoiceListeningOverlay.show(
      context: context,
      onSpeechFinished: (recognizedText) {
        if (recognizedText.trim().isNotEmpty) {
          _handleCapture(recognizedText);
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
                'Upload to Pingo Studio',
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
                      _handleCapture('Uploaded PDF: Project Roadmap & Agreement');
                    },
                  ),
                  _uploadOption(
                    icon: Icons.document_scanner_rounded,
                    label: 'Scan (OCR)',
                    color: const Color(0xFF00A884),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _handleCapture('Scanned document: Receipt & Expense Memo');
                    },
                  ),
                  _uploadOption(
                    icon: Icons.image_rounded,
                    label: 'Photo / Media',
                    color: const Color(0xFFE11D48),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _handleCapture('Captured whiteboard brainstorm diagram');
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
          'Pingo Studio',
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
              Icons.add_box_outlined,
              color: AppColors.brandPrimary,
              size: 22,
            ),
            tooltip: 'New Session',
            onPressed: _startNewSession,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Body: Empty Pristine Studio vs Action Stream Deliverables
            Expanded(
              child: _deliverables.isEmpty
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
                              'Memory & Document Studio',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w600,
                                color: titleColor,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Speak or type to create reminders, notes, and documents',
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
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _deliverables.length,
                      itemBuilder: (context, index) {
                        final item = _deliverables[index];

                        if (item.type == ChatMessageType.memoryReminder && item.reminder != null) {
                          return ExecutiveReminderCard(
                            reminder: item.reminder!,
                            onEdit: () {
                              EditReminderScreen.show(
                                context: context,
                                initialItem: item.reminder,
                                onSave: (updated) {
                                  _handleCapture('Updated reminder: ${updated.title}');
                                },
                              );
                            },
                          );
                        } else if (item.type == ChatMessageType.documentNote && item.document != null) {
                          return ExecutiveDocumentCard(
                            document: item.document!,
                            onViewDoc: () => DocumentsVaultSheet.show(context),
                          );
                        } else {
                          return ExecutiveThoughtCard(
                            text: item.text,
                            timestamp: item.timestamp,
                          );
                        }
                      },
                    ),
            ),

            // Processing Indicator
            if (_isProcessing) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                        Text('Processing deliverable...', style: TextStyle(fontSize: 12.5, color: Colors.grey)),
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

            // Sleek Capture Dock (No text, pure upload icon + borderless input + voice/send)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: SleekInputDock(
                onSubmitText: _handleCapture,
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
