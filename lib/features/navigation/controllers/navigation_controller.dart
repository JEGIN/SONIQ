import 'package:get/get.dart';
import '../../../core/models/song_model.dart';
import '../../audio_studio/controllers/audio_studio_controller.dart';
import '../../player/controllers/player_controller.dart';

class NavigationController extends GetxController {
  final RxInt currentTabIndex = 0.obs;

  void changeTab(int index) {
    currentTabIndex.value = index;
    if (index == 4) {
      _pauseMainPlayerIfPlaying();
    }
  }

  void openStudioWithSong(SongModel song) {
    currentTabIndex.value = 4; // Switch to Studio tab
    _pauseMainPlayerIfPlaying();
    final studioController = Get.find<AudioStudioController>();
    studioController.loadSong(song);
  }

  void _pauseMainPlayerIfPlaying() {
    try {
      if (Get.isRegistered<AudioPlayerController>()) {
        final playerCtrl = Get.find<AudioPlayerController>();
        if (playerCtrl.isPlaying.value) {
          playerCtrl.audioHandler.pause();
        }
      }
    } catch (_) {}
  }
}
