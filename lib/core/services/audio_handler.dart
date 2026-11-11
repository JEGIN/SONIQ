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
import 'playback_tracker_service.dart';

Future<SoniqAudioHandler> initAudioHandler() async {
  return await AudioService.init(
    builder: () => SoniqAudioHandler(),
    config: AudioServiceConfig(
      androidNotificationChannelId: 'com.soniq.soniq.channel.audio',
      androidNotificationChannelName: 'SONIQ Playback',
      androidNotificationChannelDescription:
          'SONIQ High Fidelity Offline Music Player',
      androidNotificationIcon: 'mipmap/ic_launcher',
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: false,
      androidShowNotificationBadge: true,
      notificationColor: const Color(0xFFFF2A85),
      androidBrowsableRootExtras: {
        'android.media.browse.CONTENT_STYLE_SUPPORTED': true,
        'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT': 1,
        'android.media.browse.CONTENT_STYLE_PLAYABLE_HINT': 1,
        'android.auto.media.CONTENT_STYLE_SUPPORTED': true,
        'android.auto.media.CONTENT_STYLE_BROWSABLE_HINT': 1,
        'android.auto.media.CONTENT_STYLE_PLAYABLE_HINT': 1,
      },
    ),
  );
}

enum PlaybackIntent {
  /// The user explicitly commanded playback (play button, selecting a song, etc.).
  playing,

  /// The user explicitly commanded pause (in-app, notification, lockscreen, Android Auto, headset).
  manualPause,

  /// The user explicitly stopped playback.
  manualStop,

  /// Playback was actively running, but was temporarily interrupted (phone call, navigation prompt, external app focus loss).
  interrupted,
}

class SoniqAudioHandler extends BaseAudioHandler {
  final AudioPlayer _player = AudioPlayer(
    handleInterruptions: false,
  );
  final SongCacheService _cacheService = SongCacheService();
  final ArtworkCacheService _artworkService = ArtworkCacheService();

  List<SongModel> _originalPlaylist = [];
  List<SongModel> _effectivePlaylist = [];
  int _currentIndex = -1;
  final List<SongModel> _playbackHistory = [];
  bool _isShuffle = false;
  bool _stopAfterCurrentTrack = false;
  String _currentPlaybackSource = 'all_songs';
  String? _currentPlaybackSourceId;
  String? _lastOutputDevice;
  String? _crossfadeFadingSongId;

  // Authoritative Playback Intent State Machine & Revision Tracking
  PlaybackIntent _playbackIntent = PlaybackIntent.manualPause;
  int _intentRevision = 0;
  int _interruptedRevision = -1;
  bool _isDucked = false;

  PlaybackIntent get playbackIntent => _playbackIntent;
  int get intentRevision => _intentRevision;

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
    _listenToOutputChanges();
    _artworkService.init();
    _hookNativeDspSession();
    _initPersistence();
    PlaybackTrackerService().initialize(_player);
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

    // Handle headphone unplug or Bluetooth disconnect (Becoming Noisy)
    session.becomingNoisyEventStream.listen((_) {
      debugPrint('SONIQ: Becoming noisy event received (headset unplugged / Bluetooth disconnected).');
      _playbackIntent = PlaybackIntent.manualPause;
      _interruptedRevision = -1;
      _intentRevision++;
      pause();
    });

    // Authoritative Audio Interruption & Focus Change Handler
    session.interruptionEventStream.listen((event) async {
      debugPrint(
        'SONIQ Focus Event: begin=${event.begin}, type=${event.type}, '
        'intent=$_playbackIntent, rev=$_intentRevision, intRev=$_interruptedRevision',
      );

      if (event.begin) {
        // --- INTERRUPTION STARTED ---
        switch (event.type) {
          case AudioInterruptionType.duck:
            if (_player.playing && _playbackIntent == PlaybackIntent.playing) {
              _isDucked = true;
              await _player.setVolume(0.25);
            }
            break;

          case AudioInterruptionType.pause:
            // Transient focus loss (phone call, Instagram reel, YouTube video, etc.)
            if (_playbackIntent == PlaybackIntent.playing && _player.playing) {
              _playbackIntent = PlaybackIntent.interrupted;
              _interruptedRevision = ++_intentRevision;
              await _player.pause();
              _broadcastPlaybackState();
              debugPrint('SONIQ: Playback interrupted. Will auto-resume when interruption ends.');
            } else {
              // Was ALREADY manually paused or stopped. PRESERVE user intent!
              debugPrint('SONIQ: Interruption occurred while already paused/stopped. Preserving manual pause.');
              if (_player.playing) {
                await _player.pause();
                _broadcastPlaybackState();
              }
            }
            break;

          case AudioInterruptionType.unknown:
            // Permanent focus loss (e.g. another music player took exclusive audio)
            _playbackIntent = PlaybackIntent.manualPause;
            _interruptedRevision = -1;
            _intentRevision++;
            await _player.pause();
            _broadcastPlaybackState();
            debugPrint('SONIQ: Permanent audio focus loss. Transitioned to manualPause.');
            break;
        }
      } else {
        // --- INTERRUPTION ENDED ---
        switch (event.type) {
          case AudioInterruptionType.duck:
            if (_isDucked) {
              _isDucked = false;
              await _player.setVolume(1.0);
            }
            break;

          case AudioInterruptionType.pause:
            // Transient focus returned (phone call ended, Instagram closed, YouTube stopped)
            final currentRev = _intentRevision;
            if (_playbackIntent == PlaybackIntent.interrupted &&
                currentRev == _interruptedRevision &&
                currentSong != null) {
              _playbackIntent = PlaybackIntent.playing;
              _interruptedRevision = -1;
              _intentRevision++;
              debugPrint('SONIQ: Auto-resuming playback after genuine transient interruption.');
              final granted = await session.setActive(true);
              if (granted) {
                await _player.play();
                _broadcastPlaybackState();
              } else {
                _playbackIntent = PlaybackIntent.manualPause;
                _broadcastPlaybackState();
              }
            } else {
              // CRITICAL REQUIREMENT: If the user manually paused BEFORE or DURING
              // the interruption, DO NOT AUTO-RESUME. Manual pause is 100% authoritative!
              debugPrint(
                'SONIQ: Audio focus gained, but playbackIntent=$_playbackIntent. '
                'Manual pause is authoritative: REMAINING PAUSED.',
              );
            }
            break;

          case AudioInterruptionType.unknown:
            debugPrint('SONIQ: Permanent focus ended. Remaining paused.');
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
          _playbackIntent = PlaybackIntent.playing;
          _interruptedRevision = -1;
          _intentRevision++;
          _player.seek(Duration.zero);
          _player.play();
          _broadcastPlaybackState();
        } else {
          skipToNext();
        }
      }
    });

    _player.positionStream.listen(_handleCrossfadePosition);
  }

  void _listenToOutputChanges() {
    AudioDspService().deviceStream.listen((device) {
      final previousDevice = _lastOutputDevice;
      _lastOutputDevice = device;
      if (previousDevice == null || previousDevice == device) return;

      final autoPlay =
          _cacheService.getSetting(
            'auto_play_on_cast_change',
            defaultValue: false,
          ) ==
          true;
      // ONLY allow route auto-play if user is ALREADY actively in playing intent!
      // NEVER auto-play if user manually paused!
      if (autoPlay && currentSong != null && _playbackIntent == PlaybackIntent.playing) {
        play();
      }
    });
  }

  void _handleCrossfadePosition(Duration position) {
    final enabled =
        _cacheService.getSetting('crossfade_enabled', defaultValue: false) ==
        true;
    final song = currentSong;
    if (!enabled) {
      if (_crossfadeFadingSongId != null) {
        _crossfadeFadingSongId = null;
        _player.setVolume(1.0);
      }
      return;
    }
    if (song == null) return;
    if (_player.loopMode == LoopMode.one || _effectivePlaylist.length < 2) {
      return;
    }
    if (_currentIndex >= _effectivePlaylist.length - 1 &&
        _player.loopMode != LoopMode.all) {
      return;
    }
    if (_crossfadeFadingSongId == song.id) return;

    final duration = _player.duration;
    if (duration == null || duration <= const Duration(seconds: 2)) return;
    if (duration - position <= const Duration(milliseconds: 1800) &&
        position > Duration.zero) {
      _crossfadeFadingSongId = song.id;
      _fadeOutCurrentTrack(song.id);
    }
  }

  Future<void> _fadeOutCurrentTrack(String songId) async {
    for (var step = 7; step >= 0; step--) {
      if (currentSong?.id != songId) return;
      final duration = _player.duration;
      if (!_player.playing ||
          (duration != null &&
              duration - _player.position >
                  const Duration(milliseconds: 2200))) {
        await _player.setVolume(1.0);
        _crossfadeFadingSongId = null;
        return;
      }
      await _player.setVolume(step / 7);
      await Future.delayed(const Duration(milliseconds: 130));
    }
  }

  Future<void> _fadeInCurrentTrack(String songId) async {
    for (var step = 1; step <= 8; step++) {
      if (currentSong?.id != songId || !_player.playing) return;
      await _player.setVolume(step / 8);
      await Future.delayed(const Duration(milliseconds: 75));
    }
  }

  void _broadcastPlaybackState() {
    final playing = _player.playing && _playbackIntent == PlaybackIntent.playing;
    final isFav = currentSong?.isFavorite ?? false;

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.custom(
            androidIcon: isFav
                ? 'drawable/ic_favorite_filled'
                : 'drawable/ic_favorite_border',
            label: isFav ? 'Unfavorite' : 'Favorite',
            name: 'toggle_favorite',
          ),
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.setShuffleMode,
          MediaAction.setRepeatMode,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState:
            const {
              ProcessingState.idle: AudioProcessingState.idle,
              ProcessingState.loading: AudioProcessingState.loading,
              ProcessingState.buffering: AudioProcessingState.buffering,
              ProcessingState.ready: AudioProcessingState.ready,
              ProcessingState.completed: AudioProcessingState.completed,
            }[_player.processingState] ??
            AudioProcessingState.idle,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _currentIndex,
        shuffleMode: _isShuffle
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
        repeatMode:
            {
              LoopMode.off: AudioServiceRepeatMode.none,
              LoopMode.one: AudioServiceRepeatMode.one,
              LoopMode.all: AudioServiceRepeatMode.all,
            }[_player.loopMode] ??
            AudioServiceRepeatMode.none,
      ),
    );
  }

  /// Sets queue and plays selected track
  Future<void> playSongList(
    List<SongModel> songs,
    int initialIndex, {
    bool? shuffle,
    String source = 'all_songs',
    String? sourceId,
  }) async {
    if (songs.isEmpty) return;

    _playbackIntent = PlaybackIntent.playing;
    _interruptedRevision = -1;
    _intentRevision++;

    _currentPlaybackSource = source;
    _currentPlaybackSourceId = sourceId;

    if (shuffle != null) {
      _isShuffle = shuffle;
    }

    _originalPlaylist = List.from(songs);
    final clampedIdx = initialIndex.clamp(0, _originalPlaylist.length - 1);
    final targetSong = _originalPlaylist[clampedIdx];

    if (_isShuffle) {
      if (initialIndex == 0 && shuffle == true) {
        // True random shuffle for "Shuffle All"
        final shuffled = List<SongModel>.from(_originalPlaylist)
          ..shuffle(Random());
        _effectivePlaylist = shuffled;
        _currentIndex = 0;
      } else {
        final remaining = List<SongModel>.from(_originalPlaylist)
          ..removeAt(clampedIdx);
        remaining.shuffle(Random());
        _effectivePlaylist = [targetSong, ...remaining];
        _currentIndex = 0;
      }
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

  /// Inserts a song immediately after the currently playing song.
  /// If [allowDuplicate] is false and the track is already in the upcoming queue,
  /// it smoothly relocates the track to play next instead of adding a duplicate.
  void playNext(SongModel song, {bool allowDuplicate = false}) {
    if (_effectivePlaylist.isEmpty) {
      playSongList([song], 0);
      return;
    }

    if (!allowDuplicate) {
      final existingUpcomingIdx = _effectivePlaylist.indexWhere(
        (s) => s.id == song.id,
        _currentIndex + 1,
      );
      if (existingUpcomingIdx > _currentIndex) {
        reorderQueue(existingUpcomingIdx, _currentIndex + 1);
        return;
      }
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

  /// Appends a song to the end of the playback queue.
  /// If [allowDuplicate] is false and the track is already upcoming,
  /// moves the track to the end instead of duplicating it.
  void addToQueue(SongModel song, {bool allowDuplicate = false}) {
    if (_effectivePlaylist.isEmpty) {
      playSongList([song], 0);
      return;
    }

    if (!allowDuplicate) {
      final existingUpcomingIdx = _effectivePlaylist.indexWhere(
        (s) => s.id == song.id,
        _currentIndex + 1,
      );
      if (existingUpcomingIdx > _currentIndex) {
        reorderQueue(existingUpcomingIdx, _effectivePlaylist.length);
        return;
      }
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
    _originalPlaylist.removeWhere((s) => s.id == removed.id);

    if (index == _currentIndex) {
      final wasPlaying =
          _playbackIntent == PlaybackIntent.playing && _player.playing;
      if (_effectivePlaylist.isEmpty) {
        _currentIndex = -1;
        _player.stop();
        mediaItem.add(null);
      } else {
        if (_currentIndex >= _effectivePlaylist.length) {
          _currentIndex = _effectivePlaylist.length - 1;
        }
        _loadAndPlayCurrent(autoPlay: wasPlaying);
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
    if (!_originalPlaylist.any((s) => s.id == song.id)) {
      _originalPlaylist.add(song);
    }

    if (targetIdx <= _currentIndex) {
      _currentIndex += 1;
    }

    _updateQueueItems();
    _broadcastPlaybackState();
    persistCurrentQueue();
  }

  List<SongModel> _lastClearedUpcoming = [];
  List<SongModel> get lastClearedUpcoming => List.unmodifiable(_lastClearedUpcoming);

  /// Clears upcoming songs in the queue while keeping currently playing song at index 0.
  /// Returns the cleared upcoming songs so they can be restored via Undo.
  List<SongModel> clearUpcomingQueue() {
    if (_effectivePlaylist.isEmpty) return [];

    final curr = currentSong;
    List<SongModel> cleared;
    if (_currentIndex < _effectivePlaylist.length - 1) {
      cleared = _effectivePlaylist.sublist(_currentIndex + 1);
    } else {
      cleared = [];
    }
    _lastClearedUpcoming = List.from(cleared);

    if (curr != null) {
      _effectivePlaylist = [curr];
      _currentIndex = 0;
      _originalPlaylist = [curr];
    } else {
      _effectivePlaylist.clear();
      _originalPlaylist.clear();
      _currentIndex = -1;
    }

    _updateQueueItems();
    _broadcastPlaybackState();
    persistCurrentQueue();
    return cleared;
  }

  /// Restores the recently cleared upcoming queue back to its previous position
  void restoreClearedUpcomingQueue() {
    if (_lastClearedUpcoming.isEmpty) return;
    final insertIdx = (_currentIndex + 1).clamp(0, _effectivePlaylist.length);
    _effectivePlaylist.insertAll(insertIdx, _lastClearedUpcoming);
    for (final s in _lastClearedUpcoming) {
      if (!_originalPlaylist.any((o) => o.id == s.id)) {
        _originalPlaylist.add(s);
      }
    }
    _lastClearedUpcoming.clear();
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
      final origIds = _originalPlaylist.map((s) => s.id).toList();
      await _cacheService.setSetting('saved_queue_ids', ids);
      await _cacheService.setSetting('saved_original_queue_ids', origIds);
      await _cacheService.setSetting('saved_queue_index', _currentIndex);
      await _cacheService.setSetting(
        'saved_queue_pos_ms',
        _player.position.inMilliseconds,
      );
      await _cacheService.setSetting('saved_queue_shuffle', _isShuffle);
      await _cacheService.setSetting(
        'saved_repeat_mode',
        _player.loopMode.name,
      );
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
        final restored = savedIds
            .map((id) => songMap[id])
            .whereType<SongModel>()
            .toList();

        if (restored.isNotEmpty) {
          final savedOrigIds = _cacheService.getSetting('saved_original_queue_ids');
          if (savedOrigIds is List && savedOrigIds.isNotEmpty) {
            final orig = savedOrigIds
                .map((id) => songMap[id])
                .whereType<SongModel>()
                .toList();
            _originalPlaylist = orig.isNotEmpty ? orig : List.from(restored);
          } else {
            _originalPlaylist = List.from(restored);
          }
          _effectivePlaylist = List.from(restored);
          final savedIdx = (_cacheService.getSetting(
            'saved_queue_index',
            defaultValue: 0,
          ) as num).toInt();
          _currentIndex = savedIdx.clamp(0, _effectivePlaylist.length - 1);
          final savedShuffle = _cacheService.getSetting(
            'saved_queue_shuffle',
            defaultValue: false,
          ) as bool;
          _isShuffle = savedShuffle;

          final savedRepeat = _cacheService.getSetting(
            'saved_repeat_mode',
            defaultValue: 'off',
          ) as String;
          final loop = LoopMode.values.firstWhere(
            (m) => m.name == savedRepeat,
            orElse: () => LoopMode.off,
          );
          await _player.setLoopMode(loop);

          final savedPosMs = (_cacheService.getSetting(
            'saved_queue_pos_ms',
            defaultValue: 0,
          ) as num).toInt();

          _playbackIntent = PlaybackIntent.manualPause;
          _interruptedRevision = -1;
          _intentRevision++;

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

  Future<void> _loadAndPlayCurrent({bool autoPlay = true}) async {
    if (_currentIndex < 0 || _currentIndex >= _effectivePlaylist.length) return;
    final song = _effectivePlaylist[_currentIndex];

    if (!autoPlay) {
      _playbackIntent = PlaybackIntent.manualPause;
      _interruptedRevision = -1;
      _intentRevision++;

      final immediateItem = _songToMediaItem(song);
      mediaItem.add(immediateItem);
      _broadcastPlaybackState();

      _artworkService.getArtworkUriForSong(song.id).then((artUri) {
        if (artUri != null && currentSong?.id == song.id) {
          mediaItem.add(_songToMediaItem(song, artUriOverride: artUri));
        }
      });

      try {
        if (song.dataPath.startsWith('http://') ||
            song.dataPath.startsWith('https://')) {
          await _player.setUrl(song.dataPath);
        } else {
          final file = File(song.dataPath);
          if (await file.exists()) {
            try {
              await _player.setFilePath(song.dataPath);
            } catch (e) {
              debugPrint('SONIQ: Corrupt audio file: ${song.dataPath} ($e)');
              return;
            }
          }
        }
        await _player.pause();
        _broadcastPlaybackState();
        persistCurrentQueue();
      } catch (e) {
        debugPrint('SONIQ: Error loading audio without autoplay: $e');
      }
      return;
    }

    _playbackIntent = PlaybackIntent.playing;
    _interruptedRevision = -1;
    final currentRev = ++_intentRevision;

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
      final session = await AudioSession.instance;
      final granted = await session.setActive(true);
      if (!granted) {
        debugPrint('SONIQ: Audio focus request denied before play.');
        _playbackIntent = PlaybackIntent.manualPause;
        _broadcastPlaybackState();
        return;
      }

      if (_playbackIntent != PlaybackIntent.playing || currentRev != _intentRevision) {
        debugPrint('SONIQ: Loading track superseded by user manual pause.');
        return;
      }

      final useCrossfade =
          _cacheService.getSetting('crossfade_enabled', defaultValue: false) ==
              true &&
          _effectivePlaylist.length > 1;
      _crossfadeFadingSongId = null;
      await _player.setVolume(useCrossfade ? 0.0 : 1.0);
      if (song.dataPath.startsWith('http://') ||
          song.dataPath.startsWith('https://')) {
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

      if (_playbackIntent != PlaybackIntent.playing || currentRev != _intentRevision) {
        debugPrint('SONIQ: Loading track completed but playback was paused in the interim.');
        return;
      }

      await _player.play();
      if (useCrossfade) _fadeInCurrentTrack(song.id);
      _broadcastPlaybackState();

      final sid = _player.androidAudioSessionId;
      if (sid != null && sid > 0) {
        AudioDspService().attachAudioSession(sid);
      }

      // Track playback start in accurate Listening Analytics
      await PlaybackTrackerService().onTrackStarted(
        song: song,
        source: _currentPlaybackSource,
        playlistId: _currentPlaybackSourceId,
      );

      persistCurrentQueue();
    } catch (e) {
      debugPrint('SONIQ: Error loading audio: $e');
    }
  }

  MediaItem _songToMediaItem(
    SongModel song, {
    Uri? artUriOverride,
    String? idOverride,
    Map<String, dynamic>? additionalExtras,
  }) {
    final artUri =
        artUriOverride ?? _artworkService.getCachedArtworkUri(song.id);

    return MediaItem(
      id: idOverride ?? song.id,
      album: song.album,
      title: song.title,
      artist: song.artist,
      duration: Duration(milliseconds: song.durationMs),
      artUri: artUri,
      playable: true,
      displayTitle: song.title,
      displaySubtitle: song.artist,
      displayDescription: song.album,
      extras: {
        'dataPath': song.dataPath,
        'isFavorite': song.isFavorite,
        'fileExtension': song.fileExtension,
        'originalSongId': song.id,
        'android.media.browse.CONTENT_STYLE_PLAYABLE_HINT': 1,
        'android.auto.media.CONTENT_STYLE_PLAYABLE_HINT': 1,
        ...?additionalExtras,
      },
    );
  }

  SongModel? _findSongByMediaItem(MediaItem item) {
    final originalId = item.extras?['originalSongId'] as String? ?? item.id;
    return _cacheService
            .getCachedSongs()
            .where((s) => s.id == originalId)
            .firstOrNull ??
        _effectivePlaylist.where((s) => s.id == originalId).firstOrNull;
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    final song = _findSongByMediaItem(mediaItem);
    if (song != null) {
      addToQueue(song);
    }
  }

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    final songs = <SongModel>[];
    for (final item in mediaItems) {
      final s = _findSongByMediaItem(item);
      if (s != null) songs.add(s);
    }
    if (songs.isNotEmpty) {
      addMultipleToQueue(songs);
    }
  }

  @override
  Future<void> insertQueueItem(int index, MediaItem mediaItem) async {
    final song = _findSongByMediaItem(mediaItem);
    if (song != null) {
      insertIntoQueue(index, song);
    }
  }

  @override
  Future<void> removeQueueItem(MediaItem mediaItem) async {
    final originalId =
        mediaItem.extras?['originalSongId'] as String? ?? mediaItem.id;
    final idx = _effectivePlaylist.indexWhere((s) => s.id == originalId);
    if (idx >= 0) {
      removeFromQueue(idx);
    }
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    removeFromQueue(index);
  }

  @override
  Future<void> updateQueue(List<MediaItem> queue) async {
    final cachedSongs = _cacheService.getCachedSongs();
    final songMap = {for (var s in cachedSongs) s.id: s};
    final newSongs = <SongModel>[];
    for (final item in queue) {
      final id = item.extras?['originalSongId'] as String? ?? item.id;
      final s =
          songMap[id] ??
          _effectivePlaylist.where((p) => p.id == id).firstOrNull;
      if (s != null) newSongs.add(s);
    }
    if (newSongs.isNotEmpty) {
      _effectivePlaylist = newSongs;
      _updateQueueItems();
      _broadcastPlaybackState();
      persistCurrentQueue();
    }
  }

  @override
  Future<dynamic> customAction(
    String name, [
    Map<String, dynamic>? extras,
  ]) async {
    final cachedSongs = _cacheService.getCachedSongs();
    switch (name) {
      case 'play_all':
        if (cachedSongs.isNotEmpty) {
          await playSongList(cachedSongs, 0, shuffle: false);
        }
        return true;
      case 'shuffle_all':
        if (cachedSongs.isNotEmpty) {
          await playSongList(cachedSongs, 0, shuffle: true);
        }
        return true;
      case 'toggle_favorite':
        final songId = extras?['songId'] as String? ?? currentSong?.id;
        if (songId != null) {
          final s =
              cachedSongs.where((x) => x.id == songId).firstOrNull ??
              currentSong;
          if (s != null) {
            await toggleFavorite(s);
            return true;
          }
        }
        return false;
      case 'play_next':
        final songId = extras?['songId'] as String?;
        if (songId != null) {
          final s = cachedSongs.where((x) => x.id == songId).firstOrNull;
          if (s != null) {
            playNext(s);
            return true;
          }
        }
        return false;
      case 'add_to_queue':
        final songId = extras?['songId'] as String?;
        if (songId != null) {
          final s = cachedSongs.where((x) => x.id == songId).firstOrNull;
          if (s != null) {
            addToQueue(s);
            return true;
          }
        }
        return false;
      default:
        return super.customAction(name, extras);
    }
  }

  /// Toggles favorite status for a song across Hive cache and MediaSession
  Future<void> toggleFavorite(SongModel song) async {
    await _cacheService.toggleFavorite(song.id);
    song.isFavorite = !song.isFavorite;
    if (currentSong?.id == song.id) {
      mediaItem.add(_songToMediaItem(song));
      _broadcastPlaybackState();
    }
  }

  @override
  Future<void> play() async {
    _playbackIntent = PlaybackIntent.playing;
    _interruptedRevision = -1;
    final currentRev = ++_intentRevision;

    final session = await AudioSession.instance;
    final granted = await session.setActive(true);
    if (!granted) {
      debugPrint('SONIQ: Audio focus request denied by Android. Aborting play.');
      _playbackIntent = PlaybackIntent.manualPause;
      _broadcastPlaybackState();
      return;
    }

    if (_playbackIntent != PlaybackIntent.playing || currentRev != _intentRevision) {
      debugPrint('SONIQ: Play superseded by subsequent user command.');
      return;
    }

    await _player.play();
    _broadcastPlaybackState();
  }

  @override
  Future<void> pause() async {
    _playbackIntent = PlaybackIntent.manualPause;
    _interruptedRevision = -1;
    _intentRevision++;

    await _player.pause();
    _broadcastPlaybackState();

    // Release audio focus on manual pause so other apps (Instagram, YouTube, etc.)
    // take audio focus without considering SONIQ an active contender.
    try {
      final session = await AudioSession.instance;
      await session.setActive(false);
    } catch (e) {
      debugPrint('SONIQ: Error releasing audio session on pause: $e');
    }
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    _playbackIntent = PlaybackIntent.manualStop;
    _interruptedRevision = -1;
    _intentRevision++;

    await PlaybackTrackerService().finalizeActiveEvent(isSkipped: false);
    await _player.stop();
    _broadcastPlaybackState();

    try {
      final session = await AudioSession.instance;
      await session.setActive(false);
    } catch (e) {
      debugPrint('SONIQ: Error releasing audio session on stop: $e');
    }

    await super.stop();
  }

  @override
  Future<void> skipToNext() async {
    if (_effectivePlaylist.isEmpty) return;
    await PlaybackTrackerService().finalizeActiveEvent(isSkipped: true);

    // Single song in queue edge-case handling
    if (_effectivePlaylist.length == 1) {
      if (_player.loopMode == LoopMode.all ||
          _player.loopMode == LoopMode.one) {
        _playbackIntent = PlaybackIntent.playing;
        _interruptedRevision = -1;
        final currentRev = ++_intentRevision;
        try {
          final session = await AudioSession.instance;
          final granted = await session.setActive(true);
          if (!granted) {
            _playbackIntent = PlaybackIntent.manualPause;
            _broadcastPlaybackState();
            return;
          }
          if (_playbackIntent != PlaybackIntent.playing ||
              currentRev != _intentRevision) {
            return;
          }
          await _player.seek(Duration.zero);
          await _player.play();
          _broadcastPlaybackState();
        } catch (e) {
          debugPrint('SONIQ: Error in single-song loop replay: $e');
        }
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
          final reshuffled = List<SongModel>.from(_originalPlaylist)
            ..shuffle(Random());
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
      await PlaybackTrackerService().finalizeActiveEvent(isSkipped: true);
      await _player.seek(Duration.zero);
      return;
    }

    await PlaybackTrackerService().finalizeActiveEvent(isSkipped: true);

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
      await PlaybackTrackerService().finalizeActiveEvent(isSkipped: true);
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
    persistCurrentQueue();
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
  final StreamController<int> _sleepTimerSecController =
      StreamController<int>.broadcast();
  Stream<int> get sleepTimerRemainingSecStream =>
      _sleepTimerSecController.stream;
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
  Future<List<MediaItem>> getChildren(
    String parentMediaId, [
    Map<String, dynamic>? options,
  ]) async {
    final cachedSongs = _cacheService.getCachedSongs();
    final fallbackArt = cachedSongs.firstOrNull != null
        ? _artworkService.getCachedArtworkUri(cachedSongs.first.id)
        : null;

    // 1. Root categories for Android Auto / In-Car Infotainment
    if (parentMediaId == AudioService.browsableRootId ||
        parentMediaId == '/' ||
        parentMediaId == 'root' ||
        parentMediaId.isEmpty) {
      final playlists = _cacheService.getPlaylists();
      final favIds = _cacheService.getFavoriteSongIds().toSet();
      final favCount = cachedSongs
          .where((s) => favIds.contains(s.id) || s.isFavorite)
          .length;
      final artists = cachedSongs.map((s) => s.artist).toSet().length;
      final albums = cachedSongs.map((s) => s.album).toSet().length;

      final categories = <MediaItem>[];

      // Current Queue - only displayed when there is an active playback queue
      if (_effectivePlaylist.isNotEmpty) {
        final currentArt = currentSong != null
            ? _artworkService.getCachedArtworkUri(currentSong!.id)
            : fallbackArt;
        categories.add(
          MediaItem(
            id: 'category_current_queue',
            title: 'Current Queue',
            displaySubtitle:
                '${_effectivePlaylist.length} tracks queued • Active playback',
            artUri: currentArt,
            playable: false,
          ),
        );
      }

      categories.addAll([
        MediaItem(
          id: 'category_all_songs',
          title: 'All Songs',
          displaySubtitle: '${cachedSongs.length} tracks • Offline Library',
          artUri: fallbackArt,
          playable: false,
        ),
        MediaItem(
          id: 'category_favorites',
          title: 'Favorites',
          displaySubtitle: '$favCount favorite tracks',
          artUri: fallbackArt,
          playable: false,
        ),
        MediaItem(
          id: 'category_recently_played',
          title: 'Recently Played',
          displaySubtitle: 'Recent listening history',
          artUri: fallbackArt,
          playable: false,
        ),
        MediaItem(
          id: 'category_recently_added',
          title: 'Recently Added',
          displaySubtitle: 'Newest downloads',
          artUri: fallbackArt,
          playable: false,
        ),
        MediaItem(
          id: 'category_playlists',
          title: 'Playlists',
          displaySubtitle: '${playlists.length} playlists',
          artUri: fallbackArt,
          playable: false,
          extras: const {
            'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT': 2,
            'android.auto.media.CONTENT_STYLE_BROWSABLE_HINT': 2,
          },
        ),
        MediaItem(
          id: 'category_artists',
          title: 'Artists',
          displaySubtitle: '$artists artists',
          artUri: fallbackArt,
          playable: false,
          extras: const {
            'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT': 2,
            'android.auto.media.CONTENT_STYLE_BROWSABLE_HINT': 2,
          },
        ),
        MediaItem(
          id: 'category_albums',
          title: 'Albums',
          displaySubtitle: '$albums albums',
          artUri: fallbackArt,
          playable: false,
          extras: const {
            'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT': 2,
            'android.auto.media.CONTENT_STYLE_BROWSABLE_HINT': 2,
          },
        ),
      ]);

      return categories;
    }

    // 2. Current Queue
    if (parentMediaId == 'category_current_queue') {
      return _effectivePlaylist.map((s) => _songToMediaItem(s)).toList();
    }

    // 3. All Songs Container (with top-level Play All and Shuffle All)
    if (parentMediaId == 'category_all_songs') {
      final items = <MediaItem>[];
      if (cachedSongs.isNotEmpty) {
        items.add(
          MediaItem(
            id: 'action_play_all_songs',
            title: '▶  Play All',
            displaySubtitle:
                'Play all ${cachedSongs.length} songs in library order',
            artUri: fallbackArt,
            playable: true,
            extras: const {
              'android.media.browse.CONTENT_STYLE_PLAYABLE_HINT': 1,
              'android.auto.media.CONTENT_STYLE_PLAYABLE_HINT': 1,
            },
          ),
        );
        items.add(
          MediaItem(
            id: 'action_shuffle_all_songs',
            title: '🔀  Shuffle All',
            displaySubtitle: 'Shuffle and play all ${cachedSongs.length} songs',
            artUri: fallbackArt,
            playable: true,
            extras: const {
              'android.media.browse.CONTENT_STYLE_PLAYABLE_HINT': 1,
              'android.auto.media.CONTENT_STYLE_PLAYABLE_HINT': 1,
            },
          ),
        );
      }
      items.addAll(
        cachedSongs.map(
          (s) => _songToMediaItem(s, idOverride: 'all_song_${s.id}'),
        ),
      );
      return items;
    }

    // 4. Favorites Container
    if (parentMediaId == 'category_favorites') {
      final favIds = _cacheService.getFavoriteSongIds().toSet();
      final favs = cachedSongs
          .where((s) => favIds.contains(s.id) || s.isFavorite)
          .toList();
      final items = <MediaItem>[];
      if (favs.isNotEmpty) {
        final favArt = _artworkService.getCachedArtworkUri(favs.first.id);
        items.add(
          MediaItem(
            id: 'action_play_all_favorites',
            title: '▶  Play All Favorites',
            displaySubtitle: 'Play all ${favs.length} favorite tracks',
            artUri: favArt,
            playable: true,
            extras: const {
              'android.media.browse.CONTENT_STYLE_PLAYABLE_HINT': 1,
              'android.auto.media.CONTENT_STYLE_PLAYABLE_HINT': 1,
            },
          ),
        );
        items.add(
          MediaItem(
            id: 'action_shuffle_all_favorites',
            title: '🔀  Shuffle Favorites',
            displaySubtitle: 'Shuffle ${favs.length} favorite tracks',
            artUri: favArt,
            playable: true,
            extras: const {
              'android.media.browse.CONTENT_STYLE_PLAYABLE_HINT': 1,
              'android.auto.media.CONTENT_STYLE_PLAYABLE_HINT': 1,
            },
          ),
        );
        items.addAll(
          favs.map((s) => _songToMediaItem(s, idOverride: 'fav_song_${s.id}')),
        );
      }
      return items;
    }

    // 5. Recently Played Container
    if (parentMediaId == 'category_recently_played') {
      final recentIds = _cacheService.getRecentlyPlayedSongIds(limit: 50);
      final songMap = {for (var s in cachedSongs) s.id: s};
      final recentSongs = <SongModel>[];
      for (final id in recentIds) {
        final s = songMap[id];
        if (s != null) recentSongs.add(s);
      }
      final items = <MediaItem>[];
      if (recentSongs.isNotEmpty) {
        final rArt = _artworkService.getCachedArtworkUri(recentSongs.first.id);
        items.add(
          MediaItem(
            id: 'action_play_all_recent',
            title: '▶  Play All Recents',
            displaySubtitle:
                'Play ${recentSongs.length} recently played tracks',
            artUri: rArt,
            playable: true,
            extras: const {
              'android.media.browse.CONTENT_STYLE_PLAYABLE_HINT': 1,
              'android.auto.media.CONTENT_STYLE_PLAYABLE_HINT': 1,
            },
          ),
        );
        items.add(
          MediaItem(
            id: 'action_shuffle_all_recent',
            title: '🔀  Shuffle Recents',
            displaySubtitle:
                'Shuffle ${recentSongs.length} recently played tracks',
            artUri: rArt,
            playable: true,
            extras: const {
              'android.media.browse.CONTENT_STYLE_PLAYABLE_HINT': 1,
              'android.auto.media.CONTENT_STYLE_PLAYABLE_HINT': 1,
            },
          ),
        );
        items.addAll(
          recentSongs.map(
            (s) => _songToMediaItem(s, idOverride: 'recent_song_${s.id}'),
          ),
        );
      }
      return items;
    }

    // 6. Recently Added Container
    if (parentMediaId == 'category_recently_added') {
      final sorted = List<SongModel>.from(cachedSongs)
        ..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
      final recentAdded = sorted.take(50).toList();
      final items = <MediaItem>[];
      if (recentAdded.isNotEmpty) {
        final raArt = _artworkService.getCachedArtworkUri(recentAdded.first.id);
        items.add(
          MediaItem(
            id: 'action_play_all_recent_added',
            title: '▶  Play All New Tracks',
            displaySubtitle: 'Play ${recentAdded.length} newest additions',
            artUri: raArt,
            playable: true,
            extras: const {
              'android.media.browse.CONTENT_STYLE_PLAYABLE_HINT': 1,
              'android.auto.media.CONTENT_STYLE_PLAYABLE_HINT': 1,
            },
          ),
        );
        items.add(
          MediaItem(
            id: 'action_shuffle_all_recent_added',
            title: '🔀  Shuffle New Tracks',
            displaySubtitle: 'Shuffle ${recentAdded.length} newest additions',
            artUri: raArt,
            playable: true,
            extras: const {
              'android.media.browse.CONTENT_STYLE_PLAYABLE_HINT': 1,
              'android.auto.media.CONTENT_STYLE_PLAYABLE_HINT': 1,
            },
          ),
        );
        items.addAll(
          recentAdded.map(
            (s) => _songToMediaItem(s, idOverride: 'recent_added_song_${s.id}'),
          ),
        );
      }
      return items;
    }

    // 7. Playlists Top-Level
    if (parentMediaId == 'category_playlists') {
      final playlists = _cacheService.getPlaylists();
      final songMap = {for (var s in cachedSongs) s.id: s};
      return playlists.map((p) {
        Uri? pArt;
        for (final id in p.songIds) {
          final s = songMap[id];
          if (s != null) {
            pArt = _artworkService.getCachedArtworkUri(s.id);
            break;
          }
        }
        return MediaItem(
          id: 'playlist_${p.id}',
          title: p.name,
          displaySubtitle: '${p.songCount} songs',
          artUri: pArt ?? fallbackArt,
          playable: false,
          extras: const {
            'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT': 1,
            'android.auto.media.CONTENT_STYLE_BROWSABLE_HINT': 1,
          },
        );
      }).toList();
    }

    // 7b. Specific Playlist Content
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
        final items = <MediaItem>[];
        if (pSongs.isNotEmpty) {
          final plArt = _artworkService.getCachedArtworkUri(pSongs.first.id);
          items.add(
            MediaItem(
              id: 'action_play_all_playlist_$pId',
              title: '▶  Play Playlist',
              displaySubtitle: 'Play all ${pSongs.length} songs in "${p.name}"',
              artUri: plArt,
              playable: true,
              extras: const {
                'android.media.browse.CONTENT_STYLE_PLAYABLE_HINT': 1,
                'android.auto.media.CONTENT_STYLE_PLAYABLE_HINT': 1,
              },
            ),
          );
          items.add(
            MediaItem(
              id: 'action_shuffle_all_playlist_$pId',
              title: '🔀  Shuffle Playlist',
              displaySubtitle:
                  'Shuffle all ${pSongs.length} songs in "${p.name}"',
              artUri: plArt,
              playable: true,
              extras: const {
                'android.media.browse.CONTENT_STYLE_PLAYABLE_HINT': 1,
                'android.auto.media.CONTENT_STYLE_PLAYABLE_HINT': 1,
              },
            ),
          );
          items.addAll(
            pSongs.map(
              (s) => _songToMediaItem(
                s,
                idOverride: 'playlist_song_$pId:::${s.id}',
              ),
            ),
          );
        }
        return items;
      }
      return [];
    }

    // 8. Artists Top-Level
    if (parentMediaId == 'category_artists') {
      final artistMap = <String, List<SongModel>>{};
      for (final s in cachedSongs) {
        artistMap.putIfAbsent(s.artist, () => []).add(s);
      }
      final sortedArtists = artistMap.keys.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return sortedArtists.map((a) {
        final songs = artistMap[a]!;
        final art = _artworkService.getCachedArtworkUri(songs.first.id);
        return MediaItem(
          id: 'artist_$a',
          title: a,
          displaySubtitle:
              '${songs.length} ${songs.length == 1 ? 'song' : 'songs'}',
          artUri: art ?? fallbackArt,
          playable: false,
          extras: const {
            'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT': 1,
            'android.auto.media.CONTENT_STYLE_BROWSABLE_HINT': 1,
          },
        );
      }).toList();
    }

    // 8b. Specific Artist Tracks
    if (parentMediaId.startsWith('artist_')) {
      final artistName = parentMediaId.substring('artist_'.length);
      final aSongs = cachedSongs.where((s) => s.artist == artistName).toList();
      final items = <MediaItem>[];
      if (aSongs.isNotEmpty) {
        final aArt = _artworkService.getCachedArtworkUri(aSongs.first.id);
        items.add(
          MediaItem(
            id: 'action_play_all_artist_$artistName',
            title: '▶  Play All by $artistName',
            displaySubtitle: 'Play all ${aSongs.length} songs',
            artUri: aArt,
            playable: true,
            extras: const {
              'android.media.browse.CONTENT_STYLE_PLAYABLE_HINT': 1,
              'android.auto.media.CONTENT_STYLE_PLAYABLE_HINT': 1,
            },
          ),
        );
        items.add(
          MediaItem(
            id: 'action_shuffle_all_artist_$artistName',
            title: '🔀  Shuffle Artist',
            displaySubtitle:
                'Shuffle all ${aSongs.length} songs by $artistName',
            artUri: aArt,
            playable: true,
            extras: const {
              'android.media.browse.CONTENT_STYLE_PLAYABLE_HINT': 1,
              'android.auto.media.CONTENT_STYLE_PLAYABLE_HINT': 1,
            },
          ),
        );
        items.addAll(
          aSongs.map(
            (s) => _songToMediaItem(
              s,
              idOverride: 'artist_song_$artistName:::${s.id}',
            ),
          ),
        );
      }
      return items;
    }

    // 9. Albums Top-Level
    if (parentMediaId == 'category_albums') {
      final albumMap = <String, List<SongModel>>{};
      for (final s in cachedSongs) {
        albumMap.putIfAbsent(s.album, () => []).add(s);
      }
      final sortedAlbums = albumMap.keys.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return sortedAlbums.map((alb) {
        final songs = albumMap[alb]!;
        final art = _artworkService.getCachedArtworkUri(songs.first.id);
        final artist = songs.first.artist;
        return MediaItem(
          id: 'album_$alb',
          title: alb,
          displaySubtitle: '$artist • ${songs.length} tracks',
          artUri: art ?? fallbackArt,
          playable: false,
          extras: const {
            'android.media.browse.CONTENT_STYLE_BROWSABLE_HINT': 1,
            'android.auto.media.CONTENT_STYLE_BROWSABLE_HINT': 1,
          },
        );
      }).toList();
    }

    // 9b. Specific Album Tracks
    if (parentMediaId.startsWith('album_')) {
      final albumName = parentMediaId.substring('album_'.length);
      final alSongs = cachedSongs.where((s) => s.album == albumName).toList();
      final items = <MediaItem>[];
      if (alSongs.isNotEmpty) {
        final alArt = _artworkService.getCachedArtworkUri(alSongs.first.id);
        items.add(
          MediaItem(
            id: 'action_play_all_album_$albumName',
            title: '▶  Play Album',
            displaySubtitle:
                'Play all ${alSongs.length} tracks in "$albumName"',
            artUri: alArt,
            playable: true,
            extras: const {
              'android.media.browse.CONTENT_STYLE_PLAYABLE_HINT': 1,
              'android.auto.media.CONTENT_STYLE_PLAYABLE_HINT': 1,
            },
          ),
        );
        items.add(
          MediaItem(
            id: 'action_shuffle_all_album_$albumName',
            title: '🔀  Shuffle Album',
            displaySubtitle:
                'Shuffle all ${alSongs.length} tracks in "$albumName"',
            artUri: alArt,
            playable: true,
            extras: const {
              'android.media.browse.CONTENT_STYLE_PLAYABLE_HINT': 1,
              'android.auto.media.CONTENT_STYLE_PLAYABLE_HINT': 1,
            },
          ),
        );
        items.addAll(
          alSongs.map(
            (s) => _songToMediaItem(
              s,
              idOverride: 'album_song_$albumName:::${s.id}',
            ),
          ),
        );
      }
      return items;
    }

    return [];
  }

  @override
  Future<MediaItem?> getMediaItem(String mediaId) async {
    final cachedSongs = _cacheService.getCachedSongs();
    String targetId = mediaId;
    if (targetId.startsWith('all_song_')) {
      targetId = targetId.substring('all_song_'.length);
    } else if (targetId.startsWith('fav_song_')) {
      targetId = targetId.substring('fav_song_'.length);
    } else if (targetId.startsWith('recent_song_')) {
      targetId = targetId.substring('recent_song_'.length);
    } else if (targetId.startsWith('recent_added_song_')) {
      targetId = targetId.substring('recent_added_song_'.length);
    } else if (targetId.contains(':::')) {
      targetId = targetId.split(':::').last;
    }

    for (final s in cachedSongs) {
      if (s.id == targetId) return _songToMediaItem(s);
    }
    return null;
  }

  @override
  Future<void> playFromMediaId(
    String mediaId, [
    Map<String, dynamic>? extras,
  ]) async {
    PlaybackTrackerService().setOutputProfile('car_audio');
    final cachedSongs = _cacheService.getCachedSongs();
    if (cachedSongs.isEmpty) return;

    // A. Direct Play All / Shuffle All Container Actions
    if (mediaId == 'action_play_all_songs' || mediaId == 'category_all_songs') {
      await playSongList(cachedSongs, 0, shuffle: false);
      return;
    }
    if (mediaId == 'action_shuffle_all_songs') {
      await playSongList(cachedSongs, 0, shuffle: true);
      return;
    }

    if (mediaId == 'action_play_all_favorites' ||
        mediaId == 'category_favorites') {
      final favIds = _cacheService.getFavoriteSongIds().toSet();
      final favs = cachedSongs
          .where((s) => favIds.contains(s.id) || s.isFavorite)
          .toList();
      if (favs.isNotEmpty) await playSongList(favs, 0, shuffle: false);
      return;
    }
    if (mediaId == 'action_shuffle_all_favorites') {
      final favIds = _cacheService.getFavoriteSongIds().toSet();
      final favs = cachedSongs
          .where((s) => favIds.contains(s.id) || s.isFavorite)
          .toList();
      if (favs.isNotEmpty) await playSongList(favs, 0, shuffle: true);
      return;
    }

    if (mediaId == 'action_play_all_recent' ||
        mediaId == 'category_recently_played') {
      final recentIds = _cacheService.getRecentlyPlayedSongIds(limit: 50);
      final songMap = {for (var s in cachedSongs) s.id: s};
      final recentSongs = <SongModel>[];
      for (final id in recentIds) {
        final s = songMap[id];
        if (s != null) recentSongs.add(s);
      }
      if (recentSongs.isNotEmpty) {
        await playSongList(recentSongs, 0, shuffle: false);
      }
      return;
    }
    if (mediaId == 'action_shuffle_all_recent') {
      final recentIds = _cacheService.getRecentlyPlayedSongIds(limit: 50);
      final songMap = {for (var s in cachedSongs) s.id: s};
      final recentSongs = <SongModel>[];
      for (final id in recentIds) {
        final s = songMap[id];
        if (s != null) recentSongs.add(s);
      }
      if (recentSongs.isNotEmpty) {
        await playSongList(recentSongs, 0, shuffle: true);
      }
      return;
    }

    if (mediaId == 'action_play_all_recent_added' ||
        mediaId == 'category_recently_added') {
      final sorted = List<SongModel>.from(cachedSongs)
        ..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
      final recentAdded = sorted.take(50).toList();
      if (recentAdded.isNotEmpty) {
        await playSongList(recentAdded, 0, shuffle: false);
      }
      return;
    }
    if (mediaId == 'action_shuffle_all_recent_added') {
      final sorted = List<SongModel>.from(cachedSongs)
        ..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
      final recentAdded = sorted.take(50).toList();
      if (recentAdded.isNotEmpty) {
        await playSongList(recentAdded, 0, shuffle: true);
      }
      return;
    }

    if (mediaId.startsWith('action_play_all_playlist_') ||
        (mediaId.startsWith('playlist_') && !mediaId.contains(':::'))) {
      final pId = mediaId.startsWith('action_play_all_playlist_')
          ? mediaId.substring('action_play_all_playlist_'.length)
          : mediaId.substring('playlist_'.length);
      final playlists = _cacheService.getPlaylists();
      final p = playlists.where((pl) => pl.id == pId).firstOrNull;
      if (p != null) {
        final songMap = {for (var s in cachedSongs) s.id: s};
        final pSongs = <SongModel>[];
        for (final id in p.songIds) {
          final s = songMap[id];
          if (s != null) pSongs.add(s);
        }
        if (pSongs.isNotEmpty) await playSongList(pSongs, 0, shuffle: false);
      }
      return;
    }
    if (mediaId.startsWith('action_shuffle_all_playlist_')) {
      final pId = mediaId.substring('action_shuffle_all_playlist_'.length);
      final playlists = _cacheService.getPlaylists();
      final p = playlists.where((pl) => pl.id == pId).firstOrNull;
      if (p != null) {
        final songMap = {for (var s in cachedSongs) s.id: s};
        final pSongs = <SongModel>[];
        for (final id in p.songIds) {
          final s = songMap[id];
          if (s != null) pSongs.add(s);
        }
        if (pSongs.isNotEmpty) await playSongList(pSongs, 0, shuffle: true);
      }
      return;
    }

    if (mediaId.startsWith('action_play_all_album_') ||
        (mediaId.startsWith('album_') && !mediaId.contains(':::'))) {
      final albumName = mediaId.startsWith('action_play_all_album_')
          ? mediaId.substring('action_play_all_album_'.length)
          : mediaId.substring('album_'.length);
      final alSongs = cachedSongs.where((s) => s.album == albumName).toList();
      if (alSongs.isNotEmpty) await playSongList(alSongs, 0, shuffle: false);
      return;
    }
    if (mediaId.startsWith('action_shuffle_all_album_')) {
      final albumName = mediaId.substring('action_shuffle_all_album_'.length);
      final alSongs = cachedSongs.where((s) => s.album == albumName).toList();
      if (alSongs.isNotEmpty) await playSongList(alSongs, 0, shuffle: true);
      return;
    }

    if (mediaId.startsWith('action_play_all_artist_') ||
        (mediaId.startsWith('artist_') && !mediaId.contains(':::'))) {
      final artistName = mediaId.startsWith('action_play_all_artist_')
          ? mediaId.substring('action_play_all_artist_'.length)
          : mediaId.substring('artist_'.length);
      final aSongs = cachedSongs.where((s) => s.artist == artistName).toList();
      if (aSongs.isNotEmpty) await playSongList(aSongs, 0, shuffle: false);
      return;
    }
    if (mediaId.startsWith('action_shuffle_all_artist_')) {
      final artistName = mediaId.substring('action_shuffle_all_artist_'.length);
      final aSongs = cachedSongs.where((s) => s.artist == artistName).toList();
      if (aSongs.isNotEmpty) await playSongList(aSongs, 0, shuffle: true);
      return;
    }

    // B. Contextual Individual Song Selections
    if (mediaId.startsWith('all_song_')) {
      final songId = mediaId.substring('all_song_'.length);
      final idx = cachedSongs.indexWhere((s) => s.id == songId);
      if (idx >= 0) await playSongList(cachedSongs, idx);
      return;
    }

    if (mediaId.startsWith('fav_song_')) {
      final songId = mediaId.substring('fav_song_'.length);
      final favIds = _cacheService.getFavoriteSongIds().toSet();
      final favs = cachedSongs
          .where((s) => favIds.contains(s.id) || s.isFavorite)
          .toList();
      final idx = favs.indexWhere((s) => s.id == songId);
      if (idx >= 0) await playSongList(favs, idx);
      return;
    }

    if (mediaId.startsWith('recent_song_')) {
      final songId = mediaId.substring('recent_song_'.length);
      final recentIds = _cacheService.getRecentlyPlayedSongIds(limit: 50);
      final songMap = {for (var s in cachedSongs) s.id: s};
      final recentSongs = <SongModel>[];
      for (final id in recentIds) {
        final s = songMap[id];
        if (s != null) recentSongs.add(s);
      }
      final idx = recentSongs.indexWhere((s) => s.id == songId);
      if (idx >= 0) await playSongList(recentSongs, idx);
      return;
    }

    if (mediaId.startsWith('recent_added_song_')) {
      final songId = mediaId.substring('recent_added_song_'.length);
      final sorted = List<SongModel>.from(cachedSongs)
        ..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
      final recentAdded = sorted.take(50).toList();
      final idx = recentAdded.indexWhere((s) => s.id == songId);
      if (idx >= 0) await playSongList(recentAdded, idx);
      return;
    }

    if (mediaId.startsWith('album_song_')) {
      final parts = mediaId.substring('album_song_'.length).split(':::');
      if (parts.length >= 2) {
        final albumName = parts[0];
        final songId = parts[1];
        final alSongs = cachedSongs.where((s) => s.album == albumName).toList();
        final idx = alSongs.indexWhere((s) => s.id == songId);
        if (idx >= 0) {
          await playSongList(alSongs, idx);
          return;
        }
      }
    }

    if (mediaId.startsWith('artist_song_')) {
      final parts = mediaId.substring('artist_song_'.length).split(':::');
      if (parts.length >= 2) {
        final artistName = parts[0];
        final songId = parts[1];
        final aSongs = cachedSongs
            .where((s) => s.artist == artistName)
            .toList();
        final idx = aSongs.indexWhere((s) => s.id == songId);
        if (idx >= 0) {
          await playSongList(aSongs, idx);
          return;
        }
      }
    }

    if (mediaId.startsWith('playlist_song_')) {
      final parts = mediaId.substring('playlist_song_'.length).split(':::');
      if (parts.length >= 2) {
        final pId = parts[0];
        final songId = parts[1];
        final playlists = _cacheService.getPlaylists();
        final p = playlists.where((pl) => pl.id == pId).firstOrNull;
        if (p != null) {
          final songMap = {for (var s in cachedSongs) s.id: s};
          final pSongs = <SongModel>[];
          for (final id in p.songIds) {
            final s = songMap[id];
            if (s != null) pSongs.add(s);
          }
          final idx = pSongs.indexWhere((s) => s.id == songId);
          if (idx >= 0) {
            await playSongList(pSongs, idx);
            return;
          }
        }
      }
    }

    // C. Current Active Queue Item Jump
    final inQueueIdx = _effectivePlaylist.indexWhere((s) => s.id == mediaId);
    if (inQueueIdx >= 0) {
      await skipToQueueItem(inQueueIdx);
      return;
    }

    // D. Direct Song ID fallback
    final targetIdx = cachedSongs.indexWhere((s) => s.id == mediaId);
    if (targetIdx >= 0) {
      await playSongList(cachedSongs, targetIdx);
    }
  }

  @override
  Future<List<MediaItem>> search(
    String query, [
    Map<String, dynamic>? extras,
  ]) async {
    if (query.trim().isEmpty) return [];
    final q = query.toLowerCase().trim();
    final cachedSongs = _cacheService.getCachedSongs();
    final results = cachedSongs
        .where(
          (s) =>
              s.title.toLowerCase().contains(q) ||
              s.artist.toLowerCase().contains(q) ||
              s.album.toLowerCase().contains(q),
        )
        .toList();
    return results.map((s) => _songToMediaItem(s)).toList();
  }

  @override
  Future<void> playFromSearch(
    String query, [
    Map<String, dynamic>? extras,
  ]) async {
    final results = await search(query, extras);
    if (results.isNotEmpty) {
      await playFromMediaId(results.first.id);
    }
  }
}
