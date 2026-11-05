import 'package:flutter/material.dart';
import 'package:pingo_mobile/core/constants/app_constants.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';
import 'package:pingo_mobile/core/typography/app_typography.dart';

/// Central Ambient AI Voice Orb that pulses smoothly and invites interaction.
class AmbientVoiceOrb extends StatefulWidget {
  final VoidCallback onTap;

  const AmbientVoiceOrb({
    super.key,
    required this.onTap,
  });

  @override
  State<AmbientVoiceOrb> createState() => _AmbientVoiceOrbState();
}

class _AmbientVoiceOrbState extends State<AmbientVoiceOrb>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 1.0 + (_controller.value * 0.06);
        final glowRadius = 24.0 + (_controller.value * 16.0);

        return GestureDetector(
          onTap: widget.onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: scale,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF6366F1), // Electric Indigo
                        Color(0xFF3B82F6), // Sky Blue
                        Color(0xFF06B6D4), // Cyan Accent
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brandPrimary.withValues(alpha: 0.4),
                        blurRadius: glowRadius,
                        spreadRadius: 4,
                      ),
                      BoxShadow(
                        color: AppColors.brandSecondary.withValues(alpha: 0.25),
                        blurRadius: glowRadius * 1.5,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.mic_rounded,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.spacing16),
              Text(
                'ট্যাপ করে মুখে বলুন বা লিখুন',
                style: AppTypography.titleMedium(
                  color: AppColors.brandPrimary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

