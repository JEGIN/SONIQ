import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/models/song_model.dart';
import '../../../navigation/controllers/navigation_controller.dart';
import '../../../player/controllers/player_controller.dart';
import '../../../playlists/controllers/playlist_controller.dart';
import '../../../playlists/controllers/favorites_controller.dart';
import '../../../analytics/views/widgets/entity_analytics_sheet.dart';

class TrackOptionsBottomSheet extends StatelessWidget {
  final SongModel song;

  const TrackOptionsBottomSheet({super.key, required this.song});

  @override
  Widget build(BuildContext context) {
    final playerController = Get.find<AudioPlayerController>();
    final playlistController = Get.find<PlaylistController>();
    final navController = Get.find<NavigationController>();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Track Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.headlineSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${song.artist} • ${song.formattedDuration} • ${song.formattedSize}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: AppColors.border, height: 1),

            ListTile(
              leading: const Icon(Icons.play_circle_outline_rounded, color: AppColors.primary),
              title: const Text('Play Next'),
              onTap: () {
                Navigator.pop(context);
                playerController.playNext(song);
                Get.snackbar(
                  'Play Next',
                  '${song.title} will play next.',
                  backgroundColor: AppColors.surfaceElevated,
                  colorText: Colors.white,
                  duration: const Duration(seconds: 2),
                );
              },
            ),

            ListTile(
              leading: const Icon(Icons.queue_music_rounded, color: AppColors.gold),
              title: const Text('Add to Queue'),
              onTap: () {
                Navigator.pop(context);
                playerController.addToQueue(song);
                Get.snackbar(
                  'Added to Queue',
                  '${song.title} added to the end of the queue.',
                  backgroundColor: AppColors.surfaceElevated,
                  colorText: Colors.white,
                  duration: const Duration(seconds: 2),
                );
              },
            ),

            if (song.album.isNotEmpty && song.album != 'Unknown Album')
              ListTile(
                leading: const Icon(Icons.album_rounded, color: AppColors.gold),
                title: Text('Add Album to Queue ("${song.album}")'),
                onTap: () {
                  Navigator.pop(context);
                  playerController.addAlbumToQueue(song.album);
                  Get.snackbar(
                    'Album Added',
                    'Tracks from ${song.album} added to queue.',
                    backgroundColor: AppColors.surfaceElevated,
                    colorText: Colors.white,
                    duration: const Duration(seconds: 2),
                  );
                },
              ),

            if (song.artist.isNotEmpty && song.artist != 'Unknown Artist')
              ListTile(
                leading: const Icon(Icons.person_rounded, color: AppColors.secondary),
                title: Text('Add Artist to Queue ("${song.artist}")'),
                onTap: () {
                  Navigator.pop(context);
                  playerController.addArtistToQueue(song.artist);
                  Get.snackbar(
                    'Artist Added',
                    'Tracks by ${song.artist} added to queue.',
                    backgroundColor: AppColors.surfaceElevated,
                    colorText: Colors.white,
                    duration: const Duration(seconds: 2),
                  );
                },
              ),

            ListTile(
              leading: const Icon(Icons.content_cut_rounded, color: AppColors.primary),
              title: const Text('Open in Audio Studio'),
              subtitle: const Text('Trim & create custom ringtones', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                navController.openStudioWithSong(song);
              },
            ),

            ListTile(
              leading: const Icon(Icons.playlist_add_rounded, color: AppColors.secondary),
              title: const Text('Add to Playlist'),
              onTap: () {
                Navigator.pop(context);
                _showAddToPlaylistDialog(context, playlistController, song);
              },
            ),

            Builder(
              builder: (context) {
                final favCtrl = Get.isRegistered<FavoritesController>()
                    ? Get.find<FavoritesController>()
                    : null;
                if (favCtrl != null) {
                  return Obx(() {
                    final isFav = favCtrl.isFavorite(song.id);
                    return ListTile(
                      leading: Icon(
                        isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isFav ? AppColors.primary : AppColors.textPrimary,
                      ),
                      title: Text(isFav ? 'Remove from Favorites' : 'Add to Favorites'),
                      onTap: () {
                        Navigator.pop(context);
                        favCtrl.toggleFavorite(song);
                      },
                    );
                  });
                }
                return ListTile(
                  leading: Icon(
                    song.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: song.isFavorite ? AppColors.primary : AppColors.textPrimary,
                  ),
                  title: Text(song.isFavorite ? 'Remove from Favorites' : 'Add to Favorites'),
                  onTap: () {
                    Navigator.pop(context);
                    playerController.toggleFavorite(song);
                  },
                );
              },
            ),

            ListTile(
              leading: const Icon(Icons.insights_rounded, color: AppColors.gold),
              title: const Text('View Song Analytics'),
              onTap: () {
                Navigator.pop(context);
                EntityAnalyticsSheet.show(
                  context,
                  entityType: 'Song',
                  entityId: song.id,
                  title: song.title,
                  subtitle: song.artist,
                );
              },
            ),

            ListTile(
              leading: const Icon(Icons.share_rounded, color: AppColors.textPrimary),
              title: const Text('Share Audio File'),
              onTap: () {
                Navigator.pop(context);
                if (song.dataPath.isNotEmpty) {
                  // ignore: deprecated_member_use
                  Share.shareXFiles([XFile(song.dataPath)], text: song.title);
                }
              },
            ),

            ListTile(
              leading: const Icon(Icons.info_outline_rounded, color: AppColors.textMuted),
              title: const Text('File Information'),
              subtitle: Text(
                song.dataPath,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
              onTap: () {},
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showAddToPlaylistDialog(
    BuildContext context,
    PlaylistController controller,
    SongModel song,
  ) {
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
              child: Text('Add to Playlist', style: AppTypography.headlineSmall),
            ),
            if (controller.playlists.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Text('No playlists created yet. Create one first!'),
              )
            else
              ...controller.playlists.map((pl) => ListTile(
                    leading: const Icon(Icons.queue_music_rounded, color: AppColors.secondary),
                    title: Text(pl.name),
                    subtitle: Text('${pl.songCount} tracks'),
                    onTap: () {
                      controller.addSongToPlaylist(pl.id, song);
                      Navigator.pop(context);
                    },
                  )),
          ],
        ),
      ),
    );
  }
}
