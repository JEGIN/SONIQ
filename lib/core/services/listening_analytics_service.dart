import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/song_cache_service.dart';
import '../models/analytics_summary_model.dart';
import '../models/discovery_insights_model.dart';
import '../models/playback_event_model.dart';
import '../models/song_model.dart';
import '../models/soniq_replay_model.dart';

class ListeningAnalyticsService {
  static final ListeningAnalyticsService _instance =
      ListeningAnalyticsService._internal();
  factory ListeningAnalyticsService() => _instance;
  ListeningAnalyticsService._internal();

  final SongCacheService _cacheService = SongCacheService();

  /// Computes a comprehensive listening summary for a given time filter
  Future<AnalyticsSummaryModel> computeSummary({
    AnalyticsTimeFilter filter = AnalyticsTimeFilter.last30Days,
    DateTimeRange? customRange,
  }) async {
    final allEvents = _cacheService.getAllPlaybackEvents();
    final range = filter.getRange(customRange);

    // 1. Filter events by timestamp
    final List<PlaybackEventModel> filtered;
    if (range != null) {
      final startMs = range.start.millisecondsSinceEpoch;
      final endMs = range.end.millisecondsSinceEpoch;
      filtered = allEvents
          .where((e) => e.startTimeMs >= startMs && e.startTimeMs <= endMs)
          .toList();
    } else {
      filtered = allEvents;
    }

    if (filtered.isEmpty) {
      return AnalyticsSummaryModel(
        filter: filter,
        dateRange: range,
        totalListeningTimeMs: 0,
        totalEvents: 0,
        qualifiedPlays: 0,
        completedPlays: 0,
        skippedPlays: 0,
        completionRate: 0.0,
        skipRate: 0.0,
        uniqueTracksPlayed: 0,
        uniqueArtistsPlayed: 0,
        uniqueAlbumsPlayed: 0,
        averageDailyListeningMs: 0,
        averageSessionDurationMs: 0,
        currentStreakDays: 0,
        longestStreakDays: 0,
        peakListeningHour: 20,
        topSongs: const [],
        topArtists: const [],
        topAlbums: const [],
        topGenres: const [],
        dailyMetrics: const [],
        hourlyMetrics: _emptyHourlyMetrics(),
        weekdayVsWeekend: const {'weekday': 0, 'weekend': 0},
        dayParts: const {
          'morning': 0,
          'afternoon': 0,
          'evening': 0,
          'night': 0,
        },
      );
    }

    // 2. Aggregate Base Totals
    int totalListeningTimeMs = 0;
    int qualifiedPlays = 0;
    int completedPlays = 0;
    int skippedPlays = 0;
    final uniqueSongIds = <String>{};
    final uniqueArtists = <String>{};
    final uniqueAlbums = <String>{};

    for (final e in filtered) {
      totalListeningTimeMs += e.listenedDurationMs;
      if (e.isQualifiedPlay) qualifiedPlays++;
      if (e.completionPercentage >= 0.90) completedPlays++;
      if (e.isSkipped) skippedPlays++;
      uniqueSongIds.add(e.songId);
      uniqueArtists.add(e.artistName);
      uniqueAlbums.add(e.albumName);
    }

    final totalEvents = filtered.length;
    final completionRate = totalEvents > 0
        ? (completedPlays / totalEvents)
        : 0.0;
    final skipRate = totalEvents > 0 ? (skippedPlays / totalEvents) : 0.0;

    // 3. Average Daily Listening Calculation
    final uniqueDaysInPeriod = <String>{};
    for (final e in filtered) {
      final d = DateTime.fromMillisecondsSinceEpoch(e.startTimeMs);
      uniqueDaysInPeriod.add(DateFormat('yyyy-MM-dd').format(d));
    }
    final activeDayCount = uniqueDaysInPeriod.isEmpty
        ? 1
        : uniqueDaysInPeriod.length;
    final averageDailyListeningMs = totalListeningTimeMs ~/ activeDayCount;

    // 4. Session Duration Calculation
    final sessionMap = <String, int>{};
    for (final e in filtered) {
      sessionMap[e.sessionId] =
          (sessionMap[e.sessionId] ?? 0) + e.listenedDurationMs;
    }
    final totalSessions = sessionMap.isEmpty ? 1 : sessionMap.length;
    final totalSessionDuration = sessionMap.values.fold<int>(
      0,
      (a, b) => a + b,
    );
    final averageSessionDurationMs = totalSessionDuration ~/ totalSessions;

    // 5. Streaks (Computed across qualified plays in all history)
    final streakData = _calculateStreaks(allEvents);

    // 6. Top Songs
    final songGroups = <String, List<PlaybackEventModel>>{};
    for (final e in filtered) {
      songGroups.putIfAbsent(e.songId, () => []).add(e);
    }

    final topSongs =
        songGroups.entries.map((entry) {
          final list = entry.value;
          final first = list.first;
          final playCount = list.where((e) => e.isQualifiedPlay).length;
          final songDurationMs = list.fold<int>(
            0,
            (sum, e) => sum + e.listenedDurationMs,
          );
          final completed = list
              .where((e) => e.completionPercentage >= 0.90)
              .length;
          final skipped = list.where((e) => e.isSkipped).length;
          final percentage = totalListeningTimeMs > 0
              ? (songDurationMs / totalListeningTimeMs)
              : 0.0;

          return TopItemMetric(
            id: first.songId,
            title: first.songTitle,
            subtitle: first.artistName,
            playCount: playCount,
            totalListeningMs: songDurationMs,
            completionRate: list.isNotEmpty ? completed / list.length : 0.0,
            skipRate: list.isNotEmpty ? skipped / list.length : 0.0,
            extraInfo: first.albumName,
            percentage: percentage,
          );
        }).toList()..sort((a, b) {
          final c = b.playCount.compareTo(a.playCount);
          if (c != 0) return c;
          final d = b.totalListeningMs.compareTo(a.totalListeningMs);
          if (d != 0) return d;
          return a.title.compareTo(b.title);
        });

    // 7. Top Artists
    final artistGroups = <String, List<PlaybackEventModel>>{};
    for (final e in filtered) {
      artistGroups.putIfAbsent(e.artistName, () => []).add(e);
    }

    final topArtists =
        artistGroups.entries.map((entry) {
          final list = entry.value;
          final artistName = entry.key;
          final playCount = list.where((e) => e.isQualifiedPlay).length;
          final durationMs = list.fold<int>(
            0,
            (sum, e) => sum + e.listenedDurationMs,
          );
          final uniqueSongs = list.map((e) => e.songId).toSet().length;
          final percentage = totalListeningTimeMs > 0
              ? (durationMs / totalListeningTimeMs)
              : 0.0;

          return TopItemMetric(
            id: artistName,
            title: artistName,
            subtitle: '$uniqueSongs songs played',
            playCount: playCount,
            totalListeningMs: durationMs,
            percentage: percentage,
          );
        }).toList()..sort((a, b) {
          final c = b.playCount.compareTo(a.playCount);
          if (c != 0) return c;
          return b.totalListeningMs.compareTo(a.totalListeningMs);
        });

    // 8. Top Albums
    final albumGroups = <String, List<PlaybackEventModel>>{};
    for (final e in filtered) {
      albumGroups.putIfAbsent(e.albumName, () => []).add(e);
    }

    final topAlbums =
        albumGroups.entries.map((entry) {
          final list = entry.value;
          final albumName = entry.key;
          final artistName = list.first.artistName;
          final playCount = list.where((e) => e.isQualifiedPlay).length;
          final durationMs = list.fold<int>(
            0,
            (sum, e) => sum + e.listenedDurationMs,
          );
          final completed = list
              .where((e) => e.completionPercentage >= 0.90)
              .length;
          final percentage = totalListeningTimeMs > 0
              ? (durationMs / totalListeningTimeMs)
              : 0.0;

          return TopItemMetric(
            id: albumName,
            title: albumName,
            subtitle: artistName,
            playCount: playCount,
            totalListeningMs: durationMs,
            completionRate: list.isNotEmpty ? completed / list.length : 0.0,
            percentage: percentage,
          );
        }).toList()..sort((a, b) {
          final c = b.playCount.compareTo(a.playCount);
          if (c != 0) return c;
          return b.totalListeningMs.compareTo(a.totalListeningMs);
        });

    // 9. Top Genres
    final genreGroups = <String, List<PlaybackEventModel>>{};
    for (final e in filtered) {
      genreGroups.putIfAbsent(e.genre, () => []).add(e);
    }

    final topGenres =
        genreGroups.entries.map((entry) {
            final list = entry.value;
            final genre = entry.key;
            final playCount = list.where((e) => e.isQualifiedPlay).length;
            final durationMs = list.fold<int>(
              0,
              (sum, e) => sum + e.listenedDurationMs,
            );
            final percentage = totalListeningTimeMs > 0
                ? (durationMs / totalListeningTimeMs)
                : 0.0;

            return TopItemMetric(
              id: genre,
              title: genre,
              subtitle: '$playCount plays',
              playCount: playCount,
              totalListeningMs: durationMs,
              percentage: percentage,
            );
          }).toList()
          ..sort((a, b) => b.totalListeningMs.compareTo(a.totalListeningMs));

    // 10. Hourly Distribution & Peak Hour
    final hourMinutes = List<int>.filled(24, 0);
    final hourPlays = List<int>.filled(24, 0);
    for (final e in filtered) {
      final hour = DateTime.fromMillisecondsSinceEpoch(e.startTimeMs).hour;
      hourMinutes[hour] += e.listenedDurationMs ~/ 60000;
      if (e.isQualifiedPlay) hourPlays[hour]++;
    }

    int peakHour = 0;
    int maxHourMin = -1;
    for (int h = 0; h < 24; h++) {
      if (hourMinutes[h] > maxHourMin) {
        maxHourMin = hourMinutes[h];
        peakHour = h;
      }
    }

    final hourlyMetrics = List.generate(
      24,
      (h) => HourlyListeningMetric(
        hour: h,
        listeningMinutes: hourMinutes[h],
        playCount: hourPlays[h],
      ),
    );

    // 11. Daily Distribution (up to 30 intervals)
    final dailyMap = <String, List<PlaybackEventModel>>{};
    for (final e in filtered) {
      final dStr = DateFormat('yyyy-MM-dd')
          .format(DateTime.fromMillisecondsSinceEpoch(e.startTimeMs));
      dailyMap.putIfAbsent(dStr, () => []).add(e);
    }

    final sortedDates = dailyMap.keys.toList()..sort();
    List<String> metricDates = sortedDates;
    if (filter == AnalyticsTimeFilter.last7Days) {
      final today = DateTime.now();
      final firstDay = DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(const Duration(days: 6));
      metricDates = List.generate(
        7,
        (index) =>
            DateFormat('yyyy-MM-dd')
                .format(firstDay.add(Duration(days: index))),
      );
    }
    final dailyMetrics = metricDates.map((dStr) {
      final list = dailyMap[dStr] ?? const <PlaybackEventModel>[];
      final minutes = list.fold<int>(
        0,
        (acc, e) => acc + (e.listenedDurationMs ~/ 60000),
      );
      final qPlays = list.where((e) => e.isQualifiedPlay).length;
      return DailyListeningMetric(
        date: DateTime.parse(dStr),
        listeningMinutes: minutes,
        qualifiedPlays: qPlays,
      );
    }).toList();

    // 12. Weekday vs Weekend
    int weekdayMs = 0;
    int weekendMs = 0;
    for (final e in filtered) {
      final day = DateTime.fromMillisecondsSinceEpoch(e.startTimeMs).weekday;
      if (day == DateTime.saturday || day == DateTime.sunday) {
        weekendMs += e.listenedDurationMs;
      } else {
        weekdayMs += e.listenedDurationMs;
      }
    }

    // 13. Day Parts (Morning, Afternoon, Evening, Night)
    int morningMs = 0;
    int afternoonMs = 0;
    int eveningMs = 0;
    int nightMs = 0;

    for (final e in filtered) {
      final h = DateTime.fromMillisecondsSinceEpoch(e.startTimeMs).hour;
      if (h >= 5 && h < 12) {
        morningMs += e.listenedDurationMs;
      } else if (h >= 12 && h < 17) {
        afternoonMs += e.listenedDurationMs;
      } else if (h >= 17 && h < 22) {
        eveningMs += e.listenedDurationMs;
      } else {
        nightMs += e.listenedDurationMs;
      }
    }

    return AnalyticsSummaryModel(
      filter: filter,
      dateRange: range,
      totalListeningTimeMs: totalListeningTimeMs,
      totalEvents: totalEvents,
      qualifiedPlays: qualifiedPlays,
      completedPlays: completedPlays,
      skippedPlays: skippedPlays,
      completionRate: completionRate,
      skipRate: skipRate,
      uniqueTracksPlayed: uniqueSongIds.length,
      uniqueArtistsPlayed: uniqueArtists.length,
      uniqueAlbumsPlayed: uniqueAlbums.length,
      averageDailyListeningMs: averageDailyListeningMs,
      averageSessionDurationMs: averageSessionDurationMs,
      currentStreakDays: streakData['current'] ?? 0,
      longestStreakDays: streakData['longest'] ?? 0,
      peakListeningHour: peakHour,
      mostPlayedSong: topSongs.isNotEmpty ? topSongs.first : null,
      mostPlayedArtist: topArtists.isNotEmpty ? topArtists.first : null,
      mostPlayedAlbum: topAlbums.isNotEmpty ? topAlbums.first : null,
      topSongs: topSongs,
      topArtists: topArtists,
      topAlbums: topAlbums,
      topGenres: topGenres,
      dailyMetrics: dailyMetrics,
      hourlyMetrics: hourlyMetrics,
      weekdayVsWeekend: {'weekday': weekdayMs, 'weekend': weekendMs},
      dayParts: {
        'morning': morningMs,
        'afternoon': afternoonMs,
        'evening': eveningMs,
        'night': nightMs,
      },
    );
  }

  /// Calculates current streak and longest historical streak in days
  Map<String, int> _calculateStreaks(List<PlaybackEventModel> allEvents) {
    if (allEvents.isEmpty) return {'current': 0, 'longest': 0};

    // Collect calendar days with at least 1 qualified play
    final qualifiedDays = <DateTime>{};
    for (final e in allEvents) {
      if (e.isQualifiedPlay) {
        final d = DateTime.fromMillisecondsSinceEpoch(e.startTimeMs);
        qualifiedDays.add(DateTime(d.year, d.month, d.day));
      }
    }

    if (qualifiedDays.isEmpty) return {'current': 0, 'longest': 0};

    final sortedDays = qualifiedDays.toList()..sort();

    int longestStreak = 1;
    int tempStreak = 1;

    for (int i = 1; i < sortedDays.length; i++) {
      final prev = sortedDays[i - 1];
      final curr = sortedDays[i];
      if (curr.difference(prev).inDays == 1) {
        tempStreak++;
        if (tempStreak > longestStreak) {
          longestStreak = tempStreak;
        }
      } else {
        tempStreak = 1;
      }
    }

    // Current Streak calculation
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    int currentStreak = 0;
    if (qualifiedDays.contains(today) || qualifiedDays.contains(yesterday)) {
      DateTime checkDate = qualifiedDays.contains(today) ? today : yesterday;
      while (qualifiedDays.contains(checkDate)) {
        currentStreak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      }
    }

    return {'current': currentStreak, 'longest': longestStreak};
  }

  List<HourlyListeningMetric> _emptyHourlyMetrics() {
    return List.generate(
      24,
      (h) => HourlyListeningMetric(hour: h, listeningMinutes: 0, playCount: 0),
    );
  }

  /// Generates personalized music discovery recommendations based on listening history
  Future<DiscoveryInsightsModel> generateDiscoveryInsights(
    List<SongModel> library,
  ) async {
    final allEvents = _cacheService.getAllPlaybackEvents();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final thirtyDaysMs = 30 * 24 * 60 * 60 * 1000;
    final fortyFiveDaysMs = 45 * 24 * 60 * 60 * 1000;
    final sevenDaysMs = 7 * 24 * 60 * 60 * 1000;

    final songLastPlayedMap = <String, int>{};
    final songEventsMap = <String, List<PlaybackEventModel>>{};

    for (final e in allEvents) {
      songEventsMap.putIfAbsent(e.songId, () => []).add(e);
      final existing = songLastPlayedMap[e.songId] ?? 0;
      if (e.startTimeMs > existing) {
        songLastPlayedMap[e.songId] = e.startTimeMs;
      }
    }

    // 1. Forgotten Favorites: Marked as Favorite, but not played in > 30 days
    final forgottenFavorites = library
        .where((s) {
          if (!s.isFavorite) return false;
          final lastPlayed = songLastPlayedMap[s.id] ?? s.lastPlayedTimestamp;
          return (nowMs - lastPlayed) > thirtyDaysMs;
        })
        .take(10)
        .toList();

    // 2. Rediscovered Music: Played in the last 7 days after a silence of > 45 days
    final rediscovered = <SongModel>[];
    for (final entry in songEventsMap.entries) {
      final events = entry.value
        ..sort((a, b) => a.startTimeMs.compareTo(b.startTimeMs));
      if (events.length >= 2) {
        final last = events.last;
        if (nowMs - last.startTimeMs <= sevenDaysMs) {
          final secondLast = events[events.length - 2];
          if ((last.startTimeMs - secondLast.startTimeMs) >= fortyFiveDaysMs) {
            final match = library.where((s) => s.id == entry.key);
            if (match.isNotEmpty) {
              rediscovered.add(match.first);
            }
          }
        }
      }
    }

    // 3. Underplayed Albums: Albums in the library with <= 1 plays
    final albumPlays = <String, int>{};
    for (final e in allEvents) {
      albumPlays[e.albumName] =
          (albumPlays[e.albumName] ?? 0) + (e.isQualifiedPlay ? 1 : 0);
    }
    final allLibraryAlbums = library.map((s) => s.album).toSet();
    final underplayedAlbums = allLibraryAlbums
        .where(
          (alb) =>
              (albumPlays[alb] ?? 0) <= 1 && alb.isNotEmpty && alb != 'Unknown',
        )
        .take(8)
        .toList();

    // 4. Most Replayed Songs: Highest ratio of multi-plays in single sessions
    final sessionSongCounts = <String, Map<String, int>>{};
    for (final e in allEvents) {
      if (e.isQualifiedPlay) {
        sessionSongCounts.putIfAbsent(e.sessionId, () => {});
        sessionSongCounts[e.sessionId]![e.songId] =
            (sessionSongCounts[e.sessionId]![e.songId] ?? 0) + 1;
      }
    }
    final replayedSongScores = <String, int>{};
    for (final map in sessionSongCounts.values) {
      for (final entry in map.entries) {
        if (entry.value >= 2) {
          replayedSongScores[entry.key] =
              (replayedSongScores[entry.key] ?? 0) + entry.value;
        }
      }
    }
    final sortedReplayed = replayedSongScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final mostReplayed = <SongModel>[];
    for (final item in sortedReplayed.take(8)) {
      final match = library.where((s) => s.id == item.key);
      if (match.isNotEmpty) {
        mostReplayed.add(match.first);
      }
    }

    // 5. Frequently Skipped Songs (skip rate >= 50% with at least 3 attempts)
    final frequentlySkipped = <SongModel>[];
    for (final entry in songEventsMap.entries) {
      final list = entry.value;
      if (list.length >= 3) {
        final skipCount = list.where((e) => e.isSkipped).length;
        if ((skipCount / list.length) >= 0.50) {
          final match = library.where((s) => s.id == entry.key);
          if (match.isNotEmpty) {
            frequentlySkipped.add(match.first);
          }
        }
      }
    }

    // 6. Heavy Rotation Artists (past 14 days)
    final fourteenDaysMs = 14 * 24 * 60 * 60 * 1000;
    final recentArtistPlays = <String, int>{};
    for (final e in allEvents) {
      if (nowMs - e.startTimeMs <= fourteenDaysMs && e.isQualifiedPlay) {
        recentArtistPlays[e.artistName] =
            (recentArtistPlays[e.artistName] ?? 0) + 1;
      }
    }
    final heavyRotation = recentArtistPlays.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return DiscoveryInsightsModel(
      forgottenFavorites: forgottenFavorites,
      rediscoveredMusic: rediscovered.take(8).toList(),
      underplayedAlbums: underplayedAlbums,
      mostReplayedSongs: mostReplayed,
      frequentlySkippedSongs: frequentlySkipped.take(8).toList(),
      heavyRotationArtists: heavyRotation.take(6).map((e) => e.key).toList(),
    );
  }

  /// Generates the annual SONIQ Replay summary (e.g. for Spotify Wrapped / Apple Music Replay)
  Future<SoniqReplayModel> generateSoniqReplay(
    int year,
    List<SongModel> library,
  ) async {
    final startOfYear = DateTime(year, 1, 1).millisecondsSinceEpoch;
    final endOfYear = DateTime(year, 12, 31, 23, 59, 59).millisecondsSinceEpoch;

    final yearEvents = _cacheService
        .getAllPlaybackEvents()
        .where(
          (e) => e.startTimeMs >= startOfYear && e.startTimeMs <= endOfYear,
        )
        .toList();

    int totalListeningTimeMs = 0;
    int qualifiedPlays = 0;
    for (final e in yearEvents) {
      totalListeningTimeMs += e.listenedDurationMs;
      if (e.isQualifiedPlay) qualifiedPlays++;
    }

    final totalHours = (totalListeningTimeMs / (1000.0 * 60 * 60));

    // Summary calculation for rankings
    final summary = await computeSummary(
      filter: AnalyticsTimeFilter.custom,
      customRange: DateTimeRange(
        start: DateTime(year, 1, 1),
        end: DateTime(year, 12, 31, 23, 59, 59),
      ),
    );

    // Peak Month
    final monthMinutes = List<int>.filled(12, 0);
    for (final e in yearEvents) {
      final month =
          DateTime.fromMillisecondsSinceEpoch(e.startTimeMs).month - 1;
      monthMinutes[month] += e.listenedDurationMs ~/ 60000;
    }
    int maxMonthIdx = 0;
    int maxMonthMin = -1;
    for (int m = 0; m < 12; m++) {
      if (monthMinutes[m] > maxMonthMin) {
        maxMonthMin = monthMinutes[m];
        maxMonthIdx = m;
      }
    }
    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final peakMonth = monthNames[maxMonthIdx];

    // Most Active Day
    final dayMinutes = List<int>.filled(7, 0);
    for (final e in yearEvents) {
      final weekday =
          DateTime.fromMillisecondsSinceEpoch(e.startTimeMs).weekday -
          1; // 0 = Mon
      dayMinutes[weekday] += e.listenedDurationMs ~/ 60000;
    }
    const dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    int maxDayIdx = 0;
    int maxDayMin = -1;
    for (int d = 0; d < 7; d++) {
      if (dayMinutes[d] > maxDayMin) {
        maxDayMin = dayMinutes[d];
        maxDayIdx = d;
      }
    }
    final mostActiveDay = dayNames[maxDayIdx];

    // Milestones
    final milestones = <String>[];
    if (totalHours >= 1.0) {
      milestones.add(
        '${totalHours.toStringAsFixed(1)} hours of pure offline music',
      );
    }
    if (qualifiedPlays >= 10) {
      milestones.add('$qualifiedPlays qualified tracks enjoyed');
    }
    if (summary.uniqueArtistsPlayed >= 5) {
      milestones.add(
        '${summary.uniqueArtistsPlayed} distinct artists explored',
      );
    }
    if (summary.longestStreakDays >= 3) {
      milestones.add(
        '${summary.longestStreakDays}-day consecutive listening streak',
      );
    }
    if (milestones.isEmpty) {
      milestones.add('Beginning your personal offline listening journey');
    }

    return SoniqReplayModel(
      year: year,
      totalListeningHours: totalHours,
      totalQualifiedPlays: qualifiedPlays,
      topSongs: summary.topSongs.take(5).toList(),
      topArtists: summary.topArtists.take(5).toList(),
      topAlbums: summary.topAlbums.take(5).toList(),
      favoriteGenre: summary.topGenres.isNotEmpty
          ? summary.topGenres.first.title
          : 'Eclectic Mix',
      peakMonth: peakMonth,
      mostActiveDay: mostActiveDay,
      longestStreakDays: summary.longestStreakDays,
      topReplayedSong: summary.topSongs.isNotEmpty
          ? summary.topSongs.first
          : null,
      milestones: milestones,
    );
  }

  /// Exports all listening analytics data as formatted JSON
  Future<String> exportAnalyticsJson() async {
    final allEvents = _cacheService.getAllPlaybackEvents();
    final exportData = {
      'exportedAt': DateTime.now().toIso8601String(),
      'app': 'SONIQ Offline Music Player',
      'version': '1.0.0',
      'totalEventCount': allEvents.length,
      'events': allEvents.map((e) => e.toMap()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(exportData);
  }

  /// Detailed individual item analytics
  Future<Map<String, dynamic>> getSongAnalytics(String songId) async {
    final allEvents = _cacheService.getAllPlaybackEvents();
    final songEvents = allEvents.where((e) => e.songId == songId).toList();

    int totalPlays = 0;
    int totalListeningMs = 0;
    int completed = 0;
    int skipped = 0;
    int firstPlayed = 0;
    int lastPlayed = 0;

    for (final e in songEvents) {
      if (e.isQualifiedPlay) totalPlays++;
      totalListeningMs += e.listenedDurationMs;
      if (e.completionPercentage >= 0.90) completed++;
      if (e.isSkipped) skipped++;
      if (firstPlayed == 0 || e.startTimeMs < firstPlayed) {
        firstPlayed = e.startTimeMs;
      }
      if (e.startTimeMs > lastPlayed) {
        lastPlayed = e.startTimeMs;
      }
    }

    return {
      'songId': songId,
      'totalPlays': totalPlays,
      'totalListeningMs': totalListeningMs,
      'completionRate': songEvents.isNotEmpty
          ? completed / songEvents.length
          : 0.0,
      'skipCount': skipped,
      'firstPlayedMs': firstPlayed,
      'lastPlayedMs': lastPlayed,
      'eventCount': songEvents.length,
    };
  }
}
