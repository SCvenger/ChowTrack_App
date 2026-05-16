import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// --- 1. PALETA DE COLORES ---
// Aquí guardamos los colores exactos de tu diseño.
class AppColors {
  static const Color trustBlue = Color(0xFF0047AB); // Tu color de autoridad
  static const Color emeraldGreen = Color(0xFF50C878); // Para estados seguros
  static const Color panicRed = Color(0xFFDC3545); // EXCLUSIVO para emergencias
  static const Color surface = Color(0xFFFAF8FF); // Fondo principal
  static const Color outline = Color(0xFF737784); // Bordes de inputs
  static const Color black = Color(0xFF000000);
}

// --- 2. CONFIGURACIÓN DEL TEMA  ---
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      // Aplicamos Metropolis de Google Fonts a toda la App
      textTheme: GoogleFonts.metrophobicTextTheme(),

      // Esquema de colores base para los widgets internos
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.trustBlue,
        primary: AppColors.trustBlue,
        surface: AppColors.surface,
        error: AppColors.panicRed,
      ),

      // BOTONES: Aquí definimos sus especificaciones
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.trustBlue,
          foregroundColor: Colors.white,
          // Altura fija de 56px para "alta visibilidad"
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      // INPUTS: Cómo se ven los campos donde el usuario escribe
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey[180],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.trustBlue, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.panicRed, width: 2),
        ),
      ),
    );
  }

  static const SizedBox spacer = SizedBox(height: 16);
}
