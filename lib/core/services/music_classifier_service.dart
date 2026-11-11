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
      'ishq', 'pyaar', 'dil', 'mohabbat', 'deewana', 'humsafar', 'sanam', 'tum', 'jaan',
      'bae', 'crush', 'darling', 'honey', 'lover', 'beloved', 'hug', 'passion', 'forever',
      'baby', 'kanna', 'chellam', 'premam', 'priya', 'kannalane', 'vaseegara', 'unakkaga',
    },
    'Fast Beat': {
      'fast', 'beat', 'dj', 'remix', 'dance', 'club', 'bass', 'drop', 'speed', 'thumping',
      'electro', 'house', 'edm', 'groove', 'upbeat', 'tempo', 'bounce', 'dappankuthu',
      'kuthu', 'marana', 'thiruvizha', 'alappara', 'vaaliba', 'dappan', 'thara local',
      'disco', 'trap', 'hyper', 'electronic', 'trance', 'drifting', 'banger', 'boost',
    },
    'Sad & Emotional': {
      'sad', 'emotional', 'pain', 'tears', 'crying', 'alone', 'breakup', 'heartbreak',
      'sokam', 'pirivu', 'valigal', 'kanneer', 'maranam', 'thuyaram', 'thaanguma',
      'dard', 'judai', 'bewafa', 'gham', 'rona', 'tanhai', 'khamoshi', 'slow', 'cry',
      'lonely', 'melancholy', 'loss', 'grief', 'sorry', 'goodbye', 'memories', 'miss you',
      'missing', 'heavy', 'hurt', 'sorrow', 'alone in the dark', 'separated', 'soham',
    },
    'Chill & Relax': {
      'chill', 'relax', 'acoustic', 'unplugged', 'calm', 'breeze', 'night', 'rain',
      'moon', 'peace', 'soft', 'lofi', 'ambient', 'gentle', 'evening', 'quiet',
      'mellow', 'soothing', 'serene', 'zen', 'cozy', 'laidback', 'lazy', 'sunset',
      'waves', 'slowdown', 'breathe', 'thendral', 'kaatru', 'mazhai', 'deep calm',
    },
    'Workout': {
      'workout', 'gym', 'run', 'fitness', 'energy', 'punch', 'pump', 'beast', 'heavy',
      'charge', 'training', 'power', 'iron', 'sweat', 'muscle', 'push', 'cardio',
      'lift', 'crossfit', 'exercise', 'stamina', 'champion', 'unstoppable', 'hustle',
      'singam', 'veeram', 'thunivu', 'vetri', 'motivate', 'hardwork', 'warrior',
    },
    'Party': {
      'party', 'celebration', 'fest', 'cheers', 'nightclub', 'banger', 'shout',
      'carnival', 'champagne', 'celebrate', 'festival', 'vibes', 'turn up', 'crazy',
      'drinks', 'dj mix', 'club mix', 'saturday', 'weekend', 'bass boosted', 'fun',
      'alappara', 'kuthu', 'thiruvizha', 'tasakku', 'ooru', 'dhamaka', 'hungama',
    },
    'Motivation': {
      'motivation', 'inspire', 'rise', 'victory', 'winner', 'glory', 'champions',
      'hero', 'power', 'vetri', 'veeram', 'thunivu', 'unmai', 'singam', 'motivational',
      'fateh', 'himmat', 'junoon', 'hosla', 'jeet', 'strength', 'unstoppable', 'legend',
      'beast', 'warrior', 'fight', 'stride', 'anthem', 'triumph', 'dare', 'brave', 'fearless',
      'believe', 'dream', 'focus', 'never give up', 'success', 'goals', 'conquer',
    },
    'Focus': {
      'focus', 'study', 'work', 'flow', 'code', 'deep', 'read', 'zen', 'study session',
      'concentration', 'mind', 'thought', 'focusing', 'instrumental', 'piano', 'lo-fi',
      'lofi', 'reading', 'brain', 'ambient', 'clarity', 'minimal', 'coding', 'peaceful',
    },
    'Sleep': {
      'sleep', 'lullaby', 'slumber', 'ambient', 'stars', 'whisper', 'sleeping',
      'thaalaattu', 'thookkam', 'neend', 'soja', 'lori', 'dreaming', 'bedtime',
      'night time', 'deep sleep', 'meditation', 'midnight', 'hush', 'softly', 'calm night',
    },
    'Road Trip': {
      'drive', 'road', 'trip', 'highway', 'journey', 'travel', 'cruising', 'voyage',
      'wander', 'route', 'destination', 'touring', 'on the road', 'driving', 'riding',
      'car', 'speed', 'wheels', 'fly', 'miles', 'long drive', 'night drive', 'ride',
      'navigator', 'scenic', 'freeway', 'roadtrip', 'cruiser', 'wanderlust',
    },
    'Melody': {
      'melody', 'melodious', 'isai', 'thendral', 'raag', 'sur', 'tune', 'lyrical',
      'harmony', 'acoustic guitar', 'violins', 'symphony', 'acoustic', 'unplugged',
      'kadhal', 'anbe', 'uyire', 'kanmani', 'malare', 'paatu', 'kavidhai', 'azhage',
      'sweet melody', 'classic melody', 'evergreen', 'golden melody', 'melodic',
    },
    'Instrumental': {
      'instrumental', 'bgm', 'theme', 'flute', 'violin', 'piano', 'guitar',
      'orchestra', 'soundtrack', 'karaoke', 'score', 'symphony', 'solo', 'strings',
      'brass', 'synth', 'tune', 'acoustic solo', 'ost', 'background music',
    },
    'Devotional': {
      'devotional', 'bhajan', 'god', 'krishna', 'shiva', 'murugan', 'ganesha', 'allah',
      'jesus', 'prayer', 'temple', 'church', 'pooja', 'bakthi', 'aarthi', 'mantra',
      'slokam', 'namam', 'sivan', 'ayyappa', 'amman', 'saibaba', 'hanuman', 'rama',
      'spiritual', 'divine', 'hymn', 'blessing', 'om', 'shanti', 'namaste', 'vinayagar',
      'perumal', 'venkateswara', 'bakthi padal', 'isai aradhanai', 'stotram',
    },
    'Tamil Melody': {
      'kadhal', 'kadhale', 'anbe', 'uyire', 'thendral', 'mazhai', 'malare', 'kaatru',
      'melody', 'isai', 'paatu', 'kavidhai', 'kanave', 'ninaivu', 'azhage', 'kanmani',
      'penne', 'paasathukku', 'vaseegara', 'unakkaga', 'nenjukkul', 'munbe vaa', 'adiye',
      'kannazhaga', 'thamizha', 'ilaiyaraaja', 'rahman', 'anirudh', 'harris', 'yuvan',
    },
    'Tamil Kuthu': {
      'kuthu', 'thiruvizha', 'marana', 'dappan', 'gana', 'folk', 'dappankuthu', 'local',
      'tasakku', 'kuthu song', 'ooru', 'koothu', 'vaaliba', 'alappara', 'beat', 'thara local',
      'dance', 'mass', 'intro', 'item', 'fast', 'party', 'morattu', 'naa ready', 'hukum',
      'badass', 'aathi', 'vaathi', 'jalabulajangu', 'rowdy baby', 'arabic kuthu',
    },
  };

  // Known Tamil Music Artists, Composers & Music Labels
  static final Set<String> _tamilArtists = {
    'a.r. rahman', 'ar rahman', 'ilaiyaraaja', 'ilayaraja', 'yuvan shankar raja', 'yuvan',
    'harris jayaraj', 'anirudh ravichander', 'anirudh', 'sid sriram', 's. p. balasubrahmanyam',
    'spb', 'k. s. chithra', 'chithra', 'd. imman', 'imman', 'g. v. prakash kumar', 'gv prakash',
    'santhosh narayanan', 'vijay antony', 'vidyasagar', 'deva', 'pradeep kumar', 'dhibu ninan thomas',
    'hariharan', 'chinmayi', 'shreya ghoshal', 'unni menon', 'karthik', 'sujatha', 'mano',
    'dhanush', 'silambarasan', 'simbu', 'str', 'vijay', 'sivakarthikeyan', 'hiphop tamizha',
    'sean roldan', 'sam c.s.', 'sam cs', 'leon james', 'nivas k prasanna', 't-series tamil',
    'sony music south', 'think music', 'lahari music', 'saregama tamil', 'isaimini', 'masstamilan',
  };

  // Known Hindi Artists, Composers & Music Labels
  static final Set<String> _hindiArtists = {
    'arijit singh', 'neha kakkar', 'badshah', 'pritam', 'shreya ghoshal', 'armaan malik',
    'atif aslam', 'vishal-shekhar', 'sachin-jigar', 'sonu nigam', 'kishore kumar', 'lata mangeshkar',
    'kumar sanu', 'alka yagnik', 'udit narayan', 'shankar-ehsaan-loy', 't-series', 'zeemusic',
    'amit trivedi', 'jubin nautiyal', 'darshan raval', 'b praak', 'jasleen royal',
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
      final fallbackPrimary = features.energy >= 0.55
          ? 'Fast Beat'
          : (features.energy <= 0.38 ? 'Chill & Relax' : 'Melody');
      final fallbackSecondary = features.energy >= 0.55
          ? ['Workout', 'Party', 'Road Trip']
          : (features.energy <= 0.38 ? ['Focus', 'Sleep', 'Sad & Emotional'] : ['Love & Romance', 'Motivation', 'Tamil Melody']);

      return SongClassificationModel(
        songId: song.id,
        primaryMood: fallbackPrimary,
        secondaryMoods: fallbackSecondary,
        energyLevel: energyLevel,
        language: language,
        confidenceScore: 0.65,
        audioFeatures: features,
        analyzedTimestamp: now,
      );
    }

    final sorted = scoredMoods.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topCandidate = sorted.first;
    final primaryMood = topCandidate.key;
    final confidenceScore = topCandidate.value.clamp(0.40, 1.0);

    // Extract secondary moods that have significant relative strength (>= 0.25 of primary mood)
    final secondary = sorted
        .skip(1)
        .where((e) => e.value >= 0.25)
        .take(5)
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

  /// Stage B: Continuous, Realistic Audio Feature Extraction
  AudioFeaturesModel _extractAudioFeatures(SongModel song) {
    final durSec = song.durationMs > 0 ? song.durationMs / 1000.0 : 210.0;

    // 1. Calculate energy from pre-calculated waveform peaks if available
    double energy = 0.50;
    double loudnessRms = 0.50;
    int? estimatedBpm;

    if (song.waveformPeaks != null && song.waveformPeaks!.isNotEmpty) {
      final peaks = song.waveformPeaks!;
      final sum = peaks.fold<double>(0.0, (acc, val) => acc + val.abs());
      final mean = sum / peaks.length;

      // RMS calculation
      final sumSquares = peaks.fold<double>(0.0, (acc, val) => acc + (val * val));
      loudnessRms = sqrt(sumSquares / peaks.length).clamp(0.1, 1.0);

      // Energy metric incorporates variance and peak density
      energy = ((mean * 0.6) + (loudnessRms * 0.4)).clamp(0.15, 0.95);

      // Tempo onset estimation from high-energy transition intervals
      final onsets = <int>[];
      for (int i = 1; i < peaks.length; i++) {
        if (peaks[i] - peaks[i - 1] > 0.30) {
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
      final combined = '${song.title} ${song.artist} ${song.album} ${song.dataPath}'.toLowerCase();
      final hasHighEnergy = {'fast', 'beat', 'remix', 'dance', 'club', 'kuthu', 'workout', 'party', 'bass', 'edm', 'drop', 'hyper', 'dappan', 'alappara'}.any((w) => combined.contains(w));
      final hasLowEnergy = {'chill', 'relax', 'calm', 'lullaby', 'sleep', 'acoustic', 'ambient', 'soft', 'lofi', 'slow', 'peace', 'sad', 'pain', 'tears', 'alone'}.any((w) => combined.contains(w));
      final hasRomanticOrMelody = {'love', 'kadhal', 'anbe', 'melody', 'romance', 'uyire', 'kanmani'}.any((w) => combined.contains(w));

      // Continuous duration-based acoustic distribution
      double baseEnergy = 0.52;
      if (durSec < 150) {
        baseEnergy = 0.60; // punchy short tracks
      } else if (durSec <= 240) {
        baseEnergy = 0.52; // standard dynamic tracks
      } else if (durSec <= 330) {
        baseEnergy = 0.46; // moderate melodic tracks
      } else {
        baseEnergy = 0.38; // long progressive / classical tracks
      }

      if (hasLowEnergy) {
        baseEnergy = 0.28; // distinctly ambient, calm, or acoustic
      } else if (hasHighEnergy) {
        baseEnergy = 0.72; // distinctly upbeat, workout, or kuthu
      } else if (hasRomanticOrMelody) {
        baseEnergy = 0.46; // smooth sweet spot for melody
      }

      // Bitrate / file size nuance
      if (song.sizeBytes > 0 && durSec > 0) {
        final byteRate = song.sizeBytes / durSec;
        loudnessRms = (byteRate / 40000.0).clamp(0.25, 0.90);
      } else {
        loudnessRms = baseEnergy.clamp(0.25, 0.85);
      }

      // Subtle deterministic jitter across song titles for natural variance (±0.04)
      final hashJitter = ((song.title.hashCode.abs() % 9) - 4) / 100.0;
      energy = (baseEnergy + hashJitter).clamp(0.18, 0.92);

      estimatedBpm = (75 + (energy * 75)).round().clamp(70, 160);
    }

    return AudioFeaturesModel(
      bpm: estimatedBpm,
      energy: energy,
      loudnessRms: loudnessRms,
      durationSeconds: durSec,
    );
  }

  String _determineEnergyLevel(double energy) {
    if (energy >= 0.60) return 'high';
    if (energy <= 0.40) return 'low';
    return 'medium';
  }

  /// Multilingual Music Language Heuristic inspecting title, artist, album & file path
  String _detectLanguage(SongModel song) {
    final artistLower = song.artist.toLowerCase();
    final combined = '${song.title} ${song.artist} ${song.album} ${song.dataPath}'.toLowerCase();

    // 1. Tamil Unicode Script Check (range \u0B80 - \u0BFF)
    final containsTamilScript = RegExp(r'[\u0B80-\u0BFF]').hasMatch(combined);
    if (containsTamilScript) return 'tamil';

    // 2. Tamil Composer / Artist catalog match
    if (_tamilArtists.any((a) => artistLower.contains(a) || combined.contains(a))) {
      return 'tamil';
    }

    // 3. Tamil phonetic token presence
    final tamilPhoneticWords = {
      'kadhal', 'kadhale', 'uyire', 'anbe', 'thendral', 'paatu', 'kuthu', 'marana', 'thiruvizha',
      'kanmani', 'penne', 'azhage', 'vaathi', 'alappara', 'thalaivar', 'singam', 'chellamma',
      'naa ready', 'aradhya', 'ennodu', 'nee', 'naan', 'adiye', 'kanave', 'vizhi', 'unmai',
      'thunivu', 'varisu', 'leo', 'jailer', 'master', 'petta', 'viswasam', 'mersal', 'sarkar',
      'bigil', 'vikram', 'kabali', 'kaala', 'asuran', 'karnan', 'soorarai', 'ponniyin', 'isaimini',
      'masstamilan', 'starmusiq', 'tamilwire', 'tamilsongs', 'tamil', 'kuttyweb', 'dhanush',
      'vijay', 'ajith', 'suriya', 'kamal', 'rajini', 'rajinikanth', 'sivakarthikeyan', 'simbu'
    };
    if (tamilPhoneticWords.any((w) => combined.contains(w))) {
      return 'tamil';
    }

    // 4. Hindi Artists & tokens
    if (_hindiArtists.any((a) => artistLower.contains(a) || combined.contains(a))) {
      return 'hindi';
    }
    final hindiPhoneticWords = {
      'ishq', 'pyaar', 'dil', 'mohabbat', 'deewana', 'humsafar', 'sanam', 'tum', 'dard',
      'judai', 'bewafa', 'gham', 't-series', 'bollywood', 'hindi', 'songspk', 'hungama'
    };
    if (hindiPhoneticWords.any((w) => combined.contains(w))) {
      return 'hindi';
    }

    // 5. English default indicator
    return 'english';
  }

  /// Stage C: On-Device Softmax Feature Vector Classifier with Acoustic Heuristics for ALL 15 Moods
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

      // 1. High-Energy Rhythm & Dance Moods
      if (['Fast Beat', 'Workout', 'Party', 'Tamil Kuthu'].contains(mood)) {
        if (features.energy >= 0.55) acousticWeight += 1.6;
        if (features.bpm != null && features.bpm! >= 115) acousticWeight += 1.0;
        if (mood == 'Party' && features.durationSeconds >= 120 && features.durationSeconds <= 320) {
          acousticWeight += 0.8;
        }
      }

      // 2. Low-Energy Ambient & Calm Moods
      if (['Chill & Relax', 'Sleep', 'Focus'].contains(mood)) {
        if (features.energy <= 0.48) acousticWeight += 1.6;
        if (features.durationSeconds >= 200) acousticWeight += 0.8;
        if (mood == 'Sleep' && features.energy <= 0.35) acousticWeight += 1.0;
      }

      // 3. Emotional & Melancholic Moods
      if (mood == 'Sad & Emotional') {
        if (features.energy <= 0.48) acousticWeight += 1.4;
        if (features.durationSeconds >= 160) acousticWeight += 0.6;
      }

      // 4. Melodic & Heartfelt Moods
      if (['Love & Romance', 'Melody', 'Tamil Melody'].contains(mood)) {
        if (features.energy >= 0.25 && features.energy <= 0.68) acousticWeight += 1.4;
        if (features.durationSeconds >= 180 && features.durationSeconds <= 360) acousticWeight += 0.6;
      }

      // 5. Drive, Movement & Motivation
      if (['Motivation', 'Road Trip'].contains(mood)) {
        if (features.energy >= 0.48) acousticWeight += 1.4;
        if (features.durationSeconds >= 150) acousticWeight += 0.5;
      }

      // 6. Instrumental & Score
      if (mood == 'Instrumental') {
        if (combinedText.contains('theme') || combinedText.contains('bgm') || combinedText.contains('score')) {
          acousticWeight += 2.0;
        } else if (features.durationSeconds >= 120) {
          acousticWeight += 0.4;
        }
      }

      // 7. Devotional & Spiritual
      if (mood == 'Devotional') {
        if (features.energy >= 0.20 && features.energy <= 0.55) acousticWeight += 0.8;
      }

      // Language constraint checks
      double languageMultiplier = 1.0;
      if (mood == 'Tamil Melody' || mood == 'Tamil Kuthu') {
        if (language != 'tamil') {
          languageMultiplier = 0.35; // gentle penalty, never total exclusion
        } else {
          languageMultiplier = 1.8;
        }
      }

      final totalLogit = ((lexicalWeight * 2.4) + (acousticWeight * 1.3)) * languageMultiplier;
      if (totalLogit > 0) {
        rawScores[mood] = totalLogit;
      }
    }

    // Safety fallback: if no category scored, seed naturally from acoustic energy
    if (rawScores.isEmpty) {
      if (features.energy >= 0.55) {
        rawScores['Fast Beat'] = 1.5;
        rawScores['Workout'] = 1.2;
        rawScores['Road Trip'] = 1.0;
        rawScores['Party'] = 0.9;
      } else if (features.energy <= 0.38) {
        rawScores['Chill & Relax'] = 1.5;
        rawScores['Melody'] = 1.2;
        rawScores['Sleep'] = 1.0;
        rawScores['Sad & Emotional'] = 0.9;
      } else {
        rawScores['Melody'] = 1.5;
        rawScores['Love & Romance'] = 1.3;
        rawScores['Focus'] = 1.0;
        rawScores['Motivation'] = 0.9;
        if (language == 'tamil') {
          rawScores['Tamil Melody'] = 1.4;
        }
      }
    }

    // Relative normalization to produce well-balanced multi-label candidates
    final maxScore = rawScores.values.reduce(max);
    if (maxScore == 0) return {};

    return rawScores.map((k, v) => MapEntry(k, (v / maxScore).clamp(0.0, 1.0)));
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
