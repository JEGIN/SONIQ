import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/models/analytics_summary_model.dart';

class DailyListeningChart extends StatefulWidget {
  final List<DailyListeningMetric> metrics;

  const DailyListeningChart({super.key, required this.metrics});

  @override
  State<DailyListeningChart> createState() => _DailyListeningChartState();
}

class _DailyListeningChartState extends State<DailyListeningChart> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.metrics.isEmpty) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF191724),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'No listening activity recorded in this period',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      );
    }

    final maxMinutes = widget.metrics.fold<int>(
      1,
      (maxVal, m) => max(maxVal, m.listeningMinutes),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF191724),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with live scrubber detail
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Daily Listening Trend',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              if (_selectedIndex != null &&
                  _selectedIndex! < widget.metrics.length) ...[
                Text(
                  '${DateFormat('MMM d').format(widget.metrics[_selectedIndex!].date)}: ${NumberFormat.decimalPattern().format(widget.metrics[_selectedIndex!].listeningMinutes)}m (${NumberFormat.decimalPattern().format(widget.metrics[_selectedIndex!].qualifiedPlays)} plays)',
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ] else ...[
                const Text(
                  'Tap or drag bar to inspect',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ],
          ),

          const SizedBox(height: 16),

          // Interactive Chart Canvas
          SizedBox(
            height: 140,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onPanDown: (details) => _handleTouch(
                    details.localPosition.dx,
                    constraints.maxWidth,
                  ),
                  onPanUpdate: (details) => _handleTouch(
                    details.localPosition.dx,
                    constraints.maxWidth,
                  ),
                  child: CustomPaint(
                    size: Size(constraints.maxWidth, 140),
                    painter: _DailyChartPainter(
                      metrics: widget.metrics,
                      maxMinutes: maxMinutes,
                      selectedIndex: _selectedIndex,
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 6),

          // Date interval labels at base
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMM d').format(widget.metrics.first.date),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
              if (widget.metrics.length > 2)
                Text(
                  DateFormat('MMM d')
                      .format(widget.metrics[widget.metrics.length ~/ 2].date),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              Text(
                DateFormat('MMM d').format(widget.metrics.last.date),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleTouch(double touchX, double totalWidth) {
    if (widget.metrics.isEmpty) return;
    final itemWidth = totalWidth / widget.metrics.length;
    final index = (touchX / itemWidth).floor().clamp(
      0,
      widget.metrics.length - 1,
    );
    setState(() {
      _selectedIndex = index;
    });
  }
}

class _DailyChartPainter extends CustomPainter {
  final List<DailyListeningMetric> metrics;
  final int maxMinutes;
  final int? selectedIndex;

  _DailyChartPainter({
    required this.metrics,
    required this.maxMinutes,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (metrics.isEmpty) return;

    final n = metrics.length;
    final barSpacing = (size.width / n) * 0.28;
    final barWidth = max(2.5, (size.width / n) - barSpacing);

    // Draw grid baseline
    final baselinePaint = Paint()
      ..color = AppColors.borderLight.withValues(alpha: 0.3)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      baselinePaint,
    );

    for (int i = 0; i < n; i++) {
      final m = metrics[i];
      final x = (i * (barWidth + barSpacing)) + (barSpacing / 2);
      final ratio = (m.listeningMinutes / maxMinutes).clamp(0.04, 1.0);
      final barHeight = ratio * (size.height - 10);
      final y = size.height - barHeight;

      final isSelected = selectedIndex == i;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        const Radius.circular(4),
      );

      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: isSelected
              ? [const Color(0xFFFFD700), const Color(0xFFFFF099)]
              : [
                  AppColors.primary.withValues(alpha: 0.5),
                  AppColors.gold.withValues(alpha: 0.85),
                ],
        ).createShader(Rect.fromLTWH(x, y, barWidth, barHeight));

      canvas.drawRRect(rect, paint);

      if (isSelected) {
        // Subtle glow indicator for selected bar
        final glowPaint = Paint()
          ..color = AppColors.gold.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawRRect(rect, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DailyChartPainter oldDelegate) =>
      oldDelegate.metrics != metrics ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.maxMinutes != maxMinutes;
}
