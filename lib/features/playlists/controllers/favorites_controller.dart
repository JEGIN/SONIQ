import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/database/song_cache_service.dart';
import '../../../core/models/song_model.dart';
import '../../home/controllers/home_controller.dart';
import '../../library/controllers/library_controller.dart';
import '../../player/controllers/player_controller.dart';

class FavoritesController extends GetxController {
  final SongCacheService cacheService = SongCacheService();

  // Single Source of Truth for favorite status
  final RxSet<String> favoriteIds = <String>{}.obs;

  // Complete list of favorited SongModel objects
  final RxList<SongModel> favoriteSongs = <SongModel>[].obs;

  // Sorting and search filtering within Favorites
  final Rx<SongSortOption> sortOption = SongSortOption.titleAsc.obs;
  final RxString searchQuery = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadFavorites();
  }

  /// Reloads favorite IDs and builds the reactive favoriteSongs list
  void loadFavorites() {
    final ids = cacheService.getFavoriteSongIds();
    favoriteIds.assignAll(ids);
    rebuildFavoriteSongs();
  }

  /// Synchronizes favoriteSongs from cached songs and library controller based on favoriteIds
  void rebuildFavoriteSongs() {
    List<SongModel> allSongs = cacheService.getCachedSongs();
    if (allSongs.isEmpty && Get.isRegistered<LibraryController>()) {
      allSongs = Get.find<LibraryController>().allSongs.toList();
    }
    final Map<String, SongModel> songMap = {for (final s in allSongs) s.id: s};
    for (final s in favoriteSongs) {
      songMap.putIfAbsent(s.id, () => s);
    }
    final favList = songMap.values.where((s) => favoriteIds.contains(s.id)).toList();
    for (final s in favList) {
      s.isFavorite = true;
    }
    favoriteSongs.assignAll(favList);
  }

  /// O(1) check if a song is favorited
  bool isFavorite(String songId) => favoriteIds.contains(songId);

  /// Toggles favorite status for a song across the entire application
  Future<bool> toggleFavorite(SongModel song) async {
    HapticFeedback.lightImpact();

    final currentStatus = favoriteIds.contains(song.id);
    final newStatus = !currentStatus;

    // 1. Immediately update reactive set and list (0ms UI reactivity)
    if (newStatus) {
      favoriteIds.add(song.id);
      song.isFavorite = true;
      if (!favoriteSongs.any((s) => s.id == song.id)) {
        favoriteSongs.add(song);
      }
    } else {
      favoriteIds.remove(song.id);
      song.isFavorite = false;
      favoriteSongs.removeWhere((s) => s.id == song.id);
    }

    // 2. Persist in database
    await cacheService.setFavorite(song.id, newStatus);

    // 3. Rebuild favorites list to sync full metadata from cache
    rebuildFavoriteSongs();

    // 4. Synchronize LibraryController in-memory lists
    try {
      if (Get.isRegistered<LibraryController>()) {
        final libCtrl = Get.find<LibraryController>();
        final libIdx = libCtrl.allSongs.indexWhere((s) => s.id == song.id);
        if (libIdx >= 0) {
          libCtrl.allSongs[libIdx].isFavorite = newStatus;
          libCtrl.allSongs.refresh();
          libCtrl.filteredSongs.refresh();
        }
      }
    } catch (_) {}

    // 5. Synchronize HomeController
    try {
      if (Get.isRegistered<HomeController>()) {
        final homeCtrl = Get.find<HomeController>();
        homeCtrl.refreshHomeData();
      }
    } catch (_) {}

    // 6. Synchronize Now Playing in AudioPlayerController
    try {
      if (Get.isRegistered<AudioPlayerController>()) {
        final playerCtrl = Get.find<AudioPlayerController>();
        if (playerCtrl.currentSong.value?.id == song.id) {
          playerCtrl.currentSong.value?.isFavorite = newStatus;
          playerCtrl.currentSong.refresh();
        }
      }
    } catch (_) {}

    return newStatus;
  }

  /// Sets sorting option for favorites
  void setSortOption(SongSortOption option) {
    sortOption.value = option;
  }

  /// Updates live search query for favorites
  void updateSearch(String query) {
    searchQuery.value = query;
  }

  /// Returns sorted and search-filtered list of favorites
  List<SongModel> get filteredFavoriteSongs {
    List<SongModel> list = List.from(favoriteSongs);

    // 1. Apply search filter
    final q = searchQuery.value.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((song) =>
          song.title.toLowerCase().contains(q) ||
          song.artist.toLowerCase().contains(q) ||
          song.album.toLowerCase().contains(q)).toList();
    }

    // 2. Apply sorting
    switch (sortOption.value) {
      case SongSortOption.titleAsc:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case SongSortOption.titleDesc:
        list.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
        break;
      case SongSortOption.artistAsc:
        list.sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
        break;
      case SongSortOption.artistDesc:
        list.sort((a, b) => b.artist.toLowerCase().compareTo(a.artist.toLowerCase()));
        break;
      case SongSortOption.dateAddedDesc:
        list.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
        break;
      case SongSortOption.dateAddedAsc:
        list.sort((a, b) => a.dateAdded.compareTo(b.dateAdded));
        break;
      case SongSortOption.durationAsc:
        list.sort((a, b) => a.durationMs.compareTo(b.durationMs));
        break;
      case SongSortOption.durationDesc:
        list.sort((a, b) => b.durationMs.compareTo(a.durationMs));
        break;
    }

    return list;
  }

  /// Plays all favorites with optional shuffle
  void playAll({bool shuffle = false}) {
    if (favoriteSongs.isEmpty) return;
    final playerCtrl = Get.find<AudioPlayerController>();
    final songsToPlay = List<SongModel>.from(favoriteSongs);
    playerCtrl.playSong(songsToPlay.first, songsToPlay, shuffle: shuffle);
  }
}
