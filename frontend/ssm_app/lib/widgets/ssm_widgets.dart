import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ══════════════════════════════════════════════════════════
// 1. SSMStatCard — Carte statistique
// ══════════════════════════════════════════════════════════
class SSMStatCard extends StatelessWidget {
  final String titre;
  final String valeur;
  final IconData icone;
  final Color couleurIcone;
  final String? variation;
  final bool variationPositive;

  const SSMStatCard({
    super.key,
    required this.titre,
    required this.valeur,
    required this.icone,
    required this.couleurIcone,
    this.variation,
    this.variationPositive = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: couleurIcone.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icone, color: couleurIcone, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            valeur,
            style: GoogleFonts.sora(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            titre,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF334155),
            ),
          ),
          if (variation != null) ...[
            const SizedBox(height: 8),
            SSMBadge(
              label: variation!,
              couleur: variationPositive ? SSMBadge.succes : SSMBadge.erreur,
            ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 2. SSMBadge — Badge statut pilule
// ══════════════════════════════════════════════════════════
class SSMBadge extends StatelessWidget {
  static const Color succes = Color(0xFF16A34A);
  static const Color erreur = Color(0xFFDC2626);
  static const Color avertissement = Color(0xFFEA580C);
  static const Color info = Color(0xFF0284C7);
  static const Color ambre = Color(0xFFD97706);

  final String label;
  final Color couleur;
  final IconData? icone;

  const SSMBadge({
    super.key,
    required this.label,
    required this.couleur,
    this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[
            Icon(icone, size: 12, color: couleur),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: couleur,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 3. SSMSectionTitre — Titre de section
// ══════════════════════════════════════════════════════════
class SSMSectionTitre extends StatelessWidget {
  final String titre;
  final String? action;
  final VoidCallback? onAction;

  const SSMSectionTitre({
    super.key,
    required this.titre,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            titre,
            style: GoogleFonts.sora(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                action!,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF1E3A8A),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 4. SSMCarteClasse — Carte classe cliquable
// ══════════════════════════════════════════════════════════
class SSMCarteClasse extends StatelessWidget {
  final String nom;
  final int nombreEleves;
  final int capaciteMax;
  final String? professeurPrincipal;
  final VoidCallback onTap;

  const SSMCarteClasse({
    super.key,
    required this.nom,
    required this.nombreEleves,
    required this.capaciteMax,
    this.professeurPrincipal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pourcentage =
        capaciteMax > 0 ? (nombreEleves / capaciteMax).clamp(0.0, 1.0) : 0.0;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: const Border(
              left: BorderSide(color: Color(0xFF1E3A8A), width: 4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nom,
                style: GoogleFonts.sora(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F172A),
                ),
              ),
              if (professeurPrincipal != null) ...[
                const SizedBox(height: 2),
                Text(
                  professeurPrincipal!,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF334155),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pourcentage,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFF1F5F9),
                  color: const Color(0xFF1E3A8A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$nombreEleves / $capaciteMax élèves (${(pourcentage * 100).round()}%)',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Voir les élèves',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFD97706),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 5. SSMActionRapide — Bouton action rapide
// ══════════════════════════════════════════════════════════
class SSMActionRapide extends StatelessWidget {
  final IconData icone;
  final String label;
  final VoidCallback onTap;
  final Color? couleur;

  const SSMActionRapide({
    super.key,
    required this.icone,
    required this.label,
    required this.onTap,
    this.couleur,
  });

  @override
  Widget build(BuildContext context) {
    final couleurIcone = couleur ?? const Color(0xFF1E3A8A);

    return Material(
      color: const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        splashColor: const Color(0xFF1E3A8A).withValues(alpha: 0.15),
        highlightColor: const Color(0xFF1E3A8A).withValues(alpha: 0.08),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icone, size: 28, color: couleurIcone),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 6. SSMListeTile — Ligne de liste stylisée
// ══════════════════════════════════════════════════════════
class SSMListeTile extends StatelessWidget {
  final String titre;
  final String? sousTitre;
  final IconData icone;
  final Color couleurIcone;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? dateHeure;

  const SSMListeTile({
    super.key,
    required this.titre,
    this.sousTitre,
    required this.icone,
    required this.couleurIcone,
    this.trailing,
    this.onTap,
    this.dateHeure,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: const Color(0xFF94A3B8).withValues(alpha: 0.15)),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: couleurIcone.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icone, color: couleurIcone, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titre,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    if (sousTitre != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        sousTitre!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (dateHeure != null) ...[
                const SizedBox(width: 8),
                Text(
                  dateHeure!,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 7. SSMEnteteEcran — Bandeau de bienvenue
// ══════════════════════════════════════════════════════════
class SSMEnteteEcran extends StatelessWidget {
  final String salutation;
  final String sousTitre;
  final String? valeurPrincipale;
  final String? labelValeur;
  final Color couleur;

  const SSMEnteteEcran({
    super.key,
    required this.salutation,
    required this.sousTitre,
    this.valeurPrincipale,
    this.labelValeur,
    this.couleur = const Color(0xFF1E3A8A),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: couleur,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  salutation,
                  style: GoogleFonts.sora(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sousTitre,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          if (valeurPrincipale != null) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    valeurPrincipale!,
                    style: GoogleFonts.sora(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  if (labelValeur != null)
                    Text(
                      labelValeur!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
