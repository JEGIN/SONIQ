import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:soniq/core/database/song_cache_service.dart';
import 'package:soniq/core/models/analytics_summary_model.dart';
import 'package:soniq/core/models/playback_event_model.dart';
import 'package:soniq/core/models/song_model.dart';
import 'package:soniq/core/services/listening_analytics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late SongCacheService cacheService;
  late ListeningAnalyticsService analyticsService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('soniq_analytics_test_');

    const MethodChannel pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      pathChannel,
      (MethodCall methodCall) async => tempDir.path,
    );

    cacheService = SongCacheService();
    await cacheService.init(force: true);
    analyticsService = ListeningAnalyticsService();
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  SongModel createTestSong({
    required String id,
    required String title,
    required String artist,
    required String album,
    int durationMs = 180000,
    bool isFavorite = false,
  }) {
    return SongModel(
      id: id,
      title: title,
      artist: artist,
      album: album,
      durationMs: durationMs,
      sizeBytes: 4000000,
      dataPath: '/music/$id.mp3',
      fileExtension: 'mp3',
      dateAdded: DateTime.now().millisecondsSinceEpoch,
      isFavorite: isFavorite,
    );
  }

  PlaybackEventModel createTestEvent({
    required String songId,
    required String title,
    required String artist,
    required String album,
    required int startTimeMs,
    required int listenedMs,
    int trackDurationMs = 180000,
    bool isSkipped = false,
    String source = 'all_songs',
    String sessionId = 'sess_1',
  }) {
    final completion = (listenedMs / trackDurationMs).clamp(0.0, 1.0);
    final isQualified = trackDurationMs < 60000 ? listenedMs >= (trackDurationMs * 0.5) : listenedMs >= 30000;

    return PlaybackEventModel(
      id: 'evt_${startTimeMs}_$songId',
      songId: songId,
      songTitle: title,
      artistId: artist,
      artistName: artist,
      albumId: album,
      albumName: album,
      trackDurationMs: trackDurationMs,
      startTimeMs: startTimeMs,
      endTimeMs: startTimeMs + listenedMs,
      listenedDurationMs: listenedMs,
      completionPercentage: completion,
      isQualifiedPlay: isQualified,
      isSkipped: isSkipped,
      playbackSource: source,
      sessionId: sessionId,
    );
  }

  group('PlaybackEventModel Serialization', () {
    test('Correctly serializes and deserializes full playback event', () {
      final event = PlaybackEventModel(
        id: 'evt_101',
        songId: 'song_1',
        songTitle: 'Master the Blaster',
        artistId: 'Anirudh',
        artistName: 'Anirudh Ravichander',
        albumId: 'Master',
        albumName: 'Master OST',
        genre: 'Tamil Kuthu',
        trackDurationMs: 210000,
        startTimeMs: 1700000000000,
        endTimeMs: 1700000200000,
        listenedDurationMs: 195000,
        completionPercentage: 0.92,
        isQualifiedPlay: true,
        isSkipped: false,
        playbackSource: 'android_auto',
        sessionId: 'sess_auto_1',
        outputProfile: 'car_audio',
      );

      final jsonStr = event.toJson();
      final restored = PlaybackEventModel.fromJson(jsonStr);

      expect(restored.id, 'evt_101');
      expect(restored.songId, 'song_1');
      expect(restored.songTitle, 'Master the Blaster');
      expect(restored.artistName, 'Anirudh Ravichander');
      expect(restored.albumName, 'Master OST');
      expect(restored.listenedDurationMs, 195000);
      expect(restored.isQualifiedPlay, true);
      expect(restored.isSkipped, false);
      expect(restored.playbackSource, 'android_auto');
      expect(restored.outputProfile, 'car_audio');
    });
  });

  group('Play-Count Definitions & Qualification Rules', () {
    test('Track listened for less than 30s is NOT a qualified play', () {
      final event = createTestEvent(
        songId: 's1',
        title: 'Song 1',
        artist: 'Artist A',
        album: 'Album X',
        startTimeMs: DateTime.now().millisecondsSinceEpoch,
        listenedMs: 25000, // 25 seconds (< 30s)
        trackDurationMs: 200000,
      );

      expect(event.isQualifiedPlay, isFalse);
    });

    test('Track listened for 30s or more is a qualified play', () {
      final event = createTestEvent(
        songId: 's1',
        title: 'Song 1',
        artist: 'Artist A',
        album: 'Album X',
        startTimeMs: DateTime.now().millisecondsSinceEpoch,
        listenedMs: 35000, // 35 seconds (>= 30s)
        trackDurationMs: 200000,
      );

      expect(event.isQualifiedPlay, isTrue);
    });

    test('Short track (< 60s) qualifies at 50% threshold', () {
      // 40 second track
      final shortEventQualified = createTestEvent(
        songId: 'short1',
        title: 'Intro Jingle',
        artist: 'Artist A',
        album: 'Album X',
        startTimeMs: DateTime.now().millisecondsSinceEpoch,
        listenedMs: 22000, // 22s >= 50% of 40s (20s)
        trackDurationMs: 40000,
      );

      final shortEventUnqualified = createTestEvent(
        songId: 'short2',
        title: 'Intro Jingle 2',
        artist: 'Artist A',
        album: 'Album X',
        startTimeMs: DateTime.now().millisecondsSinceEpoch,
        listenedMs: 15000, // 15s < 50% of 40s (20s)
        trackDurationMs: 40000,
      );

      expect(shortEventQualified.isQualifiedPlay, isTrue);
      expect(shortEventUnqualified.isQualifiedPlay, isFalse);
    });
  });

  group('Listening Analytics Aggregation Engine', () {
    test('Computes accurate listening time, completion rate, and rankings', () async {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);

      // Seed 4 events:
      // Song A: 120s (qualified, completed), Song A: 100s (qualified, completed) -> Total 220s, 2 plays
      // Song B: 40s (qualified, skipped) -> Total 40s, 1 play
      // Song C: 15s (unqualified, skipped) -> Total 15s, 0 plays
      final e1 = createTestEvent(
        songId: 's_a',
        title: 'Song A',
        artist: 'Artist Alpha',
        album: 'Album Red',
        startTimeMs: startOfToday.add(const Duration(minutes: 10)).millisecondsSinceEpoch,
        listenedMs: 120000,
        trackDurationMs: 120000,
        isSkipped: false,
        sessionId: 'sess_1',
      );
      final e2 = createTestEvent(
        songId: 's_a',
        title: 'Song A',
        artist: 'Artist Alpha',
        album: 'Album Red',
        startTimeMs: startOfToday.add(const Duration(minutes: 20)).millisecondsSinceEpoch,
        listenedMs: 100000,
        trackDurationMs: 120000,
        isSkipped: false,
        sessionId: 'sess_1',
      );
      final e3 = createTestEvent(
        songId: 's_b',
        title: 'Song B',
        artist: 'Artist Beta',
        album: 'Album Blue',
        startTimeMs: startOfToday.add(const Duration(minutes: 30)).millisecondsSinceEpoch,
        listenedMs: 40000,
        trackDurationMs: 150000,
        isSkipped: true,
        sessionId: 'sess_2',
      );
      final e4 = createTestEvent(
        songId: 's_c',
        title: 'Song C',
        artist: 'Artist Beta',
        album: 'Album Blue',
        startTimeMs: startOfToday.add(const Duration(minutes: 40)).millisecondsSinceEpoch,
        listenedMs: 15000,
        trackDurationMs: 180000,
        isSkipped: true,
        sessionId: 'sess_2',
      );

      await cacheService.savePlaybackEvent(e1);
      await cacheService.savePlaybackEvent(e2);
      await cacheService.savePlaybackEvent(e3);
      await cacheService.savePlaybackEvent(e4);

      final summary = await analyticsService.computeSummary(filter: AnalyticsTimeFilter.today);

      // Verify Totals
      expect(summary.totalListeningTimeMs, 120000 + 100000 + 40000 + 15000);
      expect(summary.totalEvents, 4);
      expect(summary.qualifiedPlays, 3); // e1, e2, e3 are qualified
      expect(summary.completedPlays, 1); // e1 has 100% completion
      expect(summary.skippedPlays, 2); // e3, e4 are skipped
      expect(summary.uniqueTracksPlayed, 3);
      expect(summary.uniqueArtistsPlayed, 2);
      expect(summary.uniqueAlbumsPlayed, 2);

      // Verify Top Songs Ranking
      expect(summary.topSongs.first.id, 's_a');
      expect(summary.topSongs.first.playCount, 2);
      expect(summary.topSongs.first.totalListeningMs, 220000);

      // Verify Top Artists Ranking
      expect(summary.topArtists.first.id, 'Artist Alpha');
      expect(summary.topArtists.first.playCount, 2);
    });

    test('Calculates current streak and longest streak accurately', () async {
      final now = DateTime.now();

      // Create qualified events on 3 consecutive days (today, yesterday, 2 days ago)
      final dToday = DateTime(now.year, now.month, now.day, 14, 0).millisecondsSinceEpoch;
      final dYest = DateTime(now.year, now.month, now.day - 1, 14, 0).millisecondsSinceEpoch;
      final d2DaysAgo = DateTime(now.year, now.month, now.day - 2, 14, 0).millisecondsSinceEpoch;

      await cacheService.savePlaybackEvent(createTestEvent(
        songId: 's1',
        title: 'Track 1',
        artist: 'A1',
        album: 'Alb1',
        startTimeMs: d2DaysAgo,
        listenedMs: 60000,
      ));
      await cacheService.savePlaybackEvent(createTestEvent(
        songId: 's1',
        title: 'Track 1',
        artist: 'A1',
        album: 'Alb1',
        startTimeMs: dYest,
        listenedMs: 60000,
      ));
      await cacheService.savePlaybackEvent(createTestEvent(
        songId: 's1',
        title: 'Track 1',
        artist: 'A1',
        album: 'Alb1',
        startTimeMs: dToday,
        listenedMs: 60000,
      ));

      final summary = await analyticsService.computeSummary(filter: AnalyticsTimeFilter.allTime);

      expect(summary.currentStreakDays, 3);
      expect(summary.longestStreakDays, 3);
    });
  });

  group('Discovery Insights & SONIQ Replay', () {
    test('Identifies forgotten favorites and frequently skipped tracks', () async {
      final now = DateTime.now();
      final sixtyDaysAgo = now.subtract(const Duration(days: 60)).millisecondsSinceEpoch;

      final songFav = createTestSong(
        id: 'fav_old',
        title: 'Old Favorite Song',
        artist: 'Classic Artist',
        album: 'Classic Album',
        isFavorite: true,
      );
      final songSkipped = createTestSong(
        id: 'skip_heavy',
        title: 'Annoying Track',
        artist: 'Pop Artist',
        album: 'Pop Album',
      );

      final library = [songFav, songSkipped];

      // Event for fav_old was 60 days ago
      await cacheService.savePlaybackEvent(createTestEvent(
        songId: 'fav_old',
        title: songFav.title,
        artist: songFav.artist,
        album: songFav.album,
        startTimeMs: sixtyDaysAgo,
        listenedMs: 120000,
      ));

      // 4 events for songSkipped, all skipped
      for (int i = 0; i < 4; i++) {
        await cacheService.savePlaybackEvent(createTestEvent(
          songId: 'skip_heavy',
          title: songSkipped.title,
          artist: songSkipped.artist,
          album: songSkipped.album,
          startTimeMs: now.subtract(Duration(hours: i + 1)).millisecondsSinceEpoch,
          listenedMs: 5000,
          isSkipped: true,
        ));
      }

      final insights = await analyticsService.generateDiscoveryInsights(library);

      expect(insights.forgottenFavorites.any((s) => s.id == 'fav_old'), isTrue);
      expect(insights.frequentlySkippedSongs.any((s) => s.id == 'skip_heavy'), isTrue);
    });

    test('Generates annual SONIQ Replay with accurate metrics and milestones', () async {
      final year = DateTime.now().year;
      final eventTime = DateTime(year, 6, 15, 12, 0).millisecondsSinceEpoch;

      final s1 = createTestSong(id: 's1', title: 'Summer Hit', artist: 'Sun Band', album: 'Heat');

      await cacheService.savePlaybackEvent(createTestEvent(
        songId: s1.id,
        title: s1.title,
        artist: s1.artist,
        album: s1.album,
        startTimeMs: eventTime,
        listenedMs: 180000,
      ));

      final replay = await analyticsService.generateSoniqReplay(year, [s1]);

      expect(replay.year, year);
      expect(replay.totalQualifiedPlays, 1);
      expect(replay.topSongs.first.title, 'Summer Hit');
      expect(replay.topArtists.first.title, 'Sun Band');
      expect(replay.peakMonth, 'June');
      expect(replay.milestones, isNotEmpty);
    });
  });

  group('Privacy Controls & Data Management', () {
    test('Clearing analytics deletes event records while preserving songs and favorites', () async {
      final s = createTestSong(id: 's_keep', title: 'Keep Me', artist: 'Artist', album: 'Album', isFavorite: true);
      await cacheService.saveSongs([s]);
      await cacheService.setFavorite(s.id, true);

      await cacheService.savePlaybackEvent(createTestEvent(
        songId: s.id,
        title: s.title,
        artist: s.artist,
        album: s.album,
        startTimeMs: DateTime.now().millisecondsSinceEpoch,
        listenedMs: 60000,
      ));

      expect(cacheService.getAllPlaybackEvents().length, 1);
      expect(cacheService.getCachedSongs().length, 1);
      expect(cacheService.getFavoriteSongIds().contains(s.id), isTrue);

      // Clear all analytics data
      await cacheService.clearAllPlaybackEvents();

      expect(cacheService.getAllPlaybackEvents().isEmpty, isTrue);
      // Original songs and favorites MUST remain intact
      expect(cacheService.getCachedSongs().length, 1);
      expect(cacheService.getFavoriteSongIds().contains(s.id), isTrue);
    });

    test('Exporting analytics generates valid JSON', () async {
      await cacheService.savePlaybackEvent(createTestEvent(
        songId: 'exp1',
        title: 'Export Song',
        artist: 'Export Artist',
        album: 'Export Album',
        startTimeMs: 1700000000000,
        listenedMs: 45000,
      ));

      final jsonOutput = await analyticsService.exportAnalyticsJson();
      expect(jsonOutput.contains('Export Song'), isTrue);
      expect(jsonOutput.contains('SONIQ Offline Music Player'), isTrue);
    });
  });
}
