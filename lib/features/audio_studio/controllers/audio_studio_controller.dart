import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/models/song_model.dart';
import '../../../core/models/ringtone_model.dart';
import '../../../core/services/waveform_service.dart';
import '../../../core/services/audio_trimmer_service.dart';
import '../../../core/services/ringtone_service.dart';
import '../../library/controllers/library_controller.dart';
import '../../player/controllers/player_controller.dart';
import '../../ringtone/views/ringtone_export_dialog.dart';

class AudioStudioController extends GetxController {
  final WaveformService waveformService = WaveformService();
  final AudioTrimmerService trimmerService = AudioTrimmerService();
  final RingtoneService ringtoneService = RingtoneService();
  final LibraryController libraryController = Get.find<LibraryController>();

  final AudioPlayer _previewPlayer = AudioPlayer();

  final Rx<SongModel?> selectedSong = Rx<SongModel?>(null);
  final RxList<double> waveformPeaks = <double>[].obs;
  final RxBool isLoadingWaveform = false.obs;

  // Trimming timestamps in milliseconds
  final RxInt startMs = 0.obs;
  final RxInt endMs = 30000.obs;
  int get lengthMs => (endMs.value - startMs.value).clamp(0, totalDurationMs);
  int get totalDurationMs => selectedSong.value?.durationMs ?? 30000;

  // Preview playback state
  final RxBool isPreviewPlaying = false.obs;
  final RxInt previewCurrentMs = 0.obs;
  StreamSubscription? _previewPositionSub;

  // Zoom control
  final RxDouble zoomLevel = 1.0.obs; // 1.0x to 4.0x
  final RxDouble scrollOffset = 0.0.obs;

  // Export progress
  final RxBool isExporting = false.obs;
  final RxDouble exportProgress = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    _initPreviewPlayer();

    // Auto-select first song if available
    if (libraryController.allSongs.isNotEmpty) {
      loadSong(libraryController.allSongs.first);
    }
  }

  void _initPreviewPlayer() {
    _previewPlayer.playerStateStream.listen((state) {
      isPreviewPlaying.value = state.playing;
    });

    // If main music player starts playing, automatically stop/pause the preview
    try {
      final playerController = Get.find<AudioPlayerController>();
      playerController.isPlaying.listen((playing) {
        if (playing && isPreviewPlaying.value) {
          _previewPlayer.pause();
        }
      });
    } catch (_) {}

    _previewPositionSub = _previewPlayer.positionStream.listen((pos) {
      final current = pos.inMilliseconds;
      previewCurrentMs.value = current;

      // Stop preview when reaching end boundary
      if (current >= endMs.value) {
        _previewPlayer.pause();
        _previewPlayer.seek(Duration(milliseconds: startMs.value));
      }
    });
  }

  /// Loads a new song into Audio Studio
  Future<void> loadSong(SongModel song) async {
    await stopPreview();
    selectedSong.value = song;
    isLoadingWaveform.value = true;
    zoomLevel.value = 1.0;
    scrollOffset.value = 0.0;

    // Default start at 0, end at min(30s, totalDuration)
    startMs.value = 0;
    endMs.value = song.durationMs > 30000 ? 30000 : song.durationMs;
    previewCurrentMs.value = startMs.value;

    try {
      final peaks = await waveformService.getWaveformPeaks(song, samples: 160);
      waveformPeaks.assignAll(peaks);

      // Pre-set preview player source
      if (song.dataPath.isNotEmpty) {
        await _previewPlayer.setFilePath(song.dataPath);
      }
    } catch (e) {
      debugPrint('SONIQ Studio: Error loading song waveform: $e');
    } finally {
      isLoadingWaveform.value = false;
    }
  }

  /// Sets selection start time with bounds check
  void setStartMs(int ms) {
    if (ms < 0) ms = 0;
    if (ms >= endMs.value - 1000) {
      ms = (endMs.value - 1000).clamp(0, totalDurationMs);
    }
    startMs.value = ms;
    if (previewCurrentMs.value < startMs.value) {
      previewCurrentMs.value = startMs.value;
    }
  }

  /// Sets selection end time with bounds check
  void setEndMs(int ms) {
    if (ms > totalDurationMs) ms = totalDurationMs;
    if (ms <= startMs.value + 1000) {
      ms = (startMs.value + 1000).clamp(0, totalDurationMs);
    }
    endMs.value = ms;
    if (previewCurrentMs.value > endMs.value) {
      previewCurrentMs.value = endMs.value;
    }
  }

  /// Nudge selection bounds precisely (e.g. +/- 100ms or 500ms)
  void nudgeStart(int deltaMs) {
    setStartMs(startMs.value + deltaMs);
  }

  void nudgeEnd(int deltaMs) {
    setEndMs(endMs.value + deltaMs);
  }

  /// Reset selection to first 30 seconds
  void resetSelection() {
    startMs.value = 0;
    endMs.value = totalDurationMs > 30000 ? 30000 : totalDurationMs;
  }

  /// Play or pause the preview of selected region
  Future<void> togglePreview() async {
    if (selectedSong.value == null) return;

    if (isPreviewPlaying.value) {
      await _previewPlayer.pause();
    } else {
      // Pause main player to avoid dual audio playback clashing
      try {
        final playerController = Get.find<AudioPlayerController>();
        if (playerController.isPlaying.value) {
          await playerController.audioHandler.pause();
        }
      } catch (_) {}

      // Seek to start boundary before playing
      if (_previewPlayer.position.inMilliseconds < startMs.value ||
          _previewPlayer.position.inMilliseconds >= endMs.value) {
        await _previewPlayer.seek(Duration(milliseconds: startMs.value));
      }
      await _previewPlayer.play();
    }
  }

  Future<void> stopPreview() async {
    if (isPreviewPlaying.value) {
      await _previewPlayer.stop();
    }
  }

  /// Zoom controls
  void setZoom(double zoom) {
    zoomLevel.value = zoom.clamp(1.0, 4.0);
  }

  void zoomIn() {
    setZoom(zoomLevel.value + 0.5);
  }

  void zoomOut() {
    setZoom(zoomLevel.value - 0.5);
  }

  void resetZoom() {
    zoomLevel.value = 1.0;
  }

  /// Open Ringtone Export Dialog
  void openExportDialog(BuildContext context) {
    if (selectedSong.value == null) return;
    stopPreview();

    showDialog(
      context: context,
      builder: (_) => RingtoneExportDialog(
        originalSong: selectedSong.value!,
        startMs: startMs.value,
        endMs: endMs.value,
        durationMs: lengthMs,
      ),
    );
  }

  /// Perform export and set ringtone
  Future<bool> exportRingtone({
    required String customTitle,
    required RingtoneTarget target,
  }) async {
    final song = selectedSong.value;
    if (song == null) return false;

    isExporting.value = true;
    exportProgress.value = 0.2;

    try {
      exportProgress.value = 0.5;
      final exportedPath = await trimmerService.trimAudio(
        sourcePath: song.dataPath,
        outputName: customTitle,
        startMs: startMs.value,
        endMs: endMs.value,
        totalDurationMs: song.durationMs,
      );

      exportProgress.value = 0.8;

      final ringtone = RingtoneModel(
        id: 'ring_${DateTime.now().millisecondsSinceEpoch}',
        title: customTitle,
        originalSongTitle: song.title,
        filePath: exportedPath,
        durationMs: lengthMs,
        startMs: startMs.value,
        endMs: endMs.value,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        target: target,
      );

      await ringtoneService.recordSavedRingtone(ringtone);

      // Attempt system ringtone assignment
      final systemSetSuccess = await ringtoneService.setSystemRingtone(
        filePath: exportedPath,
        target: target,
      );

      exportProgress.value = 1.0;
      return systemSetSuccess;
    } catch (e) {
      debugPrint('SONIQ Studio: Export failed: $e');
      rethrow;
    } finally {
      isExporting.value = false;
      exportProgress.value = 0.0;
    }
  }

  @override
  void onClose() {
    _previewPositionSub?.cancel();
    _previewPlayer.dispose();
    super.onClose();
  }
}
