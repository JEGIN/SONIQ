import 'dart:convert';

enum RingtoneTarget { phone, notification, alarm }

class RingtoneModel {
  final String id;
  final String title;
  final String originalSongTitle;
  final String filePath;
  final int durationMs;
  final int startMs;
  final int endMs;
  final int createdAt;
  final RingtoneTarget target;

  RingtoneModel({
    required this.id,
    required this.title,
    required this.originalSongTitle,
    required this.filePath,
    required this.durationMs,
    required this.startMs,
    required this.endMs,
    required this.createdAt,
    this.target = RingtoneTarget.phone,
  });

  String get formattedDuration {
    final duration = Duration(milliseconds: durationMs);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    final ms = ((durationMs % 1000) / 10).floor();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${ms.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'originalSongTitle': originalSongTitle,
      'filePath': filePath,
      'durationMs': durationMs,
      'startMs': startMs,
      'endMs': endMs,
      'createdAt': createdAt,
      'target': target.name,
    };
  }

  factory RingtoneModel.fromMap(Map<dynamic, dynamic> map) {
    return RingtoneModel(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Custom Ringtone',
      originalSongTitle: map['originalSongTitle']?.toString() ?? 'Original Song',
      filePath: map['filePath']?.toString() ?? '',
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
      startMs: (map['startMs'] as num?)?.toInt() ?? 0,
      endMs: (map['endMs'] as num?)?.toInt() ?? 0,
      createdAt: (map['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      target: RingtoneTarget.values.firstWhere(
        (e) => e.name == map['target'],
        orElse: () => RingtoneTarget.phone,
      ),
    );
  }

  String toJson() => json.encode(toMap());

  factory RingtoneModel.fromJson(String source) => RingtoneModel.fromMap(json.decode(source));
}
