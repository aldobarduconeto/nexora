import 'package:flutter/material.dart';

abstract final class AppColors {
  // Backgrounds
  static const Color background = Color(0xFF080D18);
  static const Color surface = Color(0xFF101827);
  static const Color surfaceSecondary = Color(0xFF172235);
  static const Color surfaceElevated = Color(0xFF1D2A40);

  // Brand
  static const Color primary = Color(0xFF4F7DFF);
  static const Color primaryHover = Color(0xFF7095FF);
  static const Color primaryDark = Color(0xFF294DB8);
  static const Color accent = Color(0xFF35D9FF);

  // Text
  static const Color textPrimary = Color(0xFFF1F5FF);
  static const Color textSecondary = Color(0xFFA0AEC4);
  static const Color textMuted = Color(0xFF697991);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Borders and dividers
  static const Color border = Color(0xFF26344B);
  static const Color divider = Color(0xFF1D293B);
  static const Color borderFocused = Color(0xFF4F7DFF);

  // Status
  static const Color success = Color(0xFF36D399);
  static const Color warning = Color(0xFFFFC857);
  static const Color error = Color(0xFFFF647C);
  static const Color info = Color(0xFF35D9FF);

  // Chat
  static const Color messageSent = Color(0xFF294DB8);
  static const Color messageReceived = Color(0xFF172235);
  static const Color online = Color(0xFF36D399);
  static const Color offline = Color(0xFF697991);
  static const Color typingIndicator = Color(0xFF35D9FF);

  // Security and privacy
  static const Color encrypted = Color(0xFF36D399);
  static const Color anonymous = Color(0xFF9B8CFF);

  // Overlays
  static const Color overlay = Color(0x99000000);
  static const Color scrim = Color(0xCC080D18);

  // Utility
  static const Color transparent = Colors.transparent;
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
}
