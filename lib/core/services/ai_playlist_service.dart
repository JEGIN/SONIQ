import 'dart:math';
import '../models/song_model.dart';

enum AiPlaylistVibe {
  workout,
  chill,
  roadTrip,
  focus,
  heavyRotation,
  forgottenGems,
}

class AiPlaylistService {
  static final AiPlaylistService _instance = AiPlaylistService._internal();
  factory AiPlaylistService() => _instance;
  AiPlaylistService._internal();

  /// Generate a curated smart playlist based on pre-defined audio vibes
  List<SongModel> generateByVibe(
    List<SongModel> library,
    AiPlaylistVibe vibe, {
    int limit = 30,
    Set<String> favoriteIds = const {},
  }) {
    if (library.isEmpty) return [];

    final list = List<SongModel>.from(library);
    final random = Random();

    switch (vibe) {
      case AiPlaylistVibe.workout:
        // Energetic tracks: 2.5 min to 4.5 min, upbeat keywords or favorites
        final workoutKeywords = {'beat', 'fast', 'rock', 'power', 'remix', 'dance', 'run', 'fire', 'bass', 'party', 'dj', 'club', 'trap', 'rap', 'punch', 'energy', 'anthem', 'mass', 'hit'};
        list.sort((a, b) {
          int aScore = 0;
          int bScore = 0;
          if (workoutKeywords.any((k) => a.title.toLowerCase().contains(k) || a.artist.toLowerCase().contains(k))) aScore += 10;
          if (workoutKeywords.any((k) => b.title.toLowerCase().contains(k) || b.artist.toLowerCase().contains(k))) bScore += 10;
          if (a.durationMs >= 150000 && a.durationMs <= 270000) aScore += 3;
          if (b.durationMs >= 150000 && b.durationMs <= 270000) bScore += 3;
          return bScore.compareTo(aScore);
        });
        return list.take(limit).toList();

      case AiPlaylistVibe.chill:
        // Relaxing acoustic, longer melodic tracks (>3.5 mins)
        final chillKeywords = {'chill', 'night', 'love', 'acoustic', 'melody', 'slow', 'rain', 'breeze', 'calm', 'sweet', 'soft', 'soul', 'moon', 'dream', 'piano', 'silence', 'peace', 'unplugged'};
        list.sort((a, b) {
          int aScore = 0;
          int bScore = 0;
          if (chillKeywords.any((k) => a.title.toLowerCase().contains(k) || a.album.toLowerCase().contains(k))) aScore += 10;
          if (chillKeywords.any((k) => b.title.toLowerCase().contains(k) || b.album.toLowerCase().contains(k))) bScore += 10;
          if (a.durationMs >= 240000) aScore += 4;
          if (b.durationMs >= 240000) bScore += 4;
          return bScore.compareTo(aScore);
        });
        return list.take(limit).toList();

      case AiPlaylistVibe.roadTrip:
        // Diverse cross-artist mix prioritizing favorites & popular tracks
        final favorites = list.where((s) => favoriteIds.contains(s.id) || s.isFavorite).toList()..shuffle(random);
        final nonFavorites = list.where((s) => !favoriteIds.contains(s.id) && !s.isFavorite).toList()..shuffle(random);
        
        // 50% favorites + 50% library tracks
        final result = <SongModel>[];
        int fIdx = 0;
        int nIdx = 0;
        while (result.length < limit && (fIdx < favorites.length || nIdx < nonFavorites.length)) {
          if (fIdx < favorites.length) {
            result.add(favorites[fIdx++]);
          }
          if (result.length < limit && nIdx < nonFavorites.length) {
            result.add(nonFavorites[nIdx++]);
          }
        }
        return result;

      case AiPlaylistVibe.focus:
        // Instrumental, calm, minimal variation
        final focusKeywords = {'study', 'focus', 'instrumental', 'theme', 'piano', 'guitar', 'ambient', 'classic', 'meditation', 'lofi', 'calm'};
        list.sort((a, b) {
          int aScore = 0;
          int bScore = 0;
          if (focusKeywords.any((k) => a.title.toLowerCase().contains(k))) aScore += 10;
          if (focusKeywords.any((k) => b.title.toLowerCase().contains(k))) bScore += 10;
          return bScore.compareTo(aScore);
        });
        return list.take(limit).toList();

      case AiPlaylistVibe.heavyRotation:
        // Most listened & favorite tracks
        final favs = list.where((s) => favoriteIds.contains(s.id) || s.isFavorite).toList();
        favs.shuffle(random);
        if (favs.length >= limit) return favs.take(limit).toList();
        
        // Supplement with recently added or longest tracks
        final remaining = list.where((s) => !favs.contains(s)).toList()..shuffle(random);
        return [...favs, ...remaining].take(limit).toList();

      case AiPlaylistVibe.forgottenGems:
        // Deep cuts: tracks not in favorites, shuffled from older library additions
        final nonFavs = list.where((s) => !favoriteIds.contains(s.id) && !s.isFavorite).toList();
        nonFavs.sort((a, b) => a.dateAdded.compareTo(b.dateAdded)); // oldest first
        final pool = nonFavs.take(min(nonFavs.length, 50)).toList()..shuffle(random);
        return pool.take(limit).toList();
    }
  }

  /// Natural Language AI prompt matcher for offline music library
  List<SongModel> generateByPrompt(
    List<SongModel> library,
    String prompt, {
    int limit = 30,
    Set<String> favoriteIds = const {},
  }) {
    if (library.isEmpty || prompt.trim().isEmpty) return [];

    final tokens = prompt
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 1)
        .toList();

    if (tokens.isEmpty) return library.take(limit).toList();

    // Score every track in local library
    final scored = <SongModel, double>{};

    for (final song in library) {
      double score = 0.0;
      final titleLower = song.title.toLowerCase();
      final artistLower = song.artist.toLowerCase();
      final albumLower = song.album.toLowerCase();

      for (final token in tokens) {
        // Direct title match
        if (titleLower.contains(token)) score += 5.0;
        // Direct artist match
        if (artistLower.contains(token)) score += 6.0;
        // Direct album match
        if (albumLower.contains(token)) score += 4.0;

        // Vibe intent tokens
        if (['fast', 'energy', 'beat', 'workout', 'dance', 'gym', 'speed'].contains(token)) {
          if (song.durationMs >= 150000 && song.durationMs <= 240000) score += 3.0;
        }
        if (['slow', 'chill', 'night', 'sleep', 'relax', 'calm', 'melody', 'love'].contains(token)) {
          if (song.durationMs >= 240000) score += 3.0;
        }
        if (['favorite', 'fav', 'best', 'top', 'loved'].contains(token)) {
          if (favoriteIds.contains(song.id) || song.isFavorite) score += 8.0;
        }
        if (['long', 'epic'].contains(token) && song.durationMs > 300000) {
          score += 4.0;
        }
        if (['short', 'quick'].contains(token) && song.durationMs < 180000) {
          score += 4.0;
        }
      }

      if (score > 0) {
        // Subtle randomization to keep playlist exciting
        scored[song] = score + (Random().nextDouble() * 0.5);
      }
    }

    if (scored.isEmpty) {
      // Fallback: substring loose search
      final loose = library.where((s) {
        final raw = '${s.title} ${s.artist} ${s.album}'.toLowerCase();
        return tokens.any((t) => raw.contains(t));
      }).toList();

      if (loose.isNotEmpty) return loose.take(limit).toList();
      return library.take(limit).toList();
    }

    final sortedEntries = scored.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedEntries.take(limit).map((e) => e.key).toList();
  }
}
