import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/models/song_model.dart';
import '../../../player/controllers/player_controller.dart';
import '../../controllers/discovery_controller.dart';

class RecommendationFeedbackDialog extends StatelessWidget {
  final SongModel song;

  const RecommendationFeedbackDialog({super.key, required this.song});

  const RecommendationFeedbackDialog.withSeed({super.key, required SongModel seedSong})
      : song = seedSong;

  static void show(BuildContext context, SongModel song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => RecommendationFeedbackDialog(song: song),
    );
  }

  @override
  Widget build(BuildContext context) {
    final discoveryCtrl = Get.isRegistered<DiscoveryController>()
        ? Get.find<DiscoveryController>()
        : Get.put(DiscoveryController());
    final playerCtrl = Get.find<AudioPlayerController>();

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF161822),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            song.artist,
                            maxLines: 1,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(color: AppColors.border, height: 1),

              // Play Next
              ListTile(
                leading: const Icon(Icons.play_circle_outline_rounded, color: AppColors.primary),
                title: const Text('Play Next', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  playerCtrl.playNext(song);
                  Get.snackbar('Play Next', '${song.title} will play next.');
                },
              ),

              // Add to Queue
              ListTile(
                leading: const Icon(Icons.queue_music_rounded, color: AppColors.secondary),
                title: const Text('Add to Queue', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  playerCtrl.addToQueue(song);
                  Get.snackbar('Added to Queue', '${song.title} added to the end of queue.');
                },
              ),

              const Divider(color: AppColors.border, height: 1),

              // More like this (Like recommendation)
              ListTile(
                leading: const Icon(Icons.thumb_up_alt_rounded, color: AppColors.gold),
                title: const Text('More Like This', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Recommend more music like this song', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                onTap: () {
                  Navigator.pop(context);
                  discoveryCtrl.giveLike(song);
                },
              ),

              // Dislike recommendation
              ListTile(
                leading: const Icon(Icons.thumb_down_alt_rounded, color: AppColors.textMuted),
                title: const Text('Fewer Like This', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Recommend fewer tracks with this vibe', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                onTap: () {
                  Navigator.pop(context);
                  discoveryCtrl.giveDislike(song);
                },
              ),

              // Not Interested
              ListTile(
                leading: const Icon(Icons.visibility_off_rounded, color: AppColors.textMuted),
                title: const Text('Not Interested', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Hide this song from discovery for 30 days', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                onTap: () {
                  Navigator.pop(context);
                  discoveryCtrl.markNotInterested(song);
                },
              ),

              // Exclude Song
              ListTile(
                leading: const Icon(Icons.block_rounded, color: AppColors.red),
                title: const Text('Exclude Song from Discovery', style: TextStyle(color: AppColors.red)),
                onTap: () {
                  Navigator.pop(context);
                  discoveryCtrl.excludeSong(song);
                },
              ),

              // Exclude Artist
              ListTile(
                leading: const Icon(Icons.person_off_rounded, color: AppColors.red),
                title: Text('Exclude Artist: ${song.artist}', style: const TextStyle(color: AppColors.red)),
                onTap: () {
                  Navigator.pop(context);
                  discoveryCtrl.excludeArtist(song.artist);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
