import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ParkingColors {
  static const scaffold = Color(0xFFF4F7FC);
  static const surface = Colors.white;
  static const surfaceMuted = Color(0xFFF7F8FF);
  static const ink = Color(0xFF111A4D);
  static const inkSoft = Color(0xFF69708F);
  static const primary = Color(0xFF2A63F5);
  static const primaryDeep = Color(0xFF6D3EF7);
  static const accent = Color(0xFF3E86FF);
  static const success = Color(0xFF17B26A);
  static const warning = Color(0xFFF2994A);
  static const danger = Color(0xFFF04444);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF2A63F5), Color(0xFF6D3EF7)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient entryHeaderGradient = LinearGradient(
    colors: [Color(0xFF245CF5), Color(0xFF3362F4), Color(0xFF5F42F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient blueCardGradient = LinearGradient(
    colors: [Color(0xFF245CF5), Color(0xFF3D7BFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient purpleCardGradient = LinearGradient(
    colors: [Color(0xFF9B5BFF), Color(0xFF6A3EF4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient navyCardGradient = LinearGradient(
    colors: [Color(0xFF0A1E63), Color(0xFF102D8A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

ThemeData parkingTheme() {
  const primary = ParkingColors.primary;
  const accent = ParkingColors.primaryDeep;
  const deepInk = ParkingColors.ink;
  const bg = ParkingColors.scaffold;
  const surface = ParkingColors.surfaceMuted;

  final baseTextTheme = GoogleFonts.manropeTextTheme();

  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: accent,
      surface: ParkingColors.surface,
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
      fillColor: ParkingColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: const Color(0xFFE3E8F5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: const Color(0xFFE3E8F5)),
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
