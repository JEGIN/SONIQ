import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/localization/soniq_localizations.dart';

class PlayerControlsBar extends StatelessWidget {
  final bool isPlaying;
  final bool isShuffle;
  final LoopMode loopMode;
  final VoidCallback onPlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToggleShuffle;
  final VoidCallback onCycleRepeat;

  const PlayerControlsBar({
    super.key,
    required this.isPlaying,
    required this.isShuffle,
    required this.loopMode,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.onToggleShuffle,
    required this.onCycleRepeat,
  });

  @override
  Widget build(BuildContext context) {
    final strings = SoniqLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Shuffle
          IconButton(
            isSelected: isShuffle,
            icon: Icon(
              Icons.shuffle_rounded,
              color: isShuffle ? AppColors.gold : AppColors.textMuted,
              size: 24,
            ),
            onPressed: onToggleShuffle,
            tooltip: strings.text('shuffle'),
          ),

          // Previous
          IconButton(
            icon: const Icon(
              Icons.skip_previous_rounded,
              color: AppColors.textPrimary,
              size: 36,
            ),
            onPressed: onPrevious,
            tooltip: strings.text('previous'),
          ),

          // Center Glowing Play / Pause (Matches Reference Image 3)
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.goldGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.goldGlow,
                  blurRadius: 24,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Semantics(
                button: true,
                toggled: isPlaying,
                label: isPlaying ? strings.text('pause') : strings.text('play'),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onPlayPause,
                  child: Center(
                    child: Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: AppColors.textDark,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Next
          IconButton(
            icon: const Icon(
              Icons.skip_next_rounded,
              color: AppColors.textPrimary,
              size: 36,
            ),
            onPressed: onNext,
            tooltip: strings.text('next'),
          ),

          // Repeat Mode
          IconButton(
            icon: _buildRepeatIcon(),
            isSelected: loopMode != LoopMode.off,
            onPressed: onCycleRepeat,
            tooltip: strings.text('repeat'),
          ),
        ],
      ),
    );
  }

  Widget _buildRepeatIcon() {
    switch (loopMode) {
      case LoopMode.off:
        return const Icon(
          Icons.repeat_rounded,
          color: AppColors.textMuted,
          size: 24,
        );
      case LoopMode.all:
        return const Icon(
          Icons.repeat_rounded,
          color: AppColors.gold,
          size: 24,
        );
      case LoopMode.one:
        return const Icon(
          Icons.repeat_one_rounded,
          color: AppColors.gold,
          size: 24,
        );
    }
  }
}
