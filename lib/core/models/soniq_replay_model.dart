import 'analytics_summary_model.dart';

class SoniqReplayModel {
  final int year;
  final double totalListeningHours;
  final int totalQualifiedPlays;
  final List<TopItemMetric> topSongs;
  final List<TopItemMetric> topArtists;
  final List<TopItemMetric> topAlbums;
  final String favoriteGenre;
  final String peakMonth;
  final String mostActiveDay;
  final int longestStreakDays;
  final TopItemMetric? topReplayedSong;
  final List<String> milestones;

  const SoniqReplayModel({
    required this.year,
    required this.totalListeningHours,
    required this.totalQualifiedPlays,
    required this.topSongs,
    required this.topArtists,
    required this.topAlbums,
    required this.favoriteGenre,
    required this.peakMonth,
    required this.mostActiveDay,
    required this.longestStreakDays,
    this.topReplayedSong,
    required this.milestones,
  });

  bool get hasSufficientData => totalQualifiedPlays >= 5 || totalListeningHours >= 0.1;
}
