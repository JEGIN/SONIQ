import 'package:get/get.dart';
import '../../core/services/audio_handler.dart';
import '../../features/navigation/controllers/navigation_controller.dart';
import '../../features/player/controllers/player_controller.dart';
import '../../features/library/controllers/library_controller.dart';
import '../../features/home/controllers/home_controller.dart';
import '../../features/playlists/controllers/playlist_controller.dart';
import '../../features/audio_studio/controllers/audio_studio_controller.dart';
import '../../features/settings/controllers/settings_controller.dart';
import '../../features/equalizer/controllers/equalizer_controller.dart';
import '../../features/playlists/controllers/favorites_controller.dart';
import '../../features/playlists/controllers/smart_playlist_controller.dart';

class InitialBinding extends Bindings {
  final SoniqAudioHandler audioHandler;

  InitialBinding({required this.audioHandler});

  @override
  void dependencies() {
    Get.put<NavigationController>(NavigationController(), permanent: true);
    Get.put<FavoritesController>(FavoritesController(), permanent: true);
    Get.put<AudioPlayerController>(AudioPlayerController(audioHandler: audioHandler), permanent: true);
    Get.put<EqualizerController>(EqualizerController(), permanent: true);
    Get.put<LibraryController>(LibraryController(), permanent: true);
    Get.put<PlaylistController>(PlaylistController(), permanent: true);
    Get.put<SmartPlaylistController>(SmartPlaylistController(), permanent: true);
    Get.put<HomeController>(HomeController(), permanent: true);
    Get.put<AudioStudioController>(AudioStudioController(), permanent: true);
    Get.put<SettingsController>(SettingsController(), permanent: true);
  }
}
