import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/notification_model.dart';
import '../../models/utilisateur.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/parametre_ecole_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_data_table.dart';
import '../../widgets/ssm/ssm_page_scaffold.dart';
import '../../widgets/ssm/ssm_pill.dart';
import '../../widgets/ssm/ssm_quick_action_button.dart';
import '../../widgets/ssm/ssm_sidebar.dart';
import '../../widgets/ssm/ssm_stat_card.dart';
import 'detail_notification_screen.dart';
import 'historique_notifications_screen.dart';
import 'modeles_messages_screen.dart';
import 'nouvelle_notification_screen.dart';
import 'parametres_declencheurs_screen.dart';
import 'statistiques_notifications_screen.dart';

bool _estAujourdhui(DateTime d) {
  final n = DateTime.now();
  return d.year == n.year && d.month == n.month && d.day == n.day;
}

String _formatDate(DateTime? d) {
  if (d == null) return '—';
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

// ══════════════════════════════════════════════════════════
// Point d'entrée unique du module Notifications (même logique que
// notes_module_screen.dart / statistiques_module_screen.dart).
// ══════════════════════════════════════════════════════════
class NotificationsModuleScreen extends StatefulWidget {
  const NotificationsModuleScreen({super.key});

  @override
  State<NotificationsModuleScreen> createState() => _NotificationsModuleScreenState();
}

class _NotificationsModuleScreenState extends State<NotificationsModuleScreen> {
  Utilisateur? _utilisateur;
  String _nomEcole = 'Mon établissement';
  bool _chargementUtilisateur = true;
  List<NotificationSSM> _notifications = [];
  bool _chargementListe = true;
  String? _erreur;

  String? _filtreStatut;
  String? _filtreCanal;
  String? _filtreCategorie;

  bool get _peutCreer => !(_utilisateur?.estEnseignant ?? true);
  bool get _estDirecteur => (_utilisateur?.estDirecteur ?? false) || (_utilisateur?.estSuperAdmin ?? false);

  int get _totalEnvoyes => _notifications.fold(0, (s, n) => s + n.nombreEnvoyes);
  int get _totalEnvoyesAujourdhui => _notifications
      .where((n) => n.createdAt != null && _estAujourdhui(n.createdAt!))
      .fold(0, (s, n) => s + n.nombreEnvoyes);
  int get _enAttenteCount => _notifications.where((n) => n.estEnAttente).length;
  int get _echoueesCount => _notifications.where((n) => n.estEnEchec).length;
  int get _delivreesCount => _notifications.where((n) => n.statut == StatutNotification.envoyee).length;

  @override
  void initState() {
    super.initState();
    _initialiser();
  }

  Future<void> _initialiser() async {
    final utilisateur = await AuthService.getUtilisateur();
    if (!mounted) return;
    setState(() {
      _utilisateur = utilisateur;
      _chargementUtilisateur = false;
    });
    unawaited(_chargerNomEcole());
    _charger();
  }

  Future<void> _chargerNomEcole() async {
    try {
      final infos = await ParametreEcoleService.getInformationsEtablissement();
      final nom = infos.nomCourt ?? infos.nomOfficiel;
      if (mounted && nom != null) setState(() => _nomEcole = nom);
    } catch (_) {
      // Le nom générique de repli reste affiché si le chargement échoue.
    }
  }

  Future<void> _charger() async {
    setState(() {
      _chargementListe = true;
      _erreur = null;
    });
    try {
      final notifications = await NotificationService.getNotifications(
        statut: _filtreStatut,
        canal: _filtreCanal,
        categorie: _filtreCategorie,
      );
      if (!mounted) return;
      setState(() {
        _notifications = notifications;
        _chargementListe = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargementListe = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _naviguer(String route) {
    if (route == '/notifications') return;
    Navigator.pushNamed(context, route);
  }

  Future<void> _ouvrirNouvelleNotification() async {
    final cree = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const NouvelleNotificationScreen()),
    );
    if (cree == true) _charger();
  }

  Future<void> _ouvrirDetail(int id) async {
    final modifie = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => DetailNotificationScreen(notificationId: id)),
    );
    if (modifie == true) _charger();
  }

  Future<void> _ouvrirModeles() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const ModelesMessagesScreen()));
  }

  Future<void> _ouvrirParametresDeclencheurs() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const ParametresDeclencheursScreen()));
  }

  Future<void> _ouvrirHistorique() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoriqueNotificationsScreen()));
    _charger();
  }

  Future<void> _ouvrirStatistiques() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const StatistiquesNotificationsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    if (_chargementUtilisateur) {
      return const Scaffold(
        backgroundColor: SSMPalette.fond,
        body: Center(child: CircularProgressIndicator(color: SSMPalette.indigo)),
      );
    }
    if (_utilisateur == null) {
      return Scaffold(
        backgroundColor: SSMPalette.fond,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Impossible de charger votre profil. Reconnectez-vous.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: SSMPalette.texte2),
            ),
          ),
        ),
      );
    }

    return SSMPageScaffold(
      nomEcole: _nomEcole,
      codeEcole: _utilisateur!.codeEcole,
      nomUtilisateur: _utilisateur!.nom,
      role: _libelleRole(_utilisateur!.role),
      sections: _sections(),
      routeActuelle: '/notifications',
      onNavigate: _naviguer,
      onProfilTap: () => Navigator.pushNamed(context, '/profil'),
      breadcrumb: 'Accueil',
      breadcrumbActuel: 'Notifications',
      floatingActionButton: _peutCreer
          ? Padding(
              padding: const EdgeInsets.only(bottom: 4, right: 4),
              child: SSMQuickActionButton(
                icone: Icons.add,
                label: 'Nouvelle notification',
                variante: SSMActionVariante.primaire,
                onTap: _ouvrirNouvelleNotification,
              ),
            )
          : null,
      child: RefreshIndicator(
        onRefresh: _charger,
        color: SSMPalette.indigo,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cartesResume(),
              const SizedBox(height: 20),
              _boutonsNavigation(),
              const SizedBox(height: 20),
              _titreSection('Notifications récentes'),
              const SizedBox(height: 12),
              _filtres(),
              const SizedBox(height: 14),
              _corpsListe(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Barre latérale ──────────────────────────────────────
  List<SSMNavSection> _sections() {
    final role = _utilisateur?.role;

    if (role == 'enseignant') {
      return [
        const SSMNavSection(titre: 'Principal', items: [
          SSMNavItem(icone: Icons.dashboard_outlined, label: 'Tableau de bord', route: '/dashboard/enseignant'),
        ]),
        const SSMNavSection(titre: 'Mes classes', items: [
          SSMNavItem(icone: Icons.grade_outlined, label: 'Notes & évaluations', route: '/notes'),
          SSMNavItem(icone: Icons.event_busy_outlined, label: 'Saisie des absences', route: '/enseignant/absences'),
          SSMNavItem(icone: Icons.calendar_view_week_outlined, label: 'Mon emploi du temps', route: '/emploi-du-temps'),
        ]),
        const SSMNavSection(titre: 'Général', items: [
          SSMNavItem(icone: Icons.notifications_outlined, label: 'Notifications', route: '/notifications'),
          SSMNavItem(icone: Icons.sync_outlined, label: 'Synchronisation', route: '/sync'),
          SSMNavItem(icone: Icons.person_outline, label: 'Mon profil', route: '/profil'),
          SSMNavItem(icone: Icons.settings_outlined, label: 'Paramètres', route: '/parametres'),
        ]),
      ];
    }

    if (role == 'censeur') {
      return [
        const SSMNavSection(titre: 'Principal', items: [
          SSMNavItem(icone: Icons.dashboard_outlined, label: 'Tableau de bord', route: '/dashboard/censeur'),
        ]),
        const SSMNavSection(titre: 'Pédagogie', items: [
          SSMNavItem(icone: Icons.grade_outlined, label: 'Notes & évaluations', route: '/notes'),
          SSMNavItem(icone: Icons.description_outlined, label: 'Bulletins', route: '/bulletins'),
          SSMNavItem(icone: Icons.event_busy_outlined, label: 'Saisie des absences', route: '/enseignant/absences'),
          SSMNavItem(icone: Icons.calendar_view_week_outlined, label: 'Emplois du temps', route: '/emploi-du-temps'),
        ]),
        const SSMNavSection(titre: 'Pilotage', items: [
          SSMNavItem(icone: Icons.bar_chart_outlined, label: 'Statistiques', route: '/statistiques'),
          SSMNavItem(icone: Icons.notifications_outlined, label: 'Notifications', route: '/notifications'),
        ]),
        const SSMNavSection(titre: 'Général', items: [
          SSMNavItem(icone: Icons.sync_outlined, label: 'Synchronisation', route: '/sync'),
          SSMNavItem(icone: Icons.person_outline, label: 'Mon profil', route: '/profil'),
          SSMNavItem(icone: Icons.settings_outlined, label: 'Paramètres', route: '/parametres'),
        ]),
      ];
    }

    // Directeur, secrétaire, comptable, super_admin : même structure que le
    // dashboard directeur (voir notes_module_screen.dart pour le précédent).
    return [
      const SSMNavSection(titre: 'Principal', items: [
        SSMNavItem(icone: Icons.dashboard_outlined, label: 'Tableau de bord', route: '/tableau-de-bord'),
        SSMNavItem(icone: Icons.people_outline, label: 'Élèves', route: '/directeur/eleves'),
        SSMNavItem(icone: Icons.grade_outlined, label: 'Notes & évaluations', route: '/notes'),
        SSMNavItem(icone: Icons.price_change_outlined, label: 'Frais scolaires', route: '/directeur/frais'),
        SSMNavItem(icone: Icons.calendar_view_week_outlined, label: 'Emploi du temps', route: '/emploi-du-temps'),
        SSMNavItem(icone: Icons.description_outlined, label: 'Bulletins PDF', route: '/bulletins'),
      ]),
      const SSMNavSection(titre: 'Pilotage', items: [
        SSMNavItem(icone: Icons.bar_chart_outlined, label: 'Statistiques', route: '/statistiques'),
        SSMNavItem(icone: Icons.notifications_outlined, label: 'Notifications', route: '/notifications'),
        SSMNavItem(icone: Icons.settings_outlined, label: 'Paramètres école', route: '/parametres'),
      ]),
      if (role == 'directeur')
        const SSMNavSection(titre: 'Administration', items: [
          SSMNavItem(icone: Icons.people_alt_outlined, label: 'Utilisateurs', route: '/directeur/utilisateurs'),
          SSMNavItem(icone: Icons.class_outlined, label: 'Classes', route: '/directeur/classes'),
          SSMNavItem(icone: Icons.menu_book_outlined, label: 'Matières', route: '/directeur/matieres'),
          SSMNavItem(icone: Icons.calendar_month_outlined, label: 'Années & Périodes', route: '/directeur/annees'),
        ]),
    ];
  }

  String _libelleRole(String? role) {
    switch (role) {
      case 'directeur':
        return 'Directeur';
      case 'censeur':
        return 'Censeur';
      case 'secretaire':
        return 'Secrétaire';
      case 'comptable':
        return 'Comptable';
      case 'enseignant':
        return 'Enseignant';
      default:
        return role ?? '';
    }
  }

  Widget _titreSection(String titre) {
    return Text(titre, style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.texte1));
  }

  // ── Cartes résumé ──
  Widget _cartesResume() {
    final cartes = <Widget>[
      SSMStatCard(
        icone: Icons.send_outlined,
        couleur: SSMPalette.indigo,
        valeur: '$_totalEnvoyes',
        label: 'Total envoyées',
        sousTexte: _totalEnvoyesAujourdhui > 0 ? "$_totalEnvoyesAujourdhui aujourd'hui" : null,
      ),
      SSMStatCard(
        icone: Icons.hourglass_empty,
        couleur: SSMPalette.ambre,
        valeur: '$_enAttenteCount',
        label: 'En attente',
      ),
      SSMStatCard(
        icone: Icons.error_outline,
        couleur: SSMPalette.rouge,
        valeur: '$_echoueesCount',
        label: 'Échouées',
      ),
      SSMStatCard(
        icone: Icons.check_circle_outline,
        couleur: SSMPalette.teal,
        valeur: '$_delivreesCount',
        label: 'Délivrées',
      ),
    ];

    return LayoutBuilder(builder: (context, contraintes) {
      final colonnes = contraintes.maxWidth >= 900 ? 4 : (contraintes.maxWidth >= 560 ? 2 : 1);
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: cartes.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: colonnes,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 168,
        ),
        itemBuilder: (context, i) => cartes[i],
      );
    });
  }

  Widget _boutonsNavigation() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        SSMQuickActionButton(
          icone: Icons.article_outlined,
          label: 'Modèles de messages',
          variante: SSMActionVariante.teal,
          onTap: _ouvrirModeles,
        ),
        SSMQuickActionButton(
          icone: Icons.history,
          label: 'Historique complet',
          variante: SSMActionVariante.gris,
          onTap: _ouvrirHistorique,
        ),
        SSMQuickActionButton(
          icone: Icons.bar_chart_outlined,
          label: 'Statistiques',
          variante: SSMActionVariante.ambre,
          onTap: _ouvrirStatistiques,
        ),
        if (_estDirecteur)
          SSMQuickActionButton(
            icone: Icons.tune,
            label: 'Déclencheurs',
            variante: SSMActionVariante.rouge,
            onTap: _ouvrirParametresDeclencheurs,
          ),
      ],
    );
  }

  // ── Filtres ──
  Widget _filtres() {
    return Row(
      children: [
        Expanded(
          child: _dropdownFiltre(
            valeur: _filtreStatut,
            hint: 'Statut',
            options: {for (final s in StatutNotification.values) s.valeurApi: s.libelle},
            onChanged: (v) {
              setState(() => _filtreStatut = v);
              _charger();
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _dropdownFiltre(
            valeur: _filtreCanal,
            hint: 'Canal',
            options: {for (final c in CanalNotification.values) c.valeurApi: c.libelle},
            onChanged: (v) {
              setState(() => _filtreCanal = v);
              _charger();
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _dropdownFiltre(
            valeur: _filtreCategorie,
            hint: 'Catégorie',
            options: {for (final c in CategorieNotification.values) c.valeurApi: c.libelle},
            onChanged: (v) {
              setState(() => _filtreCategorie = v);
              _charger();
            },
          ),
        ),
      ],
    );
  }

  Widget _dropdownFiltre({
    required String? valeur,
    required String hint,
    required Map<String, String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: SSMPalette.blanc,
        borderRadius: BorderRadius.circular(SSMRayons.moyen),
        border: Border.all(color: SSMPalette.bordure),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          isExpanded: true,
          value: valeur,
          hint: Text(hint, style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte3)),
          style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte1),
          items: [
            DropdownMenuItem<String?>(value: null, child: Text('Tout ($hint)')),
            ...options.entries.map((e) => DropdownMenuItem<String?>(value: e.key, child: Text(e.value))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ── Liste ──
  Widget _corpsListe() {
    if (_chargementListe) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(color: SSMPalette.indigo)),
      );
    }
    if (_erreur != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text(_erreur!, style: GoogleFonts.inter(color: SSMPalette.rouge))),
      );
    }
    if (_notifications.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.notifications_none, size: 40, color: SSMPalette.texte3),
              const SizedBox(height: 12),
              Text('Aucune notification pour ces filtres.', style: GoogleFonts.inter(color: SSMPalette.texte2)),
            ],
          ),
        ),
      );
    }

    return SSMDataTable(
      colonnes: const [
        SSMDataColumn('Titre'),
        SSMDataColumn('Cible'),
        SSMDataColumn('Canal'),
        SSMDataColumn('Statut'),
        SSMDataColumn('Date'),
      ],
      onLigneTap: (i) => _ouvrirDetail(_notifications[i].id!),
      lignes: [
        for (final n in _notifications)
          [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (n.urgent) ...[
                  const Icon(Icons.priority_high, size: 14, color: SSMPalette.rouge),
                  const SizedBox(width: 3),
                ],
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(
                    n.titre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: SSMPalette.texte1),
                  ),
                ),
              ],
            ),
            Text(n.typeCible.libelle, style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(n.canal.icone, size: 14, color: n.canal.couleur),
                const SizedBox(width: 5),
                Text(n.canal.libelle, style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
              ],
            ),
            SSMPill.couleur(label: n.statut.libelle, couleur: n.statut.couleur),
            Text(_formatDate(n.createdAt), style: GoogleFonts.jetBrainsMono(fontSize: 11, color: SSMPalette.texte3)),
          ],
      ],
    );
  }
}
