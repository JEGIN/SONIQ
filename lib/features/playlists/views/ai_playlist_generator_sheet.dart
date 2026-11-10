import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/models/song_model.dart';
import '../../../core/services/ai_playlist_service.dart';
import '../../../core/database/song_cache_service.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../library/controllers/library_controller.dart';
import '../../player/controllers/player_controller.dart';
import '../controllers/favorites_controller.dart';
import '../controllers/playlist_controller.dart';

class AiPlaylistGeneratorSheet extends StatefulWidget {
  const AiPlaylistGeneratorSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AiPlaylistGeneratorSheet(),
    );
  }

  @override
  State<AiPlaylistGeneratorSheet> createState() => _AiPlaylistGeneratorSheetState();
}

class _AiPlaylistGeneratorSheetState extends State<AiPlaylistGeneratorSheet> {
  final aiService = AiPlaylistService();
  final cacheService = SongCacheService();
  final playerCtrl = Get.find<AudioPlayerController>();
  final playlistCtrl = Get.find<PlaylistController>();
  final favCtrl = Get.isRegistered<FavoritesController>() ? Get.find<FavoritesController>() : null;

  AiPlaylistVibe? _selectedVibe = AiPlaylistVibe.workout;
  final TextEditingController _promptController = TextEditingController();
  List<SongModel> _generatedSongs = [];
  String _generatedTitle = '⚡ High Energy Workout';

  List<SongModel> _getLibrarySongs() {
    if (Get.isRegistered<LibraryController>()) {
      final libCtrl = Get.find<LibraryController>();
      if (libCtrl.allSongs.isNotEmpty) return libCtrl.allSongs.toList();
    }
    return cacheService.getCachedSongs();
  }

  @override
  void initState() {
    super.initState();
    _generatePlaylistForVibe(AiPlaylistVibe.workout, '⚡ High Energy Workout');
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  void _generatePlaylistForVibe(AiPlaylistVibe vibe, String title) {
    final favIds = favCtrl?.favoriteIds ?? <String>{};
    final library = _getLibrarySongs();
    final songs = aiService.generateByVibe(
      library,
      vibe,
      favoriteIds: favIds,
    );

    setState(() {
      _selectedVibe = vibe;
      _generatedTitle = title;
      _generatedSongs = songs;
    });
  }

  void _generateFromCustomPrompt(String text) {
    if (text.trim().isEmpty) return;
    final favIds = favCtrl?.favoriteIds ?? <String>{};
    final library = _getLibrarySongs();
    final songs = aiService.generateByPrompt(
      library,
      text,
      favoriteIds: favIds,
    );

    setState(() {
      _selectedVibe = null;
      _generatedTitle = '✨ AI Mix: ${text.trim()}';
      _generatedSongs = songs;
    });
  }

  int get _totalDurationMs =>
      _generatedSongs.fold(0, (sum, song) => sum + song.durationMs);

  String get _formattedTotalDuration {
    final totalSec = _totalDurationMs ~/ 1000;
    final hours = totalSec ~/ 3600;
    final mins = (totalSec % 3600) ~/ 60;
    if (hours > 0) {
      return '$hours' 'h $mins' 'm';
    }
    return '$mins min';
  }

  @override
  Widget build(BuildContext context) {
    final sheetHeight = MediaQuery.of(context).size.height * 0.90;

    return Material(
      color: Colors.transparent,
      child: Container(
        height: sheetHeight,
        decoration: const BoxDecoration(
          color: Color(0xFF110E1B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 12, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AI Smart Playlist Studio', style: AppTypography.headlineMedium),
                        SizedBox(height: 2),
                        Text(
                          'Generate instant offline mixes from your 500+ songs',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(color: AppColors.border, height: 1),

            // Prompt & Vibe Selection Area
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Natural Language Search Bar
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1929),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.5), width: 1.0),
                    ),
                    child: TextField(
                      controller: _promptController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      textInputAction: TextInputAction.search,
                      onSubmitted: _generateFromCustomPrompt,
                      decoration: InputDecoration(
                        hintText: 'Ask AI: "Fast driving songs", "Romantic acoustic"...',
                        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        prefixIcon: const Icon(Icons.psychology_rounded, color: Color(0xFFD946EF), size: 18),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.arrow_forward_rounded, color: AppColors.gold, size: 18),
                          onPressed: () => _generateFromCustomPrompt(_promptController.text),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Quick Vibe Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildVibeChip('⚡ Workout', AiPlaylistVibe.workout, '⚡ High Energy Workout'),
                        const SizedBox(width: 8),
                        _buildVibeChip('🌙 Late Night Chill', AiPlaylistVibe.chill, '🌙 Late Night Chill Mix'),
                        const SizedBox(width: 8),
                        _buildVibeChip('🚗 Road Trip', AiPlaylistVibe.roadTrip, '🚗 Road Trip Anthems'),
                        const SizedBox(width: 8),
                        _buildVibeChip('☕ Focus', AiPlaylistVibe.focus, '☕ Deep Focus & Flow'),
                        const SizedBox(width: 8),
                        _buildVibeChip('🏆 Heavy Rotation', AiPlaylistVibe.heavyRotation, '🏆 Heavy Rotation Mix'),
                        const SizedBox(width: 8),
                        _buildVibeChip('💎 Hidden Gems', AiPlaylistVibe.forgottenGems, '💎 Forgotten Local Gems'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Summary Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _generatedTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    '${_generatedSongs.length} tracks • $_formattedTotalDuration',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

            const Divider(color: AppColors.border, height: 1),

            // Generated Songs Preview List
            Expanded(
              child: _generatedSongs.isEmpty
                  ? const Center(
                      child: Text(
                        'No matching songs found in library.\nTry another vibe or prompt.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: _generatedSongs.length,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemBuilder: (context, index) {
                        final song = _generatedSongs[index];
                        return Material(
                          color: Colors.transparent,
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                            leading: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1B4B),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            title: Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                            ),
                            trailing: Text(
                              DurationFormatter.format(song.durationMs),
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Bottom Action Controls
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: const BoxDecoration(
                color: Color(0xFF0D0A14),
                border: Border(top: BorderSide(color: AppColors.border, width: 0.8)),
              ),
              child: Row(
                children: [
                  // Save as Playlist Button
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.gold,
                        side: const BorderSide(color: AppColors.gold, width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.playlist_add_rounded, size: 20),
                      label: const Text('Save Playlist', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      onPressed: _generatedSongs.isEmpty ? null : _savePlaylist,
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Play Now Button
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 22),
                      label: const Text('Play Mix Now', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      onPressed: _generatedSongs.isEmpty
                          ? null
                          : () {
                              HapticFeedback.mediumImpact();
                              Navigator.pop(context);
                              playerCtrl.playSong(_generatedSongs.first, _generatedSongs);
                              Get.snackbar(
                                'AI Mix Playing',
                                'Now playing $_generatedTitle (${_generatedSongs.length} tracks)',
                                backgroundColor: const Color(0xFF1A1728),
                                colorText: Colors.white,
                              );
                            },
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

  Widget _buildVibeChip(String label, AiPlaylistVibe vibe, String playlistTitle) {
    final isSelected = _selectedVibe == vibe;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        HapticFeedback.selectionClick();
        _promptController.clear();
        _generatePlaylistForVibe(vibe, playlistTitle);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6B21A8) : const Color(0xFF1E192B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFD946EF) : AppColors.border,
            width: isSelected ? 1.4 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _savePlaylist() async {
    final title = _generatedTitle.replaceAll(RegExp(r'^[^\w]+'), '').trim();
    final nameController = TextEditingController(text: title);

    final confirmedName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1A2B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Save AI Playlist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter playlist name...',
            hintStyle: TextStyle(color: AppColors.textMuted),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.gold)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.gold, width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            child: const Text('Save', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirmedName != null && confirmedName.isNotEmpty) {
      await playlistCtrl.createPlaylist(confirmedName);
      final pl = playlistCtrl.playlists.firstWhereOrNull((p) => p.name == confirmedName);
      if (pl != null) {
        for (final song in _generatedSongs) {
          await playlistCtrl.addSongToPlaylist(pl.id, song);
        }
      }
      playlistCtrl.loadPlaylists();
      if (mounted) {
        Navigator.pop(context);
        Get.snackbar(
          'Playlist Saved',
          '"$confirmedName" created with ${_generatedSongs.length} songs.',
          backgroundColor: const Color(0xFF1E1A2B),
          colorText: Colors.white,
        );
      }
    }
  }
}
