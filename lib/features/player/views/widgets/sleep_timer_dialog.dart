import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../controllers/player_controller.dart';

class SleepTimerDialog extends StatelessWidget {
  final AudioPlayerController controller;

  const SleepTimerDialog({super.key, required this.controller});

  static void show(BuildContext context, AudioPlayerController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SleepTimerDialog(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bedtime_rounded, color: AppColors.gold, size: 22),
                    SizedBox(width: 10),
                    Text('Sleep Timer', style: AppTypography.headlineMedium),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 12),

            // Active countdown banner if timer is running or stop after track is active
            Obx(() {
              final sec = controller.sleepTimerSecondsRemaining.value;
              final stopAfter = controller.stopAfterCurrentTrack.value;
              if (sec <= 0 && !stopAfter) return const SizedBox.shrink();

              final m = sec ~/ 60;
              final s = sec % 60;
              final formatted = stopAfter ? 'End of Song' : '$m:${s.toString().padLeft(2, '0')} remaining';

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, color: AppColors.gold, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Sleep Timer Active', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 13)),
                          Text(stopAfter ? 'Will pause playback at end of current track' : '$formatted • Fades gently before stopping',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    TextButton(
                      child: const Text('Cancel', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w700)),
                      onPressed: () {
                        controller.cancelSleepTimer();
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              );
            }),

            // Preset Options (15m, 30m, 45m, 60m, End of Song)
            _buildTimerTile(context, '15 Minutes', 15),
            _buildTimerTile(context, '30 Minutes', 30),
            _buildTimerTile(context, '45 Minutes', 45),
            _buildTimerTile(context, '60 Minutes (1 Hour)', 60),

            // End of track option
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: const Icon(Icons.skip_next_rounded, color: AppColors.gold),
              title: const Text('End of Current Song', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: const Text('Stops playback as soon as this song completes', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              onTap: () {
                final remMs = controller.duration.value.inMilliseconds - controller.position.value.inMilliseconds;
                final minutes = (remMs / 60000).ceil().clamp(1, 60);
                controller.setSleepTimer(minutes);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerTile(BuildContext context, String title, int minutes) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: const Icon(Icons.alarm_rounded, color: AppColors.textSecondary),
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      onTap: () {
        controller.setSleepTimer(minutes);
        Navigator.pop(context);
      },
    );
  }
}
