import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song_model.dart';
import '../database/song_cache_service.dart';
import 'artwork_cache_service.dart';
import 'audio_dsp_service.dart';

Future<SoniqAudioHandler> initAudioHandler() async {
  return await AudioService.init(
    builder: () => SoniqAudioHandler(),
    config: AudioServiceConfig(
      androidNotificationChannelId: 'com.soniq.soniq.channel.audio',
      androidNotificationChannelName: 'SONIQ Playback',
      androidNotificationChannelDescription: 'SONIQ High Fidelity Offline Music Player',
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: false,
      androidShowNotificationBadge: true,
      notificationColor: const Color(0xFFFF2A85),
    ),
  );
}

class SoniqAudioHandler extends BaseAudioHandler {
  final AudioPlayer _player = AudioPlayer();
  final SongCacheService _cacheService = SongCacheService();
  final ArtworkCacheService _artworkService = ArtworkCacheService();

  List<SongModel> _originalPlaylist = [];
  List<SongModel> _effectivePlaylist = [];
  int _currentIndex = -1;
  final List<SongModel> _playbackHistory = [];
  bool _isShuffle = false;
  bool _stopAfterCurrentTrack = false;

  AudioPlayer get player => _player;
  List<SongModel> get currentPlaylist => _effectivePlaylist;
  List<SongModel> get originalPlaylist => _originalPlaylist;
  int get currentIndex => _currentIndex;
  bool get isShuffle => _isShuffle;
  bool get stopAfterCurrentTrack => _stopAfterCurrentTrack;
  void setStopAfterCurrentTrack(bool val) => _stopAfterCurrentTrack = val;
  List<SongModel> get playbackHistory => List.unmodifiable(_playbackHistory);
  SongModel? get currentSong =>
      (_currentIndex >= 0 && _currentIndex < _effectivePlaylist.length)
          ? _effectivePlaylist[_currentIndex]
          : null;

  SoniqAudioHandler() {
    _initAudioSession();
    _listenToPlayerEvents();
    _artworkService.init();
    _hookNativeDspSession();
    _initPersistence();
  }

  void _initPersistence() {
    // Periodically save playback position when pausing or state changes
    _player.playerStateStream.listen((state) {
      if (!state.playing) {
        persistCurrentQueue();
      }
    });

    // Restore saved queue after cache is initialized
    Future.delayed(const Duration(milliseconds: 300), () {
      restorePersistedQueue();
    });
  }

  void _hookNativeDspSession() {
    _player.androidAudioSessionIdStream.listen((sessionId) {
      if (sessionId != null && sessionId > 0) {
        AudioDspService().attachAudioSession(sessionId);
      }
    });
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    // Handle headphone unplug or Bluetooth disconnect
    session.becomingNoisyEventStream.listen((_) {
      pause();
    });

    // Handle audio interruptions (e.g. phone call)
    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        switch (event.type) {
          case AudioInterruptionType.duck:
            _player.setVolume(0.3);
            break;
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            pause();
            break;
        }
      } else {
        switch (event.type) {
          case AudioInterruptionType.duck:
            _player.setVolume(1.0);
            break;
          case AudioInterruptionType.pause:
            play();
            break;
          case AudioInterruptionType.unknown:
            break;
        }
      }
    });
  }

  void _listenToPlayerEvents() {
    // Broadcast playback state updates to system lock-screen / notification
    _player.playbackEventStream.listen((PlaybackEvent event) {
      _broadcastPlaybackState();
    });

    // Handle song completion and advance to next track
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (_stopAfterCurrentTrack) {
          _stopAfterCurrentTrack = false;
          pause();
          return;
        }
        if (_player.loopMode == LoopMode.one) {
          _player.seek(Duration.zero);
          _player.play();
        } else {
          skipToNext();
        }
      }
    });
  }

  void _broadcastPlaybackState() {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.setShuffleMode,
        MediaAction.setRepeatMode,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState] ?? AudioProcessingState.idle,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _currentIndex,
      shuffleMode: _isShuffle
          ? AudioServiceShuffleMode.all
          : AudioServiceShuffleMode.none,
      repeatMode: {
        LoopMode.off: AudioServiceRepeatMode.none,
        LoopMode.one: AudioServiceRepeatMode.one,
        LoopMode.all: AudioServiceRepeatMode.all,
      }[_player.loopMode] ?? AudioServiceRepeatMode.none,
    ));
  }

  /// Sets queue and plays selected track
  Future<void> playSongList(List<SongModel> songs, int initialIndex, {bool? shuffle}) async {
    if (songs.isEmpty) return;

    if (shuffle != null) {
      _isShuffle = shuffle;
    }

    _originalPlaylist = List.from(songs);
    final clampedIdx = initialIndex.clamp(0, _originalPlaylist.length - 1);
    final targetSong = _originalPlaylist[clampedIdx];

    if (_isShuffle) {
      final remaining = List<SongModel>.from(_originalPlaylist)..removeAt(clampedIdx);
      remaining.shuffle(Random());
      _effectivePlaylist = [targetSong, ...remaining];
      _currentIndex = 0;
    } else {
      _effectivePlaylist = List.from(_originalPlaylist);
      _currentIndex = clampedIdx;
    }

    _playbackHistory.clear();

    // Broadcast updated queue
    _updateQueueItems();
    await _loadAndPlayCurrent();
  }

  void _updateQueueItems() {
    final items = _effectivePlaylist.map((s) => _songToMediaItem(s)).toList();
    queue.add(items);
  }

  // ==========================================
  // PROFESSIONAL QUEUE MANAGEMENT METHODS
  // ==========================================

  /// Reorders items in the queue from oldIndex to newIndex.
  /// Seamlessly updates _currentIndex so currently playing audio is never interrupted!
  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _effectivePlaylist.length) return;
    if (newIndex < 0 || newIndex > _effectivePlaylist.length) return;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    if (oldIndex == newIndex) return;

    final song = _effectivePlaylist.removeAt(oldIndex);
    _effectivePlaylist.insert(newIndex, song);

    // Adjust currentIndex
    if (oldIndex == _currentIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex -= 1;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex += 1;
    }

    _updateQueueItems();
    _broadcastPlaybackState();
    persistCurrentQueue();
  }

  /// Inserts a song immediately after the currently playing song
  void playNext(SongModel song) {
    if (_effectivePlaylist.isEmpty) {
      playSongList([song], 0);
      return;
    }

    final insertIdx = (_currentIndex + 1).clamp(0, _effectivePlaylist.length);
    _effectivePlaylist.insert(insertIdx, song);
    if (!_originalPlaylist.any((s) => s.id == song.id)) {
      _originalPlaylist.add(song);
    }

    _updateQueueItems();
    _broadcastPlaybackState();
    persistCurrentQueue();
  }

  /// Appends a song to the end of the playback queue
  void addToQueue(SongModel song) {
    if (_effectivePlaylist.isEmpty) {
      playSongList([song], 0);
      return;
    }

    _effectivePlaylist.add(song);
    if (!_originalPlaylist.any((s) => s.id == song.id)) {
      _originalPlaylist.add(song);
    }

    _updateQueueItems();
    _broadcastPlaybackState();
    persistCurrentQueue();
  }

  /// Adds multiple songs (e.g. from an album or artist) to the queue
  void addMultipleToQueue(List<SongModel> songs, {bool playNext = false}) {
    if (songs.isEmpty) return;

    if (_effectivePlaylist.isEmpty) {
      playSongList(songs, 0);
      return;
    }

    if (playNext) {
      final insertIdx = (_currentIndex + 1).clamp(0, _effectivePlaylist.length);
      _effectivePlaylist.insertAll(insertIdx, songs);
    } else {
      _effectivePlaylist.addAll(songs);
    }

    for (final s in songs) {
      if (!_originalPlaylist.any((o) => o.id == s.id)) {
        _originalPlaylist.add(s);
      }
    }

    _updateQueueItems();
    _broadcastPlaybackState();
    persistCurrentQueue();
  }

  /// Adds all songs from an album to the queue
  void addAlbumToQueue(String albumName, {bool playNext = false}) {
    final cachedSongs = _cacheService.getCachedSongs();
    final albumSongs = cachedSongs
        .where((s) => s.album.toLowerCase() == albumName.toLowerCase())
        .toList();
    if (albumSongs.isNotEmpty) {
      addMultipleToQueue(albumSongs, playNext: playNext);
    }
  }

  /// Adds all songs from an artist to the queue
  void addArtistToQueue(String artistName, {bool playNext = false}) {
    final cachedSongs = _cacheService.getCachedSongs();
    final artistSongs = cachedSongs
        .where((s) => s.artist.toLowerCase() == artistName.toLowerCase())
        .toList();
    if (artistSongs.isNotEmpty) {
      addMultipleToQueue(artistSongs, playNext: playNext);
    }
  }

  /// Removes item at index from queue, adjusting currentIndex properly.
  /// Returns the removed SongModel.
  SongModel? removeFromQueue(int index) {
    if (index < 0 || index >= _effectivePlaylist.length) return null;

    final removed = _effectivePlaylist.removeAt(index);

    if (index == _currentIndex) {
      if (_effectivePlaylist.isEmpty) {
        _currentIndex = -1;
        _player.stop();
        mediaItem.add(null);
      } else {
        if (_currentIndex >= _effectivePlaylist.length) {
          _currentIndex = _effectivePlaylist.length - 1;
        }
        _loadAndPlayCurrent();
      }
    } else if (index < _currentIndex) {
      _currentIndex -= 1;
    }

    _updateQueueItems();
    _broadcastPlaybackState();
    persistCurrentQueue();
    return removed;
  }

  /// Inserts a song back at specific index (for Undo)
  void insertIntoQueue(int index, SongModel song) {
    final targetIdx = index.clamp(0, _effectivePlaylist.length);
    _effectivePlaylist.insert(targetIdx, song);

    if (targetIdx <= _currentIndex) {
      _currentIndex += 1;
    }

    _updateQueueItems();
    _broadcastPlaybackState();
    persistCurrentQueue();
  }

  /// Clears upcoming songs in the queue while keeping currently playing song at index 0
  void clearUpcomingQueue() {
    if (_effectivePlaylist.isEmpty) return;

    final curr = currentSong;
    if (curr != null) {
      _effectivePlaylist = [curr];
      _currentIndex = 0;
    } else {
      _effectivePlaylist.clear();
      _currentIndex = -1;
    }

    _updateQueueItems();
    _broadcastPlaybackState();
    persistCurrentQueue();
  }

  /// Move item one position up
  void moveQueueItemUp(int index) {
    if (index > 0 && index < _effectivePlaylist.length) {
      reorderQueue(index, index - 1);
    }
  }

  /// Move item one position down
  void moveQueueItemDown(int index) {
    if (index >= 0 && index < _effectivePlaylist.length - 1) {
      reorderQueue(index, index + 2);
    }
  }

  /// Persists current queue, position, and index to Hive for state restoration
  Future<void> persistCurrentQueue() async {
    try {
      final ids = _effectivePlaylist.map((s) => s.id).toList();
      await _cacheService.setSetting('saved_queue_ids', ids);
      await _cacheService.setSetting('saved_queue_index', _currentIndex);
      await _cacheService.setSetting('saved_queue_pos_ms', _player.position.inMilliseconds);
      await _cacheService.setSetting('saved_queue_shuffle', _isShuffle);
      await _cacheService.setSetting('saved_repeat_mode', _player.loopMode.name);
    } catch (e) {
      debugPrint('SONIQ: Error persisting queue: $e');
    }
  }

  /// Restores saved queue on app startup
  Future<void> restorePersistedQueue() async {
    try {
      final savedIds = _cacheService.getSetting('saved_queue_ids');
      if (savedIds is List && savedIds.isNotEmpty) {
        final allCached = _cacheService.getCachedSongs();
        final songMap = {for (final s in allCached) s.id: s};
        final restored = savedIds.map((id) => songMap[id]).whereType<SongModel>().toList();

        if (restored.isNotEmpty) {
          _originalPlaylist = List.from(restored);
          _effectivePlaylist = List.from(restored);
          final savedIdx = (_cacheService.getSetting('saved_queue_index', defaultValue: 0) as num).toInt();
          _currentIndex = savedIdx.clamp(0, _effectivePlaylist.length - 1);
          final savedShuffle = _cacheService.getSetting('saved_queue_shuffle', defaultValue: false) as bool;
          _isShuffle = savedShuffle;

          final savedRepeat = _cacheService.getSetting('saved_repeat_mode', defaultValue: 'off') as String;
          final loop = LoopMode.values.firstWhere(
            (m) => m.name == savedRepeat,
            orElse: () => LoopMode.off,
          );
          await _player.setLoopMode(loop);

          final savedPosMs = (_cacheService.getSetting('saved_queue_pos_ms', defaultValue: 0) as num).toInt();

          final song = _effectivePlaylist[_currentIndex];
          final artUri = await _artworkService.getArtworkUriForSong(song.id);
          final item = _songToMediaItem(song, artUriOverride: artUri);
          mediaItem.add(item);
          _updateQueueItems();
          _broadcastPlaybackState();

          final file = File(song.dataPath);
          if (await file.exists()) {
            await _player.setFilePath(song.dataPath);
            if (savedPosMs > 0) {
              await _player.seek(Duration(milliseconds: savedPosMs));
            }
          } else {
            // Find first available file if saved current song was deleted
            for (int i = 0; i < _effectivePlaylist.length; i++) {
              if (await File(_effectivePlaylist[i].dataPath).exists()) {
                _currentIndex = i;
                await _player.setFilePath(_effectivePlaylist[i].dataPath);
                break;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('SONIQ: Error restoring persisted queue: $e');
    }
  }

  Future<void> _loadAndPlayCurrent() async {
    if (_currentIndex < 0 || _currentIndex >= _effectivePlaylist.length) return;
    final song = _effectivePlaylist[_currentIndex];

    // 1. Immediately emit mediaItem with cached/fallback artwork so notification updates in 0ms!
    final immediateItem = _songToMediaItem(song);
    mediaItem.add(immediateItem);
    _broadcastPlaybackState();

    // 2. Asynchronously fetch high-res artwork URI if not yet assigned
    _artworkService.getArtworkUriForSong(song.id).then((artUri) {
      if (artUri != null && currentSong?.id == song.id) {
        mediaItem.add(_songToMediaItem(song, artUriOverride: artUri));
      }
    });

    try {
      if (song.dataPath.startsWith('http://') || song.dataPath.startsWith('https://')) {
        await _player.setUrl(song.dataPath);
      } else {
        final file = File(song.dataPath);
        if (await file.exists()) {
          try {
            await _player.setFilePath(song.dataPath);
          } catch (e) {
            debugPrint('SONIQ: Corrupt audio file: ${song.dataPath} ($e)');
            skipToNext();
            return;
          }
        } else {
          debugPrint('SONIQ: File not found: ${song.dataPath}');
          skipToNext();
          return;
        }
      }

      await _player.play();
      _broadcastPlaybackState();

      final sid = _player.androidAudioSessionId;
      if (sid != null && sid > 0) {
        AudioDspService().attachAudioSession(sid);
      }

      // Record play count and last played in Hive
      await _cacheService.recordSongPlayed(song.id);
      persistCurrentQueue();
    } catch (e) {
      debugPrint('SONIQ: Error loading audio: $e');
    }
  }

  MediaItem _songToMediaItem(SongModel song, {Uri? artUriOverride}) {
    Uri? artUri = artUriOverride;
    if (artUri == null && _artworkService.fallbackArtFile != null) {
      final diskFile = File('${_artworkService.fallbackArtFile!.parent.path}/art_${song.id}.jpg');
      if (diskFile.existsSync()) {
        artUri = Uri.file(diskFile.path);
      } else {
        artUri = Uri.file(_artworkService.fallbackArtFile!.path);
      }
    }

    return MediaItem(
      id: song.id,
      album: song.album,
      title: song.title,
      artist: song.artist,
      duration: Duration(milliseconds: song.durationMs),
      artUri: artUri,
      playable: true,
      extras: {
        'dataPath': song.dataPath,
        'isFavorite': song.isFavorite,
        'fileExtension': song.fileExtension,
      },
    );
  }

  @override
  Future<void> play() async {
    await _player.play();
    _broadcastPlaybackState();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    _broadcastPlaybackState();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    _broadcastPlaybackState();
    await super.stop();
  }

  @override
  Future<void> skipToNext() async {
    if (_effectivePlaylist.isEmpty) return;

    // Single song in queue edge-case handling
    if (_effectivePlaylist.length == 1) {
      if (_player.loopMode == LoopMode.all || _player.loopMode == LoopMode.one) {
        await _player.seek(Duration.zero);
        await _player.play();
      } else {
        await pause();
        await _player.seek(Duration.zero);
      }
      return;
    }

    final curr = currentSong;
    if (curr != null) {
      _playbackHistory.add(curr);
      while (_playbackHistory.length > 50) {
        _playbackHistory.removeAt(0);
      }
    }

    if (_currentIndex < _effectivePlaylist.length - 1) {
      _currentIndex += 1;
    } else {
      if (_player.loopMode == LoopMode.all) {
        if (_isShuffle) {
          // Exhausted current shuffle sequence: re-shuffle for next cycle without repeating last song
          final lastId = _effectivePlaylist.last.id;
          final reshuffled = List<SongModel>.from(_originalPlaylist)..shuffle(Random());
          if (reshuffled.length > 1 && reshuffled.first.id == lastId) {
            final first = reshuffled.removeAt(0);
            reshuffled.add(first);
          }
          _effectivePlaylist = reshuffled;
          _currentIndex = 0;
          _updateQueueItems();
        } else {
          _currentIndex = 0;
        }
      } else {
        await pause();
        return;
      }
    }
    await _loadAndPlayCurrent();
  }

  @override
  Future<void> skipToPrevious() async {
    if (_effectivePlaylist.isEmpty) return;

    // If more than 3 seconds in, or only 1 song in queue, restart the song
    if (_player.position.inSeconds > 3 || _effectivePlaylist.length == 1) {
      await _player.seek(Duration.zero);
      return;
    }

    // Follow exact playback history
    if (_playbackHistory.isNotEmpty) {
      final prevSong = _playbackHistory.removeLast();
      final idx = _effectivePlaylist.indexWhere((s) => s.id == prevSong.id);
      if (idx >= 0) {
        _currentIndex = idx;
      } else {
        _effectivePlaylist.insert(_currentIndex, prevSong);
        _updateQueueItems();
      }
    } else if (_currentIndex > 0) {
      _currentIndex -= 1;
    } else if (_player.loopMode == LoopMode.all) {
      _currentIndex = _effectivePlaylist.length - 1;
    } else {
      await _player.seek(Duration.zero);
      return;
    }
    await _loadAndPlayCurrent();
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index >= 0 && index < _effectivePlaylist.length) {
      final curr = currentSong;
      if (curr != null) {
        _playbackHistory.add(curr);
      }
      _currentIndex = index;
      await _loadAndPlayCurrent();
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enable = shuffleMode == AudioServiceShuffleMode.all;
    if (_isShuffle == enable) return;
    _isShuffle = enable;

    final curr = currentSong;
    if (_isShuffle) {
      if (curr != null) {
        final remaining = List<SongModel>.from(_originalPlaylist)
          ..removeWhere((s) => s.id == curr.id);
        remaining.shuffle(Random());
        _effectivePlaylist = [curr, ...remaining];
        _currentIndex = 0;
      } else {
        _effectivePlaylist = List.from(_originalPlaylist)..shuffle(Random());
        _currentIndex = 0;
      }
    } else {
      _effectivePlaylist = List.from(_originalPlaylist);
      if (curr != null) {
        final idx = _effectivePlaylist.indexWhere((s) => s.id == curr.id);
        _currentIndex = idx >= 0 ? idx : 0;
      } else {
        _currentIndex = 0;
      }
    }

    _updateQueueItems();
    _broadcastPlaybackState();
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        await _player.setLoopMode(LoopMode.off);
        break;
      case AudioServiceRepeatMode.one:
        await _player.setLoopMode(LoopMode.one);
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        await _player.setLoopMode(LoopMode.all);
        break;
    }
    _broadcastPlaybackState();
    persistCurrentQueue();
  }

  @override
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
    _broadcastPlaybackState();
  }

  // --- SLEEP TIMER ---
  Timer? _sleepTimer;
  final StreamController<int> _sleepTimerSecController = StreamController<int>.broadcast();
  Stream<int> get sleepTimerRemainingSecStream => _sleepTimerSecController.stream;
  int _sleepTimerRemainingSec = 0;
  int get sleepTimerRemainingSec => _sleepTimerRemainingSec;

  void startSleepTimer(int minutes) {
    cancelSleepTimer();
    _sleepTimerRemainingSec = minutes * 60;
    _sleepTimerSecController.add(_sleepTimerRemainingSec);

    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      _sleepTimerRemainingSec--;
      _sleepTimerSecController.add(_sleepTimerRemainingSec);

      // Smooth volume fade during the last 15 seconds
      if (_sleepTimerRemainingSec <= 15 && _sleepTimerRemainingSec > 0) {
        final fadeVolume = (_sleepTimerRemainingSec / 15.0).clamp(0.05, 1.0);
        await _player.setVolume(fadeVolume);
      }

      if (_sleepTimerRemainingSec <= 0) {
        timer.cancel();
        _sleepTimer = null;
        await pause();
        await _player.setVolume(1.0);
        _sleepTimerSecController.add(0);
      }
    });
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerRemainingSec = 0;
    _sleepTimerSecController.add(0);
    _player.setVolume(1.0);
  }

  // ==========================================
  // ANDROID AUTO / MEDIABROWSER SERVICE APIS
  // ==========================================

  @override
  Future<List<MediaItem>> getChildren(String parentMediaId, [Map<String, dynamic>? options]) async {
    final cachedSongs = _cacheService.getCachedSongs();

    // 1. Root categories for Android Auto / In-Car Infotainment
    if (parentMediaId == AudioService.browsableRootId ||
        parentMediaId == '/' ||
        parentMediaId == 'root' ||
        parentMediaId.isEmpty) {
      final playlists = _cacheService.getPlaylists();
      final favIds = _cacheService.getFavoriteSongIds().toSet();
      final favCount = cachedSongs.where((s) => favIds.contains(s.id) || s.isFavorite).length;
      final artists = cachedSongs.map((s) => s.artist).toSet().length;
      final albums = cachedSongs.map((s) => s.album).toSet().length;

      return [
        MediaItem(
          id: 'category_current_queue',
          title: 'Current Queue',
          displaySubtitle: '${_effectivePlaylist.length} tracks queued • Active order',
          playable: false,
        ),
        MediaItem(
          id: 'category_all_songs',
          title: 'All Songs',
          displaySubtitle: '${cachedSongs.length} tracks • Offline Library',
          playable: false,
        ),
        MediaItem(
          id: 'category_recently_played',
          title: 'Recently Played',
          displaySubtitle: 'Recent listening history',
          playable: false,
        ),
        MediaItem(
          id: 'category_recently_added',
          title: 'Recently Added',
          displaySubtitle: 'Newest downloads',
          playable: false,
        ),
        MediaItem(
          id: 'category_favorites',
          title: 'Favorites',
          displaySubtitle: '$favCount favorite tracks',
          playable: false,
        ),
        MediaItem(
          id: 'category_playlists',
          title: 'Playlists',
          displaySubtitle: '${playlists.length} playlists',
          playable: false,
        ),
        MediaItem(
          id: 'category_artists',
          title: 'Artists',
          displaySubtitle: '$artists local artists',
          playable: false,
        ),
        MediaItem(
          id: 'category_albums',
          title: 'Albums',
          displaySubtitle: '$albums albums',
          playable: false,
        ),
      ];
    }

    // 2. Current Queue
    if (parentMediaId == 'category_current_queue') {
      return _effectivePlaylist.map((s) => _songToMediaItem(s)).toList();
    }

    // 3. All Songs
    if (parentMediaId == 'category_all_songs') {
      return cachedSongs.map((s) => _songToMediaItem(s)).toList();
    }

    // 3. Recently Played
    if (parentMediaId == 'category_recently_played') {
      final recentIds = _cacheService.getRecentlyPlayedSongIds(limit: 50);
      final songMap = {for (var s in cachedSongs) s.id: s};
      final recentSongs = <SongModel>[];
      for (final id in recentIds) {
        final s = songMap[id];
        if (s != null) recentSongs.add(s);
      }
      return recentSongs.map((s) => _songToMediaItem(s)).toList();
    }

    // 4. Recently Added
    if (parentMediaId == 'category_recently_added') {
      final sorted = List<SongModel>.from(cachedSongs)
        ..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
      return sorted.take(50).map((s) => _songToMediaItem(s)).toList();
    }

    // 5. Favorites
    if (parentMediaId == 'category_favorites') {
      final favIds = _cacheService.getFavoriteSongIds().toSet();
      final favs = cachedSongs.where((s) => favIds.contains(s.id) || s.isFavorite).toList();
      return favs.map((s) => _songToMediaItem(s)).toList();
    }

    // 6. Playlists Top-Level
    if (parentMediaId == 'category_playlists') {
      final playlists = _cacheService.getPlaylists();
      return playlists.map((p) => MediaItem(
        id: 'playlist_${p.id}',
        title: p.name,
        displaySubtitle: '${p.songCount} songs',
        playable: false,
      )).toList();
    }

    // 6b. Specific Playlist Content
    if (parentMediaId.startsWith('playlist_')) {
      final pId = parentMediaId.substring('playlist_'.length);
      final playlists = _cacheService.getPlaylists();
      final p = playlists.where((pl) => pl.id == pId).firstOrNull;
      if (p != null) {
        final songMap = {for (var s in cachedSongs) s.id: s};
        final pSongs = <SongModel>[];
        for (final id in p.songIds) {
          final s = songMap[id];
          if (s != null) pSongs.add(s);
        }
        return pSongs.map((s) => _songToMediaItem(s)).toList();
      }
      return [];
    }

    // 7. Artists Top-Level
    if (parentMediaId == 'category_artists') {
      final artists = cachedSongs.map((s) => s.artist).toSet().toList()..sort();
      return artists.map((a) => MediaItem(
        id: 'artist_$a',
        title: a,
        displaySubtitle: 'Artist',
        playable: false,
      )).toList();
    }

    // 7b. Specific Artist Tracks
    if (parentMediaId.startsWith('artist_')) {
      final artistName = parentMediaId.substring('artist_'.length);
      final aSongs = cachedSongs.where((s) => s.artist == artistName).toList();
      return aSongs.map((s) => _songToMediaItem(s)).toList();
    }

    // 8. Albums Top-Level
    if (parentMediaId == 'category_albums') {
      final albums = cachedSongs.map((s) => s.album).toSet().toList()..sort();
      return albums.map((a) => MediaItem(
        id: 'album_$a',
        title: a,
        displaySubtitle: 'Album',
        playable: false,
      )).toList();
    }

    // 8b. Specific Album Tracks
    if (parentMediaId.startsWith('album_')) {
      final albumName = parentMediaId.substring('album_'.length);
      final alSongs = cachedSongs.where((s) => s.album == albumName).toList();
      return alSongs.map((s) => _songToMediaItem(s)).toList();
    }

    return [];
  }

  @override
  Future<MediaItem?> getMediaItem(String mediaId) async {
    final cachedSongs = _cacheService.getCachedSongs();
    for (final s in cachedSongs) {
      if (s.id == mediaId) return _songToMediaItem(s);
    }
    return null;
  }

  @override
  Future<void> playFromMediaId(String mediaId, [Map<String, dynamic>? extras]) async {
    final cachedSongs = _cacheService.getCachedSongs();
    if (cachedSongs.isEmpty) return;

    if (mediaId == 'category_current_queue') {
      if (_effectivePlaylist.isNotEmpty) {
        await play();
      }
      return;
    }

    // If the song is already in the current active queue, jump to it without resetting the queue
    final inQueueIdx = _effectivePlaylist.indexWhere((s) => s.id == mediaId);
    if (inQueueIdx >= 0) {
      await skipToQueueItem(inQueueIdx);
      return;
    }

    if (mediaId == 'category_all_songs') {
      await playSongList(cachedSongs, 0);
      return;
    }
    if (mediaId == 'category_recently_played') {
      final recentIds = _cacheService.getRecentlyPlayedSongIds(limit: 50);
      final songMap = {for (var s in cachedSongs) s.id: s};
      final recentSongs = <SongModel>[];
      for (final id in recentIds) {
        final s = songMap[id];
        if (s != null) recentSongs.add(s);
      }
      if (recentSongs.isNotEmpty) await playSongList(recentSongs, 0);
      return;
    }
    if (mediaId == 'category_recently_added') {
      final sorted = List<SongModel>.from(cachedSongs)..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
      if (sorted.isNotEmpty) await playSongList(sorted, 0);
      return;
    }
    if (mediaId == 'category_favorites') {
      final favIds = _cacheService.getFavoriteSongIds().toSet();
      final favs = cachedSongs.where((s) => favIds.contains(s.id) || s.isFavorite).toList();
      if (favs.isNotEmpty) await playSongList(favs, 0);
      return;
    }
    if (mediaId.startsWith('playlist_')) {
      final pId = mediaId.substring('playlist_'.length);
      final playlists = _cacheService.getPlaylists();
      final p = playlists.where((pl) => pl.id == pId).firstOrNull;
      if (p != null) {
        final songMap = {for (var s in cachedSongs) s.id: s};
        final pSongs = <SongModel>[];
        for (final id in p.songIds) {
          final s = songMap[id];
          if (s != null) pSongs.add(s);
        }
        if (pSongs.isNotEmpty) await playSongList(pSongs, 0);
      }
      return;
    }
    if (mediaId.startsWith('album_')) {
      final albumName = mediaId.substring('album_'.length);
      final alSongs = cachedSongs.where((s) => s.album == albumName).toList();
      if (alSongs.isNotEmpty) await playSongList(alSongs, 0);
      return;
    }
    if (mediaId.startsWith('artist_')) {
      final artistName = mediaId.substring('artist_'.length);
      final aSongs = cachedSongs.where((s) => s.artist == artistName).toList();
      if (aSongs.isNotEmpty) await playSongList(aSongs, 0);
      return;
    }

    final targetIdx = cachedSongs.indexWhere((s) => s.id == mediaId);
    if (targetIdx >= 0) {
      await playSongList(cachedSongs, targetIdx);
    }
  }

  @override
  Future<List<MediaItem>> search(String query, [Map<String, dynamic>? extras]) async {
    if (query.trim().isEmpty) return [];
    final q = query.toLowerCase().trim();
    final cachedSongs = _cacheService.getCachedSongs();
    final results = cachedSongs.where((s) =>
        s.title.toLowerCase().contains(q) ||
        s.artist.toLowerCase().contains(q) ||
        s.album.toLowerCase().contains(q)).toList();
    return results.map((s) => _songToMediaItem(s)).toList();
  }

  @override
  Future<void> playFromSearch(String query, [Map<String, dynamic>? extras]) async {
    final results = await search(query, extras);
    if (results.isNotEmpty) {
      await playFromMediaId(results.first.id);
    }
  }
}
