import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pingo_mobile/core/constants/app_constants.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';
import 'package:pingo_mobile/core/typography/app_typography.dart';

/// Top greeting header with human-centric time-of-day greeting and date badge.
class GreetingHeader extends StatelessWidget {
  final String userName;
  final VoidCallback? onSettingsTap;

  const GreetingHeader({
    super.key,
    this.userName = 'ইশতিয়াক',
    this.onSettingsTap,
  });

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'শুভ সকাল';
    } else if (hour >= 12 && hour < 15) {
      return 'শুভ দুপুর';
    } else if (hour >= 15 && hour < 18) {
      return 'শুভ বিকেল';
    } else if (hour >= 18 && hour < 22) {
      return 'শুভ সন্ধ্যা';
    } else {
      return 'শুভ রাত্রি';
    }
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    return DateFormat('EEEE, d MMMM', 'bn_BD').format(now);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacing20,
        vertical: AppConstants.spacing16,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getFormattedDate(),
                  style: AppTypography.labelMedium(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: AppConstants.spacing4),
                Text(
                  '${_getTimeGreeting()}, $userName 👋',
                  style: AppTypography.headlineMedium(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onSettingsTap,
            borderRadius: BorderRadius.circular(AppConstants.radiusFull),
            child: Container(
              padding: const EdgeInsets.all(AppConstants.spacing12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Icon(
                Icons.settings_outlined,
                size: 20,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

