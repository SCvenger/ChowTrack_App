
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Colores ────────────────────────────────────────────────────────
class AppColors {
  static const Color trustBlue    = Color(0xFF0047AB);
  static const Color esmeraldGreen = Color(0xFF50C878);
  static const Color panicRed     = Color(0xFFDC3545);
  static const Color surface      = Color(0xFFFAF8FF);
  static const Color inputFill    = Color(0xFFF2F2F7);
  static const Color outline      = Color(0xFF737784);
  static const Color black        = Color(0xFF000000);
  static const Color alertAmber  = Color(0xFFFFC107);

  // Tokens auxiliares para superficies/sombras (evita literales Colors.* sueltos)
  static const Color cardSurface  = Color(0xFFFFFFFF);
  static const Color cardShadow   = Color(0x14000000); // black @ 8%
  static const Color disabledFill = Color(0xFFEDEDF2);
  static const Color disabledText = Color(0xFFA0A3AD);

  // Tintes de íconos de categoría (menú de Perfil) — evita hex sueltos por widget
  static const Color tintBlueBg   = Color(0xFFE8F0FB);
  static const Color tintPurple   = Color(0xFF6D51D8);
  static const Color tintPurpleBg = Color(0xFFF0EEFE);
  static const Color tintAmber    = Color(0xFFB45309);
  static const Color tintAmberBg  = Color(0xFFFEF3CD);
  static const Color tintGreenBg  = Color(0xFFE6F4EE);

  /// Variante legible de un color de estado para TEXTO e íconos pequeños.
  /// `esmeraldGreen`, `alertAmber` y `panicRed` no alcanzan 4.5:1 (WCAG AA)
  /// como texto sobre fondos claros/tintados; se oscurecen sin cambiar el tono.
  /// Los fondos, bordes y puntos de estado siguen usando el token original.
  static Color readable(Color status) {
    if (status == trustBlue) return trustBlue; // ya cumple (8.6:1)
    if (status == alertAmber) return tintAmber;
    return Color.lerp(status, black, 0.4)!;
  }
}

// ── Tema principal ─────────────────────────────────────────────────
class AppTheme {

  static const double stackSm      = 12;
  static const double gutter       = 16;
  static const double stackMd      = 24;
  static const double marginMobile = 24;
  static const double stackLg      = 40;
  static const double tapTarget    = 48;

  // Widgets de espaciado reutilizables
  static const SizedBox spacerSm  = SizedBox(height: stackSm);
  static const SizedBox spacer    = SizedBox(height: gutter);
  static const SizedBox spacerMd  = SizedBox(height: stackMd);
  static const SizedBox spacerLg  = SizedBox(height: stackLg);
  static const SizedBox smallSpacer = SizedBox(height: 8);
  static const SizedBox largeSpacer = SizedBox(height: stackMd);

  // ── Escala tipográfica (DESIGN.md typography scale) ──────────────
  static TextStyle get displayLg => GoogleFonts.inter(
    fontSize: 40, 
    fontWeight: FontWeight.w700,
    height: 48 / 40, 
    letterSpacing: -0.02 * 40,
  );

  static TextStyle get headlineLg => GoogleFonts.inter(
    fontSize: 32, 
    fontWeight: FontWeight.w700,
    height: 40 / 32,
  );

  static TextStyle get headlineMd => GoogleFonts.inter(
    fontSize: 24, 
    fontWeight: FontWeight.w600,
    height: 32 / 24,
  );

  static TextStyle get bodyLg => GoogleFonts.inter(
    fontSize: 18, 
    fontWeight: FontWeight.w400,
    height: 28 / 18,
  );

  static TextStyle get bodyMd => GoogleFonts.inter(
    fontSize: 16, 
    fontWeight: FontWeight.w400,
    height: 24 / 16,
  );

  static TextStyle get labelLg => GoogleFonts.inter(
    fontSize: 14, 
    fontWeight: FontWeight.w600,
    height: 20 / 14, 
    letterSpacing: 0.05 * 14,
  );

  static TextStyle get labelSm => GoogleFonts.inter(
    fontSize: 12, 
    fontWeight: FontWeight.w500,
    height: 16 / 12,
  );

  // ── ThemeData ────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      textTheme: GoogleFonts.interTextTheme(), 

      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.trustBlue,
        primary: AppColors.trustBlue,
        surface: AppColors.surface,
        error: AppColors.panicRed,
        brightness: Brightness.light,
      ),

      // ── Botones ─────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.trustBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: labelLg.copyWith(color: Colors.white),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: BorderSide(color: AppColors.outline.withValues(alpha: 0.3)),
          textStyle: labelLg,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.trustBlue,
          textStyle: labelLg,
        ),
      ),

      // ── Inputs ──────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.trustBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.panicRed, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.panicRed, width: 2),
        ),
        labelStyle: labelLg.copyWith(color: AppColors.outline),
        hintStyle: bodyMd.copyWith(color: AppColors.outline.withValues(alpha: 0.6)),
      ),

      // ── AppBar ──────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        titleTextStyle: headlineMd.copyWith(color: AppColors.trustBlue),
        iconTheme: const IconThemeData(color: AppColors.trustBlue),
      ),

      // ── Diálogos ────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cardSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: headlineMd.copyWith(color: AppColors.black),
        contentTextStyle: bodyMd.copyWith(color: AppColors.outline),
      ),

      // ── Bottom sheets ───────────────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.cardSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      // ── Snackbars ───────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF262630),
        contentTextStyle: bodyMd.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),

      // ── Transiciones de pantalla ──────────────────────────────────
      // Slide nativo en vez del "fade+scale" default de Material,
      // se percibe más fluido y consistente entre Android/iOS/desktop.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}