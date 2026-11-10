import 'package:get/get.dart';
import '../../../core/models/song_model.dart';
import '../../audio_studio/controllers/audio_studio_controller.dart';

class NavigationController extends GetxController {
  final RxInt currentTabIndex = 0.obs;

  void changeTab(int index) {
    currentTabIndex.value = index;
  }

  void openStudioWithSong(SongModel song) {
    currentTabIndex.value = 4; // Switch to Studio tab
    final studioController = Get.find<AudioStudioController>();
    studioController.loadSong(song);
  }
}
