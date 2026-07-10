import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Couleurs du Brand Book SSM ──────────────────────────────
class SSMCouleurs {
  static const Color principale     = Color(0xFF1E3A8A); // Indigo
  static const Color secondaire     = Color(0xFF0D9488); // Teal
  static const Color accent         = Color(0xFFD97706); // Ambre
  static const Color succes         = Color(0xFF16A34A); // Vert
  static const Color erreur         = Color(0xFFDC2626); // Rouge
  static const Color avertissement  = Color(0xFFEA580C); // Orange
  static const Color textePrincipal  = Color(0xFF0F172A);
  static const Color texteSecondaire = Color(0xFF334155);
  static const Color fondClair       = Color(0xFFF1F5F9);
  static const Color bordure         = Color(0xFF94A3B8);
}

class SSMTheme {
  static ThemeData get themeClaire => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.light(
          primary: SSMCouleurs.principale,
          secondary: SSMCouleurs.secondaire,
          tertiary: SSMCouleurs.accent,
          error: SSMCouleurs.erreur,
          surface: SSMCouleurs.fondClair,
        ),

        // Typographie
        textTheme: TextTheme(
          displayLarge: GoogleFonts.sora(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: SSMCouleurs.textePrincipal),
          displayMedium: GoogleFonts.sora(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: SSMCouleurs.textePrincipal),
          displaySmall: GoogleFonts.sora(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: SSMCouleurs.textePrincipal),
          headlineMedium: GoogleFonts.sora(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: SSMCouleurs.textePrincipal),
          bodyLarge: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: SSMCouleurs.textePrincipal),
          bodyMedium: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: SSMCouleurs.texteSecondaire),
          bodySmall: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: SSMCouleurs.texteSecondaire),
          labelLarge: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
        ),

        // AppBar
        appBarTheme: AppBarTheme(
          backgroundColor: SSMCouleurs.principale,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.sora(
              fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
        ),

        // Boutons primaires
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: SSMCouleurs.principale,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),

        // Boutons outlined
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: SSMCouleurs.principale,
            side: const BorderSide(color: SSMCouleurs.principale, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),

        // Cartes
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: SSMCouleurs.bordure.withValues(alpha: 0.3)),
          ),
          margin: EdgeInsets.zero,
        ),

        // Inputs
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: SSMCouleurs.fondClair,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: SSMCouleurs.bordure),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: SSMCouleurs.bordure),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: SSMCouleurs.principale, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: SSMCouleurs.erreur),
          ),
          labelStyle: GoogleFonts.inter(color: SSMCouleurs.texteSecondaire),
          hintStyle: GoogleFonts.inter(color: SSMCouleurs.bordure),
        ),

        // Drawer (menu latéral)
        drawerTheme: const DrawerThemeData(
          backgroundColor: SSMCouleurs.textePrincipal,
          width: 280,
        ),

        // Divider
        dividerTheme: DividerThemeData(
          color: SSMCouleurs.bordure.withValues(alpha: 0.3),
          thickness: 1,
        ),

        // Scaffold
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),

        // Chip
        chipTheme: const ChipThemeData(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(9999))),
          side: BorderSide.none,
        ),
      );
}
