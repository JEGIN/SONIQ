import 'dart:convert';

class AudioFeaturesModel {
  final int? bpm;
  final double energy; // 0.0 - 1.0
  final double loudnessRms; // 0.0 - 1.0
  final double durationSeconds;

  AudioFeaturesModel({
    this.bpm,
    this.energy = 0.5,
    this.loudnessRms = 0.5,
    required this.durationSeconds,
  });

  Map<String, dynamic> toMap() {
    return {
      'bpm': bpm,
      'energy': energy,
      'loudnessRms': loudnessRms,
      'durationSeconds': durationSeconds,
    };
  }

  factory AudioFeaturesModel.fromMap(Map<dynamic, dynamic> map) {
    return AudioFeaturesModel(
      bpm: (map['bpm'] as num?)?.toInt(),
      energy: (map['energy'] as num?)?.toDouble() ?? 0.5,
      loudnessRms: (map['loudnessRms'] as num?)?.toDouble() ?? 0.5,
      durationSeconds: (map['durationSeconds'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class SongClassificationModel {
  final String songId;
  String primaryMood;
  List<String> secondaryMoods;
  String energyLevel; // 'low', 'medium', 'high'
  String language; // 'tamil', 'english', 'hindi', 'other'
  double confidenceScore; // 0.0 to 1.0
  bool isUserCorrected;
  List<String> userTags;
  AudioFeaturesModel audioFeatures;
  final int analyzedTimestamp;

  List<String> get allMoods => [primaryMood, ...secondaryMoods];
  List<String> get detectedMoods => allMoods;
  double get confidence => confidenceScore;

  SongClassificationModel({
    required this.songId,
    required this.primaryMood,
    List<String>? secondaryMoods,
    this.energyLevel = 'medium',
    this.language = 'other',
    this.confidenceScore = 0.5,
    this.isUserCorrected = false,
    List<String>? userTags,
    required this.audioFeatures,
    required this.analyzedTimestamp,
  })  : secondaryMoods = secondaryMoods ?? [],
        userTags = userTags ?? [];

  Map<String, dynamic> toMap() {
    return {
      'songId': songId,
      'primaryMood': primaryMood,
      'secondaryMoods': secondaryMoods,
      'energyLevel': energyLevel,
      'language': language,
      'confidenceScore': confidenceScore,
      'isUserCorrected': isUserCorrected,
      'userTags': userTags,
      'audioFeatures': audioFeatures.toMap(),
      'analyzedTimestamp': analyzedTimestamp,
    };
  }

  factory SongClassificationModel.fromMap(Map<dynamic, dynamic> map) {
    return SongClassificationModel(
      songId: map['songId']?.toString() ?? '',
      primaryMood: map['primaryMood']?.toString() ?? 'Unclassified',
      secondaryMoods: map['secondaryMoods'] != null ? List<String>.from(map['secondaryMoods'] as List) : [],
      energyLevel: map['energyLevel']?.toString() ?? 'medium',
      language: map['language']?.toString() ?? 'other',
      confidenceScore: (map['confidenceScore'] as num?)?.toDouble() ?? 0.5,
      isUserCorrected: map['isUserCorrected'] == true,
      userTags: map['userTags'] != null ? List<String>.from(map['userTags'] as List) : [],
      audioFeatures: map['audioFeatures'] != null
          ? AudioFeaturesModel.fromMap(map['audioFeatures'] as Map)
          : AudioFeaturesModel(durationSeconds: 0.0),
      analyzedTimestamp: (map['analyzedTimestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  String toJson() => json.encode(toMap());

  factory SongClassificationModel.fromJson(String source) => SongClassificationModel.fromMap(json.decode(source));
}
