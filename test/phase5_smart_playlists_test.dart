import 'package:flutter_test/flutter_test.dart';
import 'package:soniq/core/models/playlist_model.dart';
import 'package:soniq/core/models/smart_playlist_model.dart';
import 'package:soniq/core/models/song_classification_model.dart';
import 'package:soniq/core/models/song_model.dart';
import 'package:soniq/core/services/music_classifier_service.dart';
import 'package:soniq/core/services/smart_playlist_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MusicClassifierService classifier;
  late SmartPlaylistService smartService;

  setUp(() {
    classifier = MusicClassifierService();
    smartService = SmartPlaylistService();
  });

  SongModel createSong({
    required String id,
    required String title,
    required String artist,
    String album = 'Test Album',
    int durationMs = 240000,
    bool isFavorite = false,
  }) {
    return SongModel(
      id: id,
      title: title,
      artist: artist,
      album: album,
      durationMs: durationMs,
      dataPath: '/storage/emulated/0/Music/$title.mp3',
      dateAdded: 1600000000,
      sizeBytes: 8000000,
      fileExtension: 'mp3',
      isFavorite: isFavorite,
    );
  }

  group('SONIQ Phase 5 Addition: AI Smart Playlists & Mood MIR Classifier', () {
    test('1. Love & Romance: Accurately classifies romantic tracks & generates playlist', () {
      final loveSong = createSong(
        id: '1',
        title: 'Enna Sona Romantic Love Ballad',
        artist: 'Arijit Singh',
      );

      final classification = classifier.classifySong(loveSong);

      expect(classification.detectedMoods.contains('Love & Romance'), isTrue);
      expect(classification.confidence, greaterThanOrEqualTo(0.35));

      final smartPl = SmartPlaylistModel(
        id: 'pl_love',
        name: 'Romance Mix',
        category: 'Love & Romance',
        rules: SmartPlaylistRules(selectedMoods: ['Love & Romance']),
      );

      final matched = smartService.evaluateSmartPlaylist(
        playlist: smartPl,
        library: [loveSong],
        classifications: {loveSong.id: classification},
      );

      expect(matched.length, equals(1));
      expect(matched.first.id, equals('1'));
    });

    test('2. Fast Beat & Party: High-energy track detected & included in Fast Beat mix', () {
      final fastSong = createSong(
        id: '2',
        title: 'Vaathi Raid Club Fast Beat Remix',
        artist: 'Anirudh Ravichander',
      );

      final classification = classifier.classifySong(fastSong);

      expect(classification.detectedMoods.contains('Fast Beat'), isTrue);
      expect(classification.energyLevel, equals('high'));

      final fastPl = SmartPlaylistModel(
        id: 'pl_fast',
        name: 'Fast Beat Energy',
        category: 'Fast Beat',
        rules: SmartPlaylistRules(selectedMoods: ['Fast Beat']),
      );

      final matched = smartService.evaluateSmartPlaylist(
        playlist: fastPl,
        library: [fastSong],
        classifications: {fastSong.id: classification},
      );

      expect(matched.length, equals(1));
      expect(matched.first.title, contains('Vaathi Raid'));
    });

    test('3. Sad & Emotional: Detects melancholy keywords & generates tearjerker mix', () {
      final sadSong = createSong(
        id: '3',
        title: 'Po Nee Po Pain of Love Sad Version',
        artist: 'Anirudh Ravichander, Mohit Chauhan',
      );

      final classification = classifier.classifySong(sadSong);

      expect(classification.detectedMoods.contains('Sad & Emotional'), isTrue);

      final sadPl = SmartPlaylistModel(
        id: 'pl_sad',
        name: 'Sad & Emotional',
        category: 'Sad & Emotional',
        rules: SmartPlaylistRules(selectedMoods: ['Sad & Emotional']),
      );

      final matched = smartService.evaluateSmartPlaylist(
        playlist: sadPl,
        library: [sadSong],
        classifications: {sadSong.id: classification},
      );

      expect(matched.length, equals(1));
      expect(matched.first.id, equals('3'));
    });

    test('4. Chill & Relax: Detects tranquil acoustic and ambient vibes', () {
      final chillSong = createSong(
        id: '4',
        title: 'Acoustic Calm Breeze Relaxing Sunset',
        artist: 'Various Artists',
      );

      final classification = classifier.classifySong(chillSong);

      expect(classification.detectedMoods.contains('Chill & Relax'), isTrue);
      expect(classification.energyLevel, equals('low'));

      final chillPl = SmartPlaylistModel(
        id: 'pl_chill',
        name: 'Chill & Relax',
        category: 'Chill & Relax',
        rules: SmartPlaylistRules(selectedMoods: ['Chill & Relax']),
      );

      final matched = smartService.evaluateSmartPlaylist(
        playlist: chillPl,
        library: [chillSong],
        classifications: {chillSong.id: classification},
      );

      expect(matched.length, equals(1));
      expect(matched.first.id, equals('4'));
    });

    test('5. Tamil Melody: Detects Tamil phonetic tokens (Kadhale, Uyire, Anbe) & script', () {
      final tamilSong = createSong(
        id: '5',
        title: 'Yennai Maatrum Kadhale Melody',
        artist: 'Sid Sriram',
      );

      final classification = classifier.classifySong(tamilSong);

      expect(classification.language, equals('tamil'));
      expect(classification.detectedMoods.contains('Tamil Melody'), isTrue);

      final tamilPl = SmartPlaylistModel(
        id: 'pl_tamil',
        name: 'Tamil Melodies',
        category: 'Tamil Melody',
        rules: SmartPlaylistRules(selectedMoods: ['Tamil Melody']),
      );

      final matched = smartService.evaluateSmartPlaylist(
        playlist: tamilPl,
        library: [tamilSong],
        classifications: {tamilSong.id: classification},
      );

      expect(matched.length, equals(1));
      expect(matched.first.id, equals('5'));
    });

    test('6. Favorites-only filter strictly excludes non-favorites', () {
      final favSong = createSong(id: '10', title: 'Romantic Melody 1', artist: 'Artist A', isFavorite: true);
      final nonFavSong = createSong(id: '11', title: 'Romantic Melody 2', artist: 'Artist B', isFavorite: false);

      final class1 = classifier.classifySong(favSong);
      final class2 = classifier.classifySong(nonFavSong);

      final favRules = SmartPlaylistRules(
        selectedMoods: ['Love & Romance'],
        favoritesOnly: true,
      );

      final smartPl = SmartPlaylistModel(
        id: 'pl_fav_romance',
        name: 'Favorite Romance',
        category: 'Love & Romance',
        rules: favRules,
      );

      final matched = smartService.evaluateSmartPlaylist(
        playlist: smartPl,
        library: [favSong, nonFavSong],
        classifications: {favSong.id: class1, nonFavSong.id: class2},
      );

      expect(matched.length, equals(1));
      expect(matched.first.id, equals('10'));
    });

    test('7. Target size limit caps playlist output to specified number of tracks', () {
      final library = List.generate(
        20,
        (i) => createSong(id: '$i', title: 'Love Ballad $i', artist: 'Artist $i'),
      );

      final classifications = <String, SongClassificationModel>{};
      for (final s in library) {
        classifications[s.id] = classifier.classifySong(s);
      }

      final smartPl = SmartPlaylistModel(
        id: 'pl_capped',
        name: 'Top 5 Love Hits',
        category: 'Love & Romance',
        targetSize: 5,
        rules: SmartPlaylistRules(selectedMoods: ['Love & Romance']),
      );

      final matched = smartService.evaluateSmartPlaylist(
        playlist: smartPl,
        library: library,
        classifications: classifications,
      );

      expect(matched.length, equals(5));
    });

    test('8. Empty match fallback: Returns empty list cleanly when no tracks match', () {
      final heavyMetalSong = createSong(
        id: '99',
        title: 'Death Metal Thunder Screaming Guitars',
        artist: 'Metal Band',
      );

      final classification = classifier.classifySong(heavyMetalSong);

      final sleepPl = SmartPlaylistModel(
        id: 'pl_sleep',
        name: 'Sleep & Lullaby',
        category: 'Sleep',
        rules: SmartPlaylistRules(selectedMoods: ['Sleep']),
      );

      final matched = smartService.evaluateSmartPlaylist(
        playlist: sleepPl,
        library: [heavyMetalSong],
        classifications: {heavyMetalSong.id: classification},
      );

      expect(matched, isEmpty);
    });

    test('9. Manual mood correction overrides classifier with confidence 1.0', () {
      final neutralSong = createSong(
        id: '77',
        title: 'Track 01 Without Mood Keywords',
        artist: 'Unknown Artist',
      );

      // Initially unclassified or low confidence
      final initialClassification = classifier.classifySong(neutralSong);

      // User manually corrects mood to Workout with custom tag "beast_mode"
      final corrected = classifier.applyUserCorrection(
        songId: neutralSong.id,
        current: initialClassification,
        newMood: 'Workout',
        userTags: ['beast_mode'],
      );

      expect(corrected.isUserCorrected, isTrue);
      expect(corrected.confidence, equals(1.0));
      expect(corrected.primaryMood, equals('Workout'));
      expect(corrected.userTags, contains('beast_mode'));

      // Now Workout smart playlist must match it
      final workoutPl = SmartPlaylistModel(
        id: 'pl_workout',
        name: 'Workout Mix',
        category: 'Workout',
        rules: SmartPlaylistRules(selectedMoods: ['Workout']),
      );

      final matched = smartService.evaluateSmartPlaylist(
        playlist: workoutPl,
        library: [neutralSong],
        classifications: {neutralSong.id: corrected},
      );

      expect(matched.length, equals(1));
      expect(matched.first.id, equals('77'));
    });

    test('10. Song exclusion persists across regeneration and rule re-evaluation', () {
      final songA = createSong(id: 'A', title: 'Romantic Song A', artist: 'Artist A');
      final songB = createSong(id: 'B', title: 'Romantic Song B', artist: 'Artist B');

      final classA = classifier.classifySong(songA);
      final classB = classifier.classifySong(songB);

      // Exclude songA
      final smartPl = SmartPlaylistModel(
        id: 'pl_exclude',
        name: 'Romance without Song A',
        category: 'Love & Romance',
        rules: SmartPlaylistRules(selectedMoods: ['Love & Romance']),
        excludedSongIds: ['A'],
      );

      final matched = smartService.evaluateSmartPlaylist(
        playlist: smartPl,
        library: [songA, songB],
        classifications: {'A': classA, 'B': classB},
      );

      expect(matched.length, equals(1));
      expect(matched.first.id, equals('B'));
      expect(matched.any((s) => s.id == 'A'), isFalse);
    });

    test('11. Pinned song is guaranteed inclusion at the top even if it fails strict rules', () {
      // Song C is Workout/Fast Beat, NOT romantic
      final fastSong = createSong(id: 'C', title: 'High Tempo Gym Beat', artist: 'DJ Fast');
      final romSong = createSong(id: 'D', title: 'Sweet Gentle Love Song', artist: 'Romantic Singer');

      final classC = classifier.classifySong(fastSong);
      final classD = classifier.classifySong(romSong);

      // Smart playlist is strictly Love & Romance, but user pinned fastSong 'C'
      final smartPl = SmartPlaylistModel(
        id: 'pl_pinned',
        name: 'Love Songs with Special Pin',
        category: 'Love & Romance',
        rules: SmartPlaylistRules(selectedMoods: ['Love & Romance']),
        pinnedSongIds: ['C'],
      );

      final matched = smartService.evaluateSmartPlaylist(
        playlist: smartPl,
        library: [fastSong, romSong],
        classifications: {'C': classC, 'D': classD},
      );

      // Both must be included, and pinned song 'C' must be at index 0
      expect(matched.length, equals(2));
      expect(matched.first.id, equals('C'));
      expect(matched[1].id, equals('D'));
    });

    test('12. Automatic Library Synchronization: cleanses deleted songs without touching audio files', () async {
      // Simulate library where song 'DEL_1' and 'DEL_2' were deleted from disk
      final liveSongs = [
        createSong(id: 'LIVE_1', title: 'Live Song 1', artist: 'Artist 1'),
        createSong(id: 'LIVE_2', title: 'Live Song 2', artist: 'Artist 2'),
      ];

      // Smart playlist had pinned 'DEL_1' and excluded 'DEL_2'
      final smartPl = SmartPlaylistModel(
        id: 'pl_sync_smart',
        name: 'Smart Sync Test',
        category: 'General',
        rules: SmartPlaylistRules(),
        pinnedSongIds: ['DEL_1', 'LIVE_1'],
        excludedSongIds: ['DEL_2', 'LIVE_2'],
      );

      // Manual playlist had 'LIVE_1', 'DEL_1', 'LIVE_2'
      final manualPl = PlaylistModel(
        id: 'pl_sync_manual',
        name: 'Manual Sync Test',
        songIds: ['LIVE_1', 'DEL_1', 'LIVE_2'],
        createdAt: 1000,
      );

      // Run synchronization with current live library
      await smartService.synchronizeWithLibrary(
        smartPlaylists: [smartPl],
        manualPlaylists: [manualPl],
        currentLibrary: liveSongs,
        checkFileExistence: false,
      );

      // Smart playlist must have purged DEL_1 from pinned and DEL_2 from excluded
      expect(smartPl.pinnedSongIds, equals(['LIVE_1']));
      expect(smartPl.excludedSongIds, equals(['LIVE_2']));

      // Manual playlist must have purged DEL_1
      expect(manualPl.songIds, equals(['LIVE_1', 'LIVE_2']));
      expect(manualPl.songCount, equals(2));
    });

    test('13. Conversion from dynamic Smart Playlist to static Manual Snapshot', () {
      final song1 = createSong(id: 'S1', title: 'Romance Hit 1', artist: 'Singer 1');
      final song2 = createSong(id: 'S2', title: 'Romance Hit 2', artist: 'Singer 2');

      final smartPl = SmartPlaylistModel(
        id: 'smart_dyn',
        name: 'Dynamic Romance',
        category: 'Love & Romance',
        rules: SmartPlaylistRules(selectedMoods: ['Love & Romance']),
      );

      final snapshot = smartService.createManualSnapshot(
        source: smartPl,
        evaluatedSongs: [song1, song2],
        snapshotName: 'Romance Snapshot 2026',
      );

      expect(snapshot.name, equals('Romance Snapshot 2026'));
      expect(snapshot.songIds, equals(['S1', 'S2']));
      expect(snapshot.songCount, equals(2));
      expect(snapshot.id, isNot(equals(smartPl.id)));
    });
  });
}
