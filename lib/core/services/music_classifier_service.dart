import 'dart:math';
import '../models/song_model.dart';
import '../models/song_classification_model.dart';

class MusicClassifierService {
  static final MusicClassifierService _instance = MusicClassifierService._internal();
  factory MusicClassifierService() => _instance;
  MusicClassifierService._internal();

  // Standard Target Categories
  static const List<String> availableMoods = [
    'Love & Romance',
    'Fast Beat',
    'Sad & Emotional',
    'Chill & Relax',
    'Workout',
    'Party',
    'Motivation',
    'Focus',
    'Sleep',
    'Road Trip',
    'Melody',
    'Instrumental',
    'Devotional',
    'Tamil Melody',
    'Tamil Kuthu',
    'Recently Added',
    'Most Played',
    'Favorites Mix',
  ];

  // Lexical Keyword Lexicons for Stage A Analysis
  static final Map<String, Set<String>> _moodLexicons = {
    'Love & Romance': {
      'love', 'romance', 'romantic', 'heart', 'kiss', 'couple', 'valentine', 'sweetheart',
      'kadhal', 'kadhale', 'anbe', 'uyire', 'kanmani', 'penne', 'azhage', 'paasathukku',
      'ishq', 'pyaar', 'dil', 'mohabbat', 'deewana', 'humsafar', 'sanam', 'tum',
    },
    'Fast Beat': {
      'fast', 'beat', 'dj', 'remix', 'dance', 'club', 'bass', 'drop', 'speed', 'thumping',
      'electro', 'house', 'edm', 'groove', 'upbeat', 'tempo', 'bounce',
    },
    'Sad & Emotional': {
      'sad', 'emotional', 'pain', 'tears', 'crying', 'alone', 'breakup', 'heartbreak',
      'sokam', 'pirivu', 'valigal', 'kanneer', 'maranam', 'thuyaram', 'thaanguma',
      'dard', 'judai', 'bewafa', 'gham', 'rona', 'tanhai', 'khamoshi',
    },
    'Chill & Relax': {
      'chill', 'relax', 'acoustic', 'unplugged', 'calm', 'breeze', 'night', 'rain',
      'moon', 'peace', 'soft', 'lofi', 'ambient', 'gentle', 'evening', 'quiet',
    },
    'Workout': {
      'workout', 'gym', 'run', 'fitness', 'energy', 'punch', 'pump', 'beast', 'heavy',
      'charge', 'training', 'power', 'iron', 'sweat', 'muscle',
    },
    'Party': {
      'party', 'celebration', 'fest', 'cheers', 'nightclub', 'banger', 'shout',
      'carnival', 'champagne', 'celebrate', 'festival', 'vibes',
    },
    'Motivation': {
      'motivation', 'inspire', 'rise', 'victory', 'winner', 'glory', 'champions',
      'hero', 'power', 'vetri', 'veeram', 'thunivu', 'unmai', 'singam',
      'fateh', 'himmat', 'junoon', 'hosla', 'jeet',
    },
    'Focus': {
      'focus', 'study', 'work', 'flow', 'code', 'deep', 'read', 'zen', 'study session',
      'concentration', 'mind', 'thought', 'focusing',
    },
    'Sleep': {
      'sleep', 'lullaby', 'slumber', 'ambient', 'stars', 'whisper', 'sleeping',
      'thaalaattu', 'thookkam', 'neend', 'soja', 'lori',
    },
    'Road Trip': {
      'drive', 'road', 'trip', 'highway', 'journey', 'travel', 'cruising', 'voyage',
      'wander', 'route', 'destination', 'touring', 'on the road', 'driving',
    },
    'Melody': {
      'melody', 'melodious', 'isai', 'thendral', 'raag', 'sur', 'tune', 'lyrical',
      'harmony', 'acoustic guitar', 'violins', 'symphony',
    },
    'Instrumental': {
      'instrumental', 'bgm', 'theme', 'flute', 'violin', 'piano', 'guitar',
      'orchestra', 'soundtrack', 'karaoke', 'score',
    },
    'Devotional': {
      'devotional', 'bhajan', 'god', 'krishna', 'shiva', 'murugan', 'ganesha', 'allah',
      'jesus', 'prayer', 'temple', 'church', 'pooja', 'bakthi', 'aarthi', 'mantra',
      'slokam', 'namam', 'sivan', 'ayyappa', 'amman', 'saibaba',
    },
    'Tamil Melody': {
      'kadhal', 'kadhale', 'anbe', 'uyire', 'thendral', 'mazhai', 'malare', 'kaatru',
      'melody', 'isai', 'paatu', 'kavidhai', 'kanave', 'ninaivu', 'azhage',
    },
    'Tamil Kuthu': {
      'kuthu', 'thiruvizha', 'marana', 'dappan', 'gana', 'folk', 'dappankuthu', 'local',
      'tasakku', 'kuthu song', 'ooru', 'koothu', 'vaaliba', 'alappara', 'beat',
    },
  };

  // Known Tamil Music Artists & Composers
  static final Set<String> _tamilArtists = {
    'a.r. rahman', 'ar rahman', 'ilaiyaraaja', 'ilayaraja', 'yuvan shankar raja', 'yuvan',
    'harris jayaraj', 'anirudh ravichander', 'anirudh', 'sid sriram', 's. p. balasubrahmanyam',
    'spb', 'k. s. chithra', 'chithra', 'd. imman', 'imman', 'g. v. prakash kumar', 'gv prakash',
    'santhosh narayanan', 'vijay antony', 'vidyasagar', 'deva', 'pradeep kumar', 'dhibu ninan thomas',
    'hariharan', 'chinmayi', 'shreya ghoshal', 'unni menon', 'karthik', 'sujatha', 'mano',
  };

  // Known Hindi Artists & Composers
  static final Set<String> _hindiArtists = {
    'arijit singh', 'neha kakkar', 'badshah', 'pritam', 'shreya ghoshal', 'armaan malik',
    'atif aslam', 'vishal-shekhar', 'sachin-jigar', 'sonu nigam', 'kishore kumar', 'lata mangeshkar',
    'kumar sanu', 'alka yagnik', 'udit narayan', 'shankar-ehsaan-loy',
  };

  /// Stage A + B + C: Progressive Music Classification Pipeline
  SongClassificationModel classifySong(
    SongModel song, {
    SongClassificationModel? existing,
  }) {
    // 0. User manual correction takes absolute priority
    if (existing != null && existing.isUserCorrected) {
      return existing;
    }

    final now = DateTime.now().millisecondsSinceEpoch;

    // Stage B: Audio Signal & Feature Extraction
    final features = _extractAudioFeatures(song);
    final energyLevel = _determineEnergyLevel(features.energy);

    // Language Detection Heuristic
    final language = _detectLanguage(song);

    // Stage A & C: On-Device Softmax Feature Vector Classifier
    final scoredMoods = _evaluateMoodScores(song, features, language);

    if (scoredMoods.isEmpty) {
      return SongClassificationModel(
        songId: song.id,
        primaryMood: 'Unclassified',
        secondaryMoods: [],
        energyLevel: energyLevel,
        language: language,
        confidenceScore: 0.25,
        audioFeatures: features,
        analyzedTimestamp: now,
      );
    }

    final sorted = scoredMoods.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topCandidate = sorted.first;
    final primaryMood = topCandidate.key;
    final confidenceScore = topCandidate.value.clamp(0.0, 1.0);

    // Extract secondary moods that have significant probability (> 0.08)
    final secondary = sorted
        .skip(1)
        .where((e) => e.value >= 0.08)
        .take(3)
        .map((e) => e.key)
        .toList();

    return SongClassificationModel(
      songId: song.id,
      primaryMood: primaryMood,
      secondaryMoods: secondary,
      energyLevel: energyLevel,
      language: language,
      confidenceScore: confidenceScore,
      audioFeatures: features,
      analyzedTimestamp: now,
    );
  }

  /// Stage B: Audio Feature Extraction
  AudioFeaturesModel _extractAudioFeatures(SongModel song) {
    final durSec = song.durationMs / 1000.0;

    // 1. Calculate energy from pre-calculated waveform peaks if available
    double energy = 0.5;
    double loudnessRms = 0.5;
    int? estimatedBpm;

    if (song.waveformPeaks != null && song.waveformPeaks!.isNotEmpty) {
      final peaks = song.waveformPeaks!;
      final sum = peaks.fold<double>(0.0, (acc, val) => acc + val.abs());
      final mean = sum / peaks.length;

      // RMS calculation
      final sumSquares = peaks.fold<double>(0.0, (acc, val) => acc + (val * val));
      loudnessRms = sqrt(sumSquares / peaks.length).clamp(0.0, 1.0);

      // Energy metric incorporates variance and peak density
      energy = ((mean * 0.6) + (loudnessRms * 0.4)).clamp(0.0, 1.0);

      // Simple tempo onset estimation from high-energy transition intervals
      final onsets = <int>[];
      for (int i = 1; i < peaks.length; i++) {
        if (peaks[i] - peaks[i - 1] > 0.35) {
          onsets.add(i);
        }
      }
      if (onsets.length >= 4 && durSec > 0) {
        final avgIntervalSeconds = durSec / onsets.length;
        if (avgIntervalSeconds > 0) {
          final rawBpm = (60.0 / avgIntervalSeconds).round();
          estimatedBpm = rawBpm.clamp(70, 165);
        }
      }
    } else {
      final textLower = '${song.title} ${song.artist} ${song.album}'.toLowerCase();
      final hasHighEnergy = {'fast', 'beat', 'remix', 'dance', 'club', 'kuthu', 'workout', 'party'}.any((w) => textLower.contains(w));
      final hasLowEnergy = {'chill', 'relax', 'calm', 'lullaby', 'sleep', 'acoustic', 'ambient', 'soft'}.any((w) => textLower.contains(w));

      if (hasHighEnergy) {
        energy = 0.80;
        loudnessRms = 0.75;
        estimatedBpm = 132;
      } else if (hasLowEnergy) {
        energy = 0.25;
        loudnessRms = 0.35;
        estimatedBpm = 75;
      } else if (song.sizeBytes > 0 && durSec > 0) {
        final byteRate = song.sizeBytes / durSec; // ~32000 for 256kbps, ~16000 for 128kbps
        final isPunchyDuration = durSec >= 160 && durSec <= 260;
        energy = isPunchyDuration ? 0.60 : (durSec > 320 ? 0.38 : 0.50);
        loudnessRms = (byteRate / 40000.0).clamp(0.3, 0.85);
      }
    }

    return AudioFeaturesModel(
      bpm: estimatedBpm,
      energy: energy,
      loudnessRms: loudnessRms,
      durationSeconds: durSec,
    );
  }

  String _determineEnergyLevel(double energy) {
    if (energy >= 0.65) return 'high';
    if (energy <= 0.35) return 'low';
    return 'medium';
  }

  /// Multilingual Music Language Heuristic
  String _detectLanguage(SongModel song) {
    final titleLower = song.title.toLowerCase();
    final artistLower = song.artist.toLowerCase();

    // 1. Tamil Unicode Script Check (range \u0B80 - \u0BFF)
    final containsTamilScript = RegExp(r'[\u0B80-\u0BFF]').hasMatch(song.title);
    if (containsTamilScript) return 'tamil';

    // 2. Tamil Composer / Artist catalog match
    if (_tamilArtists.any((a) => artistLower.contains(a))) {
      return 'tamil';
    }

    // 3. Tamil phonetic token presence
    final tamilPhoneticWords = {'kadhal', 'kadhale', 'uyire', 'anbe', 'thendral', 'paatu', 'kuthu', 'marana', 'thiruvizha'};
    if (tamilPhoneticWords.any((w) => titleLower.contains(w))) {
      return 'tamil';
    }

    // 4. Hindi Artists
    if (_hindiArtists.any((a) => artistLower.contains(a))) {
      return 'hindi';
    }

    // 5. English default indicator
    return 'english';
  }

  /// Stage C: On-Device Softmax Feature Vector Classifier
  Map<String, double> _evaluateMoodScores(
    SongModel song,
    AudioFeaturesModel features,
    String language,
  ) {
    final rawScores = <String, double>{};
    final combinedText = '${song.title} ${song.artist} ${song.album} ${song.dataPath}'.toLowerCase();

    // Iterate over all target categories
    for (final mood in _moodLexicons.keys) {
      final keywords = _moodLexicons[mood]!;
      double lexicalWeight = 0.0;

      for (final kw in keywords) {
        if (combinedText.contains(kw)) {
          lexicalWeight += 1.0;
        }
      }

      double acousticWeight = 0.0;
      // Acoustic & rhythmic energy matching
      if (['Fast Beat', 'Workout', 'Party', 'Tamil Kuthu'].contains(mood)) {
        if (features.energy >= 0.60) acousticWeight += 1.5;
        if (features.bpm != null && features.bpm! >= 120) acousticWeight += 1.0;
      }
      if (['Chill & Relax', 'Sleep', 'Focus'].contains(mood)) {
        if (features.energy <= 0.40) acousticWeight += 1.5;
        if (features.durationSeconds >= 240) acousticWeight += 0.8;
      }
      if (['Love & Romance', 'Melody', 'Tamil Melody'].contains(mood)) {
        if (features.energy >= 0.30 && features.energy <= 0.65) acousticWeight += 1.0;
      }

      // Language constraint checks
      double languageMultiplier = 1.0;
      if (mood == 'Tamil Melody' || mood == 'Tamil Kuthu') {
        if (language != 'tamil') {
          languageMultiplier = 0.1;
        } else {
          languageMultiplier = 1.5;
        }
      }

      final totalLogit = ((lexicalWeight * 2.2) + (acousticWeight * 1.4)) * languageMultiplier;
      if (totalLogit > 0) {
        rawScores[mood] = totalLogit;
      }
    }

    if (rawScores.isEmpty) return {};

    // Softmax normalization to compute genuine probabilities
    final maxLogit = rawScores.values.reduce(max);
    final expScores = <String, double>{};
    double sumExp = 0.0;

    for (final entry in rawScores.entries) {
      final expVal = exp(entry.value - maxLogit);
      expScores[entry.key] = expVal;
      sumExp += expVal;
    }

    if (sumExp == 0) return {};

    return expScores.map((k, v) => MapEntry(k, v / sumExp));
  }

  /// User manual mood correction with confidence 1.0
  SongClassificationModel applyUserCorrection({
    required String songId,
    required SongClassificationModel current,
    required String newMood,
    List<String> userTags = const [],
  }) {
    return SongClassificationModel(
      songId: songId,
      primaryMood: newMood,
      secondaryMoods: current.secondaryMoods,
      energyLevel: current.energyLevel,
      language: current.language,
      confidenceScore: 1.0,
      isUserCorrected: true,
      userTags: userTags.isNotEmpty ? userTags : current.userTags,
      audioFeatures: current.audioFeatures,
      analyzedTimestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }
}
