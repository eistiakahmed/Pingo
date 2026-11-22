import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Quiet horological ledger canvas background.
/// Uses the single Ink neutral ramp (#0B0D14) with a subtle 240x240 monochrome
/// technical motif (locks, clock dials, document slips, audio bars, and grid ticks).
/// No radial color washes, no neon emerald strokes, and no AI sparkle icons.
class TechCanvasBackground extends StatelessWidget {
  final Widget child;

  const TechCanvasBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: AppColors.inkBlack),
          Positioned.fill(
            child: CustomPaint(
              painter: _PingoLedgerPainter(),
            ),
          ),
          Positioned.fill(
            child: child,
          ),
        ],
      ),
    );
  }
}

class _PingoLedgerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = AppColors.paperWhite.withValues(alpha: 0.035)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = AppColors.paperWhite.withValues(alpha: 0.035)
      ..style = PaintingStyle.fill;

    final gridPaint = Paint()
      ..color = AppColors.paperWhite.withValues(alpha: 0.025)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const double tileSize = 240.0;
    final int cols = (size.width / tileSize).ceil() + 1;
    final int rows = (size.height / tileSize).ceil() + 1;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        _drawTile(
          canvas,
          c * tileSize,
          r * tileSize,
          linePaint,
          fillPaint,
          gridPaint,
        );
      }
    }
  }

  void _drawTile(
    Canvas canvas,
    double ox,
    double oy,
    Paint linePaint,
    Paint fillPaint,
    Paint gridPaint,
  ) {
    // 1. Privacy Padlock
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(ox + 22, oy + 30, 18, 14),
        const Radius.circular(3.5),
      ),
      linePaint,
    );
    final lockShackle = Path()
      ..moveTo(ox + 26, oy + 30)
      ..lineTo(ox + 26, oy + 25.5)
      ..arcToPoint(
        Offset(ox + 36, oy + 25.5),
        radius: const Radius.circular(5),
        clockwise: true,
      )
      ..lineTo(ox + 36, oy + 30);
    canvas.drawPath(lockShackle, linePaint);
    canvas.drawCircle(Offset(ox + 31, oy + 37), 1.2, fillPaint);

    // 2. Clock Dial
    canvas.drawCircle(Offset(ox + 184, oy + 34), 12, linePaint);
    final clockHand = Path()
      ..moveTo(ox + 184, oy + 27.5)
      ..lineTo(ox + 184, oy + 34)
      ..lineTo(ox + 188.5, oy + 36.5);
    canvas.drawPath(clockHand, linePaint);

    // 3. Document Note Slip
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(ox + 178, oy + 92, 20, 24),
        const Radius.circular(3.5),
      ),
      linePaint,
    );
    canvas.drawLine(Offset(ox + 183, oy + 99), Offset(ox + 193, oy + 99), linePaint);
    canvas.drawLine(Offset(ox + 183, oy + 104), Offset(ox + 193, oy + 104), linePaint);
    canvas.drawLine(Offset(ox + 183, oy + 109), Offset(ox + 189, oy + 109), linePaint);

    // 4. Microphone Capsule
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(ox + 182, oy + 166, 9, 15),
        const Radius.circular(4.5),
      ),
      linePaint,
    );
    final micArc = Path()
      ..moveTo(ox + 177.5, oy + 176)
      ..arcToPoint(
        Offset(ox + 195.5, oy + 176),
        radius: const Radius.circular(9),
        clockwise: false,
      );
    canvas.drawPath(micArc, linePaint);
    canvas.drawLine(Offset(ox + 186.5, oy + 185), Offset(ox + 186.5, oy + 190.5), linePaint);
    canvas.drawLine(Offset(ox + 182, oy + 190.5), Offset(ox + 191, oy + 190.5), linePaint);

    // 5. Audio Waveform Bars
    canvas.drawLine(Offset(ox + 22, oy + 104), Offset(ox + 22, oy + 112), linePaint);
    canvas.drawLine(Offset(ox + 27.5, oy + 98), Offset(ox + 27.5, oy + 118), linePaint);
    canvas.drawLine(Offset(ox + 33, oy + 93), Offset(ox + 33, oy + 123), linePaint);
    canvas.drawLine(Offset(ox + 38.5, oy + 99), Offset(ox + 38.5, oy + 117), linePaint);
    canvas.drawLine(Offset(ox + 44, oy + 104), Offset(ox + 44, oy + 112), linePaint);

    // 6. Verified Check Dial
    canvas.drawCircle(Offset(ox + 106, oy + 180), 11, linePaint);
    final checkCircle = Path()
      ..moveTo(ox + 101, oy + 180)
      ..lineTo(ox + 104.5, oy + 183.5)
      ..lineTo(ox + 111.5, oy + 176.5);
    canvas.drawPath(checkCircle, linePaint);

    // 7. Ledger Crosshairs
    canvas.drawLine(Offset(ox + 64, oy + 218), Offset(ox + 72, oy + 218), gridPaint);
    canvas.drawLine(Offset(ox + 144, oy + 218), Offset(ox + 152, oy + 218), gridPaint);
    canvas.drawLine(Offset(ox + 216, oy + 64), Offset(ox + 216, oy + 72), gridPaint);
    canvas.drawLine(Offset(ox + 216, oy + 144), Offset(ox + 216, oy + 152), gridPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
