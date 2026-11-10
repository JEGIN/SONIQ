import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../../core/database/song_cache_service.dart';
import '../../../core/models/smart_playlist_model.dart';
import '../../../core/models/song_classification_model.dart';
import '../../../core/models/song_model.dart';
import '../../../core/services/music_classifier_service.dart';
import '../../../core/services/smart_playlist_service.dart';
import 'playlist_controller.dart';

class SmartPlaylistController extends GetxController {
  final cacheService = SongCacheService();
  final classifier = MusicClassifierService();
  final smartService = SmartPlaylistService();

  final RxList<SmartPlaylistModel> smartPlaylists = <SmartPlaylistModel>[].obs;
  final RxMap<String, SongClassificationModel> classifications = <String, SongClassificationModel>{}.obs;
  final RxBool isAnalyzing = false.obs;
  final RxDouble analysisProgress = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    loadSmartPlaylists();
    loadClassifications();
    _autoAnalyzeIfLibraryAvailable();
  }

  void _autoAnalyzeIfLibraryAvailable() {
    Future.microtask(() {
      final cached = cacheService.getCachedSongs();
      if (cached.isNotEmpty) {
        if (classifications.length < cached.length) {
          analyzeLibrarySongs(cached);
        }
      }
    });
  }

  void loadSmartPlaylists() {
    final saved = cacheService.getSmartPlaylists();
    if (saved.isNotEmpty) {
      smartPlaylists.assignAll(saved);
    } else {
      // First run: bootstrap high-value built-in smart playlists
      final builtins = smartService.createBuiltinSmartPlaylists();
      smartPlaylists.assignAll(builtins);
      for (final pl in builtins) {
        cacheService.saveSmartPlaylist(pl);
      }
    }
  }

  void loadClassifications() {
    final saved = cacheService.getClassifications();
    classifications.assignAll(saved);
  }

  /// Evaluates dynamic smart playlist matching songs
  List<SongModel> evaluatePlaylist(SmartPlaylistModel pl, List<SongModel> library) {
    if (library.isNotEmpty && classifications.length < library.length) {
      bool hasNew = false;
      for (final song in library) {
        if (!classifications.containsKey(song.id)) {
          classifications[song.id] = classifier.classifySong(song);
          hasNew = true;
        }
      }
      if (hasNew) {
        cacheService.saveAllClassifications(classifications);
      }
    }

    return smartService.evaluateSmartPlaylist(
      playlist: pl,
      library: library,
      classifications: classifications,
    );
  }

  /// Run progressive on-device audio & metadata analysis across local songs
  Future<void> analyzeLibrarySongs(List<SongModel> songs, {bool force = false}) async {
    if (isAnalyzing.value || songs.isEmpty) return;
    isAnalyzing.value = true;
    analysisProgress.value = 0.0;

    try {
      final unanalyzed = force
          ? songs
          : songs.where((s) => !classifications.containsKey(s.id) || !classifications[s.id]!.isUserCorrected).toList();

      if (unanalyzed.isEmpty) {
        analysisProgress.value = 1.0;
        isAnalyzing.value = false;
        return;
      }

      int processed = 0;
      final total = unanalyzed.length;
      final batch = <String, SongClassificationModel>{};

      for (final song in unanalyzed) {
        final existing = classifications[song.id];
        final result = classifier.classifySong(song, existing: existing);
        batch[song.id] = result;
        classifications[song.id] = result;

        processed++;
        analysisProgress.value = processed / total;

        // Yield execution periodically to maintain 60fps UI smoothness
        if (processed % 25 == 0) {
          await Future.delayed(const Duration(milliseconds: 10));
        }
      }

      await cacheService.saveAllClassifications(batch);
      debugPrint('SONIQ AI: Successfully classified ${batch.length} tracks offline.');
    } catch (e) {
      debugPrint('SONIQ AI: Error analyzing library: $e');
    } finally {
      isAnalyzing.value = false;
      analysisProgress.value = 1.0;
    }
  }

  /// Manual User Mood Correction (takes absolute precedence with confidence 1.0)
  Future<void> correctSongMood({
    required String songId,
    required String newMood,
    List<String> userTags = const [],
  }) async {
    final existing = classifications[songId];
    final corrected = SongClassificationModel(
      songId: songId,
      primaryMood: newMood,
      secondaryMoods: existing?.secondaryMoods ?? [],
      energyLevel: existing?.energyLevel ?? 'medium',
      language: existing?.language ?? 'other',
      confidenceScore: 1.0,
      isUserCorrected: true,
      userTags: userTags,
      audioFeatures: existing?.audioFeatures ?? AudioFeaturesModel(durationSeconds: 0.0),
      analyzedTimestamp: DateTime.now().millisecondsSinceEpoch,
    );

    classifications[songId] = corrected;
    await cacheService.saveClassification(corrected);
    smartPlaylists.refresh();
  }

  /// Exclude a song from returning to this smart playlist
  Future<void> excludeSong(String playlistId, String songId) async {
    final index = smartPlaylists.indexWhere((p) => p.id == playlistId);
    if (index >= 0) {
      final pl = smartPlaylists[index];
      if (!pl.excludedSongIds.contains(songId)) {
        pl.excludedSongIds.add(songId);
      }
      pl.pinnedSongIds.remove(songId);
      pl.updatedAt = DateTime.now().millisecondsSinceEpoch;

      await cacheService.saveSmartPlaylist(pl);
      smartPlaylists[index] = pl;
      smartPlaylists.refresh();
    }
  }

  /// Pin a song to guarantee inclusion at the top
  Future<void> pinSong(String playlistId, String songId) async {
    final index = smartPlaylists.indexWhere((p) => p.id == playlistId);
    if (index >= 0) {
      final pl = smartPlaylists[index];
      if (!pl.pinnedSongIds.contains(songId)) {
        pl.pinnedSongIds.add(songId);
      }
      pl.excludedSongIds.remove(songId);
      pl.updatedAt = DateTime.now().millisecondsSinceEpoch;

      await cacheService.saveSmartPlaylist(pl);
      smartPlaylists[index] = pl;
      smartPlaylists.refresh();
    }
  }

  /// Unpin a pinned song
  Future<void> unpinSong(String playlistId, String songId) async {
    final index = smartPlaylists.indexWhere((p) => p.id == playlistId);
    if (index >= 0) {
      final pl = smartPlaylists[index];
      pl.pinnedSongIds.remove(songId);
      pl.updatedAt = DateTime.now().millisecondsSinceEpoch;

      await cacheService.saveSmartPlaylist(pl);
      smartPlaylists[index] = pl;
      smartPlaylists.refresh();
    }
  }

  /// Save or create a dynamic smart playlist
  Future<void> saveSmartPlaylist(SmartPlaylistModel pl) async {
    final index = smartPlaylists.indexWhere((p) => p.id == pl.id);
    if (index >= 0) {
      smartPlaylists[index] = pl;
    } else {
      smartPlaylists.add(pl);
    }
    await cacheService.saveSmartPlaylist(pl);
    smartPlaylists.refresh();
  }

  /// Delete a smart playlist definition
  Future<void> deleteSmartPlaylist(String id) async {
    smartPlaylists.removeWhere((p) => p.id == id);
    await cacheService.deleteSmartPlaylist(id);
  }

  /// Convert a Smart Playlist into a static regular Manual Playlist snapshot
  Future<bool> convertToManualPlaylist({
    required SmartPlaylistModel smartPl,
    required String manualName,
    required List<SongModel> library,
  }) async {
    final matchedSongs = evaluatePlaylist(smartPl, library);
    final playlistCtrl = Get.find<PlaylistController>();

    await playlistCtrl.createPlaylist(
      manualName,
      description: 'Snapshot of "${smartPl.name}" (${matchedSongs.length} songs)',
    );

    final manualPl = playlistCtrl.playlists.firstWhereOrNull((p) => p.name == manualName);
    if (manualPl != null) {
      for (final song in matchedSongs) {
        await playlistCtrl.addSongToPlaylist(manualPl.id, song);
      }
      playlistCtrl.loadPlaylists();
      return true;
    }
    return false;
  }

  /// CRITICAL REQUIREMENT 5: Automatic Playlist Synchronization
  Future<void> synchronizeWithLibrary(List<SongModel> currentLibrary) async {
    final playlistCtrl = Get.find<PlaylistController>();

    await smartService.synchronizeWithLibrary(
      currentLibrary: currentLibrary,
      smartPlaylists: smartPlaylists,
      manualPlaylists: playlistCtrl.playlists,
      onSmartPlaylistUpdated: (updatedPl) async {
        await cacheService.saveSmartPlaylist(updatedPl);
      },
      onManualPlaylistUpdated: (updatedManual) async {
        await cacheService.savePlaylist(updatedManual);
      },
    );

    smartPlaylists.refresh();
    playlistCtrl.playlists.refresh();
  }
}
