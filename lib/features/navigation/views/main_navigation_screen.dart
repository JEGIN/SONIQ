import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/localization/soniq_localizations.dart';
import '../../../core/widgets/mini_player_widget.dart';
import '../../home/views/home_view.dart';
import '../../library/views/library_view.dart';
import '../../equalizer/views/equalizer_view.dart';
import '../../playlists/views/playlists_view.dart';
import '../../audio_studio/views/audio_studio_view.dart';
import '../controllers/navigation_controller.dart';

class MainNavigationScreen extends StatelessWidget {
  const MainNavigationScreen({super.key});

  static const List<Widget> _screens = [
    HomeView(),
    LibraryView(),
    EqualizerView(),
    PlaylistsView(),
    AudioStudioView(),
  ];

  @override
  Widget build(BuildContext context) {
    final navController = Get.find<NavigationController>();
    final strings = SoniqLocalizations.of(context);

    return Obx(() {
      final currentIndex = navController.currentTabIndex.value;

      return Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            // Screen Pages indexed stack
            IndexedStack(index: currentIndex, children: _screens),

            // Persistent Mini Player above bottom bar
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: MiniPlayerWidget(),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(
              top: BorderSide(color: AppColors.border, width: 0.8),
            ),
          ),
          child: NavigationBar(
            backgroundColor: AppColors.surface,
            indicatorColor: AppColors.primary.withValues(alpha: 0.18),
            selectedIndex: currentIndex,
            onDestinationSelected: (index) => navController.changeTab(index),
            destinations: [
              NavigationDestination(
                icon: const Icon(
                  Icons.home_outlined,
                  color: AppColors.textMuted,
                ),
                selectedIcon: const Icon(
                  Icons.home_rounded,
                  color: AppColors.primary,
                ),
                label: strings.text('home'),
              ),
              NavigationDestination(
                icon: const Icon(
                  Icons.library_music_outlined,
                  color: AppColors.textMuted,
                ),
                selectedIcon: const Icon(
                  Icons.library_music_rounded,
                  color: AppColors.primary,
                ),
                label: strings.text('library'),
              ),
              NavigationDestination(
                icon: const Icon(
                  Icons.tune_outlined,
                  color: AppColors.textMuted,
                ),
                selectedIcon: const Icon(
                  Icons.tune_rounded,
                  color: AppColors.gold,
                ),
                label: strings.text('equalizer'),
              ),
              NavigationDestination(
                icon: const Icon(
                  Icons.queue_music_outlined,
                  color: AppColors.textMuted,
                ),
                selectedIcon: const Icon(
                  Icons.queue_music_rounded,
                  color: AppColors.primary,
                ),
                label: strings.text('playlists'),
              ),
              NavigationDestination(
                icon: const Icon(
                  Icons.graphic_eq_rounded,
                  color: AppColors.textMuted,
                ),
                selectedIcon: const Icon(
                  Icons.graphic_eq_rounded,
                  color: AppColors.primary,
                ),
                label: strings.text('studio'),
              ),
            ],
          ),
        ),
      );
    });
  }
}
