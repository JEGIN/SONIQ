import 'package:flutter_test/flutter_test.dart';
import 'package:soniq/core/models/song_model.dart';
import 'package:soniq/features/library/controllers/library_controller.dart';

void main() {
  group('Library Sorting Tests', () {
    final songs = [
      SongModel(
        id: '1',
        title: 'Zebra',
        artist: 'The Beatles',
        album: 'Album A',
        durationMs: 300000,
        dataPath: '/path/zebra.mp3',
        albumArtUri: '1',
        dateAdded: 1000,
        sizeBytes: 1000,
        fileExtension: 'mp3',
      ),
      SongModel(
        id: '2',
        title: 'apple',
        artist: 'Adele',
        album: 'Album B',
        durationMs: 120000,
        dataPath: '/path/apple.mp3',
        albumArtUri: '2',
        dateAdded: 3000,
        sizeBytes: 2000,
        fileExtension: 'mp3',
      ),
      SongModel(
        id: '3',
        title: 'Moon',
        artist: '<unknown>',
        album: 'Album C',
        durationMs: 240000,
        dataPath: '/path/moon.mp3',
        albumArtUri: '3',
        dateAdded: 2000,
        sizeBytes: 3000,
        fileExtension: 'mp3',
      ),
    ];

    test('Title A to Z case-insensitive', () {
      final list = List<SongModel>.from(songs);
      list.sort((a, b) => a.title.trim().toLowerCase().compareTo(b.title.trim().toLowerCase()));
      expect(list.map((s) => s.title).toList(), ['apple', 'Moon', 'Zebra']);
    });

    test('Title Z to A case-insensitive', () {
      final list = List<SongModel>.from(songs);
      list.sort((a, b) => b.title.trim().toLowerCase().compareTo(a.title.trim().toLowerCase()));
      expect(list.map((s) => s.title).toList(), ['Zebra', 'Moon', 'apple']);
    });

    test('Artist A to Z handles unknown artist gracefully', () {
      final list = List<SongModel>.from(songs);
      list.sort((a, b) {
        final aUnknown = a.artist.isEmpty || a.artist.toLowerCase().contains('unknown');
        final bUnknown = b.artist.isEmpty || b.artist.toLowerCase().contains('unknown');
        final aArtist = aUnknown ? 'zzz' : a.artist.trim().toLowerCase();
        final bArtist = bUnknown ? 'zzz' : b.artist.trim().toLowerCase();
        return aArtist.compareTo(bArtist);
      });
      expect(list.map((s) => s.artist).toList(), ['Adele', 'The Beatles', '<unknown>']);
    });

    test('Recently Added puts highest timestamp first', () {
      final list = List<SongModel>.from(songs);
      list.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
      expect(list.map((s) => s.id).toList(), ['2', '3', '1']);
    });

    test('Duration Shortest First puts lowest durationMs first', () {
      final list = List<SongModel>.from(songs);
      list.sort((a, b) => a.durationMs.compareTo(b.durationMs));
      expect(list.map((s) => s.durationMs).toList(), [120000, 240000, 300000]);
    });
  });

  group('Sort Option Labels and Subtitles', () {
    test('All 8 options have defined labels and subtitles', () {
      expect(SongSortOption.values.length, 8);
      for (final opt in SongSortOption.values) {
        expect(opt.label.isNotEmpty, true);
        expect(opt.subtitle.isNotEmpty, true);
      }
    });
  });
}
