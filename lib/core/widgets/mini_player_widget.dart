import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:on_audio_query/on_audio_query.dart' hide SongModel;
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../features/player/controllers/player_controller.dart';
import '../../features/playlists/controllers/favorites_controller.dart';
import 'glass_container.dart';

class MiniPlayerWidget extends StatelessWidget {
  const MiniPlayerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final playerController = Get.find<AudioPlayerController>();

    return Obx(() {
      final song = playerController.currentSong.value;
      if (song == null) return const SizedBox.shrink();

      return GestureDetector(
        onTap: () => playerController.openNowPlaying(),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: GlassContainer(
            borderRadius: BorderRadius.circular(18),
            padding: EdgeInsets.zero,
            color: const Color(0xE6151722),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Thin progress track along top of mini player (Granular Obx for position)
                Obx(() {
                  final currentPos = playerController.position.value.inMilliseconds;
                  final totalDur = playerController.duration.value.inMilliseconds;
                  final progress = totalDur > 0 ? (currentPos / totalDur).clamp(0.0, 1.0) : 0.0;
                  return ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 2.5,
                      backgroundColor: Colors.transparent,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  );
                }),

                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
                  child: Row(
                    children: [
                      // Artwork (Keyed to song.id so it never re-queries on position tick)
                      _buildArtwork(song.id),

                      const SizedBox(width: 12),

                      // Title & Artist
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.labelLarge.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Favorite quick toggle
                      Builder(
                        builder: (context) {
                          final favCtrl = Get.isRegistered<FavoritesController>()
                              ? Get.find<FavoritesController>()
                              : null;
                          if (favCtrl != null) {
                            return Obx(() {
                              final isFav = favCtrl.isFavorite(song.id);
                              return IconButton(
                                icon: Icon(
                                  isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  color: isFav ? AppColors.primary : AppColors.textMuted,
                                  size: 20,
                                ),
                                onPressed: () => favCtrl.toggleFavorite(song),
                                splashRadius: 20,
                              );
                            });
                          }
                          return IconButton(
                            icon: Icon(
                              song.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: song.isFavorite ? AppColors.primary : AppColors.textMuted,
                              size: 20,
                            ),
                            onPressed: () => playerController.toggleFavorite(),
                            splashRadius: 20,
                          );
                        },
                      ),

                      // Play / Pause Button with slight gradient (Granular Obx)
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.primaryGradient,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryGlow,
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Obx(() {
                          final isPlaying = playerController.isPlaying.value;
                          return IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            onPressed: () => playerController.playPause(),
                          );
                        }),
                      ),

                      // Next Song Button
                      IconButton(
                        icon: const Icon(
                          Icons.skip_next_rounded,
                          color: AppColors.textPrimary,
                          size: 24,
                        ),
                        onPressed: () => playerController.skipNext(),
                        splashRadius: 20,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildArtwork(String songId) {
    final int? audioId = int.tryParse(songId);
    return Container(
      key: ValueKey('mini_art_$songId'),
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: audioId != null
            ? QueryArtworkWidget(
                id: audioId,
                type: ArtworkType.AUDIO,
                artworkBorder: BorderRadius.circular(12),
                nullArtworkWidget: _buildFallbackArtwork(),
                errorBuilder: (_, _, _) => _buildFallbackArtwork(),
              )
            : _buildFallbackArtwork(),
      ),
    );
  }

  Widget _buildFallbackArtwork() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E202B), Color(0xFF12141C)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.music_note_rounded, color: AppColors.primary, size: 20),
      ),
    );
  }
}
