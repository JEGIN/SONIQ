import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:on_audio_query/on_audio_query.dart' hide SongModel;

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../app/localization/soniq_localizations.dart';
import '../../features/library/views/widgets/track_options_bottom_sheet.dart';
import '../../features/playlists/controllers/favorites_controller.dart';
import '../models/song_model.dart';

class TrackTile extends StatelessWidget {
  final SongModel song;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback? onMoreTap;
  final VoidCallback? onFavoriteTap;

  const TrackTile({
    super.key,
    required this.song,
    this.isPlaying = false,
    required this.onTap,
    this.onMoreTap,
    this.onFavoriteTap,
  });

  @override
  Widget build(BuildContext context) {
    final strings = SoniqLocalizations.of(context);
    final allowTwoLines = MediaQuery.textScalerOf(context).scale(14) > 18;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.primaryGlow,
        highlightColor: AppColors.surfaceHighlight,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Album Artwork
              _buildArtwork(context),

              const SizedBox(width: 14),

              // Title & Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      song.title,
                      maxLines: allowTwoLines ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isPlaying
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            song.artist,
                            maxLines: allowTwoLines ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: const BoxDecoration(
                            color: AppColors.textMuted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          song.formattedDuration,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textMuted,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        if (song.fileExtension.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: AppColors.border,
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              song.fileExtension.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Equalizer icon if playing
              if (isPlaying) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.equalizer_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ],

              // Global Reactive Favorite Toggle Button
              Builder(
                builder: (context) {
                  final favCtrl = Get.isRegistered<FavoritesController>()
                      ? Get.find<FavoritesController>()
                      : null;

                  if (favCtrl != null) {
                    return Obx(() {
                      final isFav = favCtrl.isFavorite(song.id);
                      return IconButton(
                        tooltip: isFav
                            ? strings.text('removeFavorite')
                            : strings.text('addFavorite'),
                        icon: Icon(
                          isFav
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: isFav
                              ? AppColors.primary
                              : AppColors.textMuted,
                          size: 20,
                        ),
                        onPressed:
                            onFavoriteTap ?? () => favCtrl.toggleFavorite(song),
                        splashRadius: 20,
                      );
                    });
                  }

                  return IconButton(
                    tooltip: song.isFavorite
                        ? strings.text('removeFavorite')
                        : strings.text('addFavorite'),
                    icon: Icon(
                      song.isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: song.isFavorite
                          ? AppColors.primary
                          : AppColors.textMuted,
                      size: 20,
                    ),
                    onPressed: onFavoriteTap,
                    splashRadius: 20,
                  );
                },
              ),

              // 3-dot options menu
              IconButton(
                tooltip: strings.text('moreOptions'),
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
                onPressed:
                    onMoreTap ??
                    () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => TrackOptionsBottomSheet(song: song),
                      );
                    },
                splashRadius: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArtwork(BuildContext context) {
    final int? audioId = int.tryParse(song.id);
    return Semantics(
      image: true,
      label:
          '${SoniqLocalizations.of(context).text('albumArtwork')}: ${song.album}, ${song.artist}',
      child: ExcludeSemantics(
        child: Container(
          key: ValueKey('tile_art_${song.id}'),
          width: 52,
          height: 52,
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
        ),
      ),
    );
  }

  Widget _buildFallbackArtwork() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E202B), Color(0xFF12141C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          color: isPlaying ? AppColors.primary : AppColors.textMuted,
          size: 24,
        ),
      ),
    );
  }
}
