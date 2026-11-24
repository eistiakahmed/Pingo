import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';
import '../../domain/reminder_item.dart';

/// Shared category badge color helper for autonomous LLM-assigned categories.
Color categoryBadgeColor(ReminderCategory category) {
  switch (category) {
    case ReminderCategory.medicine:
      return AppColors.categoryMedicine;
    case ReminderCategory.bill:
      return AppColors.categoryBill;
    case ReminderCategory.work:
      return const Color(0xFF38BDF8);
    case ReminderCategory.personal:
      return AppColors.paperWhite;
    case ReminderCategory.birthday:
      return AppColors.categoryBirthday;
    case ReminderCategory.document:
      return const Color(0xFFA78BFA);
    case ReminderCategory.general:
      return AppColors.paperMuted;
  }
}

/// Reusable read-only task card displaying the autonomous LLM category badge
/// (`MEDICINE`, `BILL`, `WORK`, `PERSONAL`, `BIRTHDAY`, `DOCUMENT`, `GENERAL`)
/// and automated `Scheduled` / `Completed` lifecycle status.
class ReadOnlyTaskCard extends StatelessWidget {
  final ReminderItem item;

  const ReadOnlyTaskCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final badgeColor = categoryBadgeColor(item.category);
    final timeStr = DateFormat.jm().format(item.dueAt);
    final dateStr = DateFormat('d MMM').format(item.dueAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.inkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.inkBorder, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Automated Status Indicator Dot (Sage = Completed, Amber = Scheduled)
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: item.isDone ? AppColors.success : AppColors.signalAmber,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: item.isDone
                        ? AppColors.paperSubtle
                        : AppColors.paperWhite,
                    decoration:
                        item.isDone ? TextDecoration.lineThrough : null,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    // LLM-Classified Category Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: badgeColor.withValues(alpha: 0.38),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        item.category.badgeLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: badgeColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$timeStr · $dateStr',
                      style: const TextStyle(
                        fontSize: 12,
                        fontFeatures: [FontFeature.tabularFigures()],
                        color: AppColors.paperSubtle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            item.isDone ? 'Completed' : 'Scheduled',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: item.isDone ? AppColors.success : AppColors.paperMuted,
            ),
          ),
        ],
      ),
    );
  }
}
