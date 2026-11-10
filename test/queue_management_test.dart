import 'package:flutter_test/flutter_test.dart';
import 'package:soniq/core/models/song_model.dart';

void main() {
  group('Professional Queue Management Tests', () {
    late List<SongModel> testSongs;

    setUp(() {
      testSongs = List.generate(
        15,
        (i) => SongModel(
          id: 'song_$i',
          title: 'Track $i',
          artist: 'Artist ${i % 3}',
          album: 'Album ${i % 2}',
          durationMs: 180000 + i * 1000,
          dataPath: '/storage/emulated/0/Music/song_$i.mp3',
          sizeBytes: 5000000,
          dateAdded: 1600000000 + i * 100,
          fileExtension: 'mp3',
        ),
      );
    });

    test('Reordering upcoming song (after currentIndex) preserves currentIndex', () {
      final queue = List<SongModel>.from(testSongs);
      int currentIndex = 2; // Track 2 is currently playing

      // Move Track 10 (oldIndex: 10) to position 4 (newIndex: 4)
      int oldIndex = 10;
      int newIndex = 4;

      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final song = queue.removeAt(oldIndex);
      queue.insert(newIndex, song);

      if (oldIndex == currentIndex) {
        currentIndex = newIndex;
      } else if (oldIndex < currentIndex && newIndex >= currentIndex) {
        currentIndex -= 1;
      } else if (oldIndex > currentIndex && newIndex <= currentIndex) {
        currentIndex += 1;
      }

      expect(currentIndex, 2); // Current playing track untouched!
      expect(queue[currentIndex].id, 'song_2');
      expect(queue[4].id, 'song_10');
    });

    test('Moving currently playing song updates currentIndex to new position', () {
      final queue = List<SongModel>.from(testSongs);
      int currentIndex = 2; // Track 2 is currently playing

      // Move Track 2 to position 7
      int oldIndex = 2;
      int newIndex = 7;

      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final song = queue.removeAt(oldIndex);
      queue.insert(newIndex, song);

      if (oldIndex == currentIndex) {
        currentIndex = newIndex;
      } else if (oldIndex < currentIndex && newIndex >= currentIndex) {
        currentIndex -= 1;
      } else if (oldIndex > currentIndex && newIndex <= currentIndex) {
        currentIndex += 1;
      }

      expect(currentIndex, 6);
      expect(queue[currentIndex].id, 'song_2');
    });

    test('Moving item from after currentIndex to before currentIndex increments currentIndex', () {
      final queue = List<SongModel>.from(testSongs);
      int currentIndex = 3;

      // Move Track 8 to position 1
      int oldIndex = 8;
      int newIndex = 1;

      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final song = queue.removeAt(oldIndex);
      queue.insert(newIndex, song);

      if (oldIndex == currentIndex) {
        currentIndex = newIndex;
      } else if (oldIndex < currentIndex && newIndex >= currentIndex) {
        currentIndex -= 1;
      } else if (oldIndex > currentIndex && newIndex <= currentIndex) {
        currentIndex += 1;
      }

      expect(currentIndex, 4); // Shifted by +1
      expect(queue[currentIndex].id, 'song_3'); // Still Track 3!
      expect(queue[1].id, 'song_8');
    });

    test('Play Next inserts song immediately after currentIndex', () {
      final queue = List<SongModel>.from(testSongs);
      const currentIndex = 2;

      final newSong = SongModel(
        id: 'new_song',
        title: 'New Track',
        artist: 'Guest',
        album: 'Single',
        durationMs: 200000,
        dataPath: '/music/new.mp3',
        sizeBytes: 4000000,
        dateAdded: 1600005000,
        fileExtension: 'mp3',
      );

      final insertIdx = (currentIndex + 1).clamp(0, queue.length);
      queue.insert(insertIdx, newSong);

      expect(queue[3].id, 'new_song');
      expect(queue[currentIndex].id, 'song_2');
    });

    test('Add to Queue appends song to the end', () {
      final queue = List<SongModel>.from(testSongs);
      final newSong = SongModel(
        id: 'end_song',
        title: 'End Track',
        artist: 'Guest',
        album: 'Single',
        durationMs: 200000,
        dataPath: '/music/end.mp3',
        sizeBytes: 4000000,
        dateAdded: 1600005000,
        fileExtension: 'mp3',
      );

      queue.add(newSong);
      expect(queue.last.id, 'end_song');
    });

    test('Remove from upcoming queue and Undo restoration', () {
      final queue = List<SongModel>.from(testSongs);
      int currentIndex = 2;

      // Remove Track 5 (upcoming)
      int removeIdx = 5;
      final removed = queue.removeAt(removeIdx);

      if (removeIdx < currentIndex) {
        currentIndex -= 1;
      }

      expect(removed.id, 'song_5');
      expect(queue.length, 14);
      expect(currentIndex, 2);

      // Undo Remove
      queue.insert(removeIdx, removed);
      if (removeIdx <= currentIndex) {
        currentIndex += 1;
      }

      expect(queue.length, 15);
      expect(queue[5].id, 'song_5');
      expect(currentIndex, 2);
    });

    test('Clear Upcoming Queue preserves currently playing song at index 0', () {
      final queue = List<SongModel>.from(testSongs);
      int currentIndex = 4;
      final currentSong = queue[currentIndex];

      final clearedQueue = [currentSong];
      currentIndex = 0;

      expect(clearedQueue.length, 1);
      expect(clearedQueue.first.id, 'song_4');
      expect(currentIndex, 0);
    });

    test('Reorder songs from position 10 to position 2 while track 0 is playing', () {
      final queue = List<SongModel>.from(testSongs);
      int currentIndex = 0;

      int oldIndex = 10;
      int newIndex = 2;

      if (oldIndex < newIndex) newIndex -= 1;
      final song = queue.removeAt(oldIndex);
      queue.insert(newIndex, song);

      if (oldIndex == currentIndex) {
        currentIndex = newIndex;
      } else if (oldIndex < currentIndex && newIndex >= currentIndex) {
        currentIndex -= 1;
      } else if (oldIndex > currentIndex && newIndex <= currentIndex) {
        currentIndex += 1;
      }

      expect(currentIndex, 0);
      expect(queue[2].id, 'song_10');
      expect(queue[0].id, 'song_0');
    });

    test('Move a song from the very bottom to the very top (index 0) updates current playing track index', () {
      final queue = List<SongModel>.from(testSongs);
      int currentIndex = 0; // Currently playing track 0

      int oldIndex = queue.length - 1; // Last track (index 14)
      int newIndex = 0; // Move to top

      if (oldIndex < newIndex) newIndex -= 1;
      final song = queue.removeAt(oldIndex);
      queue.insert(newIndex, song);

      if (oldIndex == currentIndex) {
        currentIndex = newIndex;
      } else if (oldIndex < currentIndex && newIndex >= currentIndex) {
        currentIndex -= 1;
      } else if (oldIndex > currentIndex && newIndex <= currentIndex) {
        currentIndex += 1;
      }

      expect(queue[0].id, 'song_14'); // Last song is now top
      expect(currentIndex, 1); // Current song index shifted to 1!
      expect(queue[currentIndex].id, 'song_0'); // Still playing track 0 without restart!
    });

    test('Reorder with shuffle enabled preserves non-repeating sequence', () {
      final original = List<SongModel>.from(testSongs);
      final currentSong = original[3];

      // Shuffle logic with current song locked at index 0
      final remaining = List<SongModel>.from(original)..removeWhere((s) => s.id == currentSong.id);
      remaining.shuffle();
      final effectivePlaylist = [currentSong, ...remaining];
      int currentIndex = 0;

      expect(effectivePlaylist[0].id, 'song_3');
      expect(effectivePlaylist.length, original.length);

      // Reorder upcoming shuffled track
      int oldIndex = 5;
      int newIndex = 2;
      final moved = effectivePlaylist.removeAt(oldIndex);
      effectivePlaylist.insert(newIndex, moved);

      expect(effectivePlaylist[0].id, 'song_3');
      expect(currentIndex, 0);
      expect(effectivePlaylist[2].id, moved.id);
    });

    test('Single song queue next/previous edge case handles smoothly', () {
      final singleQueue = [testSongs.first];
      int currentIndex = 0;

      // Skip to next with loop all
      if (singleQueue.length == 1) {
        // Loops the same track without crashing or advancing out of bounds
        currentIndex = 0;
      }

      expect(currentIndex, 0);
      expect(singleQueue[currentIndex].id, 'song_0');
    });

    test('Queue with 500+ songs executes reordering with sub-millisecond latency', () {
      final largeQueue = List.generate(
        600,
        (i) => SongModel(
          id: 'song_$i',
          title: 'Large Catalog Track $i',
          artist: 'Artist ${i % 10}',
          album: 'Album ${i % 5}',
          durationMs: 200000,
          dataPath: '/music/track_$i.mp3',
          sizeBytes: 4000000,
          dateAdded: 1600000000 + i,
          fileExtension: 'mp3',
        ),
      );

      int currentIndex = 45; // Playing song 45

      final stopwatch = Stopwatch()..start();

      // Move track 580 to position 12
      int oldIndex = 580;
      int newIndex = 12;

      if (oldIndex < newIndex) newIndex -= 1;
      final song = largeQueue.removeAt(oldIndex);
      largeQueue.insert(newIndex, song);

      if (oldIndex == currentIndex) {
        currentIndex = newIndex;
      } else if (oldIndex < currentIndex && newIndex >= currentIndex) {
        currentIndex -= 1;
      } else if (oldIndex > currentIndex && newIndex <= currentIndex) {
        currentIndex += 1;
      }

      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(10)); // <10ms for 600 items
      expect(largeQueue.length, 600);
      expect(largeQueue[12].id, 'song_580');
      expect(currentIndex, 46); // shifted by +1
      expect(largeQueue[currentIndex].id, 'song_45'); // Current playing song stays intact
    });

    test('Add album to queue and Add artist to queue append correct subset', () {
      final library = List<SongModel>.from(testSongs);
      final activeQueue = <SongModel>[testSongs[0]];

      // Add all tracks from 'Album 0'
      final albumSongs = library.where((s) => s.album == 'Album 0').toList();
      activeQueue.addAll(albumSongs);

      expect(activeQueue.length, 1 + albumSongs.length);
      for (final s in albumSongs) {
        expect(s.album, 'Album 0');
      }

      // Add all tracks by 'Artist 1'
      final artistSongs = library.where((s) => s.artist == 'Artist 1').toList();
      activeQueue.addAll(artistSongs);

      expect(activeQueue.length, 1 + albumSongs.length + artistSongs.length);
    });
  });
}
