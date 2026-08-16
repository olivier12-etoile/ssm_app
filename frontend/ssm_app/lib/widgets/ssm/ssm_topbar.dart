import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/ssm_theme.dart';

// ══════════════════════════════════════════════════════════
// SSMPeriodePill — Pastille "2024–2025 · Trimestre 1 · EN COURS"
// ══════════════════════════════════════════════════════════
class SSMPeriodePill extends StatelessWidget {
  final String texte;
  final String? badge;

  const SSMPeriodePill({super.key, required this.texte, this.badge});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: SSMPalette.indigoClair,
        borderRadius: BorderRadius.circular(SSMRayons.petit),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_today_outlined, size: 12, color: SSMPalette.indigo),
          const SizedBox(width: 5),
          Text(
            texte,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: SSMPalette.indigo,
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: SSMPalette.ambre,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                badge!,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// SSMTopbar — Barre supérieure 50px : breadcrumb, pill période,
// recherche, notifications, avatar. Bouton menu (hamburger)
// optionnel pour ouvrir le Drawer en mobile.
// ══════════════════════════════════════════════════════════
class SSMTopbar extends StatelessWidget implements PreferredSizeWidget {
  final String breadcrumb;
  final String? breadcrumbActuel;
  final Widget? periodePill;
  final String rechercheHint;
  final ValueChanged<String>? onRechercheChanged;
  final VoidCallback? onNotificationTap;
  final bool hasNotification;
  final String initialesUtilisateur;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onMenuTap;
  final List<Widget>? actions;

  const SSMTopbar({
    super.key,
    required this.breadcrumb,
    this.breadcrumbActuel,
    this.periodePill,
    this.rechercheHint = 'Rechercher…',
    this.onRechercheChanged,
    this.onNotificationTap,
    this.hasNotification = false,
    this.initialesUtilisateur = '',
    this.onAvatarTap,
    this.onMenuTap,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(50);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, contraintes) {
      final estEtroit = contraintes.maxWidth < 640;

      return Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: const BoxDecoration(
          color: SSMPalette.blanc,
          border: Border(bottom: BorderSide(color: SSMPalette.bordure)),
        ),
        child: Row(
          children: [
            if (onMenuTap != null) ...[
              InkWell(
                onTap: onMenuTap,
                borderRadius: BorderRadius.circular(SSMRayons.petit),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.menu, size: 20, color: SSMPalette.texte2),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Row(
                children: [
                  if (!estEtroit) Flexible(child: _breadcrumbTexte()),
                  if (!estEtroit && periodePill != null) ...[
                    const SizedBox(width: 14),
                    periodePill!,
                  ],
                ],
              ),
            ),
            if (!estEtroit && onRechercheChanged != null) ...[
              _recherche(),
              const SizedBox(width: 12),
            ],
            if (actions != null) ...[
              ...actions!,
              const SizedBox(width: 12),
            ],
            GestureDetector(
              onTap: onNotificationTap,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_outlined, size: 19, color: SSMPalette.texte2),
                  if (hasNotification)
                    Positioned(
                      top: -1,
                      right: -1,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: SSMPalette.ambre,
                          shape: BoxShape.circle,
                          border: Border.all(color: SSMPalette.blanc, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: onAvatarTap,
              child: CircleAvatar(
                radius: 15,
                backgroundColor: SSMPalette.teal,
                child: Text(
                  initialesUtilisateur,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _breadcrumbTexte() {
    return Text(
      breadcrumbActuel ?? breadcrumb,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: SSMPalette.texte1,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _recherche() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(SSMRayons.moyen),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search, size: 14, color: SSMPalette.texte3),
          const SizedBox(width: 7),
          SizedBox(
            width: 190,
            child: TextField(
              onChanged: onRechercheChanged,
              style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: rechercheHint,
                hintStyle: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
