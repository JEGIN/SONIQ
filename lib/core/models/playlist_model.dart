import 'dart:convert';

class PlaylistModel {
  final String id;
  String name;
  String description;
  final int createdAt;
  List<String> songIds;
  String? coverSongId;

  PlaylistModel({
    required this.id,
    required this.name,
    this.description = '',
    required this.createdAt,
    List<String>? songIds,
    this.coverSongId,
  }) : songIds = songIds ?? [];

  int get songCount => songIds.length;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'createdAt': createdAt,
      'songIds': songIds,
      'coverSongId': coverSongId,
    };
  }

  factory PlaylistModel.fromMap(Map<dynamic, dynamic> map) {
    return PlaylistModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Untitled Playlist',
      description: map['description']?.toString() ?? '',
      createdAt: (map['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      songIds: map['songIds'] != null ? List<String>.from(map['songIds'] as List) : [],
      coverSongId: map['coverSongId']?.toString(),
    );
  }

  String toJson() => json.encode(toMap());

  factory PlaylistModel.fromJson(String source) => PlaylistModel.fromMap(json.decode(source));
}
