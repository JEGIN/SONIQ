import 'package:get/get.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/models/playlist_model.dart';
import '../../../core/models/song_model.dart';
import '../../../core/services/audio_handler.dart';
import '../../../core/database/song_cache_service.dart';
import '../../playlists/controllers/favorites_controller.dart';
import '../views/now_playing_view.dart';

class AudioPlayerController extends GetxController {
  final SoniqAudioHandler audioHandler;
  final SongCacheService cacheService = SongCacheService();

  AudioPlayerController({required this.audioHandler});

  final Rx<SongModel?> currentSong = Rx<SongModel?>(null);
  final RxInt currentIndex = 0.obs;
  final RxBool isPlaying = false.obs;
  final Rx<Duration> position = Duration.zero.obs;
  final Rx<Duration> duration = Duration.zero.obs;
  final Rx<Duration> bufferedPosition = Duration.zero.obs;
  final RxBool isShuffle = false.obs;
  final Rx<LoopMode> loopMode = LoopMode.off.obs;
  final RxDouble playbackSpeed = 1.0.obs;
  final RxList<SongModel> queue = <SongModel>[].obs;
  final RxList<SongModel> playbackHistory = <SongModel>[].obs;
  final RxInt sleepTimerSecondsRemaining = 0.obs;
  final RxInt sleepTimerMinutes = 0.obs;
  final RxBool stopAfterCurrentTrack = false.obs;

  @override
  void onInit() {
    super.onInit();
    _bindAudioHandlerStreams();
  }

  void _bindAudioHandlerStreams() {
    // Sleep timer stream
    audioHandler.sleepTimerRemainingSecStream.listen((sec) {
      sleepTimerSecondsRemaining.value = sec;
      sleepTimerMinutes.value = (sec / 60).ceil();
    });
    // Current song & mediaItem stream
    audioHandler.mediaItem.listen((item) {
      if (item != null) {
        final song = audioHandler.currentSong;
        if (song != null) {
          currentSong.value = song;
          duration.value = Duration(milliseconds: song.durationMs);
        }
      }
      currentIndex.value = audioHandler.currentIndex;
      playbackHistory.assignAll(audioHandler.playbackHistory);
    });

    // Playback state stream (playing, buffering, shuffle, repeat)
    audioHandler.playbackState.listen((state) {
      isPlaying.value = state.playing;
      isShuffle.value = state.shuffleMode == AudioServiceShuffleMode.all;
      position.value = state.position;
      bufferedPosition.value = state.bufferedPosition;
      currentIndex.value = audioHandler.currentIndex;
    });

    // Queue updates from audioHandler
    audioHandler.queue.listen((_) {
      queue.assignAll(audioHandler.currentPlaylist);
      currentIndex.value = audioHandler.currentIndex;
      playbackHistory.assignAll(audioHandler.playbackHistory);
    });

    // Fine-grained position stream from player
    audioHandler.player.positionStream.listen((pos) {
      position.value = pos;
    });

    // Player duration stream
    audioHandler.player.durationStream.listen((dur) {
      if (dur != null) duration.value = dur;
    });

    // Player buffered position stream
    audioHandler.player.bufferedPositionStream.listen((buf) {
      bufferedPosition.value = buf;
    });

    // Loop mode stream
    audioHandler.player.loopModeStream.listen((loop) {
      loopMode.value = loop;
    });

    // Speed stream
    audioHandler.player.speedStream.listen((speed) {
      playbackSpeed.value = speed;
    });
  }

  /// Plays a specific song within a playlist list with optional shuffle specification
  Future<void> playSong(SongModel song, List<SongModel> playlist, {bool? shuffle}) async {
    final index = playlist.indexWhere((s) => s.id == song.id);
    final targetIndex = index >= 0 ? index : 0;
    currentSong.value = song;
    duration.value = Duration(milliseconds: song.durationMs);
    await audioHandler.playSongList(playlist, targetIndex, shuffle: shuffle);
    queue.assignAll(audioHandler.currentPlaylist);
  }

  /// Plays an entire song collection from the beginning (Play All),
  /// or randomizes the sequence with a true random first track (Shuffle All).
  Future<void> playAll(List<SongModel> songs, {bool shuffle = false}) async {
    if (songs.isEmpty) return;
    await audioHandler.playSongList(songs, 0, shuffle: shuffle);
    currentSong.value = audioHandler.currentSong;
    queue.assignAll(audioHandler.currentPlaylist);
  }

  /// Play / Pause toggle
  Future<void> playPause() async {
    if (currentSong.value == null && queue.isNotEmpty) {
      await playSong(queue.first, queue);
      return;
    }
    if (isPlaying.value) {
      await audioHandler.pause();
    } else {
      await audioHandler.play();
    }
  }

  /// Seek to position
  Future<void> seek(Duration target) async {
    await audioHandler.seek(target);
  }

  /// Next track
  Future<void> skipNext() async {
    await audioHandler.skipToNext();
    currentSong.value = audioHandler.currentSong;
  }

  /// Previous track
  Future<void> skipPrevious() async {
    await audioHandler.skipToPrevious();
    currentSong.value = audioHandler.currentSong;
  }

  /// Shuffle toggle (Synchronized across UI, handler, and notification)
  Future<void> toggleShuffle() async {
    final nextMode = !isShuffle.value;
    await audioHandler.setShuffleMode(
      nextMode ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
    );
    isShuffle.value = audioHandler.isShuffle;
    queue.assignAll(audioHandler.currentPlaylist);
  }

  /// Cycle Repeat: Off -> All -> One -> Off
  Future<void> cycleRepeatMode() async {
    switch (loopMode.value) {
      case LoopMode.off:
        await audioHandler.setRepeatMode(AudioServiceRepeatMode.all);
        break;
      case LoopMode.all:
        await audioHandler.setRepeatMode(AudioServiceRepeatMode.one);
        break;
      case LoopMode.one:
        await audioHandler.setRepeatMode(AudioServiceRepeatMode.none);
        break;
    }
  }

  /// Set Playback Speed (0.5x, 0.75x, 1.0x, 1.25x, 1.5x, 2.0x)
  Future<void> setSpeed(double speed) async {
    await audioHandler.setSpeed(speed);
  }

  /// Favorite toggle for current or passed song (delegates to centralized FavoritesController)
  Future<void> toggleFavorite([SongModel? targetSong]) async {
    final song = targetSong ?? currentSong.value;
    if (song == null) return;

    if (Get.isRegistered<FavoritesController>()) {
      await Get.find<FavoritesController>().toggleFavorite(song);
    } else {
      await cacheService.toggleFavorite(song.id);
      song.isFavorite = !song.isFavorite;
      if (currentSong.value?.id == song.id) {
        currentSong.refresh();
      }
    }
  }

  /// Set Sleep Timer in minutes
  void setSleepTimer(int minutes) {
    stopAfterCurrentTrack.value = false;
    audioHandler.setStopAfterCurrentTrack(false);
    audioHandler.startSleepTimer(minutes);
  }

  /// Stop playback immediately after current song completes
  void setStopAfterCurrentTrack(bool enable) {
    stopAfterCurrentTrack.value = enable;
    audioHandler.setStopAfterCurrentTrack(enable);
    if (enable) {
      audioHandler.cancelSleepTimer();
    }
  }

  /// Cancel Sleep Timer
  void cancelSleepTimer() {
    stopAfterCurrentTrack.value = false;
    audioHandler.setStopAfterCurrentTrack(false);
    audioHandler.cancelSleepTimer();
  }

  // ==========================================
  // SMART QUEUE MANAGEMENT METHODS
  // ==========================================

  /// Reorder items in the queue (Drag & Drop)
  void reorderQueue(int oldIndex, int newIndex) {
    audioHandler.reorderQueue(oldIndex, newIndex);
    queue.assignAll(audioHandler.currentPlaylist);
    currentIndex.value = audioHandler.currentIndex;
    currentSong.value = audioHandler.currentSong;
  }

  /// Insert song immediately next in queue
  void playNext(SongModel song) {
    audioHandler.playNext(song);
    queue.assignAll(audioHandler.currentPlaylist);
  }

  /// Add song to the end of the queue
  void addToQueue(SongModel song) {
    audioHandler.addToQueue(song);
    queue.assignAll(audioHandler.currentPlaylist);
  }

  /// Add multiple songs (e.g. from an album or artist) to the queue
  void addMultipleToQueue(List<SongModel> songs, {bool playNext = false}) {
    audioHandler.addMultipleToQueue(songs, playNext: playNext);
    queue.assignAll(audioHandler.currentPlaylist);
  }

  /// Add all songs from an album to the queue
  void addAlbumToQueue(String albumName, {bool playNext = false}) {
    audioHandler.addAlbumToQueue(albumName, playNext: playNext);
    queue.assignAll(audioHandler.currentPlaylist);
  }

  /// Add all songs from an artist to the queue
  void addArtistToQueue(String artistName, {bool playNext = false}) {
    audioHandler.addArtistToQueue(artistName, playNext: playNext);
    queue.assignAll(audioHandler.currentPlaylist);
  }

  /// Remove song from queue by index (returns removed song for Undo)
  SongModel? removeFromQueue(int index) {
    final removed = audioHandler.removeFromQueue(index);
    queue.assignAll(audioHandler.currentPlaylist);
    currentIndex.value = audioHandler.currentIndex;
    currentSong.value = audioHandler.currentSong;
    return removed;
  }

  /// Restore removed song back to the queue (Undo action)
  void undoRemove(int index, SongModel song) {
    audioHandler.insertIntoQueue(index, song);
    queue.assignAll(audioHandler.currentPlaylist);
    currentIndex.value = audioHandler.currentIndex;
    currentSong.value = audioHandler.currentSong;
  }

  /// Clear upcoming queue while keeping currently playing song
  void clearUpcomingQueue() {
    audioHandler.clearUpcomingQueue();
    queue.assignAll(audioHandler.currentPlaylist);
    currentIndex.value = audioHandler.currentIndex;
  }

  /// Move queue item up or down (accessible alternative to drag)
  void moveQueueItem(int index, bool up) {
    if (up) {
      audioHandler.moveQueueItemUp(index);
    } else {
      audioHandler.moveQueueItemDown(index);
    }
    queue.assignAll(audioHandler.currentPlaylist);
    currentIndex.value = audioHandler.currentIndex;
  }

  /// Save current playback queue as a new custom playlist
  Future<bool> saveQueueAsPlaylist(String playlistName) async {
    if (queue.isEmpty || playlistName.trim().isEmpty) return false;
    final playlist = PlaylistModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: playlistName.trim(),
      songIds: queue.map((s) => s.id).toList(),
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await cacheService.savePlaylist(playlist);
    return true;
  }

  /// Open full-screen Now Playing bottom sheet / route
  void openNowPlaying() {
    if (currentSong.value == null) return;
    Get.to(
      () => const NowPlayingView(),
      transition: Transition.downToUp,
      duration: const Duration(milliseconds: 300),
    );
  }
}
