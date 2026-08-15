import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/caisse_model.dart';
import '../../theme/ssm_theme.dart';

enum SSMTailleBadge { compact, large }

// Couleur "en retard" — 4ème état du statut financier, plus sévère que
// "non réglé". Ne fait pas partie de SSMPalette (aucun token rouge foncé
// dédié) mais reprend la valeur déjà utilisée pour ce même état ailleurs
// dans le code (StatutFinancier.enRetard, situation_par_classe_screen.dart).
const Color _rougeFonce = Color(0xFF991B1B);

Color _couleurStatutFinancier(StatutFinancier statut) {
  switch (statut) {
    case StatutFinancier.enRegle:
      return SSMPalette.teal;
    case StatutFinancier.partiel:
      return SSMPalette.ambre;
    case StatutFinancier.nonRegle:
      return SSMPalette.rouge;
    case StatutFinancier.enRetard:
      return _rougeFonce;
  }
}

// ══════════════════════════════════════════════════════════
// SSMStatutFinancierBadge — Badge de statut financier élève,
// palette unique et cohérente à travers tout le module Paiements /
// Frais scolaires : en_regle=teal, partiel=ambre, non_regle=rouge,
// en_retard=rouge foncé.
// ══════════════════════════════════════════════════════════
class SSMStatutFinancierBadge extends StatelessWidget {
  final StatutFinancier statut;
  final SSMTailleBadge taille;

  const SSMStatutFinancierBadge({
    super.key,
    required this.statut,
    this.taille = SSMTailleBadge.compact,
  });

  @override
  Widget build(BuildContext context) {
    final estGrand = taille == SSMTailleBadge.large;
    final couleur = _couleurStatutFinancier(statut);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: estGrand ? 16 : 10, vertical: estGrand ? 10 : 4),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(SSMRayons.pilule),
        border: Border.all(color: couleur.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statut.icone, size: estGrand ? 20 : 14, color: couleur),
          SizedBox(width: estGrand ? 8 : 4),
          Text(
            statut.libelle,
            style: GoogleFonts.inter(fontSize: estGrand ? 15 : 12, fontWeight: FontWeight.w700, color: couleur),
          ),
        ],
      ),
    );
  }
}
