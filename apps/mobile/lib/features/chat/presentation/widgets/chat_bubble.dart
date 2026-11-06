import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pingo_mobile/core/constants/app_constants.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';
import 'package:pingo_mobile/core/typography/app_typography.dart';
import '../../domain/chat_message.dart';
import 'memory_capsule_widget.dart';
import 'document_card_widget.dart';

/// Conversational message bubble with support for text, memory capsules, and document notes.
class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onEditReminder;

  const ChatBubble({
    super.key,
    required this.message,
    this.onEditReminder,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == ChatMessageSender.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeStr = DateFormat('hh:mm a').format(message.timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacing16,
        vertical: AppConstants.spacing8,
      ),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pingo Avatar for AI responses
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8, top: 4),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.brandPrimary, AppColors.brandSecondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🔔', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],

          // Bubble Container
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.78,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser
                        ? AppColors.brandPrimary
                        : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(AppConstants.radiusMedium),
                      topRight: const Radius.circular(AppConstants.radiusMedium),
                      bottomLeft: Radius.circular(isUser ? AppConstants.radiusMedium : 4),
                      bottomRight: Radius.circular(isUser ? 4 : AppConstants.radiusMedium),
                    ),
                    border: isUser
                        ? null
                        : Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.text,
                        style: AppTypography.bodyMedium(
                          color: isUser
                              ? Colors.white
                              : (isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          timeStr,
                          style: AppTypography.labelSmall(
                            color: isUser
                                ? Colors.white.withValues(alpha: 0.7)
                                : (isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.lightTextMuted),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Attached Memory Capsule
                if (message.reminder != null)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.78,
                    ),
                    child: MemoryCapsuleWidget(
                      reminder: message.reminder!,
                      onEdit: onEditReminder,
                    ),
                  ),

                // Attached Document Note
                if (message.document != null)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.78,
                    ),
                    child: DocumentCardWidget(
                      document: message.document!,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

