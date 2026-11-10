import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/song_model.dart';
import '../database/song_cache_service.dart';

class WaveformService {
  static final WaveformService _instance = WaveformService._internal();
  factory WaveformService() => _instance;
  WaveformService._internal();

  final SongCacheService _cacheService = SongCacheService();

  /// Returns cached waveform peaks or computes them quickly from the audio file
  Future<List<double>> getWaveformPeaks(SongModel song, {int samples = 140}) async {
    // 1. Check in-memory / model cached peaks
    if (song.waveformPeaks != null && song.waveformPeaks!.length >= samples / 2) {
      return song.waveformPeaks!;
    }

    // 2. Compute from file
    try {
      final file = File(song.dataPath);
      if (await file.exists()) {
        final peaks = await compute(_extractPeaksFromFile, {
          'path': song.dataPath,
          'samples': samples,
        });

        // Cache in song model and database
        song.waveformPeaks = peaks;
        await _cacheService.updateSong(song);
        return peaks;
      }
    } catch (e) {
      debugPrint('SONIQ: Error extracting waveform peaks: $e');
    }

    // 3. Fallback: Generate dynamic deterministic pseudo-waveform based on song id/title
    return _generateDeterministicPeaks(song.id + song.title, samples);
  }

  /// Extracts amplitude peaks by reading audio byte chunks across the file
  static List<double> _extractPeaksFromFile(Map<String, dynamic> params) {
    final String path = params['path'];
    final int samples = params['samples'];
    final List<double> peaks = [];

    try {
      final file = File(path);
      final fileSize = file.lengthSync();
      if (fileSize < 1000) return _generateDeterministicPeaks(path, samples);

      // Skip initial ID3 header (approx first 4096 bytes) and trailer (last 4096 bytes)
      final startOffset = min(4096, fileSize ~/ 10);
      final usableBytes = max(1000, fileSize - startOffset - 4096);
      final step = usableBytes ~/ samples;
      final chunkSize = min(512, step);

      final randomAccess = file.openSync(mode: FileMode.read);
      double maxPeak = 0.001;

      for (int i = 0; i < samples; i++) {
        final offset = startOffset + (i * step);
        randomAccess.setPositionSync(offset);
        final Uint8List buffer = randomAccess.readSync(chunkSize);

        if (buffer.isEmpty) {
          peaks.add(0.1);
          continue;
        }

        // Calculate RMS / peak amplitude
        double sum = 0;
        for (int b = 0; b < buffer.length; b += 2) {
          int val;
          if (b + 1 < buffer.length) {
            val = (buffer[b] | (buffer[b + 1] << 8)).toSigned(16);
          } else {
            val = (buffer[b] - 128) * 256;
          }
          sum += (val * val);
        }
        final double rms = sqrt(sum / (buffer.length ~/ 2 + 1));
        if (rms > maxPeak) maxPeak = rms;
        peaks.add(rms);
      }

      randomAccess.closeSync();

      // Normalize peaks between 0.08 and 1.0
      return peaks.map((p) {
        final normalized = (p / maxPeak).clamp(0.08, 1.0);
        return double.parse(normalized.toStringAsFixed(3));
      }).toList();
    } catch (e) {
      return _generateDeterministicPeaks(path, samples);
    }
  }

  /// Generates a realistic musical waveform shape for fallback
  static List<double> _generateDeterministicPeaks(String seedStr, int samples) {
    final random = Random(seedStr.hashCode.abs());
    final List<double> peaks = [];
    double current = 0.4;

    for (int i = 0; i < samples; i++) {
      // Harmonic modulation + noise
      final harmonic = (sin(i / 10.0) * 0.25) + (sin(i / 3.0) * 0.15);
      final delta = (random.nextDouble() - 0.5) * 0.3;
      current = (current + delta + harmonic).clamp(0.12, 0.95);
      peaks.add(double.parse(current.toStringAsFixed(3)));
    }
    return peaks;
  }
}
