import 'package:flutter/material.dart';

/// WhatsApp-style minimalist dark doodle background (.pingo-doodle-dark).
/// Features a base #0B141A tone, radial emerald glow at top center,
/// and a seamless 240x240 doodle pattern depicting privacy locks, clock reminders,
/// neural AI nodes, document notes, audio waves, and verification marks.
class TechCanvasBackground extends StatelessWidget {
  final Widget child;

  const TechCanvasBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Base tone from user CSS: #0B141A (dark) or #EFEAE2 (light)
    final baseBg = isDark ? const Color(0xFF0B141A) : const Color(0xFFEFEAE2);

    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Base Wallpaper Fill
          ColoredBox(color: baseBg),

          // 2. Vector Seamless Doodle Canvas with Radial Emerald Glow
          Positioned.fill(
            child: CustomPaint(
              painter: _PingoDoodlePainter(isDark: isDark),
            ),
          ),

          // 3. Foreground Application Content with Guaranteed Bounded Layout
          Positioned.fill(
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Painter rendering the 240x240 vector SVG doodle pattern tiled across the canvas.
class _PingoDoodlePainter extends CustomPainter {
  final bool isDark;

  _PingoDoodlePainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // --- 1. Radial Emerald Glow at (50% 0%) ---
    // CSS: radial-gradient(circle at 50% 0%, rgba(16, 185, 129, 0.05) 0%, transparent 65%)
    final radialPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, -1.0),
        radius: 0.95,
        colors: [
          const Color(0xFF10B981).withValues(alpha: isDark ? 0.055 : 0.045),
          Colors.transparent,
        ],
        stops: const [0.0, 0.65],
      ).createShader(rect);

    canvas.drawRect(rect, radialPaint);

    // --- 2. Doodle Paint Styles ---
    // Slate icons: stroke #94A3B8, opacity 0.065, strokeWidth 1.4
    final slateColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final slatePaint = Paint()
      ..color = slateColor.withValues(alpha: isDark ? 0.065 : 0.08)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final slateFillPaint = Paint()
      ..color = slateColor.withValues(alpha: isDark ? 0.065 : 0.08)
      ..style = PaintingStyle.fill;

    // Emerald accent: stroke #10B981, opacity 0.07, strokeWidth 1.4
    final emeraldColor = const Color(0xFF10B981);
    final emeraldPaint = Paint()
      ..color = emeraldColor.withValues(alpha: isDark ? 0.07 : 0.09)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Faint grid dots and crosshairs: stroke #94A3B8, opacity 0.045, strokeWidth 1.4
    final faintPaint = Paint()
      ..color = slateColor.withValues(alpha: isDark ? 0.045 : 0.06)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final faintFillPaint = Paint()
      ..color = slateColor.withValues(alpha: isDark ? 0.045 : 0.06)
      ..style = PaintingStyle.fill;

    // --- 3. Seamless 240x240 Tiled Grid Drawing ---
    const tileSize = 240.0;
    final cols = (size.width / tileSize).ceil() + 1;
    final rows = (size.height / tileSize).ceil() + 1;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final ox = c * tileSize;
        final oy = r * tileSize;
        _drawDoodleTile(
          canvas,
          ox,
          oy,
          slatePaint,
          slateFillPaint,
          emeraldPaint,
          faintPaint,
          faintFillPaint,
        );
      }
    }
  }

  void _drawDoodleTile(
    Canvas canvas,
    double ox,
    double oy,
    Paint slatePaint,
    Paint slateFill,
    Paint emeraldPaint,
    Paint faintPaint,
    Paint faintFill,
  ) {
    // ----------------------------------------------------
    // Group 1: Slate Tone (#94A3B8, opacity 0.065)
    // ----------------------------------------------------

    // 1. Padlock (Privacy / AES-256 Vault)
    // <rect x='22' y='30' width='18' height='14' rx='3.5'/>
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(ox + 22, oy + 30, 18, 14),
        const Radius.circular(3.5),
      ),
      slatePaint,
    );
    // <path d='M26 30v-4.5a5 5 0 0 1 10 0V30'/>
    final shackle = Path()
      ..moveTo(ox + 26, oy + 30)
      ..lineTo(ox + 26, oy + 25.5)
      ..arcToPoint(
        Offset(ox + 36, oy + 25.5),
        radius: const Radius.circular(5),
      )
      ..lineTo(ox + 36, oy + 30);
    canvas.drawPath(shackle, slatePaint);
    // <circle cx='31' cy='37' r='1.2'/>
    canvas.drawCircle(Offset(ox + 31, oy + 37), 1.2, slateFill);

    // 2. Clock Reminder (Alarms / Punctuality)
    // <circle cx='184' cy='34' r='12'/>
    canvas.drawCircle(Offset(ox + 184, oy + 34), 12, slatePaint);
    // <path d='M184 27.5V34l4.5 2.5'/>
    final clockHands = Path()
      ..moveTo(ox + 184, oy + 27.5)
      ..lineTo(ox + 184, oy + 34)
      ..lineTo(ox + 188.5, oy + 36.5);
    canvas.drawPath(clockHands, slatePaint);

    // 3. AI Neural Network Nodes & Synapses
    // <circle cx='106' cy='106' r='3.2'/>
    canvas.drawCircle(Offset(ox + 106, oy + 106), 3.2, slateFill);
    // <circle cx='126' cy='95' r='2.5'/>
    canvas.drawCircle(Offset(ox + 126, oy + 95), 2.5, slateFill);
    // <circle cx='126' cy='117' r='2.5'/>
    canvas.drawCircle(Offset(ox + 126, oy + 117), 2.5, slateFill);
    // <path d='M109 104.5l14.5-8M109 107.5l14.5 8M92 106h11'/>
    canvas.drawLine(Offset(ox + 109, oy + 104.5), Offset(ox + 123.5, oy + 96.5), slatePaint);
    canvas.drawLine(Offset(ox + 109, oy + 107.5), Offset(ox + 123.5, oy + 115.5), slatePaint);
    canvas.drawLine(Offset(ox + 92, oy + 106), Offset(ox + 103, oy + 106), slatePaint);

    // 4. Document / Task Card
    // <rect x='178' y='92' width='20' height='24' rx='3.5'/>
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(ox + 178, oy + 92, 20, 24),
        const Radius.circular(3.5),
      ),
      slatePaint,
    );
    // <path d='M183 99h10M183 104h10M183 109h6'/>
    canvas.drawLine(Offset(ox + 183, oy + 99), Offset(ox + 193, oy + 99), slatePaint);
    canvas.drawLine(Offset(ox + 183, oy + 104), Offset(ox + 193, oy + 104), slatePaint);
    canvas.drawLine(Offset(ox + 183, oy + 109), Offset(ox + 189, oy + 109), slatePaint);

    // 5. Microphone (Hold-to-speak voice capture)
    // <rect x='182' y='166' width='9' height='15' rx='4.5'/>
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(ox + 182, oy + 166, 9, 15),
        const Radius.circular(4.5),
      ),
      slatePaint,
    );
    // <path d='M177.5 176a9 9 0 0 0 18 0M186.5 185v5.5M182 190.5h9'/>
    final micCup = Path()
      ..moveTo(ox + 177.5, oy + 176)
      ..arcToPoint(
        Offset(ox + 195.5, oy + 176),
        radius: const Radius.circular(9),
      );
    canvas.drawPath(micCup, slatePaint);
    canvas.drawLine(Offset(ox + 186.5, oy + 185), Offset(ox + 186.5, oy + 190.5), slatePaint);
    canvas.drawLine(Offset(ox + 182, oy + 190.5), Offset(ox + 191, oy + 190.5), slatePaint);

    // ----------------------------------------------------
    // Group 2: Emerald Accent Tone (#10B981, opacity 0.07)
    // ----------------------------------------------------

    // 6. Security Shield with Verification Check
    // <path d='M106 20l12 4.5v8.5c0 7.5-5 13-12 16-7-3-12-8.5-12-16v-8.5L106 20z'/>
    final shield = Path()
      ..moveTo(ox + 106, oy + 20)
      ..lineTo(ox + 118, oy + 24.5)
      ..lineTo(ox + 118, oy + 33)
      ..cubicTo(ox + 118, oy + 40.5, ox + 113, oy + 46, ox + 106, oy + 49)
      ..cubicTo(ox + 99, oy + 46, ox + 94, oy + 40.5, ox + 94, oy + 33)
      ..lineTo(ox + 94, oy + 24.5)
      ..close();
    canvas.drawPath(shield, emeraldPaint);

    // <path d='M102 33.5l3 3 5.5-5.5'/>
    final shieldCheck = Path()
      ..moveTo(ox + 102, oy + 33.5)
      ..lineTo(ox + 105, oy + 36.5)
      ..lineTo(ox + 110.5, oy + 31);
    canvas.drawPath(shieldCheck, emeraldPaint);

    // 7. Audio Waveform (Discrete Voice Streams)
    // <path d='M22 104v8M27.5 98v20M33 93v30M38.5 99v18M44 104v8'/>
    canvas.drawLine(Offset(ox + 22, oy + 104), Offset(ox + 22, oy + 112), emeraldPaint);
    canvas.drawLine(Offset(ox + 27.5, oy + 98), Offset(ox + 27.5, oy + 118), emeraldPaint);
    canvas.drawLine(Offset(ox + 33, oy + 93), Offset(ox + 33, oy + 123), emeraldPaint);
    canvas.drawLine(Offset(ox + 38.5, oy + 99), Offset(ox + 38.5, oy + 117), emeraldPaint);
    canvas.drawLine(Offset(ox + 44, oy + 104), Offset(ox + 44, oy + 112), emeraldPaint);

    // 8. Sparkle / Intelligence Star
    // <path d='M34 170l2.8 7.2L44 180l-7.2 2.8L34 190l-2.8-7.2L24 180l7.2-2.8z'/>
    final spark = Path()
      ..moveTo(ox + 34, oy + 170)
      ..lineTo(ox + 36.8, oy + 177.2)
      ..lineTo(ox + 44, oy + 180)
      ..lineTo(ox + 36.8, oy + 182.8)
      ..lineTo(ox + 34, oy + 190)
      ..lineTo(ox + 31.2, oy + 182.8)
      ..lineTo(ox + 24, oy + 180)
      ..lineTo(ox + 31.2, oy + 177.2)
      ..close();
    canvas.drawPath(spark, emeraldPaint);

    // 9. Completed Task Check Circle (Zero False Alarms)
    // <circle cx='106' cy='180' r='11'/>
    canvas.drawCircle(Offset(ox + 106, oy + 180), 11, emeraldPaint);
    // <path d='M101 180l3.5 3.5 7-7'/>
    final checkCircle = Path()
      ..moveTo(ox + 101, oy + 180)
      ..lineTo(ox + 104.5, oy + 183.5)
      ..lineTo(ox + 111.5, oy + 176.5);
    canvas.drawPath(checkCircle, emeraldPaint);

    // ----------------------------------------------------
    // Group 3: Faint Grid Dots & Crosshairs (opacity 0.045)
    // ----------------------------------------------------

    // Accent Dots
    // <circle cx='68' cy='66' r='1.6'/><circle cx='148' cy='66' r='1.6'/>
    // <circle cx='68' cy='144' r='1.6'/><circle cx='148' cy='144' r='1.6'/>
    canvas.drawCircle(Offset(ox + 68, oy + 66), 1.6, faintFill);
    canvas.drawCircle(Offset(ox + 148, oy + 66), 1.6, faintFill);
    canvas.drawCircle(Offset(ox + 68, oy + 144), 1.6, faintFill);
    canvas.drawCircle(Offset(ox + 148, oy + 144), 1.6, faintFill);

    // Grid Crosshairs
    // <path d='M64 218h9M144 218h9M216 64v9M216 144v9'/>
    canvas.drawLine(Offset(ox + 64, oy + 218), Offset(ox + 73, oy + 218), faintPaint);
    canvas.drawLine(Offset(ox + 144, oy + 218), Offset(ox + 153, oy + 218), faintPaint);
    canvas.drawLine(Offset(ox + 216, oy + 64), Offset(ox + 216, oy + 73), faintPaint);
    canvas.drawLine(Offset(ox + 216, oy + 144), Offset(ox + 216, oy + 153), faintPaint);
  }

  @override
  bool shouldRepaint(covariant _PingoDoodlePainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}
