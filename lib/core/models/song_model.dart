import 'dart:convert';

class SongModel {
  final String id;
  final String title;
  final String artist;
  final String album;
  final int durationMs;
  final String dataPath;
  final String? albumArtUri;
  final int dateAdded;
  final int sizeBytes;
  final String fileExtension;
  bool isFavorite;
  int playCount;
  int lastPlayedTimestamp;
  List<double>? waveformPeaks;

  SongModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMs,
    required this.dataPath,
    this.albumArtUri,
    required this.dateAdded,
    required this.sizeBytes,
    required this.fileExtension,
    this.isFavorite = false,
    this.playCount = 0,
    this.lastPlayedTimestamp = 0,
    this.waveformPeaks,
  });

  String get formattedDuration {
    final duration = Duration(milliseconds: durationMs);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedSize {
    final mb = sizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'durationMs': durationMs,
      'dataPath': dataPath,
      'albumArtUri': albumArtUri,
      'dateAdded': dateAdded,
      'sizeBytes': sizeBytes,
      'fileExtension': fileExtension,
      'isFavorite': isFavorite,
      'playCount': playCount,
      'lastPlayedTimestamp': lastPlayedTimestamp,
      'waveformPeaks': waveformPeaks,
    };
  }

  factory SongModel.fromMap(Map<dynamic, dynamic> map) {
    return SongModel(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString().isNotEmpty == true ? map['title'].toString() : 'Unknown Track',
      artist: map['artist']?.toString().isNotEmpty == true ? map['artist'].toString() : 'Unknown Artist',
      album: map['album']?.toString().isNotEmpty == true ? map['album'].toString() : 'Unknown Album',
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
      dataPath: map['dataPath']?.toString() ?? '',
      albumArtUri: map['albumArtUri']?.toString(),
      dateAdded: (map['dateAdded'] as num?)?.toInt() ?? 0,
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
      fileExtension: map['fileExtension']?.toString() ?? 'mp3',
      isFavorite: map['isFavorite'] == true,
      playCount: (map['playCount'] as num?)?.toInt() ?? 0,
      lastPlayedTimestamp: (map['lastPlayedTimestamp'] as num?)?.toInt() ?? 0,
      waveformPeaks: map['waveformPeaks'] != null
          ? List<double>.from((map['waveformPeaks'] as List).map((e) => (e as num).toDouble()))
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory SongModel.fromJson(String source) => SongModel.fromMap(json.decode(source));

  SongModel copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    int? durationMs,
    String? dataPath,
    String? albumArtUri,
    int? dateAdded,
    int? sizeBytes,
    String? fileExtension,
    bool? isFavorite,
    int? playCount,
    int? lastPlayedTimestamp,
    List<double>? waveformPeaks,
  }) {
    return SongModel(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      durationMs: durationMs ?? this.durationMs,
      dataPath: dataPath ?? this.dataPath,
      albumArtUri: albumArtUri ?? this.albumArtUri,
      dateAdded: dateAdded ?? this.dateAdded,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      fileExtension: fileExtension ?? this.fileExtension,
      isFavorite: isFavorite ?? this.isFavorite,
      playCount: playCount ?? this.playCount,
      lastPlayedTimestamp: lastPlayedTimestamp ?? this.lastPlayedTimestamp,
      waveformPeaks: waveformPeaks ?? this.waveformPeaks,
    );
  }
}
