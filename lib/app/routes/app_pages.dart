import 'package:get/get.dart';
import '../../features/navigation/views/main_navigation_screen.dart';
import '../../features/player/views/now_playing_view.dart';
import '../../features/audio_studio/views/audio_studio_view.dart';
import '../../features/car_mode/views/car_mode_view.dart';
import 'app_routes.dart';

class AppPages {
  AppPages._();

  static const initial = Routes.main;

  static final routes = [
    GetPage(
      name: Routes.main,
      page: () => const MainNavigationScreen(),
    ),
    GetPage(
      name: Routes.nowPlaying,
      page: () => const NowPlayingView(),
      transition: Transition.downToUp,
    ),
    GetPage(
      name: Routes.studio,
      page: () => const AudioStudioView(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: Routes.carMode,
      page: () => const CarModeView(),
      transition: Transition.fadeIn,
    ),
  ];
}
