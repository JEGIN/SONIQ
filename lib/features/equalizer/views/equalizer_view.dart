import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/models/equalizer_preset_model.dart';
import '../controllers/equalizer_controller.dart';
import 'widgets/spectrum_visualizer_widget.dart';
import 'widgets/vertical_fader.dart';
import 'widgets/rotary_knob.dart';
import 'widgets/preset_selector_dialog.dart';
import 'spatial_audio_view.dart';

class EqualizerView extends StatelessWidget {
  const EqualizerView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<EqualizerController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Header Toolbar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  const Text('Equalizer', style: AppTypography.displayLarge),
                  const Spacer(),

                  // Preset Button
                  Obx(() => TextButton.icon(
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.surfaceElevated,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: AppColors.border, width: 0.8),
                          ),
                        ),
                        icon: const Icon(Icons.tune_rounded, color: AppColors.gold, size: 16),
                        label: Text(
                          controller.currentPreset.value.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: () => PresetSelectorDialog.show(context, controller),
                      )),

                  const SizedBox(width: 8),

                  // Spatial Sound shortcut
                  IconButton(
                    icon: const Icon(Icons.spatial_audio_rounded, color: AppColors.gold, size: 22),
                    tooltip: 'Spatial Audio',
                    onPressed: () => Get.to(() => const SpatialAudioView()),
                  ),

                  // Master EQ Switch
                  Obx(() => Switch(
                        value: controller.isEqualizerEnabled.value,
                        activeThumbColor: AppColors.gold,
                        onChanged: (val) => controller.toggleEqualizer(val),
                      )),
                ],
              ),
            ),

            // 2. Hardware Audio Profile Selector (Phone Speaker, Headphones, Bluetooth, Renault Triber)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Obx(() {
                final currentProf = controller.activeProfile.value;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildProfilePill(
                        label: 'Speaker',
                        icon: Icons.phone_android_rounded,
                        isSelected: currentProf == 'speaker',
                        onTap: () => controller.switchAudioProfile('speaker'),
                      ),
                      const SizedBox(width: 6),
                      _buildProfilePill(
                        label: 'Headphones',
                        icon: Icons.headphones_rounded,
                        isSelected: currentProf == 'headphones',
                        onTap: () => controller.switchAudioProfile('headphones'),
                      ),
                      const SizedBox(width: 6),
                      _buildProfilePill(
                        label: 'Bluetooth',
                        icon: Icons.bluetooth_audio_rounded,
                        isSelected: currentProf == 'bluetooth',
                        onTap: () => controller.switchAudioProfile('bluetooth'),
                      ),
                      const SizedBox(width: 6),
                      _buildProfilePill(
                        label: 'Renault Triber',
                        icon: Icons.directions_car_rounded,
                        isSelected: currentProf == 'renault_triber',
                        isCar: true,
                        onTap: () => controller.switchAudioProfile('renault_triber'),
                      ),
                    ],
                  ),
                );
              }),
            ),

            // 3. Real-time Audio Spectrum Visualizer (60fps FFT)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Obx(() => SpectrumVisualizerWidget(
                    magnitudes: controller.spectrumMagnitudes,
                    height: 52,
                    isPlaying: controller.isEqualizerEnabled.value,
                  )),
            ),

            const SizedBox(height: 6),

            // 3. 10-Band Graphic Equalizer Faders + Preamp Fader
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border, width: 0.8),
                ),
                child: Row(
                  children: [
                    // Preamp Fader (-6dB to +6dB)
                    Obx(() => VerticalFader(
                          value: controller.preamp.value,
                          min: -6.0,
                          max: 6.0,
                          label: 'Preamp',
                          activeColor: AppColors.primary,
                          onChanged: (val) => controller.setPreamp(val),
                        )),

                    // Vertical Separator
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                      width: 1,
                      color: AppColors.border,
                    ),

                    // 10 Horizontal Scrolling Equalizer Bands
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: List.generate(10, (index) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 5.0),
                              child: Obx(() => VerticalFader(
                                    value: controller.gains[index],
                                    label: EqualizerController.bandLabels[index],
                                    activeColor: AppColors.gold,
                                    onChanged: (val) => controller.setBandGain(index, val),
                                  )),
                            );
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 4),

            // 4. Poweramp-style Sound Enhancement Panel (Bass Boost & Treble Rotary Knobs)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border, width: 0.8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Bass Boost Rotary Knob
                      Obx(() => RotaryKnob(
                            value: controller.bassBoost.value,
                            label: 'Bass Boost',
                            valueDisplay: '${(controller.bassBoost.value * 100).toInt()}%',
                            activeColor: AppColors.primary,
                            onChanged: (val) => controller.setBassBoost(val),
                          )),

                      // Quick Action Buttons (Limit, Tone, Reset)
                      Column(
                        children: [
                          // Preset button
                          _buildSmallButton(
                            label: 'Presets',
                            icon: Icons.tune_rounded,
                            onTap: () => PresetSelectorDialog.show(context, controller),
                          ),
                          const SizedBox(height: 8),
                          // Reset to Flat button
                          _buildSmallButton(
                            label: 'Reset',
                            icon: Icons.refresh_rounded,
                            onTap: () => controller.resetToFlat(),
                          ),
                          const SizedBox(height: 8),
                          // Spatial Sound button
                          _buildSmallButton(
                            label: 'Spatial',
                            icon: Icons.surround_sound_rounded,
                            onTap: () => Get.to(() => const SpatialAudioView()),
                          ),
                        ],
                      ),

                      // Treble Rotary Knob
                      Obx(() {
                        final tr = controller.treble.value;
                        final norm = ((tr + 12.0) / 24.0).clamp(0.0, 1.0);
                        return RotaryKnob(
                          value: norm,
                          label: 'Treble',
                          valueDisplay: tr > 0 ? '+${tr.toStringAsFixed(1)} dB' : '${tr.toStringAsFixed(1)} dB',
                          activeColor: AppColors.gold,
                          onChanged: (val) {
                            final db = -12.0 + val * 24.0;
                            controller.setTreble(db);
                          },
                        );
                      }),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Preset Quick Pills
                  Obx(() {
                    final isTriber = controller.activeProfile.value == 'renault_triber';
                    final pillNames = isTriber
                        ? ['Renault Triber Balanced', 'Deep Bass (Road Boost)', 'Vocal Clarity', 'Pop', 'Rock', 'Classical', 'Acoustic']
                        : ['Flat', 'Pop', 'Rock', 'Classical', 'Hip-Hop', 'Deep Bass', 'Vocal'];

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          if (isTriber) ...[
                            // Road Noise Compensation Toggle
                            GestureDetector(
                              onTap: () => controller.toggleRoadNoiseCompensation(),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: controller.isRoadNoiseCompensationEnabled.value
                                      ? const Color(0xFF2E2200)
                                      : const Color(0xFF1E202B),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: controller.isRoadNoiseCompensationEnabled.value
                                        ? AppColors.gold
                                        : AppColors.border,
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.speed_rounded,
                                      size: 13,
                                      color: controller.isRoadNoiseCompensationEnabled.value
                                          ? AppColors.gold
                                          : AppColors.textMuted,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Road Boost',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: controller.isRoadNoiseCompensationEnabled.value
                                            ? AppColors.gold
                                            : AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          ...pillNames.map((name) {
                            final isSelected = controller.currentPreset.value.name == name;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  final pool = isTriber
                                      ? EqualizerPreset.renaultTriberPresets
                                      : EqualizerPreset.builtInPresets;
                                  final match = pool.firstWhere(
                                    (p) => p.name == name,
                                    orElse: () => pool.first,
                                  );
                                  controller.applyPreset(match);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.gold : const Color(0xFF1E202B),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected ? AppColors.gold : AppColors.border,
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      color: isSelected ? Colors.black : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePill({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    bool isCar = false,
  }) {
    final activeBg = isCar ? const Color(0xFF332600) : AppColors.gold;
    final activeBorder = isCar ? AppColors.gold : AppColors.gold;
    final activeTextColor = isCar ? AppColors.gold : Colors.black;
    final activeIconColor = isCar ? AppColors.gold : Colors.black;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeBorder : AppColors.border,
            width: isSelected ? 1.2 : 0.8,
          ),
          boxShadow: isSelected && isCar
              ? [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? activeIconColor : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? activeTextColor : AppColors.textSecondary,
              ),
            ),
            if (isCar && isSelected) ...[
              const SizedBox(width: 4),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSmallButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1E202B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.gold),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
