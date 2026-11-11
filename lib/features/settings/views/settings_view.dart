import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/soniq_card.dart';
import '../controllers/settings_controller.dart';
import 'about_dialog_view.dart';
import '../../analytics/views/analytics_dashboard_view.dart';
import '../../analytics/views/analytics_settings_view.dart';
import 'device_capabilities_view.dart';

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
            Obx(
              () => SoniqCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Library Overview',
                      style: AppTypography.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          'Tracks',
                          '${settingsController.totalIndexedSongs}',
                        ),
                        _buildStatDivider(),
                        _buildStatItem(
                          'Storage',
                          settingsController.totalLibrarySizeFormatted,
                        ),
                        _buildStatDivider(),
                        _buildStatItem(
                          'Ringtones',
                          '${settingsController.totalRingtonesCount}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            _buildSectionHeader('Library & Audio Indexing'),

            SoniqCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.sync_rounded,
                      color: AppColors.primary,
                    ),
                    title: const Text('Rescan Music Library'),
                    subtitle: const Text(
                      'Scan local device storage for newly added tracks',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    onTap: () {
                      settingsController.libraryController.scanLibrary();
                      Get.snackbar(
                        'Scanning',
                        'Rescanning audio files from storage...',
                      );
                    },
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.cleaning_services_rounded,
                      color: AppColors.cyan,
                    ),
                    title: const Text('Clear Artwork Cache'),
                    subtitle: Obx(
                      () => Text(
                        'Cached artwork: ${settingsController.cacheSizeText.value}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    trailing: Obx(
                      () => settingsController.isClearingCache.value
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.delete_sweep_rounded,
                              color: AppColors.textMuted,
                            ),
                    ),
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
                    secondary: const Icon(
                      Icons.headset_rounded,
                      color: AppColors.primary,
                    ),
                    title: const Text('Pause on Disconnect'),
                    subtitle: const Text(
                      'Auto pause playback when headphones are unplugged',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    value: true,
                    onChanged: (_) {},
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  SwitchListTile(
                    activeTrackColor: AppColors.primary,
                    secondary: const Icon(
                      Icons.high_quality_rounded,
                      color: AppColors.gold,
                    ),
                    title: const Text('Lossless Frame Slicing'),
                    subtitle: const Text(
                      'Preserves 100% original MPEG bitrate during ringtone trims',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    value: true,
                    onChanged: (_) {},
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  Obx(
                    () => SwitchListTile(
                      activeTrackColor: AppColors.primary,
                      activeThumbColor: AppColors.gold,
                      secondary: const Icon(
                        Icons.mic_off_rounded,
                        color: AppColors.gold,
                      ),
                      title: const Text('Filter Voice & Call Recordings'),
                      subtitle: const Text(
                        'Skip Sound Recorder, WhatsApp voice notes, and call recordings so they never interrupt music playback',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      value: settingsController.skipRecordings.value,
                      onChanged: (val) =>
                          settingsController.toggleSkipRecordings(val),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            _buildSectionHeader('Device & Playback'),

            SoniqCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  Obx(
                    () => SwitchListTile(
                      activeTrackColor: AppColors.primary,
                      secondary: const Icon(
                        Icons.cast_connected_rounded,
                        color: AppColors.primary,
                      ),
                      title: const Text('Auto Play on Cast Connect/Disconnect'),
                      subtitle: const Text(
                        'Resume playback after the active audio output changes',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      value: settingsController.autoPlayOnCastChange.value,
                      onChanged: settingsController.setAutoPlayOnCastChange,
                    ),
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  Obx(
                    () => SwitchListTile(
                      activeTrackColor: AppColors.primary,
                      secondary: const Icon(
                        Icons.swap_horiz_rounded,
                        color: AppColors.gold,
                      ),
                      title: const Text('Crossfade'),
                      subtitle: const Text(
                        'Fade between tracks for smoother transitions',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      value: settingsController.crossfadeEnabled.value,
                      onChanged: settingsController.setCrossfadeEnabled,
                    ),
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  Obx(
                    () => SwitchListTile(
                      activeTrackColor: AppColors.primary,
                      secondary: const Icon(
                        Icons.battery_saver_rounded,
                        color: AppColors.cyan,
                      ),
                      title: const Text('Battery Optimization'),
                      subtitle: const Text(
                        'Turn off the live spectrum visualizer to reduce background work',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      value:
                          settingsController.batteryOptimizationEnabled.value,
                      onChanged:
                          settingsController.setBatteryOptimizationEnabled,
                    ),
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  Obx(
                    () => SwitchListTile(
                      activeTrackColor: AppColors.primary,
                      secondary: const Icon(
                        Icons.speed_rounded,
                        color: AppColors.gold,
                      ),
                      title: const Text('High Refresh Rate'),
                      subtitle: const Text(
                        'Request the fastest display mode available',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      value: settingsController.highRefreshRateEnabled.value,
                      onChanged: settingsController.setHighRefreshRateEnabled,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            SoniqCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  Obx(
                    () => SwitchListTile(
                      activeTrackColor: AppColors.primary,
                      secondary: const Icon(
                        Icons.vibration_rounded,
                        color: AppColors.primary,
                      ),
                      title: const Text('Haptic Feedback'),
                      subtitle: const Text(
                        'Use subtle vibration for supported player actions',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      value: settingsController.hapticFeedbackEnabled.value,
                      onChanged: settingsController.setHapticFeedbackEnabled,
                    ),
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  Obx(
                    () => SwitchListTile(
                      activeTrackColor: AppColors.primary,
                      secondary: const Icon(
                        Icons.swipe_rounded,
                        color: AppColors.cyan,
                      ),
                      title: const Text('Player Gestures'),
                      subtitle: const Text(
                        'Swipe left or right in Now Playing to change tracks',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      value: settingsController.playerGesturesEnabled.value,
                      onChanged: settingsController.setPlayerGesturesEnabled,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            SoniqCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.folder_off_rounded,
                      color: AppColors.gold,
                    ),
                    title: const Text('Exclude Directories'),
                    subtitle: Obx(
                      () => Text(
                        settingsController.excludedDirectories.isEmpty
                            ? 'Choose folders to skip during library scans'
                            : '${settingsController.excludedDirectories.length} folder${settingsController.excludedDirectories.length == 1 ? '' : 's'} excluded',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                    ),
                    onTap: () => _showExcludedDirectoriesDialog(
                      context,
                      settingsController,
                    ),
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.memory_rounded,
                      color: AppColors.cyan,
                    ),
                    title: const Text('Device Capabilities'),
                    subtitle: const Text(
                      'Formats, local storage, outputs and device details',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                    ),
                    onTap: () => Get.to(() => const DeviceCapabilitiesView()),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            _buildSectionHeader('Listening Analytics & Insights'),

            SoniqCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.insights_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    title: const Text(
                      'Listening Analytics Dashboard',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'View personal music statistics, top songs, trends and streaks',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                    ),
                    onTap: () => Get.to(() => const AnalyticsDashboardView()),
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.privacy_tip_rounded,
                        color: AppColors.gold,
                        size: 22,
                      ),
                    ),
                    title: const Text(
                      'Analytics Privacy & History',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Manage on-device tracking, export JSON data, or clear history',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                    ),
                    onTap: () => Get.to(() => const AnalyticsSettingsView()),
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
                  child: const Icon(
                    Icons.share_rounded,
                    color: AppColors.gold,
                    size: 22,
                  ),
                ),
                title: const Text(
                  'Share App (as APK)',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Export and send the SONIQ .apk file via Quick Share, Bluetooth, or messaging apps',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                trailing: Obx(
                  () => settingsController.isSharingApk.value
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.gold,
                          ),
                        )
                      : const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: AppColors.gold,
                          size: 16,
                        ),
                ),
                onTap: () => settingsController.shareAppAsApk(),
              ),
            ),

            const SizedBox(height: 20),

            _buildSectionHeader('About'),

            SoniqCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.secondary,
                ),
                title: const Text('About SONIQ'),
                subtitle: const Text(
                  'Version 1.0.0 • Architecture & Credits',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
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
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(width: 1, height: 32, color: AppColors.border);
  }

  void _showExcludedDirectoriesDialog(
    BuildContext context,
    SettingsController controller,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Excluded Directories'),
        content: SizedBox(
          width: double.maxFinite,
          child: Obx(() {
            if (controller.excludedDirectories.isEmpty) {
              return const Text(
                'No folders are excluded yet.',
                style: TextStyle(color: AppColors.textMuted),
              );
            }
            return ListView(
              shrinkWrap: true,
              children: controller.excludedDirectories.map((directory) {
                final parts = directory
                    .split(RegExp(r'[/\\]'))
                    .where((part) => part.isNotEmpty)
                    .toList();
                final name = parts.isEmpty ? directory : parts.last;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.folder_rounded,
                    color: AppColors.gold,
                  ),
                  title: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    directory,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    tooltip: 'Remove exclusion',
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textMuted,
                    ),
                    onPressed: () =>
                        controller.removeExcludedDirectory(directory),
                  ),
                );
              }).toList(),
            );
          }),
        ),
        actions: [
          TextButton.icon(
            onPressed: controller.addExcludedDirectory,
            icon: const Icon(Icons.create_new_folder_outlined),
            label: const Text('Add folder'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
