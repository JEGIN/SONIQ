import 'dart:convert';
import 'package:flutter/material.dart';
import 'song_model.dart';

/// Represents a single recommended song with explainable reasoning
class RecommendationItem {
  final SongModel song;
  final double score; // 0.0 to 1.0 (or normalized relevance score)
  final String explanation; // E.g., "Similar tempo (124 BPM) & upbeat mood"
  final List<String> reasonTags; // E.g., ["Same Genre", "Frequently Co-played"]
  final Map<String, double> featureMatches; // Feature breakdown

  const RecommendationItem({
    required this.song,
    required this.score,
    required this.explanation,
    this.reasonTags = const [],
    this.featureMatches = const {},
  });
}

/// Represents a curated discovery mix or shelf (e.g. Daily Mix, Forgotten Gems, Mood Mix)
class RecommendationMix {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final String mixType; // 'daily_mix', 'discover_mix', 'artist_radio', 'forgotten_gems', 'mood_mix', 'similar_mix'
  final List<SongModel> songs;
  final Color accentColor;
  final IconData icon;

  const RecommendationMix({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.mixType,
    required this.songs,
    this.accentColor = const Color(0xFFD4AF37), // AppColors.gold
    this.icon = Icons.auto_awesome_rounded,
  });

  int get songCount => songs.length;
  int get totalDurationMs => songs.fold<int>(0, (sum, s) => sum + s.durationMs);

  RecommendationMix copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? description,
    String? mixType,
    List<SongModel>? songs,
    Color? accentColor,
    IconData? icon,
  }) {
    return RecommendationMix(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      mixType: mixType ?? this.mixType,
      songs: songs ?? this.songs,
      accentColor: accentColor ?? this.accentColor,
      icon: icon ?? this.icon,
    );
  }
}

/// User feedback on recommendations to personalize future suggestions
class RecommendationFeedback {
  final Set<String> likedSongIds;
  final Set<String> dislikedSongIds;
  final Set<String> notInterestedSongIds;
  final Set<String> excludedSongIds;
  final Set<String> excludedArtists;
  final Map<String, int> feedbackTimestamps;

  RecommendationFeedback({
    Set<String>? likedSongIds,
    Set<String>? dislikedSongIds,
    Set<String>? notInterestedSongIds,
    Set<String>? excludedSongIds,
    Set<String>? excludedArtists,
    Map<String, int>? feedbackTimestamps,
  })  : likedSongIds = likedSongIds ?? {},
        dislikedSongIds = dislikedSongIds ?? {},
        notInterestedSongIds = notInterestedSongIds ?? {},
        excludedSongIds = excludedSongIds ?? {},
        excludedArtists = excludedArtists ?? {},
        feedbackTimestamps = feedbackTimestamps ?? {};

  bool isExcluded(SongModel song) {
    if (excludedSongIds.contains(song.id)) return true;
    if (dislikedSongIds.contains(song.id)) return true;
    if (excludedArtists.any((a) => a.toLowerCase() == song.artist.toLowerCase())) return true;
    
    // Check not interested expiration (30 days)
    if (notInterestedSongIds.contains(song.id)) {
      final ts = feedbackTimestamps[song.id];
      if (ts != null) {
        final ageMs = DateTime.now().millisecondsSinceEpoch - ts;
        if (ageMs < 30 * 24 * 60 * 60 * 1000) {
          return true;
        }
      }
    }
    return false;
  }

  Map<String, dynamic> toMap() {
    return {
      'likedSongIds': likedSongIds.toList(),
      'dislikedSongIds': dislikedSongIds.toList(),
      'notInterestedSongIds': notInterestedSongIds.toList(),
      'excludedSongIds': excludedSongIds.toList(),
      'excludedArtists': excludedArtists.toList(),
      'feedbackTimestamps': feedbackTimestamps,
    };
  }

  factory RecommendationFeedback.fromMap(Map<dynamic, dynamic> map) {
    return RecommendationFeedback(
      likedSongIds: Set<String>.from((map['likedSongIds'] as List? ?? []).map((e) => e.toString())),
      dislikedSongIds: Set<String>.from((map['dislikedSongIds'] as List? ?? []).map((e) => e.toString())),
      notInterestedSongIds: Set<String>.from((map['notInterestedSongIds'] as List? ?? []).map((e) => e.toString())),
      excludedSongIds: Set<String>.from((map['excludedSongIds'] as List? ?? []).map((e) => e.toString())),
      excludedArtists: Set<String>.from((map['excludedArtists'] as List? ?? []).map((e) => e.toString())),
      feedbackTimestamps: Map<String, int>.from(map['feedbackTimestamps'] as Map? ?? {}),
    );
  }

  String toJson() => json.encode(toMap());

  factory RecommendationFeedback.fromJson(String source) =>
      RecommendationFeedback.fromMap(json.decode(source) as Map<dynamic, dynamic>);
}

/// Discovery settings (diversity, repetition, familiarity ratio)
class RecommendationSettings {
  final bool enableDiscoveryAnalysis;
  final double familiarityRatio; // 0.0 (all discovery) to 1.0 (all familiar), default 0.6
  final int maxTracksPerArtist; // Default 2 to prevent repetition
  final bool excludeExplicitKeywords;

  const RecommendationSettings({
    this.enableDiscoveryAnalysis = true,
    this.familiarityRatio = 0.6,
    this.maxTracksPerArtist = 2,
    this.excludeExplicitKeywords = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'enableDiscoveryAnalysis': enableDiscoveryAnalysis,
      'familiarityRatio': familiarityRatio,
      'maxTracksPerArtist': maxTracksPerArtist,
      'excludeExplicitKeywords': excludeExplicitKeywords,
    };
  }

  factory RecommendationSettings.fromMap(Map<dynamic, dynamic> map) {
    return RecommendationSettings(
      enableDiscoveryAnalysis: map['enableDiscoveryAnalysis'] as bool? ?? true,
      familiarityRatio: (map['familiarityRatio'] as num?)?.toDouble() ?? 0.6,
      maxTracksPerArtist: (map['maxTracksPerArtist'] as num?)?.toInt() ?? 2,
      excludeExplicitKeywords: map['excludeExplicitKeywords'] as bool? ?? false,
    );
  }

  String toJson() => json.encode(toMap());

  factory RecommendationSettings.fromJson(String source) =>
      RecommendationSettings.fromMap(json.decode(source) as Map<dynamic, dynamic>);
}
