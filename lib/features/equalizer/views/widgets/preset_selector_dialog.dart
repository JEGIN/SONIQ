import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/models/equalizer_preset_model.dart';
import '../../controllers/equalizer_controller.dart';

class PresetSelectorDialog extends StatelessWidget {
  final EqualizerController controller;

  const PresetSelectorDialog({super.key, required this.controller});

  static void show(BuildContext context, EqualizerController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PresetSelectorDialog(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    final carPresets = EqualizerPreset.renaultTriberPresets;
    final studioPresets = EqualizerPreset.builtInPresets;
    final customPresets = controller.customPresets;

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
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
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Equalizer Presets', style: AppTypography.headlineMedium),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_rounded, color: AppColors.gold),
                      tooltip: 'Save Custom Preset',
                      onPressed: () => _showSavePresetDialog(context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(color: AppColors.border, height: 1),

          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // SECTION 1: RENAULT TRIBER CABIN TUNED PRESETS
                _buildSectionHeader('RENAULT TRIBER CABIN PRESETS', Icons.directions_car_rounded, AppColors.gold),
                ...carPresets.map((preset) => _buildPresetTile(context, preset, isTriber: true)),

                const SizedBox(height: 12),
                // SECTION 2: STUDIO PRESETS
                _buildSectionHeader('STUDIO PRESETS', Icons.graphic_eq_rounded, AppColors.primary),
                ...studioPresets.map((preset) => _buildPresetTile(context, preset)),

                if (customPresets.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  // SECTION 3: CUSTOM PRESETS
                  _buildSectionHeader('MY CUSTOM PRESETS', Icons.tune_rounded, AppColors.textSecondary),
                  ...customPresets.map((preset) => _buildPresetTile(context, preset)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetTile(BuildContext context, EqualizerPreset preset, {bool isTriber = false}) {
    final isSelected = controller.currentPreset.value.name == preset.name;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? AppColors.gold : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppColors.gold : AppColors.textMuted,
            width: 2,
          ),
        ),
      ),
      title: Text(
        preset.name,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected ? AppColors.gold : AppColors.textPrimary,
        ),
      ),
      subtitle: isTriber
          ? const Text(
              'Renault 4-speaker cabin compensation',
              style: TextStyle(fontSize: 10, color: AppColors.textMuted),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isTriber)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2000),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.5), width: 0.6),
              ),
              child: const Text('TRIBER', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: AppColors.gold)),
            ),
          if (preset.isCustom) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceHighlight,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('CUSTOM', style: TextStyle(fontSize: 9, color: AppColors.gold)),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary, size: 18),
              tooltip: 'Rename Preset',
              onPressed: () => _showRenamePresetDialog(context, preset.name),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.red, size: 18),
              tooltip: 'Delete Preset',
              onPressed: () {
                controller.deleteCustomPreset(preset.name);
                Navigator.pop(context);
              },
            ),
          ],
        ],
      ),
      onTap: () {
        controller.applyPreset(preset);
        if (isTriber && controller.activeProfile.value != 'renault_triber') {
          controller.activeProfile.value = 'renault_triber';
        }
        Navigator.pop(context);
      },
    );
  }

  void _showSavePresetDialog(BuildContext context) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Save Preset', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter preset name...',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
            child: const Text('Save', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
            onPressed: () {
              final name = textController.text.trim();
              if (name.isNotEmpty) {
                controller.saveCustomPreset(name);
                Navigator.pop(ctx);
                Navigator.pop(context); // close sheet
              }
            },
          ),
        ],
      ),
    );
  }

  void _showRenamePresetDialog(BuildContext context, String currentName) {
    final textController = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Rename Preset', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'New preset name...',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
            child: const Text('Rename', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
            onPressed: () {
              final newName = textController.text.trim();
              if (newName.isNotEmpty && newName != currentName) {
                controller.renameCustomPreset(currentName, newName);
                Navigator.pop(ctx);
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }
}
