import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';
import '../../domain/reminder_item.dart';

/// Shared category badge color helper for autonomous LLM-assigned categories.
/// Adapts contrast for Light and Dark Penguin themes.
Color categoryBadgeColor(ReminderCategory category, {bool isDark = true}) {
  switch (category) {
    case ReminderCategory.medicine:
      return isDark ? const Color(0xFFE5484D) : const Color(0xFFC93035);
    case ReminderCategory.bill:
      return isDark ? PenguinPalette.dark.accent : PenguinPalette.light.accent;
    case ReminderCategory.work:
      return isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
    case ReminderCategory.personal:
      return isDark
          ? PenguinPalette.dark.textPrimary
          : PenguinPalette.light.textPrimary;
    case ReminderCategory.birthday:
      return isDark ? PenguinPalette.dark.success : PenguinPalette.light.success;
    case ReminderCategory.document:
      return isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);
    case ReminderCategory.general:
      return isDark
          ? PenguinPalette.dark.textSecondary
          : PenguinPalette.light.textSecondary;
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
    final p = AppColors.of(context);
    final badgeColor = categoryBadgeColor(item.category, isDark: p.isDark);
    final timeStr = DateFormat.jm().format(item.dueAt);
    final dateStr = DateFormat('d MMM').format(item.dueAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Automated Status Indicator Dot (Success = Completed, Accent = Scheduled)
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: item.isDone ? p.success : p.accent,
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
                    color: item.isDone ? p.textMuted : p.textPrimary,
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
                        color: badgeColor.withValues(alpha: p.isDark ? 0.14 : 0.10),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: badgeColor.withValues(alpha: p.isDark ? 0.34 : 0.28),
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
                      style: TextStyle(
                        fontSize: 12,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: p.textMuted,
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
              color: item.isDone ? p.success : p.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
