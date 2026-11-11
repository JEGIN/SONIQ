import 'dart:math';

import 'package:get/get.dart';

import '../../../core/models/song_model.dart';
import '../../../core/database/song_cache_service.dart';
import '../../library/controllers/library_controller.dart';
import '../../player/controllers/player_controller.dart';

class HomeController extends GetxController {
  final SongCacheService cacheService = SongCacheService();
  final LibraryController libraryController = Get.find<LibraryController>();

  final RxList<SongModel> recentlyPlayed = <SongModel>[].obs;
  final RxList<SongModel> recentlyAdded = <SongModel>[].obs;
  final RxList<SongModel> favorites = <SongModel>[].obs;
  final RxList<SongModel> mostPlayed = <SongModel>[].obs;
  final RxList<SongModel> todaysMix = <SongModel>[].obs;

  final RxString activeMixFilter = 'Song mix'.obs;
  final List<String> mixFilters = ['Song mix', 'Album mix', 'Decade mix'];

  @override
  void onInit() {
    super.onInit();
    refreshHomeData();
    // Re-sync when library songs change
    ever(libraryController.allSongs, (_) => refreshHomeData());
    if (Get.isRegistered<AudioPlayerController>()) {
      ever(Get.find<AudioPlayerController>().currentSong, (_) {
        Future.delayed(const Duration(milliseconds: 500), refreshHomeData);
      });
    }
  }

  void refreshHomeData() {
    final all = libraryController.allSongs;
    final favIds = cacheService.getFavoriteSongIds().toSet();

    if (all.isEmpty) {
      recentlyPlayed.clear();
      recentlyAdded.clear();
      favorites.clear();
      mostPlayed.clear();
      todaysMix.clear();
      return;
    }

    // Favorites
    favorites.assignAll(
      all.where((s) => favIds.contains(s.id) || s.isFavorite).toList(),
    );

    // Recently Added (sort dateAdded desc)
    final addedList = List<SongModel>.from(all)
      ..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    recentlyAdded.assignAll(addedList.take(15).toList());

    // Recently Played
    final recentIds = cacheService.getRecentlyPlayedSongIds(limit: 20);
    final songMap = {for (final s in all) s.id: s};
    final recentSongs = <SongModel>[];
    for (final id in recentIds) {
      if (songMap.containsKey(id)) {
        recentSongs.add(songMap[id]!);
      }
    }
    recentlyPlayed.assignAll(recentSongs);

    // Most Played (sort playCount desc)
    final mostPlayedList = List<SongModel>.from(
      all.where((s) => s.playCount > 0),
    )..sort((a, b) => b.playCount.compareTo(a.playCount));
    mostPlayed.assignAll(mostPlayedList.take(15).toList());
    _buildTodaysMix(all.toList(), favIds);
  }

  void _buildTodaysMix(List<SongModel> songs, Set<String> favoriteIds) {
    final now = DateTime.now();
    final recentEvents = cacheService.getAllPlaybackEvents().where((event) {
      final age = now.millisecondsSinceEpoch - event.startTimeMs;
      return age >= 0 && age <= const Duration(days: 45).inMilliseconds;
    }).toList();

    final scores = <String, double>{};
    final preferredArtists = <String, double>{};
    final preferredAlbums = <String, double>{};
    for (final event in recentEvents) {
      final ageDays =
          ((now.millisecondsSinceEpoch - event.startTimeMs) /
                  const Duration(days: 1).inMilliseconds)
              .clamp(0, 45)
              .toDouble();
      final recencyWeight = 1.0 - ageDays / 60.0;
      final eventWeight = event.isQualifiedPlay ? 2.0 : 0.7;
      scores[event.songId] =
          (scores[event.songId] ?? 0) + eventWeight * recencyWeight;
      preferredArtists[event.artistName.toLowerCase()] =
          (preferredArtists[event.artistName.toLowerCase()] ?? 0) +
          recencyWeight;
      preferredAlbums[event.albumName.toLowerCase()] =
          (preferredAlbums[event.albumName.toLowerCase()] ?? 0) +
          recencyWeight * 0.5;
    }

    final dailySeed = DateTime(
      now.year,
      now.month,
      now.day,
    ).millisecondsSinceEpoch;
    final ranked = songs.map((song) {
      final recencyDays = song.lastPlayedTimestamp <= 0
          ? 45.0
          : ((now.millisecondsSinceEpoch ~/ 1000 - song.lastPlayedTimestamp) /
                    const Duration(days: 1).inSeconds)
                .clamp(0, 45)
                .toDouble();
      var score = (scores[song.id] ?? 0) + song.playCount * 0.18;
      score += (preferredArtists[song.artist.toLowerCase()] ?? 0) * 0.35;
      score += (preferredAlbums[song.album.toLowerCase()] ?? 0) * 0.2;
      if (favoriteIds.contains(song.id) || song.isFavorite) score += 3.0;
      score += (45 - recencyDays) / 90;
      final dailyJitter =
          Random(dailySeed ^ song.id.hashCode).nextDouble() * 0.12;
      return (song: song, score: score + dailyJitter);
    }).toList()..sort((a, b) => b.score.compareTo(a.score));

    final mix = <SongModel>[];
    final artistCounts = <String, int>{};
    for (final candidate in ranked) {
      final artist = candidate.song.artist.trim().toLowerCase();
      if ((artistCounts[artist] ?? 0) >= 3) continue;
      mix.add(candidate.song);
      artistCounts[artist] = (artistCounts[artist] ?? 0) + 1;
      if (mix.length == 12) break;
    }
    if (mix.length < 12) {
      for (final candidate in ranked) {
        if (mix.any((song) => song.id == candidate.song.id)) continue;
        mix.add(candidate.song);
        if (mix.length == 12) break;
      }
    }
    todaysMix.assignAll(mix);
  }

  void playTodaysMix() {
    if (todaysMix.isEmpty || !Get.isRegistered<AudioPlayerController>()) return;
    Get.find<AudioPlayerController>().playAll(
      todaysMix.toList(),
      source: 'daily_mix',
    );
  }

  void setMixFilter(String filter) {
    activeMixFilter.value = filter;
  }
}
