import 'dart:io';
import '../models/song_model.dart';
import '../models/playlist_model.dart';
import '../models/smart_playlist_model.dart';
import '../models/song_classification_model.dart';
import 'music_classifier_service.dart';

class SmartPlaylistService {
  static final SmartPlaylistService _instance = SmartPlaylistService._internal();
  factory SmartPlaylistService() => _instance;
  SmartPlaylistService._internal();

  /// Evaluates a dynamic smart playlist definition against the current library state
  List<SongModel> evaluateSmartPlaylist({
    required SmartPlaylistModel playlist,
    required List<SongModel> library,
    required Map<String, SongClassificationModel> classifications,
  }) {
    if (library.isEmpty) return [];

    final classifier = MusicClassifierService();
    final libraryMap = {for (final s in library) s.id: s};
    final excludedSet = playlist.excludedSongIds.toSet();
    final pinnedSet = playlist.pinnedSongIds.toSet();

    final List<SongModel> matchedSongs = [];

    for (final song in library) {
      // 1. Skip if user explicitly excluded this song from this smart playlist
      if (excludedSet.contains(song.id)) continue;

      // 2. Pinned songs are guaranteed inclusion (handled in final pass)
      if (pinnedSet.contains(song.id)) continue;

      // 3. Obtain classification (from cache, or compute on the fly instantly)
      final classification = classifications[song.id] ?? classifier.classifySong(song);

      // 4. Evaluate criteria rules
      if (_matchesRules(song, playlist.rules, classification)) {
        matchedSongs.add(song);
      }
    }

    // 4. Pin items at the top of the smart playlist
    final pinnedSongs = <SongModel>[];
    for (final pinId in playlist.pinnedSongIds) {
      if (libraryMap.containsKey(pinId) && !excludedSet.contains(pinId)) {
        pinnedSongs.add(libraryMap[pinId]!);
      }
    }

    final combined = [...pinnedSongs, ...matchedSongs];

    // 5. Apply target playlist size limit (-1 for unlimited)
    if (playlist.targetSize > 0 && combined.length > playlist.targetSize) {
      return combined.take(playlist.targetSize).toList();
    }

    return combined;
  }

  bool _matchesRules(
    SongModel song,
    SmartPlaylistRules rules,
    SongClassificationModel? classification,
  ) {
    // 1. Favorites-only filter
    if (rules.favoritesOnly && !song.isFavorite) {
      return false;
    }

    // 2. Artist inclusion & exclusion
    if (rules.includedArtists.isNotEmpty) {
      final matchesArtist = rules.includedArtists.any(
          (a) => song.artist.toLowerCase().contains(a.toLowerCase()));
      if (!matchesArtist) return false;
    }
    if (rules.excludedArtists.isNotEmpty) {
      final isExcludedArtist = rules.excludedArtists.any(
          (a) => song.artist.toLowerCase().contains(a.toLowerCase()));
      if (isExcludedArtist) return false;
    }

    // 3. Duration limits
    if (rules.minDurationMs != null && song.durationMs < rules.minDurationMs!) {
      return false;
    }
    if (rules.maxDurationMs != null && song.durationMs > rules.maxDurationMs!) {
      return false;
    }

    // 4. Energy Level
    if (rules.energyLevel != null && rules.energyLevel!.isNotEmpty) {
      if (classification != null && classification.energyLevel != rules.energyLevel) {
        return false;
      }
    }

    // 5. Language
    if (rules.language != null && rules.language!.isNotEmpty) {
      if (classification != null && classification.language != rules.language) {
        return false;
      }
    }

    // 6. Mood matching
    if (rules.selectedMoods.isNotEmpty) {
      // If user selected all categories, every track naturally matches
      if (rules.selectedMoods.length >= 15) {
        return true;
      }

      final songMoods = <String>{};
      if (classification != null) {
        songMoods.add(classification.primaryMood.toLowerCase());
        songMoods.addAll(classification.secondaryMoods.map((m) => m.toLowerCase()));
        songMoods.addAll(classification.userTags.map((m) => m.toLowerCase()));
      }
      if (song.isFavorite) {
        songMoods.add('favorites mix');
      }
      if (song.playCount >= 5) {
        songMoods.add('most played');
      }

      final songText = '${song.title} ${song.artist} ${song.album}'.toLowerCase();

      final matchesMood = rules.selectedMoods.any((m) {
        final mLower = m.toLowerCase();
        if (songMoods.contains(mLower)) return true;
        // Direct title/artist lexical match fallback
        if (mLower == 'tamil melody' && (songText.contains('melody') || classification?.language == 'tamil')) return true;
        if (mLower == 'tamil kuthu' && (songText.contains('kuthu') || songText.contains('gana'))) return true;
        if (mLower == 'devotional' && (songText.contains('god') || songText.contains('bhajan') || songText.contains('slokam') || songText.contains('bakthi') || songText.contains('prayer'))) return true;
        if (mLower == 'instrumental' && (songText.contains('bgm') || songText.contains('theme') || songText.contains('instrumental') || songText.contains('score'))) return true;
        if (mLower == 'sad & emotional' && (songText.contains('sad') || songText.contains('pain') || songText.contains('tears') || songText.contains('alone'))) return true;
        if (mLower == 'motivation' && (songText.contains('motivation') || songText.contains('vetri') || songText.contains('power'))) return true;
        if (mLower == 'workout' && (songText.contains('gym') || songText.contains('workout') || songText.contains('fitness'))) return true;
        return false;
      });

      if (!matchesMood) return false;
    }

    // 7. Genre matching
    if (rules.selectedGenres.isNotEmpty) {
      final songAlbum = song.album.toLowerCase();
      final songTitle = song.title.toLowerCase();
      final matchesGenre = rules.selectedGenres.any(
          (g) => songAlbum.contains(g.toLowerCase()) || songTitle.contains(g.toLowerCase()));
      if (!matchesGenre) return false;
    }

    return true;
  }

  /// CRITICAL REQUIREMENT 5: Automatic Playlist Synchronization
  /// Cleanses missing/deleted files from all smart & manual playlists.
  /// Never deletes original music files.
  Future<void> synchronizeWithLibrary({
    required List<SongModel> currentLibrary,
    required List<SmartPlaylistModel> smartPlaylists,
    required List<PlaylistModel> manualPlaylists,
    Future<void> Function(SmartPlaylistModel)? onSmartPlaylistUpdated,
    Future<void> Function(PlaylistModel)? onManualPlaylistUpdated,
    bool checkFileExistence = true,
  }) async {
    // Collect active valid song IDs and verify underlying files actually exist on disk
    final validSongIds = <String>{};
    for (final song in currentLibrary) {
      if (checkFileExistence) {
        if (song.dataPath.isNotEmpty && File(song.dataPath).existsSync()) {
          validSongIds.add(song.id);
        }
      } else {
        validSongIds.add(song.id);
      }
    }

    // 1. Synchronize Smart Playlists (cleanse pinned & excluded lists)
    for (final pl in smartPlaylists) {
      bool changed = false;

      final newPinned = pl.pinnedSongIds.where((id) => validSongIds.contains(id)).toList();
      if (newPinned.length != pl.pinnedSongIds.length) {
        pl.pinnedSongIds = newPinned;
        changed = true;
      }

      final newExcluded = pl.excludedSongIds.where((id) => validSongIds.contains(id)).toList();
      if (newExcluded.length != pl.excludedSongIds.length) {
        pl.excludedSongIds = newExcluded;
        changed = true;
      }

      if (changed) {
        pl.updatedAt = DateTime.now().millisecondsSinceEpoch;
        if (onSmartPlaylistUpdated != null) {
          await onSmartPlaylistUpdated(pl);
        }
      }
    }

    // 2. Synchronize Manual Playlists (remove deleted song references)
    for (final pl in manualPlaylists) {
      final initialCount = pl.songIds.length;
      final newSongIds = pl.songIds.where((id) => validSongIds.contains(id)).toList();

      if (newSongIds.length != initialCount) {
        pl.songIds = newSongIds;
        if (onManualPlaylistUpdated != null) {
          await onManualPlaylistUpdated(pl);
        }
      }
    }
  }

  /// Default Pre-built Smart Playlists for Instant Discovery
  List<SmartPlaylistModel> createBuiltinSmartPlaylists() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return [
      SmartPlaylistModel(
        id: 'smart_love_romance',
        name: 'Love & Romance',
        description: 'Soulful melodies, romantic ballads and heartfelt love songs',
        category: 'Love & Romance',
        iconCodePoint: 0xe25b, // favorite
        colorHex: 0xFFE11D48, // Rose Red
        targetSize: 30,
        rules: SmartPlaylistRules(selectedMoods: ['Love & Romance']),
        createdAt: now,
      ),
      SmartPlaylistModel(
        id: 'smart_tamil_melody',
        name: 'Tamil Melody & Classics',
        description: 'Evergreen acoustic melodies and Tamil film soundtrack gems',
        category: 'Tamil Melody',
        iconCodePoint: 0xe3e3, // music_note
        colorHex: 0xFFD97706, // Amber Gold
        targetSize: 30,
        rules: SmartPlaylistRules(selectedMoods: ['Tamil Melody', 'Love & Romance'], language: 'tamil'),
        createdAt: now + 1,
      ),
      SmartPlaylistModel(
        id: 'smart_fast_kuthu',
        name: 'Fast Beat & Tamil Kuthu',
        description: 'High-energy dance beats, local kuthu and party bangers',
        category: 'Fast Beat',
        iconCodePoint: 0xe067, // bolt
        colorHex: 0xFF9333EA, // Purple
        targetSize: 25,
        rules: SmartPlaylistRules(selectedMoods: ['Fast Beat', 'Tamil Kuthu'], energyLevel: 'high'),
        createdAt: now + 2,
      ),
      SmartPlaylistModel(
        id: 'smart_chill_relax',
        name: 'Chill & Relax',
        description: 'Late night acoustic vibes, peaceful breezes and calm flows',
        category: 'Chill & Relax',
        iconCodePoint: 0xf552, // bedtime / moon
        colorHex: 0xFF0284C7, // Sky Blue
        targetSize: 30,
        rules: SmartPlaylistRules(selectedMoods: ['Chill & Relax', 'Sleep', 'Focus'], energyLevel: 'low'),
        createdAt: now + 3,
      ),
      SmartPlaylistModel(
        id: 'smart_workout_power',
        name: 'Workout & Motivation',
        description: 'Driving rhythms and high-intensity motivational pump',
        category: 'Workout',
        iconCodePoint: 0xe260, // fitness_center
        colorHex: 0xFFEA580C, // Flame Orange
        targetSize: 25,
        rules: SmartPlaylistRules(selectedMoods: ['Workout', 'Motivation', 'Fast Beat']),
        createdAt: now + 4,
      ),
      SmartPlaylistModel(
        id: 'smart_road_trip',
        name: 'Road Trip Anthems',
        description: 'Dynamic journey soundtracks for highway cruising',
        category: 'Road Trip',
        iconCodePoint: 0xe1d7, // directions_car
        colorHex: 0xFF10B981, // Emerald Green
        targetSize: 35,
        rules: SmartPlaylistRules(selectedMoods: ['Road Trip', 'Fast Beat', 'Melody']),
        createdAt: now + 5,
      ),
    ];
  }

  /// Converts evaluated songs from a Smart Playlist into a static regular Manual Playlist
  PlaylistModel createManualSnapshot({
    required SmartPlaylistModel source,
    required List<SongModel> evaluatedSongs,
    required String snapshotName,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return PlaylistModel(
      id: 'snapshot_${source.id}_$now',
      name: snapshotName,
      description: 'Static snapshot of "${source.name}" (${evaluatedSongs.length} tracks)',
      songIds: evaluatedSongs.map((s) => s.id).toList(),
      createdAt: now,
    );
  }
}
