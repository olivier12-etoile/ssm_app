import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/ssm_theme.dart';

enum SSMTendance { hausse, baisse, neutre }

// ══════════════════════════════════════════════════════════
// SSMStatCard — Carte statistique (icône, valeur, label, tendance)
// ══════════════════════════════════════════════════════════
class SSMStatCard extends StatelessWidget {
  final IconData icone;
  final Color couleur;
  final String valeur;
  final String label;
  final String? sousTexte;
  final SSMTendance tendance;

  const SSMStatCard({
    super.key,
    required this.icone,
    required this.couleur,
    required this.valeur,
    required this.label,
    this.sousTexte,
    this.tendance = SSMTendance.neutre,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: SSMPalette.blanc,
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        border: Border.all(color: SSMPalette.bordure),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icone, size: 17, color: couleur),
          ),
          const SizedBox(height: 10),
          Text(
            valeur,
            style: GoogleFonts.sora(fontSize: 25, fontWeight: FontWeight.w700, color: couleur, height: 1),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 11.5, color: SSMPalette.texte2),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (sousTexte != null) ...[
            const SizedBox(height: 5),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (tendance == SSMTendance.neutre)
                  Icon(Icons.circle, size: 6, color: SSMPalette.texte3)
                else
                  Icon(
                    tendance == SSMTendance.hausse ? Icons.trending_up : Icons.trending_down,
                    size: 12,
                    color: _couleurTendance,
                  ),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    sousTexte!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 11, color: _couleurTendance),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color get _couleurTendance {
    switch (tendance) {
      case SSMTendance.hausse:
        return SSMPalette.teal;
      case SSMTendance.baisse:
        return SSMPalette.rouge;
      case SSMTendance.neutre:
        return SSMPalette.texte3;
    }
  }
}
