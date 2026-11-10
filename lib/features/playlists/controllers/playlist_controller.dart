import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/models/playlist_model.dart';
import '../../../core/models/song_model.dart';
import '../../../core/database/song_cache_service.dart';
import '../../player/controllers/player_controller.dart';
import '../../library/controllers/library_controller.dart';

class PlaylistController extends GetxController {
  final SongCacheService cacheService = SongCacheService();
  final LibraryController libraryController = Get.find<LibraryController>();

  final RxList<PlaylistModel> playlists = <PlaylistModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadPlaylists();
  }

  void loadPlaylists() {
    final list = cacheService.getPlaylists();
    playlists.assignAll(list);
  }

  Future<void> createPlaylist(String name, {String description = ''}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final newPlaylist = PlaylistModel(
      id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
      name: trimmed,
      description: description,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    await cacheService.savePlaylist(newPlaylist);
    playlists.add(newPlaylist);
  }

  Future<void> renamePlaylist(String playlistId, String newName) async {
    final index = playlists.indexWhere((p) => p.id == playlistId);
    if (index >= 0) {
      final pl = playlists[index];
      pl.name = newName.trim();
      await cacheService.savePlaylist(pl);
      playlists.refresh();
    }
  }

  Future<void> deletePlaylist(String playlistId) async {
    await cacheService.deletePlaylist(playlistId);
    playlists.removeWhere((p) => p.id == playlistId);
  }

  Future<void> addSongToPlaylist(String playlistId, SongModel song) async {
    final index = playlists.indexWhere((p) => p.id == playlistId);
    if (index >= 0) {
      final pl = playlists[index];
      if (!pl.songIds.contains(song.id)) {
        pl.songIds.add(song.id);
        pl.coverSongId ??= song.id;
        await cacheService.savePlaylist(pl);
        playlists.refresh();
        Get.snackbar(
          'Added to Playlist',
          '${song.title} added to ${pl.name}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF1B1D26),
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
      }
    }
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final index = playlists.indexWhere((p) => p.id == playlistId);
    if (index >= 0) {
      final pl = playlists[index];
      pl.songIds.remove(songId);
      await cacheService.savePlaylist(pl);
      playlists.refresh();
    }
  }

  Future<void> reorderSongs(String playlistId, int oldIndex, int newIndex) async {
    final index = playlists.indexWhere((p) => p.id == playlistId);
    if (index >= 0) {
      final pl = playlists[index];
      if (newIndex > oldIndex) newIndex -= 1;
      final songId = pl.songIds.removeAt(oldIndex);
      pl.songIds.insert(newIndex, songId);
      await cacheService.savePlaylist(pl);
      playlists.refresh();
    }
  }

  List<SongModel> getSongsForPlaylist(PlaylistModel playlist) {
    final songMap = {for (final s in libraryController.allSongs) s.id: s};
    final List<SongModel> songs = [];
    for (final id in playlist.songIds) {
      if (songMap.containsKey(id)) {
        songs.add(songMap[id]!);
      }
    }
    return songs;
  }

  void playEntirePlaylist(PlaylistModel playlist, {bool shuffle = false}) {
    final songs = getSongsForPlaylist(playlist);
    if (songs.isEmpty) {
      Get.snackbar('Playlist Empty', 'Add some songs to this playlist first.');
      return;
    }
    final playerController = Get.find<AudioPlayerController>();
    playerController.playSong(songs.first, songs, shuffle: shuffle);
  }
}
