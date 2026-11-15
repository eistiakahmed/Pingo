import 'dart:async';
import 'package:flutter/material.dart';

/// Cute animated penguin mascot widget displayed on onboarding / empty chat state.
/// Features a gentle breathing pulse animation, periodic eye blinks, and bilingual starter chips.
class PenguinMascotWidget extends StatefulWidget {
  final String language; // 'bn' or 'en'
  final ValueChanged<String> onPromptSelected;

  const PenguinMascotWidget({
    super.key,
    required this.language,
    required this.onPromptSelected,
  });

  @override
  State<PenguinMascotWidget> createState() => _PenguinMascotWidgetState();
}

class _PenguinMascotWidgetState extends State<PenguinMascotWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _blinkController;
  Timer? _blinkTimer;

  @override
  void initState() {
    super.initState();

    // 1. Gentle breathing pulse animation (2.4s easeInOut loop)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    // 2. Periodic natural eye blink animation
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _blinkTimer = Timer.periodic(const Duration(milliseconds: 3600), (_) {
      if (mounted) {
        _blinkController.forward().then((_) {
          if (mounted) _blinkController.reverse();
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _blinkController.dispose();
    _blinkTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isBangla = widget.language == 'bn';

    final greetingTitle = isBangla ? 'হাই, আমি পিঙ্গো!' : "Hi, I'm Pingo!";
    final greetingSubtitle = isBangla
        ? 'আপনার যা মনে রাখা প্রয়োজন, আমাকে বলুন বা লিখে জানান।'
        : 'Tell or text me what you need to remember.';

    final starterChips = isBangla
        ? [
            'রাত ৮টায় আম্মুকে ফোন দেওয়ার রিমাইন্ডার দাও',
            'আজকে আমার কী কী শিডিউল আছে?',
            'নোটিফিকেশন এলার্ট চেক করো',
            'কাল সকাল ১০টায় মিটিং',
          ]
        : [
            'Remind me to call Mom at 8 PM',
            "What's on my schedule today?",
            'Test instant alert',
            'Team sync tomorrow at 10 AM',
          ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 10),

            // Gentle Pulsing Mascot Container with Ambient Glow
            AnimatedBuilder(
              animation: Listenable.merge([_pulseController, _blinkController]),
              builder: (context, child) {
                final scale = 1.0 + (_pulseController.value * 0.04);
                final glowAlpha = 0.15 + (_pulseController.value * 0.12);

                return Transform.scale(
                  scale: scale,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Ambient Radial Glow
                      Container(
                        width: 170,
                        height: 170,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF38BDF8).withValues(alpha: glowAlpha),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                      ),

                      // Vector Penguin Canvas
                      CustomPaint(
                        size: const Size(130, 140),
                        painter: _PenguinPainter(blinkValue: _blinkController.value),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Mascot Greeting Title
            Text(
              greetingTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFFF8FAFC),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),

            // Conversational Subtitle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                greetingSubtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14.5,
                  color: Color(0xFF94A3B8),
                  height: 1.4,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),

            const SizedBox(height: 28),

            // Quick-Reply Inspiration Chips
            Wrap(
              spacing: 8,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: starterChips.map((chipText) {
                return InkWell(
                  onTap: () => widget.onPromptSelected(chipText),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131B2A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF1E293B), width: 1.1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 13,
                          color: Color(0xFF38BDF8),
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            chipText,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFFE2E8F0),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// Custom painter rendering Pingo the cute vector penguin.
class _PenguinPainter extends CustomPainter {
  final double blinkValue; // 0.0 = fully open, 1.0 = fully closed

  _PenguinPainter({required this.blinkValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 1. Little Orange Feet
    final footPaint = Paint()..color = const Color(0xFFF59E0B);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx - 22, size.height - 8),
        width: 26,
        height: 14,
      ),
      footPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx + 22, size.height - 8),
        width: 26,
        height: 14,
      ),
      footPaint,
    );

    // 2. Glossy Penguin Body (Deep Obsidian/Navy)
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + 2),
        width: size.width - 24,
        height: size.height - 20,
      ),
      const Radius.circular(52),
    );
    canvas.drawRRect(bodyRect, bodyPaint);

    // 3. Cute Flippers (Left & Right Wings)
    final flipperPaint = Paint()..color = const Color(0xFF1E293B);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx - 48, center.dy + 12), width: 14, height: 42),
      flipperPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx + 48, center.dy + 12), width: 14, height: 42),
      flipperPaint,
    );

    // 4. Soft Snowy Belly
    final bellyPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFFFFF), Color(0xFFF1F5F9)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + 16),
        width: 62,
        height: 68,
      ),
      bellyPaint,
    );

    // 5. Expressive Blinking Eyes
    final eyeY = center.dy - 18;
    final eyeHeight = (1.0 - blinkValue).clamp(0.08, 1.0) * 11.0;

    final eyePaint = Paint()..color = const Color(0xFF0F172A);
    final catchlightPaint = Paint()..color = Colors.white;

    // Left Eye
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx - 15, eyeY), width: 10, height: eyeHeight),
      eyePaint,
    );
    if (blinkValue < 0.6) {
      canvas.drawCircle(Offset(center.dx - 13.5, eyeY - 2.5), 2.2, catchlightPaint);
    }

    // Right Eye
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx + 15, eyeY), width: 10, height: eyeHeight),
      eyePaint,
    );
    if (blinkValue < 0.6) {
      canvas.drawCircle(Offset(center.dx + 16.5, eyeY - 2.5), 2.2, catchlightPaint);
    }

    // 6. Cute Warm Amber Beak
    final beakPath = Path()
      ..moveTo(center.dx - 9, eyeY + 6)
      ..lineTo(center.dx + 9, eyeY + 6)
      ..lineTo(center.dx, eyeY + 17)
      ..close();

    final beakPaint = Paint()..color = const Color(0xFFF59E0B);
    canvas.drawPath(beakPath, beakPaint);
  }

  @override
  bool shouldRepaint(covariant _PenguinPainter oldDelegate) {
    return oldDelegate.blinkValue != blinkValue;
  }
}
