import 'dart:async';
import 'dart:math';
import 'package:just_audio/just_audio.dart';
import '../database/song_cache_service.dart';
import '../models/playback_event_model.dart';
import '../models/song_model.dart';

class PlaybackTrackerService {
  static final PlaybackTrackerService _instance = PlaybackTrackerService._internal();
  factory PlaybackTrackerService() => _instance;
  PlaybackTrackerService._internal();

  final SongCacheService _cacheService = SongCacheService();

  // Active tracking state
  SongModel? _activeSong;
  String _activeSource = 'all_songs';
  String? _activePlaylistId;
  String _activeSessionId = '';
  int _sessionLastActivityMs = 0;
  String _activeOutputProfile = 'speaker';

  int _eventStartTimeMs = 0;
  int _lastPositionMs = 0;
  int _accumulatedListenedMs = 0;
  bool _isPlaying = false;
  bool _naturalCompletion = false;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _stateSub;

  SongModel? get activeSong => _activeSong;
  int get currentListenedMs => _accumulatedListenedMs;
  String get activeSessionId => _activeSessionId;

  void initialize(AudioPlayer player) {
    _positionSub?.cancel();
    _stateSub?.cancel();

    _positionSub = player.positionStream.listen(_onPositionChanged);
    _stateSub = player.playerStateStream.listen(_onPlayerStateChanged);
    _ensureSessionActive();
  }

  void _ensureSessionActive() {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Reset session if idle for more than 30 minutes
    if (_activeSessionId.isEmpty || (now - _sessionLastActivityMs > 30 * 60 * 1000)) {
      _activeSessionId = 'sess_${now}_${Random().nextInt(9999)}';
    }
    _sessionLastActivityMs = now;
  }

  void setOutputProfile(String profile) {
    _activeOutputProfile = profile;
  }

  /// Called whenever a track begins playing or is selected in queue
  Future<void> onTrackStarted({
    required SongModel song,
    String source = 'all_songs',
    String? playlistId,
    String? outputProfile,
  }) async {
    // 1. Finalize any previous track's active event
    if (_activeSong != null) {
      await finalizeActiveEvent(isSkipped: !_naturalCompletion);
    }

    _ensureSessionActive();

    _activeSong = song;
    _activeSource = source;
    _activePlaylistId = playlistId;
    if (outputProfile != null) {
      _activeOutputProfile = outputProfile;
    }

    _eventStartTimeMs = DateTime.now().millisecondsSinceEpoch;
    _lastPositionMs = 0;
    _accumulatedListenedMs = 0;
    _naturalCompletion = false;
  }

  void _onPositionChanged(Duration position) {
    if (_activeSong == null) return;

    final currentPosMs = position.inMilliseconds;

    if (_isPlaying) {
      final delta = currentPosMs - _lastPositionMs;
      // Normal playback advancement (1 to 1500 ms)
      if (delta > 0 && delta <= 1500) {
        _accumulatedListenedMs += delta;
      }
      // If delta > 1500ms, user sought forward; do NOT count skipped time
      // If delta < 0, user sought backward; reposition tracking marker
    }

    _lastPositionMs = currentPosMs;
    _sessionLastActivityMs = DateTime.now().millisecondsSinceEpoch;
  }

  void _onPlayerStateChanged(PlayerState state) {
    _isPlaying = state.playing;

    if (state.processingState == ProcessingState.completed) {
      _naturalCompletion = true;
    }
  }

  /// Finalizes and records the currently active playback event into local storage
  Future<PlaybackEventModel?> finalizeActiveEvent({bool isSkipped = false}) async {
    final song = _activeSong;
    if (song == null) return null;

    final endTimeMs = DateTime.now().millisecondsSinceEpoch;
    final trackDurMs = song.durationMs > 0 ? song.durationMs : 1;

    // Check privacy setting
    if (!_cacheService.isAnalyticsTrackingEnabled()) {
      _resetState();
      return null;
    }

    // Determine completion percentage
    final completionPercentage = (_accumulatedListenedMs / trackDurMs).clamp(0.0, 1.0);

    // Play qualification definition
    // Rule: At least 30s of actual listening, or 50% for tracks shorter than 60s
    final thresholdSec = _cacheService.getPlayCountThresholdSeconds();
    final thresholdMs = thresholdSec * 1000;
    bool isQualified = false;

    if (trackDurMs < 60000) {
      isQualified = _accumulatedListenedMs >= (trackDurMs * 0.50).round();
    } else {
      isQualified = _accumulatedListenedMs >= thresholdMs;
    }

    // Determine if skipped
    // A track is skipped if user navigated away before completing at least 90% of duration
    final actuallySkipped = isSkipped && !_naturalCompletion && completionPercentage < 0.90;
    final skipPosMs = actuallySkipped ? _lastPositionMs : null;

    // Build event
    final event = PlaybackEventModel(
      id: 'evt_${_eventStartTimeMs}_${Random().nextInt(99999)}',
      songId: song.id,
      songTitle: song.title,
      artistId: song.artist,
      artistName: song.artist,
      albumId: song.album,
      albumName: song.album,
      genre: 'Music',
      trackDurationMs: song.durationMs,
      startTimeMs: _eventStartTimeMs,
      endTimeMs: endTimeMs,
      listenedDurationMs: _accumulatedListenedMs,
      completionPercentage: completionPercentage,
      isQualifiedPlay: isQualified,
      isSkipped: actuallySkipped,
      skipPositionMs: skipPosMs,
      playbackSource: _activeSource,
      playlistId: _activePlaylistId,
      sessionId: _activeSessionId,
      outputProfile: _activeOutputProfile,
    );

    // Save event to local Hive database
    await _cacheService.savePlaybackEvent(event);

    // If qualified play, update the song model's playCount in Hive
    if (isQualified) {
      await _cacheService.recordSongPlayed(song.id);
    }

    _resetState();
    return event;
  }

  void _resetState() {
    _activeSong = null;
    _lastPositionMs = 0;
    _accumulatedListenedMs = 0;
    _naturalCompletion = false;
  }

  void dispose() {
    _positionSub?.cancel();
    _stateSub?.cancel();
  }
}
