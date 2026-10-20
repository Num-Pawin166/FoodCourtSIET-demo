import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const bg = Color(0xFFFDF7EC);
  static const surface = Colors.white;
  static const pink = Color(0xFFF7A1C0);
  static const pinkSoft = Color(0xFFFDE1EA);
  static const pinkSofter = Color(0xFFFFF1F4);
  static const accent = Color(0xFFE5437F);
  static const ink = Color(0xFF2B2B2B);
  static const ink2 = Color(0xFF5D5D5D);
  static const muted = Color(0xFF9A9A9A);
  static const line = Color(0xFFF1DFE4);
  static const green = Color(0xFF1F8A4C);
  static const kmitl = Color(0xFF2E8B57);
  static const red = Color(0xFFE5484D);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.accent, surface: AppColors.bg),
    scaffoldBackgroundColor: AppColors.bg,
  );
  return base.copyWith(
    textTheme: GoogleFonts.promptTextTheme(base.textTheme).apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      hintStyle: const TextStyle(color: AppColors.muted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFFD9D9D9))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.pink, width: 1.5)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

final cardShadow = [BoxShadow(color: AppColors.accent.withValues(alpha: 0.10), blurRadius: 10, offset: const Offset(0, 3))];

BoxDecoration cardDecoration({Color color = AppColors.surface, double radius = 16}) =>
    BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius), boxShadow: cardShadow);
