import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/models/song_model.dart';
import '../../../core/models/playlist_model.dart';
import '../../../core/models/recommendation_model.dart';
import '../../../core/services/music_discovery_service.dart';
import '../../../core/services/audio_handler.dart';
import '../../../core/database/song_cache_service.dart';
import '../../library/controllers/library_controller.dart';
import '../../playlists/controllers/playlist_controller.dart';

class DiscoveryController extends GetxController {
  final MusicDiscoveryService _discoveryService = MusicDiscoveryService();
  final SongCacheService _cacheService = SongCacheService();
  final SoniqAudioHandler _audioHandler = Get.find<SoniqAudioHandler>();

  final dailyMixes = <RecommendationMix>[].obs;
  final discoverMix = Rxn<RecommendationMix>();
  final artistRadios = <RecommendationMix>[].obs;
  final forgottenGems = Rxn<RecommendationMix>();
  final becauseYouListened = Rxn<RecommendationMix>();
  final moodMixes = <RecommendationMix>[].obs;

  final feedback = RecommendationFeedback().obs;
  final settings = const RecommendationSettings().obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    feedback.value = _discoveryService.getFeedback();
    settings.value = _discoveryService.getSettings();
    loadDiscovery();
  }

  /// Refreshes all recommendation shelves
  Future<void> loadDiscovery({bool force = false}) async {
    isLoading.value = true;
    try {
      final libraryController = Get.isRegistered<LibraryController>()
          ? Get.find<LibraryController>()
          : null;

      final library = libraryController?.allSongs ?? _cacheService.getCachedSongs();
      if (library.isEmpty) {
        isLoading.value = false;
        return;
      }

      feedback.value = _discoveryService.getFeedback();
      settings.value = _discoveryService.getSettings();

      // 1. Daily Mixes
      dailyMixes.assignAll(
        _discoveryService.generateDailyMixes(library, mixesCount: 4, forceRegenerate: force),
      );

      // 2. Discover Mix
      discoverMix.value = _discoveryService.generateDiscoverMix(library);

      // 3. Forgotten Gems
      final fg = _discoveryService.generateForgottenGems(library);
      forgottenGems.value = fg.songs.isNotEmpty ? fg : null;

      // 4. Because You Listened
      becauseYouListened.value = _discoveryService.generateBecauseYouListened(library);

      // 5. Mood Mixes
      moodMixes.assignAll(_discoveryService.generateMoodMixes(library));

      // 6. Popular Artist Radios (top 5 artists with >= 3 songs)
      final artistCounts = <String, int>{};
      for (final s in library) {
        if (s.artist.isNotEmpty && s.artist.toLowerCase() != 'unknown') {
          artistCounts[s.artist] = (artistCounts[s.artist] ?? 0) + 1;
        }
      }
      final topArtists = artistCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final radios = <RecommendationMix>[];
      for (final entry in topArtists.take(5)) {
        if (entry.value >= 3) {
          radios.add(_discoveryService.generateArtistRadio(entry.key, library));
        }
      }
      artistRadios.assignAll(radios);
    } catch (e) {
      debugPrint('SONIQ DiscoveryController error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Plays a recommendation mix directly via SONIQ's authoritative playback engine
  Future<void> playMix(
    RecommendationMix mix, {
    int startIndex = 0,
    bool shuffle = false,
  }) async {
    if (mix.songs.isEmpty) {
      Get.snackbar('Empty Mix', 'No songs available in this mix.');
      return;
    }

    await _audioHandler.playSongList(
      mix.songs,
      startIndex,
      shuffle: shuffle,
      source: 'discovery_mix',
      sourceId: mix.id,
    );
  }

  /// Starts an Artist Radio immediately for a given artist name
  Future<void> startArtistRadio(String artistName) async {
    final libraryController = Get.isRegistered<LibraryController>()
        ? Get.find<LibraryController>()
        : null;
    final library = libraryController?.allSongs ?? _cacheService.getCachedSongs();
    final radio = _discoveryService.generateArtistRadio(artistName, library);

    if (radio.songs.isNotEmpty) {
      await playMix(radio, shuffle: true);
      Get.snackbar(
        'Artist Radio Started',
        'Streaming music inspired by $artistName',
        snackPosition: SnackPosition.BOTTOM,
      );
    } else {
      Get.snackbar('Unavailable', 'Not enough tracks found for $artistName radio.');
    }
  }

  /// Computes and plays a Similar Songs queue for a given seed track
  Future<void> playSimilarSongs(SongModel seedSong) async {
    final libraryController = Get.isRegistered<LibraryController>()
        ? Get.find<LibraryController>()
        : null;
    final library = libraryController?.allSongs ?? _cacheService.getCachedSongs();
    final similarItems = _discoveryService.getSimilarSongs(seedSong, library, limit: 25);

    if (similarItems.isEmpty) {
      Get.snackbar('Discovery', 'No similar tracks found for "${seedSong.title}".');
      return;
    }

    final queue = [seedSong, ...similarItems.map((e) => e.song)];
    await _audioHandler.playSongList(
      queue,
      0,
      source: 'similar_songs',
      sourceId: seedSong.id,
    );
    Get.snackbar(
      'Similar Songs Radio',
      'Playing tracks matched to "${seedSong.title}"',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  /// Saves a recommendation mix as a persistent user playlist
  Future<bool> saveMixAsPlaylist(RecommendationMix mix) async {
    if (mix.songs.isEmpty) return false;

    final playlist = PlaylistModel(
      id: 'pl_discover_${DateTime.now().millisecondsSinceEpoch}',
      name: mix.title,
      songIds: mix.songs.map((s) => s.id).toList(),
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    await _cacheService.savePlaylist(playlist);

    if (Get.isRegistered<PlaylistController>()) {
      Get.find<PlaylistController>().loadPlaylists();
    }

    Get.snackbar(
      'Playlist Created',
      'Saved "${mix.title}" with ${mix.songs.length} tracks to your Playlists.',
      snackPosition: SnackPosition.BOTTOM,
    );
    return true;
  }

  // Feedback Actions
  Future<void> giveLike(SongModel song) async {
    await _discoveryService.likeSong(song.id);
    feedback.value = _discoveryService.getFeedback();
    Get.snackbar('Feedback Saved', 'SONIQ will recommend more music like "${song.title}".');
  }

  Future<void> giveDislike(SongModel song) async {
    await _discoveryService.dislikeSong(song.id);
    feedback.value = _discoveryService.getFeedback();
    await loadDiscovery(force: true);
    Get.snackbar('Feedback Saved', '"${song.title}" will no longer be recommended.');
  }

  Future<void> markNotInterested(SongModel song) async {
    await _discoveryService.markNotInterested(song.id);
    feedback.value = _discoveryService.getFeedback();
    await loadDiscovery(force: true);
    Get.snackbar('Not Interested', '"${song.title}" hidden from recommendations for 30 days.');
  }

  Future<void> excludeSong(SongModel song) async {
    await _discoveryService.excludeSong(song.id);
    feedback.value = _discoveryService.getFeedback();
    await loadDiscovery(force: true);
    Get.snackbar('Song Excluded', '"${song.title}" excluded from all discovery mixes.');
  }

  Future<void> excludeArtist(String artistName) async {
    await _discoveryService.excludeArtist(artistName);
    feedback.value = _discoveryService.getFeedback();
    await loadDiscovery(force: true);
    Get.snackbar('Artist Excluded', 'Music by $artistName excluded from recommendations.');
  }

  Future<void> removeExclusion(String idOrName) async {
    await _discoveryService.removeExclusion(idOrName);
    feedback.value = _discoveryService.getFeedback();
    await loadDiscovery(force: true);
    Get.snackbar('Exclusion Removed', 'Restored to recommendations.');
  }

  Future<void> resetPreferences() async {
    await _discoveryService.resetAllFeedback();
    feedback.value = _discoveryService.getFeedback();
    await loadDiscovery(force: true);
    Get.snackbar('Preferences Reset', 'All recommendation feedback and exclusions cleared.');
  }

  Future<void> saveSettings(RecommendationSettings newSettings) async {
    await _discoveryService.saveSettings(newSettings);
    settings.value = newSettings;
    await loadDiscovery(force: true);
    Get.snackbar('Settings Saved', 'Discovery recommendations updated.');
  }
}
