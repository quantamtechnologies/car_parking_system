import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

ThemeData parkingTheme() {
  const primary = Color(0xFF0F4CFF);
  const deepBlue = Color(0xFF0A1F44);
  const accent = Color(0xFF4DD4FF);
  const bg = Color(0xFFF4F8FF);

  final baseTextTheme = GoogleFonts.manropeTextTheme();

  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: accent,
      surface: Colors.white,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: bg,
    textTheme: baseTextTheme.apply(
      bodyColor: deepBlue,
      displayColor: deepBlue,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: deepBlue,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      shadowColor: Colors.black.withOpacity(0.08),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: primary, width: 1.4)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    ),
  );
}

class BlueGradient extends LinearGradient {
  const BlueGradient()
      : super(
          colors: const [Color(0xFF0F4CFF), Color(0xFF48C9FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
}
