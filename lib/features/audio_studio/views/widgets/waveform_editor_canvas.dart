import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum _DragTarget { none, startHandle, endHandle, middleRegion }

class WaveformEditorCanvas extends StatefulWidget {
  final List<double> peaks;
  final int totalDurationMs;
  final int startMs;
  final int endMs;
  final int previewCurrentMs;
  final double zoom;
  final Function(int newStartMs) onStartChanged;
  final Function(int newEndMs) onEndChanged;
  final Function(int newStartMs, int newEndMs) onRegionMoved;

  const WaveformEditorCanvas({
    super.key,
    required this.peaks,
    required this.totalDurationMs,
    required this.startMs,
    required this.endMs,
    required this.previewCurrentMs,
    required this.zoom,
    required this.onStartChanged,
    required this.onEndChanged,
    required this.onRegionMoved,
  });

  @override
  State<WaveformEditorCanvas> createState() => _WaveformEditorCanvasState();
}

class _WaveformEditorCanvasState extends State<WaveformEditorCanvas> {
  _DragTarget _activeDrag = _DragTarget.none;
  double _initialDragX = 0;
  int _dragInitialStartMs = 0;
  int _dragInitialEndMs = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth * widget.zoom;
        final height = constraints.maxHeight;

        final startX = (widget.startMs / widget.totalDurationMs) * totalWidth;
        final endX = (widget.endMs / widget.totalDurationMs) * totalWidth;
        final playheadX = (widget.previewCurrentMs / widget.totalDurationMs) * totalWidth;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (details) {
            final x = details.localPosition.dx;
            const touchRadius = 32.0;

            if ((x - startX).abs() < touchRadius) {
              _activeDrag = _DragTarget.startHandle;
              HapticFeedback.selectionClick();
            } else if ((x - endX).abs() < touchRadius) {
              _activeDrag = _DragTarget.endHandle;
              HapticFeedback.selectionClick();
            } else if (x > startX && x < endX) {
              _activeDrag = _DragTarget.middleRegion;
              _initialDragX = x;
              _dragInitialStartMs = widget.startMs;
              _dragInitialEndMs = widget.endMs;
              HapticFeedback.selectionClick();
            } else {
              _activeDrag = _DragTarget.none;
            }
          },
          onHorizontalDragUpdate: (details) {
            final x = details.localPosition.dx.clamp(0.0, totalWidth);
            final msAtX = ((x / totalWidth) * widget.totalDurationMs).toInt();

            switch (_activeDrag) {
              case _DragTarget.startHandle:
                final newStart = msAtX.clamp(0, widget.endMs - 500);
                widget.onStartChanged(newStart);
                break;

              case _DragTarget.endHandle:
                final newEnd = msAtX.clamp(widget.startMs + 500, widget.totalDurationMs);
                widget.onEndChanged(newEnd);
                break;

              case _DragTarget.middleRegion:
                final deltaPx = x - _initialDragX;
                final deltaMs = ((deltaPx / totalWidth) * widget.totalDurationMs).toInt();
                final regionLen = _dragInitialEndMs - _dragInitialStartMs;

                int newStart = (_dragInitialStartMs + deltaMs).clamp(0, widget.totalDurationMs - regionLen);
                int newEnd = newStart + regionLen;
                widget.onRegionMoved(newStart, newEnd);
                break;

              case _DragTarget.none:
                break;
            }
          },
          onHorizontalDragEnd: (_) {
            _activeDrag = _DragTarget.none;
          },
          child: CustomPaint(
            size: Size(totalWidth, height),
            painter: _WaveformPainter(
              peaks: widget.peaks,
              startX: startX,
              endX: endX,
              playheadX: playheadX,
              activeDrag: _activeDrag,
            ),
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> peaks;
  final double startX;
  final double endX;
  final double playheadX;
  final _DragTarget activeDrag;

  _WaveformPainter({
    required this.peaks,
    required this.startX,
    required this.endX,
    required this.playheadX,
    required this.activeDrag,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (peaks.isEmpty) return;

    final centerY = size.height / 2;
    final maxWaveformHeight = size.height * 0.75;
    final double barWidth = max(2.0, (size.width / peaks.length) * 0.7);
    final double spacing = (size.width / peaks.length) * 0.3;
    final double step = barWidth + spacing;

    // Paints
    final inactiveBarPaint = Paint()
      ..color = const Color(0xFF1E283D)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.fill;

    final activeBarPaint = Paint()
      ..color = const Color(0xFF00C8FF)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.fill;

    final selectionOverlayPaint = Paint()
      ..color = const Color(0x1800C8FF)
      ..style = PaintingStyle.fill;

    // 1. Draw light blue highlight box for active region
    final selectedRect = Rect.fromLTRB(startX, 0, endX, size.height);
    canvas.drawRect(selectedRect, selectionOverlayPaint);

    // 2. Draw Waveform bars
    for (int i = 0; i < peaks.length; i++) {
      final x = i * step + (barWidth / 2);
      final double peakVal = peaks[i];
      final double barHeight = max(4.0, peakVal * maxWaveformHeight);

      final isSelected = x >= startX && x <= endX;
      final paint = isSelected ? activeBarPaint : inactiveBarPaint;

      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, centerY),
          width: barWidth,
          height: barHeight,
        ),
        Radius.circular(barWidth / 2),
      );

      canvas.drawRRect(rect, paint);
    }

    // 3. Draw Vertical Pink Selection Boundaries & Tabs (Matches Reference Image 1)
    final handleLinePaint = Paint()
      ..color = const Color(0xFFFF2A85)
      ..strokeWidth = 2.5;

    // Left vertical line
    canvas.drawLine(Offset(startX, 0), Offset(startX, size.height), handleLinePaint);
    // Right vertical line
    canvas.drawLine(Offset(endX, 0), Offset(endX, size.height), handleLinePaint);

    // 4. Draw Start Handle (Bottom magenta tab with 4x2 grip dots)
    _drawHandleTab(
      canvas: canvas,
      x: startX,
      y: size.height - 40,
      width: 32,
      height: 38,
      isTop: false,
    );

    // 5. Draw End Handle (Top magenta tab with 4x2 grip dots)
    _drawHandleTab(
      canvas: canvas,
      x: endX,
      y: 2,
      width: 32,
      height: 38,
      isTop: true,
    );

    // 6. Draw Preview Playhead (white vertical line)
    if (playheadX >= startX && playheadX <= endX) {
      final playheadPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2.0;

      canvas.drawLine(Offset(playheadX, 0), Offset(playheadX, size.height), playheadPaint);

      final dotPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(playheadX, centerY), 4, dotPaint);
    }
  }

  void _drawHandleTab({
    required Canvas canvas,
    required double x,
    required double y,
    required double width,
    required double height,
    required bool isTop,
  }) {
    final tabPaint = Paint()
      ..color = const Color(0xFFFF2A85)
      ..style = PaintingStyle.fill;

    // Shift tab slightly inwards or outwards so it's ergonomic
    final rect = isTop
        ? Rect.fromLTWH(x - width + 2, y, width, height)
        : Rect.fromLTWH(x - 2, y, width, height);

    final rrect = RRect.fromRectAndCorners(
      rect,
      topLeft: const Radius.circular(8),
      topRight: const Radius.circular(8),
      bottomLeft: const Radius.circular(8),
      bottomRight: const Radius.circular(8),
    );

    canvas.drawRRect(rrect, tabPaint);

    // Tactile 4x2 Grip Dots
    final dotPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;

    final double dotRadius = 1.3;
    final double startDotX = rect.left + 9;
    final double startDotY = rect.top + 9;

    for (int row = 0; row < 4; row++) {
      for (int col = 0; col < 2; col++) {
        canvas.drawCircle(
          Offset(startDotX + (col * 8), startDotY + (row * 6)),
          dotRadius,
          dotPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.startX != startX ||
        oldDelegate.endX != endX ||
        oldDelegate.playheadX != playheadX ||
        oldDelegate.peaks != peaks ||
        oldDelegate.activeDrag != activeDrag;
  }
}
