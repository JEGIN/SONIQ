import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/localization/soniq_localizations.dart';
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
    final strings = SoniqLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(playlist.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.queue_music_rounded),
            tooltip: strings.text('addPlaylistToQueue'),
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
            tooltip: strings.text('renamePlaylist'),
            onPressed: () => _showRenameDialog(context, playlistController),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.red,
            ),
            tooltip: strings.text('delete'),
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
            return SoniqEmptyState(
              icon: Icons.queue_music_rounded,
              title: strings.text('emptyPlaylist'),
              description: strings.text('emptyPlaylistHelp'),
            );
          }

          return Column(
            children: [
              // Header with Play & Shuffle Buttons
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SoniqButton(
                        text: '${strings.text('playAll')} (${songs.length})',
                        icon: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () => playlistController.playEntirePlaylist(
                          currentPl,
                          shuffle: false,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SoniqButton(
                        text: strings.text('shuffle'),
                        variant: SoniqButtonVariant.secondary,
                        icon: const Icon(
                          Icons.shuffle_rounded,
                          color: AppColors.primary,
                        ),
                        onPressed: () => playlistController.playEntirePlaylist(
                          currentPl,
                          shuffle: true,
                        ),
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
                  proxyDecorator:
                      (Widget child, int index, Animation<double> animation) {
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
                    playlistController.reorderSongs(
                      currentPl.id,
                      oldIdx,
                      newIdx,
                    );
                  },
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    return Dismissible(
                      key: ValueKey('${song.id}_$index'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: AlignmentDirectional.centerEnd,
                        padding: const EdgeInsetsDirectional.only(end: 20),
                        color: AppColors.red.withValues(alpha: 0.2),
                        child: const Icon(
                          Icons.delete_rounded,
                          color: AppColors.red,
                        ),
                      ),
                      onDismissed: (_) {
                        playlistController.removeSongFromPlaylist(
                          currentPl.id,
                          song.id,
                        );
                      },
                      child: TrackTile(
                        song: song,
                        isPlaying:
                            playerController.currentSong.value?.id == song.id,
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
    final strings = SoniqLocalizations.of(context);
    final textController = TextEditingController(text: playlist.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text(
          strings.text('renamePlaylist'),
          style: AppTypography.headlineMedium,
        ),
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
            child: Text(
              strings.text('cancel'),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text(
              strings.text('save'),
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
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
    final strings = SoniqLocalizations.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text(
          strings.text('deletePlaylistTitle'),
          style: AppTypography.headlineMedium,
        ),
        content: Text(
          strings
              .text('deletePlaylistConfirm')
              .replaceAll('{name}', playlist.name),
        ),
        actions: [
          TextButton(
            child: Text(
              strings.text('cancel'),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text(
              strings.text('delete'),
              style: const TextStyle(
                color: AppColors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
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
