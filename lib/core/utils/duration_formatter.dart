class DurationFormatter {
  DurationFormatter._();

  /// Formats milliseconds to standard MM:SS or HH:MM:SS
  static String format(int milliseconds) {
    if (milliseconds < 0) milliseconds = 0;
    final duration = Duration(milliseconds: milliseconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Formats milliseconds to precision MM:SS.cc (hundredths of a second)
  /// As shown in Studio reference: 01:50.12
  static String formatPrecision(int milliseconds) {
    if (milliseconds < 0) milliseconds = 0;
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    final hundredths = ((milliseconds % 1000) / 10).floor();

    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${hundredths.toString().padLeft(2, '0')}';
  }

  /// Formats seconds double to timeline ruler notation: 02:00.00
  static String formatTimeline(double secondsTotal) {
    if (secondsTotal < 0) secondsTotal = 0;
    final minutes = (secondsTotal / 60).floor();
    final seconds = (secondsTotal % 60).floor();
    final hundredths = ((secondsTotal * 100) % 100).floor();

    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${hundredths.toString().padLeft(2, '0')}';
  }
}
