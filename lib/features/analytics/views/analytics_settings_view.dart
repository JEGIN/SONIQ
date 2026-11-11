import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/soniq_card.dart';
import '../controllers/analytics_controller.dart';

class AnalyticsSettingsView extends StatelessWidget {
  const AnalyticsSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AnalyticsController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Analytics & Privacy', style: AppTypography.headlineMedium),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // Offline & Privacy Guarantee Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1B2314),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.4)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_rounded, color: Color(0xFF00E676), size: 24),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '100% On-Device & Private',
                        style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'SONIQ stores all listening events in an encrypted local database. No data is ever uploaded, shared with third parties, or tied to an online account.',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          const Text('Tracking Controls', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5)),
          const SizedBox(height: 8),

          SoniqCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Obx(() => SwitchListTile(
                      activeTrackColor: AppColors.primary,
                      activeThumbColor: AppColors.gold,
                      secondary: const Icon(Icons.history_rounded, color: AppColors.gold),
                      title: const Text('Record Listening History', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      subtitle: const Text(
                        'When paused, music plays normally without recording new events',
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                      value: controller.isTrackingEnabled.value,
                      onChanged: (val) => controller.toggleTracking(val),
                    )),
                const Divider(color: AppColors.border, height: 1),
                ListTile(
                  leading: const Icon(Icons.timer_rounded, color: AppColors.primary),
                  title: const Text('Play-Count Threshold', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  subtitle: const Text(
                    'Tracks must be actively played for at least 30s (or 50% for short tracks) to register as a qualified play',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                  trailing: Obx(() => Text(
                        '${controller.playCountThresholdSeconds.value}s',
                        style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800),
                      )),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          const Text('Data Management', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5)),
          const SizedBox(height: 8),

          SoniqCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.file_download_outlined, color: Color(0xFF00E5FF)),
                  title: const Text('Export Analytics Data (JSON)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  subtitle: const Text('Export all recorded listening events for your personal backup', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 14),
                  onTap: () => controller.exportAnalytics(),
                ),
                const Divider(color: AppColors.border, height: 1),
                ListTile(
                  leading: const Icon(Icons.date_range_rounded, color: AppColors.gold),
                  title: const Text('Clear Specific Date Range', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  subtitle: const Text('Delete listening events within a chosen date range', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 14),
                  onTap: () async {
                    final range = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (range != null && context.mounted) {
                      _showConfirmDialog(
                        context,
                        title: 'Delete Selected Range?',
                        message: 'Permanently remove listening records between ${range.start.month}/${range.start.day} and ${range.end.month}/${range.end.day}? Your audio files and playlists will remain untouched.',
                        onConfirm: () => controller.clearHistoryForRange(range.start, range.end),
                      );
                    }
                  },
                ),
                const Divider(color: AppColors.border, height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: Color(0xFFFF5252)),
                  title: const Text('Delete All Analytics Data', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFFFF5252))),
                  subtitle: const Text('Clears all recorded playback history and streaks. Never deletes original songs or playlists.', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  onTap: () => _showConfirmDialog(
                    context,
                    title: 'Clear All Listening Analytics?',
                    message: 'This will reset all play counts, streaks, and top music statistics in the analytics dashboard. Your audio files and playlists are 100% safe.',
                    onConfirm: () => controller.clearAllHistory(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1A2B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
        content: Text(message, style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.35)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
