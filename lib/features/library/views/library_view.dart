import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/localization/soniq_localizations.dart';
import '../../../core/models/song_model.dart';
import '../../../core/widgets/track_tile.dart';
import '../../../core/widgets/soniq_pill_tab.dart';
import '../../../core/widgets/soniq_empty_state.dart';
import '../../../core/widgets/alphabet_fast_scroller.dart';
import '../../../core/widgets/soniq_floating_playback_bar.dart';
import '../../player/controllers/player_controller.dart';
import '../controllers/library_controller.dart';
import 'widgets/track_options_bottom_sheet.dart';
import 'widgets/folder_browse_view.dart';
import 'widgets/library_sort_bottom_sheet.dart';

class LibraryView extends StatefulWidget {
  const LibraryView({super.key});

  @override
  State<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<LibraryView> {
  bool _isSearchExpanded = false;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final libraryController = Get.find<LibraryController>();
    final playerController = Get.find<AudioPlayerController>();
    final strings = SoniqLocalizations.of(context);
    final useFlexibleRows = MediaQuery.textScalerOf(context).scale(14) > 18;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Header (Title "Local" + Search & Sort Icons) (Matches Reference Image 2)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 12, 4),
              child: Row(
                children: [
                  Text(
                    strings.text('local'),
                    style: AppTypography.displayLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      _isSearchExpanded
                          ? Icons.close_rounded
                          : Icons.search_rounded,
                      color: AppColors.textPrimary,
                      size: 24,
                    ),
                    tooltip: _isSearchExpanded
                        ? MaterialLocalizations.of(context).closeButtonTooltip
                        : strings.text('searchHint'),
                    onPressed: () {
                      setState(() {
                        _isSearchExpanded = !_isSearchExpanded;
                        if (!_isSearchExpanded) {
                          _searchController.clear();
                          libraryController.updateSearch('');
                        }
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.sort_rounded,
                      color: AppColors.textPrimary,
                      size: 24,
                    ),
                    tooltip: strings.text('sortSongs'),
                    onPressed: () =>
                        LibrarySortBottomSheet.show(context, libraryController),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.sync_rounded,
                      color: AppColors.textPrimary,
                      size: 24,
                    ),
                    tooltip: strings.text('rescanLibrary'),
                    onPressed: () => libraryController.scanLibrary(),
                  ),
                ],
              ),
            ),

            // Search Bar Input (Expanded)
            if (_isSearchExpanded)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  textAlign: Directionality.of(context) == TextDirection.rtl
                      ? TextAlign.right
                      : TextAlign.left,
                  textDirection: Directionality.of(context),
                  onChanged: (val) => libraryController.updateSearch(val),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: strings.text('searchHint'),
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.secondary),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 8),

            // 2. Pill Tabs: Songs, Artists, Albums, Folders (Matches Reference Image 2)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Obx(
                () => SoniqPillTab<LibraryFilterTab>(
                  items: LibraryFilterTab.values,
                  selectedItem: libraryController.activeTab.value,
                  onSelect: (tab) => libraryController.setFilterTab(tab),
                  labelBuilder: (tab) {
                    switch (tab) {
                      case LibraryFilterTab.songs:
                        return '${strings.text('songs')} (${libraryController.allSongs.length})';
                      case LibraryFilterTab.artists:
                        return strings.text('artists');
                      case LibraryFilterTab.albums:
                        return strings.text('albums');
                      case LibraryFilterTab.folders:
                        return strings.text('folders');
                    }
                  },
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Scanning indicator
            Obx(() {
              if (libraryController.isScanning.value) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${strings.text('scanningTracks')} (${libraryController.scanCurrent}/${libraryController.scanTotal})',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            }),

            // 3. Tab Content
            Expanded(
              child: Stack(
                children: [
                  Obx(() {
                    final tab = libraryController.activeTab.value;
                    final songs = libraryController.filteredSongs;

                    if (songs.isEmpty && !libraryController.isScanning.value) {
                      return SoniqEmptyState(
                        title: strings.text('noMusicFound'),
                        description: strings.text('noAudioFiles'),
                        buttonText: strings.text('scanStorage'),
                        onButtonPressed: () => libraryController.scanLibrary(),
                      );
                    }

                    switch (tab) {
                      case LibraryFilterTab.songs:
                        return AlphabetFastScroller(
                          scrollController: _scrollController,
                          songs: songs,
                          itemExtent: 68.0,
                          enabled: !useFlexibleRows,
                          isArtistSort:
                              libraryController.sortOption.value ==
                                  SongSortOption.artistAsc ||
                              libraryController.sortOption.value ==
                                  SongSortOption.artistDesc,
                          child: RefreshIndicator(
                            color: AppColors.primary,
                            backgroundColor: AppColors.surfaceElevated,
                            onRefresh: () => libraryController.scanLibrary(),
                            child: ListView.builder(
                              controller: _scrollController,
                              itemCount: songs.length,
                              itemExtent: useFlexibleRows ? null : 68.0,
                              padding: EdgeInsets.only(
                                bottom:
                                    playerController.currentSong.value != null
                                    ? 165.0
                                    : 100.0,
                              ),
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              itemBuilder: (context, index) {
                                final song = songs[index];
                                final isCurrent =
                                    playerController.currentSong.value?.id ==
                                    song.id;

                                return TrackTile(
                                  song: song,
                                  isPlaying: isCurrent,
                                  onTap: () {
                                    playerController.playSong(song, songs);
                                  },
                                  onFavoriteTap: () {
                                    libraryController.toggleFavorite(song);
                                  },
                                  onMoreTap: () =>
                                      _openTrackOptions(context, song),
                                );
                              },
                            ),
                          ),
                        );

                      case LibraryFilterTab.artists:
                        return _buildArtistsView(
                          libraryController,
                          playerController,
                        );

                      case LibraryFilterTab.albums:
                        return _buildAlbumsView(
                          libraryController,
                          playerController,
                        );

                      case LibraryFilterTab.folders:
                        return FolderBrowseView(
                          foldersMap: libraryController.foldersMap,
                        );
                    }
                  }),

                  // Floating Play All & Shuffle All action bar (visible on Songs tab)
                  Obx(
                    () => SoniqFloatingPlaybackBar(
                      songs: libraryController.filteredSongs,
                      collectionTitle: 'All Songs',
                      isVisible:
                          libraryController.activeTab.value ==
                          LibraryFilterTab.songs,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtistsView(
    LibraryController libraryCtrl,
    AudioPlayerController playerCtrl,
  ) {
    final artists = libraryCtrl.artistsMap.entries.toList();
    if (artists.isEmpty) {
      return const Center(child: Text('No artists found'));
    }

    return ListView.builder(
      itemCount: artists.length,
      padding: const EdgeInsets.only(bottom: 80),
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final entry = artists[index];
        final artistName = entry.key;
        final songs = entry.value;

        return ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: AppColors.secondary,
              size: 24,
            ),
          ),
          title: Text(
            artistName,
            style: AppTypography.headlineSmall.copyWith(fontSize: 15),
          ),
          subtitle: Text(
            '${songs.length} songs',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          trailing: IconButton(
            icon: const Icon(
              Icons.play_circle_fill_rounded,
              color: AppColors.primary,
              size: 28,
            ),
            onPressed: () => playerCtrl.playSong(songs.first, songs),
          ),
          onTap: () => _openGroupList(context, artistName, songs, playerCtrl),
        );
      },
    );
  }

  Widget _buildAlbumsView(
    LibraryController libraryCtrl,
    AudioPlayerController playerCtrl,
  ) {
    final albums = libraryCtrl.albumsMap.entries.toList();
    if (albums.isEmpty) {
      return const Center(child: Text('No albums found'));
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: albums.length,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final entry = albums[index];
        final albumName = entry.key;
        final songs = entry.value;

        return GestureDetector(
          onTap: () => _openGroupList(context, albumName, songs, playerCtrl),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 0.8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF231E34), Color(0xFF141320)],
                      ),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.album_rounded,
                        size: 48,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        albumName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${songs.length} tracks',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openGroupList(
    BuildContext context,
    String title,
    List<SongModel> songs,
    AudioPlayerController playerCtrl,
  ) {
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
                  Expanded(
                    child: Text(
                      title,
                      style: AppTypography.headlineMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.play_circle_fill_rounded,
                      color: AppColors.primary,
                      size: 32,
                    ),
                    onPressed: () {
                      playerCtrl.playSong(songs.first, songs);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: songs.length,
                itemBuilder: (ctx, idx) => TrackTile(
                  song: songs[idx],
                  onTap: () {
                    playerCtrl.playSong(songs[idx], songs);
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

  void _openTrackOptions(BuildContext context, SongModel song) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TrackOptionsBottomSheet(song: song),
    );
  }
}
