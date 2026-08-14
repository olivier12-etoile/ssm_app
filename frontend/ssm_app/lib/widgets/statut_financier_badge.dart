import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/caisse_model.dart';

enum TailleBadgeStatut { compact, large }

// Badge réutilisable affichant le statut financier d'un élève
// (🟢 En règle / 🟠 Partiel / 🔴 Non réglé / ⚠ En retard).
// `compact` pour les listes, `large` pour une fiche élève.
class StatutFinancierBadge extends StatelessWidget {
  final StatutFinancier statut;
  final TailleBadgeStatut taille;

  const StatutFinancierBadge({
    super.key,
    required this.statut,
    this.taille = TailleBadgeStatut.compact,
  });

  @override
  Widget build(BuildContext context) {
    final estGrand = taille == TailleBadgeStatut.large;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: estGrand ? 16 : 10,
        vertical: estGrand ? 10 : 4,
      ),
      decoration: BoxDecoration(
        color: statut.couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: statut.couleur.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statut.icone, size: estGrand ? 20 : 14, color: statut.couleur),
          SizedBox(width: estGrand ? 8 : 4),
          Text(
            '${statut.emoji} ${statut.libelle}',
            style: GoogleFonts.inter(
              fontSize: estGrand ? 15 : 12,
              fontWeight: FontWeight.w700,
              color: statut.couleur,
            ),
          ),
        ],
      ),
    );
  }
}
