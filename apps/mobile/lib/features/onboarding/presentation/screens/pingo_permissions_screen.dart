import 'package:flutter/material.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';
import 'package:pingo_mobile/features/home/presentation/screens/pingo_home_screen.dart';

/// Screen implementing '8. Permissions.png'.
class PingoPermissionsScreen extends StatefulWidget {
  const PingoPermissionsScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PingoPermissionsScreen()),
    );
  }

  @override
  State<PingoPermissionsScreen> createState() => _PingoPermissionsScreenState();
}

class _PingoPermissionsScreenState extends State<PingoPermissionsScreen> {
  bool _notifAllowed = true;
  bool _micAllowed = true;
  bool _bgOpened = false;

  void _finish() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PingoHomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.pingoBackground;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.pingoSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.pingoBorder;
    final textColor = isDark ? Colors.white : AppColors.pingoDark;
    final mutedColor = isDark ? AppColors.darkTextSecondary : AppColors.pingoMuted;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Dots indicator & Skip Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFD1D5DB),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFD1D5DB),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 24,
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: AppColors.pingoPurple,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _finish,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: mutedColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Text(
                'Let Pingo remind you\non time',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Three quick permissions, so no reminder is ever missed.',
                style: TextStyle(fontSize: 15.5, color: mutedColor, height: 1.35),
              ),

              const SizedBox(height: 28),

              // Permission 1: Notifications
              _permissionCard(
                icon: Icons.notifications_none_rounded,
                title: 'Notifications',
                description: 'To alert you at the right moment',
                actionLabel: _notifAllowed ? 'Allowed' : 'Allow',
                isAllowed: _notifAllowed,
                onTap: () => setState(() => _notifAllowed = !_notifAllowed),
                cardBg: cardBg,
                borderColor: borderColor,
                textColor: textColor,
                mutedColor: mutedColor,
              ),

              const SizedBox(height: 14),

              // Permission 2: Microphone
              _permissionCard(
                icon: Icons.mic_none_rounded,
                title: 'Microphone',
                description: 'So you can say reminders aloud',
                actionLabel: _micAllowed ? 'Allowed' : 'Allow',
                isAllowed: _micAllowed,
                onTap: () => setState(() => _micAllowed = !_micAllowed),
                cardBg: cardBg,
                borderColor: borderColor,
                textColor: textColor,
                mutedColor: mutedColor,
              ),

              const SizedBox(height: 14),

              // Permission 3: Keep running in background
              _permissionCard(
                icon: Icons.phone_android_rounded,
                title: 'Keep running in\nbackground',
                description: 'Stops your phone from silencing reminders',
                actionLabel: _bgOpened ? 'Done' : 'Open',
                isAllowed: _bgOpened,
                onTap: () => setState(() => _bgOpened = !_bgOpened),
                cardBg: cardBg,
                borderColor: borderColor,
                textColor: textColor,
                mutedColor: mutedColor,
              ),

              const Spacer(),

              // Continue Button
              InkWell(
                onTap: _finish,
                borderRadius: BorderRadius.circular(26),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    color: AppColors.pingoPurple,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.pingoPurple.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Center(
                child: Text(
                  'You can change these anytime in Settings.',
                  style: TextStyle(fontSize: 13, color: mutedColor),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _permissionCard({
    required IconData icon,
    required String title,
    required String description,
    required String actionLabel,
    required bool isAllowed,
    required VoidCallback onTap,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color mutedColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFEDEBFD),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.pingoPurple, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(fontSize: 13, color: mutedColor),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: isAllowed
                    ? (actionLabel == 'Open' ? const Color(0xFFEDEBFD) : AppColors.pingoPurple)
                    : const Color(0xFFEDEBFD),
              ),
              child: Text(
                actionLabel,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: isAllowed
                      ? (actionLabel == 'Open' ? AppColors.pingoPurple : Colors.white)
                      : AppColors.pingoPurple,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

