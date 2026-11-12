import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/localization/soniq_localizations.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/models/song_model.dart';
import '../../../core/widgets/soniq_card.dart';
import '../../../core/widgets/track_tile.dart';
import '../../home/controllers/home_controller.dart';
import '../../library/controllers/library_controller.dart';
import '../../player/controllers/player_controller.dart';
import '../controllers/favorites_controller.dart';
import '../controllers/playlist_controller.dart';
import '../controllers/smart_playlist_controller.dart';
import 'ai_playlist_generator_sheet.dart';
import 'favorites_view.dart';
import 'playlist_detail_view.dart';
import 'smart_playlist_detail_view.dart';
import 'smart_playlist_generator_dialog.dart';

class PlaylistsView extends StatefulWidget {
  const PlaylistsView({super.key});

  @override
  State<PlaylistsView> createState() => _PlaylistsViewState();
}

class _PlaylistsViewState extends State<PlaylistsView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<SongModel> _getLibrary() {
    if (Get.isRegistered<LibraryController>()) {
      final lib = Get.find<LibraryController>();
      if (lib.allSongs.isNotEmpty) return lib.allSongs.toList();
    }
    if (Get.isRegistered<SmartPlaylistController>()) {
      final cached = Get.find<SmartPlaylistController>().cacheService
          .getCachedSongs();
      if (cached.isNotEmpty) return cached;
    }
    if (Get.isRegistered<HomeController>()) {
      final home = Get.find<HomeController>();
      if (home.recentlyAdded.isNotEmpty) return home.recentlyAdded.toList();
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final strings = SoniqLocalizations.of(context);
    final playlistController = Get.find<PlaylistController>();
    final smartCtrl = Get.find<SmartPlaylistController>();
    final playerController = Get.find<AudioPlayerController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            // Top App Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        strings.text('playlists'),
                        style: AppTypography.displayLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.auto_awesome_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
                          tooltip: strings.text('aiPlaylistStudio'),
                          onPressed: () =>
                              SmartPlaylistGeneratorDialog.show(context),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.add_rounded,
                            color: AppColors.gold,
                            size: 28,
                          ),
                          tooltip: strings.text('createPlaylist'),
                          onPressed: () => _showCreatePlaylistDialog(
                            context,
                            playlistController,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Tab Bar: AI Smart Playlists vs Manual Playlists
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border, width: 0.8),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2E2200), Color(0xFF1F1A00)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.gold, width: 1.2),
                    ),
                    labelColor: AppColors.gold,
                    unselectedLabelColor: AppColors.textSecondary,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    dividerColor: Colors.transparent,
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome_rounded, size: 16),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                strings.text('aiSmartPlaylists'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.queue_music_rounded, size: 16),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                strings.text('manual'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildSmartPlaylistsTab(context, smartCtrl, playerController),
              _buildManualPlaylistsTab(
                context,
                playlistController,
                playerController,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: AI SMART PLAYLISTS
  // ==========================================

  Widget _buildSmartPlaylistsTab(
    BuildContext context,
    SmartPlaylistController smartCtrl,
    AudioPlayerController playerCtrl,
  ) {
    final strings = SoniqLocalizations.of(context);
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // AI Generator Studio Card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: SoniqCard(
              onTap: () => SmartPlaylistGeneratorDialog.show(context),
              gradient: const LinearGradient(
                colors: [Color(0xFF2E1065), Color(0xFF160D2E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                strings.text('aiPlaylistStudio'),
                                style: AppTypography.headlineSmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD946EF)
                                    .withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFD946EF),
                                  width: 0.8,
                                ),
                              ),
                              child: const Text(
                                'OFFLINE MIR',
                                style: TextStyle(
                                  color: Color(0xFFE879F9),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          strings.text('generateMoodEnergyMixes'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: AppColors.textMuted,
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Quick Vibe Mixes Option
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => AiPlaylistGeneratorSheet.show(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, width: 0.8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.bolt_rounded, color: AppColors.gold, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        strings.text('quickVibeGenerator'),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // MIR Audio Analysis Progress Bar (if running)
        SliverToBoxAdapter(
          child: Obx(() {
            if (smartCtrl.isAnalyzing.value) {
              final pct = (smartCtrl.analysisProgress.value * 100).toInt();
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1D2B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.gold,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                strings.text('analyzingAudioOffline'),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '$pct%',
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: smartCtrl.analysisProgress.value,
                          backgroundColor: AppColors.surface,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.gold,
                          ),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          }),
        ),

        // Section Title: Dynamic Smart Playlists
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    strings.text('aiMoodEnergyPlaylists'),
                    style: AppTypography.headlineMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Obx(
                  () => Text(
                    '${smartCtrl.smartPlaylists.length} Smart',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Smart Playlists Grid/List
        Obx(() {
          final lists = smartCtrl.smartPlaylists;
          final library = _getLibrary();

          if (lists.isEmpty) {
            return SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    strings.text('noSmartPlaylists'),
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              ),
            );
          }

          return SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final pl = lists[index];
                final matchedSongs = smartCtrl.evaluatePlaylist(pl, library);
                final color = Color(pl.colorHex);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: SoniqCard(
                    padding: const EdgeInsets.all(12),
                    onTap: () =>
                        Get.to(() => SmartPlaylistDetailView(playlist: pl)),
                    child: Row(
                      children: [
                        // Mood Color Icon
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                color.withValues(alpha: 0.8),
                                color.withValues(alpha: 0.3),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: color.withValues(alpha: 0.5),
                              width: 1.2,
                            ),
                          ),
                          child: Icon(
                            _getIconForPlaylist(
                              pl.rules.selectedMoods.isNotEmpty
                                  ? pl.rules.selectedMoods.first
                                  : '',
                            ),
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Playlist Title & Rules Summary
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      pl.name,
                                      style: AppTypography.labelLarge.copyWith(
                                        fontSize: 15,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'SMART',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                pl.description.isNotEmpty
                                    ? pl.description
                                    : '${matchedSongs.length} tracks matched',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // Track Count Pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.border,
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            '${matchedSongs.length}',
                            style: TextStyle(
                              color: color,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Play Button
                        IconButton(
                          icon: const Icon(
                            Icons.play_circle_fill_rounded,
                            color: AppColors.gold,
                            size: 32,
                          ),
                          tooltip: strings.text('playSmartPlaylist'),
                          onPressed: () {
                            if (matchedSongs.isNotEmpty) {
                              playerCtrl.playSong(
                                matchedSongs.first,
                                matchedSongs,
                              );
                            } else {
                              Get.snackbar(
                                pl.name,
                                strings.text('noMatchingTracks'),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }, childCount: lists.length),
            ),
          );
        }),
      ],
    );
  }

  // ==========================================
  // TAB 2: MANUAL PLAYLISTS
  // ==========================================

  Widget _buildManualPlaylistsTab(
    BuildContext context,
    PlaylistController playlistController,
    AudioPlayerController playerController,
  ) {
    final strings = SoniqLocalizations.of(context);
    final homeController = Get.find<HomeController>();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Smart Auto-Playlists Cards (Favorites & Recently Played)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              children: [
                // Favorites Smart Card
                Expanded(
                  child: Obx(() {
                    final favCtrl = Get.find<FavoritesController>();
                    final favCount = favCtrl.favoriteSongs.length;
                    return SoniqCard(
                      onTap: () => Get.to(() => const FavoritesView()),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B132C), Color(0xFF1B121D)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.favorite_rounded,
                            color: AppColors.primary,
                            size: 28,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            strings.text('favorites'),
                            style: AppTypography.headlineSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$favCount tracks',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
                const SizedBox(width: 12),
                // Recently Played Smart Card
                Expanded(
                  child: Obx(() {
                    final recentCount = homeController.recentlyPlayed.length;
                    return SoniqCard(
                      onTap: () => _openSmartPlaylist(
                        context,
                        'Recently Played',
                        homeController.recentlyPlayed,
                        playerController,
                      ),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF16253B), Color(0xFF101622)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.history_rounded,
                            color: AppColors.cyan,
                            size: 28,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            strings.text('recentlyPlayed'),
                            style: AppTypography.headlineSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$recentCount tracks',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 16, 8),
            child: Text(
              strings.text('yourPlaylists'),
              style: AppTypography.headlineMedium,
            ),
          ),
        ),

        // User Playlists List
        Obx(() {
          final lists = playlistController.playlists;
          if (lists.isEmpty) {
            return SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 32,
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.queue_music_rounded,
                        size: 48,
                        color: AppColors.textMuted.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        strings.text('noCustomPlaylists'),
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.add, color: AppColors.primary),
                        label: Text(
                          strings.text('createPlaylist'),
                          style: const TextStyle(color: AppColors.primary),
                        ),
                        onPressed: () => _showCreatePlaylistDialog(
                          context,
                          playlistController,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final pl = lists[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: SoniqCard(
                    padding: const EdgeInsets.all(12),
                    onTap: () => Get.to(() => PlaylistDetailView(playlist: pl)),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.border,
                              width: 0.8,
                            ),
                          ),
                          child: const Icon(
                            Icons.queue_music_rounded,
                            color: AppColors.secondary,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pl.name,
                                style: AppTypography.labelLarge.copyWith(
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${pl.songCount} songs',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.play_arrow_rounded,
                            color: AppColors.primary,
                            size: 28,
                          ),
                          onPressed: () =>
                              playlistController.playEntirePlaylist(pl),
                        ),
                      ],
                    ),
                  ),
                );
              }, childCount: lists.length),
            ),
          );
        }),
      ],
    );
  }

  IconData _getIconForPlaylist(String mood) {
    switch (mood) {
      case 'Love & Romance':
        return Icons.favorite_rounded;
      case 'Fast Beat':
      case 'Workout':
        return Icons.offline_bolt_rounded;
      case 'Sad & Emotional':
        return Icons.water_drop_rounded;
      case 'Chill & Relax':
      case 'Sleep':
        return Icons.spa_rounded;
      case 'Party':
        return Icons.celebration_rounded;
      case 'Motivation':
      case 'Focus':
        return Icons.fitness_center_rounded;
      case 'Road Trip':
        return Icons.directions_car_rounded;
      case 'Devotional':
        return Icons.self_improvement_rounded;
      case 'Tamil Melody':
      case 'Melody':
        return Icons.music_note_rounded;
      case 'Tamil Kuthu':
        return Icons.music_note_rounded;
      case 'Instrumental':
        return Icons.piano_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  void _openSmartPlaylist(
    BuildContext context,
    String title,
    List<dynamic> songs,
    AudioPlayerController playerCtrl,
  ) {
    if (songs.isEmpty) {
      Get.snackbar(title, 'No songs in $title yet.');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$title (${songs.length})',
                    style: AppTypography.headlineMedium,
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.play_circle_fill_rounded,
                      color: AppColors.primary,
                      size: 32,
                    ),
                    onPressed: () {
                      playerCtrl.playSong(songs.first, songs.cast());
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.border, height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: songs.length,
                itemBuilder: (ctx, idx) => TrackTile(
                  song: songs[idx],
                  isPlaying: playerCtrl.currentSong.value?.id == songs[idx].id,
                  onTap: () {
                    playerCtrl.playSong(songs[idx], songs.cast());
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreatePlaylistDialog(
    BuildContext context,
    PlaylistController controller,
  ) {
    final strings = SoniqLocalizations.of(context);
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text(
          strings.text('newPlaylist'),
          style: AppTypography.headlineMedium,
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: strings.text('playlistName'),
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            child: Text(
              strings.text('cancel'),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text(
              strings.text('create'),
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () {
              if (textController.text.trim().isNotEmpty) {
                controller.createPlaylist(textController.text);
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
