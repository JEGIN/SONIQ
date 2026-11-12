import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/localization/soniq_localizations.dart';

class VerticalFader extends StatelessWidget {
  final double value; // in dB
  final double min;
  final double max;
  final String label;
  final ValueChanged<double> onChanged;
  final Color activeColor;
  final double height;

  const VerticalFader({
    super.key,
    required this.value,
    this.min = -12.0,
    this.max = 12.0,
    required this.label,
    required this.onChanged,
    this.activeColor = AppColors.gold,
    this.height = 180.0,
  });

  @override
  Widget build(BuildContext context) {
    final double normalized = ((value - min) / (max - min)).clamp(0.0, 1.0);
    void adjustBy(double delta) =>
        onChanged((value + delta).clamp(min, max).toDouble());

    return Semantics(
      slider: true,
      focusable: true,
      label: '${SoniqLocalizations.of(context).text('bandLevel')} $label',
      value: '${value.toStringAsFixed(1)} dB',
      increasedValue: '${(value + 0.5).clamp(min, max).toStringAsFixed(1)} dB',
      decreasedValue: '${(value - 0.5).clamp(min, max).toStringAsFixed(1)} dB',
      onIncrease: () => adjustBy(0.5),
      onDecrease: () => adjustBy(-0.5),
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          switch (event.logicalKey) {
            case LogicalKeyboardKey.arrowUp:
            case LogicalKeyboardKey.arrowRight:
            case LogicalKeyboardKey.equal:
              adjustBy(0.5);
              return KeyEventResult.handled;
            case LogicalKeyboardKey.arrowDown:
            case LogicalKeyboardKey.arrowLeft:
            case LogicalKeyboardKey.minus:
              adjustBy(-0.5);
              return KeyEventResult.handled;
            default:
              return KeyEventResult.ignored;
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Gain value readout
            Text(
              value > 0
                  ? '+${value.toStringAsFixed(1)}'
                  : value.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: value != 0 ? activeColor : AppColors.textMuted,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),

            const SizedBox(height: 6),

            // Vertical Track & Capsule Thumb
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: (details) {
                final renderBox = context.findRenderObject() as RenderBox?;
                if (renderBox != null) {
                  final localY = details.localPosition.dy.clamp(0.0, height);
                  // Top is max, bottom is min
                  final ratio = 1.0 - (localY / height);
                  final newValue = min + ratio * (max - min);

                  // Snap near 0.0 dB
                  final snapped = newValue.abs() < 0.4 ? 0.0 : newValue;
                  if (snapped == 0.0 && value != 0.0) {
                    HapticFeedback.selectionClick();
                  }
                  onChanged(snapped);
                }
              },
              child: SizedBox(
                width: 48,
                height: height,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Track line
                    Container(
                      width: 3,
                      height: height,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHighlight,
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),

                    // Center 0 dB marker
                    Positioned(
                      top: height / 2 - 1,
                      child: Container(
                        width: 14,
                        height: 2,
                        decoration: BoxDecoration(
                          color: AppColors.textMuted.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),

                    // Active level line from center to thumb
                    Positioned(
                      top: normalized >= 0.5
                          ? (height * (1.0 - normalized))
                          : (height / 2),
                      height: (height * (normalized - 0.5)).abs(),
                      child: Container(
                        width: 3,
                        decoration: BoxDecoration(
                          color: activeColor.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      ),
                    ),

                    // Capsule Thumb (Matches Poweramp design)
                    Positioned(
                      top: (height * (1.0 - normalized) - 14).clamp(
                        0.0,
                        height - 28,
                      ),
                      child: Container(
                        width: 24,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E202B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: value != 0
                                ? activeColor
                                : const Color(0xFF3E4254),
                            width: 1.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: value != 0
                                  ? activeColor.withValues(alpha: 0.35)
                                  : Colors.black.withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: value != 0
                                  ? activeColor
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Frequency Label
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
