import 'dart:convert';

/// Represents a single recorded playback event in SONIQ's offline listening analytics.
class PlaybackEventModel {
  final String id;
  final String songId;
  final String songTitle;
  final String artistId;
  final String artistName;
  final String albumId;
  final String albumName;
  final String genre;
  final int trackDurationMs;
  final int startTimeMs;
  final int endTimeMs;
  final int listenedDurationMs;
  final double completionPercentage;
  final bool isQualifiedPlay;
  final bool isSkipped;
  final int? skipPositionMs;
  final String playbackSource;
  final String? playlistId;
  final String sessionId;
  final String outputProfile;

  const PlaybackEventModel({
    required this.id,
    required this.songId,
    required this.songTitle,
    required this.artistId,
    required this.artistName,
    required this.albumId,
    required this.albumName,
    this.genre = 'Unknown',
    required this.trackDurationMs,
    required this.startTimeMs,
    required this.endTimeMs,
    required this.listenedDurationMs,
    required this.completionPercentage,
    required this.isQualifiedPlay,
    required this.isSkipped,
    this.skipPositionMs,
    required this.playbackSource,
    this.playlistId,
    required this.sessionId,
    this.outputProfile = 'speaker',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'songId': songId,
      'songTitle': songTitle,
      'artistId': artistId,
      'artistName': artistName,
      'albumId': albumId,
      'albumName': albumName,
      'genre': genre,
      'trackDurationMs': trackDurationMs,
      'startTimeMs': startTimeMs,
      'endTimeMs': endTimeMs,
      'listenedDurationMs': listenedDurationMs,
      'completionPercentage': completionPercentage,
      'isQualifiedPlay': isQualifiedPlay,
      'isSkipped': isSkipped,
      'skipPositionMs': skipPositionMs,
      'playbackSource': playbackSource,
      'playlistId': playlistId,
      'sessionId': sessionId,
      'outputProfile': outputProfile,
    };
  }

  factory PlaybackEventModel.fromMap(Map<String, dynamic> map) {
    return PlaybackEventModel(
      id: map['id']?.toString() ?? '',
      songId: map['songId']?.toString() ?? '',
      songTitle: map['songTitle']?.toString() ?? 'Unknown Title',
      artistId: map['artistId']?.toString() ?? '',
      artistName: map['artistName']?.toString() ?? 'Unknown Artist',
      albumId: map['albumId']?.toString() ?? '',
      albumName: map['albumName']?.toString() ?? 'Unknown Album',
      genre: map['genre']?.toString() ?? 'Unknown',
      trackDurationMs: (map['trackDurationMs'] as num?)?.toInt() ?? 0,
      startTimeMs: (map['startTimeMs'] as num?)?.toInt() ?? 0,
      endTimeMs: (map['endTimeMs'] as num?)?.toInt() ?? 0,
      listenedDurationMs: (map['listenedDurationMs'] as num?)?.toInt() ?? 0,
      completionPercentage: (map['completionPercentage'] as num?)?.toDouble() ?? 0.0,
      isQualifiedPlay: map['isQualifiedPlay'] as bool? ?? false,
      isSkipped: map['isSkipped'] as bool? ?? false,
      skipPositionMs: (map['skipPositionMs'] as num?)?.toInt(),
      playbackSource: map['playbackSource']?.toString() ?? 'all_songs',
      playlistId: map['playlistId']?.toString(),
      sessionId: map['sessionId']?.toString() ?? '',
      outputProfile: map['outputProfile']?.toString() ?? 'speaker',
    );
  }

  String toJson() => json.encode(toMap());

  factory PlaybackEventModel.fromJson(String source) =>
      PlaybackEventModel.fromMap(json.decode(source) as Map<String, dynamic>);
}
