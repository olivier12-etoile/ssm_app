import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/utilisateur.dart';
import '../../services/auth_service.dart';

class _SansScrollbarBehavior extends ScrollBehavior {
  const _SansScrollbarBehavior();

  @override
  Widget buildScrollbar(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

class MenuLateral extends StatelessWidget {
  final Utilisateur utilisateur;

  const MenuLateral({super.key, required this.utilisateur});

  @override
  Widget build(BuildContext context) {
    final routeActuelle = ModalRoute.of(context)?.settings.name;

    return Drawer(
      backgroundColor: const Color(0xFF0F172A),
      child: Column(
        children: [
          _enTete(),

          // ── Menu ─────────────────────────────────────────
          Expanded(
            child: ScrollConfiguration(
              behavior: const _SansScrollbarBehavior(),
              child: ListView(
                padding: const EdgeInsets.only(top: 8),
                children: [
                  // Tableau de bord — tout le monde
                  _menuItem(context,
                    icone: Icons.dashboard,
                    titre: 'Tableau de bord',
                    route: '/tableau-de-bord',
                    routeActuelle: routeActuelle,
                  ),

                  // ── Directeur uniquement ──────────────────
                  if (utilisateur.estDirecteur) ...[
                    _separateur('Administration'),
                    _menuItem(context,
                      icone: Icons.people,
                      titre: 'Utilisateurs',
                      route: '/directeur/utilisateurs',
                      routeActuelle: routeActuelle,
                    ),
                    _menuItem(context,
                      icone: Icons.class_,
                      titre: 'Classes',
                      route: '/directeur/classes',
                      routeActuelle: routeActuelle,
                    ),
                    _menuItem(context,
                      icone: Icons.library_books_outlined,
                      titre: 'Catalogue des matières',
                      route: '/directeur/catalogue-matieres',
                      routeActuelle: routeActuelle,
                    ),
                    _menuItem(context,
                      icone: Icons.calendar_month,
                      titre: 'Années & Périodes',
                      route: '/directeur/annees',
                      routeActuelle: routeActuelle,
                    ),
                    _menuItem(context,
                      icone: Icons.people_outline,
                      titre: 'Élèves',
                      route: '/directeur/eleves',
                      routeActuelle: routeActuelle,
                    ),
                    _menuItem(context,
                      icone: Icons.price_change,
                      titre: 'Frais scolaires',
                      route: '/directeur/frais',
                      routeActuelle: routeActuelle,
                    ),
                    _menuItem(context,
                      icone: Icons.bar_chart,
                      titre: 'Statistiques',
                      route: '/statistiques',
                      routeActuelle: routeActuelle,
                    ),
                  ],

                  // ── Censeur uniquement ─────────────────────
                  if (utilisateur.estCenseur) ...[
                    _separateur('Classes'),
                    _menuItem(context,
                      icone: Icons.class_,
                      titre: 'Mes classes',
                      route: '/dashboard/censeur',
                      routeActuelle: routeActuelle,
                    ),
                  ],

                  // ── Directeur + Censeur ───────────────────
                  if (utilisateur.estDirecteur || utilisateur.estCenseur) ...[
                    _separateur('Pédagogie'),
                    _menuItem(context,
                      icone: Icons.edit_note,
                      titre: 'Saisie des notes',
                      route: '/enseignant/notes',
                      routeActuelle: routeActuelle,
                    ),
                    _menuItem(context,
                      icone: Icons.grade,
                      titre: 'Validation des notes',
                      route: '/notes/validation',
                      routeActuelle: routeActuelle,
                    ),
                    _menuItem(context,
                      icone: Icons.description,
                      titre: 'Bulletins',
                      route: '/bulletins',
                      routeActuelle: routeActuelle,
                    ),
                    _menuItem(context,
                      icone: Icons.event_busy,
                      titre: 'Saisie des absences',
                      route: '/enseignant/absences',
                      routeActuelle: routeActuelle,
                    ),
                    _menuItem(context,
                      icone: Icons.calendar_view_week,
                      titre: 'Emplois du temps',
                      route: '/emploi-du-temps',
                      routeActuelle: routeActuelle,
                    ),
                  ],

                  // ── Directeur + Secrétaire ────────────────
                  if (utilisateur.estDirecteur || utilisateur.estSecretaire) ...[
                    _separateur('Finances'),
                    _menuItem(context,
                      icone: Icons.payment,
                      titre: 'Paiements',
                      route: '/paiements',
                      routeActuelle: routeActuelle,
                    ),
                    _menuItem(context,
                      icone: Icons.person_remove,
                      titre: 'Liste de renvoi',
                      route: '/paiements/renvoi',
                      routeActuelle: routeActuelle,
                    ),
                    _menuItem(context,
                      icone: Icons.send_to_mobile,
                      titre: 'Notifications à envoyer',
                      route: '/notifications',
                      routeActuelle: routeActuelle,
                    ),
                  ],

                  // ── Enseignant uniquement ─────────────────
                  if (utilisateur.estEnseignant) ...[
                    _separateur('Mes classes'),
                    _menuItem(context,
                      icone: Icons.edit_note,
                      titre: 'Saisie des notes',
                      route: '/enseignant/notes',
                      routeActuelle: routeActuelle,
                    ),
                    _menuItem(context,
                      icone: Icons.event_busy,
                      titre: 'Saisie des absences',
                      route: '/enseignant/absences',
                      routeActuelle: routeActuelle,
                    ),
                    _menuItem(context,
                      icone: Icons.calendar_view_week,
                      titre: 'Mon emploi du temps',
                      route: '/emploi-du-temps/enseignant',
                      routeActuelle: routeActuelle,
                    ),
                  ],

                  Divider(
                    color: const Color(0xFF1E293B),
                    thickness: 1,
                    height: 24,
                  ),

                  // Synchronisation — tout le monde
                  _menuItem(context,
                    icone: Icons.sync,
                    titre: 'Synchronisation',
                    route: '/sync',
                    routeActuelle: routeActuelle,
                  ),

                  // Profil — tout le monde
                  _menuItem(context,
                    icone: Icons.person,
                    titre: 'Mon profil',
                    route: '/profil',
                    routeActuelle: routeActuelle,
                  ),
                ],
              ),
            ),
          ),

          // ── Déconnexion ───────────────────────────────────
          _boutonDeconnexion(context),
        ],
      ),
    );
  }

  Widget _enTete() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF1E3A8A),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.school, color: Colors.white, size: 26),
                  const SizedBox(width: 8),
                  Text(
                    'SSM',
                    style: GoogleFonts.sora(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Smart School Manager',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                utilisateur.nom,
                style: GoogleFonts.sora(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  utilisateur.role.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                utilisateur.email,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuItem(
    BuildContext context, {
    required IconData icone,
    required String titre,
    required String route,
    required String? routeActuelle,
  }) {
    final actif = route == routeActuelle;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: actif
            ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
            : Colors.transparent,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
        child: InkWell(
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(8),
            bottomRight: Radius.circular(8),
          ),
          onTap: () {
            Navigator.pop(context);
            if (!actif) Navigator.pushNamed(context, route);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: actif ? const Color(0xFF1E3A8A) : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icone,
                  size: 20,
                  color: actif
                      ? const Color(0xFF6B8AFB)
                      : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    titre,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: actif ? FontWeight.w600 : FontWeight.w400,
                      color: actif ? Colors.white : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _separateur(String titre) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, left: 16, bottom: 4),
      child: Text(
        titre.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF475569),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _boutonDeconnexion(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(color: Color(0xFF1E293B), thickness: 1, height: 1),
        Material(
          color: Colors.transparent,
          child: InkWell(
            hoverColor: const Color(0xFFDC2626).withValues(alpha: 0.08),
            splashColor: const Color(0xFFDC2626).withValues(alpha: 0.15),
            highlightColor: const Color(0xFFDC2626).withValues(alpha: 0.08),
            onTap: () async {
              await AuthService.deconnecter();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.logout, color: Color(0xFFDC2626), size: 20),
                  const SizedBox(width: 14),
                  Text(
                    'Déconnexion',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
