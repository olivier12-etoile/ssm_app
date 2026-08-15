import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/ssm_theme.dart';

// ══════════════════════════════════════════════════════════
// Modèle de navigation — alimente SSMSidebar et SSMPageScaffold
// ══════════════════════════════════════════════════════════
class SSMNavItem {
  final IconData icone;
  final String label;
  final String route;
  final int? badge;
  final Color? couleurBadge;

  const SSMNavItem({
    required this.icone,
    required this.label,
    required this.route,
    this.badge,
    this.couleurBadge,
  });
}

class SSMNavSection {
  final String? titre;
  final List<SSMNavItem> items;

  const SSMNavSection({this.titre, required this.items});
}

// ══════════════════════════════════════════════════════════
// SSMSidebar — Menu latéral indigo (224px), utilisé fixe en
// desktop ou glissé dans un Drawer en mobile via SSMPageScaffold
// ══════════════════════════════════════════════════════════
class SSMSidebar extends StatelessWidget {
  final String nomEcole;
  final String codeEcole;
  final String nomUtilisateur;
  final String role;
  final List<SSMNavSection> sections;
  final String? routeActuelle;
  final ValueChanged<String> onNavigate;
  final VoidCallback? onProfilTap;

  const SSMSidebar({
    super.key,
    required this.nomEcole,
    required this.codeEcole,
    required this.nomUtilisateur,
    required this.role,
    required this.sections,
    required this.onNavigate,
    this.routeActuelle,
    this.onProfilTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 224,
      color: SSMPalette.indigo,
      child: Column(
        children: [
          _entete(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              children: [
                for (final section in sections) ...[
                  if (section.titre != null) _etiquetteSection(section.titre!),
                  for (final item in section.items) _itemNav(item),
                ],
              ],
            ),
          ),
          _pied(),
        ],
      ),
    );
  }

  Widget _entete() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.07))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _logoMark(),
              const SizedBox(width: 9),
              Text(
                'SSM',
                style: GoogleFonts.sora(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            nomEcole,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.92),
              height: 1.25,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'CODE  $codeEcole',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.35),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoMark() {
    Widget carre(Color couleur) => Container(
          width: 10.5,
          height: 10.5,
          decoration: BoxDecoration(color: couleur, borderRadius: BorderRadius.circular(3)),
        );

    return SizedBox(
      width: 24,
      height: 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            carre(SSMPalette.teal),
            const SizedBox(width: 3),
            carre(Colors.white.withValues(alpha: 0.82)),
          ]),
          const SizedBox(height: 3),
          Row(mainAxisSize: MainAxisSize.min, children: [
            carre(Colors.white.withValues(alpha: 0.82)),
            const SizedBox(width: 3),
            carre(SSMPalette.ambre),
          ]),
        ],
      ),
    );
  }

  Widget _etiquetteSection(String titre) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      child: Text(
        titre.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.4,
          color: Colors.white.withValues(alpha: 0.28),
        ),
      ),
    );
  }

  Widget _itemNav(SSMNavItem item) {
    final actif = item.route == routeActuelle;

    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: Material(
        color: actif ? Colors.white.withValues(alpha: 0.11) : Colors.transparent,
        borderRadius: BorderRadius.circular(SSMRayons.moyen),
        child: InkWell(
          borderRadius: BorderRadius.circular(SSMRayons.moyen),
          hoverColor: Colors.white.withValues(alpha: 0.07),
          onTap: () => onNavigate(item.route),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SSMRayons.moyen),
              border: Border(
                left: BorderSide(
                  color: actif ? SSMPalette.teal : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  item.icone,
                  size: 16,
                  color: actif ? Colors.white : Colors.white.withValues(alpha: 0.58),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    item.label,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: actif ? FontWeight.w500 : FontWeight.w400,
                      color: actif ? Colors.white : Colors.white.withValues(alpha: 0.58),
                    ),
                  ),
                ),
                if (item.badge != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: item.couleurBadge ?? SSMPalette.ambre,
                      borderRadius: BorderRadius.circular(SSMRayons.pilule),
                    ),
                    child: Text(
                      '${item.badge}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pied() {
    final initiales = _initiales(nomUtilisateur);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.07))),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onProfilTap,
          borderRadius: BorderRadius.circular(SSMRayons.petit),
          child: Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: SSMPalette.teal,
                child: Text(
                  initiales,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      nomUtilisateur,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      role,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.38),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _initiales(String nom) {
    final parties = nom.trim().split(RegExp(r'\s+'));
    if (parties.isEmpty || parties.first.isEmpty) return '?';
    if (parties.length == 1) return parties.first.substring(0, 1).toUpperCase();
    return (parties.first.substring(0, 1) + parties.last.substring(0, 1)).toUpperCase();
  }
}
