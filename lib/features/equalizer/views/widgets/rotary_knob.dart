import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';

class RotaryKnob extends StatelessWidget {
  final double value; // 0.0 to 1.0 (or normalized)
  final String label;
  final String valueDisplay;
  final ValueChanged<double> onChanged;
  final Color activeColor;
  final double size;

  const RotaryKnob({
    super.key,
    required this.value,
    required this.label,
    required this.valueDisplay,
    required this.onChanged,
    this.activeColor = AppColors.gold,
    this.size = 86.0,
  });

  @override
  Widget build(BuildContext context) {
    // Rotation range from -135 deg to +135 deg (total 270 deg)
    final double angle = (-135.0 + value * 270.0) * (pi / 180.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: (details) {
            // Dragging up increases, down decreases
            final delta = -details.primaryDelta! / 120.0;
            final next = (value + delta).clamp(0.0, 1.0);
            if ((next == 0.0 && value != 0.0) || (next == 1.0 && value != 1.0)) {
              HapticFeedback.lightImpact();
            }
            onChanged(next);
          },
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background Track Arc
                CustomPaint(
                  size: Size(size, size),
                  painter: _KnobArcPainter(
                    progress: value,
                    activeColor: activeColor,
                  ),
                ),

                // Brushed Metal Knob Disc
                Container(
                  width: size * 0.76,
                  height: size * 0.76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [Color(0xFF282B38), Color(0xFF14151C)],
                      center: Alignment(-0.2, -0.2),
                    ),
                    border: Border.all(color: const Color(0xFF383C4D), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Rotating Indicator Dot
                      Transform.rotate(
                        angle: angle,
                        child: Align(
                          alignment: const Alignment(0.0, -0.72),
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: value > 0 ? activeColor : AppColors.textMuted,
                              boxShadow: value > 0
                                  ? [
                                      BoxShadow(
                                        color: activeColor.withValues(alpha: 0.7),
                                        blurRadius: 6,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Label
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),

        const SizedBox(height: 2),

        // Value text
        Text(
          valueDisplay,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: value > 0 ? activeColor : AppColors.textMuted,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _KnobArcPainter extends CustomPainter {
  final double progress;
  final Color activeColor;

  _KnobArcPainter({required this.progress, required this.activeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 4;

    final trackPaint = Paint()
      ..color = const Color(0xFF222533)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    // Start angle: 135 degrees (converted to radians)
    final startAngle = 135.0 * (pi / 180.0);
    // Total sweep: 270 degrees
    final totalSweep = 270.0 * (pi / 180.0);

    // Draw background track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      totalSweep,
      false,
      trackPaint,
    );

    // Draw active arc
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        totalSweep * progress.clamp(0.0, 1.0),
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _KnobArcPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.activeColor != activeColor;
  }
}
