import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:on_audio_query/on_audio_query.dart' hide SongModel;
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/models/song_model.dart';
import '../../../../core/services/music_discovery_service.dart';
import '../../../library/controllers/library_controller.dart';
import '../../../player/controllers/player_controller.dart';
import 'recommendation_feedback_dialog.dart';

class SimilarSongsSheet extends StatelessWidget {
  final SongModel seedSong;

  const SimilarSongsSheet({super.key, required this.seedSong});

  static void show(BuildContext context, SongModel seedSong) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SimilarSongsSheet(seedSong: seedSong),
    );
  }

  @override
  Widget build(BuildContext context) {
    final libraryController = Get.find<LibraryController>();
    final playerController = Get.find<AudioPlayerController>();
    final discoveryService = MusicDiscoveryService();

    final similarItems = discoveryService.getSimilarSongs(
      seedSong,
      libraryController.allSongs,
      limit: 25,
    );

    final sheetHeight = MediaQuery.of(context).size.height * 0.82;

    return Material(
      color: Colors.transparent,
      child: Container(
        height: sheetHeight,
        decoration: const BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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

            // Header with seed track info
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 50,
                      height: 50,
                      child: QueryArtworkWidget(
                        id: int.tryParse(seedSong.id) ?? 0,
                        type: ArtworkType.AUDIO,
                        artworkFit: BoxFit.cover,
                        nullArtworkWidget: Container(
                          color: AppColors.surfaceHighlight,
                          child: const Icon(Icons.music_note_rounded, color: AppColors.gold, size: 26),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SONG RADIO / SIMILAR SONGS',
                          style: TextStyle(
                            color: AppColors.gold,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          seedSong.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.headlineSmall,
                        ),
                        Text(
                          seedSong.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.play_circle_fill_rounded, color: AppColors.gold, size: 36),
                    tooltip: 'Play Radio',
                    onPressed: () {
                      Navigator.pop(context);
                      final queue = [seedSong, ...similarItems.map((e) => e.song)];
                      playerController.playSong(seedSong, queue);
                    },
                  ),
                ],
              ),
            ),

            const Divider(color: AppColors.border, height: 1),

            // Results count badge
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  Text(
                    '${similarItems.length} SIMILAR TRACKS FOUND',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'Ranked by Acoustic & Habit Fit',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                  ),
                ],
              ),
            ),

            // Similar songs list
            Expanded(
              child: similarItems.isEmpty
                  ? const Center(
                      child: Text(
                        'No similar tracks found in your local library.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: similarItems.length,
                      padding: const EdgeInsets.only(bottom: 24),
                      itemBuilder: (context, index) {
                        final item = similarItems[index];
                        final song = item.song;
                        final matchPct = (item.score * 100).clamp(15, 99).toInt();

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: QueryArtworkWidget(
                                id: int.tryParse(song.id) ?? 0,
                                type: ArtworkType.AUDIO,
                                artworkFit: BoxFit.cover,
                                nullArtworkWidget: Container(
                                  color: AppColors.surfaceHighlight,
                                  child: const Icon(Icons.music_note_rounded, color: AppColors.textMuted, size: 20),
                                ),
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  song.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.gold.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.4), width: 0.8),
                                ),
                                child: Text(
                                  '$matchPct% fit',
                                  style: const TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${song.artist} • ${song.formattedDuration}',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.explanation,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppColors.primary, fontSize: 11, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted, size: 20),
                            onPressed: () {
                              RecommendationFeedbackDialog.show(context, song);
                            },
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            final queue = [song, ...similarItems.map((e) => e.song).where((s) => s.id != song.id)];
                            playerController.playSong(song, queue);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
