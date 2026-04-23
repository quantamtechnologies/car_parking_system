import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

ThemeData parkingTheme() {
  const primary = Color(0xFF4A35E8);
  const accent = Color(0xFF2EC7FF);
  const deepInk = Color(0xFF0D1530);
  const bg = Color(0xFFF3F6FB);
  const surface = Color(0xFFF9FBFF);

  final baseTextTheme = GoogleFonts.manropeTextTheme();

  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: accent,
      surface: Colors.white,
      surfaceContainerHighest: surface,
      onSurface: deepInk,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: bg,
    textTheme: baseTextTheme.apply(
      bodyColor: deepInk,
      displayColor: deepInk,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: deepInk,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      shadowColor: const Color(0x14000000),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: const Color(0xFFE5EBF4)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: const Color(0xFFE5EBF4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: primary, width: 1.4),
      ),
      labelStyle: const TextStyle(color: Color(0xFF6C768C), fontWeight: FontWeight.w600),
      floatingLabelStyle: const TextStyle(color: primary, fontWeight: FontWeight.w700),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white.withOpacity(0.92),
      indicatorColor: primary.withOpacity(0.12),
      labelTextStyle: MaterialStateProperty.resolveWith(
        (states) => TextStyle(
          fontWeight: states.contains(MaterialState.selected) ? FontWeight.w800 : FontWeight.w600,
          color: states.contains(MaterialState.selected) ? primary : const Color(0xFF718096),
          fontSize: 12,
        ),
      ),
      iconTheme: MaterialStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(MaterialState.selected) ? primary : const Color(0xFF8C96A8),
          size: 22,
        ),
      ),
    ),
  );
}

class BlueGradient extends LinearGradient {
  const BlueGradient()
      : super(
          colors: const [Color(0xFF4A35E8), Color(0xFF2EC7FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
}
