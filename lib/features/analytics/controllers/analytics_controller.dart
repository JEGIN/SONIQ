import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/database/song_cache_service.dart';
import '../../../core/models/analytics_summary_model.dart';
import '../../../core/models/discovery_insights_model.dart';
import '../../../core/models/playlist_model.dart';
import '../../../core/models/song_model.dart';
import '../../../core/models/soniq_replay_model.dart';
import '../../../core/services/listening_analytics_service.dart';
import '../../library/controllers/library_controller.dart';
import '../../player/controllers/player_controller.dart';
import '../../playlists/controllers/playlist_controller.dart';

class AnalyticsController extends GetxController {
  final ListeningAnalyticsService _analyticsService = ListeningAnalyticsService();
  final SongCacheService _cacheService = SongCacheService();

  final Rx<AnalyticsTimeFilter> timeFilter = AnalyticsTimeFilter.last30Days.obs;
  final Rx<DateTimeRange?> customRange = Rx<DateTimeRange?>(null);
  final Rx<AnalyticsSummaryModel?> summary = Rx<AnalyticsSummaryModel?>(null);
  final Rx<DiscoveryInsightsModel?> discoveryInsights = Rx<DiscoveryInsightsModel?>(null);
  final Rx<SoniqReplayModel?> replayModel = Rx<SoniqReplayModel?>(null);

  final RxBool isLoading = false.obs;
  final RxInt selectedTabIndex = 0.obs; // 0: Overview, 1: Top Music, 2: Trends, 3: Discovery
  final RxInt topMusicCategoryIndex = 0.obs; // 0: Songs, 1: Artists, 2: Albums, 3: Genres
  final RxBool isTrackingEnabled = true.obs;
  final RxInt playCountThresholdSeconds = 30.obs;

  @override
  void onInit() {
    super.onInit();
    isTrackingEnabled.value = _cacheService.isAnalyticsTrackingEnabled();
    playCountThresholdSeconds.value = _cacheService.getPlayCountThresholdSeconds();
    loadAnalytics();
  }

  Future<void> loadAnalytics() async {
    isLoading.value = true;
    try {
      final s = await _analyticsService.computeSummary(
        filter: timeFilter.value,
        customRange: customRange.value,
      );
      summary.value = s;

      final library = _getLibrary();
      final disc = await _analyticsService.generateDiscoveryInsights(library);
      discoveryInsights.value = disc;
    } catch (e) {
      debugPrint('SONIQ Analytics: Error loading data: $e');
    } finally {
      isLoading.value = false;
    }
  }

  List<SongModel> _getLibrary() {
    if (Get.isRegistered<LibraryController>()) {
      final lib = Get.find<LibraryController>();
      if (lib.allSongs.isNotEmpty) return lib.allSongs.toList();
    }
    return _cacheService.getCachedSongs();
  }

  void setTimeFilter(AnalyticsTimeFilter filter) {
    timeFilter.value = filter;
    loadAnalytics();
  }

  void setCustomRange(DateTimeRange range) {
    customRange.value = range;
    timeFilter.value = AnalyticsTimeFilter.custom;
    loadAnalytics();
  }

  Future<void> toggleTracking(bool enabled) async {
    isTrackingEnabled.value = enabled;
    await _cacheService.setAnalyticsTrackingEnabled(enabled);
    Get.snackbar(
      'Listening History',
      enabled ? 'Listening analytics enabled.' : 'Listening analytics paused.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<void> setThresholdSeconds(int seconds) async {
    playCountThresholdSeconds.value = seconds;
    await _cacheService.setPlayCountThresholdSeconds(seconds);
    loadAnalytics();
  }

  Future<void> clearAllHistory() async {
    await _cacheService.clearAllPlaybackEvents();
    await loadAnalytics();
    Get.snackbar(
      'Analytics Reset',
      'All listening history has been permanently cleared.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<void> clearHistoryForRange(DateTime start, DateTime end) async {
    await _cacheService.deletePlaybackEventsInRange(start, end);
    await loadAnalytics();
    Get.snackbar(
      'Range Cleared',
      'Listening events in selected date range deleted.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<void> exportAnalytics() async {
    try {
      final jsonStr = await _analyticsService.exportAnalyticsJson();
      // ignore: deprecated_member_use
      await Share.share(
        jsonStr,
        subject: 'SONIQ_Listening_Analytics_Export.json',
      );
    } catch (e) {
      Get.snackbar('Export Failed', 'Unable to export analytics data: $e');
    }
  }

  Future<void> loadReplay({int? year}) async {
    final y = year ?? DateTime.now().year;
    final library = _getLibrary();
    final rep = await _analyticsService.generateSoniqReplay(y, library);
    replayModel.value = rep;
  }

  void playSongFromAnalytics(String songId) {
    final library = _getLibrary();
    final match = library.where((s) => s.id == songId);
    if (match.isNotEmpty && Get.isRegistered<AudioPlayerController>()) {
      Get.find<AudioPlayerController>().playSong(
        match.first,
        library,
        source: 'analytics',
      );
    }
  }

  void playCollection(List<SongModel> songs, {bool shuffle = false}) {
    if (songs.isEmpty) return;
    if (Get.isRegistered<AudioPlayerController>()) {
      Get.find<AudioPlayerController>().playAll(
        songs,
        shuffle: shuffle,
        source: 'discovery',
      );
    }
  }

  Future<void> createPlaylistFromDiscovery(String name, List<SongModel> songs) async {
    if (songs.isEmpty) return;
    if (!Get.isRegistered<PlaylistController>()) return;

    final playlistCtrl = Get.find<PlaylistController>();
    final newPl = PlaylistModel(
      id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      songIds: songs.map((s) => s.id).toList(),
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await playlistCtrl.createPlaylist(newPl.name);
    Get.snackbar(
      'Playlist Created',
      'Created "$name" with ${songs.length} tracks.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}
