import 'dart:math';
import 'package:flutter/material.dart';
import '../database/song_cache_service.dart';
import '../models/song_model.dart';
import '../models/playback_event_model.dart';
import '../models/playlist_model.dart';
import '../models/recommendation_model.dart';
import 'music_classifier_service.dart';

class MusicDiscoveryService {
  static final MusicDiscoveryService _instance = MusicDiscoveryService._internal();
  factory MusicDiscoveryService() => _instance;
  MusicDiscoveryService._internal();

  final SongCacheService _cacheService = SongCacheService();
  final MusicClassifierService _classifierService = MusicClassifierService();

  // In-memory cache for fast repeated queries
  List<RecommendationMix>? _cachedDailyMixes;
  int _lastDailyMixesGeneratedMs = 0;
  static const int _cacheTtlMs = 15 * 60 * 1000; // 15 minutes

  // ==========================================
  // FEEDBACK & SETTINGS PERSISTENCE
  // ==========================================

  RecommendationFeedback getFeedback() {
    final raw = _cacheService.getSetting('discovery_feedback_v1');
    if (raw is String && raw.isNotEmpty) {
      try {
        return RecommendationFeedback.fromJson(raw);
      } catch (e) {
        debugPrint('SONIQ: Error decoding recommendation feedback: $e');
      }
    }
    return RecommendationFeedback();
  }

  Future<void> saveFeedback(RecommendationFeedback feedback) async {
    await _cacheService.setSetting('discovery_feedback_v1', feedback.toJson());
    invalidateCache();
  }

  RecommendationSettings getSettings() {
    final raw = _cacheService.getSetting('discovery_settings_v1');
    if (raw is String && raw.isNotEmpty) {
      try {
        return RecommendationSettings.fromJson(raw);
      } catch (e) {
        debugPrint('SONIQ: Error decoding recommendation settings: $e');
      }
    }
    return const RecommendationSettings();
  }

  Future<void> saveSettings(RecommendationSettings settings) async {
    await _cacheService.setSetting('discovery_settings_v1', settings.toJson());
    invalidateCache();
  }

  void invalidateCache() {
    _cachedDailyMixes = null;
    _lastDailyMixesGeneratedMs = 0;
  }

  // Feedback convenience methods
  Future<void> likeSong(String songId) async {
    final fb = getFeedback();
    fb.likedSongIds.add(songId);
    fb.dislikedSongIds.remove(songId);
    fb.notInterestedSongIds.remove(songId);
    fb.feedbackTimestamps[songId] = DateTime.now().millisecondsSinceEpoch;
    await saveFeedback(fb);
  }

  Future<void> dislikeSong(String songId) async {
    final fb = getFeedback();
    fb.dislikedSongIds.add(songId);
    fb.likedSongIds.remove(songId);
    fb.feedbackTimestamps[songId] = DateTime.now().millisecondsSinceEpoch;
    await saveFeedback(fb);
  }

  Future<void> markNotInterested(String songId) async {
    final fb = getFeedback();
    fb.notInterestedSongIds.add(songId);
    fb.feedbackTimestamps[songId] = DateTime.now().millisecondsSinceEpoch;
    await saveFeedback(fb);
  }

  Future<void> excludeSong(String songId) async {
    final fb = getFeedback();
    fb.excludedSongIds.add(songId);
    fb.feedbackTimestamps[songId] = DateTime.now().millisecondsSinceEpoch;
    await saveFeedback(fb);
  }

  Future<void> excludeArtist(String artistName) async {
    final fb = getFeedback();
    fb.excludedArtists.add(artistName.trim());
    await saveFeedback(fb);
  }

  Future<void> removeExclusion(String idOrName) async {
    final fb = getFeedback();
    fb.excludedSongIds.remove(idOrName);
    fb.excludedArtists.removeWhere((a) => a.toLowerCase() == idOrName.toLowerCase());
    fb.dislikedSongIds.remove(idOrName);
    fb.notInterestedSongIds.remove(idOrName);
    await saveFeedback(fb);
  }

  Future<void> resetAllFeedback() async {
    await _cacheService.setSetting('discovery_feedback_v1', null);
    invalidateCache();
  }

  // ==========================================
  // 1. SIMILAR SONGS RECOMMENDATION ENGINE
  // ==========================================

  /// Computes top similar songs for a given seed track with explainable reasoning
  List<RecommendationItem> getSimilarSongs(
    SongModel seedSong,
    List<SongModel> library, {
    int limit = 20,
  }) {
    if (library.isEmpty) return [];

    final feedback = getFeedback();
    final classifications = _cacheService.getClassifications();
    final allEvents = _cacheService.getAllPlaybackEvents();
    final playlists = _cacheService.getPlaylists();

    // Pre-calculate co-occurrence matrices
    final sessionCoPlays = _buildSessionCoPlayCounts(seedSong.id, allEvents);
    final playlistCoPlays = _buildPlaylistCoPlayCounts(seedSong.id, playlists);

    final seedClassification = classifications[seedSong.id] ??
        _classifierService.classifySong(seedSong);
    final seedSecondaryMoods = seedClassification.secondaryMoods.toSet();

    final seedDuration = seedSong.durationMs;
    final seedGenre = (seedSong.album.isNotEmpty ? seedSong.album : 'Music').toLowerCase();
    final seedArtist = seedSong.artist.toLowerCase();

    final candidateList = <RecommendationItem>[];

    for (final song in library) {
      if (song.id == seedSong.id) continue;
      if (feedback.isExcluded(song)) continue;

      final classification = classifications[song.id] ??
          _classifierService.classifySong(song);

      double score = 0.0;
      final reasonTags = <String>[];
      final featureMatches = <String, double>{};

      // A. Artist Match / Collaboration (0.0 to 0.30)
      final candidateArtist = song.artist.toLowerCase();
      if (candidateArtist == seedArtist && seedArtist != 'unknown') {
        score += 0.30;
        reasonTags.add('Same Artist');
        featureMatches['artist'] = 1.0;
      } else if (candidateArtist.contains(seedArtist) || seedArtist.contains(candidateArtist)) {
        score += 0.18;
        reasonTags.add('Collaborator');
        featureMatches['artist'] = 0.6;
      }

      // B. Mood & Energy Alignment (0.0 to 0.28)
      if (seedClassification.primaryMood == classification.primaryMood &&
          seedClassification.primaryMood != 'Unclassified') {
        score += 0.20;
        reasonTags.add('${seedClassification.primaryMood} Mood');
        featureMatches['mood'] = 1.0;
      } else if (seedSecondaryMoods.isNotEmpty && classification.secondaryMoods.isNotEmpty) {
        String? matchingVibe;
        for (final m in classification.secondaryMoods) {
          if (seedSecondaryMoods.contains(m)) {
            matchingVibe = m;
            break;
          }
        }
        if (matchingVibe != null) {
          score += 0.12;
          reasonTags.add('$matchingVibe Vibe');
          featureMatches['mood'] = 0.6;
        }
      }

      if (seedClassification.energyLevel == classification.energyLevel) {
        score += 0.08;
        featureMatches['energy'] = 1.0;
      }

      // C. Genre & Album Similarity (0.0 to 0.20)
      final candidateGenre = song.album.toLowerCase();
      if (candidateGenre == seedGenre && seedGenre != 'unknown' && seedGenre.isNotEmpty) {
        score += 0.20;
        reasonTags.add('Same Album/Genre');
        featureMatches['genre'] = 1.0;
      }

      // D. Sonic Proximity (Tempo & Duration) (0.0 to 0.12)
      final durDiffRatio = (song.durationMs - seedDuration).abs() / (seedDuration > 0 ? seedDuration : 1);
      if (durDiffRatio <= 0.20) {
        score += 0.07;
        featureMatches['duration'] = 1.0 - durDiffRatio;
      }

      final seedBpm = seedClassification.audioFeatures.bpm;
      final candBpm = classification.audioFeatures.bpm;
      if (seedBpm != null && candBpm != null) {
        final bpmDiff = (seedBpm - candBpm).abs();
        if (bpmDiff <= 12) {
          score += 0.05;
          reasonTags.add('Similar Tempo ($candBpm BPM)');
          featureMatches['tempo'] = 1.0;
        }
      }

      // E. Listening History Co-Occurrence (0.0 to 0.20)
      final coPlayCount = sessionCoPlays[song.id] ?? 0;
      if (coPlayCount > 0) {
        final coScore = (coPlayCount * 0.05).clamp(0.05, 0.15);
        score += coScore;
        reasonTags.add('Frequently Played Together');
        featureMatches['co_play'] = coScore;
      }

      final playlistCoCount = playlistCoPlays[song.id] ?? 0;
      if (playlistCoCount > 0) {
        score += 0.05;
        reasonTags.add('In Same Playlists');
        featureMatches['playlist_co'] = 0.05;
      }

      // F. Feedback Personalization Adjustment
      if (feedback.likedSongIds.contains(song.id)) {
        score *= 1.30; // +30% boost for liked songs
      }
      if (song.isFavorite) {
        score *= 1.15; // +15% boost for favorites
      }

      if (score >= 0.15) {
        final explanation = _generateExplanation(
          seedSong: seedSong,
          candidate: song,
          reasonTags: reasonTags,
          bpm: candBpm,
        );

        candidateList.add(RecommendationItem(
          song: song,
          score: score,
          explanation: explanation,
          reasonTags: reasonTags,
          featureMatches: featureMatches,
        ));
      }
    }

    candidateList.sort((a, b) => b.score.compareTo(a.score));
    return candidateList.take(limit).toList();
  }

  // ==========================================
  // 2. DAILY MIX GENERATION
  // ==========================================

  /// Generates personalized daily mixes (Daily Mix 1, Daily Mix 2, etc.)
  List<RecommendationMix> generateDailyMixes(
    List<SongModel> library, {
    int mixesCount = 3,
    bool forceRegenerate = false,
  }) {
    if (library.isEmpty) return [];

    final now = DateTime.now().millisecondsSinceEpoch;
    if (!forceRegenerate &&
        _cachedDailyMixes != null &&
        (now - _lastDailyMixesGeneratedMs) < _cacheTtlMs) {
      return _cachedDailyMixes!;
    }

    final feedback = getFeedback();
    final settings = getSettings();
    final classifications = _cacheService.getClassifications();
    final allEvents = _cacheService.getAllPlaybackEvents();

    // 1. Identify user's top genres and moods from qualified listening events
    final moodAffinities = <String, int>{};
    final artistAffinities = <String, int>{};

    for (final e in allEvents) {
      if (e.isQualifiedPlay) {
        artistAffinities[e.artistName] = (artistAffinities[e.artistName] ?? 0) + 1;
        final c = classifications[e.songId];
        if (c != null && c.primaryMood != 'Unclassified') {
          moodAffinities[c.primaryMood] = (moodAffinities[c.primaryMood] ?? 0) + 1;
        }
      }
    }

    // Default fallback clusters if listening history is nascent
    final defaultMoodClusters = [
      ['Love & Romance', 'Melody', 'Tamil Melody'],
      ['Fast Beat', 'Workout', 'Party', 'Tamil Kuthu'],
      ['Chill & Relax', 'Focus', 'Sleep', 'Instrumental'],
      ['Road Trip', 'Motivation', 'Rock'],
    ];

    final sortedMoods = moodAffinities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final clusters = <List<String>>[];
    for (final entry in sortedMoods) {
      clusters.add([entry.key]);
      if (clusters.length >= mixesCount) break;
    }

    // Pad with default clusters if needed
    for (final defCluster in defaultMoodClusters) {
      if (clusters.length >= mixesCount) break;
      if (!clusters.any((c) => c.any((m) => defCluster.contains(m)))) {
        clusters.add(defCluster);
      }
    }

    final mixes = <RecommendationMix>[];
    final usedSongIds = <String>{};

    const mixColors = [
      Color(0xFFE5A93C), // Gold
      Color(0xFFE53935), // Red
      Color(0xFF1E88E5), // Blue
      Color(0xFF43A047), // Green
    ];

    const mixIcons = [
      Icons.local_fire_department_rounded,
      Icons.bolt_rounded,
      Icons.spa_rounded,
      Icons.explore_rounded,
    ];

    int mixIndex = 1;
    for (final cluster in clusters) {
      final clusterSongs = <SongModel>[];
      final artistTrackCounts = <String, int>{};

      // Filter candidate songs matching cluster moods
      final matchingSongs = library.where((s) {
        if (feedback.isExcluded(s)) return false;
        if (usedSongIds.contains(s.id)) return false;

        final c = classifications[s.id] ?? _classifierService.classifySong(s);
        return cluster.contains(c.primaryMood) ||
            cluster.any((m) => c.secondaryMoods.contains(m));
      }).toList();

      // Split into Familiar (Favorites / Played) vs Discovery (Unplayed / Rare)
      final familiar = <SongModel>[];
      final discovery = <SongModel>[];

      for (final s in matchingSongs) {
        if (s.isFavorite || s.playCount > 1 || feedback.likedSongIds.contains(s.id)) {
          familiar.add(s);
        } else {
          discovery.add(s);
        }
      }

      familiar.shuffle(Random(now + mixIndex));
      discovery.shuffle(Random(now + mixIndex * 13));

      // Balance familiar and discovery according to settings (default 60% familiar, 40% discovery)
      final targetTotal = min(25, matchingSongs.length);
      final targetFamiliar = (targetTotal * settings.familiarityRatio).round();

      // Add familiar songs respecting maxTracksPerArtist
      for (final s in familiar) {
        final curCount = artistTrackCounts[s.artist] ?? 0;
        if (curCount < settings.maxTracksPerArtist) {
          clusterSongs.add(s);
          usedSongIds.add(s.id);
          artistTrackCounts[s.artist] = curCount + 1;
          if (clusterSongs.length >= targetFamiliar) break;
        }
      }

      // Add discovery songs
      for (final s in discovery) {
        final curCount = artistTrackCounts[s.artist] ?? 0;
        if (curCount < settings.maxTracksPerArtist) {
          clusterSongs.add(s);
          usedSongIds.add(s.id);
          artistTrackCounts[s.artist] = curCount + 1;
          if (clusterSongs.length >= targetTotal) break;
        }
      }

      final minRequired = matchingSongs.length < 5 ? 1 : 3;
      if (clusterSongs.length >= minRequired) {
        final clusterName = cluster.first;
        final topArtistInMix = clusterSongs.map((s) => s.artist).toSet().take(3).join(', ');

        mixes.add(RecommendationMix(
          id: 'daily_mix_$mixIndex',
          title: 'Daily Mix $mixIndex',
          subtitle: topArtistInMix,
          description: 'A personalized mix centered on $clusterName and related favorites.',
          mixType: 'daily_mix',
          songs: clusterSongs,
          accentColor: mixColors[(mixIndex - 1) % mixColors.length],
          icon: mixIcons[(mixIndex - 1) % mixIcons.length],
        ));
        mixIndex++;
      }
    }

    _cachedDailyMixes = mixes;
    _lastDailyMixesGeneratedMs = now;
    return mixes;
  }

  // ==========================================
  // 3. DISCOVER MIX (DEEP CUTS & UNEXPLORED GEMS)
  // ==========================================

  /// Curates library tracks that the user hasn't played or hasn't heard in a long time
  RecommendationMix generateDiscoverMix(List<SongModel> library, {int limit = 25}) {
    final feedback = getFeedback();
    final settings = getSettings();
    final allEvents = _cacheService.getAllPlaybackEvents();

    final playedSongIds = allEvents.map((e) => e.songId).toSet();

    // Prefer unplayed tracks first, or tracks played <= 1 times
    final candidates = library.where((s) {
      if (feedback.isExcluded(s)) return false;
      return !playedSongIds.contains(s.id) && !s.isFavorite;
    }).toList();

    // If candidate pool is small, supplement with oldest played tracks
    if (candidates.length < limit) {
      final additional = library.where((s) {
        if (feedback.isExcluded(s)) return false;
        return s.playCount <= 1;
      }).toList();
      candidates.addAll(additional);
    }

    candidates.shuffle(Random());

    final selected = <SongModel>[];
    final artistCounts = <String, int>{};

    for (final song in candidates) {
      final count = artistCounts[song.artist] ?? 0;
      if (count < settings.maxTracksPerArtist) {
        selected.add(song);
        artistCounts[song.artist] = count + 1;
        if (selected.length >= limit) break;
      }
    }

    if (selected.isEmpty && library.isNotEmpty) {
      final fallback = library.where((s) => !feedback.isExcluded(s)).take(limit).toList();
      selected.addAll(fallback);
    }

    return RecommendationMix(
      id: 'discover_mix_weekly',
      title: 'Discover Mix',
      subtitle: 'Unexplored tracks from your library',
      description: 'Hidden gems and rare tracks waiting to be discovered in your music collection.',
      mixType: 'discover_mix',
      songs: selected,
      accentColor: const Color(0xFF9C27B0), // Purple accent
      icon: Icons.explore_rounded,
    );
  }

  // ==========================================
  // 4. ARTIST RADIO ENGINE
  // ==========================================

  /// Generates a continuous dynamic radio stream anchored around a specific artist
  RecommendationMix generateArtistRadio(
    String artistName,
    List<SongModel> library, {
    int limit = 30,
  }) {
    if (library.isEmpty || artistName.trim().isEmpty) {
      return RecommendationMix(
        id: 'artist_radio_${artistName.hashCode}',
        title: '$artistName Radio',
        subtitle: 'Artist Radio',
        description: 'Music by $artistName and related styles',
        mixType: 'artist_radio',
        songs: const [],
      );
    }

    final feedback = getFeedback();
    final allEvents = _cacheService.getAllPlaybackEvents();
    final playlists = _cacheService.getPlaylists();
    final classifications = _cacheService.getClassifications();

    final cleanArtist = artistName.trim().toLowerCase();

    // 1. Direct songs by the anchor artist
    final anchorSongs = library
        .where((s) => s.artist.trim().toLowerCase() == cleanArtist && !feedback.isExcluded(s))
        .toList()
      ..shuffle(Random());

    // 2. Discover related artists based on co-occurrence in listening sessions & playlists
    final relatedArtistScores = <String, double>{};

    // A. Playlist co-occurrence
    for (final p in playlists) {
      final pSongs = library.where((s) => p.songIds.contains(s.id)).toList();
      final hasAnchor = pSongs.any((s) => s.artist.trim().toLowerCase() == cleanArtist);
      if (hasAnchor) {
        for (final s in pSongs) {
          final a = s.artist.trim();
          if (a.toLowerCase() != cleanArtist) {
            relatedArtistScores[a] = (relatedArtistScores[a] ?? 0) + 1.0;
          }
        }
      }
    }

    // B. Listening Session co-occurrence
    final sessionMap = <String, List<PlaybackEventModel>>{};
    for (final e in allEvents) {
      sessionMap.putIfAbsent(e.sessionId, () => []).add(e);
    }
    for (final events in sessionMap.values) {
      final hasAnchor = events.any((e) => e.artistName.trim().toLowerCase() == cleanArtist);
      if (hasAnchor) {
        for (final e in events) {
          final a = e.artistName.trim();
          if (a.toLowerCase() != cleanArtist) {
            relatedArtistScores[a] = (relatedArtistScores[a] ?? 0) + 0.5;
          }
        }
      }
    }

    // C. Sonic / Mood similarity of anchor artist's primary profile
    final anchorMoods = <String, int>{};
    for (final s in anchorSongs) {
      final c = classifications[s.id] ?? _classifierService.classifySong(s);
      if (c.primaryMood != 'Unclassified') {
        anchorMoods[c.primaryMood] = (anchorMoods[c.primaryMood] ?? 0) + 1;
      }
    }

    // Score all other library songs based on related artist score + mood match
    final relatedSongs = <SongModel>[];
    for (final s in library) {
      if (s.artist.trim().toLowerCase() == cleanArtist) continue;
      if (feedback.isExcluded(s)) continue;

      double score = relatedArtistScores[s.artist.trim()] ?? 0.0;
      final c = classifications[s.id] ?? _classifierService.classifySong(s);
      if (anchorMoods.containsKey(c.primaryMood)) {
        score += 1.2;
      }

      if (score > 0) {
        relatedSongs.add(s);
      }
    }

    relatedSongs.shuffle(Random());

    // Assemble radio queue: ~40% anchor artist, ~60% related artists
    final result = <SongModel>[];
    final targetAnchor = (limit * 0.40).round();
    final targetRelated = limit - targetAnchor;

    result.addAll(anchorSongs.take(targetAnchor));
    result.addAll(relatedSongs.take(targetRelated));

    // Fallback if related songs are scarce
    if (result.length < limit) {
      final remainingAnchor = anchorSongs.skip(targetAnchor);
      result.addAll(remainingAnchor.take(limit - result.length));
    }

    return RecommendationMix(
      id: 'artist_radio_${artistName.hashCode}',
      title: '$artistName Radio',
      subtitle: 'Featuring ${anchorSongs.take(2).map((s) => s.title).join(", ")}',
      description: 'Continuous music station inspired by $artistName and musically related artists.',
      mixType: 'artist_radio',
      songs: result,
      accentColor: const Color(0xFF00ACC1), // Cyan accent
      icon: Icons.radio_rounded,
    );
  }

  // ==========================================
  // 5. FORGOTTEN GEMS REDISCOVERY
  // ==========================================

  /// Recommends songs that the user loved/played before but hasn't listened to in > 30 days
  RecommendationMix generateForgottenGems(List<SongModel> library, {int limit = 25}) {
    final feedback = getFeedback();
    final allEvents = _cacheService.getAllPlaybackEvents();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final thirtyDaysMs = 30 * 24 * 60 * 60 * 1000;

    final songLastPlayed = <String, int>{};
    final songQualifiedPlays = <String, int>{};

    for (final e in allEvents) {
      if (e.startTimeMs > (songLastPlayed[e.songId] ?? 0)) {
        songLastPlayed[e.songId] = e.startTimeMs;
      }
      if (e.isQualifiedPlay) {
        songQualifiedPlays[e.songId] = (songQualifiedPlays[e.songId] ?? 0) + 1;
      }
    }

    final candidates = library.where((s) {
      if (feedback.isExcluded(s)) return false;

      final lastPlayed = songLastPlayed[s.id] ?? s.lastPlayedTimestamp;
      final qualified = songQualifiedPlays[s.id] ?? (s.playCount > 0 ? s.playCount : 0);

      // Must have been played at least once, but not in the last 30 days
      final isDormant = (nowMs - lastPlayed) > thirtyDaysMs;
      final hasPositiveHistory = qualified >= 1 || s.isFavorite;

      return isDormant && hasPositiveHistory;
    }).toList();

    // Sort by oldest last played date to highlight deepest forgotten cuts
    candidates.sort((a, b) {
      final aDate = songLastPlayed[a.id] ?? a.lastPlayedTimestamp;
      final bDate = songLastPlayed[b.id] ?? b.lastPlayedTimestamp;
      return aDate.compareTo(bDate);
    });

    return RecommendationMix(
      id: 'forgotten_gems',
      title: 'Forgotten Gems',
      subtitle: 'Songs you used to love',
      description: 'Tracks with a strong listening history that you have not played recently.',
      mixType: 'forgotten_gems',
      songs: candidates.take(limit).toList(),
      accentColor: const Color(0xFFFFB300), // Amber
      icon: Icons.history_toggle_off_rounded,
    );
  }

  // ==========================================
  // 6. BECAUSE YOU LISTENED TO [TRACK]
  // ==========================================

  /// Identifies the user's most significant recent track and generates a matching shelf
  RecommendationMix? generateBecauseYouListened(List<SongModel> library) {
    if (library.isEmpty) return null;

    final allEvents = _cacheService.getAllPlaybackEvents();
    final feedback = getFeedback();

    SongModel? anchorSong;

    // Prefer most recent qualified play from the last 7 days
    if (allEvents.isNotEmpty) {
      final sorted = List<PlaybackEventModel>.from(allEvents)
        ..sort((a, b) => b.startTimeMs.compareTo(a.startTimeMs));

      for (final e in sorted) {
        if (e.isQualifiedPlay && !feedback.excludedSongIds.contains(e.songId)) {
          final match = library.where((s) => s.id == e.songId);
          if (match.isNotEmpty) {
            anchorSong = match.first;
            break;
          }
        }
      }
    }

    // Fallback: pick user's first favorite or most played song
    if (anchorSong == null) {
      final favs = library.where((s) => s.isFavorite && !feedback.isExcluded(s)).toList();
      if (favs.isNotEmpty) {
        anchorSong = favs.first;
      } else {
        final sortedByPlays = List<SongModel>.from(library)
          ..sort((a, b) => b.playCount.compareTo(a.playCount));
        if (sortedByPlays.isNotEmpty && sortedByPlays.first.playCount > 0) {
          anchorSong = sortedByPlays.first;
        }
      }
    }

    if (anchorSong == null) return null;

    final similarItems = getSimilarSongs(anchorSong, library, limit: 15);
    final songs = similarItems.map((item) => item.song).toList();

    if (songs.isEmpty) return null;

    return RecommendationMix(
      id: 'because_you_listened_${anchorSong.id}',
      title: 'Because You Listened To',
      subtitle: '"${anchorSong.title}" by ${anchorSong.artist}',
      description: 'Handpicked songs that match the acoustic profile and mood of "${anchorSong.title}".',
      mixType: 'similar_mix',
      songs: songs,
      accentColor: const Color(0xFF26A69A), // Teal
      icon: Icons.thumb_up_alt_rounded,
    );
  }

  // ==========================================
  // 7. MOOD-BASED RECOMMENDATION MIXES
  // ==========================================

  /// Categorizes recommendations into mood stations (Workout, Chill, Night Drive, Focus)
  List<RecommendationMix> generateMoodMixes(List<SongModel> library) {
    if (library.isEmpty) return [];

    final feedback = getFeedback();
    final classifications = _cacheService.getClassifications();

    final targetMoods = [
      {'mood': 'Workout', 'title': 'Workout Fuel', 'desc': 'High-energy beats to power your sets', 'color': const Color(0xFFD32F2F), 'icon': Icons.fitness_center_rounded},
      {'mood': 'Chill & Relax', 'title': 'Chill & Unwind', 'desc': 'Acoustic calm and soothing melodies', 'color': const Color(0xFF1976D2), 'icon': Icons.nights_stay_rounded},
      {'mood': 'Road Trip', 'title': 'Highway Horizon', 'desc': 'Upbeat tracks perfect for long drives', 'color': const Color(0xFFF57C00), 'icon': Icons.directions_car_rounded},
      {'mood': 'Focus', 'title': 'Deep Flow', 'desc': 'Calm, minimal distraction music for study and coding', 'color': const Color(0xFF388E3C), 'icon': Icons.psychology_rounded},
      {'mood': 'Fast Beat', 'title': 'Speed & Bass', 'desc': 'Fast-tempo bangers and dance rhythms', 'color': const Color(0xFF7B1FA2), 'icon': Icons.speed_rounded},
    ];

    final mixes = <RecommendationMix>[];

    for (final m in targetMoods) {
      final moodKey = m['mood'] as String;
      final matching = library.where((s) {
        if (feedback.isExcluded(s)) return false;
        final c = classifications[s.id] ?? _classifierService.classifySong(s);
        return c.primaryMood == moodKey || c.secondaryMoods.contains(moodKey);
      }).toList();

      if (matching.length >= 4) {
        matching.shuffle(Random());
        mixes.add(RecommendationMix(
          id: 'mood_mix_${moodKey.toLowerCase().replaceAll(' ', '_')}',
          title: m['title'] as String,
          subtitle: '${matching.length} tracks available',
          description: m['desc'] as String,
          mixType: 'mood_mix',
          songs: matching.take(25).toList(),
          accentColor: m['color'] as Color,
          icon: m['icon'] as IconData,
        ));
      }
    }

    return mixes;
  }

  // ==========================================
  // PRIVATE HELPER ALGORITHMS
  // ==========================================

  Map<String, int> _buildSessionCoPlayCounts(
    String targetSongId,
    List<PlaybackEventModel> allEvents,
  ) {
    final targetSessions = <String>{};
    for (final e in allEvents) {
      if (e.songId == targetSongId && e.isQualifiedPlay) {
        targetSessions.add(e.sessionId);
      }
    }

    final coPlays = <String, int>{};
    for (final e in allEvents) {
      if (e.songId != targetSongId && targetSessions.contains(e.sessionId) && e.isQualifiedPlay) {
        coPlays[e.songId] = (coPlays[e.songId] ?? 0) + 1;
      }
    }
    return coPlays;
  }

  Map<String, int> _buildPlaylistCoPlayCounts(
    String targetSongId,
    List<PlaylistModel> playlists,
  ) {
    final coPlays = <String, int>{};
    for (final p in playlists) {
      if (p.songIds.contains(targetSongId)) {
        for (final id in p.songIds) {
          if (id != targetSongId) {
            coPlays[id] = (coPlays[id] ?? 0) + 1;
          }
        }
      }
    }
    return coPlays;
  }

  String _generateExplanation({
    required SongModel seedSong,
    required SongModel candidate,
    required List<String> reasonTags,
    int? bpm,
  }) {
    if (reasonTags.contains('Frequently Played Together')) {
      return 'Frequently played in the same session with "${seedSong.title}"';
    }
    if (reasonTags.contains('Same Artist')) {
      return 'Another top track by ${candidate.artist}';
    }
    if (reasonTags.contains('Collaborator')) {
      return 'Collaborative artist related to ${seedSong.artist}';
    }
    if (reasonTags.any((t) => t.contains('Mood'))) {
      final tag = reasonTags.firstWhere((t) => t.contains('Mood'));
      return 'Matches the $tag and musical vibe';
    }
    if (bpm != null && reasonTags.any((t) => t.contains('Similar Tempo'))) {
      return 'Similar driving tempo ($bpm BPM) and energy';
    }
    if (reasonTags.contains('Same Album/Genre')) {
      return 'From the same album and soundscape';
    }
    return 'Musically aligned in acoustic structure and user listening habits';
  }
}
