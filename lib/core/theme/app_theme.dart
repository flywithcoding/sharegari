import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ShareGari brand colours.
abstract final class AppColors {
  static const primary = Color(0xFF00C6A7); // teal-green
  static const primaryDark = Color(0xFF009E85);
  static const secondary = Color(0xFFFF7043); // deep orange accent
  static const background = Color(0xFF0D1117); // near-black
  static const surface = Color(0xFF161B22); // dark card
  static const surfaceVariant = Color(0xFF21262D);
  static const onPrimary = Color(0xFF000000);
  static const onBackground = Color(0xFFE6EDF3);
  static const onSurface = Color(0xFFE6EDF3);
  static const onSurfaceMuted = Color(0xFF8B949E);
  static const error = Color(0xFFFF5C5C);
}

/// Centralised theme for the entire ShareGari app.
final class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        secondary: AppColors.secondary,
        onSecondary: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        error: AppColors.error,
        brightness: Brightness.dark,
      ),
      textTheme: GoogleFonts.outfitTextTheme(base.textTheme).copyWith(
        bodyLarge: GoogleFonts.outfit(
            color: AppColors.onBackground, fontSize: 16),
        bodyMedium: GoogleFonts.outfit(
            color: AppColors.onBackground, fontSize: 14),
        bodySmall: GoogleFonts.outfit(
            color: AppColors.onSurfaceMuted, fontSize: 12),
        titleLarge: GoogleFonts.outfit(
            color: AppColors.onBackground,
            fontSize: 20,
            fontWeight: FontWeight.w600),
        titleMedium: GoogleFonts.outfit(
            color: AppColors.onBackground,
            fontSize: 16,
            fontWeight: FontWeight.w600),
        headlineSmall: GoogleFonts.outfit(
            color: AppColors.onBackground,
            fontSize: 24,
            fontWeight: FontWeight.w700),
        headlineMedium: GoogleFonts.outfit(
            color: AppColors.onBackground,
            fontSize: 28,
            fontWeight: FontWeight.w700),
        displaySmall: GoogleFonts.outfit(
            color: AppColors.primary,
            fontSize: 36,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.0),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onBackground,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          color: AppColors.onBackground,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.onSurfaceMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.surfaceVariant, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          minimumSize: const Size.fromHeight(52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.outfit(
              fontSize: 16, fontWeight: FontWeight.w700),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          minimumSize: const Size.fromHeight(52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.outfit(
              fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        hintStyle: GoogleFonts.outfit(
            color: AppColors.onSurfaceMuted, fontSize: 14),
        labelStyle: GoogleFonts.outfit(
            color: AppColors.onSurfaceMuted, fontSize: 14),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.surfaceVariant,
        thickness: 1,
        space: 0,
      ),
      iconTheme: const IconThemeData(color: AppColors.onSurface),
    );
  }
}
