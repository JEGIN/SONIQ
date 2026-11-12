import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../app/theme/app_colors.dart';
import '../../app/localization/soniq_localizations.dart';
import '../models/song_model.dart';
import '../../features/player/controllers/player_controller.dart';

/// Premium Floating Playback Bar containing:
/// 1. Primary Play All / Pause circular FAB (56x56) with SONIQ brand gradient & luminous glow.
/// 2. Secondary Shuffle All frosted glass button (44x44) with light tactile haptics.
///
/// Features dynamic positioning above the MiniPlayerWidget (~86px) or bottom inset (16px),
/// smooth spring scale & fade animations, debounced rapid tap protection, and full queue synchronization.
class SoniqFloatingPlaybackBar extends StatefulWidget {
  final List<SongModel> songs;
  final String collectionTitle;
  final bool isVisible;
  final double additionalBottomOffset;

  const SoniqFloatingPlaybackBar({
    super.key,
    required this.songs,
    this.collectionTitle = 'All Songs',
    this.isVisible = true,
    this.additionalBottomOffset = 0.0,
  });

  @override
  State<SoniqFloatingPlaybackBar> createState() =>
      _SoniqFloatingPlaybackBarState();
}

class _SoniqFloatingPlaybackBarState extends State<SoniqFloatingPlaybackBar> {
  DateTime _lastTapTime = DateTime.fromMillisecondsSinceEpoch(0);
  bool _playPressed = false;
  bool _shufflePressed = false;

  bool _isDebounced() {
    final now = DateTime.now();
    if (now.difference(_lastTapTime).inMilliseconds < 400) {
      return true;
    }
    _lastTapTime = now;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final playerCtrl = Get.find<AudioPlayerController>();
    final strings = SoniqLocalizations.of(context);

    return Obx(() {
      final reduceMotion = MediaQuery.of(context).disableAnimations;
      final currentSong = playerCtrl.currentSong.value;
      final isPlaying = playerCtrl.isPlaying.value;
      final hasActiveMiniPlayer = currentSong != null;

      // Calculate bottom distance:
      // If MiniPlayer is visible (height ~70px + vertical margins 12px), float 86px from bottom.
      // If MiniPlayer is absent, float 16px from bottom.
      final bottomOffset =
          (hasActiveMiniPlayer ? 86.0 : 16.0) + widget.additionalBottomOffset;

      // Determine if current collection is actively playing
      final isCollectionActive =
          currentSong != null &&
          widget.songs.any((s) => s.id == currentSong.id) &&
          playerCtrl.queue.isNotEmpty &&
          playerCtrl.queue.any((s) => s.id == currentSong.id);

      final showControls = widget.isVisible && widget.songs.isNotEmpty;

      return AnimatedPositionedDirectional(
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        end: 16,
        bottom: bottomOffset,
        child: AnimatedScale(
          scale: showControls ? 1.0 : 0.0,
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 240),
          curve: Curves.easeOutBack,
          child: AnimatedOpacity(
            opacity: showControls ? 1.0 : 0.0,
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 200),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Shuffle All Secondary Glass Action
                Semantics(
                  button: true,
                  label: '${strings.text('shuffle')} ${widget.collectionTitle}',
                  hint: strings.text('shuffleHint'),
                  child: GestureDetector(
                    onTapDown: (_) => setState(() => _shufflePressed = true),
                    onTapUp: (_) => setState(() => _shufflePressed = false),
                    onTapCancel: () => setState(() => _shufflePressed = false),
                    onTap: () async {
                      if (_isDebounced()) return;
                      await HapticFeedback.lightImpact();
                      if (widget.songs.isEmpty) {
                        Get.snackbar(
                          'No Songs',
                          'No songs found to shuffle in ${widget.collectionTitle}.',
                          backgroundColor: AppColors.surfaceElevated,
                          colorText: Colors.white,
                        );
                        return;
                      }
                      await playerCtrl.playAll(widget.songs, shuffle: true);
                    },
                    child: AnimatedScale(
                      scale: _shufflePressed ? 0.90 : 1.0,
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 100),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xE6161824),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.shuffle_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // 2. Play All / Pause Primary Circular FAB
                Semantics(
                  button: true,
                  label: isCollectionActive && isPlaying
                      ? '${strings.text('pause')} ${widget.collectionTitle}'
                      : '${strings.text('play')} ${widget.collectionTitle}',
                  toggled: isCollectionActive && isPlaying,
                  hint: strings.text('playCollectionHint'),
                  child: GestureDetector(
                    onTapDown: (_) => setState(() => _playPressed = true),
                    onTapUp: (_) => setState(() => _playPressed = false),
                    onTapCancel: () => setState(() => _playPressed = false),
                    onTap: () async {
                      if (_isDebounced()) return;
                      await HapticFeedback.mediumImpact();

                      if (widget.songs.isEmpty) {
                        Get.snackbar(
                          'No Songs',
                          'No songs available in ${widget.collectionTitle}.',
                          backgroundColor: AppColors.surfaceElevated,
                          colorText: Colors.white,
                        );
                        return;
                      }

                      // If this collection is already playing or paused:
                      if (isCollectionActive) {
                        await playerCtrl.playPause();
                      } else {
                        // Start playing this collection from index 0
                        await playerCtrl.playAll(widget.songs, shuffle: false);
                      }
                    },
                    child: AnimatedScale(
                      scale: _playPressed ? 0.90 : 1.0,
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 100),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.5),
                              blurRadius: 18,
                              offset: const Offset(0, 5),
                              spreadRadius: 1,
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            isCollectionActive && isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
