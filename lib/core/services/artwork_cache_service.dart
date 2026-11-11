import 'dart:collection';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart' as audio_query;
import 'package:path_provider/path_provider.dart';

class ArtworkCacheService {
  static final ArtworkCacheService _instance = ArtworkCacheService._internal();
  factory ArtworkCacheService() => _instance;
  ArtworkCacheService._internal();

  final audio_query.OnAudioQuery _audioQuery = audio_query.OnAudioQuery();
  static const int _maxMemoryCacheEntries = 60;
  final LinkedHashMap<String, Uint8List?> _memoryCache = LinkedHashMap<String, Uint8List?>();
  Directory? _cacheDir;
  File? _fallbackArtFile;

  Future<void> init() async {
    try {
      final tempDir = await getTemporaryDirectory();
      _cacheDir = Directory('${tempDir.path}/soniq_art_cache');
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }

      // Generate fallback artwork from bundled app icon
      _fallbackArtFile = File('${_cacheDir!.path}/soniq_fallback_artwork.png');
      if (!await _fallbackArtFile!.exists()) {
        final byteData = await rootBundle.load('assets/icons/app_icon.png');
        await _fallbackArtFile!.writeAsBytes(byteData.buffer.asUint8List());
      }
    } catch (e) {
      debugPrint('SONIQ: ArtworkCacheService init error: $e');
    }
  }

  File? get fallbackArtFile => _fallbackArtFile;

  void _putMemoryCache(String songId, Uint8List? bytes) {
    if (_memoryCache.containsKey(songId)) {
      _memoryCache.remove(songId);
    } else if (_memoryCache.length >= _maxMemoryCacheEntries) {
      _memoryCache.remove(_memoryCache.keys.first);
    }
    _memoryCache[songId] = bytes;
  }

  /// Retrieves cached artwork bytes from memory or disk, or queries MediaStore
  Future<Uint8List?> getArtworkBytes(String songId) async {
    if (_memoryCache.containsKey(songId)) {
      final bytes = _memoryCache.remove(songId);
      _memoryCache[songId] = bytes;
      return bytes;
    }

    // Check disk cache
    if (_cacheDir != null) {
      final diskFile = File('${_cacheDir!.path}/art_$songId.jpg');
      if (await diskFile.exists()) {
        try {
          final bytes = await diskFile.readAsBytes();
          _putMemoryCache(songId, bytes);
          return bytes;
        } catch (_) {}
      }
    }

    // Query via OnAudioQuery
    final int? id = int.tryParse(songId);
    if (id != null) {
      try {
        final bytes = await _audioQuery.queryArtwork(
          id,
          audio_query.ArtworkType.AUDIO,
          format: audio_query.ArtworkFormat.JPEG,
          size: 500,
        );

        _putMemoryCache(songId, bytes);

        // Persist to disk cache for MediaItem artUri
        if (bytes != null && _cacheDir != null) {
          final diskFile = File('${_cacheDir!.path}/art_$songId.jpg');
          await diskFile.writeAsBytes(bytes);
        }
        return bytes;
      } catch (e) {
        debugPrint('SONIQ: Error querying artwork for $songId: $e');
      }
    }

    _putMemoryCache(songId, null);
    return null;
  }

  /// Returns a valid local file URI for Android MediaNotification
  Future<Uri?> getArtworkUriForSong(String songId) async {
    if (_cacheDir == null) await init();

    if (_cacheDir != null) {
      final diskFile = File('${_cacheDir!.path}/art_$songId.jpg');
      if (await diskFile.exists()) {
        return Uri.file(diskFile.path);
      }
    }

    // Try fetching and caching
    final bytes = await getArtworkBytes(songId);
    if (bytes != null && _cacheDir != null) {
      final diskFile = File('${_cacheDir!.path}/art_$songId.jpg');
      if (await diskFile.exists()) {
        return Uri.file(diskFile.path);
      }
    }

    // Use fallback artwork
    if (_fallbackArtFile != null && await _fallbackArtFile!.exists()) {
      return Uri.file(_fallbackArtFile!.path);
    }

    return null;
  }

  /// Synchronously returns a local file URI if already cached on disk,
  /// or returns the fallback artwork URI immediately to keep car browsing 60fps fast.
  Uri? getCachedArtworkUri(String songId) {
    if (_cacheDir != null) {
      final diskFile = File('${_cacheDir!.path}/art_$songId.jpg');
      if (diskFile.existsSync()) {
        return Uri.file(diskFile.path);
      }
    }
    if (_fallbackArtFile != null && _fallbackArtFile!.existsSync()) {
      return Uri.file(_fallbackArtFile!.path);
    }
    return null;
  }

  /// Background pre-warmer that ensures artwork is written to disk for car browsing
  void prewarmArtworkCache(List<dynamic> songs, {int maxCount = 200}) {
    Future.microtask(() async {
      int processed = 0;
      for (final s in songs) {
        if (processed >= maxCount) break;
        final String songId = s.id.toString();
        if (_cacheDir != null) {
          final diskFile = File('${_cacheDir!.path}/art_$songId.jpg');
          if (!diskFile.existsSync()) {
            await getArtworkBytes(songId);
            processed++;
            if (processed % 10 == 0) {
              await Future.delayed(const Duration(milliseconds: 30));
            }
          }
        }
      }
    });
  }
}
