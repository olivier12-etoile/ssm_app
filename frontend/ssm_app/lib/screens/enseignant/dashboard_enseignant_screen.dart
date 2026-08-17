import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/note_model.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_alert_item.dart';
import '../../widgets/ssm/ssm_data_table.dart';
import '../../widgets/ssm/ssm_page_scaffold.dart';
import '../../widgets/ssm/ssm_panel.dart';
import '../../widgets/ssm/ssm_pill.dart';
import '../../widgets/ssm/ssm_quick_action_button.dart';
import '../../widgets/ssm/ssm_sidebar.dart';
import '../../widgets/ssm/ssm_stat_card.dart';
import '../../widgets/ssm/ssm_topbar.dart';
import '../emploi_du_temps/emploi_du_temps_module_screen.dart';
import '../notes/saisie_notes_screen.dart';
import '../notes/selection_saisie_screen.dart';
import '../presences/appel_presence_screen.dart';
import 'dashboard_enseignant_view_model.dart';

// ══════════════════════════════════════════════════════════
// DashboardEnseignantScreen — Tableau de bord de l'enseignant,
// reconstruit avec le design system SSM (flat/clean), périmètre
// limité à ce qui le concerne (ses classes, ses notes, son
// emploi du temps, l'appel de ses classes).
// ══════════════════════════════════════════════════════════
class DashboardEnseignantScreen extends StatefulWidget {
  const DashboardEnseignantScreen({super.key});

  @override
  State<DashboardEnseignantScreen> createState() => _DashboardEnseignantScreenState();
}

class _DashboardEnseignantScreenState extends State<DashboardEnseignantScreen> {
  DashboardEnseignantDonnees? _donnees;
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _chargement = true);
    final donnees = await DashboardEnseignantViewModel.charger();
    if (!mounted) return;
    setState(() {
      _donnees = donnees;
      _chargement = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = _donnees;
    final utilisateur = d?.utilisateur;

    return SSMPageScaffold(
      nomEcole: utilisateur?.codeEcole ?? 'Mon établissement',
      codeEcole: utilisateur?.codeEcole ?? '—',
      nomUtilisateur: utilisateur?.nom ?? '…',
      role: 'Enseignant',
      sections: _sections(),
      routeActuelle: '/dashboard/enseignant',
      onNavigate: (route) => _naviguer(context, route),
      onProfilTap: () => Navigator.pushNamed(context, '/profil'),
      breadcrumb: 'Accueil',
      breadcrumbActuel: 'Tableau de bord',
      periodePill: (d?.libellePeriodeActive != null)
          ? SSMPeriodePill(
              texte: d!.libellePeriodeActive!,
              badge: d.periodeEnCours ? 'EN COURS' : null,
            )
          : null,
      onNotificationTap: () => Navigator.pushNamed(context, '/notifications'),
      hasNotification: (d?.notificationsNonLues ?? 0) > 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _welcomeRow(),
          if (!_chargement && (d?.notesRejetees.isNotEmpty ?? false)) ...[
            const SizedBox(height: 14),
            _alerteNotesRejetees(context, d!),
          ],
          const SizedBox(height: 18),
          _statsGrid(),
          const SizedBox(height: 12),
          _deuxColonnes(context),
          const SizedBox(height: 14),
          _actionsRapides(context),
        ],
      ),
    );
  }

  void _naviguer(BuildContext context, String route) {
    if (route == '/dashboard/enseignant') return;
    if (route == '/enseignant/appel') {
      _ouvrirSelectionAppel(context);
      return;
    }
    Navigator.pushNamed(context, route);
  }

  // ── Navigation latérale — périmètre strict de l'enseignant ──
  List<SSMNavSection> _sections() {
    final d = _donnees;
    int? badge(int valeur) => (!_chargement && valeur > 0) ? valeur : null;

    return [
      SSMNavSection(titre: 'Principal', items: [
        const SSMNavItem(icone: Icons.dashboard_outlined, label: 'Tableau de bord', route: '/dashboard/enseignant'),
        SSMNavItem(
          icone: Icons.class_outlined,
          label: 'Mes classes',
          route: '/enseignant/mes-classes',
          badge: badge(d?.nombreClasses ?? 0),
        ),
        SSMNavItem(
          icone: Icons.edit_note_outlined,
          label: 'Notes & évaluations',
          route: '/notes',
          badge: badge(d?.saisiesEnAttente ?? 0),
          couleurBadge: SSMPalette.ambre,
        ),
        const SSMNavItem(icone: Icons.how_to_reg_outlined, label: 'Présences / Appel', route: '/enseignant/appel'),
        const SSMNavItem(icone: Icons.calendar_view_week_outlined, label: 'Mon emploi du temps', route: '/emploi-du-temps'),
      ]),
      SSMNavSection(titre: 'Général', items: [
        SSMNavItem(
          icone: Icons.notifications_outlined,
          label: 'Notifications',
          route: '/notifications',
          badge: badge(d?.notificationsNonLues ?? 0),
        ),
        const SSMNavItem(icone: Icons.settings_outlined, label: 'Paramètres', route: '/parametres'),
      ]),
    ];
  }

  // ── a) Bandeau de bienvenue ──
  Widget _welcomeRow() {
    final d = _donnees;
    final prenom = _chargement ? '…' : (d?.prenomUtilisateur ?? 'Enseignant');
    final parties = <String>[
      if ((d?.nomEcole ?? '').isNotEmpty) d!.nomEcole,
      _formaterDateComplete(DateTime.now()),
      if (!_chargement) '${d?.nombreClasses ?? 0} classe(s) · ${d?.nombreMatieres ?? 0} matière(s) enseignée(s)',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bonjour, $prenom 👋',
          style: GoogleFonts.sora(fontSize: 19, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
        ),
        const SizedBox(height: 3),
        Text(
          parties.join('  ·  '),
          style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2),
        ),
      ],
    );
  }

  // ── Bannière notes rejetées à corriger ──
  Widget _alerteNotesRejetees(BuildContext context, DashboardEnseignantDonnees d) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(SSMRayons.petit + 2),
        onTap: () => Navigator.pushNamed(context, '/notes'),
        child: SSMAlertItem(
          type: SSMAlerteType.danger,
          icone: Icons.warning_amber_rounded,
          titre: '${d.notesRejetees.length} note(s) rejetée(s) à corriger',
          sousTitre: 'Touchez ici pour ouvrir la saisie et corriger les notes concernées.',
        ),
      ),
    );
  }

  // ── b) 4 cartes statistiques ──
  Widget _statsGrid() {
    final d = _donnees;

    final cartes = <Widget>[
      SSMStatCard(
        icone: Icons.class_outlined,
        couleur: SSMPalette.indigo,
        valeur: _chargement ? '—' : '${d?.nombreClasses ?? 0}',
        label: 'Mes classes',
        sousTexte: _chargement ? null : '${d?.nombreMatieres ?? 0} matière(s) enseignée(s)',
      ),
      SSMStatCard(
        icone: Icons.people_outline,
        couleur: SSMPalette.teal,
        valeur: _chargement ? '—' : '${d?.totalEleves ?? 0}',
        label: 'Mes élèves',
        sousTexte: _chargement ? null : 'Toutes classes confondues',
      ),
      SSMStatCard(
        icone: Icons.edit_note_outlined,
        couleur: SSMPalette.ambre,
        valeur: _chargement ? '—' : '${d?.saisiesEnAttente ?? 0}',
        label: 'Saisies en attente',
        sousTexte: _chargement ? null : 'À terminer ou soumettre',
      ),
      SSMStatCard(
        icone: Icons.today_outlined,
        couleur: SSMPalette.indigo,
        valeur: _chargement ? '—' : '${d?.seancesAujourdhui.length ?? 0}',
        label: 'Prochains cours',
        sousTexte: _chargement ? null : "Aujourd'hui",
      ),
    ];

    return LayoutBuilder(builder: (context, contraintes) {
      final colonnes = contraintes.maxWidth >= 760 ? 4 : (contraintes.maxWidth >= 520 ? 2 : 1);
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

  // ── c) Colonne Saisies en cours + Colonne Emploi du temps du jour ──
  Widget _deuxColonnes(BuildContext context) {
    return LayoutBuilder(builder: (context, contraintes) {
      final panneauSaisies = _panelSaisies(context);
      final panneauEmploi = _panelEmploiDuJour(context);

      if (contraintes.maxWidth < 760) {
        return Column(children: [panneauSaisies, const SizedBox(height: 12), panneauEmploi]);
      }

      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 340, child: panneauSaisies),
            const SizedBox(width: 12),
            Expanded(child: panneauEmploi),
          ],
        ),
      );
    });
  }

  Widget _panelSaisies(BuildContext context) {
    final d = _donnees;
    final saisies = d?.progressionSaisies ?? const <SaisieNote>[];

    return SSMPanel(
      titre: 'Mes saisies en cours',
      lienAction: 'Voir tout →',
      onLienAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SelectionSaisieScreen())),
      child: _chargement
          ? const _EtatChargementPanel()
          : saisies.isEmpty
              ? const _EtatVide(icone: Icons.check_circle_outline, texte: 'Aucune saisie en cours')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int i = 0; i < saisies.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      _carteSaisie(context, saisies[i]),
                    ],
                  ],
                ),
    );
  }

  Widget _carteSaisie(BuildContext context, SaisieNote saisie) {
    final couleur = _couleurStatutSaisie(saisie.statut);
    final pourcentage = (saisie.pourcentageCompletion ?? 0) / 100;

    return Material(
      color: SSMPalette.blanc,
      borderRadius: BorderRadius.circular(SSMRayons.moyen),
      child: InkWell(
        borderRadius: BorderRadius.circular(SSMRayons.moyen),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SaisieNotesScreen(saisie: saisie))),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SSMRayons.moyen),
            border: Border(
              top: BorderSide(color: SSMPalette.bordure),
              right: BorderSide(color: SSMPalette.bordure),
              bottom: BorderSide(color: SSMPalette.bordure),
              left: BorderSide(color: couleur, width: 3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${saisie.classeNom ?? 'Classe'} · ${saisie.matiereNom ?? ''}',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: SSMPalette.texte1),
                    ),
                  ),
                  SSMPill.couleur(label: saisie.statut.libelle, couleur: couleur),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pourcentage.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: const Color(0xFFF1F5F9),
                  color: couleur,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${(saisie.pourcentageCompletion ?? 0).toStringAsFixed(0)}% complété',
                style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: SSMPalette.texte2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _couleurStatutSaisie(StatutSaisie statut) {
    switch (statut) {
      case StatutSaisie.enCours:
        return SSMPalette.indigo;
      case StatutSaisie.terminee:
      case StatutSaisie.validee:
        return SSMPalette.teal;
      case StatutSaisie.enAttenteValidation:
        return SSMPalette.ambre;
      case StatutSaisie.rejetee:
        return SSMPalette.rouge;
    }
  }

  Widget _panelEmploiDuJour(BuildContext context) {
    final d = _donnees;
    final seances = d?.seancesAujourdhui ?? const <SeanceDuJour>[];

    return SSMPanel(
      titre: "Mon emploi du temps du jour",
      lienAction: 'Voir tout →',
      onLienAction: () => Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: '/emploi-du-temps'),
          builder: (_) => const EmploiDuTempsModuleScreen(),
        ),
      ),
      padding: EdgeInsets.zero,
      child: _chargement
          ? const _EtatChargementPanel()
          : seances.isEmpty
              ? const _EtatVide(icone: Icons.event_available_outlined, texte: "Aucun cours prévu aujourd'hui")
              : SSMDataTable(
                  colonnes: const [
                    SSMDataColumn('Heure'),
                    SSMDataColumn('Matière'),
                    SSMDataColumn('Classe'),
                  ],
                  lignes: [for (final s in seances) _ligneSeance(s)],
                ),
    );
  }

  List<Widget> _ligneSeance(SeanceDuJour s) {
    return [
      Text(
        '${s.creneau.heureDebut} - ${s.creneau.heureFin}',
        style: GoogleFonts.jetBrainsMono(fontSize: 11.5, color: SSMPalette.texte1),
      ),
      Text(s.seance.nomMatiere ?? '—', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte1)),
      Text(s.classeNom, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
    ];
  }

  // ── d) Actions rapides ──
  Widget _actionsRapides(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: SSMPalette.blanc,
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        border: Border.all(color: SSMPalette.bordure),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Actions rapides',
            style: GoogleFonts.sora(fontSize: 12.5, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SSMQuickActionButton(
                icone: Icons.edit_note_outlined,
                label: 'Saisir des notes',
                variante: SSMActionVariante.primaire,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SelectionSaisieScreen())),
              ),
              SSMQuickActionButton(
                icone: Icons.how_to_reg_outlined,
                label: "Faire l'appel",
                variante: SSMActionVariante.teal,
                onTap: () => _ouvrirSelectionAppel(context),
              ),
              SSMQuickActionButton(
                icone: Icons.calendar_view_week_outlined,
                label: 'Voir mon emploi du temps',
                variante: SSMActionVariante.ambre,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    settings: const RouteSettings(name: '/emploi-du-temps'),
                    builder: (_) => const EmploiDuTempsModuleScreen(),
                  ),
                ),
              ),
              SSMQuickActionButton(
                icone: Icons.class_outlined,
                label: 'Mes classes',
                variante: SSMActionVariante.gris,
                onTap: () => Navigator.pushNamed(context, '/enseignant/mes-classes'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Sélection rapide d'une classe pour l'appel (1 classe → direct,
  // sinon feuille de choix) ──
  Future<void> _ouvrirSelectionAppel(BuildContext context) async {
    final classes = _donnees?.classesAffectees ?? const <Map<String, dynamic>>[];
    if (classes.isEmpty) return;

    if (classes.length == 1) {
      _ouvrirAppel(context, classes.first);
      return;
    }

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                "Faire l'appel — choisir une classe",
                style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
              ),
            ),
            for (final c in classes)
              ListTile(
                leading: const Icon(Icons.class_outlined, color: SSMPalette.indigo),
                title: Text(c['classe_nom'] as String, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _ouvrirAppel(context, c);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _ouvrirAppel(BuildContext context, Map<String, dynamic> classe) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AppelPresenceScreen(
          classeId: classe['classe_id'] as int,
          classeNom: classe['classe_nom'] as String,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// Petits états d'affichage internes à cet écran
// ══════════════════════════════════════════════════════════
class _EtatChargementPanel extends StatelessWidget {
  const _EtatChargementPanel();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: SSMPalette.indigo),
        ),
      ),
    );
  }
}

class _EtatVide extends StatelessWidget {
  final IconData icone;
  final String texte;

  const _EtatVide({required this.icone, required this.texte});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Center(
        child: Column(
          children: [
            Icon(icone, size: 22, color: SSMPalette.texte3),
            const SizedBox(height: 6),
            Text(texte, style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte3)),
          ],
        ),
      ),
    );
  }
}

// ── Formatage (pas de dépendance intl dans ce projet) ──

const _mois = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];
const _jours = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];

String _formaterDateComplete(DateTime date) {
  final jour = _jours[date.weekday - 1];
  final moisNom = _mois[date.month - 1];
  final jourCapitalise = jour[0].toUpperCase() + jour.substring(1);
  return '$jourCapitalise ${date.day} $moisNom ${date.year}';
}
