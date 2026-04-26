import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ParkingColors {
  static const scaffold = Color(0xFF081429);
  static const surface = Color(0xFF0D1832);
  static const surfaceMuted = Color(0xFF111E3C);
  static const ink = Color(0xFFF7FAFF);
  static const inkSoft = Color(0xFF90A0C0);
  static const primary = Color(0xFF2563EB);
  static const primaryDeep = Color(0xFF7C3AED);
  static const accent = Color(0xFF4F7DFB);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient entryHeaderGradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF3B82F6), Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient blueCardGradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF4F7DFB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient purpleCardGradient = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient navyCardGradient = LinearGradient(
    colors: [Color(0xFF0A152A), Color(0xFF10264D)],
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

  final baseTextTheme =
      GoogleFonts.manropeTextTheme(ThemeData.dark().textTheme);

  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: accent,
      surface: ParkingColors.surface,
      surfaceContainerHighest: surface,
      onSurface: deepInk,
      brightness: Brightness.dark,
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
      fillColor: const Color(0xFF0F1B35),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: const Color(0xFF243559)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: const Color(0xFF243559)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: primary, width: 1.4),
      ),
      hintStyle: const TextStyle(
        color: Color(0xFF7E8CAD),
        fontWeight: FontWeight.w500,
      ),
      labelStyle: const TextStyle(
          color: Color(0xFF93A1C4), fontWeight: FontWeight.w600),
      floatingLabelStyle:
          const TextStyle(color: primary, fontWeight: FontWeight.w700),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF0C1731).withOpacity(0.96),
      indicatorColor: primary.withOpacity(0.18),
      labelTextStyle: MaterialStateProperty.resolveWith(
        (states) => TextStyle(
          fontWeight: states.contains(MaterialState.selected)
              ? FontWeight.w800
              : FontWeight.w600,
          color: states.contains(MaterialState.selected)
              ? primary
              : const Color(0xFF8A97B7),
          fontSize: 12,
        ),
      ),
      iconTheme: MaterialStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(MaterialState.selected)
              ? primary
              : const Color(0xFF8C96A8),
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
