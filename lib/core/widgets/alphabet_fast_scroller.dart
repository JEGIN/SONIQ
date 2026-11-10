import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme/app_colors.dart';
import '../../core/models/song_model.dart';

class AlphabetFastScroller extends StatefulWidget {
  final ScrollController scrollController;
  final List<SongModel> songs;
  final double itemExtent;
  final Widget child;
  final bool isArtistSort;

  const AlphabetFastScroller({
    super.key,
    required this.scrollController,
    required this.songs,
    required this.child,
    this.itemExtent = 72.0,
    this.isArtistSort = false,
  });

  @override
  State<AlphabetFastScroller> createState() => _AlphabetFastScrollerState();
}

class _AlphabetFastScrollerState extends State<AlphabetFastScroller> {
  static const List<String> _alphabet = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', '#'
  ];

  String? _activeLetter;
  double _indicatorY = 0.0;
  final GlobalKey _stripKey = GlobalKey();

  // Maps letter -> first song index in list
  Map<String, int> _letterMap = {};

  @override
  void initState() {
    super.initState();
    _computeLetterMap();
  }

  @override
  void didUpdateWidget(covariant AlphabetFastScroller oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.songs != oldWidget.songs || widget.isArtistSort != oldWidget.isArtistSort) {
      _computeLetterMap();
    }
  }

  void _computeLetterMap() {
    final Map<String, int> map = {};
    for (int i = 0; i < widget.songs.length; i++) {
      final song = widget.songs[i];
      final keyText = widget.isArtistSort ? song.artist.trim() : song.title.trim();
      if (keyText.isEmpty) continue;

      final firstChar = keyText[0].toUpperCase();
      final letter = RegExp(r'[A-Z]').hasMatch(firstChar) ? firstChar : '#';

      if (!map.containsKey(letter)) {
        map[letter] = i;
      }
    }
    _letterMap = map;
  }

  void _onPan(Offset localPosition, double height) {
    if (height <= 0 || _alphabet.isEmpty) return;

    final ratio = (localPosition.dy / height).clamp(0.0, 0.999);
    final letterIndex = (ratio * _alphabet.length).floor();
    final letter = _alphabet[letterIndex];

    if (_activeLetter != letter) {
      HapticFeedback.selectionClick();
      _activeLetter = letter;
      _scrollToLetter(letter);
    }

    setState(() {
      _indicatorY = localPosition.dy.clamp(20.0, height - 20.0);
    });
  }

  void _scrollToLetter(String letter) {
    if (!widget.scrollController.hasClients) return;

    int? targetIndex = _letterMap[letter];

    // If letter doesn't have an exact song, find closest following letter
    if (targetIndex == null) {
      final letterIdx = _alphabet.indexOf(letter);
      for (int i = letterIdx + 1; i < _alphabet.length; i++) {
        if (_letterMap.containsKey(_alphabet[i])) {
          targetIndex = _letterMap[_alphabet[i]];
          break;
        }
      }
      // Or previous
      if (targetIndex == null) {
        for (int i = letterIdx - 1; i >= 0; i--) {
          if (_letterMap.containsKey(_alphabet[i])) {
            targetIndex = _letterMap[_alphabet[i]];
            break;
          }
        }
      }
    }

    if (targetIndex != null) {
      final maxScroll = widget.scrollController.position.maxScrollExtent;
      final targetOffset = (targetIndex * widget.itemExtent).clamp(0.0, maxScroll);
      widget.scrollController.jumpTo(targetOffset);
    }
  }

  void _onPanEnd() {
    setState(() {
      _activeLetter = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main list
        widget.child,

        // Vertical Alphabet Bar along the right edge
        if (widget.songs.length > 15)
          Positioned(
            right: 2,
            top: 8,
            bottom: 8,
            child: Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragDown: (details) {
                  final renderBox = _stripKey.currentContext?.findRenderObject() as RenderBox?;
                  if (renderBox != null) {
                    final local = renderBox.globalToLocal(details.globalPosition);
                    _onPan(local, renderBox.size.height);
                  }
                },
                onVerticalDragUpdate: (details) {
                  final renderBox = _stripKey.currentContext?.findRenderObject() as RenderBox?;
                  if (renderBox != null) {
                    final local = renderBox.globalToLocal(details.globalPosition);
                    _onPan(local, renderBox.size.height);
                  }
                },
                onVerticalDragEnd: (_) => _onPanEnd(),
                onVerticalDragCancel: () => _onPanEnd(),
                onTapDown: (details) {
                  final renderBox = _stripKey.currentContext?.findRenderObject() as RenderBox?;
                  if (renderBox != null) {
                    final local = renderBox.globalToLocal(details.globalPosition);
                    _onPan(local, renderBox.size.height);
                  }
                },
                onTapUp: (_) => _onPanEnd(),
                child: Container(
                  key: _stripKey,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  decoration: BoxDecoration(
                    color: _activeLetter != null
                        ? AppColors.surfaceElevated.withValues(alpha: 0.85)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _alphabet.map((letter) {
                      final isSelected = _activeLetter == letter;
                      final hasSongs = _letterMap.containsKey(letter);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 0.8),
                        child: Text(
                          letter,
                          style: TextStyle(
                            fontSize: isSelected ? 13 : 9.5,
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                            color: isSelected
                                ? AppColors.gold
                                : (hasSongs
                                    ? AppColors.textSecondary.withValues(alpha: 0.8)
                                    : AppColors.textMuted.withValues(alpha: 0.3)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),

        // Floating Alphabet Bubble / Indicator near user's touch
        if (_activeLetter != null)
          Positioned(
            right: 48,
            top: (_indicatorY - 32).clamp(10.0, MediaQuery.of(context).size.height - 120),
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.gold, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.goldGlow,
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  _activeLetter!,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.gold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
