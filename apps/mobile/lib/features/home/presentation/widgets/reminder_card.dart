import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pingo_mobile/core/constants/app_constants.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';
import 'package:pingo_mobile/core/typography/app_typography.dart';
import 'package:pingo_mobile/features/home/domain/reminder_item.dart';

/// Single reminder item card with 1-tap done, snooze options, and category pill.
class ReminderCard extends StatelessWidget {
  final ReminderItem reminder;
  final VoidCallback onToggleDone;
  final VoidCallback? onTap;
  final Function(Duration duration)? onSnooze;

  const ReminderCard({
    super.key,
    required this.reminder,
    required this.onToggleDone,
    this.onTap,
    this.onSnooze,
  });

  Color _getCategoryColor(ReminderCategory category) {
    switch (category) {
      case ReminderCategory.medicine:
        return AppColors.categoryMedicine;
      case ReminderCategory.bill:
        return AppColors.categoryBill;
      case ReminderCategory.work:
        return AppColors.categoryWork;
      case ReminderCategory.personal:
        return AppColors.categoryPersonal;
      case ReminderCategory.birthday:
        return AppColors.categoryBirthday;
      case ReminderCategory.other:
        return AppColors.brandSecondary;
    }
  }

  String _getCategoryLabel(ReminderCategory category) {
    switch (category) {
      case ReminderCategory.medicine:
        return 'ওষুধ';
      case ReminderCategory.bill:
        return 'বিল';
      case ReminderCategory.work:
        return 'অফিস';
      case ReminderCategory.personal:
        return 'ব্যক্তিগত';
      case ReminderCategory.birthday:
        return 'জন্মদিন';
      case ReminderCategory.other:
        return 'সাধারণ';
    }
  }

  String _formatTime(DateTime time) {
    return DateFormat('hh:mm a').format(time);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoryColor = _getCategoryColor(reminder.category);

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacing20,
        vertical: AppConstants.spacing8,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(
          color: reminder.isOverdue
              ? AppColors.overdue.withValues(alpha: 0.5)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacing16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Done checkbox trigger
            GestureDetector(
              onTap: onToggleDone,
              child: AnimatedContainer(
                duration: AppConstants.fastAnimation,
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: reminder.isDone
                      ? AppColors.success
                      : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: reminder.isDone
                        ? AppColors.success
                        : (isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted),
                    width: 2,
                  ),
                ),
                child: reminder.isDone
                    ? const Icon(Icons.check, size: 18, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: AppConstants.spacing12),

            // Main Info
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          reminder.title,
                          style: AppTypography.titleLarge().copyWith(
                            decoration: reminder.isDone
                                ? TextDecoration.lineThrough
                                : null,
                            color: reminder.isDone
                                ? (isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.lightTextMuted)
                                : (isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary),
                          ),
                        ),
                      ),
                      if (reminder.priority == ReminderPriority.important)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(
                            Icons.flag_rounded,
                            size: 18,
                            color: AppColors.warning,
                          ),
                        ),
                    ],
                  ),
                  if (reminder.notes != null && reminder.notes!.isNotEmpty) ...[
                    const SizedBox(height: AppConstants.spacing4),
                    Text(
                      reminder.notes!,
                      style: AppTypography.bodySmall(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: AppConstants.spacing12),

                  // Metadata Chips Row
                  Row(
                    children: [
                      // Time chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder.withValues(alpha: 0.5),
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusSmall),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 13,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatTime(reminder.dueAt),
                              style: AppTypography.labelSmall(
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Category chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: categoryColor.withValues(alpha: 0.12),
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusSmall),
                        ),
                        child: Text(
                          _getCategoryLabel(reminder.category),
                          style: AppTypography.labelSmall(
                            color: categoryColor,
                          ),
                        ),
                      ),

                      if (reminder.repeatRule != null) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.repeat_rounded,
                          size: 14,
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

            // Snooze quick action menu
            if (!reminder.isDone && onSnooze != null)
              PopupMenuButton<Duration>(
                icon: Icon(
                  Icons.snooze_rounded,
                  size: 20,
                  color: isDark
                      ? AppColors.darkTextMuted
                      : AppColors.lightTextMuted,
                ),
                tooltip: 'স্নুজ (Snooze)',
                onSelected: onSnooze,
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: Duration(minutes: 10),
                    child: Text('১০ মিনিট পরে'),
                  ),
                  const PopupMenuItem(
                    value: Duration(hours: 1),
                    child: Text('১ ঘণ্টা পরে'),
                  ),
                  const PopupMenuItem(
                    value: Duration(days: 1),
                    child: Text('আগামীকাল এই সময়ে'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

