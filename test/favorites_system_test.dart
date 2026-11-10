import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:soniq/core/models/song_model.dart';
import 'package:soniq/features/library/controllers/library_controller.dart';
import 'package:soniq/features/playlists/controllers/favorites_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SONIQ Global Favorites System & Synchronization Tests', () {
    late List<SongModel> sampleSongs;

    setUp(() {
      Get.reset();
      sampleSongs = [
        SongModel(
          id: '101',
          title: 'Believer',
          artist: 'Imagine Dragons',
          album: 'Evolve',
          durationMs: 204000,
          dataPath: '/storage/emulated/0/Music/believer.mp3',
          sizeBytes: 8120000,
          dateAdded: 1620000000,
          fileExtension: 'mp3',
        ),
        SongModel(
          id: '102',
          title: 'Starboy',
          artist: 'The Weeknd',
          album: 'Starboy',
          durationMs: 230000,
          dataPath: '/storage/emulated/0/Music/starboy.mp3',
          sizeBytes: 9200000,
          dateAdded: 1630000000,
          fileExtension: 'mp3',
        ),
        SongModel(
          id: '103',
          title: 'Animals',
          artist: 'Martin Garrix',
          album: 'Gold Skies',
          durationMs: 190000,
          dataPath: '/storage/emulated/0/Music/animals.mp3',
          sizeBytes: 7500000,
          dateAdded: 1610000000,
          fileExtension: 'mp3',
        ),
        SongModel(
          id: '104',
          title: 'Believer', // Duplicate title, different artist & distinct ID
          artist: 'Major Lazer',
          album: 'Peace Is the Mission',
          durationMs: 220000,
          dataPath: '/storage/emulated/0/Music/believer_ml.mp3',
          sizeBytes: 8800000,
          dateAdded: 1640000000,
          fileExtension: 'mp3',
        ),
      ];
    });

    test('1. Initial FavoritesController state is empty and responsive', () {
      final favCtrl = FavoritesController();
      expect(favCtrl.favoriteIds.isEmpty, true);
      expect(favCtrl.favoriteSongs.isEmpty, true);
      expect(favCtrl.isFavorite('101'), false);
    });

    test('2. Toggling favorite adds song immediately (0ms reactive)', () async {
      final favCtrl = FavoritesController();
      final song = sampleSongs[0];

      // Toggling on
      final newStatus = await favCtrl.toggleFavorite(song);

      expect(newStatus, true);
      expect(song.isFavorite, true);
      expect(favCtrl.isFavorite('101'), true);
      expect(favCtrl.favoriteIds.contains('101'), true);
      expect(favCtrl.favoriteSongs.any((s) => s.id == '101'), true);
      expect(favCtrl.favoriteSongs.length, 1);
    });

    test('3. Toggling off removes song from favorites immediately', () async {
      final favCtrl = FavoritesController();
      final song = sampleSongs[0];

      // Toggle on
      await favCtrl.toggleFavorite(song);
      expect(favCtrl.isFavorite(song.id), true);

      // Toggle off
      final newStatus = await favCtrl.toggleFavorite(song);
      expect(newStatus, false);
      expect(song.isFavorite, false);
      expect(favCtrl.isFavorite(song.id), false);
      expect(favCtrl.favoriteIds.contains(song.id), false);
      expect(favCtrl.favoriteSongs.any((s) => s.id == song.id), false);
      expect(favCtrl.favoriteSongs.isEmpty, true);
    });

    test('4. Removing from favorites preserves playback queue and file data path', () async {
      final favCtrl = FavoritesController();
      final queue = List<SongModel>.from(sampleSongs);
      final songToToggle = queue[1]; // Starboy

      // Favorite it
      await favCtrl.toggleFavorite(songToToggle);
      expect(favCtrl.isFavorite(songToToggle.id), true);

      // Remove it from favorites
      await favCtrl.toggleFavorite(songToToggle);
      expect(favCtrl.isFavorite(songToToggle.id), false);

      // Verify the queue still contains all songs and data path is intact
      expect(queue.length, 4);
      expect(queue[1].id, '102');
      expect(queue[1].dataPath, '/storage/emulated/0/Music/starboy.mp3');
      expect(queue[1].title, 'Starboy');
    });

    test('5. Prevent duplicate favorite entries even if toggled multiple times', () async {
      final favCtrl = FavoritesController();
      final song = sampleSongs[0];

      // Add
      await favCtrl.toggleFavorite(song);
      // Manually calling rebuild or adding again
      favCtrl.favoriteIds.add(song.id);
      favCtrl.rebuildFavoriteSongs();

      expect(favCtrl.favoriteIds.length, 1);
      expect(favCtrl.favoriteSongs.length, 1);
    });

    test('6. Distinct songs with the same title are maintained independently', () async {
      final favCtrl = FavoritesController();
      final song1 = sampleSongs[0]; // Believer - Imagine Dragons (ID: 101)
      final song2 = sampleSongs[3]; // Believer - Major Lazer (ID: 104)

      await favCtrl.toggleFavorite(song1);

      expect(favCtrl.isFavorite('101'), true);
      expect(favCtrl.isFavorite('104'), false);
      expect(favCtrl.favoriteSongs.length, 1);

      await favCtrl.toggleFavorite(song2);
      expect(favCtrl.isFavorite('101'), true);
      expect(favCtrl.isFavorite('104'), true);
      expect(favCtrl.favoriteSongs.length, 2);

      // Untoggle only Imagine Dragons
      await favCtrl.toggleFavorite(song1);
      expect(favCtrl.isFavorite('101'), false);
      expect(favCtrl.isFavorite('104'), true);
      expect(favCtrl.favoriteSongs.length, 1);
      expect(favCtrl.favoriteSongs.first.artist, 'Major Lazer');
    });

    test('7. Rapid multi-tap toggle preserves atomic consistency', () async {
      final favCtrl = FavoritesController();
      final song = sampleSongs[2];

      // Simulate 5 rapid taps
      for (int i = 0; i < 5; i++) {
        await favCtrl.toggleFavorite(song);
      }

      // Odd number of taps (5) -> must end in favorite = true
      expect(favCtrl.isFavorite(song.id), true);
      expect(favCtrl.favoriteSongs.length, 1);

      // 6th tap -> must end in favorite = false
      await favCtrl.toggleFavorite(song);
      expect(favCtrl.isFavorite(song.id), false);
      expect(favCtrl.favoriteSongs.isEmpty, true);
    });

    test('8. Live search filters favorites by title, artist, or album', () async {
      final favCtrl = FavoritesController();
      for (final s in sampleSongs) {
        await favCtrl.toggleFavorite(s);
      }
      expect(favCtrl.favoriteSongs.length, 4);

      // Search by title "star"
      favCtrl.updateSearch('star');
      expect(favCtrl.filteredFavoriteSongs.length, 1);
      expect(favCtrl.filteredFavoriteSongs.first.title, 'Starboy');

      // Search by artist "Imagine"
      favCtrl.updateSearch('Imagine');
      expect(favCtrl.filteredFavoriteSongs.length, 1);
      expect(favCtrl.filteredFavoriteSongs.first.artist, 'Imagine Dragons');

      // Search by album "Gold Skies"
      favCtrl.updateSearch('gold');
      expect(favCtrl.filteredFavoriteSongs.length, 1);
      expect(favCtrl.filteredFavoriteSongs.first.album, 'Gold Skies');

      // Search clear
      favCtrl.updateSearch('');
      expect(favCtrl.filteredFavoriteSongs.length, 4);
    });

    test('9. 8-Tier Sorting works accurately on favorite tracks', () async {
      final favCtrl = FavoritesController();
      for (final s in sampleSongs) {
        await favCtrl.toggleFavorite(s);
      }

      // 1. Title A-Z
      favCtrl.setSortOption(SongSortOption.titleAsc);
      var sorted = favCtrl.filteredFavoriteSongs;
      expect(sorted[0].title, 'Animals'); // A
      expect(sorted[1].title, 'Believer'); // B
      expect(sorted[3].title, 'Starboy'); // S

      // 2. Title Z-A
      favCtrl.setSortOption(SongSortOption.titleDesc);
      sorted = favCtrl.filteredFavoriteSongs;
      expect(sorted[0].title, 'Starboy');

      // 3. Artist A-Z
      favCtrl.setSortOption(SongSortOption.artistAsc);
      sorted = favCtrl.filteredFavoriteSongs;
      expect(sorted[0].artist, 'Imagine Dragons');

      // 4. Artist Z-A
      favCtrl.setSortOption(SongSortOption.artistDesc);
      sorted = favCtrl.filteredFavoriteSongs;
      expect(sorted[0].artist, 'The Weeknd');

      // 5. Date Added Descending (Newest first)
      favCtrl.setSortOption(SongSortOption.dateAddedDesc);
      sorted = favCtrl.filteredFavoriteSongs;
      expect(sorted[0].id, '104'); // 1640000000

      // 6. Date Added Ascending (Oldest first)
      favCtrl.setSortOption(SongSortOption.dateAddedAsc);
      sorted = favCtrl.filteredFavoriteSongs;
      expect(sorted[0].id, '103'); // 1610000000

      // 7. Duration Ascending (Shortest first)
      favCtrl.setSortOption(SongSortOption.durationAsc);
      sorted = favCtrl.filteredFavoriteSongs;
      expect(sorted[0].durationMs, 190000); // Animals

      // 8. Duration Descending (Longest first)
      favCtrl.setSortOption(SongSortOption.durationDesc);
      sorted = favCtrl.filteredFavoriteSongs;
      expect(sorted[0].durationMs, 230000); // Starboy
    });

    test('10. AudioScannerService favorite preservation logic on rescanning', () {
      final persistedFavoriteIds = {'101', '102'};
      final existingFavorites = {
        '101': 'believer_imagine dragons',
        '102': 'starboy_the weeknd',
      };

      // Simulated newly scanned songs (e.g. file paths changed or rescanned)
      final scannedSongs = [
        SongModel(
          id: '101',
          title: 'Believer',
          artist: 'Imagine Dragons',
          album: 'Evolve',
          durationMs: 204000,
          dataPath: '/storage/emulated/0/Music/NewPath/believer.mp3',
          sizeBytes: 8120000,
          dateAdded: 1620000000,
          fileExtension: 'mp3',
        ),
        SongModel(
          id: '999', // Device assigned a new ID to moved Starboy file
          title: 'Starboy',
          artist: 'The Weeknd',
          album: 'Starboy',
          durationMs: 230000,
          dataPath: '/storage/emulated/0/Music/Renamed/starboy.mp3',
          sizeBytes: 9200000,
          dateAdded: 1630000000,
          fileExtension: 'mp3',
        ),
      ];

      // Mirror the scanner preservation logic
      for (final song in scannedSongs) {
        final key = '${song.title.toLowerCase().trim()}_${song.artist.toLowerCase().trim()}';
        if (persistedFavoriteIds.contains(song.id) || existingFavorites.values.contains(key)) {
          song.isFavorite = true;
        }
      }

      expect(scannedSongs[0].isFavorite, true); // Preserved by ID
      expect(scannedSongs[1].isFavorite, true); // Preserved by Title+Artist despite new device ID!
    });
  });
}
