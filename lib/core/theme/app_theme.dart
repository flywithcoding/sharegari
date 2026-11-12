import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// ShareGari light brand color palette.
abstract final class AppColors {
  // ── Primary greens ──────────────────────────────────────────────────────────
  /// Main green: buttons, app bar accents, selected chips, active icons (#0B7A4B).
  static const primary = Color(0xFF0B7A4B);

  /// Darker green: pressed states, headings (#085C38).
  static const primaryDark = Color(0xFF085C38);

  /// Light green tint: highlights, banners (#E3F4EA).
  static const primaryTint = Color(0xFFE3F4EA);

  /// High contrast pin accent (distinct from green pickup).
  static const secondary = Color(0xFFE65100); // deep contrasting orange

  /// Optional small accent for savings badge, rating stars (#FFB400).
  static const accent = Color(0xFFFFB400);

  // ── Background & Surfaces ───────────────────────────────────────────────────
  /// Scaffold / canvas background: white (#FFFFFF).
  static const background = Color(0xFFFFFFFF);

  /// Cards, input fields, bottom sheets: very light green-grey (#F4F8F5).
  static const surface = Color(0xFFF4F8F5);

  /// Card/input/container thin border (#DDE8E1).
  static const border = Color(0xFFDDE8E1);

  /// Chip unselected / input fill / divider variant (#E8EFEA).
  static const surfaceVariant = Color(0xFFE8EFEA);

  // ── Foreground & Text ───────────────────────────────────────────────────────
  /// White foreground on primary green elements (#FFFFFF).
  static const onPrimary = Color(0xFFFFFFFF);

  /// Dark primary text (#1B1F1D).
  static const onBackground = Color(0xFF1B1F1D);
  static const onSurface = Color(0xFF1B1F1D);

  /// Secondary muted text (#5F6B64).
  static const onSurfaceMuted = Color(0xFF5F6B64);

  // ── Semantic ────────────────────────────────────────────────────────────────
  /// Error text & icon (#D32F2F).
  static const error = Color(0xFFD32F2F);

  /// Error light background tint (#FDE8E8).
  static const errorTint = Color(0xFFFDE8E8);

  /// Success green (#0B7A4B).
  static const success = Color(0xFF0B7A4B);
}

/// Centralised theme for ShareGari — Light Theme (Material 3).
final class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryTint,
        onPrimaryContainer: AppColors.primaryDark,
        secondary: AppColors.secondary,
        onSecondary: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        error: AppColors.error,
        onError: Colors.white,
        errorContainer: AppColors.errorTint,
        onErrorContainer: AppColors.error,
        outline: AppColors.border,
        brightness: Brightness.light,
      ),
      textTheme: GoogleFonts.outfitTextTheme(base.textTheme).copyWith(
        bodyLarge: GoogleFonts.outfit(
            color: AppColors.onBackground, fontSize: 16),
        bodyMedium: GoogleFonts.outfit(
            color: AppColors.onBackground, fontSize: 14),
        bodySmall: GoogleFonts.outfit(
            color: AppColors.onSurfaceMuted, fontSize: 12),
        titleLarge: GoogleFonts.outfit(
            color: AppColors.primaryDark,
            fontSize: 20,
            fontWeight: FontWeight.w700),
        titleMedium: GoogleFonts.outfit(
            color: AppColors.primaryDark,
            fontSize: 16,
            fontWeight: FontWeight.w600),
        headlineSmall: GoogleFonts.outfit(
            color: AppColors.primaryDark,
            fontSize: 24,
            fontWeight: FontWeight.w700),
        headlineMedium: GoogleFonts.outfit(
            color: AppColors.primaryDark,
            fontSize: 28,
            fontWeight: FontWeight.w700),
        displaySmall: GoogleFonts.outfit(
            color: AppColors.primary,
            fontSize: 36,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.0),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primaryDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark, // dark icons on white
          statusBarBrightness: Brightness.light,    // iOS
          systemNavigationBarColor: AppColors.background,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: GoogleFonts.outfit(
          color: AppColors.primaryDark,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: AppColors.primaryDark),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.background,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.onSurfaceMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.surfaceVariant,
          disabledForegroundColor: AppColors.onSurfaceMuted,
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.outfit(
              fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          minimumSize: const Size.fromHeight(52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.outfit(
              fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.outfit(
              fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        hintStyle: GoogleFonts.outfit(
            color: AppColors.onSurfaceMuted, fontSize: 14),
        labelStyle: GoogleFonts.outfit(
            color: AppColors.onSurfaceMuted, fontSize: 14),
        prefixIconColor: AppColors.primary,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 0,
      ),
      iconTheme: const IconThemeData(color: AppColors.onSurface),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 3,
      ),
    );
  }

  /// Kept for backward compatibility or future dark-mode toggle.
  static ThemeData get dark => light;
}
