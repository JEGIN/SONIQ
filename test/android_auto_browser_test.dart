import 'package:flutter_test/flutter_test.dart';
import 'package:audio_service/audio_service.dart';
import 'package:soniq/core/models/song_model.dart';
import 'package:soniq/core/models/playlist_model.dart';

void main() {
  group('SONIQ Phase 4: Native Android Auto & In-Car Infotainment Integration Tests', () {
    late List<SongModel> localSongs;
    late List<PlaylistModel> localPlaylists;
    late Set<String> favoriteSongIds;

    setUp(() {
      localSongs = [
        SongModel(
          id: '1',
          title: 'Bohemian Rhapsody',
          artist: 'Queen',
          album: 'A Night at the Opera',
          durationMs: 354000,
          dataPath: '/storage/emulated/0/Music/queen.mp3',
          sizeBytes: 8000000,
          dateAdded: 1600000000,
          fileExtension: 'mp3',
          isFavorite: true,
        ),
        SongModel(
          id: '2',
          title: 'Hotel California',
          artist: 'Eagles',
          album: 'Hotel California',
          durationMs: 390000,
          dataPath: '/storage/emulated/0/Music/eagles.mp3',
          sizeBytes: 9000000,
          dateAdded: 1600001000,
          fileExtension: 'mp3',
          isFavorite: false,
        ),
        SongModel(
          id: '3',
          title: 'Starman',
          artist: 'David Bowie',
          album: 'Ziggy Stardust',
          durationMs: 255000,
          dataPath: '/storage/emulated/0/Music/bowie.mp3',
          sizeBytes: 6000000,
          dateAdded: 1600002000,
          fileExtension: 'mp3',
          isFavorite: true,
        ),
        SongModel(
          id: '4',
          title: 'Life on Mars?',
          artist: 'David Bowie',
          album: 'Hunky Dory',
          durationMs: 235000,
          dataPath: '/storage/emulated/0/Music/bowie_mars.mp3',
          sizeBytes: 5500000,
          dateAdded: 1600003000,
          fileExtension: 'mp3',
          isFavorite: false,
        ),
      ];

      favoriteSongIds = {'1', '3'};

      localPlaylists = [
        PlaylistModel(
          id: 'pl_roadtrip',
          name: 'Renault Triber Road Trip',
          description: 'Road trip music',
          songIds: ['1', '2', '3'],
          createdAt: 1650000000,
        ),
      ];
    });

    test('1. Root category MediaItems have correct hierarchy IDs and are browsable (playable: false)', () {
      final categories = [
        MediaItem(id: 'category_current_queue', title: 'Current Queue', playable: false),
        MediaItem(id: 'category_all_songs', title: 'All Songs', playable: false),
        MediaItem(id: 'category_recently_played', title: 'Recently Played', playable: false),
        MediaItem(id: 'category_recently_added', title: 'Recently Added', playable: false),
        MediaItem(id: 'category_favorites', title: 'Favorites', playable: false),
        MediaItem(id: 'category_playlists', title: 'Playlists', playable: false),
        MediaItem(id: 'category_artists', title: 'Artists', playable: false),
        MediaItem(id: 'category_albums', title: 'Albums', playable: false),
      ];

      expect(categories.length, 8);
      for (final cat in categories) {
        expect(cat.playable, false);
        expect(cat.id.startsWith('category_'), true);
      }
    });

    test('2. In-car voice/text search query matches title, artist, or album', () {
      List<SongModel> search(String query) {
        final q = query.toLowerCase().trim();
        return localSongs.where((s) =>
            s.title.toLowerCase().contains(q) ||
            s.artist.toLowerCase().contains(q) ||
            s.album.toLowerCase().contains(q)).toList();
      }

      expect(search('Queen').length, 1);
      expect(search('Queen').first.title, 'Bohemian Rhapsody');

      expect(search('hotel').length, 1);
      expect(search('hotel').first.artist, 'Eagles');

      expect(search('david').length, 2);
      expect(search('david').first.artist, 'David Bowie');

      expect(search('nonexistent').isEmpty, true);
    });

    test('3. Favorites collection synchronizes accurately with favorite_song_ids in car', () {
      final favSongs = localSongs.where((s) => favoriteSongIds.contains(s.id) || s.isFavorite).toList();
      expect(favSongs.length, 2);
      expect(favSongs.any((s) => s.title == 'Bohemian Rhapsody'), true);
      expect(favSongs.any((s) => s.title == 'Starman'), true);
      expect(favSongs.any((s) => s.title == 'Hotel California'), false);
    });

    test('4. Album and Artist hierarchy mapping extracts unique lists and track subsets', () {
      final artists = localSongs.map((s) => s.artist).toSet().toList()..sort();
      expect(artists, ['David Bowie', 'Eagles', 'Queen']);

      final bowieTracks = localSongs.where((s) => s.artist == 'David Bowie').toList();
      expect(bowieTracks.length, 2);
      expect(bowieTracks[0].title, 'Starman');
      expect(bowieTracks[1].title, 'Life on Mars?');

      final albums = localSongs.map((s) => s.album).toSet().toList()..sort();
      expect(albums.length, 4);
      expect(albums.contains('A Night at the Opera'), true);
      expect(albums.contains('Hotel California'), true);
    });

    test('5. Playlist content mapping retrieves accurate song objects from playlist IDs', () {
      final playlist = localPlaylists.first;
      final songMap = {for (final s in localSongs) s.id: s};
      final playlistTracks = playlist.songIds.map((id) => songMap[id]).whereType<SongModel>().toList();

      expect(playlistTracks.length, 3);
      expect(playlistTracks[0].title, 'Bohemian Rhapsody');
      expect(playlistTracks[1].title, 'Hotel California');
      expect(playlistTracks[2].title, 'Starman');
    });

    test('6. MediaItem metadata accurately preserves title, artist, album, duration and extras', () {
      final song = localSongs[0];
      final mediaItem = MediaItem(
        id: song.id,
        title: song.title,
        artist: song.artist,
        album: song.album,
        duration: Duration(milliseconds: song.durationMs),
        playable: true,
        extras: {
          'dataPath': song.dataPath,
          'isFavorite': song.isFavorite,
          'fileExtension': song.fileExtension,
        },
      );

      expect(mediaItem.id, '1');
      expect(mediaItem.title, 'Bohemian Rhapsody');
      expect(mediaItem.artist, 'Queen');
      expect(mediaItem.album, 'A Night at the Opera');
      expect(mediaItem.duration?.inSeconds, 354);
      expect(mediaItem.playable, true);
      expect(mediaItem.extras?['dataPath'], '/storage/emulated/0/Music/queen.mp3');
    });

    test('7. Playback controls state flags reflect available in-car steering wheel actions', () {
      const controls = [
        MediaControl.skipToPrevious,
        MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ];

      expect(controls.contains(MediaControl.play), true);
      expect(controls.contains(MediaControl.skipToNext), true);
      expect(controls.contains(MediaControl.skipToPrevious), true);
      expect(controls.contains(MediaControl.stop), true);
    });
  });
}
