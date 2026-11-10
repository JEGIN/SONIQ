import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';

enum SoniqButtonVariant { primary, secondary, outline, text, gold }

class SoniqButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Widget? icon;
  final SoniqButtonVariant variant;
  final double? width;
  final double height;
  final bool isLoading;

  const SoniqButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.variant = SoniqButtonVariant.primary,
    this.width,
    this.height = 50,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    BoxDecoration decoration;
    TextStyle textStyle;

    switch (variant) {
      case SoniqButtonVariant.primary:
        decoration = BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryGlow,
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        );
        textStyle = AppTypography.labelLarge.copyWith(color: Colors.white);
        break;

      case SoniqButtonVariant.gold:
        decoration = BoxDecoration(
          gradient: AppColors.goldGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.goldGlow,
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        );
        textStyle = AppTypography.labelLarge.copyWith(color: AppColors.textDark);
        break;

      case SoniqButtonVariant.secondary:
        decoration = BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight, width: 1),
        );
        textStyle = AppTypography.labelLarge.copyWith(color: AppColors.textPrimary);
        break;

      case SoniqButtonVariant.outline:
        decoration = BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary, width: 1.5),
        );
        textStyle = AppTypography.labelLarge.copyWith(color: AppColors.primary);
        break;

      case SoniqButtonVariant.text:
        decoration = const BoxDecoration();
        textStyle = AppTypography.labelLarge.copyWith(color: AppColors.textSecondary);
        break;
    }

    return Container(
      width: width,
      height: height,
      decoration: decoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        icon!,
                        const SizedBox(width: 8),
                      ],
                      Text(text, style: textStyle),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
