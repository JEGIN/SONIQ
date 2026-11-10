import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/soniq_card.dart';
import '../controllers/settings_controller.dart';
import 'about_dialog_view.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsController = Get.find<SettingsController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 8, 4, 16),
              child: Text('Settings', style: AppTypography.displayLarge),
            ),

            // Library & Audio Stats Card
            Obx(() => SoniqCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Library Overview', style: AppTypography.headlineSmall),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem('Tracks', '${settingsController.totalIndexedSongs}'),
                          _buildStatDivider(),
                          _buildStatItem('Storage', settingsController.totalLibrarySizeFormatted),
                          _buildStatDivider(),
                          _buildStatItem('Ringtones', '${settingsController.totalRingtonesCount}'),
                        ],
                      ),
                    ],
                  ),
                )),

            const SizedBox(height: 20),

            _buildSectionHeader('Library & Audio Indexing'),

            SoniqCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.sync_rounded, color: AppColors.primary),
                    title: const Text('Rescan Music Library'),
                    subtitle: const Text('Scan local device storage for newly added tracks', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    onTap: () {
                      settingsController.libraryController.scanLibrary();
                      Get.snackbar('Scanning', 'Rescanning audio files from storage...');
                    },
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  ListTile(
                    leading: const Icon(Icons.cleaning_services_rounded, color: AppColors.cyan),
                    title: const Text('Clear Artwork Cache'),
                    subtitle: Obx(() => Text('Cached artwork: ${settingsController.cacheSizeText.value}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted))),
                    trailing: Obx(() => settingsController.isClearingCache.value
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.delete_sweep_rounded, color: AppColors.textMuted)),
                    onTap: () => settingsController.clearCache(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            _buildSectionHeader('Playback & Audio Engine'),

            SoniqCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    activeTrackColor: AppColors.primary,
                    secondary: const Icon(Icons.headset_rounded, color: AppColors.primary),
                    title: const Text('Pause on Disconnect'),
                    subtitle: const Text('Auto pause playback when headphones are unplugged', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    value: true,
                    onChanged: (_) {},
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  SwitchListTile(
                    activeTrackColor: AppColors.primary,
                    secondary: const Icon(Icons.high_quality_rounded, color: AppColors.gold),
                    title: const Text('Lossless Frame Slicing'),
                    subtitle: const Text('Preserves 100% original MPEG bitrate during ringtone trims', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    value: true,
                    onChanged: (_) {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            _buildSectionHeader('Share & Distribute'),

            SoniqCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.share_rounded, color: AppColors.gold, size: 22),
                ),
                title: const Text('Share App (as APK)', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text(
                  'Export and send the SONIQ .apk file via Quick Share, Bluetooth, or messaging apps',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                trailing: Obx(() => settingsController.isSharingApk.value
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
                      )
                    : const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.gold, size: 16)),
                onTap: () => settingsController.shareAppAsApk(),
              ),
            ),

            const SizedBox(height: 20),

            _buildSectionHeader('About'),

            SoniqCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.info_outline_rounded, color: AppColors.secondary),
                title: const Text('About SONIQ'),
                subtitle: const Text('Version 1.0.0 • Architecture & Credits', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => const AboutDialogView(),
                  );
                },
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.displayMedium.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 32,
      color: AppColors.border,
    );
  }
}
