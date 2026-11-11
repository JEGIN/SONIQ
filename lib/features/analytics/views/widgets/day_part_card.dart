import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

class DayPartCard extends StatelessWidget {
  final Map<String, int> dayParts;
  final Map<String, int> weekdayVsWeekend;

  const DayPartCard({
    super.key,
    required this.dayParts,
    required this.weekdayVsWeekend,
  });

  @override
  Widget build(BuildContext context) {
    final totalDayPartMs = dayParts.values.fold<int>(0, (a, b) => a + b);
    final totalWeekMs = weekdayVsWeekend.values.fold<int>(0, (a, b) => a + b);

    final morningRatio = totalDayPartMs > 0 ? (dayParts['morning'] ?? 0) / totalDayPartMs : 0.0;
    final afternoonRatio = totalDayPartMs > 0 ? (dayParts['afternoon'] ?? 0) / totalDayPartMs : 0.0;
    final eveningRatio = totalDayPartMs > 0 ? (dayParts['evening'] ?? 0) / totalDayPartMs : 0.0;
    final nightRatio = totalDayPartMs > 0 ? (dayParts['night'] ?? 0) / totalDayPartMs : 0.0;

    final weekdayRatio = totalWeekMs > 0 ? (weekdayVsWeekend['weekday'] ?? 0) / totalWeekMs : 0.0;
    final weekendRatio = totalWeekMs > 0 ? (weekdayVsWeekend['weekend'] ?? 0) / totalWeekMs : 0.0;

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
          const Text(
            'Time of Day & Habits',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 14),

          // 4 Day Parts Breakdown
          Row(
            children: [
              _buildPartSegment('Morning', '5AM-12PM', Icons.wb_sunny_outlined, morningRatio, const Color(0xFFFFB020)),
              _buildPartSegment('Afternoon', '12PM-5PM', Icons.wb_sunny_rounded, afternoonRatio, const Color(0xFFFF7A00)),
              _buildPartSegment('Evening', '5PM-10PM', Icons.nights_stay_outlined, eveningRatio, const Color(0xFF9D4EDD)),
              _buildPartSegment('Night', '10PM-5AM', Icons.bedtime_rounded, nightRatio, const Color(0xFF4361EE)),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 14),

          // Weekday vs Weekend Comparison
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Weekday vs Weekend',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Text(
                '${(weekdayRatio * 100).round()}% Mon-Fri  •  ${(weekendRatio * 100).round()}% Sat-Sun',
                style: const TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Proportional Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  Expanded(
                    flex: max(1, (weekdayRatio * 100).round()),
                    child: Container(color: AppColors.primary),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: max(1, (weekendRatio * 100).round()),
                    child: Container(color: AppColors.gold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartSegment(String label, String timeRange, IconData icon, double ratio, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            '${(ratio * 100).round()}%',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600),
          ),
          Text(
            timeRange,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 8),
          ),
        ],
      ),
    );
  }

  int max(int a, int b) => a > b ? a : b;
}
