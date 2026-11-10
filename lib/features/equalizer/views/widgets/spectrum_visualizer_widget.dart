import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

class SpectrumVisualizerWidget extends StatefulWidget {
  final List<double> magnitudes; // 16 bars (0.0 to 1.0)
  final double height;
  final bool isPlaying;

  const SpectrumVisualizerWidget({
    super.key,
    required this.magnitudes,
    this.height = 54.0,
    this.isPlaying = true,
  });

  @override
  State<SpectrumVisualizerWidget> createState() => _SpectrumVisualizerWidgetState();
}

class _SpectrumVisualizerWidgetState extends State<SpectrumVisualizerWidget>
    with SingleTickerProviderStateMixin {
  late final List<double> _smoothedBars;

  @override
  void initState() {
    super.initState();
    _smoothedBars = List.generate(16, (i) => 0.05);
  }

  @override
  void didUpdateWidget(covariant SpectrumVisualizerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Smooth interpolation with decay
    for (int i = 0; i < 16; i++) {
      final target = i < widget.magnitudes.length ? widget.magnitudes[i] : 0.05;
      if (target > _smoothedBars[i]) {
        _smoothedBars[i] = _smoothedBars[i] * 0.3 + target * 0.7; // Fast attack
      } else {
        _smoothedBars[i] = _smoothedBars[i] * 0.85 + target * 0.15; // Smooth decay
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0E15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: CustomPaint(
        size: Size(double.infinity, widget.height),
        painter: _SpectrumPainter(
          bars: _smoothedBars,
          glowColor: AppColors.gold,
        ),
      ),
    );
  }
}

class _SpectrumPainter extends CustomPainter {
  final List<double> bars;
  final Color glowColor;

  _SpectrumPainter({
    required this.bars,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final int count = bars.length;
    final double spacing = 3.5;
    final double totalSpacing = spacing * (count - 1);
    final double barWidth = (size.width - totalSpacing) / count;

    for (int i = 0; i < count; i++) {
      final double magnitude = bars[i].clamp(0.04, 1.0);
      final double barHeight = magnitude * size.height;
      final double left = i * (barWidth + spacing);
      final double top = size.height - barHeight;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, barWidth, barHeight),
        const Radius.circular(2.5),
      );

      // Dual-tone Poweramp gradient (Gold to Cyan/Mint)
      final paint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Color(0xFFF59E0B), // Gold
            Color(0xFF00E5FF), // Cyan
          ],
        ).createShader(Rect.fromLTWH(left, top, barWidth, barHeight));

      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpectrumPainter oldDelegate) => true;
}
