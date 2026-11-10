import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../models/song_model.dart';
import '../models/playlist_model.dart';
import '../models/ringtone_model.dart';
import '../models/smart_playlist_model.dart';
import '../models/song_classification_model.dart';
import 'hive_boxes.dart';

class SongCacheService {
  static final SongCacheService _instance = SongCacheService._internal();
  factory SongCacheService() => _instance;
  SongCacheService._internal();

  late Box<String> _songsBox;
  late Box<String> _playlistsBox;
  late Box<String> _historyBox;
  late Box<dynamic> _settingsBox;
  late Box<String> _ringtonesBox;
  late Box<String> _smartPlaylistsBox;
  late Box<String> _classificationsBox;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;

    await Hive.initFlutter();
    _songsBox = await Hive.openBox<String>(HiveBoxes.songs);
    _playlistsBox = await Hive.openBox<String>(HiveBoxes.playlists);
    _historyBox = await Hive.openBox<String>(HiveBoxes.history);
    _settingsBox = await Hive.openBox<dynamic>(HiveBoxes.settings);
    _ringtonesBox = await Hive.openBox<String>(HiveBoxes.ringtones);
    _smartPlaylistsBox = await Hive.openBox<String>(HiveBoxes.smartPlaylists);
    _classificationsBox = await Hive.openBox<String>(HiveBoxes.classifications);

    _initialized = true;
    debugPrint('SONIQ: Hive Database initialized successfully.');
  }

  // --- SONGS CACHE ---
  List<SongModel> getCachedSongs() {
    if (!_initialized) return [];
    return _songsBox.values
        .map((jsonStr) => SongModel.fromJson(jsonStr))
        .toList();
  }

  Future<void> saveSongs(List<SongModel> songs) async {
    if (!_initialized) return;
    final Map<String, String> entries = {};
    for (final song in songs) {
      entries[song.id] = song.toJson();
    }
    await _songsBox.putAll(entries);
  }

  Future<void> updateSong(SongModel song) async {
    if (!_initialized) return;
    await _songsBox.put(song.id, song.toJson());
  }

  /// Returns list of all persisted favorite song IDs
  List<String> getFavoriteSongIds() {
    if (!_initialized) return [];
    final saved = _settingsBox.get('favorite_song_ids');
    if (saved is List && saved.isNotEmpty) {
      return List<String>.from(saved.map((e) => e.toString()));
    }

    // Auto-migration: extract favorite songs from _songsBox if settings entry is not yet created
    final favIds = <String>[];
    for (final jsonStr in _songsBox.values) {
      try {
        final song = SongModel.fromJson(jsonStr);
        if (song.isFavorite) {
          favIds.add(song.id);
        }
      } catch (_) {}
    }
    if (favIds.isNotEmpty) {
      _settingsBox.put('favorite_song_ids', favIds);
    }
    return favIds;
  }

  /// Sets favorite state for song ID, updating both the SongModel and the dedicated index
  Future<bool> setFavorite(String songId, bool isFavorite) async {
    if (!_initialized) return false;
    final jsonStr = _songsBox.get(songId);
    if (jsonStr != null) {
      try {
        final song = SongModel.fromJson(jsonStr);
        song.isFavorite = isFavorite;
        await _songsBox.put(songId, song.toJson());
      } catch (e) {
        debugPrint('SONIQ: Error updating song model favorite: $e');
      }
    }

    final currentFavs = getFavoriteSongIds().toSet();
    if (isFavorite) {
      currentFavs.add(songId);
    } else {
      currentFavs.remove(songId);
    }
    await _settingsBox.put('favorite_song_ids', currentFavs.toList());
    return isFavorite;
  }

  Future<bool> toggleFavorite(String songId) async {
    if (!_initialized) return false;
    final favIds = getFavoriteSongIds().toSet();
    final newStatus = !favIds.contains(songId);
    await setFavorite(songId, newStatus);
    return newStatus;
  }

  Future<void> recordSongPlayed(String songId) async {
    if (!_initialized) return;
    final jsonStr = _songsBox.get(songId);
    if (jsonStr != null) {
      final song = SongModel.fromJson(jsonStr);
      song.playCount += 1;
      song.lastPlayedTimestamp = DateTime.now().millisecondsSinceEpoch;
      await _songsBox.put(songId, song.toJson());

      // Also append to history box (keep most recent 100)
      await _historyBox.put(
        '${DateTime.now().millisecondsSinceEpoch}_$songId',
        song.id,
      );
    }
  }

  List<String> getRecentlyPlayedSongIds({int limit = 50}) {
    if (!_initialized) return [];
    final keys = _historyBox.keys.cast<String>().toList().reversed.toList();
    final uniqueIds = <String>{};
    for (final key in keys) {
      final songId = _historyBox.get(key);
      if (songId != null) {
        uniqueIds.add(songId);
        if (uniqueIds.length >= limit) break;
      }
    }
    return uniqueIds.toList();
  }

  // --- PLAYLISTS ---
  List<PlaylistModel> getPlaylists() {
    if (!_initialized) return [];
    return _playlistsBox.values
        .map((jsonStr) => PlaylistModel.fromJson(jsonStr))
        .toList();
  }

  Future<void> savePlaylist(PlaylistModel playlist) async {
    if (!_initialized) return;
    await _playlistsBox.put(playlist.id, playlist.toJson());
  }

  Future<void> deletePlaylist(String playlistId) async {
    if (!_initialized) return;
    await _playlistsBox.delete(playlistId);
  }

  // --- SMART PLAYLISTS ---
  List<SmartPlaylistModel> getSmartPlaylists() {
    if (!_initialized) return [];
    return _smartPlaylistsBox.values
        .map((jsonStr) => SmartPlaylistModel.fromJson(jsonStr))
        .toList();
  }

  Future<void> saveSmartPlaylist(SmartPlaylistModel playlist) async {
    if (!_initialized) return;
    await _smartPlaylistsBox.put(playlist.id, playlist.toJson());
  }

  Future<void> deleteSmartPlaylist(String playlistId) async {
    if (!_initialized) return;
    await _smartPlaylistsBox.delete(playlistId);
  }

  // --- CLASSIFICATIONS ---
  Map<String, SongClassificationModel> getClassifications() {
    if (!_initialized) return {};
    final map = <String, SongClassificationModel>{};
    for (final jsonStr in _classificationsBox.values) {
      try {
        final item = SongClassificationModel.fromJson(jsonStr);
        map[item.songId] = item;
      } catch (_) {}
    }
    return map;
  }

  Future<void> saveClassification(SongClassificationModel classification) async {
    if (!_initialized) return;
    await _classificationsBox.put(classification.songId, classification.toJson());
  }

  Future<void> saveAllClassifications(Map<String, SongClassificationModel> items) async {
    if (!_initialized) return;
    final entries = <String, String>{};
    for (final e in items.entries) {
      entries[e.key] = e.value.toJson();
    }
    await _classificationsBox.putAll(entries);
  }

  // --- RINGTONES ---
  List<RingtoneModel> getRingtones() {
    if (!_initialized) return [];
    return _ringtonesBox.values
        .map((jsonStr) => RingtoneModel.fromJson(jsonStr))
        .toList();
  }

  Future<void> saveRingtone(RingtoneModel ringtone) async {
    if (!_initialized) return;
    await _ringtonesBox.put(ringtone.id, ringtone.toJson());
  }

  Future<void> deleteRingtone(String ringtoneId) async {
    if (!_initialized) return;
    await _ringtonesBox.delete(ringtoneId);
  }

  // --- SETTINGS ---
  dynamic getSetting(String key, {dynamic defaultValue}) {
    if (!_initialized) return defaultValue;
    return _settingsBox.get(key, defaultValue: defaultValue);
  }

  Future<void> setSetting(String key, dynamic value) async {
    if (!_initialized) return;
    await _settingsBox.put(key, value);
  }

  // --- STORAGE STATS & CACHE CLEARING ---
  Future<int> getArtworkCacheSizeBytes() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/artwork_cache');
      if (await cacheDir.exists()) {
        int total = 0;
        await for (final file in cacheDir.list(recursive: true)) {
          if (file is File) {
            total += await file.length();
          }
        }
        return total;
      }
    } catch (e) {
      debugPrint('Error calculating cache size: $e');
    }
    return 0;
  }

  Future<void> clearArtworkCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/artwork_cache');
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }
}
