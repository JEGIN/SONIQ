import 'dart:math';
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:on_audio_query/on_audio_query.dart' hide SongModel;
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/models/song_model.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../playlists/controllers/playlist_controller.dart';
import '../../../playlists/controllers/favorites_controller.dart';
import '../../controllers/player_controller.dart';
import 'audio_quality_sheet.dart';
import '../../../discovery/views/widgets/similar_songs_sheet.dart';

class QueueBottomSheet extends StatefulWidget {
  const QueueBottomSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const QueueBottomSheet(),
    );
  }

  @override
  State<QueueBottomSheet> createState() => _QueueBottomSheetState();
}

class _QueueBottomSheetState extends State<QueueBottomSheet> with SingleTickerProviderStateMixin {
  final playerController = Get.find<AudioPlayerController>();
  final playlistController = Get.find<PlaylistController>();

  bool _isSearchActive = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  int _selectedTab = 0; // 0: Upcoming, 1: History

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sheetHeight = MediaQuery.of(context).size.height * 0.85;

    return Material(
      color: Colors.transparent,
      child: Container(
        height: sheetHeight,
        decoration: const BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // 1. Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 6),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // 2. Queue Header Toolbar
            _buildHeaderToolbar(context),

            // 3. Search Bar (when active)
            if (_isSearchActive) _buildSearchBar(),

            // 4. Tab Selector (Upcoming vs History)
            _buildTabSelector(),

            const Divider(color: AppColors.border, height: 1),

            // 5. Main Queue Body
            Expanded(
              child: Obx(() {
                if (_selectedTab == 1) {
                  return _buildHistoryList();
                }
                return _buildUpcomingQueueList();
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderToolbar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 12, 6),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Playback Queue', style: AppTypography.headlineMedium),
              Obx(() {
                final total = playerController.queue.length;
                final currIdx = playerController.currentIndex.value;
                final upcomingCount = max(0, total - currIdx - 1);
                final upcomingSongs = (currIdx < total - 1)
                    ? playerController.queue.sublist(currIdx + 1)
                    : <SongModel>[];
                final upcomingDurMs = upcomingSongs.fold<int>(
                  0,
                  (sum, s) => sum + s.durationMs,
                );
                final durStr = DurationFormatter.format(upcomingDurMs);

                return Text(
                  upcomingCount > 0
                      ? '$total tracks • $upcomingCount upcoming ($durStr)'
                      : '$total tracks • Queue ending',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }),
            ],
          ),
          const Spacer(),

          // Search Toggle
          IconButton(
            icon: Icon(
              _isSearchActive ? Icons.search_off_rounded : Icons.search_rounded,
              color: _isSearchActive ? AppColors.gold : AppColors.textSecondary,
              size: 22,
            ),
            tooltip: 'Search Queue',
            onPressed: () {
              setState(() {
                _isSearchActive = !_isSearchActive;
                if (!_isSearchActive) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
            },
          ),

          // Save Queue as Playlist
          IconButton(
            icon: const Icon(Icons.playlist_add_rounded, color: AppColors.textSecondary, size: 24),
            tooltip: 'Save Queue as Playlist',
            onPressed: () => _showSaveQueueDialog(context),
          ),

          // Clear Upcoming Queue
          IconButton(
            icon: const Icon(Icons.clear_all_rounded, color: AppColors.textSecondary, size: 24),
            tooltip: 'Clear Upcoming Queue',
            onPressed: () => _confirmClearQueue(context),
          ),

          // Close
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFF1E202B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 0.8),
        ),
        child: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Filter songs in queue...',
            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.gold, size: 18),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 16),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
          onChanged: (val) {
            setState(() => _searchQuery = val.trim().toLowerCase());
          },
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: _buildTabPill(
              title: 'Upcoming Queue',
              index: 0,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildTabPill(
              title: 'History',
              index: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabPill({required String title, required int index}) {
    final isSelected = _selectedTab == index;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _selectedTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2E2200) : const Color(0xFF181A24),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.gold : AppColors.border,
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? AppColors.gold : AppColors.textSecondary,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // UPCOMING QUEUE LIST WITH DRAG & DROP
  // ==========================================

  Widget _buildUpcomingQueueList() {
    final fullQueue = playerController.queue;
    if (fullQueue.isEmpty) {
      return const Center(
        child: Text('Playback queue is empty', style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    final currIdx = playerController.currentIndex.value.clamp(0, fullQueue.length - 1);
    final currentSong = playerController.currentSong.value ?? fullQueue[currIdx];

    // Upcoming items are those after current index
    List<SongModel> upcomingList;
    if (currIdx < fullQueue.length - 1) {
      upcomingList = fullQueue.sublist(currIdx + 1);
    } else {
      upcomingList = [];
    }

    // Filter by search query if active
    if (_searchQuery.isNotEmpty) {
      upcomingList = upcomingList.where((s) =>
          s.title.toLowerCase().contains(_searchQuery) ||
          s.artist.toLowerCase().contains(_searchQuery) ||
          s.album.toLowerCase().contains(_searchQuery)).toList();
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // 1. NOW PLAYING SECTION
        SliverToBoxAdapter(
          child: _buildNowPlayingSection(currentSong),
        ),

        // 2. UPCOMING HEADER
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _searchQuery.isNotEmpty
                      ? 'MATCHING RESULTS (${upcomingList.length})'
                      : 'NEXT IN QUEUE (${upcomingList.length})',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: AppColors.textMuted,
                  ),
                ),
                if (upcomingList.length > 1)
                  Text(
                    _searchQuery.isNotEmpty
                        ? 'Clear search to drag & reorder'
                        : 'Drag handle or hold to reorder',
                    style: TextStyle(
                      fontSize: 10,
                      color: _searchQuery.isNotEmpty
                          ? AppColors.gold
                          : AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        ),

        // 3. REORDERABLE UPCOMING LIST OR FILTERED SEARCH RESULTS
        if (upcomingList.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Text(
                  _searchQuery.isNotEmpty
                      ? 'No songs matching "$_searchQuery"'
                      : 'No upcoming songs. Add songs using "Play Next".',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ),
            ),
          )
        else if (_searchQuery.isNotEmpty)
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final song = upcomingList[index];
                final absoluteIndex = fullQueue.indexOf(song);

                return Material(
                  key: ValueKey('search_queue_item_${song.id}_$absoluteIndex'),
                  color: Colors.transparent,
                  child: _buildQueueTile(
                    context,
                    song: song,
                    absoluteIndex: absoluteIndex >= 0 ? absoluteIndex : currIdx + 1 + index,
                    isUpcoming: true,
                    reorderIndex: null,
                  ),
                );
              },
              childCount: upcomingList.length,
            ),
          )
        else
          SliverReorderableList(
            itemCount: upcomingList.length,
            proxyDecorator: (Widget child, int index, Animation<double> animation) {
              return AnimatedBuilder(
                animation: animation,
                builder: (BuildContext context, Widget? animChild) {
                  final double animValue = Curves.easeInOut.transform(animation.value);
                  final double elevation = lerpDouble(0, 10, animValue) ?? 8.0;
                  return Material(
                    elevation: elevation,
                    color: const Color(0xFF262938),
                    shadowColor: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(14),
                    child: animChild,
                  );
                },
                child: child,
              );
            },
            onReorderStart: (_) {
              HapticFeedback.selectionClick();
            },
            // ignore: deprecated_member_use
            onReorder: (oldIdx, newIdx) {
              HapticFeedback.mediumImpact();
              // Map local upcoming indices back to absolute indices in the full queue
              final absoluteOld = currIdx + 1 + oldIdx;
              final absoluteNew = currIdx + 1 + newIdx;
              playerController.reorderQueue(absoluteOld, absoluteNew);
            },
            itemBuilder: (context, index) {
              final song = upcomingList[index];
              final absoluteIndex = currIdx + 1 + index;

              return Material(
                key: ValueKey('queue_item_${song.id}_$absoluteIndex'),
                color: Colors.transparent,
                child: Dismissible(
                  key: ValueKey('dismiss_queue_${song.id}_$absoluteIndex'),
                  direction: DismissDirection.horizontal,
                  background: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    color: const Color(0xFF8B0000),
                    child: const Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
                        SizedBox(width: 8),
                        Text('Remove', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  secondaryBackground: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    color: const Color(0xFF8B0000),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('Remove', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        SizedBox(width: 8),
                        Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
                      ],
                    ),
                  ),
                  onDismissed: (_) {
                    final removedSong = playerController.removeFromQueue(absoluteIndex);
                    HapticFeedback.mediumImpact();

                    if (removedSong != null) {
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF1E202B),
                          duration: const Duration(seconds: 4),
                          content: Text(
                            'Removed "${removedSong.title}"',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                          action: SnackBarAction(
                            label: 'UNDO',
                            textColor: AppColors.gold,
                            onPressed: () {
                              playerController.undoRemove(absoluteIndex, removedSong);
                            },
                          ),
                        ),
                      );
                    }
                  },
                  child: ReorderableDelayedDragStartListener(
                    index: index,
                    child: _buildQueueTile(
                      context,
                      song: song,
                      absoluteIndex: absoluteIndex,
                      isUpcoming: true,
                      reorderIndex: index,
                    ),
                  ),
                ),
              );
            },
          ),

        const SliverToBoxAdapter(
          child: SizedBox(height: 30),
        ),
      ],
    );
  }

  // ==========================================
  // NOW PLAYING HERO SECTION
  // ==========================================

  Widget _buildNowPlayingSection(SongModel song) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E202B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'NOW PLAYING',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                  color: AppColors.gold,
                ),
              ),
              const Spacer(),
              // Animated Equalizer Visualizer Bars
              Obx(() => _buildAnimatedEqualizerBars(playerController.isPlaying.value)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Artwork
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: QueryArtworkWidget(
                    id: int.tryParse(song.id) ?? 0,
                    type: ArtworkType.AUDIO,
                    keepOldArtwork: true,
                    artworkFit: BoxFit.cover,
                    nullArtworkWidget: Container(
                      color: AppColors.surfaceHighlight,
                      child: const Icon(Icons.music_note_rounded, color: AppColors.gold, size: 26),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Title and artist
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${song.artist} • ${song.formattedDuration}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.gold,
                      ),
                    ),
                  ],
                ),
              ),

              // Favorite Heart
              Builder(
                builder: (context) {
                  final favCtrl = Get.isRegistered<FavoritesController>()
                      ? Get.find<FavoritesController>()
                      : null;
                  if (favCtrl != null) {
                    return Obx(() {
                      final isFav = favCtrl.isFavorite(song.id);
                      return IconButton(
                        icon: Icon(
                          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isFav ? AppColors.primary : AppColors.textMuted,
                          size: 22,
                        ),
                        onPressed: () => favCtrl.toggleFavorite(song),
                      );
                    });
                  }
                  return IconButton(
                    icon: Icon(
                      song.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: song.isFavorite ? AppColors.primary : AppColors.textMuted,
                      size: 22,
                    ),
                    onPressed: () => playerController.toggleFavorite(song),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // ANIMATED 3-BAR EQUALIZER WAVE
  // ==========================================

  Widget _buildAnimatedEqualizerBars(bool isPlaying) {
    return SizedBox(
      width: 18,
      height: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildBouncingBar(12, isPlaying, 0),
          _buildBouncingBar(16, isPlaying, 200),
          _buildBouncingBar(10, isPlaying, 400),
        ],
      ),
    );
  }

  Widget _buildBouncingBar(double maxHeight, bool isPlaying, int delayMs) {
    if (!isPlaying) {
      return Container(
        width: 3.5,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.gold,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }

    return _BouncingBar(maxHeight: maxHeight, delayMs: delayMs);
  }

  // ==========================================
  // INDIVIDUAL QUEUE ITEM TILE
  // ==========================================

  Widget _buildQueueTile(
    BuildContext context, {
    required SongModel song,
    required int absoluteIndex,
    bool isUpcoming = false,
    int? reorderIndex,
  }) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            playerController.audioHandler.skipToQueueItem(absoluteIndex);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                // Artwork
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: QueryArtworkWidget(
                      id: int.tryParse(song.id) ?? 0,
                      type: ArtworkType.AUDIO,
                      keepOldArtwork: true,
                      artworkFit: BoxFit.cover,
                      nullArtworkWidget: Container(
                        color: AppColors.surfaceHighlight,
                        child: const Icon(Icons.music_note_rounded, color: AppColors.textMuted, size: 20),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Title and artist
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${song.artist} • ${song.formattedDuration}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Item Actions Menu (Move Up, Move Down, Remove, etc.)
                IconButton(
                  icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted, size: 20),
                  onPressed: () => _showQueueItemContextMenu(context, song, absoluteIndex),
                ),

                // Drag Handle
                if (isUpcoming && reorderIndex != null)
                  ReorderableDragStartListener(
                    index: reorderIndex,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: const Icon(
                        Icons.drag_handle_rounded,
                        color: AppColors.textSecondary,
                        size: 22,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // HISTORY LIST
  // ==========================================

  Widget _buildHistoryList() {
    final history = playerController.playbackHistory;

    if (history.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history_rounded, size: 48, color: AppColors.textMuted),
              SizedBox(height: 12),
              Text(
                'No playback history yet',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 4),
              Text(
                'Tracks you play during this session will appear here.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: history.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        // Reverse so most recently played is at top
        final song = history[history.length - 1 - index];
        return Material(
          color: Colors.transparent,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 44,
                height: 44,
                child: QueryArtworkWidget(
                  id: int.tryParse(song.id) ?? 0,
                  type: ArtworkType.AUDIO,
                  keepOldArtwork: true,
                  artworkFit: BoxFit.cover,
                  nullArtworkWidget: Container(
                    color: AppColors.surfaceHighlight,
                    child: const Icon(Icons.music_note_rounded, color: AppColors.textMuted, size: 20),
                  ),
                ),
              ),
            ),
            title: Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
            ),
            subtitle: Text(
              '${song.artist} • ${DurationFormatter.format(song.durationMs)}',
              maxLines: 1,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.play_circle_outline_rounded, color: AppColors.gold, size: 24),
              tooltip: 'Replay Track',
              onPressed: () {
                playerController.playSong(song, [song, ...playerController.queue]);
                Navigator.pop(context);
              },
            ),
            onTap: () {
              playerController.playSong(song, [song, ...playerController.queue]);
              Navigator.pop(context);
            },
          ),
        );
      },
    );
  }

  // ==========================================
  // CONTEXT MENU FOR QUEUE ITEM
  // ==========================================

  void _showQueueItemContextMenu(BuildContext context, SongModel song, int absoluteIndex) {
    final fullQueue = playerController.queue;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Material(
        color: Colors.transparent,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF161822),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            song.artist,
                            maxLines: 1,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.border, height: 1),

              // Play Now
              ListTile(
                leading: const Icon(Icons.play_arrow_rounded, color: AppColors.gold),
                title: const Text('Play Now', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  playerController.audioHandler.skipToQueueItem(absoluteIndex);
                },
              ),

              // Play Next
              ListTile(
                leading: const Icon(Icons.play_circle_outline_rounded, color: AppColors.primary),
                title: const Text('Play Next', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  playerController.playNext(song);
                  Get.snackbar('Play Next', '${song.title} will play next.');
                },
              ),

              // Add to Queue
              ListTile(
                leading: const Icon(Icons.queue_music_rounded, color: AppColors.secondary),
                title: const Text('Add to Queue', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  playerController.addToQueue(song);
                  Get.snackbar('Added to Queue', '${song.title} added to the end of queue.');
                },
              ),

              // Move Up (Accessible reorder alternative)
              if (absoluteIndex > 0)
                ListTile(
                  leading: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
                  title: const Text('Move Up', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    playerController.moveQueueItem(absoluteIndex, true);
                  },
                ),

              // Move Down (Accessible reorder alternative)
              if (absoluteIndex < fullQueue.length - 1)
                ListTile(
                  leading: const Icon(Icons.arrow_downward_rounded, color: Colors.white),
                  title: const Text('Move Down', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    playerController.moveQueueItem(absoluteIndex, false);
                  },
                ),

              // Add to Playlist
              ListTile(
                leading: const Icon(Icons.playlist_add_rounded, color: AppColors.gold),
                title: const Text('Add to Playlist', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddToPlaylistSheet(context, song);
                },
              ),

              // Favorite Toggle in Queue Context Menu
              Builder(
                builder: (context) {
                  final favCtrl = Get.isRegistered<FavoritesController>()
                      ? Get.find<FavoritesController>()
                      : null;
                  if (favCtrl != null) {
                    return Obx(() {
                      final isFav = favCtrl.isFavorite(song.id);
                      return ListTile(
                        leading: Icon(
                          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isFav ? AppColors.primary : AppColors.textPrimary,
                        ),
                        title: Text(
                          isFav ? 'Remove from Favorites' : 'Add to Favorites',
                          style: const TextStyle(color: Colors.white),
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          favCtrl.toggleFavorite(song);
                        },
                      );
                    });
                  }
                  return ListTile(
                    leading: Icon(
                      song.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: song.isFavorite ? AppColors.primary : AppColors.textPrimary,
                    ),
                    title: Text(
                      song.isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      playerController.toggleFavorite(song);
                    },
                  );
                },
              ),

              // Remove from Queue with Undo
              ListTile(
                leading: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.red),
                title: const Text('Remove from Queue', style: TextStyle(color: AppColors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  final removed = playerController.removeFromQueue(absoluteIndex);
                  if (removed != null) {
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF1E202B),
                        duration: const Duration(seconds: 4),
                        content: Text(
                          'Removed "${removed.title}"',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        action: SnackBarAction(
                          label: 'UNDO',
                          textColor: AppColors.gold,
                          onPressed: () {
                            playerController.undoRemove(absoluteIndex, removed);
                          },
                        ),
                      ),
                    );
                  }
                },
              ),

              // Audio Quality Sheet
              ListTile(
                leading: const Icon(Icons.info_outline_rounded, color: AppColors.textMuted),
                title: const Text('Song Information', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  AudioQualitySheet.show(context, song);
                },
              ),

              // Song Radio / Similar Songs
              ListTile(
                leading: const Icon(Icons.radio_rounded, color: AppColors.gold),
                title: const Text('Song Radio / Similar Songs', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  SimilarSongsSheet.show(context, song);
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  void _showAddToPlaylistSheet(BuildContext context, SongModel song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Add to Playlist', style: AppTypography.headlineSmall),
            ),
            if (playlistController.playlists.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'No playlists created yet. Create one in Library!',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            else
              ...playlistController.playlists.map(
                (pl) => ListTile(
                  leading: const Icon(Icons.queue_music_rounded, color: AppColors.secondary),
                  title: Text(pl.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: Text('${pl.songCount} tracks', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  onTap: () {
                    playlistController.addSongToPlaylist(pl.id, song);
                    Navigator.pop(context);
                    Get.snackbar('Added to Playlist', 'Added "${song.title}" to ${pl.name}.');
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // CONFIRM CLEAR QUEUE DIALOG
  // ==========================================

  void _confirmClearQueue(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E202B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Clear Upcoming Queue?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: const Text(
          'This will remove all upcoming tracks from the queue. The currently playing track will continue playing.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              final cleared = playerController.clearUpcomingQueue();
              if (cleared.isNotEmpty) {
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF1E202B),
                    duration: const Duration(seconds: 4),
                    content: Text(
                      'Cleared ${cleared.length} upcoming tracks',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    action: SnackBarAction(
                      label: 'UNDO',
                      textColor: AppColors.gold,
                      onPressed: () {
                        playerController.restoreClearedUpcomingQueue();
                      },
                    ),
                  ),
                );
              }
            },
            child: const Text('Clear', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SAVE QUEUE AS PLAYLIST DIALOG
  // ==========================================

  void _showSaveQueueDialog(BuildContext context) {
    final textController = TextEditingController(
      text: 'Queue ${DateTime.now().month}/${DateTime.now().day}',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E202B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Save Queue as Playlist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter playlist name:',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: textController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Enter playlist name...',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.gold)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.gold, width: 2)),
                ),
              ),
              if (playlistController.playlists.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(color: AppColors.border, height: 1),
                const SizedBox(height: 8),
                const Text(
                  'Or append to existing playlist:',
                  style: TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: SingleChildScrollView(
                    child: Column(
                      children: playlistController.playlists.map((pl) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.playlist_add_rounded, color: AppColors.secondary, size: 20),
                        title: Text(pl.name, style: const TextStyle(color: Colors.white, fontSize: 13)),
                        subtitle: Text('${pl.songCount} tracks', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                        onTap: () async {
                          Navigator.pop(ctx);
                          final success = await playerController.appendQueueToPlaylist(pl.id);
                          if (success) {
                            playlistController.loadPlaylists();
                            Get.snackbar(
                              'Playlist Updated',
                              'Queue tracks appended to "${pl.name}".',
                              backgroundColor: AppColors.surfaceElevated,
                              colorText: Colors.white,
                            );
                          }
                        },
                      )).toList(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              final name = textController.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(ctx);
                final success = await playerController.saveQueueAsPlaylist(name);
                if (success) {
                  playlistController.loadPlaylists();
                  Get.snackbar(
                    'Playlist Saved',
                    'Queue saved as "$name" successfully.',
                    backgroundColor: AppColors.surfaceElevated,
                    colorText: Colors.white,
                  );
                }
              }
            },
            child: const Text('Save', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// BOUNCING EQUALIZER BAR COMPONENT
// ==========================================

class _BouncingBar extends StatefulWidget {
  final double maxHeight;
  final int delayMs;

  const _BouncingBar({required this.maxHeight, required this.delayMs});

  @override
  State<_BouncingBar> createState() => _BouncingBarState();
}

class _BouncingBarState extends State<_BouncingBar> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400 + widget.delayMs ~/ 2),
    );

    _animation = Tween<double>(begin: 3.0, end: widget.maxHeight).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) {
        _animController.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Container(
          width: 3.5,
          height: _animation.value,
          decoration: BoxDecoration(
            color: AppColors.gold,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      },
    );
  }
}
