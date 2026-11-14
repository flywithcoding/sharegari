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

  /// Light green tint: highlights, banners, active backgrounds (#E3F4EA).
  static const primaryTint = Color(0xFFE3F4EA);

  /// High contrast pin accent (distinct from green pickup).
  static const secondary = Color(0xFFE65100); // deep contrasting orange

  /// Secondary tint for destination accents (#FFF3E0).
  static const secondaryTint = Color(0xFFFFF3E0);

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

  /// Secondary muted text (#5F6B64) — lighter and readable.
  static const onSurfaceMuted = Color(0xFF5F6B64);

  /// Subdued placeholder or icon tint (#8C9A91).
  static const onSurfaceLight = Color(0xFF8C9A91);

  // ── Timeline & Ticket accents ──────────────────────────────────────────────
  /// Connecting track line in timeline (#DDE8E1).
  static const timelineTrack = Color(0xFFDDE8E1);

  /// Inactive/upcoming timeline node (#A4B3AA).
  static const timelinePending = Color(0xFFA4B3AA);

  /// Ticket card perforated dotted line (#CCD9D0).
  static const ticketDotted = Color(0xFFCCD9D0);

  /// Ticket notch color (matches canvas white #FFFFFF).
  static const ticketNotch = Color(0xFFFFFFFF);

  // ── Semantic ────────────────────────────────────────────────────────────────
  /// Error text & icon (#D32F2F).
  static const error = Color(0xFFD32F2F);

  /// Error light background tint (#FDE8E8).
  static const errorTint = Color(0xFFFDE8E8);

  /// Success green (#0B7A4B).
  static const success = Color(0xFF0B7A4B);

  // ── Badge status colors ─────────────────────────────────────────────────────
  static const badgeWarning = Color(0xFFB45309);
  static const badgeWarningTint = Color(0xFFFEF3C7);
  static const badgeWarningBorder = Color(0xFFFCD34D);

  static const badgeInfo = Color(0xFF1E40AF);
  static const badgeInfoTint = Color(0xFFDBEAFE);
  static const badgeInfoBorder = Color(0xFF93C5FD);
}

/// Standardized soft shadows for modern card elevations without hard borders.
abstract final class AppShadows {
  /// Standard card elevation — soft green-tinted shadow for subtle depth.
  static const card = [
    BoxShadow(
      color: Color(0x0C0B7A4B),
      blurRadius: 18,
      offset: Offset(0, 6),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0x06000000),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];

  /// Prominent elevation for hero cards, floating search sheets, and active panels.
  static const elevated = [
    BoxShadow(
      color: Color(0x140B7A4B),
      blurRadius: 24,
      offset: Offset(0, 8),
      spreadRadius: -2,
    ),
    BoxShadow(
      color: Color(0x08000000),
      blurRadius: 8,
      offset: Offset(0, 3),
    ),
  ];

  /// Gentle micro-shadow for chips, badges, and smaller interactive tiles.
  static const soft = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 10,
      offset: Offset(0, 3),
    ),
  ];

  /// Ticket shadow — clean crisp separation with a soft ambient glow.
  static const ticket = [
    BoxShadow(
      color: Color(0x0E0B7A4B),
      blurRadius: 20,
      offset: Offset(0, 6),
    ),
    BoxShadow(
      color: Color(0x05000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];
}

/// Standardized corner radii (16 to 24 px) for modern, friendly touch surfaces.
abstract final class AppRadii {
  /// Standard card radius (20 px).
  static final card = BorderRadius.circular(20);

  /// Large card & hero panel radius (24 px).
  static final cardLarge = BorderRadius.circular(24);

  /// Primary and secondary button radius (16 px).
  static final button = BorderRadius.circular(16);

  /// Input field radius (16 px).
  static final input = BorderRadius.circular(16);

  /// Circular pill radius for chips & badges (100 px).
  static final pill = BorderRadius.circular(100);

  /// Bottom sheet top corners (24 px).
  static const bottomSheet = BorderRadius.vertical(top: Radius.circular(24));

  /// Dialog corners (24 px).
  static final dialog = BorderRadius.circular(24);
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
        displaySmall: GoogleFonts.outfit(
          color: AppColors.primaryDark,
          fontSize: 34,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.0,
        ),
        headlineMedium: GoogleFonts.outfit(
          color: AppColors.primaryDark,
          fontSize: 26,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        headlineSmall: GoogleFonts.outfit(
          color: AppColors.primaryDark,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleLarge: GoogleFonts.outfit(
          color: AppColors.primaryDark,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: GoogleFonts.outfit(
          color: AppColors.onBackground,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: GoogleFonts.outfit(
          color: AppColors.onSurfaceMuted,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: GoogleFonts.outfit(
          color: AppColors.onBackground,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: GoogleFonts.outfit(
          color: AppColors.onBackground,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: GoogleFonts.outfit(
          color: AppColors.onSurfaceMuted,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        labelLarge: GoogleFonts.outfit(
          color: AppColors.primaryDark,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        labelMedium: GoogleFonts.outfit(
          color: AppColors.onSurfaceMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primaryDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: AppColors.background,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: GoogleFonts.outfit(
          color: AppColors.primaryDark,
          fontSize: 19,
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
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.bottomSheet,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.dialog,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.card,
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
          shape: RoundedRectangleBorder(borderRadius: AppRadii.button),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.button),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: AppRadii.input,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.input,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.input,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadii.input,
          borderSide: const BorderSide(color: AppColors.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadii.input,
          borderSide: const BorderSide(color: AppColors.error, width: 1.8),
        ),
        hintStyle: GoogleFonts.outfit(
          color: AppColors.onSurfaceMuted,
          fontSize: 14,
        ),
        labelStyle: GoogleFonts.outfit(
          color: AppColors.onSurfaceMuted,
          fontSize: 14,
        ),
        prefixIconColor: AppColors.primary,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 0,
      ),
      iconTheme: const IconThemeData(color: AppColors.onSurface),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  /// Kept for backward compatibility or future dark-mode toggle.
  static ThemeData get dark => light;
}
