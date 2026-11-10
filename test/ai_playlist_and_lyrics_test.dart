import 'package:flutter_test/flutter_test.dart';
import 'package:soniq/core/models/lyric_line_model.dart';
import 'package:soniq/core/models/song_model.dart';
import 'package:soniq/core/services/ai_playlist_service.dart';

void main() {
  group('AI Playlist & Synchronized Lyrics Tests', () {
    late List<SongModel> sampleSongs;

    setUp(() {
      sampleSongs = [
        SongModel(
          id: 'song_1',
          title: 'Energetic Gym Workout Beat',
          artist: 'Electronic Power',
          album: 'Fitness 2024',
          durationMs: 180000, // 3:00 min
          dataPath: '/music/song_1.mp3',
          dateAdded: 1700000000,
          sizeBytes: 6000000,
          fileExtension: 'mp3',
          isFavorite: true,
        ),
        SongModel(
          id: 'song_2',
          title: 'Midnight Rain Acoustic Melody',
          artist: 'Calm Breeze',
          album: 'Peaceful Moments',
          durationMs: 320000, // 5:20 min
          dataPath: '/music/song_2.mp3',
          dateAdded: 1690000000,
          sizeBytes: 8000000,
          fileExtension: 'mp3',
          isFavorite: false,
        ),
        SongModel(
          id: 'song_3',
          title: 'Road Trip Driving Highway Anthem',
          artist: 'Classic Rockers',
          album: 'Sunset Coast',
          durationMs: 240000,
          dataPath: '/music/song_3.mp3',
          dateAdded: 1680000000,
          sizeBytes: 7000000,
          fileExtension: 'mp3',
          isFavorite: true,
        ),
        SongModel(
          id: 'song_4',
          title: 'Deep Focus Ambient Piano',
          artist: 'Instrumental Flow',
          album: 'Study Session',
          durationMs: 210000,
          dataPath: '/music/song_4.mp3',
          dateAdded: 1670000000,
          sizeBytes: 5000000,
          fileExtension: 'mp3',
          isFavorite: false,
        ),
      ];
    });

    test('1. AI Playlist Service generates Workout mix prioritizing upbeat tracks', () {
      final ai = AiPlaylistService();
      final workoutSongs = ai.generateByVibe(sampleSongs, AiPlaylistVibe.workout, limit: 2);

      expect(workoutSongs, isNotEmpty);
      expect(workoutSongs.first.title.toLowerCase().contains('workout') || workoutSongs.first.title.toLowerCase().contains('beat'), isTrue);
    });

    test('2. AI Playlist Service generates Chill mix prioritizing long melodic tracks', () {
      final ai = AiPlaylistService();
      final chillSongs = ai.generateByVibe(sampleSongs, AiPlaylistVibe.chill, limit: 2);

      expect(chillSongs, isNotEmpty);
      expect(chillSongs.first.title.toLowerCase().contains('rain') || chillSongs.first.title.toLowerCase().contains('melody'), isTrue);
    });

    test('3. AI Playlist Service responds to natural language prompt matching', () {
      final ai = AiPlaylistService();
      final matched = ai.generateByPrompt(sampleSongs, 'acoustic midnight rain');

      expect(matched, isNotEmpty);
      expect(matched.first.id, 'song_2');
    });

    test('4. LyricLine parses standard LRC timestamp format [mm:ss.xx]', () {
      const lrcContent = '''
[ti:Midnight Rain]
[ar:Calm Breeze]
[00:15.50] First verse begins here
[00:22.10] The rain falls on the roof
[01:05.80] Chorus with high energy
''';

      final lines = LyricLine.parseLrc(lrcContent);

      expect(lines.length, 3);
      expect(lines[0].text, 'First verse begins here');
      expect(lines[0].timestamp, const Duration(seconds: 15, milliseconds: 500));
      expect(lines[0].isTimestamped, isTrue);

      expect(lines[1].text, 'The rain falls on the roof');
      expect(lines[1].timestamp, const Duration(seconds: 22, milliseconds: 100));

      expect(lines[2].text, 'Chorus with high energy');
      expect(lines[2].timestamp, const Duration(minutes: 1, seconds: 5, milliseconds: 800));
    });

    test('5. LyricLine gracefully parses plain text lyrics without timestamps', () {
      const plainLyrics = '''
Just a small town girl
Living in a lonely world
She took the midnight train going anywhere
''';

      final lines = LyricLine.parseLrc(plainLyrics);

      expect(lines.length, 3);
      expect(lines[0].text, 'Just a small town girl');
      expect(lines[0].isTimestamped, isFalse);
      expect(lines[0].timestamp, Duration.zero);
    });
  });
}
