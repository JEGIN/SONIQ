import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart' as audio_query;
import 'package:path_provider/path_provider.dart';

import '../models/song_model.dart';
import '../database/song_cache_service.dart';
import '../utils/file_utils.dart';
import 'permission_service.dart';

class AudioScannerService {
  static final AudioScannerService _instance = AudioScannerService._internal();
  factory AudioScannerService() => _instance;
  AudioScannerService._internal();

  final audio_query.OnAudioQuery _audioQuery = audio_query.OnAudioQuery();
  final SongCacheService _cacheService = SongCacheService();

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  /// Scans device for audio tracks with duplicate elimination and metadata persistence
  Future<List<SongModel>> scanAudioFiles({
    Function(int current, int total)? onProgress,
  }) async {
    if (_isScanning) return _cacheService.getCachedSongs();
    _isScanning = true;

    try {
      final hasPermission = await PermissionService.requestMediaPermissions();
      if (!hasPermission && Platform.isAndroid) {
        debugPrint(
          'SONIQ: Media permission not granted. Returning cached songs.',
        );
        _isScanning = false;
        return _cacheService.getCachedSongs();
      }

      // Existing cached songs map (id -> SongModel) to retain favorite and play stats
      final existingCache = {
        for (final s in _cacheService.getCachedSongs()) s.id: s,
      };
      final persistedFavoriteIds = _cacheService.getFavoriteSongIds().toSet();

      final List<SongModel> scannedSongs = [];
      final Set<String> seenPaths = {};

      // 1. Query via OnAudioQuery (MediaStore on Android, MPMediaQuery on iOS)
      if (hasPermission || Platform.isAndroid) {
        try {
          final queryResult = await _audioQuery.querySongs(
            sortType: audio_query.SongSortType.TITLE,
            orderType: audio_query.OrderType.ASC_OR_SMALLER,
            uriType: audio_query.UriType.EXTERNAL,
            ignoreCase: true,
          );

        int totalCount = queryResult.length;
        int processed = 0;

        for (final song in queryResult) {
          processed++;
          if (onProgress != null && totalCount > 0) {
            onProgress(processed, totalCount);
          }

          // Filter out ringtones/short notifications (< 10 seconds)
          final duration = song.duration ?? 0;
          if (duration < 10000) continue;

          final filePath = song.data;

          if (_cacheService.isPathExcluded(filePath)) continue;

          // Skip default recordings, voice notes, call recordings, and system audio
          if (_cacheService.isSkipRecordingsEnabled()) {
            final shouldSkip = isIgnoredRecordingOrSystemAudio(
              filePath: filePath,
              title: song.title,
              artist: song.artist,
              album: song.album,
              durationMs: duration,
              isMusic: song.isMusic,
              isRingtone: song.isRingtone,
              isAlarm: song.isAlarm,
              isNotification: song.isNotification,
            );
            if (shouldSkip) continue;
          }

          if (seenPaths.contains(filePath) ||
              seenPaths.contains(song.id.toString())) {
            continue;
          }
          if (filePath.isNotEmpty) {
            seenPaths.add(filePath);
          }
          seenPaths.add(song.id.toString());

          final songId = song.id.toString();
          // Match by id first, or fallback to title+artist match to survive file moves/renames
          final songTitle = (song.title.trim().isNotEmpty)
              ? song.title.trim()
              : song.displayName;
          final songArtist = (song.artist != null && song.artist != '<unknown>')
              ? song.artist!.trim()
              : 'Unknown Artist';
          final existing =
              existingCache[songId] ??
              existingCache.values
                  .where(
                    (e) =>
                        e.title.toLowerCase() == songTitle.toLowerCase() &&
                        e.artist.toLowerCase() == songArtist.toLowerCase(),
                  )
                  .firstOrNull;

          final isFav =
              (existing?.isFavorite ?? false) ||
              persistedFavoriteIds.contains(songId);

          final ext = FileUtils.getFileExtension(
            filePath.isNotEmpty ? filePath : song.displayName,
          );

          final newSong = SongModel(
            id: songId,
            title: songTitle,
            artist: songArtist,
            album: (song.album != null && song.album != '<unknown>')
                ? song.album!.trim()
                : 'Unknown Album',
            durationMs: duration,
            dataPath: filePath.isNotEmpty ? filePath : song.uri ?? '',
            albumArtUri: song.id.toString(),
            dateAdded:
                song.dateAdded ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
            sizeBytes: song.size,
            fileExtension: ext.isNotEmpty ? ext : 'mp3',
            isFavorite: isFav,
            playCount: existing?.playCount ?? 0,
            lastPlayedTimestamp: existing?.lastPlayedTimestamp ?? 0,
            waveformPeaks: existing?.waveformPeaks,
          );

          scannedSongs.add(newSong);
        }
      } catch (e) {
        debugPrint(
          'SONIQ: OnAudioQuery error: $e. Falling back to directory scan.',
        );
      }
    }

      // 2. Directory Fallback Scanner (for direct files, iOS Files app, or emulators)
      if (scannedSongs.isEmpty || Platform.isIOS) {
        final fallbackSongs = await _scanCommonDirectories(
          existingCache,
          seenPaths,
        );
        scannedSongs.addAll(fallbackSongs);
      }

      // Save to Hive cache
      await _cacheService.saveSongs(scannedSongs);
      debugPrint(
        'SONIQ: Successfully indexed ${scannedSongs.length} local audio tracks.',
      );
      return scannedSongs;
    } catch (e, stack) {
      debugPrint('SONIQ: Error scanning audio files: $e\n$stack');
      return _cacheService.getCachedSongs();
    } finally {
      _isScanning = false;
    }
  }

  /// Scans known music directories on Android / iOS
  Future<List<SongModel>> _scanCommonDirectories(
    Map<String, SongModel> existingCache,
    Set<String> seenPaths,
  ) async {
    final List<SongModel> results = [];
    final List<Directory> searchDirs = [];

    try {
      if (Platform.isAndroid) {
        searchDirs.addAll([
          Directory('/storage/emulated/0/Music'),
          Directory('/storage/emulated/0/Download'),
          Directory('/storage/emulated/0/Audio'),
        ]);
      }

      final appDocDir = await getApplicationDocumentsDirectory();
      searchDirs.add(appDocDir);

      // Include user-configured/imported custom directories
      for (final customPath in _cacheService.getCustomDirectories()) {
        searchDirs.add(Directory(customPath));
      }

      for (final dir in searchDirs) {
        if (!await dir.exists()) continue;
        await for (final entity in dir.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is File && FileUtils.isSupportedAudioFile(entity.path)) {
            if (_cacheService.isPathExcluded(entity.path)) continue;
            if (seenPaths.contains(entity.path)) continue;
            seenPaths.add(entity.path);

            final stat = await entity.stat();
            if (stat.size < 50000) continue; // Skip tiny files (< 50KB)

            final fileName = FileUtils.getFileNameWithoutExtension(entity.path);
            final ext = FileUtils.getFileExtension(entity.path);
            final id = 'file_${entity.path.hashCode.abs()}';
            final existing = existingCache[id];

            // Estimate duration roughly from file size (128kbps ~ 16KB/s) if not indexed
            final estimatedDurationMs = ((stat.size / 16000) * 1000).toInt();

            // Skip default recordings and voice notes
            if (_cacheService.isSkipRecordingsEnabled()) {
              final shouldSkip = isIgnoredRecordingOrSystemAudio(
                filePath: entity.path,
                title: fileName,
                durationMs: existing?.durationMs ?? estimatedDurationMs,
              );
              if (shouldSkip) continue;
            }

            // Extract folder structure (e.g. SONGS/ANIRUTH/song.mp3)
            final segments = entity.uri.pathSegments
                .where((s) => s.isNotEmpty)
                .toList();
            String detectedArtist = 'Unknown Artist';
            String detectedAlbum = 'Local Music';

            if (segments.length >= 2) {
              final parentName = Uri.decodeComponent(
                segments[segments.length - 2],
              );
              if (parentName.isNotEmpty &&
                  parentName.toLowerCase() != 'soniq' &&
                  parentName.toLowerCase() != 'documents' &&
                  parentName.toLowerCase() != 'music') {
                detectedArtist = parentName;
              }
            }
            if (segments.length >= 3) {
              final grandParentName = Uri.decodeComponent(
                segments[segments.length - 3],
              );
              if (grandParentName.isNotEmpty &&
                  grandParentName.toLowerCase() != 'soniq' &&
                  grandParentName.toLowerCase() != 'documents') {
                detectedAlbum = grandParentName;
              } else {
                detectedAlbum = detectedArtist;
              }
            }

            final song = SongModel(
              id: id,
              title: fileName,
              artist: existing?.artist != null &&
                      existing!.artist != 'Unknown Artist'
                  ? existing.artist
                  : detectedArtist,
              album: existing?.album != null &&
                      existing!.album != 'Unknown Album' &&
                      existing.album != 'Local Music'
                  ? existing.album
                  : detectedAlbum,
              durationMs: existing?.durationMs ?? estimatedDurationMs,
              dataPath: entity.path,
              dateAdded: stat.modified.millisecondsSinceEpoch ~/ 1000,
              sizeBytes: stat.size,
              fileExtension: ext,
              isFavorite: existing?.isFavorite ?? false,
              playCount: existing?.playCount ?? 0,
              lastPlayedTimestamp: existing?.lastPlayedTimestamp ?? 0,
              waveformPeaks: existing?.waveformPeaks,
            );
            results.add(song);
          }
        }
      }
    } catch (e) {
      debugPrint('SONIQ: Directory scan error: $e');
    }
    return results;
  }

  /// Groups songs by containing directory for Folder Browsing
  static Map<String, List<SongModel>> groupSongsByFolder(
    List<SongModel> songs,
  ) {
    final Map<String, List<SongModel>> folderMap = {};
    for (final song in songs) {
      if (song.dataPath.isEmpty) continue;
      final file = File(song.dataPath);
      final folderName = file.parent.path.split(Platform.pathSeparator).last;
      final folder = folderName.isNotEmpty ? folderName : 'Music';
      folderMap.putIfAbsent(folder, () => []).add(song);
    }
    return folderMap;
  }

  /// Directory path patterns representing voice recorders, call recordings, messaging voice notes, and system audio
  static final List<RegExp> ignoredDirectoryPatterns = [
    RegExp(r'/recordings?(/|$)', caseSensitive: false),
    RegExp(r'/sound_?recorders?(/|$)', caseSensitive: false),
    RegExp(r'/voice_?recorders?(/|$)', caseSensitive: false),
    RegExp(r'/voice_?records?(/|$)', caseSensitive: false),
    RegExp(r'/voice_?notes?(/|$)', caseSensitive: false),
    RegExp(r'/call_?recordings?(/|$)', caseSensitive: false),
    RegExp(r'/call_?rec(/|$)', caseSensitive: false),
    RegExp(r'/audio_?recordings?(/|$)', caseSensitive: false),
    RegExp(r'/audio_?recorder(/|$)', caseSensitive: false),
    RegExp(r'/recorder(/|$)', caseSensitive: false),
    RegExp(
      r'/whatsapp(\s+|_)(voice(\s+|_)notes|audio)(/|$)',
      caseSensitive: false,
    ),
    RegExp(r'/com\.whatsapp(/|$)', caseSensitive: false),
    RegExp(r'/telegram(\s+|_)audio(/|$)', caseSensitive: false),
    RegExp(r'/com\.nothing\.soundrecorder(/|$)', caseSensitive: false),
    RegExp(r'/com\.google\.android\.apps\.recorder(/|$)', caseSensitive: false),
    RegExp(r'/com\.sec\.android\.app\.voicenote(/|$)', caseSensitive: false),
    RegExp(r'/com\.coloros\.soundrecorder(/|$)', caseSensitive: false),
    RegExp(r'/miui/sound_recorder(/|$)', caseSensitive: false),
    RegExp(r'/notifications?(/|$)', caseSensitive: false),
    RegExp(r'/ringtones?(/|$)', caseSensitive: false),
    RegExp(r'/alarms?(/|$)', caseSensitive: false),
    RegExp(r'/podcasts?(/|$)', caseSensitive: false),
    RegExp(r'/\.trash(/|$)', caseSensitive: false),
    RegExp(r'/\.cache(/|$)', caseSensitive: false),
  ];

  /// Checks whether an audio track belongs to voice recording, call recording, messaging voice note, or system sound
  static bool isIgnoredRecordingOrSystemAudio({
    required String filePath,
    String? title,
    String? artist,
    String? album,
    bool? isMusic,
    bool? isRingtone,
    bool? isAlarm,
    bool? isNotification,
    int? durationMs,
  }) {
    // 1. Android MediaStore explicit non-music system flags
    if (isRingtone == true || isAlarm == true || isNotification == true) {
      return true;
    }
    if (isMusic == false && (durationMs == null || durationMs < 60000)) {
      return true;
    }

    // 2. Minimum duration requirement: Audio shorter than 10 seconds is never a regular music track
    if (durationMs != null && durationMs > 0 && durationMs < 10000) {
      return true;
    }

    final normalizedPath = filePath.replaceAll('\\', '/');

    // 3. Match against known recording & system folders
    for (final pattern in ignoredDirectoryPatterns) {
      if (pattern.hasMatch(normalizedPath)) {
        return true;
      }
    }

    // 4. Album / Artist recording indicators
    final albumLower = (album ?? '').trim().toLowerCase();
    final artistLower = (artist ?? '').trim().toLowerCase();

    const recordingLabels = {
      'recordings',
      'sound recorder',
      'sound recording',
      'voice recorder',
      'voice recordings',
      'voice notes',
      'call recordings',
      'call recording',
      'call recorder',
      'recorder',
      'whatsapp audio',
      'whatsapp voice notes',
    };

    if (recordingLabels.contains(albumLower) ||
        recordingLabels.contains(artistLower)) {
      return true;
    }

    // 5. Common call recorder & voice note file prefix heuristic
    final fileName = normalizedPath.split('/').last.toLowerCase();
    if (fileName.startsWith('call_') ||
        fileName.startsWith('rec_') ||
        fileName.startsWith('recording_') ||
        fileName.startsWith('voice_') ||
        fileName.startsWith('audiorecording_') ||
        fileName.startsWith('ptt-') ||
        fileName.startsWith('aud-20')) {
      if (albumLower.isEmpty ||
          albumLower == 'unknown album' ||
          albumLower == 'music' ||
          albumLower == 'download') {
        return true;
      }
    }

    return false;
  }
}
