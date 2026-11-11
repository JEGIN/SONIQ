import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/models/analytics_summary_model.dart';

class HourlyDistributionChart extends StatelessWidget {
  final List<HourlyListeningMetric> metrics;
  final int peakHour;

  const HourlyDistributionChart({
    super.key,
    required this.metrics,
    required this.peakHour,
  });

  @override
  Widget build(BuildContext context) {
    final maxMinutes = metrics.fold<int>(1, (m, val) => max(m, val.listeningMinutes));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF191724),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '24-Hour Listening Pattern',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded, color: AppColors.gold, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      'Peak: ${_formatHour(peakHour)}',
                      style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 24 Hour Bars
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(24, (h) {
                final m = h < metrics.length ? metrics[h] : null;
                final minutes = m?.listeningMinutes ?? 0;
                final ratio = maxMinutes > 0 ? (minutes / maxMinutes).clamp(0.04, 1.0) : 0.04;
                final isPeak = h == peakHour && minutes > 0;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: Tooltip(
                      message: '${_formatHour(h)}: $minutes mins',
                      child: Container(
                        height: ratio * 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: isPeak
                                ? [AppColors.gold, const Color(0xFFFFF1A6)]
                                : [
                                    const Color(0xFF262135),
                                    minutes > 0 ? AppColors.primary.withValues(alpha: 0.7) : const Color(0xFF322B45),
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 8),

          // Time Markers
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('12 AM', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
              Text('6 AM', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
              Text('12 PM', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
              Text('6 PM', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
              Text('11 PM', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  String _formatHour(int h) {
    final period = h >= 12 ? 'PM' : 'AM';
    final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$displayH:00 $period';
  }
}
