import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/models/playlist_model.dart';
import '../../../core/widgets/track_tile.dart';
import '../../../core/widgets/soniq_button.dart';
import '../../../core/widgets/soniq_empty_state.dart';
import '../../player/controllers/player_controller.dart';
import '../controllers/playlist_controller.dart';

class PlaylistDetailView extends StatelessWidget {
  final PlaylistModel playlist;

  const PlaylistDetailView({super.key, required this.playlist});

  @override
  Widget build(BuildContext context) {
    final playlistController = Get.find<PlaylistController>();
    final playerController = Get.find<AudioPlayerController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(playlist.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.queue_music_rounded),
            tooltip: 'Add Playlist to Queue',
            onPressed: () {
              final currentPl = playlistController.playlists.firstWhere(
                (p) => p.id == playlist.id,
                orElse: () => playlist,
              );
              final songs = playlistController.getSongsForPlaylist(currentPl);
              if (songs.isNotEmpty) {
                playerController.addMultipleToQueue(songs);
                Get.snackbar(
                  'Queue Updated',
                  'Added ${songs.length} tracks from "${currentPl.name}" to queue.',
                  backgroundColor: AppColors.surfaceElevated,
                  colorText: Colors.white,
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => _showRenameDialog(context, playlistController),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.red),
            onPressed: () => _confirmDelete(context, playlistController),
          ),
        ],
      ),
      body: SafeArea(
        child: Obx(() {
          // Re-fetch playlist state in case songs change
          final currentPl = playlistController.playlists.firstWhere(
            (p) => p.id == playlist.id,
            orElse: () => playlist,
          );
          final songs = playlistController.getSongsForPlaylist(currentPl);

          if (songs.isEmpty) {
            return const SoniqEmptyState(
              icon: Icons.queue_music_rounded,
              title: 'Empty Playlist',
              description: 'Add songs from your music library by tapping the 3-dots icon on any track.',
            );
          }

          return Column(
            children: [
              // Header with Play & Shuffle Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: SoniqButton(
                        text: 'Play All (${songs.length})',
                        icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                        onPressed: () => playlistController.playEntirePlaylist(currentPl, shuffle: false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SoniqButton(
                        text: 'Shuffle',
                        variant: SoniqButtonVariant.secondary,
                        icon: const Icon(Icons.shuffle_rounded, color: AppColors.primary),
                        onPressed: () => playlistController.playEntirePlaylist(currentPl, shuffle: true),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(color: AppColors.border, height: 1),

              // Reorderable Song List
              Expanded(
                child: ReorderableListView.builder(
                  itemCount: songs.length,
                  physics: const BouncingScrollPhysics(),
                  proxyDecorator: (Widget child, int index, Animation<double> animation) {
                    return Material(
                      elevation: 8.0,
                      color: AppColors.surfaceElevated,
                      shadowColor: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(14),
                      child: child,
                    );
                  },
                  // ignore: deprecated_member_use
                  onReorder: (oldIdx, newIdx) {
                    playlistController.reorderSongs(currentPl.id, oldIdx, newIdx);
                  },
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    return Dismissible(
                      key: ValueKey('${song.id}_$index'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: AppColors.red.withValues(alpha: 0.2),
                        child: const Icon(Icons.delete_rounded, color: AppColors.red),
                      ),
                      onDismissed: (_) {
                        playlistController.removeSongFromPlaylist(currentPl.id, song.id);
                      },
                      child: TrackTile(
                        song: song,
                        isPlaying: playerController.currentSong.value?.id == song.id,
                        onTap: () => playerController.playSong(song, songs),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, PlaylistController controller) {
    final textController = TextEditingController(text: playlist.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Rename Playlist', style: AppTypography.headlineMedium),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Save', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            onPressed: () {
              controller.renamePlaylist(playlist.id, textController.text);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, PlaylistController controller) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Delete Playlist?', style: AppTypography.headlineMedium),
        content: Text('Are you sure you want to delete "${playlist.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Delete', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.bold)),
            onPressed: () {
              controller.deletePlaylist(playlist.id);
              Navigator.pop(context); // Close dialog
              Get.back(); // Go back from detail view
            },
          ),
        ],
      ),
    );
  }
}
