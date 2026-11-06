import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/chat_message.dart';
import 'memory_capsule_widget.dart';
import 'document_card_widget.dart';

/// WhatsApp-style message bubble with inline rich memory & document cards.
class WhatsAppBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onReminderTap;

  const WhatsAppBubble({
    super.key,
    required this.message,
    this.onReminderTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == ChatMessageSender.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Classic WhatsApp bubble colors:
    // User bubble: WhatsApp soft green #E7FFDB (light) or #005C4B (dark)
    // Bot bubble: Pure white #FFFFFF (light) or #202C33 (dark)
    final bubbleColor = isUser
        ? (isDark ? const Color(0xFF005C4B) : const Color(0xFFE7FFDB))
        : (isDark ? const Color(0xFF202C33) : Colors.white);

    final textColor = isDark ? Colors.white : const Color(0xFF111B21);
    final timeColor = isDark ? const Color(0xFF8696A0) : const Color(0xFF667781);
    final timeStr = DateFormat('hh:mm a').format(message.timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.80,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: isUser ? const Radius.circular(12) : const Radius.circular(2),
                  bottomRight: isUser ? const Radius.circular(2) : const Radius.circular(12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Text message content
                  if (message.text.isNotEmpty) ...[
                    Text(
                      message.text,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15.2,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],

                  // Inline Reminder Capsule Card
                  if (message.type == ChatMessageType.memoryReminder && message.reminder != null) ...[
                    const SizedBox(height: 4),
                    MemoryCapsuleWidget(
                      reminder: message.reminder!,
                      onEdit: onReminderTap,
                    ),
                    const SizedBox(height: 4),
                  ],

                  // Inline Document Note Card
                  if (message.type == ChatMessageType.documentNote && message.document != null) ...[
                    const SizedBox(height: 4),
                    DocumentCardWidget(
                      document: message.document!,
                    ),
                    const SizedBox(height: 4),
                  ],

                  // Timestamp & Blue Read Checkmarks
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Spacer(),
                      Text(
                        timeStr,
                        style: TextStyle(
                          color: timeColor,
                          fontSize: 11,
                        ),
                      ),
                      if (isUser) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.done_all_rounded,
                          size: 16,
                          color: Color(0xFF53BDEB), // WhatsApp blue ticks
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
