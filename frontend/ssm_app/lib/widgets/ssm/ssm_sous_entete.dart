import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/ssm_theme.dart';

// ══════════════════════════════════════════════════════════
// SSMSousEnTete — Bandeau plat pour écrans "détail" atteints par
// navigation (push) : bouton retour optionnel, titre, sous-titre,
// complément libre (badge, ligne d'info) et actions à droite.
// Remplace les héros gradient indigo→teal utilisés jusqu'ici sur
// ces écrans, réutilisable par tous les modules.
// ══════════════════════════════════════════════════════════
class SSMSousEnTete extends StatelessWidget {
  final String titre;
  final String? sousTitre;
  final VoidCallback? onRetour;
  final Widget? complement;
  final List<Widget>? actions;

  const SSMSousEnTete({
    super.key,
    required this.titre,
    this.sousTitre,
    this.onRetour,
    this.complement,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: SSMPalette.blanc,
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: SSMPalette.bordure))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onRetour != null)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: SSMPalette.texte2),
              onPressed: onRetour,
            )
          else
            const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: onRetour != null ? 10 : 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titre,
                    style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
                  ),
                  if (sousTitre != null) ...[
                    const SizedBox(height: 2),
                    Text(sousTitre!, style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
                  ],
                  if (complement != null) ...[
                    const SizedBox(height: 4),
                    complement!,
                  ],
                ],
              ),
            ),
          ),
          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}
