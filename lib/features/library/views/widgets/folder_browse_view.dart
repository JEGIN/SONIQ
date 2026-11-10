import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/models/song_model.dart';
import '../../../../core/widgets/track_tile.dart';
import '../../../player/controllers/player_controller.dart';
import 'package:get/get.dart';

class FolderBrowseView extends StatelessWidget {
  final Map<String, List<SongModel>> foldersMap;

  const FolderBrowseView({super.key, required this.foldersMap});

  @override
  Widget build(BuildContext context) {
    if (foldersMap.isEmpty) {
      return const Center(
        child: Text('No folders found', style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    final folderEntries = foldersMap.entries.toList();

    return ListView.builder(
      itemCount: folderEntries.length,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final entry = folderEntries[index];
        final folderName = entry.key;
        final songs = entry.value;

        return Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, width: 0.8),
              ),
              child: const Icon(Icons.folder_rounded, color: AppColors.secondary, size: 24),
            ),
            title: Text(
              folderName,
              style: AppTypography.headlineSmall.copyWith(fontSize: 15),
            ),
            subtitle: Text(
              '${songs.length} audio tracks',
              style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.play_circle_fill_rounded, color: AppColors.primary, size: 28),
              onPressed: () {
                final player = Get.find<AudioPlayerController>();
                player.playSong(songs.first, songs);
              },
            ),
            children: songs.map((song) {
              return TrackTile(
                song: song,
                onTap: () {
                  final player = Get.find<AudioPlayerController>();
                  player.playSong(song, songs);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
