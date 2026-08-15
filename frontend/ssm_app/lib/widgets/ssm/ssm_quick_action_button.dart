import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/ssm_theme.dart';

enum SSMActionVariante { primaire, teal, ambre, gris }

class _PaletteAction {
  final Color fond;
  final Color texte;
  final Color? bordure;
  const _PaletteAction({required this.fond, required this.texte, this.bordure});
}

// ══════════════════════════════════════════════════════════
// SSMQuickActionButton — Bouton d'action rapide (icône + texte)
// ══════════════════════════════════════════════════════════
class SSMQuickActionButton extends StatelessWidget {
  final IconData icone;
  final String label;
  final VoidCallback? onTap;
  final SSMActionVariante variante;

  const SSMQuickActionButton({
    super.key,
    required this.icone,
    required this.label,
    this.onTap,
    this.variante = SSMActionVariante.gris,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _palette;

    return Material(
      color: palette.fond,
      borderRadius: BorderRadius.circular(SSMRayons.moyen),
      child: InkWell(
        borderRadius: BorderRadius.circular(SSMRayons.moyen),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SSMRayons.moyen),
            border: palette.bordure != null ? Border.all(color: palette.bordure!) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icone, size: 14, color: palette.texte),
              const SizedBox(width: 7),
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: palette.texte),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _PaletteAction get _palette {
    switch (variante) {
      case SSMActionVariante.primaire:
        return const _PaletteAction(fond: SSMPalette.indigo, texte: Colors.white);
      case SSMActionVariante.teal:
        return const _PaletteAction(
          fond: SSMPalette.tealClair,
          texte: SSMPalette.teal,
          bordure: Color(0xFFD1FAE5),
        );
      case SSMActionVariante.ambre:
        return const _PaletteAction(
          fond: SSMPalette.ambreClair,
          texte: SSMPalette.ambre,
          bordure: Color(0xFFFDE68A),
        );
      case SSMActionVariante.gris:
        return const _PaletteAction(
          fond: Color(0xFFF9FAFB),
          texte: SSMPalette.texte2,
          bordure: Color(0xFFF3F4F6),
        );
    }
  }
}
