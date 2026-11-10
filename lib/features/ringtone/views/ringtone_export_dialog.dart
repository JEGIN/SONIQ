import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/models/song_model.dart';
import '../../../core/models/ringtone_model.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../../core/widgets/soniq_button.dart';
import '../../audio_studio/controllers/audio_studio_controller.dart';

class RingtoneExportDialog extends StatefulWidget {
  final SongModel originalSong;
  final int startMs;
  final int endMs;
  final int durationMs;

  const RingtoneExportDialog({
    super.key,
    required this.originalSong,
    required this.startMs,
    required this.endMs,
    required this.durationMs,
  });

  @override
  State<RingtoneExportDialog> createState() => _RingtoneExportDialogState();
}

class _RingtoneExportDialogState extends State<RingtoneExportDialog> {
  late final TextEditingController _nameController;
  RingtoneTarget _selectedTarget = RingtoneTarget.phone;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: '${widget.originalSong.title} (Ringtone)',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleExport() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter a name for the ringtone.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    final studioController = Get.find<AudioStudioController>();

    try {
      final success = await studioController.exportRingtone(
        customTitle: name,
        target: _selectedTarget,
      );

      if (mounted) {
        Navigator.of(context).pop();

        Get.snackbar(
          'Export Complete',
          Platform.isIOS
              ? 'Ringtone exported to Files / GarageBand!'
              : success
                  ? 'Successfully set as your ${_selectedTarget.name} sound!'
                  : 'Ringtone saved to Ringtones/SONIQ folder.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF1B1D26),
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedLen = DurationFormatter.formatPrecision(widget.durationMs);

    return Dialog(
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGlow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.ring_volume_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Export Ringtone',
                    style: AppTypography.headlineMedium,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Name field
            const Text('Ringtone Name', style: AppTypography.labelLarge),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Clip summary info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border, width: 0.8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Selection Length:', style: TextStyle(color: AppColors.textSecondary)),
                  Text(
                    formattedLen,
                    style: const TextStyle(
                      color: AppColors.cyan,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Target Selector (Phone, Notification, Alarm)
            const Text('Set As', style: AppTypography.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildTargetChoice(RingtoneTarget.phone, 'Phone', Icons.phone_in_talk_rounded),
                const SizedBox(width: 8),
                _buildTargetChoice(RingtoneTarget.notification, 'Notice', Icons.notifications_active_rounded),
                const SizedBox(width: 8),
                _buildTargetChoice(RingtoneTarget.alarm, 'Alarm', Icons.alarm_rounded),
              ],
            ),

            if (Platform.isIOS) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHighlight.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'iOS allows sharing to Files or GarageBand to apply as a system ringtone.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ),
            ],

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.red, fontSize: 12),
              ),
            ],

            const SizedBox(height: 24),

            // Actions
            Row(
              children: [
                Expanded(
                  child: SoniqButton(
                    text: 'Cancel',
                    variant: SoniqButtonVariant.secondary,
                    onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SoniqButton(
                    text: 'Export',
                    isLoading: _isProcessing,
                    onPressed: _isProcessing ? null : _handleExport,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetChoice(RingtoneTarget target, String label, IconData icon) {
    final isSelected = _selectedTarget == target;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTarget = target),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: 1.2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? AppColors.primary : AppColors.textMuted,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
