import 'dart:convert';

class SmartPlaylistRules {
  List<String> selectedMoods;
  List<String> selectedGenres;
  String? energyLevel; // 'low', 'medium', 'high', null (any)
  String? language; // 'tamil', 'english', 'hindi', null (any)
  bool favoritesOnly;
  List<String> includedArtists;
  List<String> excludedArtists;
  int? minDurationMs;
  int? maxDurationMs;

  SmartPlaylistRules({
    List<String>? selectedMoods,
    List<String>? selectedGenres,
    this.energyLevel,
    this.language,
    this.favoritesOnly = false,
    List<String>? includedArtists,
    List<String>? excludedArtists,
    this.minDurationMs,
    this.maxDurationMs,
  })  : selectedMoods = selectedMoods ?? [],
        selectedGenres = selectedGenres ?? [],
        includedArtists = includedArtists ?? [],
        excludedArtists = excludedArtists ?? [];

  Map<String, dynamic> toMap() {
    return {
      'selectedMoods': selectedMoods,
      'selectedGenres': selectedGenres,
      'energyLevel': energyLevel,
      'language': language,
      'favoritesOnly': favoritesOnly,
      'includedArtists': includedArtists,
      'excludedArtists': excludedArtists,
      'minDurationMs': minDurationMs,
      'maxDurationMs': maxDurationMs,
    };
  }

  factory SmartPlaylistRules.fromMap(Map<dynamic, dynamic> map) {
    return SmartPlaylistRules(
      selectedMoods: map['selectedMoods'] != null ? List<String>.from(map['selectedMoods'] as List) : [],
      selectedGenres: map['selectedGenres'] != null ? List<String>.from(map['selectedGenres'] as List) : [],
      energyLevel: map['energyLevel']?.toString(),
      language: map['language']?.toString(),
      favoritesOnly: map['favoritesOnly'] == true,
      includedArtists: map['includedArtists'] != null ? List<String>.from(map['includedArtists'] as List) : [],
      excludedArtists: map['excludedArtists'] != null ? List<String>.from(map['excludedArtists'] as List) : [],
      minDurationMs: (map['minDurationMs'] as num?)?.toInt(),
      maxDurationMs: (map['maxDurationMs'] as num?)?.toInt(),
    );
  }
}

class SmartPlaylistModel {
  final String id;
  String name;
  String description;
  String category;
  int iconCodePoint;
  int colorHex;
  int targetSize; // -1 for unlimited, or e.g. 10, 20, 30, 50
  SmartPlaylistRules rules;
  List<String> excludedSongIds;
  List<String> pinnedSongIds;
  final int createdAt;
  int updatedAt;
  bool isSnapshot;

  SmartPlaylistModel({
    required this.id,
    required this.name,
    this.description = '',
    required this.category,
    this.iconCodePoint = 0xe87d, // Icons.auto_awesome
    this.colorHex = 0xFF8B5CF6,
    this.targetSize = 30,
    required this.rules,
    List<String>? excludedSongIds,
    List<String>? pinnedSongIds,
    int? createdAt,
    int? updatedAt,
    this.isSnapshot = false,
  })  : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
        excludedSongIds = excludedSongIds ?? [],
        pinnedSongIds = pinnedSongIds ?? [],
        updatedAt = updatedAt ?? (createdAt ?? DateTime.now().millisecondsSinceEpoch);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'iconCodePoint': iconCodePoint,
      'colorHex': colorHex,
      'targetSize': targetSize,
      'rules': rules.toMap(),
      'excludedSongIds': excludedSongIds,
      'pinnedSongIds': pinnedSongIds,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isSnapshot': isSnapshot,
    };
  }

  factory SmartPlaylistModel.fromMap(Map<dynamic, dynamic> map) {
    return SmartPlaylistModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Smart Playlist',
      description: map['description']?.toString() ?? '',
      category: map['category']?.toString() ?? 'General',
      iconCodePoint: (map['iconCodePoint'] as num?)?.toInt() ?? 0xe87d,
      colorHex: (map['colorHex'] as num?)?.toInt() ?? 0xFF8B5CF6,
      targetSize: (map['targetSize'] as num?)?.toInt() ?? 30,
      rules: map['rules'] != null
          ? SmartPlaylistRules.fromMap(map['rules'] as Map)
          : SmartPlaylistRules(),
      excludedSongIds: map['excludedSongIds'] != null ? List<String>.from(map['excludedSongIds'] as List) : [],
      pinnedSongIds: map['pinnedSongIds'] != null ? List<String>.from(map['pinnedSongIds'] as List) : [],
      createdAt: (map['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      updatedAt: (map['updatedAt'] as num?)?.toInt(),
      isSnapshot: map['isSnapshot'] == true,
    );
  }

  String toJson() => json.encode(toMap());

  factory SmartPlaylistModel.fromJson(String source) => SmartPlaylistModel.fromMap(json.decode(source));
}
