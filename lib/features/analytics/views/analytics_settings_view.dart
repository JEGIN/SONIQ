import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../app/localization/soniq_localizations.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/soniq_card.dart';
import '../controllers/analytics_controller.dart';

class AnalyticsSettingsView extends StatelessWidget {
  const AnalyticsSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AnalyticsController>();
    final strings = SoniqLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          strings.text('analyticsPrivacy'),
          style: AppTypography.headlineMedium,
        ),
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
              border: Border.all(
                color: const Color(0xFF00E676).withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_rounded, color: Color(0xFF00E676), size: 24),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.text('onDevicePrivate'),
                        style: TextStyle(
                          color: Color(0xFF00E676),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        strings.text('analyticsPrivacyDescription'),
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Text(
            strings.text('trackingControls'),
            style: const TextStyle(
              color: AppColors.gold,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),

          SoniqCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Obx(
                  () => SwitchListTile(
                    activeTrackColor: AppColors.primary,
                    activeThumbColor: AppColors.gold,
                    secondary: const Icon(
                      Icons.history_rounded,
                      color: AppColors.gold,
                    ),
                    title: Text(
                      strings.text('recordListeningHistory'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      strings.text('historyPausedDescription'),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                    value: controller.isTrackingEnabled.value,
                    onChanged: (val) => controller.toggleTracking(val),
                  ),
                ),
                const Divider(color: AppColors.border, height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.timer_rounded,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    strings.text('playCountThreshold'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    strings.text('qualifiedPlayThresholdDescription'),
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                  trailing: Obx(
                    () => Text(
                      '${controller.playCountThresholdSeconds.value}s',
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Text(
            strings.text('dataManagement'),
            style: const TextStyle(
              color: AppColors.gold,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),

          SoniqCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.file_download_outlined,
                    color: Color(0xFF00E5FF),
                  ),
                  title: Text(
                    strings.text('exportAnalyticsJson'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    strings.text('exportAnalyticsDescription'),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: AppColors.textMuted,
                    size: 14,
                  ),
                  onTap: () => controller.exportAnalytics(),
                ),
                const Divider(color: AppColors.border, height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.date_range_rounded,
                    color: AppColors.gold,
                  ),
                  title: Text(
                    strings.text('clearSpecificDateRange'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    strings.text('deleteListeningDateRange'),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: AppColors.textMuted,
                    size: 14,
                  ),
                  onTap: () async {
                    final range = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (range != null && context.mounted) {
                      _showConfirmDialog(
                        context,
                        title: strings.text('deleteSelectedRangeTitle'),
                        message: strings
                            .text('deleteSelectedRangeMessage')
                            .replaceAll(
                              '{start}',
                              DateFormat.Md(strings.locale.toString())
                                  .format(range.start),
                            )
                            .replaceAll(
                              '{end}',
                              DateFormat.Md(strings.locale.toString())
                                  .format(range.end),
                            ),
                        onConfirm: () => controller.clearHistoryForRange(
                          range.start,
                          range.end,
                        ),
                      );
                    }
                  },
                ),
                const Divider(color: AppColors.border, height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.delete_forever_rounded,
                    color: Color(0xFFFF5252),
                  ),
                  title: Text(
                    strings.text('deleteAllAnalyticsData'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Color(0xFFFF5252),
                    ),
                  ),
                  subtitle: Text(
                    strings.text('deleteAllAnalyticsSubtitle'),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                  onTap: () => _showConfirmDialog(
                    context,
                    title: strings.text('clearAllAnalyticsTitle'),
                    message: strings.text('clearAllAnalyticsMessage'),
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
    final strings = SoniqLocalizations.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1A2B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 13,
            height: 1.35,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              strings.text('cancel'),
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: Text(
              strings.text('delete'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
