import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/localization/soniq_localizations.dart';
import '../../../../core/models/song_model.dart';
import '../../../../core/services/artwork_cache_service.dart';

class CircularVinylArtwork extends StatefulWidget {
  final SongModel song;
  final bool isPlaying;
  final double progress; // 0.0 to 1.0

  const CircularVinylArtwork({
    super.key,
    required this.song,
    required this.isPlaying,
    required this.progress,
  });

  @override
  State<CircularVinylArtwork> createState() => _CircularVinylArtworkState();
}

class _CircularVinylArtworkState extends State<CircularVinylArtwork>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  final ArtworkCacheService _artService = ArtworkCacheService();
  Uint8List? _cachedArtworkBytes;
  String? _loadedSongId;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    );
    _loadArtwork(widget.song.id);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.of(context).disableAnimations;
    _syncRotation();
  }

  void _syncRotation() {
    if (widget.isPlaying && !_reduceMotion) {
      _rotationController.repeat();
    } else {
      _rotationController.stop();
    }
  }

  void _loadArtwork(String songId) async {
    if (_loadedSongId == songId && _cachedArtworkBytes != null) return;
    _loadedSongId = songId;
    final bytes = await _artService.getArtworkBytes(songId);
    if (mounted && _loadedSongId == songId) {
      setState(() {
        _cachedArtworkBytes = bytes;
      });
    }
  }

  @override
  void didUpdateWidget(covariant CircularVinylArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      _syncRotation();
    }
    if (widget.song.id != oldWidget.song.id) {
      _loadArtwork(widget.song.id);
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final size = min(viewport.width * 0.72, viewport.height * 0.44);

    return Semantics(
      image: true,
      label:
          '${SoniqLocalizations.of(context).text('albumArtwork')}: ${widget.song.album}, ${widget.song.artist}',
      child: ExcludeSemantics(
        child: Center(
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1. Golden Circular Progress Ring (Repainted only when progress changes)
                RepaintBoundary(
                  child: CustomPaint(
                    size: Size(size, size),
                    painter: _CircularProgressRingPainter(
                      progress: widget.progress,
                      trackColor: AppColors.surfaceHighlight.withValues(
                        alpha: 0.35,
                      ),
                      progressColor: AppColors.gold,
                    ),
                  ),
                ),

                // 2. Rotating Vinyl Disc (Cached image, isolated from progress rebuilds)
                RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _rotationController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _rotationController.value * 2 * pi,
                        child: child,
                      );
                    },
                    child: Container(
                      width: size * 0.82,
                      height: size * 0.82,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF14151C),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                        border: Border.all(
                          color: const Color(0xFF282A36),
                          width: 3,
                        ),
                      ),
                      child: ClipOval(child: _buildArtworkContent()),
                    ),
                  ),
                ),

                // 3. Center Vinyl Spindle Hole
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.background,
                    border: Border.all(color: AppColors.gold, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArtworkContent() {
    if (_cachedArtworkBytes != null) {
      return Image.memory(
        _cachedArtworkBytes!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }
    return _buildFallbackCover();
  }

  Widget _buildFallbackCover() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          colors: [Color(0xFF2C1E3A), Color(0xFF0F0B18)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.music_note_rounded, size: 54, color: AppColors.gold),
      ),
    );
  }
}

class _CircularProgressRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;

  _CircularProgressRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 4;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    // Draw full background track circle
    canvas.drawCircle(center, radius, trackPaint);

    // Draw progress arc starting from top (-pi / 2)
    final sweepAngle = 2 * pi * progress.clamp(0.0, 1.0);
    if (sweepAngle > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CircularProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
