import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:on_audio_query/on_audio_query.dart' hide SongModel;

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/models/song_model.dart';
import '../../../core/database/song_cache_service.dart';
import '../../../core/widgets/soniq_card.dart';
import '../../../core/widgets/track_tile.dart';
import '../../../core/widgets/soniq_empty_state.dart';
import '../../player/controllers/player_controller.dart';
import '../../library/controllers/library_controller.dart';
import '../../navigation/controllers/navigation_controller.dart';
import '../../settings/views/settings_view.dart';
import '../../car_mode/views/car_mode_view.dart';
import '../../analytics/views/analytics_dashboard_view.dart';
import '../controllers/home_controller.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final homeController = Get.find<HomeController>();
    final libraryController = Get.find<LibraryController>();
    final playerController = Get.find<AudioPlayerController>();
    final navController = Get.find<NavigationController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Obx(() {
          final allSongs = libraryController.allSongs;

          if (allSongs.isEmpty && !libraryController.isScanning.value) {
            return SoniqEmptyState(
              icon: Icons.graphic_eq_rounded,
              title: 'Welcome to SONIQ',
              description: 'SONIQ is ready to scan your offline music library and unlock the MP3 Ringtone Studio.',
              buttonText: 'Scan Audio Library',
              onButtonPressed: () => libraryController.scanLibrary(),
            );
          }

          final favs = homeController.favorites;
          final recent = homeController.recentlyPlayed;
          final added = homeController.recentlyAdded;
          final activeFilter = homeController.activeMixFilter.value;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. Top Brand Header with "S" Logo & Greeting (Matches Reference Image 4)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: [
                      // Iconic 'S' Soundwave Logo Badge
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.asset(
                            'assets/icons/app_icon.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),

                      const SizedBox(width: 14),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getGreeting(),
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textMuted,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const Text(
                              'SONIQ Music',
                              style: AppTypography.headlineMedium,
                            ),
                          ],
                        ),
                      ),

                      // Quick Scan / Refresh Button
                      IconButton(
                        icon: const Icon(
                          Icons.sync_rounded,
                          color: AppColors.textSecondary,
                        ),
                        tooltip: 'Scan Library',
                        onPressed: () => libraryController.scanLibrary(),
                      ),

                      // Renault Triber Car Mode Button
                      IconButton(
                        icon: const Icon(
                          Icons.directions_car_rounded,
                          color: AppColors.gold,
                        ),
                        tooltip: 'Renault Triber Car Mode',
                        onPressed: () => Get.to(
                          () => const CarModeView(),
                          transition: Transition.fadeIn,
                          duration: const Duration(milliseconds: 250),
                        ),
                      ),

                      // Listening Analytics Button
                      IconButton(
                        icon: const Icon(
                          Icons.insights_rounded,
                          color: AppColors.primary,
                        ),
                        tooltip: 'Listening Analytics',
                        onPressed: () => Get.to(
                          () => const AnalyticsDashboardView(),
                          transition: Transition.rightToLeft,
                        ),
                      ),

                      // Settings Button
                      IconButton(
                        icon: const Icon(
                          Icons.settings_outlined,
                          color: AppColors.textSecondary,
                        ),
                        tooltip: 'Settings',
                        onPressed: () => Get.to(() => const SettingsView()),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Mix Filter Category Pills (Matches Reference Image 4: Song mix, Album mix, Decade mix)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Row(
                    children: homeController.mixFilters.map((filter) {
                      final isSelected = activeFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            if (SongCacheService().getSetting(
                                  'haptic_feedback_enabled',
                                  defaultValue: true,
                                ) ==
                                true) {
                              HapticFeedback.selectionClick();
                            }
                            homeController.setMixFilter(filter);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF2E131D)
                                  : AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.border,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  filter == 'Song mix'
                                      ? Icons.tune_rounded
                                      : filter == 'Album mix'
                                      ? Icons.album_rounded
                                      : Icons.calendar_today_rounded,
                                  size: 14,
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.textMuted,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  filter,
                                  style: TextStyle(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // 3. Audio Studio Feature Shortcut Banner
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: SoniqCard(
                    onTap: () => navController.changeTab(4),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2D112A), Color(0xFF14131D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary,
                              width: 1.2,
                            ),
                          ),
                          child: const Icon(
                            Icons.content_cut_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Audio Studio & Ringtone Maker',
                                style: AppTypography.headlineSmall,
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Lossless waveform trimming & direct ringtone export',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: AppColors.primary,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 4. Listening Analytics & Replay Feature Shortcut Banner
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: SoniqCard(
                    onTap: () => Get.to(
                      () => const AnalyticsDashboardView(),
                      transition: Transition.rightToLeft,
                    ),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF28133C), Color(0xFF130E20)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.gold,
                              width: 1.2,
                            ),
                          ),
                          child: const Icon(
                            Icons.insights_rounded,
                            color: AppColors.gold,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Listening Analytics & Replay',
                                style: AppTypography.headlineSmall,
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Explore personal stats, top tracks, streaks & annual recap',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: AppColors.gold,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              if (homeController.todaysMix.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: SoniqCard(
                      onTap: homeController.playTodaysMix,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1D2940), Color(0xFF171521)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.cyan.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.cyan.withValues(alpha: 0.65),
                              ),
                            ),
                            child: const Icon(
                              Icons.auto_awesome_rounded,
                              color: AppColors.cyan,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'YOUR MIX',
                                  style: TextStyle(
                                    color: AppColors.cyan,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  "Today's Mix",
                                  style: AppTypography.headlineSmall,
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Picked from your listening habits',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: "Play today's mix",
                            onPressed: () {
                              if (SongCacheService().getSetting(
                                    'haptic_feedback_enabled',
                                    defaultValue: true,
                                  ) ==
                                  true) {
                                HapticFeedback.selectionClick();
                              }
                              homeController.playTodaysMix();
                            },
                            icon: const Icon(
                              Icons.play_circle_fill_rounded,
                              color: AppColors.cyan,
                              size: 38,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              if (homeController.todaysMix.isNotEmpty)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 180,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      itemCount: homeController.todaysMix.length,
                      itemBuilder: (context, index) => _buildCarouselCard(
                        homeController.todaysMix[index],
                        homeController.todaysMix,
                        playerController,
                      ),
                    ),
                  ),
                ),

              // 4. Favourite Tracks Horizontal Carousel (Matches Reference Image 4)
              if (favs.isNotEmpty)
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Favourite Tracks',
                              style: AppTypography.headlineMedium,
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 180,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: favs.length,
                          itemBuilder: (context, index) {
                            final song = favs[index];
                            return _buildCarouselCard(
                              song,
                              favs,
                              playerController,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

              // 5. Recently Played Carousel
              if (recent.isNotEmpty)
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
                        child: Text(
                          'Recently Played',
                          style: AppTypography.headlineMedium,
                        ),
                      ),
                      SizedBox(
                        height: 180,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: recent.length,
                          itemBuilder: (context, index) {
                            final song = recent[index];
                            return _buildCarouselCard(
                              song,
                              recent,
                              playerController,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

              // 6. Recently Added Music List
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recently Added',
                        style: AppTypography.headlineMedium,
                      ),
                    ],
                  ),
                ),
              ),

              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final song = added[index];
                  return TrackTile(
                    song: song,
                    isPlaying:
                        playerController.currentSong.value?.id == song.id,
                    onTap: () => playerController.playSong(song, added),
                  );
                }, childCount: added.length),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildCarouselCard(
    SongModel song,
    List<SongModel> playlist,
    AudioPlayerController playerController,
  ) {
    final int? audioId = int.tryParse(song.id);
    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () => playerController.playSong(song, playlist),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Artwork with play button overlay
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border, width: 0.8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: audioId != null
                        ? QueryArtworkWidget(
                            id: audioId,
                            type: ArtworkType.AUDIO,
                            artworkBorder: BorderRadius.circular(16),
                            nullArtworkWidget: _buildFallbackArtwork(),
                            errorBuilder: (_, _, _) => _buildFallbackArtwork(),
                          )
                        : _buildFallbackArtwork(),
                  ),
                ),
                // Play Button badge on cover (Matches Reference Image 4)
                Container(
                  margin: const EdgeInsets.all(8),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackArtwork() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF281E32), Color(0xFF14121F)],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.music_note_rounded,
          size: 36,
          color: AppColors.primary,
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }
}
