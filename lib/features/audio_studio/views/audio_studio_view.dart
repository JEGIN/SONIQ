import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../../core/widgets/soniq_empty_state.dart';
import '../controllers/audio_studio_controller.dart';
import 'song_picker_bottom_sheet.dart';
import 'widgets/studio_metric_card.dart';
import 'widgets/timeline_ruler.dart';
import 'widgets/waveform_editor_canvas.dart';

class AudioStudioView extends StatelessWidget {
  const AudioStudioView({super.key});

  @override
  Widget build(BuildContext context) {
    final studioController = Get.find<AudioStudioController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Obx(() {
          final song = studioController.selectedSong.value;
          if (song == null) {
            return SoniqEmptyState(
              icon: Icons.graphic_eq_rounded,
              title: 'No Song Selected',
              description: 'Choose any track from your music library to trim and craft custom ringtones.',
              buttonText: 'Select Song',
              onButtonPressed: () => _openSongPicker(context),
            );
          }

          final startFormatted = DurationFormatter.formatPrecision(studioController.startMs.value);
          final endFormatted = DurationFormatter.formatPrecision(studioController.endMs.value);
          final lenFormatted = DurationFormatter.formatPrecision(studioController.lengthMs);
          final isPlaying = studioController.isPreviewPlaying.value;

          return Column(
            children: [
              // 1. Top Header Bar (Song name & Checkmark)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.library_music_rounded, color: AppColors.textPrimary),
                      tooltip: 'Change Song',
                      onPressed: () => _openSongPicker(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _openSongPicker(context),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.headlineSmall.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${song.artist} • Tap to switch',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border, width: 1),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.check_rounded, color: Colors.white, size: 22),
                        tooltip: 'Export Ringtone',
                        onPressed: () => studioController.openExportDialog(context),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 2. Three Metric Cards: Start, End, Len (Matches Reference Image 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    StudioMetricCard(
                      label: 'Start',
                      value: startFormatted,
                      onTap: () => _showManualTimeDialog(context, 'Set Start Time', studioController.startMs.value, (ms) {
                        studioController.setStartMs(ms);
                      }),
                    ),
                    const SizedBox(width: 10),
                    StudioMetricCard(
                      label: 'End',
                      value: endFormatted,
                      onTap: () => _showManualTimeDialog(context, 'Set End Time', studioController.endMs.value, (ms) {
                        studioController.setEndMs(ms);
                      }),
                    ),
                    const SizedBox(width: 10),
                    StudioMetricCard(
                      label: 'Len',
                      value: lenFormatted,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 3. Timeline Ruler & Interactive Waveform Canvas
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final canvasWidth = constraints.maxWidth;
                      return Column(
                        children: [
                          TimelineRuler(
                            totalDurationMs: song.durationMs,
                            zoom: studioController.zoomLevel.value,
                            width: canvasWidth,
                          ),
                          Expanded(
                            child: WaveformEditorCanvas(
                              peaks: studioController.waveformPeaks,
                              totalDurationMs: song.durationMs,
                              startMs: studioController.startMs.value,
                              endMs: studioController.endMs.value,
                              previewCurrentMs: studioController.previewCurrentMs.value,
                              zoom: studioController.zoomLevel.value,
                              onStartChanged: (newStart) => studioController.setStartMs(newStart),
                              onEndChanged: (newEnd) => studioController.setEndMs(newEnd),
                              onRegionMoved: (newStart, newEnd) {
                                studioController.startMs.value = newStart;
                                studioController.endMs.value = newEnd;
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              // 4. Zoom Slider Toolbar (Matches Reference Image 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.zoom_out_rounded, color: AppColors.textSecondary, size: 20),
                      onPressed: () => studioController.zoomOut(),
                    ),
                    Expanded(
                      child: Slider(
                        value: studioController.zoomLevel.value,
                        min: 1.0,
                        max: 4.0,
                        activeColor: AppColors.primary,
                        inactiveColor: AppColors.surfaceHighlight,
                        onChanged: (val) => studioController.setZoom(val),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.zoom_in_rounded, color: AppColors.textSecondary, size: 20),
                      onPressed: () => studioController.zoomIn(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.fit_screen_rounded, color: AppColors.primary, size: 20),
                      tooltip: 'Fit to screen',
                      onPressed: () => studioController.resetZoom(),
                    ),
                  ],
                ),
              ),

              // 5. Precision Step Controls & Main Play/Pause Button (Matches Reference Image 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Start nudge buttons < | >
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary),
                          onPressed: () => studioController.nudgeStart(-200),
                          tooltip: 'Start -200ms',
                        ),
                        Container(
                          width: 1,
                          height: 16,
                          color: AppColors.border,
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                          onPressed: () => studioController.nudgeStart(200),
                          tooltip: 'Start +200ms',
                        ),
                      ],
                    ),

                    // Center glowing Play / Pause Button
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.primaryGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryGlow,
                            blurRadius: 20,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => studioController.togglePreview(),
                          child: Center(
                            child: Icon(
                              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // End nudge buttons < | >
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary),
                          onPressed: () => studioController.nudgeEnd(-200),
                          tooltip: 'End -200ms',
                        ),
                        Container(
                          width: 1,
                          height: 16,
                          color: AppColors.border,
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                          onPressed: () => studioController.nudgeEnd(200),
                          tooltip: 'End +200ms',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  void _openSongPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SongPickerBottomSheet(),
    );
  }

  void _showManualTimeDialog(
    BuildContext context,
    String title,
    int currentMs,
    Function(int newMs) onSave,
  ) {
    final duration = Duration(milliseconds: currentMs);
    final minController = TextEditingController(text: duration.inMinutes.toString());
    final secController = TextEditingController(text: duration.inSeconds.remainder(60).toString());
    final msController = TextEditingController(text: ((currentMs % 1000) ~/ 10).toString());

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text(title, style: AppTypography.headlineMedium),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildTimeInput(minController, 'Min'),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text(':', style: TextStyle(color: Colors.white, fontSize: 20)),
            ),
            _buildTimeInput(secController, 'Sec'),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('.', style: TextStyle(color: Colors.white, fontSize: 20)),
            ),
            _buildTimeInput(msController, 'Ms'),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Set', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            onPressed: () {
              final min = int.tryParse(minController.text) ?? 0;
              final sec = int.tryParse(secController.text) ?? 0;
              final ms = int.tryParse(msController.text) ?? 0;
              final totalMs = (min * 60000) + (sec * 1000) + (ms * 10);
              onSave(totalMs);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTimeInput(TextEditingController controller, String label) {
    return SizedBox(
      width: 55,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
        ],
      ),
    );
  }
}
