import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pingo_mobile/core/constants/app_constants.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';
import 'package:pingo_mobile/core/typography/app_typography.dart';
import 'package:pingo_mobile/features/home/domain/reminder_item.dart';

/// An inline conversational memory capsule displaying an active reminder.
class MemoryCapsuleWidget extends StatelessWidget {
  final ReminderItem reminder;
  final VoidCallback? onEdit;

  const MemoryCapsuleWidget({
    super.key,
    required this.reminder,
    this.onEdit,
  });

  String _formatDateTime(DateTime dt) {
    return DateFormat('EEEE, MMM d • hh:mm a').format(dt);
  }

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final catColor = _getCategoryColor(reminder.category);

    return Container(
      margin: const EdgeInsets.only(top: AppConstants.spacing8),
      padding: const EdgeInsets.all(AppConstants.spacing12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(
          color: AppColors.brandPrimary.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandPrimary.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.alarm_on_rounded,
                  size: 16,
                  color: AppColors.brandPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Active Memory (Scheduled)',
                style: AppTypography.labelSmall(color: AppColors.brandPrimary),
              ),
              const Spacer(),
              if (onEdit != null)
                InkWell(
                  onTap: onEdit,
                  borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      'Edit',
                      style: AppTypography.labelSmall(color: AppColors.brandSecondary),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppConstants.spacing8),
          Text(
            reminder.title,
            style: AppTypography.titleMedium(
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: AppConstants.spacing6),
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                _formatDateTime(reminder.dueAt),
                style: AppTypography.bodySmall(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                ),
                child: Text(
                  reminder.category.name.toUpperCase(),
                  style: AppTypography.labelSmall(color: catColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

