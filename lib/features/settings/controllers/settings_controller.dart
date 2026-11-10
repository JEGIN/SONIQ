import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/database/song_cache_service.dart';
import '../../../core/utils/file_utils.dart';
import '../../library/controllers/library_controller.dart';

class SettingsController extends GetxController {
  final SongCacheService cacheService = SongCacheService();
  final LibraryController libraryController = Get.find<LibraryController>();

  final RxString cacheSizeText = 'Calculating...'.obs;
  final RxBool isClearingCache = false.obs;
  final RxBool isSharingApk = false.obs;

  @override
  void onInit() {
    super.onInit();
    updateCacheSize();
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
      final sourceApkPath = await channel.invokeMethod<String>('getAppSourceApkPath');

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

      final sourceLength = await sourceFile.length();
      if (!await targetFile.exists() || await targetFile.length() != sourceLength) {
        await sourceFile.copy(targetApkPath);
      }

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
