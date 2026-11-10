import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart' hide SongModel;
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/models/equalizer_preset_model.dart';
import '../../../core/models/song_model.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../equalizer/controllers/equalizer_controller.dart';
import '../../library/controllers/library_controller.dart';
import '../../player/controllers/player_controller.dart';
import '../../player/views/widgets/queue_bottom_sheet.dart';

class CarModeView extends StatefulWidget {
  const CarModeView({super.key});

  @override
  State<CarModeView> createState() => _CarModeViewState();
}

class _CarModeViewState extends State<CarModeView> with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;
  final playerController = Get.find<AudioPlayerController>();
  final eqController = Get.find<EqualizerController>();
  final libraryController = Get.find<LibraryController>();

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );

    if (playerController.isPlaying.value) {
      _rotationController.repeat();
    }

    // Auto-activate Renault Triber Car Audio Profile when entering Car Mode
    WidgetsBinding.instance.addPostFrameCallback((_) {
      eqController.switchAudioProfile('renault_triber');
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            final isLandscape = orientation == Orientation.landscape;
            if (isLandscape) {
              return _buildLandscapeLayout(context);
            }
            return _buildPortraitLayout(context);
          },
        ),
      ),
    );
  }

  Widget _buildPortraitLayout(BuildContext context) {
    return Column(
      children: [
        // 1. Top Automotive Status Bar & Exit
        _buildTopBar(context),

        const Spacer(flex: 1),

        // 2. Large Central Artwork / Vinyl Disc
        _buildArtworkSection(),

        const SizedBox(height: 20),

        // 3. Huge Song Info
        _buildSongInfo(),

        const Spacer(flex: 1),

        // 4. Large Driver Seek Bar with -15s / +15s Jumps
        _buildDriverSeekBar(),

        const SizedBox(height: 12),

        // 5. Massive Primary Playback Controls
        _buildLargeControls(),

        const SizedBox(height: 16),

        // 6. Renault Triber Presets Bar
        _buildTriberPresetBar(),

        const SizedBox(height: 14),

        // 7. Bottom Navigation (Queue / Library Quick Access)
        _buildBottomBar(context),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildLandscapeLayout(BuildContext context) {
    return Row(
      children: [
        // Left Column: Artwork & Status
        Expanded(
          flex: 4,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTopBar(context),
              Expanded(child: Center(child: _buildArtworkSection(size: 160))),
              _buildTriberPresetBar(),
            ],
          ),
        ),

        // Right Column: Info, Seek, Huge Controls
        Expanded(
          flex: 6,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSongInfo(),
                _buildDriverSeekBar(),
                _buildLargeControls(),
                _buildBottomBar(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Exit Car Mode Button
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E202B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border, width: 1.2),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.close_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 6),
                  Text(
                    'EXIT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Renault Triber Status Badge
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF261D00),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.gold, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.gold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'RENAULT TRIBER DSP',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Road Noise Boost Toggle Pill
          Obx(() {
            final active = eqController.isRoadNoiseCompensationEnabled.value;
            return InkWell(
              onTap: () => eqController.toggleRoadNoiseCompensation(),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFF332600) : const Color(0xFF1E202B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: active ? AppColors.gold : AppColors.border,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.speed_rounded,
                      size: 16,
                      color: active ? AppColors.gold : AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ROAD BOOST',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: active ? AppColors.gold : AppColors.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildArtworkSection({double size = 220}) {
    return Obx(() {
      final song = playerController.currentSong.value;
      final isPlaying = playerController.isPlaying.value;

      if (isPlaying) {
        if (!_rotationController.isAnimating) _rotationController.repeat();
      } else {
        if (_rotationController.isAnimating) _rotationController.stop();
      }

      final songId = int.tryParse(song?.id ?? '');

      return Center(
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer Glowing Aura
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.gold.withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

              // Spinning Vinyl Disc
              RotationTransition(
                turns: _rotationController,
                child: Container(
                  width: size * 0.9,
                  height: size * 0.9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF141416),
                    border: Border.all(color: const Color(0xFF2E2E34), width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.8),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: size * 0.55,
                      height: size * 0.55,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black,
                      ),
                      child: ClipOval(
                        child: songId != null
                            ? QueryArtworkWidget(
                                id: songId,
                                type: ArtworkType.AUDIO,
                                keepOldArtwork: true,
                                artworkFit: BoxFit.cover,
                                nullArtworkWidget: Image.asset(
                                  'assets/icons/app_icon.png',
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Image.asset(
                                'assets/icons/app_icon.png',
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildSongInfo() {
    return Obx(() {
      final song = playerController.currentSong.value;
      final title = song?.title ?? 'No Track Playing';
      final artist = song?.artist ?? 'Renault Triber Car Mode';

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildDriverSeekBar() {
    return Obx(() {
      final pos = playerController.position.value;
      final dur = playerController.duration.value;
      final maxMs = max(dur.inMilliseconds, 1);
      final currMs = pos.inMilliseconds.clamp(0, maxMs);

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            Row(
              children: [
                // Jump Backward -10s
                IconButton(
                  icon: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 32),
                  tooltip: 'Rewind 10s',
                  onPressed: () {
                    final target = pos - const Duration(seconds: 10);
                    playerController.seek(target < Duration.zero ? Duration.zero : target);
                  },
                ),

                // Slider Track
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 6,
                      activeTrackColor: AppColors.gold,
                      inactiveTrackColor: const Color(0xFF2A2E3D),
                      thumbColor: Colors.white,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                    ),
                    child: Slider(
                      value: currMs.toDouble(),
                      min: 0.0,
                      max: maxMs.toDouble(),
                      onChanged: (val) {
                        playerController.seek(Duration(milliseconds: val.toInt()));
                      },
                    ),
                  ),
                ),

                // Jump Forward +10s
                IconButton(
                  icon: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 32),
                  tooltip: 'Forward 10s',
                  onPressed: () {
                    final target = pos + const Duration(seconds: 10);
                    playerController.seek(target > dur ? dur : target);
                  },
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DurationFormatter.format(pos.inMilliseconds),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    DurationFormatter.format(dur.inMilliseconds),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildLargeControls() {
    return Obx(() {
      final isPlaying = playerController.isPlaying.value;
      final isShuffle = playerController.isShuffle.value;

      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Shuffle Button (Driver Size)
          IconButton(
            icon: Icon(
              Icons.shuffle_rounded,
              color: isShuffle ? AppColors.gold : AppColors.textMuted,
              size: 32,
            ),
            onPressed: () => playerController.toggleShuffle(),
          ),

          const SizedBox(width: 14),

          // Previous Track Button (70x70)
          GestureDetector(
            onTap: () => playerController.skipPrevious(),
            child: Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1E202B),
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 38),
            ),
          ),

          const SizedBox(width: 16),

          // Primary Play/Pause Button (88x88 Massive with Glow)
          GestureDetector(
            onTap: () => playerController.playPause(),
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [AppColors.gold, Color(0xFFD49E00)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: isPlaying ? 0.6 : 0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.black,
                size: 52,
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Next Track Button (70x70)
          GestureDetector(
            onTap: () => playerController.skipNext(),
            child: Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1E202B),
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 38),
            ),
          ),

          const SizedBox(width: 14),

          // Repeat Button
          IconButton(
            icon: Icon(
              Icons.repeat_rounded,
              color: playerController.loopMode.value != LoopMode.off
                  ? AppColors.gold
                  : AppColors.textMuted,
              size: 32,
            ),
            onPressed: () => playerController.cycleRepeatMode(),
          ),
        ],
      );
    });
  }

  Widget _buildTriberPresetBar() {
    final presets = EqualizerPreset.renaultTriberPresets;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: presets.map((preset) {
            return Obx(() {
              final isSelected = eqController.currentPreset.value.name == preset.name;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => eqController.applyPreset(preset),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.gold : const Color(0xFF1E202B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppColors.gold : AppColors.border,
                        width: 1.2,
                      ),
                    ),
                    child: Text(
                      preset.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                        color: isSelected ? Colors.black : Colors.white,
                      ),
                    ),
                  ),
                ),
              );
            });
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildQuickActionBtn(
            context,
            icon: Icons.queue_music_rounded,
            label: 'QUEUE',
            onTap: () => _openCarQueueSheet(context),
          ),
          _buildQuickActionBtn(
            context,
            icon: Icons.favorite_rounded,
            label: 'FAVORITES',
            onTap: () => _openCarFavoritesSheet(context),
          ),
          _buildQuickActionBtn(
            context,
            icon: Icons.library_music_rounded,
            label: 'ALL SONGS',
            onTap: () => _openCarLibrarySheet(context),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionBtn(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E202B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.gold, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCarQueueSheet(BuildContext context) {
    QueueBottomSheet.show(context);
  }

  void _openCarFavoritesSheet(BuildContext context) {
    final favSongs = libraryController.allSongs.where((s) => s.isFavorite).toList();
    _showSongListModal(context, 'Favorite Tracks (${favSongs.length})', favSongs);
  }

  void _openCarLibrarySheet(BuildContext context) {
    _showSongListModal(context, 'All Songs (${libraryController.allSongs.length})', libraryController.allSongs);
  }

  void _showSongListModal(BuildContext context, String title, List<SongModel> songs) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Color(0xFF14161F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.library_music_rounded, color: AppColors.gold, size: 24),
                  const SizedBox(width: 10),
                  Text(title, style: AppTypography.headlineMedium),
                ],
              ),
            ),
            const Divider(color: AppColors.border, height: 1),
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: songs.length,
                itemBuilder: (ctx, idx) {
                  final song = songs[idx];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    title: Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      song.artist,
                      maxLines: 1,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    onTap: () {
                      playerController.playSong(song, songs);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
