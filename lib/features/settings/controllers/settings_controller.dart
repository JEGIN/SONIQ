import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/database/song_cache_service.dart';
import '../../../core/services/audio_dsp_service.dart';
import '../../../core/utils/file_utils.dart';
import '../../library/controllers/library_controller.dart';

class SettingsController extends GetxController {
  final SongCacheService cacheService = SongCacheService();
  final LibraryController libraryController = Get.find<LibraryController>();

  final RxString cacheSizeText = 'Calculating...'.obs;
  final RxBool isClearingCache = false.obs;
  final RxBool isSharingApk = false.obs;
  final RxBool skipRecordings = true.obs;
  final RxBool autoPlayOnCastChange = false.obs;
  final RxBool crossfadeEnabled = false.obs;
  final RxBool batteryOptimizationEnabled = false.obs;
  final RxBool highRefreshRateEnabled = false.obs;
  final RxBool hapticFeedbackEnabled = true.obs;
  final RxBool playerGesturesEnabled = true.obs;
  final RxList<String> excludedDirectories = <String>[].obs;
  final AudioDspService dspService = AudioDspService();

  @override
  void onInit() {
    super.onInit();
    skipRecordings.value = cacheService.isSkipRecordingsEnabled();
    autoPlayOnCastChange.value = cacheService.getSetting(
      'auto_play_on_cast_change',
      defaultValue: false,
    ) as bool;
    crossfadeEnabled.value = cacheService.getSetting(
      'crossfade_enabled',
      defaultValue: false,
    ) as bool;
    batteryOptimizationEnabled.value = cacheService.getSetting(
      'battery_optimization_enabled',
      defaultValue: false,
    ) as bool;
    highRefreshRateEnabled.value = cacheService.getSetting(
      'high_refresh_rate_enabled',
      defaultValue: false,
    ) as bool;
    hapticFeedbackEnabled.value = cacheService.getSetting(
      'haptic_feedback_enabled',
      defaultValue: true,
    ) as bool;
    playerGesturesEnabled.value = cacheService.getSetting(
      'player_gestures_enabled',
      defaultValue: true,
    ) as bool;
    excludedDirectories.assignAll(cacheService.getExcludedDirectories());
    dspService.setVisualizerEnabled(!batteryOptimizationEnabled.value);
    dspService.setHighRefreshRate(highRefreshRateEnabled.value);
    updateCacheSize();
  }

  Future<void> setAutoPlayOnCastChange(bool enabled) async {
    autoPlayOnCastChange.value = enabled;
    await cacheService.setSetting('auto_play_on_cast_change', enabled);
  }

  Future<void> setCrossfadeEnabled(bool enabled) async {
    crossfadeEnabled.value = enabled;
    await cacheService.setSetting('crossfade_enabled', enabled);
  }

  Future<void> setBatteryOptimizationEnabled(bool enabled) async {
    batteryOptimizationEnabled.value = enabled;
    await cacheService.setSetting('battery_optimization_enabled', enabled);
    await dspService.setVisualizerEnabled(!enabled);
  }

  Future<void> setHighRefreshRateEnabled(bool enabled) async {
    highRefreshRateEnabled.value = enabled;
    await cacheService.setSetting('high_refresh_rate_enabled', enabled);
    await dspService.setHighRefreshRate(enabled);
  }

  Future<void> setHapticFeedbackEnabled(bool enabled) async {
    hapticFeedbackEnabled.value = enabled;
    await cacheService.setSetting('haptic_feedback_enabled', enabled);
  }

  Future<void> setPlayerGesturesEnabled(bool enabled) async {
    playerGesturesEnabled.value = enabled;
    await cacheService.setSetting('player_gestures_enabled', enabled);
  }

  Future<void> addExcludedDirectory() async {
    try {
      final directory = await FilePicker.getDirectoryPath(
        dialogTitle: 'Choose a folder to exclude',
      );
      if (directory == null ||
          directory.isEmpty ||
          excludedDirectories.contains(directory)) {
        return;
      }
      final updated = [...excludedDirectories, directory];
      excludedDirectories.assignAll(updated);
      await cacheService.setExcludedDirectories(updated);
      libraryController.loadCachedSongs();
    } catch (e) {
      Get.snackbar(
        'Folder Picker Unavailable',
        'Unable to choose a folder on this device.',
      );
    }
  }

  Future<void> removeExcludedDirectory(String directory) async {
    final updated = excludedDirectories
        .where((path) => path != directory)
        .toList();
    excludedDirectories.assignAll(updated);
    await cacheService.setExcludedDirectories(updated);
    libraryController.loadCachedSongs();
  }

  Future<void> toggleSkipRecordings(bool enabled) async {
    skipRecordings.value = enabled;
    await cacheService.setSkipRecordingsEnabled(enabled);
    libraryController.loadCachedSongs();
    Get.snackbar(
      'Recording Filter',
      enabled
          ? 'Voice & call recordings excluded from music playback.'
          : 'Recordings will be visible in music library.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF1B1D26),
      colorText: Colors.white,
    );
  }

  Future<void> updateCacheSize() async {
    final bytes = await cacheService.getArtworkCacheSizeBytes();
    cacheSizeText.value = FileUtils.formatBytes(bytes);
  }

  Future<void> clearCache() async {
    isClearingCache.value = true;
    try {
      await cacheService.clearArtworkCache();
      await updateCacheSize();
      Get.snackbar(
        'Cache Cleared',
        'Artwork and temporary cache have been cleared.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF1B1D26),
        colorText: Colors.white,
      );
    } finally {
      isClearingCache.value = false;
    }
  }

  /// Exports and shares the installed SONIQ application APK file directly
  Future<void> shareAppAsApk() async {
    if (isSharingApk.value) return;
    isSharingApk.value = true;

    try {
      if (!Platform.isAndroid) {
        Get.snackbar(
          'Platform Notice',
          'Direct APK sharing is only supported on Android devices.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF1B1D26),
          colorText: Colors.white,
        );
        return;
      }

      Get.snackbar(
        'Preparing APK',
        'Extracting SONIQ APK file for sharing...',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF1B1D26),
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );

      const channel = MethodChannel('com.soniq.soniq/app_share');
      final sourceApkPath = await channel.invokeMethod<String>(
        'getAppSourceApkPath',
      );

      if (sourceApkPath == null || sourceApkPath.isEmpty) {
        throw Exception('Could not locate installed application package path.');
      }

      final sourceFile = File(sourceApkPath);
      if (!await sourceFile.exists()) {
        throw Exception('Application package file is not accessible.');
      }

      // Copy to temporary cache with user-friendly file name: SONIQ_Music_Player.apk
      final tempDir = await getTemporaryDirectory();
      final targetApkPath = '${tempDir.path}/SONIQ_Music_Player.apk';
      final targetFile = File(targetApkPath);

      if (await targetFile.exists()) {
        try {
          await targetFile.delete();
        } catch (_) {}
      }
      await sourceFile.copy(targetApkPath);

      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [
          XFile(
            targetApkPath,
            name: 'SONIQ_Music_Player.apk',
            mimeType: 'application/vnd.android.package-archive',
          ),
        ],
        subject: 'SONIQ Premium Offline Music Player',
        text: 'Download and install SONIQ Premium Offline Music Player APK directly.',
      );
    } catch (e) {
      Get.snackbar(
        'Share Failed',
        'Unable to export APK: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF3B132C),
        colorText: Colors.white,
      );
    } finally {
      isSharingApk.value = false;
    }
  }

  int get totalIndexedSongs => libraryController.allSongs.length;

  int get totalRingtonesCount => cacheService.getRingtones().length;

  String get totalLibrarySizeFormatted {
    int total = 0;
    for (final song in libraryController.allSongs) {
      total += song.sizeBytes;
    }
    return FileUtils.formatBytes(total);
  }
}
