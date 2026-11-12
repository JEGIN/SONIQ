import 'dart:io';

import 'package:intl/intl.dart';

class FileUtils {
  FileUtils._();

  static const List<String> supportedAudioExtensions = [
    'mp3',
    'm4a',
    'aac',
    'wav',
    'flac',
    'ogg',
  ];

  static bool isSupportedAudioFile(String path) {
    final ext = getFileExtension(path).toLowerCase();
    return supportedAudioExtensions.contains(ext);
  }

  static String getFileExtension(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == path.length - 1) return '';
    return path.substring(dotIndex + 1);
  }

  static String getFileNameWithoutExtension(String path) {
    final name = path.split(Platform.pathSeparator).last;
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex == -1) return name;
    return name.substring(0, dotIndex);
  }

  static String sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  }

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    int i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${NumberFormat('0.0').format(size)} ${suffixes[i]}';
  }
}
