import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/ssm_theme.dart';

enum SSMAlerteType { danger, avertissement, succes }

class _PaletteAlerte {
  final Color fond;
  final Color accent;
  final Color iconeFond;
  const _PaletteAlerte({required this.fond, required this.accent, required this.iconeFond});
}

// ══════════════════════════════════════════════════════════
// SSMAlertItem — Ligne d'alerte (danger/avertissement/succès)
// avec icône colorée, titre, sous-texte, bordure gauche
// ══════════════════════════════════════════════════════════
class SSMAlertItem extends StatelessWidget {
  final SSMAlerteType type;
  final IconData icone;
  final String titre;
  final String sousTitre;

  const SSMAlertItem({
    super.key,
    required this.type,
    required this.icone,
    required this.titre,
    required this.sousTitre,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: palette.fond,
        borderRadius: BorderRadius.circular(SSMRayons.petit + 2),
        border: Border(left: BorderSide(color: palette.accent, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: palette.iconeFond,
              borderRadius: BorderRadius.circular(SSMRayons.petit),
            ),
            child: Icon(icone, size: 14, color: palette.accent),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titre,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: SSMPalette.texte1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sousTitre,
                  style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte3, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _PaletteAlerte get _palette {
    switch (type) {
      case SSMAlerteType.danger:
        return const _PaletteAlerte(
          fond: Color(0xFFFFF5F5),
          accent: SSMPalette.rouge,
          iconeFond: Color(0xFFFEE2E2),
        );
      case SSMAlerteType.avertissement:
        return const _PaletteAlerte(
          fond: SSMPalette.ambreClair,
          accent: SSMPalette.ambre,
          iconeFond: Color(0xFFFEF3C7),
        );
      case SSMAlerteType.succes:
        return const _PaletteAlerte(
          fond: SSMPalette.tealClair,
          accent: SSMPalette.teal,
          iconeFond: Color(0xFFDCFCE7),
        );
    }
  }
}
