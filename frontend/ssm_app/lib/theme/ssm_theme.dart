import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ══════════════════════════════════════════════════════════
// SSMPalette — Design tokens (couleurs) du style flat/clean
// Source : ssm_dashboard_windows.html
// ══════════════════════════════════════════════════════════
class SSMPalette {
  static const Color indigo       = Color(0xFF1E3A8A);
  static const Color indigoClair  = Color(0xFFEEF2FF);
  static const Color teal         = Color(0xFF0D9488);
  static const Color tealClair    = Color(0xFFECFDF5);
  static const Color ambre        = Color(0xFFD97706);
  static const Color ambreClair   = Color(0xFFFFFBEB);
  static const Color rouge        = Color(0xFFEF4444);
  static const Color rougeClair   = Color(0xFFFEF2F2);

  static const Color fond         = Color(0xFFF0F4FF);
  static const Color blanc        = Color(0xFFFFFFFF);
  static const Color bordure      = Color(0xFFF0F0F0);

  static const Color texte1       = Color(0xFF1F2937);
  static const Color texte2       = Color(0xFF6B7280);
  static const Color texte3       = Color(0xFF9CA3AF);
}

// ══════════════════════════════════════════════════════════
// SSMRayons — Rayons de bordure standard
// ══════════════════════════════════════════════════════════
class SSMRayons {
  static const double petit  = 6;
  static const double moyen  = 7;
  static const double grand  = 12;
  static const double pilule = 9999;
}

// ══════════════════════════════════════════════════════════
// SSMOmbres — Ombres subtiles (à réserver aux éléments
// flottants : menus, dialogues. Les cartes du design flat
// n'utilisent qu'une bordure 1px, sans ombre).
// ══════════════════════════════════════════════════════════
class SSMOmbres {
  static const List<BoxShadow> legere = [
    BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 3)),
  ];
}

// ══════════════════════════════════════════════════════════
// SSMTypo — Raccourcis typographiques (Sora / Inter / JetBrains Mono)
// ══════════════════════════════════════════════════════════
class SSMTypo {
  static TextStyle titre({
    double taille = 19,
    FontWeight poids = FontWeight.w700,
    Color couleur = SSMPalette.texte1,
  }) =>
      GoogleFonts.sora(fontSize: taille, fontWeight: poids, color: couleur);

  static TextStyle corps({
    double taille = 13,
    FontWeight poids = FontWeight.w400,
    Color couleur = SSMPalette.texte1,
  }) =>
      GoogleFonts.inter(fontSize: taille, fontWeight: poids, color: couleur);

  static TextStyle mono({
    double taille = 11,
    FontWeight poids = FontWeight.w400,
    Color couleur = SSMPalette.texte2,
  }) =>
      GoogleFonts.jetBrainsMono(fontSize: taille, fontWeight: poids, color: couleur);
}

// ══════════════════════════════════════════════════════════
// SSMTheme — ThemeData flat/clean (remplace l'ancien thème
// glassmorphism de config/theme_config.dart). Aucun flou,
// aucune transparence de fond : bordures fines 1px + ombres
// très légères réservées aux éléments flottants.
// ══════════════════════════════════════════════════════════
class SSMTheme {
  static ThemeData get clair => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: SSMPalette.fond,
        colorScheme: const ColorScheme.light(
          primary: SSMPalette.indigo,
          secondary: SSMPalette.teal,
          tertiary: SSMPalette.ambre,
          error: SSMPalette.rouge,
          surface: SSMPalette.blanc,
        ),

        textTheme: TextTheme(
          displayLarge: GoogleFonts.sora(
              fontSize: 32, fontWeight: FontWeight.w800, color: SSMPalette.texte1),
          displayMedium: GoogleFonts.sora(
              fontSize: 25, fontWeight: FontWeight.w700, color: SSMPalette.texte1),
          displaySmall: GoogleFonts.sora(
              fontSize: 19, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
          headlineMedium: GoogleFonts.sora(
              fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
          titleMedium: GoogleFonts.sora(
              fontSize: 12.5, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
          bodyLarge: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w400, color: SSMPalette.texte1),
          bodyMedium: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w400, color: SSMPalette.texte1),
          bodySmall: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w400, color: SSMPalette.texte2),
          labelLarge: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
        ),

        appBarTheme: AppBarTheme(
          backgroundColor: SSMPalette.blanc,
          foregroundColor: SSMPalette.texte1,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          iconTheme: const IconThemeData(color: SSMPalette.texte2),
          titleTextStyle: GoogleFonts.sora(
              fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: SSMPalette.indigo,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(SSMRayons.moyen)),
            textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),

        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: SSMPalette.indigo,
            side: const BorderSide(color: SSMPalette.indigo, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(SSMRayons.moyen)),
          ),
        ),

        cardTheme: CardThemeData(
          elevation: 0,
          color: SSMPalette.blanc,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SSMRayons.grand),
            side: const BorderSide(color: SSMPalette.bordure),
          ),
          margin: EdgeInsets.zero,
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF9FAFB),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SSMRayons.moyen),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SSMRayons.moyen),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SSMRayons.moyen),
            borderSide: const BorderSide(color: SSMPalette.indigo, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SSMRayons.moyen),
            borderSide: const BorderSide(color: SSMPalette.rouge),
          ),
          labelStyle: GoogleFonts.inter(color: SSMPalette.texte2),
          hintStyle: GoogleFonts.inter(color: SSMPalette.texte3),
        ),

        drawerTheme: const DrawerThemeData(
          backgroundColor: SSMPalette.indigo,
          width: 224,
        ),

        dividerTheme: const DividerThemeData(
          color: SSMPalette.bordure,
          thickness: 1,
        ),

        chipTheme: const ChipThemeData(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(SSMRayons.pilule))),
          side: BorderSide.none,
        ),
      );
}
