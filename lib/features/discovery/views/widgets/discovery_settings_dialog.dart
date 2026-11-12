import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/models/recommendation_model.dart';
import '../../../../core/services/music_discovery_service.dart';
import '../../controllers/discovery_controller.dart';

class DiscoverySettingsDialog extends StatefulWidget {
  const DiscoverySettingsDialog({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const DiscoverySettingsDialog(),
    );
  }

  @override
  State<DiscoverySettingsDialog> createState() => _DiscoverySettingsDialogState();
}

class _DiscoverySettingsDialogState extends State<DiscoverySettingsDialog> {
  final discoveryCtrl = Get.find<DiscoveryController>();
  final discoveryService = MusicDiscoveryService();

  late double _familiarity;
  late int _maxTracksPerArtist;
  late bool _enableAnalysis;

  @override
  void initState() {
    super.initState();
    final s = discoveryCtrl.settings.value;
    _familiarity = s.familiarityRatio;
    _maxTracksPerArtist = s.maxTracksPerArtist;
    _enableAnalysis = s.enableDiscoveryAnalysis;
  }

  Future<void> _saveSettings() async {
    final updated = RecommendationSettings(
      enableDiscoveryAnalysis: _enableAnalysis,
      familiarityRatio: _familiarity,
      maxTracksPerArtist: _maxTracksPerArtist,
    );
    await discoveryCtrl.saveSettings(updated);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final sheetHeight = MediaQuery.of(context).size.height * 0.85;

    return Material(
      color: Colors.transparent,
      child: Container(
        height: sheetHeight,
        decoration: const BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  const Text('Discovery & Privacy Settings', style: AppTypography.headlineMedium),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(color: AppColors.border, height: 1),

            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  // Enable Analysis Toggle
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: AppColors.gold,
                    activeTrackColor: AppColors.gold.withValues(alpha: 0.3),
                    title: const Text('Music Intelligence Analysis', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    subtitle: const Text(
                      'Analyze tempo, acoustic features and listening sessions locally on-device. Zero cloud or network transmission.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                    value: _enableAnalysis,
                    onChanged: (val) => setState(() => _enableAnalysis = val),
                  ),

                  const SizedBox(height: 16),
                  const Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: 16),

                  // Familiarity vs Discovery Slider
                  Text(
                    'Mix Balance: ${(_familiarity * 100).toInt()}% Familiar • ${((1.0 - _familiarity) * 100).toInt()}% Discovery',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Balance familiar top plays against deep library cuts in Daily Mixes.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  Slider(
                    value: _familiarity,
                    min: 0.2,
                    max: 0.9,
                    divisions: 7,
                    activeColor: AppColors.gold,
                    inactiveColor: AppColors.surfaceHighlight,
                    label: '${(_familiarity * 100).toInt()}% Familiar',
                    onChanged: (val) => setState(() => _familiarity = val),
                  ),

                  const SizedBox(height: 16),
                  const Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: 16),

                  // Max tracks per artist
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Artist Diversity Control', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          Text('Maximum songs per artist in a mix', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ],
                      ),
                      DropdownButton<int>(
                        value: _maxTracksPerArtist,
                        dropdownColor: const Color(0xFF1E202B),
                        style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700),
                        items: [1, 2, 3, 4, 5].map((i) => DropdownMenuItem(value: i, child: Text('$i tracks'))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _maxTracksPerArtist = val);
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: 16),

                  // Active Exclusions Section
                  const Text('Active Exclusions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),

                  Obx(() {
                    final fb = discoveryCtrl.feedback.value;
                    final hasExclusions = fb.excludedArtists.isNotEmpty || fb.excludedSongIds.isNotEmpty;

                    if (!hasExclusions) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No artists or songs currently excluded.',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                        ),
                      );
                    }

                    return Column(
                      children: [
                        ...fb.excludedArtists.map((artist) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.person_off_rounded, color: AppColors.red, size: 20),
                              title: Text(artist, style: const TextStyle(color: Colors.white, fontSize: 13)),
                              trailing: IconButton(
                                icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 18),
                                onPressed: () => discoveryCtrl.removeExclusion(artist),
                              ),
                            )),
                        ...fb.excludedSongIds.map((songId) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.block_rounded, color: AppColors.red, size: 20),
                              title: Text('Song ID: $songId', style: const TextStyle(color: Colors.white, fontSize: 13)),
                              trailing: IconButton(
                                icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 18),
                                onPressed: () => discoveryCtrl.removeExclusion(songId),
                              ),
                            )),
                      ],
                    );
                  }),

                  const SizedBox(height: 24),

                  // Reset Preferences Button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.red,
                      side: const BorderSide(color: AppColors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Reset All Discovery Preferences'),
                    onPressed: () {
                      _confirmReset(context);
                    },
                  ),
                ],
              ),
            ),

            // Save changes footer
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _saveSettings,
                  child: const Text(
                    'Save Settings',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E202B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Reset Preferences?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: const Text(
          'This will clear all likes, dislikes, exclusions, and recommendation history. This cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              discoveryCtrl.resetPreferences();
            },
            child: const Text('Reset', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
