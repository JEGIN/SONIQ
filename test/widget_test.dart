import 'package:flutter_test/flutter_test.dart';
import 'package:soniq/core/models/song_model.dart';
import 'package:soniq/core/utils/duration_formatter.dart';
import 'package:soniq/core/utils/file_utils.dart';

void main() {
  group('SONIQ Core Logic Tests', () {
    test('DurationFormatter formats standard and precision times correctly', () {
      expect(DurationFormatter.format(0), '00:00');
      expect(DurationFormatter.format(65000), '01:05');
      expect(DurationFormatter.formatPrecision(110120), '01:50.12');
      expect(DurationFormatter.formatTimeline(120.0), '02:00.00');
    });

    test('FileUtils detects supported audio extensions', () {
      expect(FileUtils.isSupportedAudioFile('song.mp3'), isTrue);
      expect(FileUtils.isSupportedAudioFile('track.flac'), isTrue);
      expect(FileUtils.isSupportedAudioFile('audio.wav'), isTrue);
      expect(FileUtils.isSupportedAudioFile('audio.m4a'), isTrue);
      expect(FileUtils.isSupportedAudioFile('image.png'), isFalse);
    });

    test('SongModel serializes and deserializes accurately', () {
      final song = SongModel(
        id: 'track_1',
        title: 'Space Oddity',
        artist: 'David Bowie',
        album: 'Space Oddity',
        durationMs: 315000,
        dataPath: '/music/space_oddity.mp3',
        dateAdded: 1672531199,
        sizeBytes: 10485760,
        fileExtension: 'mp3',
        isFavorite: true,
      );

      final jsonMap = song.toMap();
      final revived = SongModel.fromMap(jsonMap);

      expect(revived.id, 'track_1');
      expect(revived.title, 'Space Oddity');
      expect(revived.artist, 'David Bowie');
      expect(revived.isFavorite, isTrue);
      expect(revived.formattedDuration, '05:15');
      expect(revived.formattedSize, '10.0 MB');
    });
  });
}
