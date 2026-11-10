import 'dart:io';
import 'package:flutter/foundation.dart';
import '../database/song_cache_service.dart';
import '../models/lyric_line_model.dart';
import '../models/song_model.dart';

class LyricsService {
  static final LyricsService _instance = LyricsService._internal();
  factory LyricsService() => _instance;
  LyricsService._internal();

  final SongCacheService _cacheService = SongCacheService();

  /// Retrieves lyrics for a song from local LRC file or Hive cache
  Future<List<LyricLine>> getLyricsForSong(SongModel song) async {
    // 1. Check user-saved custom lyrics in cache first
    final cached = _cacheService.getSetting('lyrics_${song.id}');
    if (cached is String && cached.trim().isNotEmpty) {
      return LyricLine.parseLrc(cached);
    }

    // 2. Look for local .lrc file next to the audio file on disk
    try {
      final audioFile = File(song.dataPath);
      if (await audioFile.exists()) {
        final parentDir = audioFile.parent.path;
        final baseName = audioFile.uri.pathSegments.last.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');

        // Try exact match: songName.lrc
        final lrcFile = File('$parentDir/$baseName.lrc');
        if (await lrcFile.exists()) {
          final content = await lrcFile.readAsString();
          if (content.trim().isNotEmpty) {
            return LyricLine.parseLrc(content);
          }
        }

        // Try title-based match: songTitle.lrc
        final cleanTitle = song.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
        final titleLrcFile = File('$parentDir/$cleanTitle.lrc');
        if (await titleLrcFile.exists()) {
          final content = await titleLrcFile.readAsString();
          if (content.trim().isNotEmpty) {
            return LyricLine.parseLrc(content);
          }
        }
      }
    } catch (e) {
      debugPrint('SONIQ: Error reading local LRC file: $e');
    }

    return [];
  }

  /// Saves user edited or imported lyrics locally
  Future<void> saveLyricsForSong(String songId, String rawContent) async {
    await _cacheService.setSetting('lyrics_$songId', rawContent);
  }

  /// Deletes saved lyrics for a song
  Future<void> deleteLyricsForSong(String songId) async {
    await _cacheService.setSetting('lyrics_$songId', '');
  }
}
