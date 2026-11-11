import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/models/playback_event_model.dart';
import '../../../../core/database/song_cache_service.dart';

class EntityAnalyticsSheet extends StatelessWidget {
  final String entityType; // 'Song', 'Artist', 'Album'
  final String entityId;
  final String title;
  final String subtitle;

  const EntityAnalyticsSheet({
    super.key,
    required this.entityType,
    required this.entityId,
    required this.title,
    required this.subtitle,
  });

  static void show(
    BuildContext context, {
    required String entityType,
    required String entityId,
    required String title,
    required String subtitle,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EntityAnalyticsSheet(
        entityType: entityType,
        entityId: entityId,
        title: title,
        subtitle: subtitle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allEvents = SongCacheService().getAllPlaybackEvents();
    final List<PlaybackEventModel> matchedEvents;

    if (entityType == 'Song') {
      matchedEvents = allEvents.where((e) => e.songId == entityId).toList();
    } else if (entityType == 'Artist') {
      matchedEvents = allEvents.where((e) => e.artistName == entityId).toList();
    } else {
      matchedEvents = allEvents.where((e) => e.albumName == entityId).toList();
    }

    int totalPlays = 0;
    int totalListeningMs = 0;
    int completedPlays = 0;
    int skippedPlays = 0;
    int firstPlayed = 0;
    int lastPlayed = 0;
    final uniqueSongs = <String>{};

    for (final e in matchedEvents) {
      if (e.isQualifiedPlay) totalPlays++;
      totalListeningMs += e.listenedDurationMs;
      if (e.completionPercentage >= 0.90) completedPlays++;
      if (e.isSkipped) skippedPlays++;
      uniqueSongs.add(e.songId);
      if (firstPlayed == 0 || e.startTimeMs < firstPlayed) firstPlayed = e.startTimeMs;
      if (e.startTimeMs > lastPlayed) lastPlayed = e.startTimeMs;
    }

    final totalEvents = matchedEvents.length;
    final completionRate = totalEvents > 0 ? (completedPlays / totalEvents) : 0.0;
    final skipRate = totalEvents > 0 ? (skippedPlays / totalEvents) : 0.0;

    final minutes = totalListeningMs ~/ 60000;
    final hoursFormatted = minutes >= 60 ? '${(minutes / 60.0).toStringAsFixed(1)} hrs' : '$minutes mins';

    return Container(
      height: MediaQuery.of(context).size.height * 0.70,
      decoration: const BoxDecoration(
        color: Color(0xFF14121F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    entityType == 'Song'
                        ? Icons.music_note_rounded
                        : (entityType == 'Artist' ? Icons.person_rounded : Icons.album_rounded),
                    color: AppColors.gold,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$entityType Analytics', style: AppTypography.bodySmall.copyWith(color: AppColors.gold)),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.headlineMedium,
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(color: AppColors.border, height: 1),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Top Stat Grid
                Row(
                  children: [
                    _buildStatCard('Total Plays', '$totalPlays', Icons.play_arrow_rounded, AppColors.gold),
                    const SizedBox(width: 12),
                    _buildStatCard('Listening Time', hoursFormatted, Icons.timer_rounded, AppColors.primary),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatCard('Completion Rate', '${(completionRate * 100).round()}%', Icons.check_circle_rounded, const Color(0xFF00E676)),
                    const SizedBox(width: 12),
                    _buildStatCard('Skip Rate', '${(skipRate * 100).round()}%', Icons.skip_next_rounded, const Color(0xFFFF5252)),
                  ],
                ),

                const SizedBox(height: 20),

                // Timestamps Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1A2B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow(
                        'First Played',
                        firstPlayed > 0 ? DateFormat('MMM d, yyyy • h:mm a').format(DateTime.fromMillisecondsSinceEpoch(firstPlayed)) : 'Never',
                        Icons.history_rounded,
                      ),
                      const Divider(color: AppColors.border, height: 20),
                      _buildDetailRow(
                        'Last Played',
                        lastPlayed > 0 ? DateFormat('MMM d, yyyy • h:mm a').format(DateTime.fromMillisecondsSinceEpoch(lastPlayed)) : 'Never',
                        Icons.access_time_rounded,
                      ),
                      if (entityType != 'Song') ...[
                        const Divider(color: AppColors.border, height: 20),
                        _buildDetailRow(
                          'Unique Songs Played',
                          '${uniqueSongs.length} tracks',
                          Icons.queue_music_rounded,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Recent Events Log
                const Text(
                  'Recent Listening Events',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 10),

                if (matchedEvents.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'No listening events recorded yet',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ),
                  )
                else
                  ...matchedEvents.reversed.take(5).map((e) {
                    final d = DateTime.fromMillisecondsSinceEpoch(e.startTimeMs);
                    final mins = e.listenedDurationMs ~/ 60000;
                    final secs = (e.listenedDurationMs % 60000) ~/ 1000;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF191724),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            e.isQualifiedPlay ? Icons.verified_rounded : Icons.fiber_manual_record_rounded,
                            color: e.isQualifiedPlay ? AppColors.gold : AppColors.textMuted,
                            size: 16,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DateFormat('MMM d, h:mm a').format(d),
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  'Source: ${e.playbackSource} • ${e.isSkipped ? 'Skipped' : 'Completed'}',
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${mins}m ${secs}s',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1A2B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textMuted, size: 18),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        const Spacer(),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
      ],
    );
  }
}
