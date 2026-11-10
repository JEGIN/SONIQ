import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/models/lyric_line_model.dart';
import '../../../core/models/song_model.dart';
import '../../../core/services/lyrics_service.dart';
import '../../player/controllers/player_controller.dart';

class LyricsSheet extends StatefulWidget {
  final SongModel song;

  const LyricsSheet({super.key, required this.song});

  static void show(BuildContext context, SongModel song) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LyricsSheet(song: song),
    );
  }

  @override
  State<LyricsSheet> createState() => _LyricsSheetState();
}

class _LyricsSheetState extends State<LyricsSheet> {
  final playerCtrl = Get.find<AudioPlayerController>();
  final lyricsService = LyricsService();

  List<LyricLine> _lyrics = [];
  bool _isLoading = true;
  int _activeLineIndex = -1;
  bool _isUserScrolling = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadLyrics();
  }

  Future<void> _loadLyrics() async {
    final lines = await lyricsService.getLyricsForSong(widget.song);
    if (mounted) {
      setState(() {
        _lyrics = lines;
        _isLoading = false;
      });
    }
  }

  void _scrollToActiveLine(int index) {
    if (_isUserScrolling || !_scrollController.hasClients || index < 0 || index >= _lyrics.length) return;

    // Approximate item height: 50.0
    const itemHeight = 52.0;
    final screenCenter = MediaQuery.of(context).size.height * 0.35;
    final targetOffset = (index * itemHeight - screenCenter).clamp(0.0, _scrollController.position.maxScrollExtent);

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sheetHeight = MediaQuery.of(context).size.height * 0.88;

    return Material(
      color: Colors.transparent,
      child: Container(
        height: sheetHeight,
        decoration: const BoxDecoration(
          color: Color(0xFF0F1017),
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
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.headlineMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.song.artist} • Synchronized Lyrics',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.gold, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_note_rounded, color: AppColors.gold, size: 24),
                  tooltip: 'Add / Edit Lyrics',
                  onPressed: () => _showLyricsEditorDialog(),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(color: AppColors.border, height: 1),

          // Main Lyrics Body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
                : _lyrics.isEmpty
                    ? _buildEmptyState()
                    : Stack(
                        children: [
                          NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              if (notification is ScrollStartNotification && notification.dragDetails != null) {
                                if (!_isUserScrolling) {
                                  setState(() => _isUserScrolling = true);
                                }
                              }
                              return false;
                            },
                            child: Obx(() {
                              final currentPos = playerCtrl.position.value;

                              // Find current active lyric line
                              int newIdx = -1;
                              for (int i = 0; i < _lyrics.length; i++) {
                                if (_lyrics[i].isTimestamped) {
                                  if (_lyrics[i].timestamp <= currentPos) {
                                    newIdx = i;
                                  } else {
                                    break;
                                  }
                                }
                              }

                              if (newIdx != _activeLineIndex) {
                                _activeLineIndex = newIdx;
                                if (!_isUserScrolling) {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    _scrollToActiveLine(_activeLineIndex);
                                  });
                                }
                              }

                              return ListView.builder(
                                controller: _scrollController,
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                                itemCount: _lyrics.length,
                                itemBuilder: (context, index) {
                                  final line = _lyrics[index];
                                  final isActive = index == _activeLineIndex;

                                  return GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      if (line.isTimestamped) {
                                        HapticFeedback.lightImpact();
                                        playerCtrl.seek(line.timestamp);
                                        setState(() => _isUserScrolling = false);
                                      }
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 250),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      child: Text(
                                        line.text,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: isActive ? 20 : 15,
                                          fontWeight: isActive ? FontWeight.w900 : FontWeight.w500,
                                          color: isActive ? AppColors.gold : Colors.white.withValues(alpha: 0.4),
                                          letterSpacing: isActive ? 0.3 : 0.1,
                                          shadows: isActive
                                              ? [
                                                  Shadow(
                                                    color: AppColors.gold.withValues(alpha: 0.4),
                                                    blurRadius: 16,
                                                  ),
                                                ]
                                              : null,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            }),
                          ),

                          // Resume Auto-Scroll floating chip
                          if (_isUserScrolling)
                            Positioned(
                              bottom: 20,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _isUserScrolling = false);
                                    _scrollToActiveLine(_activeLineIndex);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E202B),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: AppColors.gold, width: 1.0),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.6),
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.sync_rounded, color: AppColors.gold, size: 16),
                                        SizedBox(width: 6),
                                        Text(
                                          'Sync with playback',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.gold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lyrics_outlined, size: 54, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text(
              'No Lyrics Available',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Place a matching .lrc file in the same folder as "${widget.song.title}", or paste lyrics manually.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.add_rounded, color: Colors.black),
              label: const Text('Add or Paste Lyrics', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
              onPressed: () => _showLyricsEditorDialog(),
            ),
          ],
        ),
      ),
    );
  }

  void _showLyricsEditorDialog() {
    final textController = TextEditingController();
    // Pre-populate with existing lyrics if available
    if (_lyrics.isNotEmpty) {
      textController.text = _lyrics.map((l) => l.text).join('\n');
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add / Edit Lyrics', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste LRC format with [mm:ss.xx] timestamps, or plain text lyrics line-by-line:',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: textController,
                maxLines: 10,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: '[00:15.30] First lyric line\n[00:20.10] Second lyric line...',
                  hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
            child: const Text('Save', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
            onPressed: () async {
              final content = textController.text.trim();
              if (content.isNotEmpty) {
                await lyricsService.saveLyricsForSong(widget.song.id, content);
                await _loadLyrics();
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
          ),
        ],
      ),
    );
  }
}
