import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/ssm_theme.dart';

// ══════════════════════════════════════════════════════════
// SSMPanel — Carte avec en-tête (titre + lien "Voir tout →")
// et corps libre (listes, alertes, tableaux, contenu custom)
// ══════════════════════════════════════════════════════════
class SSMPanel extends StatelessWidget {
  final String titre;
  final Widget child;
  final String? lienAction;
  final VoidCallback? onLienAction;
  final EdgeInsetsGeometry? padding;

  const SSMPanel({
    super.key,
    required this.titre,
    required this.child,
    this.lienAction,
    this.onLienAction,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SSMPalette.blanc,
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        border: Border.all(color: SSMPalette.bordure),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: SSMPalette.bordure)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  titre,
                  style: GoogleFonts.sora(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: SSMPalette.indigo,
                  ),
                ),
                if (lienAction != null)
                  InkWell(
                    onTap: onLienAction,
                    child: Text(
                      lienAction!,
                      style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.teal),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: child,
          ),
        ],
      ),
    );
  }
}
