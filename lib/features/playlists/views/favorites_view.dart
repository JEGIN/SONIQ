import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/track_tile.dart';
import '../../../core/widgets/soniq_button.dart';
import '../../../core/widgets/soniq_empty_state.dart';
import '../../../core/widgets/soniq_floating_playback_bar.dart';
import '../../navigation/controllers/navigation_controller.dart';
import '../../player/controllers/player_controller.dart';
import '../../library/controllers/library_controller.dart';
import '../controllers/favorites_controller.dart';

class FavoritesView extends StatefulWidget {
  const FavoritesView({super.key});

  @override
  State<FavoritesView> createState() => _FavoritesViewState();
}

class _FavoritesViewState extends State<FavoritesView> {
  bool _isSearchExpanded = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final favController = Get.find<FavoritesController>();
    final playerController = Get.find<AudioPlayerController>();
    final navController = Get.find<NavigationController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Favorites', style: AppTypography.displayMedium),
        actions: [
          IconButton(
            icon: Icon(
              _isSearchExpanded ? Icons.close_rounded : Icons.search_rounded,
              color: AppColors.textPrimary,
            ),
            tooltip: 'Search Favorites',
            onPressed: () {
              setState(() {
                _isSearchExpanded = !_isSearchExpanded;
                if (!_isSearchExpanded) {
                  _searchController.clear();
                  favController.updateSearch('');
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.sort_rounded, color: AppColors.textPrimary),
            tooltip: 'Sort Favorites',
            onPressed: () => _showSortModal(context, favController),
          ),
        ],
      ),
      body: SafeArea(
        child: Obx(() {
          final favSongs = favController.filteredFavoriteSongs;
          final totalCount = favController.favoriteSongs.length;

          if (totalCount == 0) {
            return Center(
              child: SoniqEmptyState(
                icon: Icons.favorite_border_rounded,
                title: 'No Favorites Yet',
                description: 'Tap the heart icon on any song in your music library to save it to your Favorites collection.',
                buttonText: 'Browse Library',
                onButtonPressed: () {
                  Navigator.of(context).pop();
                  navController.changeTab(1); // Go to Library tab
                },
              ),
            );
          }

          return Stack(
            children: [
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // 1. Search Bar (when expanded)
                  if (_isSearchExpanded)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      onChanged: (val) => favController.updateSearch(val),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search in favorites...',
                        hintStyle: const TextStyle(color: AppColors.textMuted),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
                        filled: true,
                        fillColor: AppColors.surfaceElevated,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                  ),
                ),

              // 2. Hero Header Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B1527), Color(0xFF1B111A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.primary, width: 1.5),
                              ),
                              child: const Icon(Icons.favorite_rounded, color: AppColors.primary, size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Favorites Collection', style: AppTypography.headlineMedium),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$totalCount tracks • Offline Favorites',
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        // Action Buttons: Play All & Shuffle
                        Row(
                          children: [
                            Expanded(
                              child: SoniqButton(
                                text: 'Play All ($totalCount)',
                                icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                                onPressed: () => favController.playAll(shuffle: false),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SoniqButton(
                                text: 'Shuffle',
                                variant: SoniqButtonVariant.secondary,
                                icon: const Icon(Icons.shuffle_rounded, color: AppColors.primary),
                                onPressed: () => favController.playAll(shuffle: true),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Search Results Count Header
              if (_isSearchExpanded && _searchController.text.trim().isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Text(
                      'Search Results (${favSongs.length})',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),

              // 4. Songs List
              if (favSongs.isEmpty && _isSearchExpanded)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'No matching songs found in Favorites',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 80),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final song = favSongs[index];
                        return TrackTile(
                          song: song,
                          isPlaying: playerController.currentSong.value?.id == song.id,
                          onTap: () {
                            playerController.playSong(song, favSongs);
                          },
                        );
                      },
                      childCount: favSongs.length,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: playerController.currentSong.value != null ? 165 : 100,
                  ),
                ),
              ],
            ),
            SoniqFloatingPlaybackBar(
              songs: favSongs,
              collectionTitle: 'Favorites',
            ),
          ],
        );
        }),
      ),
    );
  }

  void _showSortModal(BuildContext context, FavoritesController controller) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Sort Favorites', style: AppTypography.headlineMedium),
              ),
              const Divider(color: AppColors.border, height: 1),
              ...SongSortOption.values.map((option) {
                final isSelected = controller.sortOption.value == option;
                return ListTile(
                  leading: Icon(
                    isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    color: isSelected ? AppColors.primary : AppColors.textMuted,
                  ),
                  title: Text(
                    option.label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(option.subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  onTap: () {
                    controller.setSortOption(option);
                    Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
