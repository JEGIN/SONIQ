import 'package:flutter_test/flutter_test.dart';
import 'package:audio_session/audio_session.dart';
import 'package:soniq/core/services/audio_handler.dart';

/// Simulation harness to verify the PlaybackIntent state machine
/// independently of hardware audio sinks.
class PlaybackIntentStateMachine {
  PlaybackIntent playbackIntent = PlaybackIntent.manualPause;
  int intentRevision = 0;
  int interruptedRevision = -1;
  bool isDucked = false;
  bool isPlaying = false;
  String? currentSongId;

  void userPlay({String? songId}) {
    playbackIntent = PlaybackIntent.playing;
    interruptedRevision = -1;
    intentRevision++;
    isPlaying = true;
    if (songId != null) currentSongId = songId;
  }

  void userPause() {
    playbackIntent = PlaybackIntent.manualPause;
    interruptedRevision = -1;
    intentRevision++;
    isPlaying = false;
  }

  void userStop() {
    playbackIntent = PlaybackIntent.manualStop;
    interruptedRevision = -1;
    intentRevision++;
    isPlaying = false;
  }

  void loadTrack({required bool autoPlay, required String songId}) {
    currentSongId = songId;
    if (!autoPlay) {
      playbackIntent = PlaybackIntent.manualPause;
      interruptedRevision = -1;
      intentRevision++;
      isPlaying = false;
    } else {
      playbackIntent = PlaybackIntent.playing;
      interruptedRevision = -1;
      intentRevision++;
      isPlaying = true;
    }
  }

  void removeFromQueue({required bool isCurrentTrack, required String nextSongId}) {
    if (isCurrentTrack) {
      final wasPlaying = playbackIntent == PlaybackIntent.playing && isPlaying;
      loadTrack(autoPlay: wasPlaying, songId: nextSongId);
    }
  }

  void handleBecomingNoisy() {
    playbackIntent = PlaybackIntent.manualPause;
    interruptedRevision = -1;
    intentRevision++;
    isPlaying = false;
  }

  void handleInterruption(AudioInterruptionEvent event) {
    if (event.begin) {
      switch (event.type) {
        case AudioInterruptionType.duck:
          if (isPlaying && playbackIntent == PlaybackIntent.playing) {
            isDucked = true;
          }
          break;

        case AudioInterruptionType.pause:
          if (playbackIntent == PlaybackIntent.playing && isPlaying) {
            playbackIntent = PlaybackIntent.interrupted;
            interruptedRevision = ++intentRevision;
            isPlaying = false;
          } else {
            // Already manually paused or stopped. Preserved!
            isPlaying = false;
          }
          break;

        case AudioInterruptionType.unknown:
          playbackIntent = PlaybackIntent.manualPause;
          interruptedRevision = -1;
          intentRevision++;
          isPlaying = false;
          break;
      }
    } else {
      switch (event.type) {
        case AudioInterruptionType.duck:
          if (isDucked) {
            isDucked = false;
          }
          break;

        case AudioInterruptionType.pause:
          final currentRev = intentRevision;
          if (playbackIntent == PlaybackIntent.interrupted &&
              currentRev == interruptedRevision &&
              currentSongId != null) {
            playbackIntent = PlaybackIntent.playing;
            interruptedRevision = -1;
            intentRevision++;
            isPlaying = true;
          }
          // If user manually paused before or during interruption, DO NOTHING!
          break;

        case AudioInterruptionType.unknown:
          break;
      }
    }
  }
}

void main() {
  group('SONIQ Playback Intent & Audio Focus Interruption Tests', () {
    late PlaybackIntentStateMachine machine;

    setUp(() {
      machine = PlaybackIntentStateMachine();
    });

    test('Initial state: Starts in manualPause, isPlaying is false', () {
      expect(machine.playbackIntent, equals(PlaybackIntent.manualPause));
      expect(machine.isPlaying, isFalse);
    });

    test('Scenario A: User manually pauses -> Instagram Reel plays & closes -> Remains paused', () {
      // 1. User plays a track
      machine.userPlay(songId: 'song_1');
      expect(machine.playbackIntent, equals(PlaybackIntent.playing));
      expect(machine.isPlaying, isTrue);

      // 2. User manually presses Pause
      machine.userPause();
      expect(machine.playbackIntent, equals(PlaybackIntent.manualPause));
      expect(machine.isPlaying, isFalse);

      // 3. User opens Instagram / plays a Reel (External focus loss)
      machine.handleInterruption(
        AudioInterruptionEvent(true, AudioInterruptionType.pause),
      );
      // Playback intent MUST NOT be changed to interrupted!
      expect(machine.playbackIntent, equals(PlaybackIntent.manualPause));
      expect(machine.isPlaying, isFalse);

      // 4. User closes Instagram / Reel ends (External focus gained back)
      machine.handleInterruption(
        AudioInterruptionEvent(false, AudioInterruptionType.pause),
      );
      // Playback MUST REMAIN PAUSED!
      expect(machine.playbackIntent, equals(PlaybackIntent.manualPause));
      expect(machine.isPlaying, isFalse);
    });

    test('Scenario B: Music is actively playing -> YouTube takes focus -> Closes YouTube -> Auto-resumes', () {
      // 1. User is actively playing
      machine.userPlay(songId: 'song_1');
      expect(machine.playbackIntent, equals(PlaybackIntent.playing));
      expect(machine.isPlaying, isTrue);

      // 2. YouTube interrupts playback
      machine.handleInterruption(
        AudioInterruptionEvent(true, AudioInterruptionType.pause),
      );
      expect(machine.playbackIntent, equals(PlaybackIntent.interrupted));
      expect(machine.isPlaying, isFalse);

      // 3. User finishes YouTube video and closes YouTube
      machine.handleInterruption(
        AudioInterruptionEvent(false, AudioInterruptionType.pause),
      );
      expect(machine.playbackIntent, equals(PlaybackIntent.playing));
      expect(machine.isPlaying, isTrue);
    });

    test('Scenario C: Manually paused -> Offline video plays and finishes -> Remains paused', () {
      // 1. Paused
      machine.userPlay(songId: 'song_1');
      machine.userPause();
      expect(machine.playbackIntent, equals(PlaybackIntent.manualPause));

      // 2. Offline video starts
      machine.handleInterruption(
        AudioInterruptionEvent(true, AudioInterruptionType.pause),
      );
      expect(machine.playbackIntent, equals(PlaybackIntent.manualPause));

      // 3. Offline video finishes
      machine.handleInterruption(
        AudioInterruptionEvent(false, AudioInterruptionType.pause),
      );
      expect(machine.playbackIntent, equals(PlaybackIntent.manualPause));
      expect(machine.isPlaying, isFalse);
    });

    test('Scenario D: Manually paused -> Phone call arrives and hangs up -> Remains paused', () {
      machine.userPlay(songId: 'song_1');
      machine.userPause();

      // Incoming phone call
      machine.handleInterruption(
        AudioInterruptionEvent(true, AudioInterruptionType.pause),
      );
      expect(machine.playbackIntent, equals(PlaybackIntent.manualPause));

      // Phone call ends
      machine.handleInterruption(
        AudioInterruptionEvent(false, AudioInterruptionType.pause),
      );
      expect(machine.playbackIntent, equals(PlaybackIntent.manualPause));
      expect(machine.isPlaying, isFalse);
    });

    test('Scenario E: Music playing -> Phone call arrives -> Call ends -> Auto-resumes', () {
      machine.userPlay(songId: 'song_1');

      // Phone call interrupts
      machine.handleInterruption(
        AudioInterruptionEvent(true, AudioInterruptionType.pause),
      );
      expect(machine.playbackIntent, equals(PlaybackIntent.interrupted));

      // Call ends
      machine.handleInterruption(
        AudioInterruptionEvent(false, AudioInterruptionType.pause),
      );
      expect(machine.playbackIntent, equals(PlaybackIntent.playing));
      expect(machine.isPlaying, isTrue);
    });

    test('Scenario F: Music playing -> Interruption occurs -> User taps Pause DURING interruption -> Call ends -> Remains paused', () {
      machine.userPlay(songId: 'song_1');

      // External app interrupts
      machine.handleInterruption(
        AudioInterruptionEvent(true, AudioInterruptionType.pause),
      );
      expect(machine.playbackIntent, equals(PlaybackIntent.interrupted));

      // User presses Pause from notification shade or lock screen
      machine.userPause();
      expect(machine.playbackIntent, equals(PlaybackIntent.manualPause));

      // External app finishes and abandons focus
      machine.handleInterruption(
        AudioInterruptionEvent(false, AudioInterruptionType.pause),
      );
      // MUST NOT RESUME because user explicitly paused during interruption!
      expect(machine.playbackIntent, equals(PlaybackIntent.manualPause));
      expect(machine.isPlaying, isFalse);
    });

    test('Scenario G: Ducking during navigation prompt lowers volume without stopping, then restores', () {
      machine.userPlay(songId: 'song_1');

      // GPS navigation announcement
      machine.handleInterruption(
        AudioInterruptionEvent(true, AudioInterruptionType.duck),
      );
      expect(machine.isDucked, isTrue);
      expect(machine.isPlaying, isTrue);

      // Announcement ends
      machine.handleInterruption(
        AudioInterruptionEvent(false, AudioInterruptionType.duck),
      );
      expect(machine.isDucked, isFalse);
      expect(machine.isPlaying, isTrue);
    });

    test('Scenario H: Becoming noisy (headset unplugged) pauses and sets manualPause (never auto-plays through speakers)', () {
      machine.userPlay(songId: 'song_1');

      // Headset unplugged
      machine.handleBecomingNoisy();
      expect(machine.playbackIntent, equals(PlaybackIntent.manualPause));
      expect(machine.isPlaying, isFalse);

      // Later, focus change or transient event must NOT restart playback
      machine.handleInterruption(
        AudioInterruptionEvent(false, AudioInterruptionType.pause),
      );
      expect(machine.playbackIntent, equals(PlaybackIntent.manualPause));
      expect(machine.isPlaying, isFalse);
    });

    test('Scenario I: Permanent focus loss sets manualPause and never auto-resumes', () {
      machine.userPlay(songId: 'song_1');

      // Another media player takes permanent focus
      machine.handleInterruption(
        AudioInterruptionEvent(true, AudioInterruptionType.unknown),
      );
      expect(machine.playbackIntent, equals(PlaybackIntent.manualPause));
      expect(machine.isPlaying, isFalse);

      // Regaining focus later
      machine.handleInterruption(
        AudioInterruptionEvent(false, AudioInterruptionType.pause),
      );
      expect(machine.playbackIntent, equals(PlaybackIntent.manualPause));
      expect(machine.isPlaying, isFalse);
    });

    test('Scenario J: State revision guards against stale asynchronous callbacks', () {
      machine.userPlay(songId: 'song_1');

      // Interruption starts
      machine.handleInterruption(
        AudioInterruptionEvent(true, AudioInterruptionType.pause),
      );
      final recordedIntRev = machine.interruptedRevision;

      // User pauses, advancing revision
      machine.userPause();
      expect(machine.intentRevision, greaterThan(recordedIntRev));

      // Interruption ends
      machine.handleInterruption(
        AudioInterruptionEvent(false, AudioInterruptionType.pause),
      );
      expect(machine.isPlaying, isFalse);
      expect(machine.playbackIntent, equals(PlaybackIntent.manualPause));
    });

    test('Scenario K: Removing current track from queue while paused remains paused without auto-play', () {
      machine.userPlay(songId: 'song_1');
      machine.userPause();
      expect(machine.isPlaying, isFalse);
      expect(machine.playbackIntent, equals(PlaybackIntent.manualPause));

      // User deletes currently paused track from queue
      machine.removeFromQueue(isCurrentTrack: true, nextSongId: 'song_2');
      expect(machine.currentSongId, equals('song_2'));
      expect(machine.isPlaying, isFalse);
      expect(machine.playbackIntent, equals(PlaybackIntent.manualPause));

      // External focus event happens later
      machine.handleInterruption(
        AudioInterruptionEvent(false, AudioInterruptionType.pause),
      );
      expect(machine.isPlaying, isFalse);
      expect(machine.playbackIntent, equals(PlaybackIntent.manualPause));
    });

    test('Scenario L: Restoring persisted queue sets manualPause and never auto-plays without user interaction', () {
      // Simulate app start / restoration
      machine.loadTrack(autoPlay: false, songId: 'restored_song');
      expect(machine.playbackIntent, equals(PlaybackIntent.manualPause));
      expect(machine.isPlaying, isFalse);

      // Instagram, reels, YouTube open and close
      machine.handleInterruption(
        AudioInterruptionEvent(true, AudioInterruptionType.pause),
      );
      machine.handleInterruption(
        AudioInterruptionEvent(false, AudioInterruptionType.pause),
      );
      expect(machine.isPlaying, isFalse);
      expect(machine.playbackIntent, equals(PlaybackIntent.manualPause));
    });
  });
}
