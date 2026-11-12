import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/localization/soniq_localizations.dart';
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
    final strings = SoniqLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 4, 16),
              child: Text(
                strings.text('settings'),
                style: AppTypography.displayLarge,
              ),
            ),

            _buildSectionHeader(strings.text('languageRegion')),
            SoniqCard(
              padding: EdgeInsets.zero,
              child: Obx(
                () => ListTile(
                  leading: const Icon(
                    Icons.language_rounded,
                    color: AppColors.cyan,
                  ),
                  title: Text(strings.text('language')),
                  subtitle: Text(
                    strings.text('languageHelp'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 112),
                        child: Text(
                          settingsController.languageCode.value == 'system'
                              ? strings.text('systemLanguage')
                              : SoniqLocalizations.languageName(
                                  settingsController.languageCode.value,
                                ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                  onTap: () => _showLanguagePicker(context, settingsController),
                ),
              ),
            ),

            // Library & Audio Stats Card
            SoniqCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.text('libraryOverview'),
                    style: AppTypography.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact =
                          constraints.maxWidth < 360 ||
                          MediaQuery.textScalerOf(context).scale(14) > 18;
                      return Obx(() {
                        final stats = [
                          _buildStatItem(
                            strings.text('trackCountLabel'),
                            NumberFormat.decimalPattern().format(
                              settingsController.totalIndexedSongs,
                            ),
                          ),
                          _buildStatItem(
                            strings.text('storage'),
                            settingsController.totalLibrarySizeFormatted,
                          ),
                          _buildStatItem(
                            strings.text('ringtones'),
                            NumberFormat.decimalPattern().format(
                              settingsController.totalRingtonesCount,
                            ),
                          ),
                        ];
                        if (compact) {
                          return Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 12,
                            runSpacing: 12,
                            children: stats
                                .map(
                                  (stat) => SizedBox(
                                    width: (constraints.maxWidth - 28) / 2,
                                    child: stat,
                                  ),
                                )
                                .toList(),
                          );
                        }
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            stats[0],
                            _buildStatDivider(),
                            stats[1],
                            _buildStatDivider(),
                            stats[2],
                          ],
                        );
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            _buildSectionHeader(strings.text('libraryAudioIndexing')),

            SoniqCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.sync_rounded,
                      color: AppColors.primary,
                    ),
                    title: Text(strings.text('rescanMusicLibrary')),
                    subtitle: Text(
                      strings.text('rescanMusicLibraryHelp'),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    onTap: () {
                      settingsController.libraryController.scanLibrary();
                      Get.snackbar('Scanning', strings.text('scanningTracks'));
                    },
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.cleaning_services_rounded,
                      color: AppColors.cyan,
                    ),
                    title: Text(strings.text('clearArtworkCache')),
                    subtitle: Obx(
                      () => Text(
                        '${strings.text('cachedArtwork')}: ${settingsController.cacheSizeText.value}',
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

            _buildSectionHeader(strings.text('playbackAudioEngine')),

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
                    title: Text(strings.text('pauseOnDisconnect')),
                    subtitle: Text(
                      strings.text('pauseOnDisconnectHelp'),
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
                    title: Text(strings.text('losslessFrameSlicing')),
                    subtitle: Text(
                      strings.text('losslessFrameSlicingHelp'),
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
                      title: Text(strings.text('filterVoiceCallRecordings')),
                      subtitle: Text(
                        strings.text('filterRecordingsHelp'),
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

            _buildSectionHeader(strings.text('deviceAndPlayback')),

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
                      title: Text(strings.text('autoPlayOnCast')),
                      subtitle: Text(
                        strings.text('autoPlayOnCastHelp'),
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
                      title: Text(strings.text('crossfade')),
                      subtitle: Text(
                        strings.text('crossfadeHelp'),
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
                      title: Text(strings.text('batteryOptimization')),
                      subtitle: Text(
                        strings.text('batteryOptimizationHelp'),
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
                      title: Text(strings.text('highRefreshRate')),
                      subtitle: Text(
                        strings.text('highRefreshRateHelp'),
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
                      title: Text(strings.text('hapticFeedback')),
                      subtitle: Text(
                        strings.text('hapticFeedbackHelp'),
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
                      title: Text(strings.text('playerGestures')),
                      subtitle: Text(
                        strings.text('playerGesturesHelp'),
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
                    title: Text(strings.text('excludeDirectories')),
                    subtitle: Obx(
                      () => Text(
                        settingsController.excludedDirectories.isEmpty
                            ? strings.text('chooseFoldersToSkip')
                            : strings
                                  .text('excludedFoldersCount')
                                  .replaceAll(
                                    '{count}',
                                    NumberFormat.decimalPattern(
                                      strings.locale.toString(),
                                    ).format(
                                      settingsController
                                          .excludedDirectories
                                          .length,
                                    ),
                                  ),
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
                    title: Text(strings.text('deviceCapabilities')),
                    subtitle: Text(
                      strings.text('deviceCapabilitiesHelp'),
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

            _buildSectionHeader(strings.text('listeningAnalyticsInsights')),

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
                    title: Text(
                      strings.text('analyticsDashboard'),
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      strings.text('analyticsDashboardHelp'),
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
                    title: Text(
                      strings.text('analyticsPrivacyHistory'),
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      strings.text('analyticsPrivacyHelp'),
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

            _buildSectionHeader(strings.text('shareDistribute')),

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
                title: Text(
                  strings.text('shareAppApk'),
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  strings.text('shareAppApkHelp'),
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

            _buildSectionHeader(strings.text('about')),

            SoniqCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.secondary,
                ),
                title: Text(strings.text('aboutSoniq')),
                subtitle: Text(
                  strings.text('aboutVersionCredits'),
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

  void _showLanguagePicker(
    BuildContext context,
    SettingsController controller,
  ) {
    const languageCodes = [
      'system',
      'en',
      'ta',
      'hi',
      'ar',
      'es',
      'fr',
      'de',
      'ja',
      'zh',
    ];
    final strings = SoniqLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevated,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.78,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 20),
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 8, bottom: 8),
                child: Text(
                  strings.text('language'),
                  style: AppTypography.headlineSmall,
                ),
              ),
              ...languageCodes.map((code) {
                final title = code == 'system'
                    ? strings.text('systemLanguage')
                    : SoniqLocalizations.languageName(code);
                return Obx(
                  () => Semantics(
                    selected: controller.languageCode.value == code,
                    child: ListTile(
                      minVerticalPadding: 10,
                      title: Text(title),
                      trailing: controller.languageCode.value == code
                          ? const Icon(
                              Icons.check_rounded,
                              color: AppColors.primary,
                            )
                          : null,
                      onTap: () async {
                        await controller.setLanguage(code);
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                      },
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.displayMedium.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
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
    final strings = SoniqLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(strings.text('excludeDirectories')),
        content: SizedBox(
          width: double.maxFinite,
          child: Obx(() {
            if (controller.excludedDirectories.isEmpty) {
              return Text(
                strings.text('noFoldersExcluded'),
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
                    tooltip: strings.text('removeExclusion'),
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
            label: Text(strings.text('addFolder')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(strings.text('done')),
          ),
        ],
      ),
    );
  }
}
