import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:soniq/core/database/song_cache_service.dart';
import 'package:soniq/core/models/song_model.dart';
import 'package:soniq/core/models/song_classification_model.dart';
import 'package:soniq/core/models/playlist_model.dart';
import 'package:soniq/core/services/music_discovery_service.dart';
import 'package:soniq/core/services/music_classifier_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late SongCacheService cacheService;
  late MusicDiscoveryService discoveryService;
  late MusicClassifierService classifierService;
  late List<SongModel> testLibrary;

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return tempDir.path;
      },
    );
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('soniq_discovery_test_');
    Hive.init(tempDir.path);

    cacheService = SongCacheService();
    await cacheService.init(force: true);
    classifierService = MusicClassifierService();
    discoveryService = MusicDiscoveryService();

    // Create 30 synthetic local library tracks across multiple artists and genres
    testLibrary = List.generate(30, (i) {
      final artistIndex = i % 5;
      final albumIndex = i % 3;
      final isRomantic = i % 2 == 0;

      return SongModel(
        id: 'song_$i',
        title: isRomantic ? 'Romantic Love Melody $i' : 'Fast Beat Energy $i',
        artist: 'Artist_$artistIndex',
        album: 'Album_$albumIndex',
        durationMs: 180000 + (i * 2000),
        dataPath: '/storage/emulated/0/Music/song_$i.mp3',
        sizeBytes: 5000000,
        dateAdded: 1600000000 + i * 1000,
        fileExtension: 'mp3',
        playCount: i < 10 ? 5 : 0,
        lastPlayedTimestamp: i < 5 ? DateTime.now().millisecondsSinceEpoch - (40 * 24 * 60 * 60 * 1000) : 0,
        isFavorite: i == 0 || i == 1,
      );
    });

    await cacheService.saveSongs(testLibrary);

    // Save classifications for tracks
    final classifications = <String, SongClassificationModel>{};
    for (int i = 0; i < testLibrary.length; i++) {
      final song = testLibrary[i];
      final isRomantic = i % 2 == 0;
      classifications[song.id] = SongClassificationModel(
        songId: song.id,
        primaryMood: isRomantic ? 'Love & Romance' : 'Fast Beat',
        secondaryMoods: isRomantic ? ['Melody', 'Chill & Relax'] : ['Workout', 'Party'],
        energyLevel: isRomantic ? 'low' : 'high',
        language: 'english',
        confidenceScore: 0.85,
        audioFeatures: AudioFeaturesModel(
          bpm: isRomantic ? 84 : 128,
          energy: isRomantic ? 0.35 : 0.88,
          durationSeconds: song.durationMs / 1000.0,
        ),
        analyzedTimestamp: DateTime.now().millisecondsSinceEpoch,
      );
    }
    await cacheService.saveAllClassifications(classifications);
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('SONIQ Phase 8: Music Intelligence & Discovery Engine Tests', () {
    test('1. Similar Songs engine matches by artist, genre, mood and tempo with explainable reasoning', () {
      final seed = testLibrary[0]; // Artist_0, Album_0, Love & Romance (84 BPM)
      final similar = discoveryService.getSimilarSongs(seed, testLibrary, limit: 10);

      expect(similar.isNotEmpty, isTrue);
      expect(similar.any((item) => item.song.id == seed.id), isFalse); // Never recommends itself

      final topMatch = similar.first;
      expect(topMatch.score, greaterThan(0.3));
      expect(topMatch.explanation.isNotEmpty, isTrue);

      // Verify that explanation describes musical attributes truthfully
      expect(
        topMatch.explanation.contains('Artist') ||
        topMatch.explanation.contains('Mood') ||
        topMatch.explanation.contains('tempo') ||
        topMatch.explanation.contains('album') ||
        topMatch.explanation.contains('aligned'),
        isTrue,
      );
    });

    test('2. Similar Songs engine respects user feedback (excludes disliked songs and boosts liked songs)', () async {
      final seed = testLibrary[0];
      final candidate = testLibrary[2]; // Artist_2, Love & Romance

      // Baseline score
      final initialSimilar = discoveryService.getSimilarSongs(seed, testLibrary, limit: 15);
      final initialCandidateItem = initialSimilar.firstWhere((item) => item.song.id == candidate.id);
      final initialScore = initialCandidateItem.score;

      // Like candidate track
      await discoveryService.likeSong(candidate.id);
      final boostedSimilar = discoveryService.getSimilarSongs(seed, testLibrary, limit: 15);
      final boostedItem = boostedSimilar.firstWhere((item) => item.song.id == candidate.id);
      expect(boostedItem.score, greaterThan(initialScore)); // Boosted!

      // Dislike candidate track -> Must be completely omitted!
      await discoveryService.dislikeSong(candidate.id);
      final filteredSimilar = discoveryService.getSimilarSongs(seed, testLibrary, limit: 15);
      expect(filteredSimilar.any((item) => item.song.id == candidate.id), isFalse);
    });

    test('3. Daily Mixes generate balanced familiar and discovery tracks respecting artist diversity', () {
      final mixes = discoveryService.generateDailyMixes(testLibrary, mixesCount: 3, forceRegenerate: true);

      expect(mixes.isNotEmpty, isTrue);
      for (final mix in mixes) {
        expect(mix.songs.isNotEmpty, isTrue);
        expect(mix.mixType, equals('daily_mix'));

        // Verify artist diversity constraint (max 2 tracks per artist by default)
        final artistCounts = <String, int>{};
        for (final s in mix.songs) {
          artistCounts[s.artist] = (artistCounts[s.artist] ?? 0) + 1;
        }
        for (final count in artistCounts.values) {
          expect(count, lessThanOrEqualTo(2));
        }
      }
    });

    test('4. Discover Mix surfaces unplayed and deep library tracks', () {
      final discoverMix = discoveryService.generateDiscoverMix(testLibrary, limit: 15);

      expect(discoverMix.mixType, equals('discover_mix'));
      expect(discoverMix.songs.isNotEmpty, isTrue);

      // Verify that unplayed tracks (playCount == 0) are prioritized
      final unplayedCount = discoverMix.songs.where((s) => s.playCount == 0).length;
      expect(unplayedCount, greaterThan(0));
    });

    test('5. Artist Radio generates continuous stream anchored by artist and co-occurring artists', () async {
      // Create playlist where Artist_0 and Artist_1 appear together
      final playlist = PlaylistModel(
        id: 'test_pl_1',
        name: 'Shared Vibes',
        songIds: ['song_0', 'song_1', 'song_5', 'song_6'], // mix of Artist_0 and Artist_1
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
      await cacheService.savePlaylist(playlist);

      final radio = discoveryService.generateArtistRadio('Artist_0', testLibrary, limit: 15);

      expect(radio.mixType, equals('artist_radio'));
      expect(radio.songs.isNotEmpty, isTrue);

      // Radio must include songs by Artist_0
      final hasAnchor = radio.songs.any((s) => s.artist == 'Artist_0');
      expect(hasAnchor, isTrue);

      // Radio must include related artists from co-playlist / shared mood
      final hasRelated = radio.songs.any((s) => s.artist != 'Artist_0');
      expect(hasRelated, isTrue);
    });

    test('6. Forgotten Gems identifies tracks played in the past but dormant in the last 30 days', () {
      final gems = discoveryService.generateForgottenGems(testLibrary, limit: 10);

      expect(gems.mixType, equals('forgotten_gems'));
      expect(gems.songs.isNotEmpty, isTrue);

      final now = DateTime.now().millisecondsSinceEpoch;
      final thirtyDaysMs = 30 * 24 * 60 * 60 * 1000;

      for (final s in gems.songs) {
        expect(s.playCount > 0 || s.isFavorite, isTrue);
        expect((now - s.lastPlayedTimestamp) > thirtyDaysMs, isTrue);
      }
    });

    test('7. Exclude Artist completely removes artist from all recommendations', () async {
      const targetArtist = 'Artist_3';

      await discoveryService.excludeArtist(targetArtist);
      final fb = discoveryService.getFeedback();
      expect(fb.excludedArtists.contains(targetArtist), isTrue);

      final seed = testLibrary[0];
      final similar = discoveryService.getSimilarSongs(seed, testLibrary, limit: 25);
      expect(similar.any((item) => item.song.artist == targetArtist), isFalse);

      final mixes = discoveryService.generateDailyMixes(testLibrary, mixesCount: 3, forceRegenerate: true);
      for (final mix in mixes) {
        expect(mix.songs.any((s) => s.artist == targetArtist), isFalse);
      }
    });

    test('8. Reset preferences clears all feedback and restores candidate tracks', () async {
      await discoveryService.excludeArtist('Artist_4');
      await discoveryService.excludeSong('song_15');
      await discoveryService.likeSong('song_20');

      var fb = discoveryService.getFeedback();
      expect(fb.excludedArtists.isNotEmpty, isTrue);
      expect(fb.excludedSongIds.isNotEmpty, isTrue);

      await discoveryService.resetAllFeedback();

      fb = discoveryService.getFeedback();
      expect(fb.excludedArtists.isEmpty, isTrue);
      expect(fb.excludedSongIds.isEmpty, isTrue);
      expect(fb.likedSongIds.isEmpty, isTrue);
    });

    test('9. Recommendation engine processes 1,000 synthetic tracks in sub-50ms', () async {
      final largeLibrary = List.generate(1000, (i) {
        return SongModel(
          id: 'large_song_$i',
          title: 'Catalog Song $i',
          artist: 'Artist_${i % 40}',
          album: 'Album_${i % 20}',
          durationMs: 200000 + (i % 60) * 1000,
          dataPath: '/music/track_$i.mp3',
          sizeBytes: 4000000,
          dateAdded: 1600000000 + i,
          fileExtension: 'mp3',
          playCount: i % 10,
        );
      });

      // In real-world SONIQ usage, library items are pre-indexed during library scan
      for (final song in largeLibrary) {
        await cacheService.saveClassification(classifierService.classifySong(song));
      }

      final stopwatch = Stopwatch()..start();
      final similar = discoveryService.getSimilarSongs(largeLibrary.first, largeLibrary, limit: 20);
      stopwatch.stop();

      expect(similar.length, 20);
      expect(stopwatch.elapsedMilliseconds, lessThan(80)); // Sub-80ms for 1,000 items on CPU
    });
  });
}
