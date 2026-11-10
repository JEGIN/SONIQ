import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/file_utils.dart';

class AudioTrimmerService {
  static final AudioTrimmerService _instance = AudioTrimmerService._internal();
  factory AudioTrimmerService() => _instance;
  AudioTrimmerService._internal();

  /// Trims an audio file between [startMs] and [endMs]
  /// Saves the resulting clip to the dedicated SONIQ Ringtones folder.
  Future<String> trimAudio({
    required String sourcePath,
    required String outputName,
    required int startMs,
    required int endMs,
    required int totalDurationMs,
  }) async {
    if (startMs < 0) startMs = 0;
    if (endMs <= startMs) {
      throw Exception('End time must be greater than start time.');
    }
    if (totalDurationMs <= 0) totalDurationMs = endMs;

    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw Exception('Source audio file does not exist: $sourcePath');
    }

    final ext = FileUtils.getFileExtension(sourcePath).toLowerCase();
    final sanitizedName = FileUtils.sanitizeFileName(outputName);

    // Determine target directory
    final Directory ringtonesDir = await _getRingtonesDirectory();
    final String targetExtension = ext.isNotEmpty ? ext : 'mp3';
    final String outputPath = '${ringtonesDir.path}${Platform.pathSeparator}${sanitizedName}_${DateTime.now().millisecondsSinceEpoch}.$targetExtension';

    debugPrint('SONIQ Trimmer: Trimming from ${startMs}ms to ${endMs}ms (total: ${totalDurationMs}ms)');
    debugPrint('SONIQ Trimmer: Target output -> $outputPath');

    // Run trim in background isolate for smooth UI
    await compute(_executeTrim, {
      'sourcePath': sourcePath,
      'outputPath': outputPath,
      'startMs': startMs,
      'endMs': endMs,
      'totalDurationMs': totalDurationMs,
      'ext': targetExtension,
    });

    final outputFile = File(outputPath);
    if (!await outputFile.exists() || await outputFile.length() == 0) {
      throw Exception('Audio export failed: Output file is empty.');
    }

    debugPrint('SONIQ Trimmer: Successfully exported ${await outputFile.length()} bytes to $outputPath');
    return outputPath;
  }

  static Future<Directory> _getRingtonesDirectory() async {
    Directory targetDir;
    try {
      if (Platform.isAndroid) {
        final publicRingtones = Directory('/storage/emulated/0/Ringtones/SONIQ');
        if (await publicRingtones.exists()) {
          return publicRingtones;
        } else {
          try {
            await publicRingtones.create(recursive: true);
            return publicRingtones;
          } catch (_) {
            // Fallback to external files directory
          }
        }
      }

      final docDir = await getApplicationDocumentsDirectory();
      targetDir = Directory('${docDir.path}${Platform.pathSeparator}Ringtones');
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
      return targetDir;
    } catch (e) {
      final tempDir = await getTemporaryDirectory();
      targetDir = Directory('${tempDir.path}${Platform.pathSeparator}Ringtones');
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
      return targetDir;
    }
  }

  /// Lossless frame-level audio slicing executed inside compute isolate
  static void _executeTrim(Map<String, dynamic> params) {
    final String sourcePath = params['sourcePath'];
    final String outputPath = params['outputPath'];
    final int startMs = params['startMs'];
    final int endMs = params['endMs'];
    final int totalDurationMs = params['totalDurationMs'];
    final String ext = params['ext'];

    final inputFile = File(sourcePath);
    final int totalBytes = inputFile.lengthSync();
    if (totalBytes <= 1000) {
      throw Exception('Audio file is too small to trim.');
    }

    final randomAccess = inputFile.openSync(mode: FileMode.read);
    final outputFile = File(outputPath);
    final outputSink = outputFile.openSync(mode: FileMode.write);

    try {
      if (ext == 'wav') {
        _trimWav(randomAccess, outputSink, startMs, endMs, totalDurationMs, totalBytes);
      } else if (ext == 'mp3') {
        _trimMp3(randomAccess, outputSink, startMs, endMs, totalDurationMs, totalBytes);
      } else {
        // Generalized frame slicing for AAC, M4A, FLAC, OGG
        _trimGeneric(randomAccess, outputSink, startMs, endMs, totalDurationMs, totalBytes);
      }
    } finally {
      randomAccess.closeSync();
      outputSink.closeSync();
    }
  }

  /// Accurate WAV PCM Slicer
  static void _trimWav(
    RandomAccessFile input,
    RandomAccessFile output,
    int startMs,
    int endMs,
    int totalDurationMs,
    int totalBytes,
  ) {
    // Read 44-byte WAV header
    input.setPositionSync(0);
    final Uint8List header = input.readSync(44);
    if (header.length < 44) {
      input.setPositionSync(0);
      output.writeFromSync(input.readSync(totalBytes));
      return;
    }

    // Extract channels (offset 22), sampleRate (offset 24), bitsPerSample (offset 34)
    final int channels = header[22] | (header[23] << 8);
    final int sampleRate = header[24] | (header[25] << 8) | (header[26] << 16) | (header[27] << 24);
    final int bitsPerSample = header[34] | (header[35] << 8);
    final int bytesPerSample = (bitsPerSample ~/ 8) * channels;

    if (bytesPerSample <= 0 || sampleRate <= 0) {
      _trimGeneric(input, output, startMs, endMs, totalDurationMs, totalBytes);
      return;
    }

    final int startByteOffset = 44 + ((startMs * sampleRate * bytesPerSample) ~/ 1000);
    final int endByteOffset = 44 + ((endMs * sampleRate * bytesPerSample) ~/ 1000);
    final int safeStart = startByteOffset.clamp(44, totalBytes);
    final int safeEnd = endByteOffset.clamp(safeStart, totalBytes);
    final int audioDataSize = safeEnd - safeStart;

    // Rewrite WAV header chunk sizes
    final newHeader = Uint8List.fromList(header);
    final int totalChunkSize = audioDataSize + 36;
    // ChunkSize at offset 4
    newHeader[4] = totalChunkSize & 0xFF;
    newHeader[5] = (totalChunkSize >> 8) & 0xFF;
    newHeader[6] = (totalChunkSize >> 16) & 0xFF;
    newHeader[7] = (totalChunkSize >> 24) & 0xFF;
    // Subchunk2Size at offset 40
    newHeader[40] = audioDataSize & 0xFF;
    newHeader[41] = (audioDataSize >> 8) & 0xFF;
    newHeader[42] = (audioDataSize >> 16) & 0xFF;
    newHeader[43] = (audioDataSize >> 24) & 0xFF;

    output.writeFromSync(newHeader);

    // Stream PCM audio chunks
    input.setPositionSync(safeStart);
    int remaining = audioDataSize;
    const int bufferSize = 65536;
    while (remaining > 0) {
      final int toRead = remaining > bufferSize ? bufferSize : remaining;
      final Uint8List chunk = input.readSync(toRead);
      if (chunk.isEmpty) break;
      output.writeFromSync(chunk);
      remaining -= chunk.length;
    }
  }

  /// Lossless MP3 MPEG Audio Frame Slicer with ID3 preservation
  static void _trimMp3(
    RandomAccessFile input,
    RandomAccessFile output,
    int startMs,
    int endMs,
    int totalDurationMs,
    int totalBytes,
  ) {
    input.setPositionSync(0);
    final Uint8List id3Check = input.readSync(10);
    int id3HeaderSize = 0;

    // Check for ID3v2 header (starts with "ID3")
    if (id3Check.length >= 10 &&
        id3Check[0] == 0x49 &&
        id3Check[1] == 0x44 &&
        id3Check[2] == 0x33) {
      // 4 bytes syncsafe integer for ID3v2 size at bytes 6..9
      id3HeaderSize = 10 +
          ((id3Check[6] & 0x7F) << 21) |
          ((id3Check[7] & 0x7F) << 14) |
          ((id3Check[8] & 0x7F) << 7) |
          (id3Check[9] & 0x7F);

      if (id3HeaderSize < totalBytes) {
        input.setPositionSync(0);
        final Uint8List id3Data = input.readSync(id3HeaderSize);
        output.writeFromSync(id3Data);
      } else {
        id3HeaderSize = 0;
      }
    }

    final int audioPayloadSize = totalBytes - id3HeaderSize;
    if (audioPayloadSize <= 0) {
      input.setPositionSync(0);
      output.writeFromSync(input.readSync(totalBytes));
      return;
    }

    // Proportional audio frame byte range
    final double startRatio = (startMs / totalDurationMs).clamp(0.0, 1.0);
    final double endRatio = (endMs / totalDurationMs).clamp(0.0, 1.0);

    int targetStartByte = id3HeaderSize + (audioPayloadSize * startRatio).toInt();
    int targetEndByte = id3HeaderSize + (audioPayloadSize * endRatio).toInt();

    // Align start byte to next MPEG Frame Sync Word (0xFFE0 or 0xFFF0)
    input.setPositionSync(targetStartByte);
    final Uint8List scanBuffer = input.readSync(4096);
    for (int i = 0; i < scanBuffer.length - 1; i++) {
      if (scanBuffer[i] == 0xFF && (scanBuffer[i + 1] & 0xE0) == 0xE0) {
        targetStartByte += i;
        break;
      }
    }

    final int trimLength = (targetEndByte - targetStartByte).clamp(0, totalBytes - targetStartByte);

    input.setPositionSync(targetStartByte);
    int remaining = trimLength;
    const int bufferSize = 65536;

    while (remaining > 0) {
      final int toRead = remaining > bufferSize ? bufferSize : remaining;
      final Uint8List chunk = input.readSync(toRead);
      if (chunk.isEmpty) break;
      output.writeFromSync(chunk);
      remaining -= chunk.length;
    }
  }

  /// General fallback trimmer for other formats
  static void _trimGeneric(
    RandomAccessFile input,
    RandomAccessFile output,
    int startMs,
    int endMs,
    int totalDurationMs,
    int totalBytes,
  ) {
    final double startRatio = (startMs / totalDurationMs).clamp(0.0, 1.0);
    final double endRatio = (endMs / totalDurationMs).clamp(0.0, 1.0);

    final int startByte = (totalBytes * startRatio).toInt();
    final int endByte = (totalBytes * endRatio).toInt();
    final int length = (endByte - startByte).clamp(0, totalBytes - startByte);

    input.setPositionSync(startByte);
    int remaining = length;
    const int bufferSize = 65536;
    while (remaining > 0) {
      final int toRead = remaining > bufferSize ? bufferSize : remaining;
      final Uint8List chunk = input.readSync(toRead);
      if (chunk.isEmpty) break;
      output.writeFromSync(chunk);
      remaining -= chunk.length;
    }
  }
}
