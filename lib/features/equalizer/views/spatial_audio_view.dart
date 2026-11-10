import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../controllers/equalizer_controller.dart';

class SpatialAudioView extends StatelessWidget {
  const SpatialAudioView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<EqualizerController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Spatial Audio & Output'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Connected Device Card
              Obx(() => _buildDeviceCard(controller.connectedDevice.value)),

              const SizedBox(height: 20),

              // 2. Spatial Sound Modes (Mono, Stereo, Wide Stereo, Virtual Surround, Headphone Spatial)
              const Text('SOUNDSTAGE & SPATIAL MODE', style: AppTypography.labelLarge),
              const SizedBox(height: 10),
              Obx(() {
                final currentMode = controller.spatialMode.value;
                return Column(
                  children: [
                    _buildModeTile(
                      controller,
                      id: 'stereo',
                      title: 'Original Stereo',
                      subtitle: 'Direct high-fidelity left and right separation',
                      icon: Icons.headphones_rounded,
                      isSelected: currentMode == 'stereo',
                    ),
                    const SizedBox(height: 8),
                    _buildModeTile(
                      controller,
                      id: 'wide_stereo',
                      title: 'Wide Stereo',
                      subtitle: 'Expanded acoustic stereo field with center preservation',
                      icon: Icons.surround_sound_rounded,
                      isSelected: currentMode == 'wide_stereo',
                    ),
                    const SizedBox(height: 8),
                    _buildModeTile(
                      controller,
                      id: 'headphone_spatial',
                      title: 'Headphone Spatial Sound',
                      subtitle: 'Binaural 3D spatial stage for in-ear and over-ear headphones',
                      icon: Icons.spatial_audio_rounded,
                      isSelected: currentMode == 'headphone_spatial',
                    ),
                    const SizedBox(height: 8),
                    _buildModeTile(
                      controller,
                      id: 'virtual_surround',
                      title: 'Virtual Surround',
                      subtitle: 'Transaural simulated 3D acoustic field for device speakers',
                      icon: Icons.speaker_group_rounded,
                      isSelected: currentMode == 'virtual_surround',
                    ),
                    const SizedBox(height: 8),
                    _buildModeTile(
                      controller,
                      id: 'mono',
                      title: 'Balanced Mono Downmix',
                      subtitle: 'Combines L+R into a unified balanced channel',
                      icon: Icons.volume_down_rounded,
                      isSelected: currentMode == 'mono',
                    ),
                  ],
                );
              }),

              const SizedBox(height: 24),

              // 3. Fine-Tune Sliders (Stereo Width, Surround Intensity, Channel Balance)
              const Text('FINE-TUNE SPATIAL PARAMETERS', style: AppTypography.labelLarge),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border, width: 0.8),
                ),
                child: Column(
                  children: [
                    // Stereo Width (0% to 150%)
                    Obx(() => Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Stereo Width', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                                Text('${controller.stereoWidth.value}%',
                                    style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
                              ],
                            ),
                            Slider(
                              value: controller.stereoWidth.value.toDouble(),
                              min: 0,
                              max: 150,
                              activeColor: AppColors.gold,
                              inactiveColor: AppColors.surfaceHighlight,
                              onChanged: (val) => controller.setStereoWidth(val.toInt()),
                            ),
                          ],
                        )),

                    const SizedBox(height: 12),

                    // Virtual Surround Intensity (0% to 100%)
                    Obx(() => Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Virtualizer Intensity', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                                Text('${(controller.virtualizer.value * 100).toInt()}%',
                                    style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
                              ],
                            ),
                            Slider(
                              value: controller.virtualizer.value,
                              min: 0.0,
                              max: 1.0,
                              activeColor: AppColors.gold,
                              inactiveColor: AppColors.surfaceHighlight,
                              onChanged: (val) => controller.setVirtualizer(val),
                            ),
                          ],
                        )),

                    const SizedBox(height: 12),

                    // Left / Right Channel Balance (-1.0 to +1.0)
                    Obx(() {
                      final bal = controller.balance.value;
                      final balText = bal == 0.0
                          ? 'Center'
                          : (bal < 0
                              ? 'L ${(bal.abs() * 100).toInt()}%'
                              : 'R ${(bal * 100).toInt()}%');
                      return Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Channel Balance', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                              Text(balText, style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          Slider(
                            value: bal,
                            min: -1.0,
                            max: 1.0,
                            activeColor: AppColors.gold,
                            inactiveColor: AppColors.surfaceHighlight,
                            onChanged: (val) {
                              // Snap to 0
                              controller.setBalance(val.abs() < 0.08 ? 0.0 : val);
                            },
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 4. Limiter & Peak Protection
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 0.8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Audio Limiter & Clip Guard',
                            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                        SizedBox(height: 2),
                        Text('Prevents distortion when bass boost is pushed high',
                            style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                    Obx(() => Switch(
                          value: controller.isLimiterEnabled.value,
                          activeThumbColor: AppColors.gold,
                          onChanged: (val) => controller.toggleLimiter(val),
                        )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceCard(String device) {
    IconData icon;
    String name;
    String desc;

    switch (device) {
      case 'bluetooth':
        icon = Icons.bluetooth_audio_rounded;
        name = 'Bluetooth Audio';
        desc = 'Wireless A2DP • Spatial audio tuned for wireless headphones';
        break;
      case 'wired_headphones':
        icon = Icons.headphones_rounded;
        name = 'Wired Headphones / AUX';
        desc = 'Analogue 3.5mm line-out • Binaural spatial stage active';
        break;
      case 'usb':
        icon = Icons.usb_rounded;
        name = 'USB DAC / Audio Interface';
        desc = 'Direct digital output stream • Bit-perfect path';
        break;
      default:
        icon = Icons.speaker_rounded;
        name = 'Built-in Device Speaker';
        desc = 'Phone speaker optimization • Transaural limiter active';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.1),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.gold.withValues(alpha: 0.15),
            ),
            child: Icon(icon, color: AppColors.gold, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('ACTIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF10B981))),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(desc, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTile(
    EqualizerController controller, {
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => controller.setSpatialMode(id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceHighlight : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.gold : AppColors.border,
            width: isSelected ? 1.4 : 0.8,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppColors.gold : AppColors.textMuted, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: isSelected ? Colors.white : AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle_rounded, color: AppColors.gold, size: 20),
          ],
        ),
      ),
    );
  }
}
