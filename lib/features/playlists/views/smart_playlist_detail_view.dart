import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/models/smart_playlist_model.dart';
import '../../../core/models/song_model.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../home/controllers/home_controller.dart';
import '../../library/controllers/library_controller.dart';
import '../../player/controllers/player_controller.dart';
import '../controllers/smart_playlist_controller.dart';
import 'smart_playlist_generator_dialog.dart';

class SmartPlaylistDetailView extends StatelessWidget {
  final SmartPlaylistModel playlist;

  const SmartPlaylistDetailView({super.key, required this.playlist});

  List<SongModel> _getLibrary() {
    if (Get.isRegistered<LibraryController>()) {
      final lib = Get.find<LibraryController>();
      if (lib.allSongs.isNotEmpty) return lib.allSongs.toList();
    }
    if (Get.isRegistered<SmartPlaylistController>()) {
      final cached = Get.find<SmartPlaylistController>().cacheService.getCachedSongs();
      if (cached.isNotEmpty) return cached;
    }
    if (Get.isRegistered<HomeController>()) {
      final home = Get.find<HomeController>();
      if (home.recentlyAdded.isNotEmpty) return home.recentlyAdded.toList();
    }
    return [];
  }

  IconData _resolveCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'love & romance': return Icons.favorite_rounded;
      case 'fast beat': return Icons.bolt_rounded;
      case 'sad & emotional': return Icons.water_drop_rounded;
      case 'chill & relax': return Icons.spa_rounded;
      case 'workout': return Icons.fitness_center_rounded;
      case 'party': return Icons.celebration_rounded;
      case 'road trip': return Icons.directions_car_rounded;
      case 'devotional': return Icons.self_improvement_rounded;
      case 'tamil melody':
      case 'melody': return Icons.music_note_rounded;
      case 'sleep': return Icons.bedtime_rounded;
      default: return Icons.auto_awesome_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final smartCtrl = Get.find<SmartPlaylistController>();
    final playerCtrl = Get.find<AudioPlayerController>();

    final themeColor = Color(playlist.colorHex);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Obx(() {
        // Re-evaluate reactively whenever library or smart playlist changes
        final currentPl = smartCtrl.smartPlaylists.firstWhereOrNull((p) => p.id == playlist.id) ?? playlist;
        final library = _getLibrary();
        final matchedSongs = smartCtrl.evaluatePlaylist(currentPl, library);

        final totalMs = matchedSongs.fold<int>(0, (sum, s) => sum + s.durationMs);
        final totalDuration = DurationFormatter.format(totalMs);

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 1. Dynamic Hero App Bar
            SliverAppBar(
              expandedHeight: 250,
              pinned: true,
              backgroundColor: const Color(0xFF14121E),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Get.back(),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  tooltip: 'Regenerate Matches',
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    smartCtrl.smartPlaylists.refresh();
                    Get.snackbar(
                      'Matches Refreshed',
                      'Evaluated ${matchedSongs.length} dynamic matching tracks.',
                      backgroundColor: const Color(0xFF1F1C2E),
                      colorText: Colors.white,
                    );
                  },
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                  color: const Color(0xFF1E1A2B),
                  onSelected: (val) {
                    if (val == 'edit') {
                      SmartPlaylistGeneratorDialog.show(context, existingPlaylist: currentPl);
                    } else if (val == 'snapshot') {
                      _showSaveAsManualDialog(context, smartCtrl, currentPl, library);
                    } else if (val == 'delete') {
                      _confirmDelete(context, smartCtrl, currentPl);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.tune_rounded, color: AppColors.gold, size: 20),
                          SizedBox(width: 10),
                          Text('Edit Matching Rules', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'snapshot',
                      child: Row(
                        children: [
                          Icon(Icons.copy_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 10),
                          Text('Save as Manual Playlist', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, color: AppColors.red, size: 20),
                          SizedBox(width: 10),
                          Text('Delete Smart Playlist', style: TextStyle(color: AppColors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [themeColor.withValues(alpha: 0.5), const Color(0xFF0D0B14)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 70, 24, 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: themeColor.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: themeColor, width: 1.0),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_resolveCategoryIcon(currentPl.category),
                                      size: 13, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text(
                                    currentPl.category.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black38,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'DYNAMIC AI SMART PLAYLIST',
                                style: TextStyle(color: AppColors.gold, fontSize: 9, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currentPl.name,
                          style: AppTypography.displayMedium.copyWith(fontSize: 24, fontWeight: FontWeight.w900),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentPl.description.isNotEmpty
                              ? currentPl.description
                              : 'Automatically synchronized offline mix',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${matchedSongs.length} tracks • $totalDuration',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 2. Play All / Shuffle All Action Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 24),
                        label: const Text('Play All', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        onPressed: matchedSongs.isEmpty
                            ? null
                            : () {
                                HapticFeedback.mediumImpact();
                                playerCtrl.playSong(matchedSongs.first, matchedSongs);
                              },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: AppColors.border, width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.shuffle_rounded, size: 20, color: AppColors.gold),
                        label: const Text('Shuffle', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        onPressed: matchedSongs.isEmpty
                            ? null
                            : () {
                                HapticFeedback.mediumImpact();
                                final shuffled = List<SongModel>.from(matchedSongs)..shuffle();
                                playerCtrl.playSong(shuffled.first, shuffled);
                              },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. Excluded songs status banner (if any)
            if (currentPl.excludedSongIds.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1416),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${currentPl.excludedSongIds.length} tracks manually excluded',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                        InkWell(
                          onTap: () async {
                            currentPl.excludedSongIds.clear();
                            await smartCtrl.saveSmartPlaylist(currentPl);
                            Get.snackbar('Excluded Reset', 'All excluded songs restored to rules.');
                          },
                          child: const Text('RESET', style: TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 4. Songs List
            if (matchedSongs.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: Text(
                      'No songs in your library match these rules.\nTap the top menu to Edit Rules.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final song = matchedSongs[index];
                    final isPinned = currentPl.pinnedSongIds.contains(song.id);

                    return Material(
                      color: Colors.transparent,
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isPinned ? AppColors.gold.withValues(alpha: 0.2) : const Color(0xFF1E1A2B),
                            borderRadius: BorderRadius.circular(8),
                            border: isPinned ? Border.all(color: AppColors.gold, width: 1.0) : null,
                          ),
                          child: Center(
                            child: isPinned
                                ? const Icon(Icons.push_pin_rounded, color: AppColors.gold, size: 18)
                                : Text('${index + 1}',
                                    style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 12)),
                          ),
                        ),
                        title: Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: Text(
                          '${song.artist} • ${song.formattedDuration}',
                          maxLines: 1,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted, size: 18),
                          onPressed: () => _showSongActionSheet(context, smartCtrl, currentPl, song, isPinned),
                        ),
                        onTap: () {
                          playerCtrl.playSong(song, matchedSongs);
                        },
                      ),
                    );
                  },
                  childCount: matchedSongs.length,
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 50)),
          ],
        );
      }),
    );
  }

  void _showSongActionSheet(
    BuildContext context,
    SmartPlaylistController smartCtrl,
    SmartPlaylistModel pl,
    SongModel song,
    bool isPinned,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Material(
        color: Colors.transparent,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1626),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                            Text(song.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                            Text(song.artist, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: AppColors.border, height: 1),

                // Pin / Unpin
                ListTile(
                  leading: Icon(isPinned ? Icons.pin_drop_outlined : Icons.push_pin_rounded, color: AppColors.gold),
                  title: Text(isPinned ? 'Unpin from Top' : 'Pin to Top of Smart Playlist', style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (isPinned) {
                      smartCtrl.unpinSong(pl.id, song.id);
                    } else {
                      smartCtrl.pinSong(pl.id, song.id);
                    }
                  },
                ),

                // Exclude Song
                ListTile(
                  leading: const Icon(Icons.do_not_disturb_on_rounded, color: AppColors.red),
                  title: const Text('Exclude Song from this Smart Playlist', style: TextStyle(color: AppColors.red)),
                  subtitle: const Text('Will not appear even when playlist regenerates', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  onTap: () {
                    Navigator.pop(ctx);
                    smartCtrl.excludeSong(pl.id, song.id);
                    Get.snackbar('Excluded', '"${song.title}" excluded from "${pl.name}".');
                  },
                ),

                // Correct Mood / Tag
                ListTile(
                  leading: const Icon(Icons.label_outline_rounded, color: AppColors.primary),
                  title: const Text('Manually Correct Mood / Category', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showMoodCorrectionDialog(context, smartCtrl, song);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMoodCorrectionDialog(
    BuildContext context,
    SmartPlaylistController smartCtrl,
    SongModel song,
  ) {
    String selected = plCategoryForSong(smartCtrl, song.id);
    final customTagCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1A2B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Correct Mood: ${song.title}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select genuine mood for this track:', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    'Love & Romance',
                    'Fast Beat',
                    'Sad & Emotional',
                    'Chill & Relax',
                    'Workout',
                    'Tamil Melody',
                    'Tamil Kuthu',
                    'Road Trip',
                    'Focus',
                    'Devotional',
                  ].map((m) {
                    final isSel = selected == m;
                    return ChoiceChip(
                      label: Text(m, style: TextStyle(color: isSel ? Colors.black : Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                      selected: isSel,
                      selectedColor: AppColors.gold,
                      backgroundColor: const Color(0xFF2A2438),
                      onSelected: (val) {
                        setDialogState(() => selected = m);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: customTagCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Add custom tag (e.g. 90s, acoustic)...',
                    hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.gold)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
              onPressed: () async {
                final tag = customTagCtrl.text.trim();
                final tags = tag.isNotEmpty ? [tag] : <String>[];
                Navigator.pop(ctx);
                await smartCtrl.correctSongMood(
                  songId: song.id,
                  newMood: selected,
                  userTags: tags,
                );
                Get.snackbar('Classification Updated', '"${song.title}" marked as "$selected".');
              },
              child: const Text('Save Tag', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  String plCategoryForSong(SmartPlaylistController ctrl, String songId) {
    final c = ctrl.classifications[songId];
    return c?.primaryMood ?? 'Love & Romance';
  }

  void _showSaveAsManualDialog(
    BuildContext context,
    SmartPlaylistController smartCtrl,
    SmartPlaylistModel pl,
    List<SongModel> library,
  ) {
    final textCtrl = TextEditingController(text: '${pl.name} Snapshot');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1A2B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Convert to Manual Playlist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This creates an editable, static copy of currently matching songs. It will not dynamically change with rules.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textCtrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Playlist name...',
                hintStyle: TextStyle(color: AppColors.textMuted),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.gold)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.gold, width: 2)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
            onPressed: () async {
              final name = textCtrl.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(ctx);
                final success = await smartCtrl.convertToManualPlaylist(
                  smartPl: pl,
                  manualName: name,
                  library: library,
                );
                if (success) {
                  Get.snackbar('Manual Playlist Saved', 'Created static playlist "$name".');
                }
              }
            },
            child: const Text('Convert & Save', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    SmartPlaylistController smartCtrl,
    SmartPlaylistModel pl,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1A2B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Delete "${pl.name}"?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: const Text(
          'This will delete the Smart Playlist definition. Your actual offline music files will never be touched or deleted.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await smartCtrl.deleteSmartPlaylist(pl.id);
              Get.back(); // Pop detail view
              Get.snackbar('Smart Playlist Deleted', '"${pl.name}" removed.');
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
