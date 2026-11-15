import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';
import 'package:pingo_mobile/core/typography/app_typography.dart';

/// Architectural Minimalist Masthead with editorial typography, live date, and system status.
class GreetingHeader extends StatelessWidget {
  final String userName;
  final VoidCallback? onSettingsTap;

  const GreetingHeader({
    super.key,
    this.userName = 'ইশতিয়াক',
    this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final formattedDate = DateFormat('EEE, d MMM').format(now).toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                  const SizedBox(width: 8),
                  Text(
                    'PINGO • EXECUTIVE SYSTEM',
                    style: AppTypography.monoLabel(
                      color: AppColors.paperSubtle,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'PINGO.',
                style: AppTypography.masthead(color: AppColors.paperWhite),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.inkSurface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.inkBorder, width: 1),
                ),
                child: Text(
                  formattedDate,
                  style: AppTypography.monoLabel(
                    color: AppColors.paperMuted,
                    fontSize: 11,
                  ),
                ),
              ),
              if (onSettingsTap != null) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: onSettingsTap,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.inkSurface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.inkBorder, width: 1),
                    ),
                    child: Text(
                      'SETTINGS',
                      style: AppTypography.monoLabel(
                        color: AppColors.paperWhite,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
