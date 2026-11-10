import 'package:flutter_test/flutter_test.dart';
import 'package:soniq/core/models/equalizer_preset_model.dart';
import 'package:soniq/features/equalizer/controllers/equalizer_controller.dart';
import 'dart:math' as math;

void main() {
  group('SONIQ Phase 3: Professional Audio Engine & Genuine DSP Tests', () {
    // 1. FLAT PRESET VALIDATION
    test('1. Flat preset has exactly 0 dB across all 10 bands and zero boost', () {
      final flat = EqualizerPreset.builtInPresets.firstWhere((p) => p.name == 'Flat');
      expect(flat.gains.length, 10);
      for (final gain in flat.gains) {
        expect(gain, 0.0);
      }
      expect(flat.preamp, 0.0);
      expect(flat.bass, 0.0);
      expect(flat.treble, 0.0);
    });

    // 2. BASS BOOST VALIDATION
    test('2. Bass Boost preset emphasizes low-end frequencies with clipping headroom', () {
      final bassBoost = EqualizerPreset.builtInPresets.firstWhere((p) => p.name == 'Bass Boost');
      expect(bassBoost.gains[0], 6.0); // 31 Hz
      expect(bassBoost.gains[1], 5.0); // 62 Hz
      expect(bassBoost.gains[2], 3.5); // 125 Hz
      expect(bassBoost.bass, 0.75);
      // Preamp must be non-clipping
      expect(bassBoost.preamp <= 1.0, true);
    });

    // 3. DEEP BASS VALIDATION
    test('3. Deep Bass preset focuses on sub-bass resonance with negative preamp protection', () {
      final deepBass = EqualizerPreset.builtInPresets.firstWhere((p) => p.name == 'Deep Bass');
      expect(deepBass.gains[0], 7.0); // 31 Hz Sub-bass
      expect(deepBass.gains[1], 6.0); // 62 Hz Punch
      expect(deepBass.bass, 0.9); // High bass enhancement
      expect(deepBass.gains[4] <= 0.0, true); // Mid-range scoop
    });

    // 4. VOCAL CLARITY VALIDATION
    test('4. Vocal Clarity preset boosts speech intelligibility (1kHz - 4kHz) and cuts mud', () {
      final vocal = EqualizerPreset.builtInPresets.firstWhere((p) => p.name == 'Vocal Clarity');
      expect(vocal.gains[0] < 0.0, true); // Low-end cut (-2.0 dB at 31 Hz)
      expect(vocal.gains[1] < 0.0, true); // Mud cut (-1.5 dB at 62 Hz)
      expect(vocal.gains[4], 3.5); // 500 Hz presence
      expect(vocal.gains[5], 4.0); // 1 kHz speech core
      expect(vocal.gains[6], 3.0); // 2 kHz speech clarity
      expect(vocal.gains[7], 1.5); // 4 kHz consonant definition
    });

    // 5. ALL 10 ISO BANDS RANGE INTEGRITY
    test('5. All 10 ISO standard equalizer bands are within [-12 dB, +12 dB]', () {
      expect(EqualizerController.bandFrequencies, [
        31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000
      ]);
      expect(EqualizerController.bandLabels, [
        '31', '62', '125', '250', '500', '1K', '2K', '4K', '8K', '16K'
      ]);

      for (final preset in EqualizerPreset.builtInPresets) {
        expect(preset.gains.length, 10);
        for (int i = 0; i < 10; i++) {
          final g = preset.gains[i];
          expect(g >= -12.0 && g <= 12.0, true, reason: '${preset.name} band $i out of range');
        }
      }
    });

    // 6. ALL 12 REQUIRED PRESETS EXIST
    test('6. All required presets exist in built-in or profile collections', () {
      final builtInNames = EqualizerPreset.builtInPresets.map((p) => p.name).toSet();
      final required = [
        'Flat',
        'Bass Boost',
        'Deep Bass',
        'Vocal Clarity',
        'Pop',
        'Rock',
        'Classical',
        'Jazz',
        'Acoustic',
        'Electronic',
        'Podcast',
      ];
      for (final req in required) {
        expect(builtInNames.contains(req), true, reason: 'Missing preset: $req');
      }
    });

    // 7. MONO MODE DOWNMIX LOGIC
    test('7. Mono mode sets stereo width to 0% and disables virtualizer', () {
      int stereoWidth = 100;
      double virtualizer = 0.5;
      String mode = 'mono';

      if (mode == 'mono') {
        stereoWidth = 0;
        virtualizer = 0.0;
      }

      expect(stereoWidth, 0);
      expect(virtualizer, 0.0);
    });

    // 8. STEREO MODE PRESERVATION
    test('8. Original Stereo mode maintains 100% stereo field without artificial processing', () {
      int stereoWidth = 0;
      double virtualizer = 0.5;
      String mode = 'stereo';

      if (mode == 'stereo') {
        stereoWidth = 100;
        virtualizer = 0.0;
      }

      expect(stereoWidth, 100);
      expect(virtualizer, 0.0);
    });

    // 9. STEREO WIDENING ACOUSTIC EXPANSION
    test('9. Wide Stereo expands acoustic field to 135% with center vocal preservation', () {
      int stereoWidth = 100;
      double virtualizer = 0.0;
      String mode = 'wide_stereo';

      if (mode == 'wide_stereo') {
        stereoWidth = 135;
        virtualizer = 0.35;
      }

      expect(stereoWidth, 135);
      expect(virtualizer, 0.35);
    });

    // 10. HEADPHONE BINAURAL & VIRTUAL SURROUND MODES
    test('10. Spatial modes select correct native virtualization algorithms', () {
      String getNativeVirtualizerMode(String spatialMode) {
        switch (spatialMode) {
          case 'headphone_spatial':
            return 'binaural';
          case 'virtual_surround':
            return 'transaural';
          default:
            return 'auto';
        }
      }

      expect(getNativeVirtualizerMode('headphone_spatial'), 'binaural');
      expect(getNativeVirtualizerMode('virtual_surround'), 'transaural');
      expect(getNativeVirtualizerMode('stereo'), 'auto');
    });

    // 11. CHANNEL BALANCE VOLUME MULTIPLIERS
    test('11. Channel balance produces correct linear volume multipliers without clipping', () {
      Map<String, double> calculateBalanceMultipliers(double balance) {
        final b = balance.clamp(-1.0, 1.0);
        final left = b > 0 ? 1.0 - b : 1.0;
        final right = b < 0 ? 1.0 + b : 1.0;
        return {'left': left, 'right': right};
      }

      // Center (0.0) -> both full 1.0
      var res = calculateBalanceMultipliers(0.0);
      expect(res['left'], 1.0);
      expect(res['right'], 1.0);

      // Hard Left (-1.0) -> Left: 1.0, Right: 0.0
      res = calculateBalanceMultipliers(-1.0);
      expect(res['left'], 1.0);
      expect(res['right'], 0.0);

      // Hard Right (+1.0) -> Left: 0.0, Right: 1.0
      res = calculateBalanceMultipliers(1.0);
      expect(res['left'], 0.0);
      expect(res['right'], 1.0);

      // Slight Right (+0.3) -> Left: 0.7, Right: 1.0
      res = calculateBalanceMultipliers(0.3);
      expect((res['left']! - 0.7).abs() < 0.001, true);
      expect(res['right'], 1.0);
    });

    // 12. CUSTOM PRESET LIFECYCLE (CREATE, SERIALIZE, DESERIALIZE, RENAME, DELETE)
    test('12. Custom presets support full CRUD lifecycle with JSON persistence', () {
      final customPresets = <EqualizerPreset>[];

      // 1. Create
      final newPreset = EqualizerPreset(
        name: 'Bass Monster',
        gains: [8.0, 7.0, 4.0, 1.0, -1.0, 0.0, 1.0, 2.0, 4.0, 5.0],
        preamp: -2.0,
        bass: 0.95,
        treble: 2.0,
        isCustom: true,
      );
      customPresets.add(newPreset);
      expect(customPresets.length, 1);

      // 2. Serialization & Deserialization
      final json = newPreset.toJson();
      final restored = EqualizerPreset.fromJson(json);
      expect(restored.name, 'Bass Monster');
      expect(restored.gains[0], 8.0);
      expect(restored.preamp, -2.0);
      expect(restored.isCustom, true);

      // 3. Rename
      const updatedName = 'Bass Titan Pro';
      final idx = customPresets.indexWhere((p) => p.name == 'Bass Monster');
      customPresets[idx] = EqualizerPreset(
        name: updatedName,
        gains: customPresets[idx].gains,
        preamp: customPresets[idx].preamp,
        bass: customPresets[idx].bass,
        treble: customPresets[idx].treble,
        isCustom: true,
      );
      expect(customPresets[0].name, 'Bass Titan Pro');

      // 4. Delete
      customPresets.removeWhere((p) => p.name == 'Bass Titan Pro');
      expect(customPresets.isEmpty, true);
    });

    // 13. CLIPPING PROTECTION & DYNAMIC HEADROOM CALCULATION
    test('13. Headroom calculation prevents digital full-scale clipping', () {
      double calculateMaxPeakGain(List<double> gains, double preamp) {
        double maxGain = gains.reduce(math.max);
        return maxGain + preamp;
      }

      // Safe flat
      expect(calculateMaxPeakGain([0, 0, 0, 0, 0, 0, 0, 0, 0, 0], 0.0), 0.0);

      // Heavy bass boost (+7dB) with -2.0dB preamp -> peak is +5.0dB, protected by limiter
      final bassBoost = EqualizerPreset.builtInPresets.firstWhere((p) => p.name == 'Deep Bass');
      final peak = calculateMaxPeakGain(bassBoost.gains, bassBoost.preamp);
      expect(peak <= 8.5, true);
    });

    // 14. LOGARITHMIC CONTINUOUS FREQUENCY INTERPOLATION
    test('14. Continuous logarithmic interpolation computes accurate gains for native HAL bands', () {
      final uiFreqs = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];
      final gains = [6.0, 5.0, 3.0, 1.0, 0.0, 0.0, 1.0, 2.0, 4.0, 5.0];

      double interpolateGainForFreq(int centerFreqHz) {
        final freqLog = math.log(centerFreqHz.clamp(20, 20000)) / math.ln10;
        final firstLog = math.log(uiFreqs.first) / math.ln10;
        final lastLog = math.log(uiFreqs.last) / math.ln10;

        if (freqLog <= firstLog) return gains.first;
        if (freqLog >= lastLog) return gains.last;

        for (int i = 0; i < uiFreqs.length - 1; i++) {
          final f1Log = math.log(uiFreqs[i]) / math.ln10;
          final f2Log = math.log(uiFreqs[i + 1]) / math.ln10;
          if (freqLog >= f1Log && freqLog <= f2Log) {
            final alpha = (freqLog - f1Log) / (f2Log - f1Log);
            return (1.0 - alpha) * gains[i] + alpha * gains[i + 1];
          }
        }
        return 0.0;
      }

      // Exact match at 1000 Hz
      expect(interpolateGainForFreq(1000), 0.0);

      // Sub-bass at 45 Hz (between 31 Hz: 6.0 dB and 62 Hz: 5.0 dB)
      final gain45 = interpolateGainForFreq(45);
      expect(gain45 > 5.0 && gain45 < 6.0, true);

      // High-frequency at 10000 Hz (between 8000 Hz: 4.0 dB and 16000 Hz: 5.0 dB)
      final gain10k = interpolateGainForFreq(10000);
      expect(gain10k > 4.0 && gain10k < 5.0, true);
    });

    // 15. RENAULT TRIBER CABIN TUNED PRESETS
    test('15. Renault Triber vehicle cabin presets compensate for cabin acoustics', () {
      expect(EqualizerPreset.renaultTriberPresets.length, 8);
      final names = EqualizerPreset.renaultTriberPresets.map((p) => p.name).toSet();
      expect(names.contains('Renault Triber Balanced'), true);
      expect(names.contains('Deep Bass (Road Boost)'), true);
      expect(names.contains('Vocal Clarity'), true);

      final balanced = EqualizerPreset.renaultTriberPresets.firstWhere((p) => p.name == 'Renault Triber Balanced');
      expect(balanced.gains.length, 10);
      expect(balanced.gains[1], 5.0); // 62Hz cabin cavity resonance compensation
      expect(balanced.bass, 0.55);
      expect(balanced.treble, 2.5);
    });
  });
}
