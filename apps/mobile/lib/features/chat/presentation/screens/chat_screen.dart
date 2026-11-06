import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pingo_mobile/core/constants/app_constants.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';
import 'package:pingo_mobile/core/typography/app_typography.dart';
import '../state/chat_provider.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_input_dock.dart';
import 'package:pingo_mobile/features/voice_capture/presentation/widgets/voice_listening_overlay.dart';
import 'package:pingo_mobile/features/reminder_editor/presentation/screens/edit_reminder_screen.dart';

/// The central Chat-First Screen of Pingo AI.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ScrollController _scrollController = ScrollController();

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: AppConstants.normalAnimation,
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _showAttachmentSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.radiusLarge)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppConstants.spacing24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ডকুমেন্টেশন ও ফাইল যুক্ত করুন', style: AppTypography.titleLarge()),
            const SizedBox(height: AppConstants.spacing16),
            ListTile(
              leading: const Icon(Icons.document_scanner_rounded, color: AppColors.brandPrimary),
              title: const Text('কাগজপত্র স্ক্যান করুন (OCR)'),
              subtitle: const Text('পাসপোর্ট, লাইসেন্স বা বিল থেকে তথ্য পড়ুন'),
              onTap: () {
                Navigator.of(ctx).pop();
                ref.read(chatProvider.notifier).sendUserMessage('আমার এই ডকুমেন্টটি স্ক্যান করে প্রয়োজনীয় ডেটগুলো সেভ রাখো');
              },
            ),
            ListTile(
              leading: const Icon(Icons.note_add_rounded, color: AppColors.info),
              title: const Text('নতুন ডকুমেন্ট নোট তৈরি করুন'),
              subtitle: const Text('মিটিং মিনিটস বা জরুরি সারসংক্ষেপ'),
              onTap: () {
                Navigator.of(ctx).pop();
                ref.read(chatProvider.notifier).sendUserMessage('একটি নতুন প্রজেক্ট ডকুমেন্ট তৈরি করো');
              },
            ),
            ListTile(
              leading: const Icon(Icons.image_rounded, color: AppColors.categoryMedicine),
              title: const Text('গ্যালারি বা প্রেসক্রিপশন আপলোড'),
              subtitle: const Text('ছবি থেকে স্বয়ংক্রিয় ওষুধ সূচি তৈরি'),
              onTap: () {
                Navigator.of(ctx).pop();
                ref.read(chatProvider.notifier).sendUserMessage('প্রেসক্রিপশন আপলোড করেছি, ওষুধের নিয়মগুলো লিখে দাও');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final notifier = ref.read(chatProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    _scrollToBottom();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            const SizedBox(width: AppConstants.spacing16),
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.brandPrimary, AppColors.brandSecondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🔔', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: AppConstants.spacing12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pingo AI',
                  style: AppTypography.titleLarge(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'স্মার্ট মেমোরি সক্রিয়',
                      style: AppTypography.labelSmall(
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _showAttachmentSheet,
            icon: const Icon(Icons.folder_shared_outlined),
            tooltip: 'মেমোরি ভল্ট ও ডকুমেন্টস',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Conversational Timeline
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: AppConstants.spacing12),
                itemCount: chatState.messages.length,
                itemBuilder: (context, index) {
                  final msg = chatState.messages[index];
                  return ChatBubble(
                    message: msg,
                    onEditReminder: msg.reminder == null
                        ? null
                        : () {
                            EditReminderScreen.show(
                              context: context,
                              initialItem: msg.reminder,
                              onSave: (saved) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('মেমোরি আপডেট সম্পন্ন: ${saved.title}'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              },
                            );
                          },
                  );
                },
              ),
            ),

            // Thinking Indicator (if AI is processing)
            if (chatState.isThinking)
              Padding(
                padding: const EdgeInsets.only(left: 24, bottom: 8),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'পিংগো মনে রাখছে ও লিখছে...',
                      style: AppTypography.bodySmall(
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ),

            // Conversational Dock
            ChatInputDock(
              onSendMessage: (text) => notifier.sendUserMessage(text),
              onAttachTap: _showAttachmentSheet,
              onMicTap: () {
                VoiceListeningOverlay.show(
                  context: context,
                  onSpeechFinished: (transcript) {
                    notifier.sendUserMessage(transcript);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
