import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/models/analytics_summary_model.dart';

class RankingItemTile extends StatelessWidget {
  final int rank;
  final TopItemMetric metric;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;

  const RankingItemTile({
    super.key,
    required this.rank,
    required this.metric,
    this.onTap,
    this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final rankColor = _getRankColor(rank);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF191724),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: rank == 1 ? AppColors.gold.withValues(alpha: 0.4) : AppColors.border.withValues(alpha: 0.5),
            width: rank == 1 ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          children: [
            // Rank Number Badge
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: rankColor.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(color: rankColor, width: 1.2),
              ),
              child: Text(
                '$rank',
                style: TextStyle(
                  color: rankColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),

            const SizedBox(width: 14),

            // Item Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metric.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    metric.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Proportion bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: metric.percentage.clamp(0.02, 1.0),
                      minHeight: 4,
                      backgroundColor: const Color(0xFF262135),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        rank == 1 ? AppColors.gold : AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 14),

            // Plays & Duration
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${metric.playCount} plays',
                  style: TextStyle(
                    color: rank == 1 ? AppColors.gold : Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  metric.formattedDuration,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),

            if (onPlay != null) ...[
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(Icons.play_circle_fill_rounded, color: AppColors.gold, size: 28),
                onPressed: onPlay,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getRankColor(int r) {
    switch (r) {
      case 1:
        return const Color(0xFFFFD700); // Gold
      case 2:
        return const Color(0xFFE0E0E0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return AppColors.textMuted;
    }
  }
}
