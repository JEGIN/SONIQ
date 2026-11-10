import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Background surfaces (OLED Luxury Dark)
  static const Color background = Color(0xFF090A0E);
  static const Color surface = Color(0xFF12131A);
  static const Color surfaceElevated = Color(0xFF1B1D26);
  static const Color surfaceHighlight = Color(0xFF262936);
  static const Color surfaceGlass = Color(0xCC141620);

  // Border & Dividers
  static const Color border = Color(0xFF232634);
  static const Color borderLight = Color(0xFF323648);
  static const Color divider = Color(0xFF1E212D);

  // Brand Accents
  static const Color primary = Color(0xFFFF2A85); // Neon Pink / Magenta
  static const Color primaryGlow = Color(0x66FF2A85);
  static const Color secondary = Color(0xFF8B5CF6); // Electric Violet
  static const Color cyan = Color(0xFF00E5FF); // Cyber Cyan (Waveform Selected)
  static const Color cyanGlow = Color(0x5500E5FF);
  static const Color gold = Color(0xFFF59E0B); // Luxury Vinyl Gold
  static const Color goldGlow = Color(0x55F59E0B);
  static const Color green = Color(0xFF10B981);
  static const Color red = Color(0xFFEF4444);

  // Text Hierarchy
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textDark = Color(0xFF0F172A);

  // Waveform Palette
  static const Color waveformInactive = Color(0xFF242C44);
  static const Color waveformActive = Color(0xFF00C3FF);
  static const Color waveformHandle = Color(0xFFFF2A85);
  static const Color waveformOverlay = Color(0x3300C3FF);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFF2A85), Color(0xFF9333EA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [Color(0xFF1B1D26), Color(0xFF12131A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient glowGradient = LinearGradient(
    colors: [Color(0x33FF2A85), Colors.transparent],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
