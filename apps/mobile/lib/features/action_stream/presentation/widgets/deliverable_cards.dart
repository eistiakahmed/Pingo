import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';
import 'package:pingo_mobile/features/home/domain/reminder_item.dart';
import 'package:pingo_mobile/features/chat/domain/chat_message.dart';

/// Clean Executive Reminder Card for the non-chatbot Action Stream.
class ExecutiveReminderCard extends StatelessWidget {
  final ReminderItem reminder;
  final VoidCallback onEdit;

  const ExecutiveReminderCard({
    super.key,
    required this.reminder,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E242B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E3842) : const Color(0xFFE5E7EB);
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final subColor = isDark ? Colors.white60 : const Color(0xFF6B7280);
    final timeStr = DateFormat('EEE, MMM d • hh:mm a').format(reminder.dueAt);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Category Pill & Status Tag
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.alarm_on_rounded, size: 14, color: AppColors.brandPrimary),
                    SizedBox(width: 4),
                    Text(
                      'REMINDER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF28313A) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  reminder.category.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: subColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            reminder.title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: titleColor,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),

          // Time Details
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 15, color: AppColors.brandPrimary),
              const SizedBox(width: 6),
              Text(
                timeStr,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: subColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Action Buttons
          Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 14),
                label: const Text('Edit Time'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white70 : const Color(0xFF374151),
                  side: BorderSide(color: borderColor),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                onPressed: onEdit,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00A884).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.notifications_active_rounded, size: 13, color: Color(0xFF00A884)),
                    SizedBox(width: 4),
                    Text(
                      'Alarm Active',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF00A884),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Clean Executive Document Deliverable Card for the Action Stream.
class ExecutiveDocumentCard extends StatelessWidget {
  final DocumentPayload document;
  final VoidCallback onViewDoc;

  const ExecutiveDocumentCard({
    super.key,
    required this.document,
    required this.onViewDoc,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E242B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E3842) : const Color(0xFFE5E7EB);
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final bodyColor = isDark ? Colors.white70 : const Color(0xFF4B5563);
    final subColor = isDark ? Colors.white60 : const Color(0xFF6B7280);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Tag
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.description_rounded, size: 14, color: Color(0xFF4F46E5)),
                    SizedBox(width: 4),
                    Text(
                      'DOCUMENT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4F46E5),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                document.category,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: subColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            document.title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: titleColor,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),

          // Summary
          Text(
            document.summary,
            style: TextStyle(
              fontSize: 13.5,
              color: bodyColor,
              height: 1.35,
            ),
          ),

          // Bullet Points
          if (document.bulletPoints.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...document.bulletPoints.map(
              (point) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.brandPrimary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        point,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white70 : const Color(0xFF374151),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Action Chips
          Row(
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.open_in_new_rounded, size: 14),
                label: const Text('Open Document'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                onPressed: onViewDoc,
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.share_outlined, size: 14),
                label: const Text('Share'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white70 : const Color(0xFF374151),
                  side: BorderSide(color: borderColor),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Clean Executive Thought/Memory Note Card.
class ExecutiveThoughtCard extends StatelessWidget {
  final String text;
  final DateTime timestamp;

  const ExecutiveThoughtCard({
    super.key,
    required this.text,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E242B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E3842) : const Color(0xFFE5E7EB);
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final timeStr = DateFormat('hh:mm a').format(timestamp);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00A884).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.lightbulb_outline_rounded, size: 14, color: Color(0xFF00A884)),
                    SizedBox(width: 4),
                    Text(
                      'INDEXED TO VAULT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF00A884),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                timeStr,
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w500,
              color: titleColor,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
