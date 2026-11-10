import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/duration_formatter.dart';

class TimelineRuler extends StatelessWidget {
  final int totalDurationMs;
  final double zoom;
  final double width;

  const TimelineRuler({
    super.key,
    required this.totalDurationMs,
    required this.zoom,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      width: width,
      child: CustomPaint(
        size: Size(width, 24),
        painter: _TimelineRulerPainter(
          totalDurationMs: totalDurationMs,
          zoom: zoom,
        ),
      ),
    );
  }
}

class _TimelineRulerPainter extends CustomPainter {
  final int totalDurationMs;
  final double zoom;

  _TimelineRulerPainter({
    required this.totalDurationMs,
    required this.zoom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final tickPaint = Paint()
      ..color = AppColors.textMuted.withValues(alpha: 0.4)
      ..strokeWidth = 1.0;

    final majorTickPaint = Paint()
      ..color = AppColors.textSecondary.withValues(alpha: 0.7)
      ..strokeWidth = 1.2;

    final totalSeconds = totalDurationMs / 1000.0;
    if (totalSeconds <= 0) return;

    // Interval between major ticks in seconds depending on zoom & duration
    double stepSeconds = 10.0;
    if (totalSeconds > 180) {
      stepSeconds = 30.0;
    }
    if (zoom >= 2.0) {
      stepSeconds /= 2.0;
    }

    final double pxPerSecond = size.width / totalSeconds;

    for (double sec = 0; sec <= totalSeconds; sec += stepSeconds) {
      final double x = sec * pxPerSecond;
      if (x < 0 || x > size.width) continue;

      // Draw major tick
      canvas.drawLine(Offset(x, 14), Offset(x, 24), majorTickPaint);

      // Draw label
      final timeStr = DurationFormatter.formatTimeline(sec);
      textPainter.text = TextSpan(
        text: timeStr,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 9.5,
          fontWeight: FontWeight.w500,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x + 3, 2));

      // Draw minor tick halfway
      final double minorX = (sec + (stepSeconds / 2)) * pxPerSecond;
      if (minorX <= size.width) {
        canvas.drawLine(Offset(minorX, 18), Offset(minorX, 24), tickPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TimelineRulerPainter oldDelegate) {
    return oldDelegate.totalDurationMs != totalDurationMs || oldDelegate.zoom != zoom;
  }
}
