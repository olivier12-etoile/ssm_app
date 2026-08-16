import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/utilisateur.dart';
import '../../models/bulletin_model.dart';
import '../../services/auth_service.dart';
import '../../services/annee_service.dart';
import '../../services/classe_service.dart';
import '../../services/bulletin_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_page_scaffold.dart';
import '../../widgets/ssm/ssm_sidebar.dart';
import '../../widgets/ssm/ssm_stat_card.dart';
import '../../widgets/ssm/ssm_panel.dart';
import '../../widgets/ssm/ssm_data_table.dart';
import '../../widgets/ssm/ssm_pill.dart';
import '../../widgets/ssm/ssm_quick_action_button.dart';
import 'generation_bulletin_screen.dart';
import 'validation_bulletins_screen.dart';
import 'historique_recherche_bulletins_screen.dart';
import 'statistiques_bulletins_screen.dart';

// ══════════════════════════════════════════════════════════
// Point d'entrée unique du module Bulletins (même logique que
// notes_module_screen.dart) : sélecteurs année/période, résumé de
// génération de l'école, liste des classes avec statut de génération, puis
// navigation vers la génération détaillée (generation_bulletin_screen.dart),
// la validation en attente (validation_bulletins_screen.dart),
// l'historique/recherche (historique_recherche_bulletins_screen.dart) et
// les statistiques (statistiques_bulletins_screen.dart).
// ══════════════════════════════════════════════════════════
class BulletinsModuleScreen extends StatefulWidget {
  const BulletinsModuleScreen({super.key});

  @override
  State<BulletinsModuleScreen> createState() => _BulletinsModuleScreenState();
}

class _BulletinsModuleScreenState extends State<BulletinsModuleScreen> {
  Utilisateur? _utilisateur;
  bool _chargement = true;
  String? _erreur;

  List<dynamic> _annees = [];
  List<dynamic> _periodes = [];
  int? _anneeId;
  int? _periodeId;

  ResumeDashboardBulletin? _resume;
  bool _chargementResume = false;

  List<dynamic> _classes = [];
  final Map<int, List<StatutGenerationEleve>> _statutParClasse = {};
  bool _chargementClasses = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final utilisateur = await AuthService.getUtilisateur();
      final annees = await AnneeService.listerAnnees();
      if (!mounted) return;
      setState(() {
        _utilisateur = utilisateur;
        _annees = annees;
        _chargement = false;
      });
      await _resoudreSelectionActive();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  // Pré-sélectionne l'année et la période actives, comme les autres
  // modules_screen.dart — l'utilisateur peut toujours changer ensuite.
  Future<void> _resoudreSelectionActive() async {
    try {
      final data = await AnneeService.anneeActive();
      final annee = data['annee'] as Map<String, dynamic>?;
      final periodeActive = data['periode_active'] as Map<String, dynamic>?;
      final anneeId = annee?['id'] as int?;
      if (anneeId == null) return;

      final periodes = await AnneeService.listerPeriodes(anneeId);
      if (!mounted) return;
      setState(() {
        _anneeId = anneeId;
        _periodes = periodes;
        _periodeId = periodeActive?['id'] as int? ?? (periodes.isNotEmpty ? periodes.first['id'] as int : null);
      });

      if (_periodeId != null) _chargerDonneesPeriode();
    } catch (_) {
      // Les sélecteurs restent vides ; l'utilisateur choisit manuellement.
    }
  }

  Future<void> _changerAnnee(int? anneeId) async {
    if (anneeId == null) return;
    setState(() {
      _anneeId = anneeId;
      _periodeId = null;
      _periodes = [];
      _resume = null;
      _classes = [];
      _statutParClasse.clear();
    });
    try {
      final periodes = await AnneeService.listerPeriodes(anneeId);
      if (mounted) setState(() => _periodes = periodes);
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _changerPeriode(int? periodeId) {
    setState(() => _periodeId = periodeId);
    if (periodeId != null) _chargerDonneesPeriode();
  }

  Future<void> _chargerDonneesPeriode() async {
    final anneeId = _anneeId;
    final periodeId = _periodeId;
    if (anneeId == null || periodeId == null) return;

    setState(() {
      _chargementResume = true;
      _chargementClasses = true;
    });

    try {
      final resume = await BulletinService.getResumeDashboard(anneeScolaireId: anneeId, periodeId: periodeId);
      if (mounted) {
        setState(() {
          _resume = resume;
          _chargementResume = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _chargementResume = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }

    try {
      final classesGroupees = await ClasseService.lister(anneeId: anneeId);
      final classes = _aplatirClasses(classesGroupees);

      final statuts = await Future.wait(classes.map((c) => BulletinService
          .getStatutGeneration(classeId: c['id'] as int, periodeId: periodeId)
          .catchError((_) => <StatutGenerationEleve>[])));

      if (!mounted) return;
      setState(() {
        _classes = classes;
        _statutParClasse
          ..clear()
          ..addEntries(List.generate(classes.length, (i) => MapEntry(classes[i]['id'] as int, statuts[i])));
        _chargementClasses = false;
      });
    } catch (e) {
      if (mounted) setState(() => _chargementClasses = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // `GET /classes` renvoie les classes groupées par cycle (puis niveau,
  // puis série) — on aplatit récursivement, comme ClasseService.listerClasses().
  List<dynamic> _aplatirClasses(dynamic valeur) {
    final toutes = <dynamic>[];
    void parcourir(dynamic v) {
      if (v is List) {
        toutes.addAll(v);
      } else if (v is Map) {
        for (final sous in v.values) {
          parcourir(sous);
        }
      }
    }

    parcourir(valeur);
    return toutes;
  }

  // ── Navigation ────────────────────────────────────────

  void _naviguer(BuildContext context, String route) {
    if (route == '/bulletins') return;
    Navigator.pushNamed(context, route);
  }

  void _ouvrirGeneration({int? classeId}) {
    if (_anneeId == null || _periodeId == null) {
      _afficherErreur('Sélectionnez une année et une période avant de générer des bulletins.');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GenerationBulletinScreen(
          anneeScolaireId: _anneeId!,
          periodeId: _periodeId!,
          classeIdInitiale: classeId,
        ),
      ),
    ).then((_) => _chargerDonneesPeriode());
  }

  void _ouvrirValidation() {
    if (_anneeId == null) {
      _afficherErreur('Sélectionnez une année scolaire.');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ValidationBulletinsScreen(anneeScolaireId: _anneeId!, periodeIdInitiale: _periodeId),
      ),
    ).then((_) => _chargerDonneesPeriode());
  }

  void _ouvrirHistoriqueRecherche() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoriqueRechercheBulletinsScreen()));
  }

  void _ouvrirStatistiques() {
    if (_anneeId == null) {
      _afficherErreur('Sélectionnez une année scolaire.');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StatistiquesBulletinsScreen(anneeScolaireId: _anneeId!, periodeIdInitiale: _periodeId),
      ),
    );
  }

  void _afficherErreur(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: SSMPalette.rouge),
    );
  }

  // ── Navigation latérale, adaptée au rôle connecté (voir notes_module_screen.dart) ──
  List<SSMNavSection> _sections() {
    final role = _utilisateur?.role;

    if (role == 'enseignant') {
      return [
        const SSMNavSection(titre: 'Principal', items: [
          SSMNavItem(icone: Icons.dashboard_outlined, label: 'Tableau de bord', route: '/dashboard/enseignant'),
        ]),
        SSMNavSection(titre: 'Mes classes', items: [
          const SSMNavItem(icone: Icons.grade_outlined, label: 'Notes & évaluations', route: '/notes'),
          const SSMNavItem(icone: Icons.event_busy_outlined, label: 'Saisie des absences', route: '/enseignant/absences'),
          const SSMNavItem(icone: Icons.calendar_view_week_outlined, label: 'Mon emploi du temps', route: '/emploi-du-temps'),
        ]),
        const SSMNavSection(titre: 'Général', items: [
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
        const SSMNavSection(titre: 'Général', items: [
          SSMNavItem(icone: Icons.sync_outlined, label: 'Synchronisation', route: '/sync'),
          SSMNavItem(icone: Icons.person_outline, label: 'Mon profil', route: '/profil'),
          SSMNavItem(icone: Icons.settings_outlined, label: 'Paramètres', route: '/parametres'),
        ]),
      ];
    }

    // Directeur, secrétaire, comptable, super_admin : même structure que le
    // dashboard directeur.
    return [
      const SSMNavSection(titre: 'Principal', items: [
        SSMNavItem(icone: Icons.dashboard_outlined, label: 'Tableau de bord', route: '/tableau-de-bord'),
        SSMNavItem(icone: Icons.people_outline, label: 'Élèves', route: '/directeur/eleves'),
        SSMNavItem(icone: Icons.price_change_outlined, label: 'Frais scolaires', route: '/directeur/frais'),
        SSMNavItem(icone: Icons.calendar_view_week_outlined, label: 'Emploi du temps', route: '/emploi-du-temps'),
        SSMNavItem(icone: Icons.description_outlined, label: 'Bulletins PDF', route: '/bulletins'),
      ]),
      const SSMNavSection(titre: 'Pilotage', items: [
        SSMNavItem(icone: Icons.grade_outlined, label: 'Notes & évaluations', route: '/notes'),
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
      case 'enseignant':
        return 'Enseignant';
      case 'comptable':
        return 'Comptable';
      case 'super_admin':
        return 'Super admin';
      default:
        return role ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) {
      return const Scaffold(backgroundColor: SSMPalette.fond, body: Center(child: CircularProgressIndicator(color: SSMPalette.indigo)));
    }

    if (_utilisateur == null) {
      return Scaffold(backgroundColor: SSMPalette.fond, body: _vueErreur('Impossible de charger votre profil. Reconnectez-vous.'));
    }

    return SSMPageScaffold(
      nomEcole: _utilisateur?.codeEcole ?? 'Mon établissement',
      codeEcole: _utilisateur?.codeEcole ?? '—',
      nomUtilisateur: _utilisateur?.nom ?? '…',
      role: _libelleRole(_utilisateur?.role),
      sections: _sections(),
      routeActuelle: '/bulletins',
      onNavigate: (route) => _naviguer(context, route),
      onProfilTap: () => Navigator.pushNamed(context, '/profil'),
      breadcrumb: 'Accueil',
      breadcrumbActuel: 'Bulletins',
      child: _erreur != null ? _vueErreur(_erreur!) : _corps(),
    );
  }

  Widget _vueErreur(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: SSMPalette.rouge, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: GoogleFonts.inter(color: SSMPalette.texte2)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _charger, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }

  Widget _corps() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _carteSelecteurs(),
        const SizedBox(height: 16),
        _grilleResume(),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: SSMQuickActionButton(
            icone: Icons.auto_awesome,
            label: 'Générer des bulletins',
            variante: SSMActionVariante.primaire,
            onTap: () => _ouvrirGeneration(),
          ),
        ),
        const SizedBox(height: 12),
        _boutonsNavigation(),
        const SizedBox(height: 20),
        SSMPanel(
          titre: 'Classes',
          padding: EdgeInsets.zero,
          child: _listeClasses(),
        ),
      ],
    );
  }

  // ── Sélecteurs année/période ────────────────────────────

  Widget _carteSelecteurs() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SSMPalette.blanc,
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        border: Border.all(color: SSMPalette.bordure),
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              value: _anneeId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Année scolaire', isDense: true),
              items: _annees.map((a) => DropdownMenuItem<int>(value: a['id'] as int, child: Text(a['libelle'] as String))).toList(),
              onChanged: _changerAnnee,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<int>(
              value: _periodeId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Période', isDense: true),
              items: _periodes.map((p) => DropdownMenuItem<int>(value: p['id'] as int, child: Text(p['nom'] as String))).toList(),
              onChanged: _periodes.isEmpty ? null : _changerPeriode,
            ),
          ),
        ],
      ),
    );
  }

  // ── Cards résumé ─────────────────────────────────────────

  Widget _grilleResume() {
    if (_chargementResume) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: SSMPalette.indigo)));
    }
    final r = _resume;
    if (r == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Choisissez une année et une période pour voir le résumé.', style: GoogleFonts.inter(color: SSMPalette.texte3)),
        ),
      );
    }

    final cartes = <Widget>[
      SSMStatCard(icone: Icons.description_outlined, couleur: SSMPalette.indigo, valeur: '${r.bulletinsGeneres}', label: 'Bulletins générés'),
      SSMStatCard(icone: Icons.verified_outlined, couleur: SSMPalette.teal, valeur: '${r.bulletinsValides}', label: 'Validés'),
      SSMStatCard(icone: Icons.hourglass_bottom, couleur: SSMPalette.ambre, valeur: '${r.bulletinsEnAttente}', label: 'En attente de validation'),
      SSMStatCard(icone: Icons.class_outlined, couleur: SSMPalette.teal, valeur: '${r.classesConcernees}', label: 'Classes concernées'),
      SSMStatCard(icone: Icons.error_outline, couleur: SSMPalette.rouge, valeur: '${r.bulletinsNonGeneres}', label: 'Non générés'),
      SSMStatCard(icone: Icons.groups_outlined, couleur: SSMPalette.texte1, valeur: '${r.effectifTotal}', label: 'Effectif total'),
    ];

    return LayoutBuilder(builder: (context, contraintes) {
      final colonnes = contraintes.maxWidth >= 900 ? 3 : (contraintes.maxWidth >= 560 ? 2 : 1);
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

  // ── Navigation rapide ───────────────────────────────────────

  Widget _boutonsNavigation() {
    return Row(
      children: [
        Expanded(
          child: SSMQuickActionButton(
            icone: Icons.playlist_add_check,
            label: 'Validation en attente',
            variante: SSMActionVariante.ambre,
            onTap: _ouvrirValidation,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SSMQuickActionButton(
            icone: Icons.history,
            label: 'Historique & Recherche',
            variante: SSMActionVariante.teal,
            onTap: _ouvrirHistoriqueRecherche,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SSMQuickActionButton(
            icone: Icons.bar_chart,
            label: 'Statistiques',
            variante: SSMActionVariante.gris,
            onTap: _ouvrirStatistiques,
          ),
        ),
      ],
    );
  }

  // ── Liste des classes avec statut de génération ────────────

  Widget _listeClasses() {
    if (_chargementClasses) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: SSMPalette.indigo)));
    }
    if (_classes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Aucune classe pour cette année scolaire.', style: GoogleFonts.inter(color: SSMPalette.texte3)),
      );
    }

    return SSMDataTable(
      colonnes: const [
        SSMDataColumn('Classe'),
        SSMDataColumn('Effectif'),
        SSMDataColumn('Statut'),
      ],
      onLigneTap: (i) => _ouvrirGeneration(classeId: _classes[i]['id'] as int),
      lignes: [
        for (final c in _classes)
          () {
            final classeId = c['id'] as int;
            final nom = c['nom'] as String? ?? '—';
            final statuts = _statutParClasse[classeId] ?? const [];
            final total = statuts.length;
            final genCount = statuts.where((s) => s.genere).length;

            final (label, couleur) = switch ((total, genCount)) {
              (0, _) => ('Aucun élève', SSMPalette.texte3),
              (_, 0) => ('Non commencé', SSMPalette.texte3),
              (var t, var g) when g == t => ('Terminé', SSMPalette.teal),
              _ => ('En cours $genCount/$total', SSMPalette.ambre),
            };

            return [
              Text(nom, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
              Text('$total', style: GoogleFonts.jetBrainsMono(fontSize: 12, color: SSMPalette.texte2)),
              SSMPill.couleur(label: label, couleur: couleur),
            ];
          }(),
      ],
    );
  }
}
