import 'package:flutter_test/flutter_test.dart';
import 'package:soniq/core/services/audio_scanner_service.dart';

void main() {
  group('AudioScannerService Voice & Call Recording Filter Tests', () {
    test('Correctly identifies Android default sound recorder paths', () {
      final paths = [
        '/storage/emulated/0/Recordings/Standard_Recording_01.m4a',
        '/storage/emulated/0/Recordings/Call/20261109_120000.m4a',
        '/storage/emulated/0/SoundRecorder/Voice 001.m4a',
        '/storage/emulated/0/VoiceRecorder/meeting_notes.aac',
        '/storage/emulated/0/CallRecordings/call_mom.mp3',
        '/storage/emulated/0/Call_Recordings/incoming_01.mp3',
        '/storage/emulated/0/MIUI/sound_recorder/call_rec/call_123.mp3',
        '/storage/emulated/0/com.nothing.soundrecorder/rec_001.wav',
        '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Audio/AUD-20261101-WA0001.opus',
        '/storage/emulated/0/WhatsApp/Media/WhatsApp Voice Notes/202645/PTT-20261101-WA0002.opus',
        '/storage/emulated/0/Telegram/Telegram Audio/voice_message.ogg',
        '/storage/emulated/0/AudioRecordings/sample.m4a',
        '/storage/emulated/0/Notifications/ping.mp3',
        '/storage/emulated/0/Ringtones/marimba.mp3',
        '/storage/emulated/0/Alarms/rooster.mp3',
      ];

      for (final path in paths) {
        final isIgnored = AudioScannerService.isIgnoredRecordingOrSystemAudio(
          filePath: path,
          durationMs: 45000,
        );
        expect(isIgnored, isTrue, reason: 'Failed to filter recording path: $path');
      }
    });

    test('Never filters genuine music library songs', () {
      final musicPaths = [
        '/storage/emulated/0/Music/Anirudh Ravichander/Master/Master the Blaster.mp3',
        '/storage/emulated/0/Music/A.R. Rahman/Roja/Chinna Chinna Aasai.flac',
        '/storage/emulated/0/Download/Imagine Dragons - Believer.mp3',
        '/storage/emulated/0/Music/The Weeknd/Starboy/Starboy.m4a',
        '/storage/emulated/0/Music/Tamil Hits 2026/Arabic Kuthu.mp3',
        '/storage/emulated/0/Audio/Coldplay/Yellow.mp3',
      ];

      for (final path in musicPaths) {
        final isIgnored = AudioScannerService.isIgnoredRecordingOrSystemAudio(
          filePath: path,
          title: 'Great Song',
          artist: 'Great Artist',
          album: 'Great Album',
          durationMs: 210000,
          isMusic: true,
          isRingtone: false,
          isAlarm: false,
          isNotification: false,
        );
        expect(isIgnored, isFalse, reason: 'False positive on music path: $path');
      }
    });

    test('Filters system sound flags from Android MediaStore', () {
      expect(
        AudioScannerService.isIgnoredRecordingOrSystemAudio(
          filePath: '/storage/emulated/0/Music/alert.mp3',
          isRingtone: true,
        ),
        isTrue,
      );

      expect(
        AudioScannerService.isIgnoredRecordingOrSystemAudio(
          filePath: '/storage/emulated/0/Music/alarm_sound.mp3',
          isAlarm: true,
        ),
        isTrue,
      );

      expect(
        AudioScannerService.isIgnoredRecordingOrSystemAudio(
          filePath: '/storage/emulated/0/Music/chime.mp3',
          isNotification: true,
        ),
        isTrue,
      );
    });

    test('Filters short audio under 10 seconds', () {
      expect(
        AudioScannerService.isIgnoredRecordingOrSystemAudio(
          filePath: '/storage/emulated/0/Music/beep.mp3',
          durationMs: 4000, // 4 seconds
        ),
        isTrue,
      );
    });

    test('Filters recordings identified by album and artist metadata', () {
      expect(
        AudioScannerService.isIgnoredRecordingOrSystemAudio(
          filePath: '/storage/emulated/0/Music/memo.mp3',
          album: 'Voice Recorder',
          durationMs: 120000,
        ),
        isTrue,
      );

      expect(
        AudioScannerService.isIgnoredRecordingOrSystemAudio(
          filePath: '/storage/emulated/0/Music/call_audio.mp3',
          artist: 'Call Recorder',
          durationMs: 120000,
        ),
        isTrue,
      );
    });
  });
}
