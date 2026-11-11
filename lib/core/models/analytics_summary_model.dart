import 'package:flutter/material.dart';

enum AnalyticsTimeFilter {
  today,
  last7Days,
  last30Days,
  thisMonth,
  lastMonth,
  last90Days,
  thisYear,
  allTime,
  custom;

  String get label {
    switch (this) {
      case AnalyticsTimeFilter.today:
        return 'Daily';
      case AnalyticsTimeFilter.last7Days:
        return 'Weekly';
      case AnalyticsTimeFilter.last30Days:
        return '30 Days';
      case AnalyticsTimeFilter.thisMonth:
        return 'Monthly';
      case AnalyticsTimeFilter.lastMonth:
        return 'Last Month';
      case AnalyticsTimeFilter.last90Days:
        return '90 Days';
      case AnalyticsTimeFilter.thisYear:
        return 'Yearly';
      case AnalyticsTimeFilter.allTime:
        return 'All Time';
      case AnalyticsTimeFilter.custom:
        return 'Custom';
    }
  }

  DateTimeRange? getRange([DateTimeRange? customRange]) {
    final now = DateTime.now();
    switch (this) {
      case AnalyticsTimeFilter.today:
        final start = DateTime(now.year, now.month, now.day);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        return DateTimeRange(start: start, end: end);
      case AnalyticsTimeFilter.last7Days:
        final start = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 6));
        return DateTimeRange(start: start, end: now);
      case AnalyticsTimeFilter.last30Days:
        final start = now.subtract(const Duration(days: 30));
        return DateTimeRange(start: start, end: now);
      case AnalyticsTimeFilter.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        return DateTimeRange(start: start, end: now);
      case AnalyticsTimeFilter.lastMonth:
        final startOfLastMonth = DateTime(now.year, now.month - 1, 1);
        final endOfLastMonth = DateTime(now.year, now.month, 0, 23, 59, 59);
        return DateTimeRange(start: startOfLastMonth, end: endOfLastMonth);
      case AnalyticsTimeFilter.last90Days:
        final start = now.subtract(const Duration(days: 90));
        return DateTimeRange(start: start, end: now);
      case AnalyticsTimeFilter.thisYear:
        final start = DateTime(now.year, 1, 1);
        return DateTimeRange(start: start, end: now);
      case AnalyticsTimeFilter.allTime:
        return null;
      case AnalyticsTimeFilter.custom:
        return customRange;
    }
  }
}

class TopItemMetric {
  final String id;
  final String title;
  final String subtitle;
  final int playCount;
  final int totalListeningMs;
  final double completionRate;
  final double skipRate;
  final String? extraInfo;
  final double percentage; // Proportion of total period time

  const TopItemMetric({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.playCount,
    required this.totalListeningMs,
    this.completionRate = 1.0,
    this.skipRate = 0.0,
    this.extraInfo,
    this.percentage = 0.0,
  });

  String get formattedDuration {
    final minutes = totalListeningMs ~/ 60000;
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final remainingMin = minutes % 60;
    return '${hours}h ${remainingMin}m';
  }
}

class DailyListeningMetric {
  final DateTime date;
  final int listeningMinutes;
  final int qualifiedPlays;

  const DailyListeningMetric({
    required this.date,
    required this.listeningMinutes,
    required this.qualifiedPlays,
  });
}

class HourlyListeningMetric {
  final int hour; // 0 - 23
  final int listeningMinutes;
  final int playCount;

  const HourlyListeningMetric({
    required this.hour,
    required this.listeningMinutes,
    required this.playCount,
  });
}

class AnalyticsSummaryModel {
  final AnalyticsTimeFilter filter;
  final DateTimeRange? dateRange;
  final int totalListeningTimeMs;
  final int totalEvents;
  final int qualifiedPlays;
  final int completedPlays;
  final int skippedPlays;
  final double completionRate;
  final double skipRate;
  final int uniqueTracksPlayed;
  final int uniqueArtistsPlayed;
  final int uniqueAlbumsPlayed;
  final int averageDailyListeningMs;
  final int averageSessionDurationMs;
  final int currentStreakDays;
  final int longestStreakDays;
  final int peakListeningHour; // 0 - 23
  final TopItemMetric? mostPlayedSong;
  final TopItemMetric? mostPlayedArtist;
  final TopItemMetric? mostPlayedAlbum;
  final List<TopItemMetric> topSongs;
  final List<TopItemMetric> topArtists;
  final List<TopItemMetric> topAlbums;
  final List<TopItemMetric> topGenres;
  final List<DailyListeningMetric> dailyMetrics;
  final List<HourlyListeningMetric> hourlyMetrics;
  final Map<String, int> weekdayVsWeekend; // 'weekday': ms, 'weekend': ms
  final Map<String, int> dayParts; // 'morning', 'afternoon', 'evening', 'night'

  const AnalyticsSummaryModel({
    required this.filter,
    this.dateRange,
    required this.totalListeningTimeMs,
    required this.totalEvents,
    required this.qualifiedPlays,
    required this.completedPlays,
    required this.skippedPlays,
    required this.completionRate,
    required this.skipRate,
    required this.uniqueTracksPlayed,
    required this.uniqueArtistsPlayed,
    required this.uniqueAlbumsPlayed,
    required this.averageDailyListeningMs,
    required this.averageSessionDurationMs,
    required this.currentStreakDays,
    required this.longestStreakDays,
    required this.peakListeningHour,
    this.mostPlayedSong,
    this.mostPlayedArtist,
    this.mostPlayedAlbum,
    required this.topSongs,
    required this.topArtists,
    required this.topAlbums,
    required this.topGenres,
    required this.dailyMetrics,
    required this.hourlyMetrics,
    required this.weekdayVsWeekend,
    required this.dayParts,
  });

  String get formattedTotalTime {
    final minutes = totalListeningTimeMs ~/ 60000;
    if (minutes < 60) {
      return '$minutes mins';
    }
    final hours = (minutes / 60.0).toStringAsFixed(1);
    return '$hours hrs';
  }

  String get formattedAverageDailyTime {
    final minutes = averageDailyListeningMs ~/ 60000;
    if (minutes < 60) {
      return '$minutes mins';
    }
    final hours = (minutes / 60.0).toStringAsFixed(1);
    return '$hours hrs';
  }

  String get peakHourLabel {
    final h = peakListeningHour;
    final period = h >= 12 ? 'PM' : 'AM';
    final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$displayH:00 $period';
  }
}
