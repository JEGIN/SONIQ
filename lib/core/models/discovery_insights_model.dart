import 'song_model.dart';

class DiscoveryInsightsModel {
  final List<SongModel> forgottenFavorites;
  final List<SongModel> rediscoveredMusic;
  final List<String> underplayedAlbums;
  final List<SongModel> mostReplayedSongs;
  final List<SongModel> frequentlySkippedSongs;
  final List<String> heavyRotationArtists;

  const DiscoveryInsightsModel({
    required this.forgottenFavorites,
    required this.rediscoveredMusic,
    required this.underplayedAlbums,
    required this.mostReplayedSongs,
    required this.frequentlySkippedSongs,
    required this.heavyRotationArtists,
  });

  bool get isEmpty =>
      forgottenFavorites.isEmpty &&
      rediscoveredMusic.isEmpty &&
      underplayedAlbums.isEmpty &&
      mostReplayedSongs.isEmpty &&
      frequentlySkippedSongs.isEmpty &&
      heavyRotationArtists.isEmpty;
}
