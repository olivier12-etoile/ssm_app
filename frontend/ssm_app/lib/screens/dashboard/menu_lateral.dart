import 'package:flutter/material.dart';
import '../../models/utilisateur.dart';
import '../../services/auth_service.dart';

class MenuLateral extends StatelessWidget {
  final Utilisateur utilisateur;

  const MenuLateral({super.key, required this.utilisateur});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // ── En-tête ──────────────────────────────────────
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: Color(
                int.parse(
                  utilisateur.couleurPrimaire.replaceAll('#', '0xFF'),
                ),
              ),
            ),
            accountName: Text(
              utilisateur.nom,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(utilisateur.email),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                utilisateur.nom[0].toUpperCase(),
                style: TextStyle(
                  fontSize: 24,
                  color: Color(
                    int.parse(
                      utilisateur.couleurPrimaire.replaceAll('#', '0xFF'),
                    ),
                  ),
                ),
              ),
            ),
            otherAccountsPictures: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  utilisateur.role.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            ],
          ),

          // ── Menu ─────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Tableau de bord — tout le monde
                _menuItem(context,
                  icone: Icons.dashboard,
                  titre: 'Tableau de bord',
                  route: '/tableau-de-bord',
                ),

                // ── Directeur uniquement ──────────────────
                if (utilisateur.estDirecteur) ...[
                  _separateur('Administration'),
                  _menuItem(context,
                    icone: Icons.people,
                    titre: 'Utilisateurs',
                    route: '/directeur/utilisateurs',
                  ),
                  _menuItem(context,
                    icone: Icons.class_,
                    titre: 'Classes',
                    route: '/directeur/classes',
                  ),
                  _menuItem(context,
                    icone: Icons.book,
                    titre: 'Matières',
                    route: '/directeur/matieres',
                  ),
                  _menuItem(context,
                    icone: Icons.calendar_month,
                    titre: 'Années & Périodes',
                    route: '/directeur/annees',
                  ),
                  _menuItem(context,
                    icone: Icons.people_outline,
                    titre: 'Élèves',
                    route: '/directeur/eleves',
                  ),
                  _menuItem(context,
                    icone: Icons.assignment_ind,
                    titre: 'Affectations',
                    route: '/directeur/affectations',
                  ),
                  _menuItem(context,
                    icone: Icons.bar_chart,
                    titre: 'Statistiques',
                    route: '/statistiques',
                  ),
                ],

                // ── Censeur uniquement ─────────────────────
                if (utilisateur.estCenseur) ...[
                  _separateur('Classes'),
                  _menuItem(context,
                    icone: Icons.class_,
                    titre: 'Mes classes',
                    route: '/dashboard/censeur',
                  ),
                ],

                // ── Directeur + Censeur ───────────────────
                if (utilisateur.estDirecteur || utilisateur.estCenseur) ...[
                  _separateur('Pédagogie'),
                  _menuItem(context,
                    icone: Icons.edit_note,
                    titre: 'Saisie des notes',
                    route: '/enseignant/notes',
                  ),
                  _menuItem(context,
                    icone: Icons.grade,
                    titre: 'Validation des notes',
                    route: '/notes/validation',
                  ),
                  _menuItem(context,
                    icone: Icons.description,
                    titre: 'Bulletins',
                    route: '/bulletins',
                  ),
                  // ← AJOUTÉ : manquait pour Directeur/Censeur
                  _menuItem(context,
                    icone: Icons.event_busy,
                    titre: 'Saisie des absences',
                    route: '/enseignant/absences',
                  ),
                ],

                // ── Directeur + Secrétaire ────────────────
                if (utilisateur.estDirecteur || utilisateur.estSecretaire) ...[
                  _separateur('Finances'),
                  _menuItem(context,
                    icone: Icons.payment,
                    titre: 'Paiements',
                    route: '/paiements',
                  ),
                  _menuItem(context,
                    icone: Icons.person_remove,
                    titre: 'Liste de renvoi',
                    route: '/paiements/renvoi',
                  ),

                  _menuItem(context,
    icone: Icons.send_to_mobile,
    titre: 'Notifications à envoyer',
    route: '/notifications',
  ),
                ],

                // ── Enseignant uniquement ─────────────────
                if (utilisateur.estEnseignant) ...[
                  _separateur('Mes classes'),
                  _menuItem(context,
                    icone: Icons.edit_note,
                    titre: 'Saisie des notes',
                    route: '/enseignant/notes',
                  ),
                  _menuItem(context,
                    icone: Icons.event_busy,
                    titre: 'Saisie des absences',
                    route: '/enseignant/absences',
                  ),
                ],

                const Divider(),

                // Synchronisation — tout le monde
                _menuItem(context,
                  icone: Icons.sync,
                  titre: 'Synchronisation',
                  route: '/sync',
                ),

                // Profil — tout le monde
                _menuItem(context,
                  icone: Icons.person,
                  titre: 'Mon profil',
                  route: '/profil',
                ),
              ],
            ),
          ),

          // ── Déconnexion ───────────────────────────────────
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Déconnexion',
                style: TextStyle(color: Colors.red)),
            onTap: () async {
              await AuthService.deconnecter();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _menuItem(
    BuildContext context, {
    required IconData icone,
    required String titre,
    required String route,
  }) {
    return ListTile(
      leading: Icon(icone),
      title: Text(titre),
      onTap: () {
        Navigator.pop(context);
        Navigator.pushNamed(context, route);
      },
    );
  }

  Widget _separateur(String titre) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        titre.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}