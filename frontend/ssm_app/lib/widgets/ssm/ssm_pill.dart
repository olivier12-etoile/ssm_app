import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/ssm_theme.dart';

enum SSMPillType { paye, partiel, retard, personnalise }

class _CouleursPill {
  final Color fond;
  final Color texte;
  const _CouleursPill(this.fond, this.texte);
}

// ══════════════════════════════════════════════════════════
// SSMPill — Badge pilule de statut (paid/partial/late + variante
// libre par couleur)
// ══════════════════════════════════════════════════════════
class SSMPill extends StatelessWidget {
  final String label;
  final SSMPillType type;
  final Color? couleur;

  const SSMPill({super.key, required this.label, this.type = SSMPillType.personnalise, this.couleur});

  const SSMPill.paye({super.key, required this.label})
      : type = SSMPillType.paye,
        couleur = null;

  const SSMPill.partiel({super.key, required this.label})
      : type = SSMPillType.partiel,
        couleur = null;

  const SSMPill.retard({super.key, required this.label})
      : type = SSMPillType.retard,
        couleur = null;

  const SSMPill.couleur({super.key, required this.label, required Color this.couleur})
      : type = SSMPillType.personnalise;

  @override
  Widget build(BuildContext context) {
    final c = _couleurs;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        color: c.fond,
        borderRadius: BorderRadius.circular(SSMRayons.petit + 6),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: c.texte),
      ),
    );
  }

  _CouleursPill get _couleurs {
    switch (type) {
      case SSMPillType.paye:
        return const _CouleursPill(SSMPalette.tealClair, SSMPalette.teal);
      case SSMPillType.partiel:
        return const _CouleursPill(SSMPalette.ambreClair, SSMPalette.ambre);
      case SSMPillType.retard:
        return const _CouleursPill(SSMPalette.rougeClair, SSMPalette.rouge);
      case SSMPillType.personnalise:
        final base = couleur ?? SSMPalette.texte2;
        return _CouleursPill(base.withValues(alpha: 0.12), base);
    }
  }
}
