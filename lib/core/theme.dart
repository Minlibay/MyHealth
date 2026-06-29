import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Дизайн-система приложения: Material 3, единый язык для iOS и Android.
class AppTheme {
  AppTheme._();

  static const _seed = Color(0xFF4F6DF5);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: brightness == Brightness.light
          ? const Color(0xFFF6F7FB)
          : const Color(0xFF0E1014),
    );

    final textTheme = GoogleFonts.manropeTextTheme(base.textTheme).copyWith(
      headlineLarge: GoogleFonts.manrope(
          fontWeight: FontWeight.w800, letterSpacing: -0.5),
      headlineMedium: GoogleFonts.manrope(
          fontWeight: FontWeight.w800, letterSpacing: -0.5),
      headlineSmall: GoogleFonts.manrope(
          fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleLarge:
          GoogleFonts.manrope(fontWeight: FontWeight.w700, letterSpacing: -0.2),
      titleMedium: GoogleFonts.manrope(fontWeight: FontWeight.w600),
      titleSmall: GoogleFonts.manrope(fontWeight: FontWeight.w600),
    );

    return base.copyWith(
      textTheme: textTheme,
      cardTheme: CardThemeData(
        elevation: 0,
        color: brightness == Brightness.light
            ? Colors.white
            : const Color(0xFF181B22),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontSize: 22),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 54),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: GoogleFonts.manrope(
              fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18))),
      ),
    );
  }
}
