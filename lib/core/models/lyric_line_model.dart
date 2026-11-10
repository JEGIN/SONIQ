class LyricLine {
  final Duration timestamp;
  final String text;
  final bool isTimestamped;

  const LyricLine({
    required this.timestamp,
    required this.text,
    this.isTimestamped = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestampMs': timestamp.inMilliseconds,
      'text': text,
      'isTimestamped': isTimestamped,
    };
  }

  factory LyricLine.fromMap(Map<String, dynamic> map) {
    return LyricLine(
      timestamp: Duration(milliseconds: (map['timestampMs'] as num?)?.toInt() ?? 0),
      text: map['text'] as String? ?? '',
      isTimestamped: map['isTimestamped'] as bool? ?? true,
    );
  }

  /// Parses an LRC format string into a sorted list of LyricLines
  static List<LyricLine> parseLrc(String lrcContent) {
    final lines = lrcContent.split('\n');
    final List<LyricLine> parsed = [];
    final timeRegex = RegExp(r'\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]');

    bool hasAnyTimestamp = false;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      // Check for metadata tags like [ti:Title], [ar:Artist], [al:Album]
      if (line.startsWith('[ti:') ||
          line.startsWith('[ar:') ||
          line.startsWith('[al:') ||
          line.startsWith('[by:') ||
          line.startsWith('[offset:')) {
        continue;
      }

      final matches = timeRegex.allMatches(line);
      if (matches.isNotEmpty) {
        hasAnyTimestamp = true;
        final text = line.replaceAll(timeRegex, '').trim();

        for (final match in matches) {
          final minutes = int.parse(match.group(1)!);
          final seconds = int.parse(match.group(2)!);
          final millisStr = match.group(3) ?? '0';
          // Convert 2-digit (hundredths) or 3-digit (milliseconds)
          final millis = millisStr.length == 2
              ? int.parse(millisStr) * 10
              : int.parse(millisStr.padRight(3, '0').substring(0, 3));

          final duration = Duration(
            minutes: minutes,
            seconds: seconds,
            milliseconds: millis,
          );

          parsed.add(LyricLine(
            timestamp: duration,
            text: text,
            isTimestamped: true,
          ));
        }
      } else {
        // Plain untimed line
        parsed.add(LyricLine(
          timestamp: Duration.zero,
          text: line,
          isTimestamped: false,
        ));
      }
    }

    if (hasAnyTimestamp) {
      parsed.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }

    return parsed;
  }
}
