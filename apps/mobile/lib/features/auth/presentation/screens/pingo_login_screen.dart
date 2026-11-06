import 'package:flutter/material.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';
import 'package:pingo_mobile/features/auth/presentation/screens/pingo_signup_screen.dart';
import 'package:pingo_mobile/features/home/presentation/screens/pingo_home_screen.dart';

/// Screen implementing '5. Log in.png'.
class PingoLoginScreen extends StatelessWidget {
  const PingoLoginScreen({super.key});

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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 36),

              // Bell Logo Icon in rounded square
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppColors.pingoPurple,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.pingoPurple.withValues(alpha: 0.3),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.notifications_rounded, color: Colors.white, size: 30),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Title & Subtitle
              Text(
                'Welcome back',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Log in to see your reminders on any phone.',
                style: TextStyle(
                  fontSize: 16,
                  color: mutedColor,
                ),
              ),

              const SizedBox(height: 32),

              // Phone or email input field
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD1D5DB), width: 1.2),
                ),
                child: const TextField(
                  decoration: InputDecoration(
                    hintText: 'Phone or email',
                    hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 15),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              Text(
                'We will send you a code. No password needed.',
                style: TextStyle(fontSize: 13, color: mutedColor),
              ),

              const SizedBox(height: 24),

              // Continue Button
              InkWell(
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const PingoHomeScreen()),
                  );
                },
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

              const SizedBox(height: 24),

              // 'or' Divider
              Row(
                children: [
                  Expanded(child: Divider(color: borderColor)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text('or', style: TextStyle(color: mutedColor, fontSize: 13)),
                  ),
                  Expanded(child: Divider(color: borderColor)),
                ],
              ),

              const SizedBox(height: 24),

              // Continue with Google Button
              InkWell(
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const PingoHomeScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(26),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: const Color(0xFFD1D5DB), width: 1.2),
                    color: cardBg,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Continue with Google',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // New to Pingo? Sign up
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('New to Pingo? ', style: TextStyle(fontSize: 14.5, color: mutedColor)),
                    InkWell(
                      onTap: () => PingoSignupScreen.open(context),
                      child: const Text(
                        'Sign up',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.pingoPurple,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Continue without an account
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const PingoHomeScreen()),
                    );
                  },
                  child: Text(
                    'Continue without an account',
                    style: TextStyle(
                      fontSize: 14,
                      color: mutedColor,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
