import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:on_audio_query/on_audio_query.dart' hide SongModel;
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/models/song_model.dart';
import '../../../core/models/recommendation_model.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../../core/widgets/mini_player_widget.dart';
import '../controllers/discovery_controller.dart';
import 'widgets/discovery_settings_dialog.dart';
import 'widgets/recommendation_feedback_dialog.dart';

class DiscoveryView extends StatelessWidget {
  const DiscoveryView({super.key});

  @override
  Widget build(BuildContext context) {
    final discoveryCtrl = Get.isRegistered<DiscoveryController>()
        ? Get.find<DiscoveryController>()
        : Get.put(DiscoveryController());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Music Intelligence', style: AppTypography.headlineMedium),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            tooltip: 'Regenerate Mixes',
            onPressed: () {
              HapticFeedback.mediumImpact();
              discoveryCtrl.loadDiscovery(force: true);
              Get.snackbar(
                'Mixes Refreshed',
                'Generated fresh recommendations from your library.',
                snackPosition: SnackPosition.BOTTOM,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: AppColors.gold),
            tooltip: 'Discovery Settings',
            onPressed: () => DiscoverySettingsDialog.show(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          Obx(() {
            if (discoveryCtrl.isLoading.value) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              );
            }

            final dailyMixes = discoveryCtrl.dailyMixes;
            final discoverMix = discoveryCtrl.discoverMix.value;
            final forgottenGems = discoveryCtrl.forgottenGems.value;
            final becauseMix = discoveryCtrl.becauseYouListened.value;
            final artistRadios = discoveryCtrl.artistRadios;
            final moodMixes = discoveryCtrl.moodMixes;

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Top Subtitle & Tagline
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    child: Text(
                      'Personalized offline recommendations powered by your genuine listening history and local music collection.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),

                // 1. DAILY MIXES CAROUSEL
                if (dailyMixes.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _buildSectionHeader(
                      title: 'DAILY MIXES',
                      subtitle: 'Made for You • Updated daily',
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 240,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: dailyMixes.length,
                        itemBuilder: (context, index) {
                          final mix = dailyMixes[index];
                          return _buildDailyMixCard(context, mix, discoveryCtrl);
                        },
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],

                // 2. BECAUSE YOU LISTENED TO...
                if (becauseMix != null && becauseMix.songs.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _buildSectionHeader(
                      title: 'BECAUSE YOU LISTENED TO',
                      subtitle: becauseMix.subtitle,
                      actionLabel: 'Play All',
                      onAction: () => discoveryCtrl.playMix(becauseMix),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 180,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: becauseMix.songs.length,
                        itemBuilder: (context, index) {
                          final song = becauseMix.songs[index];
                          return _buildRecommendedTrackCard(
                            context,
                            song,
                            becauseMix,
                            index,
                            discoveryCtrl,
                          );
                        },
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],

                // 3. DISCOVER MIX (DEEP CUTS HERO BANNER)
                if (discoverMix != null && discoverMix.songs.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _buildDiscoverMixHero(context, discoverMix, discoveryCtrl),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],

                // 4. ARTIST RADIO
                if (artistRadios.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _buildSectionHeader(
                      title: 'ARTIST RADIO',
                      subtitle: 'Continuous stations rooted in your favorite artists',
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 160,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: artistRadios.length,
                        itemBuilder: (context, index) {
                          final radio = artistRadios[index];
                          return _buildArtistRadioCard(context, radio, discoveryCtrl);
                        },
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],

                // 5. FORGOTTEN GEMS
                if (forgottenGems != null && forgottenGems.songs.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _buildSectionHeader(
                      title: 'FORGOTTEN GEMS',
                      subtitle: 'Past favorites you haven\'t played recently',
                      actionLabel: 'Play All',
                      onAction: () => discoveryCtrl.playMix(forgottenGems),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 180,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: forgottenGems.songs.length,
                        itemBuilder: (context, index) {
                          final song = forgottenGems.songs[index];
                          return _buildRecommendedTrackCard(
                            context,
                            song,
                            forgottenGems,
                            index,
                            discoveryCtrl,
                          );
                        },
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],

                // 6. MOOD MIXES
                if (moodMixes.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _buildSectionHeader(
                      title: 'MOOD STATIONS',
                      subtitle: 'Music tuned to your activities and energy levels',
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.5,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final mix = moodMixes[index];
                          return _buildMoodMixTile(context, mix, discoveryCtrl);
                        },
                        childCount: moodMixes.length,
                      ),
                    ),
                  ),
                ],

                // Bottom Padding for persistent Mini Player
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            );
          }),

          // Persistent Mini Player
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MiniPlayerWidget(),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // UI WIDGET BUILDERS
  // ==========================================

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.gold,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(actionLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }

  Widget _buildDailyMixCard(
    BuildContext context,
    RecommendationMix mix,
    DiscoveryController discoveryCtrl,
  ) {
    return Container(
      width: 175,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E202B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: mix.accentColor.withValues(alpha: 0.35), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Artwork Quadrant
            Stack(
              children: [
                Container(
                  height: 115,
                  width: double.infinity,
                  color: mix.accentColor.withValues(alpha: 0.15),
                  child: mix.songs.isNotEmpty
                      ? QueryArtworkWidget(
                          id: int.tryParse(mix.songs.first.id) ?? 0,
                          type: ArtworkType.AUDIO,
                          artworkFit: BoxFit.cover,
                          nullArtworkWidget: Center(
                            child: Icon(mix.icon, color: mix.accentColor, size: 36),
                          ),
                        )
                      : Center(child: Icon(mix.icon, color: mix.accentColor, size: 36)),
                ),
                // Gradient overlay
                Container(
                  height: 115,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF1E202B).withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                ),
                // Floating Play Button
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      discoveryCtrl.playMix(mix);
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: mix.accentColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 24),
                    ),
                  ),
                ),
              ],
            ),

            // Mix Details
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mix.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mix.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${mix.songCount} tracks',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      // Save Mix button
                      GestureDetector(
                        onTap: () => discoveryCtrl.saveMixAsPlaylist(mix),
                        child: const Icon(Icons.playlist_add_rounded, color: AppColors.textMuted, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoverMixHero(
    BuildContext context,
    RecommendationMix mix,
    DiscoveryController discoveryCtrl,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF381440),
            const Color(0xFF1B1D28),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF9C27B0).withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF9C27B0).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.explore_rounded, color: Color(0xFFCE93D8), size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DISCOVER MIX', style: TextStyle(color: Color(0xFFCE93D8), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                    Text('Unexplored tracks in your collection', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.playlist_add_rounded, color: AppColors.textSecondary),
                tooltip: 'Save as Playlist',
                onPressed: () => discoveryCtrl.saveMixAsPlaylist(mix),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            mix.description,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.3),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '${mix.songCount} songs • ${DurationFormatter.format(mix.totalDurationMs)}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9C27B0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: const Text('Play Mix', style: TextStyle(fontWeight: FontWeight.w700)),
                onPressed: () => discoveryCtrl.playMix(mix),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedTrackCard(
    BuildContext context,
    SongModel song,
    RecommendationMix mix,
    int index,
    DiscoveryController discoveryCtrl,
  ) {
    return Container(
      width: 135,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          discoveryCtrl.playMix(mix, startIndex: index);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Artwork
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 135,
                height: 115,
                child: Stack(
                  children: [
                    QueryArtworkWidget(
                      id: int.tryParse(song.id) ?? 0,
                      type: ArtworkType.AUDIO,
                      artworkFit: BoxFit.cover,
                      nullArtworkWidget: Container(
                        color: AppColors.surfaceHighlight,
                        child: const Icon(Icons.music_note_rounded, color: AppColors.gold, size: 28),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          RecommendationFeedbackDialog.show(context, song);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
            ),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtistRadioCard(
    BuildContext context,
    RecommendationMix radio,
    DiscoveryController discoveryCtrl,
  ) {
    return Container(
      width: 140,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E202B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: radio.accentColor.withValues(alpha: 0.3), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => discoveryCtrl.playMix(radio, shuffle: true),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: radio.accentColor.withValues(alpha: 0.15),
                  border: Border.all(color: radio.accentColor, width: 1.5),
                ),
                child: Icon(radio.icon, color: radio.accentColor, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                radio.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                '${radio.songCount} tracks',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoodMixTile(
    BuildContext context,
    RecommendationMix mix,
    DiscoveryController discoveryCtrl,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E202B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: mix.accentColor.withValues(alpha: 0.3), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => discoveryCtrl.playMix(mix),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: mix.accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(mix.icon, color: mix.accentColor, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      mix.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    Text(
                      '${mix.songCount} tracks',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
