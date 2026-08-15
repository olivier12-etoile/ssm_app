import 'package:flutter/material.dart';
import '../../theme/ssm_theme.dart';
import 'ssm_sidebar.dart';
import 'ssm_topbar.dart';

// ══════════════════════════════════════════════════════════
// SSMPageScaffold — Squelette réutilisable (sidebar + topbar +
// zone de contenu scrollable) que tous les écrans de modules
// utiliseront désormais au lieu de leur Scaffold actuel.
//
// Responsive :
//  - largeur >= 900px : sidebar fixe visible
//  - largeur <  900px : sidebar en Drawer, topbar avec hamburger
// ══════════════════════════════════════════════════════════
class SSMPageScaffold extends StatelessWidget {
  static const double seuilDesktop = 900;

  // Identité école / utilisateur (sidebar)
  final String nomEcole;
  final String codeEcole;
  final String nomUtilisateur;
  final String role;

  // Navigation
  final List<SSMNavSection> sections;
  final String routeActuelle;
  final ValueChanged<String> onNavigate;
  final VoidCallback? onProfilTap;

  // Barre supérieure
  final String breadcrumb;
  final String? breadcrumbActuel;
  final Widget? periodePill;
  final ValueChanged<String>? onRechercheChanged;
  final VoidCallback? onNotificationTap;
  final bool hasNotification;
  final List<Widget>? actionsTopBar;

  // Contenu
  final Widget child;
  final EdgeInsetsGeometry contentPadding;
  final Widget? floatingActionButton;

  const SSMPageScaffold({
    super.key,
    required this.nomEcole,
    required this.codeEcole,
    required this.nomUtilisateur,
    required this.role,
    required this.sections,
    required this.routeActuelle,
    required this.onNavigate,
    required this.breadcrumb,
    required this.child,
    this.onProfilTap,
    this.breadcrumbActuel,
    this.periodePill,
    this.onRechercheChanged,
    this.onNotificationTap,
    this.hasNotification = false,
    this.actionsTopBar,
    this.contentPadding = const EdgeInsets.fromLTRB(24, 22, 24, 28),
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    final estDesktop = MediaQuery.of(context).size.width >= seuilDesktop;

    final contenu = Container(
      width: double.infinity,
      color: SSMPalette.fond,
      child: SingleChildScrollView(padding: contentPadding, child: child),
    );

    if (estDesktop) {
      return Scaffold(
        backgroundColor: SSMPalette.fond,
        floatingActionButton: floatingActionButton,
        body: Row(
          children: [
            SSMSidebar(
              nomEcole: nomEcole,
              codeEcole: codeEcole,
              nomUtilisateur: nomUtilisateur,
              role: role,
              sections: sections,
              routeActuelle: routeActuelle,
              onNavigate: onNavigate,
              onProfilTap: onProfilTap,
            ),
            Expanded(
              child: Column(
                children: [
                  SSMTopbar(
                    breadcrumb: breadcrumb,
                    breadcrumbActuel: breadcrumbActuel,
                    periodePill: periodePill,
                    onRechercheChanged: onRechercheChanged,
                    onNotificationTap: onNotificationTap,
                    hasNotification: hasNotification,
                    initialesUtilisateur: _initiales(nomUtilisateur),
                    onAvatarTap: onProfilTap,
                    actions: actionsTopBar,
                  ),
                  Expanded(child: contenu),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: SSMPalette.fond,
      floatingActionButton: floatingActionButton,
      drawer: Drawer(
        backgroundColor: SSMPalette.indigo,
        width: 224,
        child: SafeArea(
          child: SSMSidebar(
            nomEcole: nomEcole,
            codeEcole: codeEcole,
            nomUtilisateur: nomUtilisateur,
            role: role,
            sections: sections,
            routeActuelle: routeActuelle,
            onNavigate: (route) {
              Navigator.of(context).pop();
              onNavigate(route);
            },
            onProfilTap: onProfilTap,
          ),
        ),
      ),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50),
        child: Builder(
          builder: (contexteAppBar) => SSMTopbar(
            breadcrumb: breadcrumb,
            breadcrumbActuel: breadcrumbActuel,
            periodePill: periodePill,
            onRechercheChanged: onRechercheChanged,
            onNotificationTap: onNotificationTap,
            hasNotification: hasNotification,
            initialesUtilisateur: _initiales(nomUtilisateur),
            onAvatarTap: onProfilTap,
            actions: actionsTopBar,
            onMenuTap: () => Scaffold.of(contexteAppBar).openDrawer(),
          ),
        ),
      ),
      body: contenu,
    );
  }

  String _initiales(String nom) {
    final parties = nom.trim().split(RegExp(r'\s+'));
    if (parties.isEmpty || parties.first.isEmpty) return '?';
    if (parties.length == 1) return parties.first.substring(0, 1).toUpperCase();
    return (parties.first.substring(0, 1) + parties.last.substring(0, 1)).toUpperCase();
  }
}
