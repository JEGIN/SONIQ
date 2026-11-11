import 'dart:async';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/models/soniq_replay_model.dart';

class SoniqReplayStoryView extends StatefulWidget {
  final SoniqReplayModel replay;

  const SoniqReplayStoryView({super.key, required this.replay});

  @override
  State<SoniqReplayStoryView> createState() => _SoniqReplayStoryViewState();
}

class _SoniqReplayStoryViewState extends State<SoniqReplayStoryView> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  int _currentIndex = 0;
  static const int _totalSlides = 6;
  Timer? _autoAdvanceTimer;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startTimer();
  }

  void _startTimer() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!_isPaused && mounted) {
        if (_currentIndex < _totalSlides - 1) {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
          );
        } else {
          _autoAdvanceTimer?.cancel();
        }
      }
    });
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details, double screenWidth) {
    setState(() => _isPaused = true);
    final dx = details.localPosition.dx;
    if (dx < screenWidth * 0.3) {
      if (_currentIndex > 0) {
        _pageController.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    } else {
      if (_currentIndex < _totalSlides - 1) {
        _pageController.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      } else {
        Navigator.pop(context);
      }
    }
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPaused = false);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final r = widget.replay;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTapDown: (details) => _onTapDown(details, screenWidth),
          onTapUp: _onTapUp,
          onTapCancel: () => setState(() => _isPaused = false),
          child: Stack(
            children: [
              // Slide Pages
              PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (idx) {
                  setState(() => _currentIndex = idx);
                  _startTimer();
                },
                children: [
                  _buildIntroSlide(r),
                  _buildTopSongsSlide(r),
                  _buildTopArtistsSlide(r),
                  _buildTopAlbumsSlide(r),
                  _buildHabitsSlide(r),
                  _buildRecapCardSlide(r),
                ],
              ),

              // Top Story Progress Bars
              Positioned(
                top: 10,
                left: 16,
                right: 16,
                child: Row(
                  children: List.generate(_totalSlides, (idx) {
                    return Expanded(
                      child: Container(
                        height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: idx < _currentIndex
                              ? AppColors.gold
                              : (idx == _currentIndex ? AppColors.gold.withValues(alpha: 0.8) : Colors.white24),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              // Close Button
              Positioned(
                top: 18,
                right: 14,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- SLIDE 1: Welcome & Total Hours ---
  Widget _buildIntroSlide(SoniqReplayModel r) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF280B3B), Color(0xFF0F081C), Colors.black],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.gold),
            ),
            child: Text(
              'SONIQ REPLAY ${r.year}',
              style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Your Year in Offline Sound',
            style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, height: 1.15),
          ),
          const SizedBox(height: 16),
          const Text(
            'You turned on the music, unplugged from the internet, and immersed yourself in genuine listening.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: 40),
          Row(
            children: [
              _buildBigMetric(r.totalListeningHours.toStringAsFixed(1), 'HOURS LISTENED', AppColors.gold),
              const SizedBox(width: 32),
              _buildBigMetric('${r.totalQualifiedPlays}', 'QUALIFIED PLAYS', AppColors.primary),
            ],
          ),
        ],
      ),
    );
  }

  // --- SLIDE 2: Top Songs ---
  Widget _buildTopSongsSlide(SoniqReplayModel r) {
    final topSong = r.topSongs.isNotEmpty ? r.topSongs.first : null;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF381A08), Color(0xFF140D05), Colors.black],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 30),
          const Text('YOUR #1 SONG', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.5)),
          const SizedBox(height: 4),
          Text(topSong?.title ?? 'No Track Data', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
          Text(topSong?.subtitle ?? '', style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),

          const SizedBox(height: 24),

          // Glowing vinyl ring
          Center(
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [Color(0xFFFFD700), Color(0xFF332000), Colors.black],
                ),
                boxShadow: [
                  BoxShadow(color: AppColors.gold.withValues(alpha: 0.3), blurRadius: 30, spreadRadius: 4),
                ],
              ),
              child: const Icon(Icons.music_note_rounded, color: Colors.black, size: 54),
            ),
          ),

          const SizedBox(height: 30),
          const Text('Top 5 Songs', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 10),

          Expanded(
            child: ListView(
              physics: const NeverScrollableScrollPhysics(),
              children: r.topSongs.take(5).toList().asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final song = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text('$idx', style: TextStyle(color: idx == 1 ? AppColors.gold : AppColors.textMuted, fontWeight: FontWeight.w900, fontSize: 14)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                            Text(song.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                          ],
                        ),
                      ),
                      Text('${song.playCount} plays', style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 11)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // --- SLIDE 3: Top Artists ---
  Widget _buildTopArtistsSlide(SoniqReplayModel r) {
    final topArtist = r.topArtists.isNotEmpty ? r.topArtists.first : null;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [Color(0xFF0D2538), Color(0xFF09141F), Colors.black],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 30),
          const Text('YOUR TOP ARTIST', style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.5)),
          const SizedBox(height: 4),
          Text(topArtist?.title ?? 'No Artist Data', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
          Text('${topArtist?.playCount ?? 0} plays • ${topArtist?.formattedDuration ?? ''}', style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),

          const SizedBox(height: 34),

          const Text('Artists You Kept on Heavy Rotation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 14),

          Expanded(
            child: ListView(
              physics: const NeverScrollableScrollPhysics(),
              children: r.topArtists.take(5).toList().asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final artist = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF132233),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: idx == 1 ? const Color(0xFF00E5FF) : Colors.white12,
                          shape: BoxShape.circle,
                        ),
                        child: Text('$idx', style: TextStyle(color: idx == 1 ? Colors.black : Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(artist.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                      Text('${artist.playCount} plays', style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.w700, fontSize: 12)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // --- SLIDE 4: Top Albums & Favorite Genre ---
  Widget _buildTopAlbumsSlide(SoniqReplayModel r) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF330926), Color(0xFF150410), Colors.black],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 30),
          const Text('YOUR MUSICAL IDENTITY', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.5)),
          const SizedBox(height: 6),
          Text(r.favoriteGenre, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
          const Text('Top Genre of the Year', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),

          const SizedBox(height: 30),
          const Text('Top Albums', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 12),

          Expanded(
            child: ListView(
              physics: const NeverScrollableScrollPhysics(),
              children: r.topAlbums.take(5).toList().asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final album = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF280C20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text('$idx', style: TextStyle(color: idx == 1 ? AppColors.primary : AppColors.textMuted, fontWeight: FontWeight.w900, fontSize: 13)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(album.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                            Text(album.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                          ],
                        ),
                      ),
                      Text('${album.playCount} plays', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 11)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // --- SLIDE 5: Habits & Streaks ---
  Widget _buildHabitsSlide(SoniqReplayModel r) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E2606), Color(0xFF0F1404), Colors.black],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 30),
          const Text('YOUR LISTENING RHYTHM', style: TextStyle(color: Color(0xFFB5E853), fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.5)),
          const SizedBox(height: 6),
          const Text('Dedication & Streaks', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),

          const SizedBox(height: 32),

          _buildHabitHighlight('Longest Streak', '${r.longestStreakDays} Days', Icons.local_fire_department_rounded, const Color(0xFFFF5722)),
          const SizedBox(height: 14),
          _buildHabitHighlight('Peak Listening Month', r.peakMonth, Icons.calendar_month_rounded, const Color(0xFFB5E853)),
          const SizedBox(height: 14),
          _buildHabitHighlight('Most Active Day', r.mostActiveDay, Icons.headphones_rounded, const Color(0xFF00E5FF)),

          const SizedBox(height: 28),

          const Text('Milestones Unlocked', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 10),

          ...r.milestones.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFFB5E853), size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(m, style: const TextStyle(color: Colors.white, fontSize: 12))),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // --- SLIDE 6: Final Shareable Recap Card ---
  Widget _buildRecapCardSlide(SoniqReplayModel r) {
    final topSong = r.topSongs.isNotEmpty ? r.topSongs.first.title : 'None';
    final topArtist = r.topArtists.isNotEmpty ? r.topArtists.first.title : 'None';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF280B3B), Color(0xFF140D05), Colors.black],
        ),
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Recap Poster Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF191426),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.gold, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.25),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('SONIQ REPLAY', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 2)),
                    Text('${r.year}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  '${r.totalListeningHours.toStringAsFixed(1)} Hours',
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                ),
                Text('${r.totalQualifiedPlays} Tracks Played', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const Divider(color: AppColors.border, height: 28),
                _buildSummaryLine('Top Song', topSong),
                const SizedBox(height: 8),
                _buildSummaryLine('Top Artist', topArtist),
                const SizedBox(height: 8),
                _buildSummaryLine('Genre', r.favoriteGenre),
                const SizedBox(height: 8),
                _buildSummaryLine('Best Streak', '${r.longestStreakDays} Days'),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // Share Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.share_rounded, size: 20),
            label: const Text('Share Replay Summary', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            onPressed: () {
              final shareText = '''🎵 My SONIQ Replay ${r.year}
⏱️ ${r.totalListeningHours.toStringAsFixed(1)} hours of pure offline music
🔥 ${r.totalQualifiedPlays} qualified tracks
🥇 Top Song: $topSong
🎤 Top Artist: $topArtist
⚡ Longest Streak: ${r.longestStreakDays} days

Offline. Private. High-Fidelity. #SONIQMusic''';
              // ignore: deprecated_member_use
              Share.share(shareText);
            },
          ),

          const SizedBox(height: 12),

          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildBigMetric(String value, String label, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 36, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildHabitHighlight(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B230C),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 14),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildSummaryLine(String title, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        Expanded(
          child: Text(
            val,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
