import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/models/song_model.dart';
import '../../../core/database/song_cache_service.dart';
import '../../navigation/controllers/navigation_controller.dart';
import '../../playlists/controllers/favorites_controller.dart';
import '../controllers/player_controller.dart';
import 'widgets/circular_vinyl_artwork.dart';
import 'widgets/waveform_progress_bar.dart';
import 'widgets/player_controls_bar.dart';
import 'widgets/queue_bottom_sheet.dart';
import 'widgets/audio_quality_sheet.dart';
import 'widgets/sleep_timer_dialog.dart';
import '../../equalizer/views/equalizer_view.dart';
import '../../car_mode/views/car_mode_view.dart';
import '../../lyrics/views/lyrics_sheet.dart';

class NowPlayingView extends StatelessWidget {
  const NowPlayingView({super.key});

  @override
  Widget build(BuildContext context) {
    final playerController = Get.find<AudioPlayerController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (details) {
            final cache = SongCacheService();
            final gesturesEnabled =
                cache.getSetting(
                  'player_gestures_enabled',
                  defaultValue: true,
                ) ==
                true;
            final velocity = details.primaryVelocity ?? 0;
            if (!gesturesEnabled || velocity.abs() < 250) return;
            if (cache.getSetting(
                  'haptic_feedback_enabled',
                  defaultValue: true,
                ) ==
                true) {
              HapticFeedback.selectionClick();
            }
            if (velocity < 0) {
              playerController.skipNext();
            } else {
              playerController.skipPrevious();
            }
          },
          child: Column(
            children: [
              // 1. Top Bar (Static, never rebuilds on position changes)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textPrimary,
                        size: 30,
                      ),
                      onPressed: () => Get.back(),
                    ),
                    Text(
                      'Now Playing',
                      style: AppTypography.headlineSmall.copyWith(
                        color: AppColors.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.lyrics_rounded,
                            color: AppColors.gold,
                            size: 22,
                          ),
                          tooltip: 'Lyrics',
                          onPressed: () {
                            final song = playerController.currentSong.value;
                            if (song != null) LyricsSheet.show(context, song);
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.queue_music_rounded,
                            color: AppColors.textPrimary,
                            size: 24,
                          ),
                          tooltip: 'Queue',
                          onPressed: () => _openQueue(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 1),

              // 2. Circular Vinyl Artwork with Golden Progress Arc (Granular Obx)
              Obx(() {
                final song = playerController.currentSong.value;
                if (song == null) {
                  return const SizedBox(
                    height: 240,
                    child: Center(
                      child: Text(
                        'No song playing',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  );
                }

                final pos = playerController.position.value;
                final dur = playerController.duration.value;
                final isPlaying = playerController.isPlaying.value;
                final progress = dur.inMilliseconds > 0
                    ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
                    : 0.0;

                return CircularVinylArtwork(
                  key: ValueKey(song.id),
                  song: song,
                  isPlaying: isPlaying,
                  progress: progress,
                );
              }),

              const Spacer(flex: 2),

              // 3. Track Metadata (Rebuilds ONLY on track change or favorite toggle)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Obx(() {
                  final song = playerController.currentSong.value;
                  if (song == null) return const SizedBox.shrink();

                  return Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.displayMedium.copyWith(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () =>
                                  AudioQualitySheet.show(context, song),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceElevated,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: AppColors.border,
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${song.fileExtension.toUpperCase()} • 44.1 kHz • ${song.formattedSize}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.gold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.info_outline_rounded,
                                      size: 11,
                                      color: AppColors.gold,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Favorite Toggle Heart
                      Builder(
                        builder: (context) {
                          final favCtrl =
                              Get.isRegistered<FavoritesController>()
                              ? Get.find<FavoritesController>()
                              : null;
                          if (favCtrl != null) {
                            return Obx(() {
                              final isFav = favCtrl.isFavorite(song.id);
                              return IconButton(
                                icon: Icon(
                                  isFav
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  color: isFav
                                      ? AppColors.primary
                                      : AppColors.textMuted,
                                  size: 26,
                                ),
                                onPressed: () => favCtrl.toggleFavorite(song),
                              );
                            });
                          }
                          return IconButton(
                            icon: Icon(
                              song.isFavorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: song.isFavorite
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                              size: 26,
                            ),
                            onPressed: () => playerController.toggleFavorite(),
                          );
                        },
                      ),

                      // More Options
                      IconButton(
                        icon: const Icon(
                          Icons.more_vert_rounded,
                          color: AppColors.textMuted,
                          size: 24,
                        ),
                        onPressed: () => _showTrackOptions(context, song),
                      ),
                    ],
                  );
                }),
              ),

              const SizedBox(height: 18),

              // 4. Waveform Audio Visualizer & Progress Bar (Granular Obx for position/duration)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Obx(() {
                  final song = playerController.currentSong.value;
                  return WaveformProgressBar(
                    position: playerController.position.value,
                    duration: playerController.duration.value,
                    waveformPeaks: song?.waveformPeaks,
                    onSeek: (target) => playerController.seek(target),
                  );
                }),
              ),

              const SizedBox(height: 16),

              // 5. Playback Controls Bar (Granular Obx for isPlaying, isShuffle, loopMode)
              Obx(
                () => PlayerControlsBar(
                  isPlaying: playerController.isPlaying.value,
                  isShuffle: playerController.isShuffle.value,
                  loopMode: playerController.loopMode.value,
                  onPlayPause: () => playerController.playPause(),
                  onPrevious: () => playerController.skipPrevious(),
                  onNext: () => playerController.skipNext(),
                  onToggleShuffle: () => playerController.toggleShuffle(),
                  onCycleRepeat: () => playerController.cycleRepeatMode(),
                ),
              ),

              const Spacer(flex: 2),

              // 6. Bottom subtle action row: Playback Speed & Studio shortcut
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Playback Speed Selector
                    Obx(
                      () => GestureDetector(
                        onTap: () =>
                            _showSpeedSelector(context, playerController),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.border,
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            '${playerController.playbackSpeed.value}x',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Equalizer Shortcut
                    GestureDetector(
                      onTap: () => Get.to(() => const EqualizerView()),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.4),
                            width: 0.8,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.equalizer_rounded,
                              color: AppColors.gold,
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'EQ',
                              style: TextStyle(
                                color: AppColors.gold,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Synchronized Lyrics Shortcut
                    GestureDetector(
                      onTap: () {
                        final song = playerController.currentSong.value;
                        if (song != null) LyricsSheet.show(context, song);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.5),
                            width: 0.8,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lyrics_rounded,
                              color: AppColors.gold,
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'LYRICS',
                              style: TextStyle(
                                color: AppColors.gold,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Renault Triber Car Mode Shortcut
                    GestureDetector(
                      onTap: () => Get.to(
                        () => const CarModeView(),
                        transition: Transition.fadeIn,
                        duration: const Duration(milliseconds: 250),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF261D00),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.6),
                            width: 1.0,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.directions_car_rounded,
                              color: AppColors.gold,
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'CAR',
                              style: TextStyle(
                                color: AppColors.gold,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Sleep Timer Shortcut
                    Obx(() {
                      final sec =
                          playerController.sleepTimerSecondsRemaining.value;
                      final isActive = sec > 0;
                      return GestureDetector(
                        onTap: () =>
                            SleepTimerDialog.show(context, playerController),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.gold.withValues(alpha: 0.2)
                                : AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isActive
                                  ? AppColors.gold
                                  : AppColors.border,
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.bedtime_rounded,
                                color: isActive
                                    ? AppColors.gold
                                    : AppColors.textSecondary,
                                size: 14,
                              ),
                              if (isActive) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '${sec ~/ 60}m',
                                  style: const TextStyle(
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),

                    // Quick Jump to Studio
                    Obx(() {
                      final song = playerController.currentSong.value;
                      if (song == null) return const SizedBox.shrink();
                      return GestureDetector(
                        onTap: () {
                          Get.back(); // close player
                          final nav = Get.find<NavigationController>();
                          nav.openStudioWithSong(song);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.5),
                              width: 0.8,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.content_cut_rounded,
                                color: AppColors.primary,
                                size: 14,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Cut',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openQueue(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const QueueBottomSheet(),
    );
  }

  void _showSpeedSelector(
    BuildContext context,
    AudioPlayerController controller,
  ) {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Playback Speed', style: AppTypography.headlineSmall),
            ),
            ...speeds.map(
              (s) => ListTile(
                title: Text('${s}x', textAlign: TextAlign.center),
                selected: controller.playbackSpeed.value == s,
                selectedColor: AppColors.primary,
                onTap: () {
                  controller.setSpeed(s);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTrackOptions(BuildContext context, dynamic song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.lyrics_rounded, color: AppColors.gold),
              title: const Text('Synchronized Lyrics'),
              onTap: () {
                Navigator.pop(context);
                if (song is SongModel) {
                  LyricsSheet.show(context, song);
                } else {
                  final playerCtrl = Get.find<AudioPlayerController>();
                  final current = playerCtrl.currentSong.value;
                  if (current != null) LyricsSheet.show(context, current);
                }
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.content_cut_rounded,
                color: AppColors.primary,
              ),
              title: const Text('Edit / Cut in Studio'),
              onTap: () {
                Navigator.pop(context);
                Get.back();
                Get.find<NavigationController>().openStudioWithSong(song);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.playlist_add_rounded,
                color: AppColors.textPrimary,
              ),
              title: const Text('Add to Playlist'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
