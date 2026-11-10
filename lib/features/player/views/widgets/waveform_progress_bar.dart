import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/duration_formatter.dart';

class WaveformProgressBar extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final List<double>? waveformPeaks;

  const WaveformProgressBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.waveformPeaks,
  });

  @override
  Widget build(BuildContext context) {
    final posMs = position.inMilliseconds;
    final durMs = duration.inMilliseconds;
    final progress = durMs > 0 ? (posMs / durMs).clamp(0.0, 1.0) : 0.0;

    return Column(
      children: [
        // Waveform Visualizer Seeking Area (Matches Reference Image 3)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) {
            final box = context.findRenderObject() as RenderBox?;
            if (box != null && durMs > 0) {
              final localX = details.localPosition.dx.clamp(0.0, box.size.width);
              final ratio = localX / box.size.width;
              final targetMs = (ratio * durMs).toInt();
              onSeek(Duration(milliseconds: targetMs));
            }
          },
          onTapDown: (details) {
            final box = context.findRenderObject() as RenderBox?;
            if (box != null && durMs > 0) {
              final localX = details.localPosition.dx.clamp(0.0, box.size.width);
              final ratio = localX / box.size.width;
              final targetMs = (ratio * durMs).toInt();
              onSeek(Duration(milliseconds: targetMs));
            }
          },
          child: SizedBox(
            height: 38,
            width: double.infinity,
            child: CustomPaint(
              painter: _PlayerWaveformPainter(
                progress: progress,
                peaks: waveformPeaks ?? _defaultPeaks,
              ),
            ),
          ),
        ),

        const SizedBox(height: 4),

        // Timestamps (Current vs Total)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DurationFormatter.format(posMs),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                DurationFormatter.format(durMs),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static const List<double> _defaultPeaks = [
    0.15, 0.25, 0.35, 0.5, 0.8, 0.45, 0.65, 0.9, 0.7, 0.3,
    0.55, 0.85, 0.6, 0.4, 0.75, 0.95, 0.8, 0.5, 0.35, 0.65,
    0.85, 0.7, 0.4, 0.6, 0.9, 0.5, 0.3, 0.45, 0.7, 0.85,
    0.65, 0.45, 0.8, 0.95, 0.6, 0.4, 0.25, 0.55, 0.75, 0.35,
    0.2, 0.4, 0.6, 0.8, 0.5, 0.7, 0.9, 0.65, 0.45, 0.3,
  ];
}

class _PlayerWaveformPainter extends CustomPainter {
  final double progress;
  final List<double> peaks;

  _PlayerWaveformPainter({
    required this.progress,
    required this.peaks,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (peaks.isEmpty) return;

    final barWidth = 3.0;
    final spacing = (size.width - (peaks.length * barWidth)) / (peaks.length - 1);
    final centerY = size.height / 2;
    final maxBarHeight = size.height * 0.85;

    final activePaint = Paint()
      ..color = AppColors.gold
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.fill;

    final inactivePaint = Paint()
      ..color = AppColors.surfaceHighlight.withValues(alpha: 0.6)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.fill;

    for (int i = 0; i < peaks.length; i++) {
      final x = i * (barWidth + spacing) + (barWidth / 2);
      final ratio = x / size.width;
      final isPlayed = ratio <= progress;

      final barHeight = (peaks[i] * maxBarHeight).clamp(4.0, maxBarHeight);

      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, centerY),
          width: barWidth,
          height: barHeight,
        ),
        const Radius.circular(2),
      );

      canvas.drawRRect(rect, isPlayed ? activePaint : inactivePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PlayerWaveformPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.peaks != peaks;
  }
}
