import 'package:flutter/material.dart';
import 'package:pingo_mobile/core/constants/app_constants.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';
import 'package:pingo_mobile/core/typography/app_typography.dart';
import 'package:pingo_mobile/features/home/domain/reminder_item.dart';

/// Informative and non-shaming alert banner for overdue reminders.
class OverdueBanner extends StatelessWidget {
  final List<ReminderItem> overdueItems;
  final Function(String id)? onQuickResolve;

  const OverdueBanner({
    super.key,
    required this.overdueItems,
    this.onQuickResolve,
  });

  @override
  Widget build(BuildContext context) {
    if (overdueItems.isEmpty) return const SizedBox.shrink();

    final count = overdueItems.length;
    final firstItem = overdueItems.first;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacing20,
        vertical: AppConstants.spacing8,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spacing16),
        decoration: BoxDecoration(
          color: AppColors.overdue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          border: Border.all(
            color: AppColors.overdue.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppConstants.spacing8),
              decoration: BoxDecoration(
                color: AppColors.overdue.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.overdue,
                size: 22,
              ),
            ),
            const SizedBox(width: AppConstants.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count == 1
                        ? 'একটি কাজ সময় পার হয়েছে'
                        : '$count টি কাজ সময় পার হয়েছে',
                    style: AppTypography.titleMedium(
                      color: AppColors.overdue,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacing2),
                  Text(
                    firstItem.title,
                    style: AppTypography.bodySmall(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (onQuickResolve != null)
              TextButton(
                onPressed: () => onQuickResolve!(firstItem.id),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.overdue.withValues(alpha: 0.12),
                  foregroundColor: AppColors.overdue,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                  ),
                ),
                child: const Text('সম্পন্ন'),
              ),
          ],
        ),
      ),
    );
  }
}

