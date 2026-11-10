import 'package:get/get.dart';
import '../../../core/models/song_model.dart';
import '../../../core/database/song_cache_service.dart';
import '../../library/controllers/library_controller.dart';

class HomeController extends GetxController {
  final SongCacheService cacheService = SongCacheService();
  final LibraryController libraryController = Get.find<LibraryController>();

  final RxList<SongModel> recentlyPlayed = <SongModel>[].obs;
  final RxList<SongModel> recentlyAdded = <SongModel>[].obs;
  final RxList<SongModel> favorites = <SongModel>[].obs;
  final RxList<SongModel> mostPlayed = <SongModel>[].obs;

  final RxString activeMixFilter = 'Song mix'.obs;
  final List<String> mixFilters = ['Song mix', 'Album mix', 'Decade mix'];

  @override
  void onInit() {
    super.onInit();
    refreshHomeData();
    // Re-sync when library songs change
    ever(libraryController.allSongs, (_) => refreshHomeData());
  }

  void refreshHomeData() {
    final all = libraryController.allSongs;
    final favIds = cacheService.getFavoriteSongIds().toSet();

    if (all.isEmpty) {
      recentlyPlayed.clear();
      recentlyAdded.clear();
      favorites.clear();
      mostPlayed.clear();
      return;
    }

    // Favorites
    favorites.assignAll(all.where((s) => favIds.contains(s.id) || s.isFavorite).toList());

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
    final mostPlayedList = List<SongModel>.from(all.where((s) => s.playCount > 0))
      ..sort((a, b) => b.playCount.compareTo(a.playCount));
    mostPlayed.assignAll(mostPlayedList.take(15).toList());
  }

  void setMixFilter(String filter) {
    activeMixFilter.value = filter;
  }
}
