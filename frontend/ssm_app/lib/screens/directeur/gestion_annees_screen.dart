import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/utilisateur.dart';
import '../../services/annee_service.dart';
import '../../services/auth_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_alert_item.dart';
import '../../widgets/ssm/ssm_page_scaffold.dart';
import '../../widgets/ssm/ssm_panel.dart';
import '../../widgets/ssm/ssm_pill.dart';
import '../../widgets/ssm/ssm_sidebar.dart';
import '../../widgets/ssm/ssm_stat_card.dart';

const List<String> _moisLongs = [
  '',
  'Janvier',
  'Février',
  'Mars',
  'Avril',
  'Mai',
  'Juin',
  'Juillet',
  'Août',
  'Septembre',
  'Octobre',
  'Novembre',
  'Décembre',
];

const Map<String, List<Map<String, String>>> _definitionsPeriodes = {
  'trimestres': [
    {'nom': '1er Trimestre', 'code': 'T1'},
    {'nom': '2ème Trimestre', 'code': 'T2'},
    {'nom': '3ème Trimestre', 'code': 'T3'},
  ],
  'semestres': [
    {'nom': 'Semestre 1', 'code': 'S1'},
    {'nom': 'Semestre 2', 'code': 'S2'},
  ],
};

String _formatDateLongue(DateTime d) =>
    '${d.day} ${_moisLongs[d.month]} ${d.year}';

String _formatDateApi(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _formatDateCourt(String? iso) {
  if (iso == null) return '—';
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

String _formatDateHeure(String? iso) {
  if (iso == null) return '—';
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '${_formatDateCourt(iso)} à $h:$m';
}

Color _couleurStatutAnnee(String statut) {
  switch (statut) {
    case 'active':
      return SSMPalette.teal;
    case 'cloturee':
      return SSMPalette.ambre;
    case 'archivee':
      return SSMPalette.texte3;
    default:
      return SSMPalette.texte3;
  }
}

String _labelStatutAnnee(String statut) {
  switch (statut) {
    case 'active':
      return '● Active';
    case 'cloturee':
      return 'Clôturée';
    case 'archivee':
      return 'Archivée';
    default:
      return 'En préparation';
  }
}

Color _couleurStatutPeriode(String statut) {
  switch (statut) {
    case 'ouverte':
      return SSMPalette.teal;
    case 'en_veille':
      return SSMPalette.ambre;
    case 'en_validation':
      return SSMPalette.indigo;
    case 'cloturee':
      return SSMPalette.rouge;
    case 'archivee':
      return SSMPalette.texte3;
    default:
      return SSMPalette.texte3;
  }
}

String _labelStatutPeriode(String statut) {
  switch (statut) {
    case 'ouverte':
      return 'OUVERTE';
    case 'en_veille':
      return 'EN VEILLE';
    case 'en_validation':
      return 'EN VALIDATION';
    case 'cloturee':
      return 'CLÔTURÉE';
    case 'archivee':
      return 'ARCHIVÉE';
    default:
      return 'PRÉPARATION';
  }
}

Color _couleurAction(String action) {
  switch (action) {
    case 'creation':
      return SSMPalette.indigo;
    case 'activation':
      return SSMPalette.teal;
    case 'ouverture':
      return SSMPalette.teal;
    case 'cloture':
      return SSMPalette.rouge;
    case 'reouverture':
      return SSMPalette.ambre;
    case 'generation_bulletins':
      return SSMPalette.ambre;
    case 'passage_eleves':
      return SSMPalette.indigo;
    default:
      return SSMPalette.texte3;
  }
}

IconData _iconeAction(String action) {
  switch (action) {
    case 'creation':
      return Icons.add_circle_outline;
    case 'activation':
      return Icons.play_circle_outline;
    case 'ouverture':
      return Icons.lock_open;
    case 'cloture':
      return Icons.lock_outline;
    case 'reouverture':
      return Icons.restart_alt;
    case 'generation_bulletins':
      return Icons.picture_as_pdf_outlined;
    case 'passage_eleves':
      return Icons.trending_up;
    case 'archivage':
      return Icons.archive_outlined;
    default:
      return Icons.circle;
  }
}

String _labelAction(String action) {
  switch (action) {
    case 'creation':
      return 'Création';
    case 'activation':
      return 'Activation';
    case 'ouverture':
      return 'Ouverture de période';
    case 'cloture':
      return 'Clôture';
    case 'reouverture':
      return 'Réouverture';
    case 'generation_bulletins':
      return 'Génération des bulletins';
    case 'passage_eleves':
      return 'Passage des élèves';
    case 'archivage':
      return 'Archivage';
    default:
      return action;
  }
}

enum _OngletAnnees { tableauDeBord, annees, journal }

class GestionAnneesScreen extends StatefulWidget {
  const GestionAnneesScreen({super.key});

  @override
  State<GestionAnneesScreen> createState() => _GestionAnneesScreenState();
}

class _GestionAnneesScreenState extends State<GestionAnneesScreen> {
  _OngletAnnees _onglet = _OngletAnnees.tableauDeBord;

  Utilisateur? _utilisateur;

  bool _chargement = true;
  Map<String, dynamic>? _tableauDeBord;
  List<dynamic> _annees = [];
  List<dynamic> _journal = [];

  @override
  void initState() {
    super.initState();
    AuthService.getUtilisateur().then((u) {
      if (mounted) setState(() => _utilisateur = u);
    });
    _chargerTout();
  }

  Future<void> _chargerTout() async {
    setState(() => _chargement = true);
    try {
      final resultats = await Future.wait([
        AnneeService.tableauDeBord(),
        AnneeService.listerAnnees(),
        AnneeService.journal(),
      ]);
      setState(() {
        _tableauDeBord = resultats[0] as Map<String, dynamic>;
        _annees = resultats[1] as List<dynamic>;
        _journal = resultats[2] as List<dynamic>;
        _chargement = false;
      });
    } catch (e) {
      setState(() => _chargement = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _afficherErreur(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: SSMPalette.rouge),
    );
  }

  void _afficherSucces(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: SSMPalette.teal),
    );
  }

  void _naviguer(BuildContext context, String route) {
    if (route == '/directeur/annees') return;
    Navigator.pushNamed(context, route);
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

  List<SSMNavSection> _sections() {
    return [
      SSMNavSection(titre: 'Principal', items: [
        const SSMNavItem(icone: Icons.dashboard_outlined, label: 'Tableau de bord', route: '/tableau-de-bord'),
        const SSMNavItem(icone: Icons.people_outline, label: 'Élèves', route: '/directeur/eleves'),
        const SSMNavItem(icone: Icons.grade_outlined, label: 'Notes & évaluations', route: '/notes'),
        const SSMNavItem(icone: Icons.price_change_outlined, label: 'Frais scolaires', route: '/directeur/frais'),
        const SSMNavItem(icone: Icons.calendar_view_week_outlined, label: 'Emploi du temps', route: '/emploi-du-temps'),
        const SSMNavItem(icone: Icons.description_outlined, label: 'Bulletins PDF', route: '/bulletins'),
      ]),
      SSMNavSection(titre: 'Pilotage', items: [
        const SSMNavItem(icone: Icons.bar_chart_outlined, label: 'Statistiques', route: '/statistiques'),
        const SSMNavItem(icone: Icons.notifications_outlined, label: 'Notifications', route: '/notifications'),
        const SSMNavItem(icone: Icons.settings_outlined, label: 'Paramètres école', route: '/parametres'),
      ]),
      if (_utilisateur?.role == 'directeur')
        const SSMNavSection(titre: 'Administration', items: [
          SSMNavItem(icone: Icons.people_alt_outlined, label: 'Utilisateurs', route: '/directeur/utilisateurs'),
          SSMNavItem(icone: Icons.class_outlined, label: 'Classes', route: '/directeur/classes'),
          SSMNavItem(icone: Icons.menu_book_outlined, label: 'Matières', route: '/directeur/matieres'),
          SSMNavItem(icone: Icons.calendar_month_outlined, label: 'Années & Périodes', route: '/directeur/annees'),
        ]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return SSMPageScaffold(
      nomEcole: _utilisateur?.codeEcole ?? 'Mon établissement',
      codeEcole: _utilisateur?.codeEcole ?? '—',
      nomUtilisateur: _utilisateur?.nom ?? '…',
      role: _libelleRole(_utilisateur?.role),
      sections: _sections(),
      routeActuelle: '/directeur/annees',
      onNavigate: (route) => _naviguer(context, route),
      onProfilTap: () => Navigator.pushNamed(context, '/profil'),
      breadcrumb: 'Accueil',
      breadcrumbActuel: 'Années & Périodes',
      child: _chargement
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: Center(child: CircularProgressIndicator(color: SSMPalette.indigo)),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Années & Périodes',
                  style: GoogleFonts.sora(fontSize: 19, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
                ),
                const SizedBox(height: 12),
                _segments(),
                const SizedBox(height: 16),
                switch (_onglet) {
                  _OngletAnnees.tableauDeBord => _ongletTableauDeBord(),
                  _OngletAnnees.annees => _ongletAnnees(),
                  _OngletAnnees.journal => _ongletJournal(),
                },
              ],
            ),
    );
  }

  Widget _segments() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(SSMRayons.moyen)),
      child: Row(
        children: [
          Expanded(child: _segment('📊 Tableau de bord', _OngletAnnees.tableauDeBord)),
          Expanded(child: _segment('📅 Années', _OngletAnnees.annees)),
          Expanded(child: _segment('📋 Journal', _OngletAnnees.journal)),
        ],
      ),
    );
  }

  Widget _segment(String label, _OngletAnnees valeur) {
    final actif = _onglet == valeur;
    return GestureDetector(
      onTap: () => setState(() => _onglet = valeur),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: actif ? SSMPalette.blanc : Colors.transparent,
          borderRadius: BorderRadius.circular(SSMRayons.petit),
          boxShadow: actif ? SSMOmbres.legere : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: actif ? FontWeight.w600 : FontWeight.w400,
            color: actif ? SSMPalette.indigo : SSMPalette.texte2,
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // ONGLET 1 — TABLEAU DE BORD
  // ══════════════════════════════════════════════════════

  Widget _ongletTableauDeBord() {
    final tdb = _tableauDeBord ?? {};
    final annee = tdb['annee_active'] as Map<String, dynamic>?;
    final periode = tdb['periode_active'] as Map<String, dynamic>?;
    final joursRestants = tdb['jours_restants_periode'] as int?;
    final classesTerminees = tdb['classes_notes_terminees'] as int? ?? 0;
    final totalClasses = tdb['total_classes'] as int? ?? 0;
    final bulletinsGeneres = tdb['bulletins_generes'] as int? ?? 0;
    final totalEleves = tdb['total_eleves'] as int? ?? 0;
    final alertes = tdb['alertes'] as List? ?? [];
    final enseignantsRetard = tdb['enseignants_en_retard'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (annee == null)
          _carteAucuneAnneeActive()
        else ...[
          _banniereAnneeActive(annee, periode, joursRestants),
          const SizedBox(height: 16),
          _grilleStats(
            annee: annee,
            periode: periode,
            joursRestants: joursRestants,
            classesTerminees: classesTerminees,
            totalClasses: totalClasses,
            bulletinsGeneres: bulletinsGeneres,
            totalEleves: totalEleves,
          ),
        ],
        if (alertes.isNotEmpty) ...[
          const SizedBox(height: 20),
          SSMPanel(
            titre: '⚠️ Alertes',
            child: Column(
              children: [
                for (final a in alertes) ...[
                  _alerteItem(a as Map<String, dynamic>),
                  if (a != alertes.last) const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
        if (enseignantsRetard.isNotEmpty) ...[
          const SizedBox(height: 20),
          SSMPanel(
            titre: 'Enseignants — Saisie des notes',
            lienAction: periode != null ? 'Voir tout' : null,
            onLienAction: periode != null ? () => _dialogEtatEnseignants(periode['id'] as int) : null,
            child: _tableauEnseignants(enseignantsRetard),
          ),
        ],
        if (periode != null && periode['statut'] == 'ouverte') ...[
          const SizedBox(height: 20),
          _carteActionsPeriode(periode),
        ],
      ],
    );
  }

  Widget _carteAucuneAnneeActive() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: SSMPalette.rougeClair,
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        border: Border.all(color: SSMPalette.rouge.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: SSMPalette.rouge, size: 44),
          const SizedBox(height: 12),
          Text(
            'Aucune année scolaire active',
            style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: SSMPalette.rouge),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.indigo, foregroundColor: Colors.white),
            onPressed: _dialogCreerAnnee,
            icon: const Icon(Icons.add),
            label: const Text('Créer une année'),
          ),
        ],
      ),
    );
  }

  Widget _alerteItem(Map<String, dynamic> alerte) {
    final type = alerte['type']?.toString() ?? 'info';
    final alerteType = switch (type) {
      'critique' => SSMAlerteType.danger,
      'avertissement' => SSMAlerteType.avertissement,
      _ => SSMAlerteType.succes,
    };
    final icone = switch (type) {
      'critique' => Icons.error_outline,
      'avertissement' => Icons.warning_amber,
      _ => Icons.info_outline,
    };

    return SSMAlertItem(
      type: alerteType,
      icone: icone,
      titre: alerte['message']?.toString() ?? '',
      sousTitre: '',
    );
  }

  Widget _banniereAnneeActive(
    Map<String, dynamic> annee,
    Map<String, dynamic>? periode,
    int? joursRestants,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SSMPalette.indigo,
        borderRadius: BorderRadius.circular(SSMRayons.grand),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.circle, size: 9, color: SSMPalette.teal),
                    const SizedBox(width: 6),
                    Text(
                      'ANNÉE ACTIVE',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  annee['libelle']?.toString() ?? '',
                  style: GoogleFonts.sora(fontSize: 21, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatDateCourt(annee['date_debut']?.toString())} → ${_formatDateCourt(annee['date_fin']?.toString())}',
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.72)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(SSMRayons.moyen),
            ),
            constraints: const BoxConstraints(minWidth: 140),
            child: periode != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        periode['nom']?.toString() ?? '',
                        style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      SSMPill.couleur(label: _labelStatutPeriode(periode['statut']?.toString() ?? ''), couleur: Colors.white),
                      const SizedBox(height: 8),
                      Text(
                        joursRestants != null ? '$joursRestants j.' : '—',
                        style: GoogleFonts.sora(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (joursRestants != null && joursRestants > 0) ? null : 0,
                          minHeight: 4,
                          backgroundColor: Colors.white.withValues(alpha: 0.22),
                          color: Colors.white,
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      const Icon(Icons.warning_amber, color: SSMPalette.ambre, size: 26),
                      const SizedBox(height: 4),
                      Text(
                        'Aucune période active',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _grilleStats({
    required Map<String, dynamic> annee,
    required Map<String, dynamic>? periode,
    required int? joursRestants,
    required int classesTerminees,
    required int totalClasses,
    required int bulletinsGeneres,
    required int totalEleves,
  }) {
    final pourcentageNotes = totalClasses > 0 ? (classesTerminees / totalClasses * 100).round() : 0;
    final couleurNotes = pourcentageNotes >= 100 ? SSMPalette.teal : (pourcentageNotes > 50 ? SSMPalette.ambre : SSMPalette.rouge);
    final pourcentageBulletins = totalEleves > 0 ? (bulletinsGeneres / totalEleves * 100).round() : 0;

    return LayoutBuilder(builder: (context, contraintes) {
      final colonnes = contraintes.maxWidth >= 900 ? 5 : (contraintes.maxWidth >= 620 ? 3 : (contraintes.maxWidth >= 400 ? 2 : 1));
      final cartes = [
        _carteStatut(
          icone: Icons.calendar_today,
          couleur: SSMPalette.indigo,
          label: 'Année',
          valeur: annee['libelle']?.toString() ?? 'Aucune',
          badge: _labelStatutAnnee(annee['statut']?.toString() ?? ''),
          badgeCouleur: _couleurStatutAnnee(annee['statut']?.toString() ?? ''),
        ),
        _carteStatut(
          icone: Icons.segment,
          couleur: SSMPalette.teal,
          label: 'Période',
          valeur: periode?['nom']?.toString() ?? 'Aucune',
          badge: periode != null ? _labelStatutPeriode(periode['statut']?.toString() ?? '') : null,
          badgeCouleur: _couleurStatutPeriode(periode?['statut']?.toString() ?? ''),
        ),
        SSMStatCard(
          icone: Icons.hourglass_empty,
          couleur: SSMPalette.ambre,
          valeur: joursRestants != null ? '$joursRestants' : '—',
          label: 'Jours restants',
        ),
        SSMStatCard(
          icone: Icons.assignment,
          couleur: couleurNotes,
          valeur: '$pourcentageNotes%',
          label: 'Notes terminées ($classesTerminees/$totalClasses classes)',
        ),
        SSMStatCard(
          icone: Icons.description,
          couleur: SSMPalette.teal,
          valeur: '$pourcentageBulletins%',
          label: 'Bulletins générés ($bulletinsGeneres/$totalEleves)',
        ),
      ];
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

  Widget _carteStatut({
    required IconData icone,
    required Color couleur,
    required String label,
    required String valeur,
    String? badge,
    Color? badgeCouleur,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: SSMPalette.blanc,
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        border: Border.all(color: SSMPalette.bordure),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: couleur.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
            child: Icon(icone, size: 17, color: couleur),
          ),
          const SizedBox(height: 10),
          Text(
            valeur,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: SSMPalette.texte1),
          ),
          const SizedBox(height: 3),
          Text(label, style: GoogleFonts.inter(fontSize: 11.5, color: SSMPalette.texte2)),
          if (badge != null) ...[
            const SizedBox(height: 6),
            SSMPill.couleur(label: badge, couleur: badgeCouleur ?? SSMPalette.texte3),
          ],
        ],
      ),
    );
  }

  Widget _tableauEnseignants(List enseignants) {
    final lignes = enseignants.take(6).toList();
    return Column(
      children: [
        for (int i = 0; i < lignes.length; i++) ...[
          if (i > 0) const Divider(height: 16),
          _ligneEnseignant(lignes[i] as Map<String, dynamic>),
        ],
      ],
    );
  }

  Widget _ligneEnseignant(Map<String, dynamic> ligne) {
    final pourcentage = ligne['pourcentage'] as int? ?? 0;
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            ligne['enseignant_nom']?.toString() ?? '',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: SSMPalette.texte1),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            ligne['matiere_nom']?.toString() ?? '',
            style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            ligne['classe_nom']?.toString() ?? '',
            style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          flex: 3,
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pourcentage / 100,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFF1F5F9),
                    color: pourcentage >= 100 ? SSMPalette.teal : SSMPalette.ambre,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text('$pourcentage%', style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte2)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _carteActionsPeriode(Map<String, dynamic> periode) {
    return SSMPanel(
      titre: 'Actions sur la période',
      child: Column(
        children: [
          _boutonAction(
            label: 'Mettre en validation',
            icone: Icons.pending_actions,
            couleur: SSMPalette.ambre,
            onTap: () => _confirmerMettreEnValidation(periode),
          ),
          const SizedBox(height: 10),
          _boutonAction(
            label: 'Générer les bulletins en masse',
            icone: Icons.picture_as_pdf,
            couleur: SSMPalette.teal,
            onTap: () => _confirmerGenererBulletins(periode),
          ),
          const SizedBox(height: 10),
          _boutonAction(
            label: 'Clôturer la période',
            icone: Icons.lock,
            couleur: SSMPalette.rouge,
            onTap: () => _dialogCloturerPeriode(periode),
          ),
        ],
      ),
    );
  }

  Widget _boutonAction({
    required String label,
    required IconData icone,
    required Color couleur,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: couleur,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
        ),
        onPressed: onTap,
        icon: Icon(icone, size: 18),
        label: Text(label),
      ),
    );
  }

  Future<void> _confirmerMettreEnValidation(Map<String, dynamic> periode) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
        backgroundColor: SSMPalette.blanc,
        title: const Text('Mettre en validation'),
        content: const Text("Les enseignants ne pourront plus modifier leurs notes. Continuer ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.ambre, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AnneeService.mettreEnValidation(periode['id'] as int);
      _afficherSucces('Période mise en validation');
      _chargerTout();
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _confirmerGenererBulletins(Map<String, dynamic> periode) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
        backgroundColor: SSMPalette.blanc,
        title: const Text('Générer les bulletins'),
        content: const Text('Générer les bulletins pour tous les élèves de la période ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.teal, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Générer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: SSMPalette.teal)),
    );
    try {
      final res = await AnneeService.genererBulletinsEnMasse(periode['id'] as int);
      if (mounted) Navigator.pop(context);
      _afficherSucces('${res['bulletins_generes']} bulletins générés avec succès');
      _chargerTout();
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _dialogEtatEnseignants(int periodeId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: SSMPalette.indigo)),
    );
    try {
      final data = await AnneeService.etatEnseignants(periodeId);
      if (mounted) Navigator.pop(context);
      final lignes = data['enseignants'] as List? ?? [];
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: SSMPalette.blanc,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(SSMRayons.grand))),
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('État des enseignants', style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: lignes.length,
                    separatorBuilder: (_, _) => const Divider(height: 16),
                    itemBuilder: (context, i) {
                      final l = lignes[i] as Map<String, dynamic>;
                      final pourcentage = l['pourcentage'] as int? ?? 0;
                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l['enseignant_nom']?.toString() ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
                                Text('${l['matiere_nom']} · ${l['classe_nom']}', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
                              ],
                            ),
                          ),
                          SSMPill.couleur(label: '$pourcentage%', couleur: pourcentage >= 100 ? SSMPalette.teal : SSMPalette.ambre),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ══════════════════════════════════════════════════════
  // ONGLET 2 — ANNÉES
  // ══════════════════════════════════════════════════════

  Widget _ongletAnnees() {
    final triees = [..._annees]..sort((a, b) {
        final da = DateTime.tryParse(a['date_debut']?.toString() ?? '');
        final db = DateTime.tryParse(b['date_debut']?.toString() ?? '');
        if (da == null || db == null) return 0;
        return db.compareTo(da);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.indigo, foregroundColor: Colors.white),
            onPressed: _dialogCreerAnnee,
            icon: const Icon(Icons.add),
            label: const Text('Nouvelle année'),
          ),
        ),
        const SizedBox(height: 16),
        for (final a in triees) ...[
          _carteAnnee(a as Map<String, dynamic>),
          if (a != triees.last) const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _carteAnnee(Map<String, dynamic> annee) {
    final statut = annee['statut']?.toString() ?? 'en_preparation';
    final couleur = _couleurStatutAnnee(statut);
    final periodes = annee['periodes'] as List? ?? [];

    return Material(
      color: SSMPalette.blanc,
      borderRadius: BorderRadius.circular(SSMRayons.grand),
      child: InkWell(
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        onTap: () => Navigator.pushNamed(
          context,
          '/directeur/annee/fiche',
          arguments: {
            'anneeId': annee['id'] as int,
            'libelle': annee['libelle']?.toString() ?? '',
            'statut': statut,
          },
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SSMRayons.grand),
            border: Border(
              top: BorderSide(color: SSMPalette.bordure),
              right: BorderSide(color: SSMPalette.bordure),
              bottom: BorderSide(color: SSMPalette.bordure),
              left: BorderSide(color: couleur, width: 4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        annee['libelle']?.toString() ?? '',
                        style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: SSMPalette.texte1),
                      ),
                    ),
                    SSMPill.couleur(label: _labelStatutAnnee(statut), couleur: couleur),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatDateCourt(annee['date_debut']?.toString())} → ${_formatDateCourt(annee['date_fin']?.toString())}',
                  style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2),
                ),
                Text(
                  'Type : ${annee['type_periodes'] == 'semestres' ? 'Semestres' : 'Trimestres'}',
                  style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2),
                ),
                if (periodes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: periodes.map((p) {
                      final periode = p as Map<String, dynamic>;
                      final pc = _couleurStatutPeriode(periode['statut']?.toString() ?? '');
                      return SSMPill.couleur(label: '${periode['code'] ?? ''} ${periode['nom'] ?? ''}', couleur: pc);
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text('${annee['nombre_eleves'] ?? 0} élèves', style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte3)),
                    const SizedBox(width: 8),
                    Text('·', style: GoogleFonts.inter(color: SSMPalette.texte3)),
                    const SizedBox(width: 8),
                    Text('${annee['nombre_classes'] ?? 0} classes', style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte3)),
                    const SizedBox(width: 8),
                    Text('·', style: GoogleFonts.inter(color: SSMPalette.texte3)),
                    const SizedBox(width: 8),
                    Text('${annee['nombre_enseignants'] ?? 0} enseignants', style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte3)),
                  ],
                ),
                const SizedBox(height: 12),
                _actionsAnnee(annee, statut),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionsAnnee(Map<String, dynamic> annee, String statut) {
    switch (statut) {
      case 'en_preparation':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.teal, foregroundColor: Colors.white),
            onPressed: () => _confirmerActiverAnnee(annee),
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Activer'),
          ),
        );
      case 'active':
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.indigo, foregroundColor: Colors.white),
                onPressed: () => _dialogGererPeriodes(annee),
                icon: const Icon(Icons.segment, size: 18),
                label: const Text('Gérer les périodes'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: SSMPalette.rouge, side: const BorderSide(color: SSMPalette.rouge, width: 1.5)),
                onPressed: () => _dialogCloturerAnnee(annee),
                icon: const Icon(Icons.lock, size: 18),
                label: const Text("Clôturer l'année"),
              ),
            ),
          ],
        );
      case 'cloturee':
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.teal, foregroundColor: Colors.white),
              onPressed: () => Navigator.pushNamed(
                context,
                '/directeur/annee/fiche',
                arguments: {
                  'anneeId': annee['id'] as int,
                  'libelle': annee['libelle']?.toString() ?? '',
                  'statut': statut,
                },
              ),
              icon: const Icon(Icons.bar_chart, size: 18),
              label: const Text('Voir le bilan'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.indigo, foregroundColor: Colors.white),
              onPressed: () => _dialogPasserEleves(annee),
              icon: const Icon(Icons.trending_up, size: 18),
              label: const Text('Passer les élèves'),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: SSMPalette.texte2, side: const BorderSide(color: Color(0xFFE5E7EB))),
              onPressed: () => _confirmerArchiverAnnee(annee),
              icon: const Icon(Icons.archive_outlined, size: 18),
              label: const Text('Archiver'),
            ),
          ],
        );
      case 'archivee':
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: SSMPalette.texte2, side: const BorderSide(color: Color(0xFFE5E7EB))),
            onPressed: () => Navigator.pushNamed(
              context,
              '/directeur/annee/fiche',
              arguments: {
                'anneeId': annee['id'] as int,
                'libelle': annee['libelle']?.toString() ?? '',
                'statut': statut,
              },
            ),
            icon: const Icon(Icons.folder_open, size: 18),
            label: const Text('Consulter les archives'),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _confirmerActiverAnnee(Map<String, dynamic> annee) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
        backgroundColor: SSMPalette.blanc,
        title: const Text('Activer cette année'),
        content: Text('Activer "${annee['libelle']}" ? Une seule année peut être active à la fois.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.teal, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Activer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AnneeService.activerAnnee(annee['id'] as int);
      _afficherSucces('Année activée avec succès');
      _chargerTout();
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _confirmerArchiverAnnee(Map<String, dynamic> annee) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
        backgroundColor: SSMPalette.blanc,
        title: const Text('Archiver cette année'),
        content: Text('Archiver "${annee['libelle']}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.texte2, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archiver'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AnneeService.archiverAnnee(annee['id'] as int);
      _afficherSucces('Année archivée avec succès');
      _chargerTout();
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ══════════════════════════════════════════════════════
  // ONGLET 3 — JOURNAL
  // ══════════════════════════════════════════════════════

  Widget _ongletJournal() {
    if (_journal.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text('Aucune action enregistrée pour le moment.', style: GoogleFonts.inter(color: SSMPalette.texte3)),
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < _journal.length; i++) ...[
          _carteJournal(_journal[i] as Map<String, dynamic>),
          if (i < _journal.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _carteJournal(Map<String, dynamic> j) {
    final action = j['action']?.toString() ?? '';
    final couleur = _couleurAction(action);
    final details = j['details'] as Map<String, dynamic>?;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SSMPalette.blanc,
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        border: Border.all(color: SSMPalette.bordure),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: couleur.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(SSMRayons.moyen)),
            child: Icon(_iconeAction(action), color: couleur, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_labelAction(action), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
                Text(
                  '${j['entite_type']}${details != null && details['libelle'] != null ? ' : ${details['libelle']}' : details != null && details['periode_nom'] != null ? ' : ${details['periode_nom']}' : ''}',
                  style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2),
                ),
                const SizedBox(height: 2),
                Text(
                  'Par ${j['utilisateur_nom'] ?? '—'} · ${_formatDateHeure(j['created_at']?.toString())}',
                  style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // DIALOG — CRÉER UNE ANNÉE
  // ══════════════════════════════════════════════════════

  InputDecoration _decorationChamp(String label, {bool dense = false}) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2),
      isDense: dense,
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SSMRayons.moyen),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SSMRayons.moyen),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SSMRayons.moyen),
        borderSide: const BorderSide(color: SSMPalette.indigo, width: 1.5),
      ),
    );
  }

  void _dialogCreerAnnee() {
    final libelleController = TextEditingController();
    DateTime? dateDebut;
    DateTime? dateFin;
    String typePeriodes = 'auto';
    double reglePassage = 10;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          void genererLibelle() {
            if (dateDebut == null) return;
            final anneeDebut = dateDebut!.year;
            libelleController.text = '$anneeDebut-${anneeDebut + 1}';
          }

          final typeAffiche = typePeriodes == 'semestres' ? 'semestres' : 'trimestres';
          final apercu = _definitionsPeriodes[typeAffiche]!;

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
            backgroundColor: SSMPalette.blanc,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nouvelle année scolaire', style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: libelleController, decoration: _decorationChamp('Libellé *'))),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            genererLibelle();
                            setStateDialog(() {});
                          },
                          child: const Text('Générer'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: SSMPalette.texte1,
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
                            ),
                            onPressed: () async {
                              final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
                              if (d != null) setStateDialog(() => dateDebut = d);
                            },
                            child: Text(dateDebut != null ? _formatDateLongue(dateDebut!) : 'Date de début *'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: SSMPalette.texte1,
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
                            ),
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: dateDebut?.add(const Duration(days: 300)) ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (d != null) setStateDialog(() => dateFin = d);
                            },
                            child: Text(dateFin != null ? _formatDateLongue(dateFin!) : 'Date de fin *'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text('Type de périodes *', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: SSMPalette.texte2)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _optionType(
                          icone: Icons.auto_awesome,
                          titre: 'Automatique',
                          sousTitre: 'SSM détecte selon vos classes',
                          selectionne: typePeriodes == 'auto',
                          onTap: () => setStateDialog(() => typePeriodes = 'auto'),
                        ),
                        const SizedBox(width: 8),
                        _optionType(
                          icone: Icons.grid_view,
                          titre: '3 Trimestres',
                          sousTitre: 'Collège & Primaire',
                          selectionne: typePeriodes == 'trimestres',
                          onTap: () => setStateDialog(() => typePeriodes = 'trimestres'),
                        ),
                        const SizedBox(width: 8),
                        _optionType(
                          icone: Icons.calendar_view_month,
                          titre: '2 Semestres',
                          sousTitre: 'Lycée',
                          selectionne: typePeriodes == 'semestres',
                          onTap: () => setStateDialog(() => typePeriodes = 'semestres'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(SSMRayons.moyen),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            typePeriodes == 'auto' ? 'Périodes créées automatiquement (selon détection) :' : 'Périodes créées automatiquement :',
                            style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2),
                          ),
                          const SizedBox(height: 6),
                          ...apercu.map(
                            (p) => Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text('📅 ${p['nom']} (${p['code']})', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte1)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Moyenne minimale de passage :', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: SSMPalette.texte2)),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: reglePassage,
                            min: 0,
                            max: 20,
                            divisions: 40,
                            activeColor: SSMPalette.indigo,
                            onChanged: (v) => setStateDialog(() => reglePassage = v),
                          ),
                        ),
                        Text('${reglePassage.toStringAsFixed(1)}/20', style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('Annuler', style: GoogleFonts.inter(color: SSMPalette.texte2)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: SSMPalette.indigo,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
                            ),
                            onPressed: libelleController.text.trim().isEmpty || dateDebut == null || dateFin == null
                                ? null
                                : () async {
                                    try {
                                      await AnneeService.creerAnnee(
                                        libelle: libelleController.text.trim(),
                                        dateDebut: _formatDateApi(dateDebut!),
                                        dateFin: _formatDateApi(dateFin!),
                                        typePeriodes: typePeriodes,
                                      );
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                      }
                                      _afficherSucces('Année créée avec succès');
                                      _chargerTout();
                                    } catch (e) {
                                      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
                                    }
                                  },
                            child: const Text("Créer l'année"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _optionType({
    required IconData icone,
    required String titre,
    required String sousTitre,
    required bool selectionne,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(SSMRayons.moyen),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: selectionne ? SSMPalette.indigoClair : null,
            border: Border.all(color: selectionne ? SSMPalette.indigo : const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(SSMRayons.moyen),
          ),
          child: Column(
            children: [
              Icon(icone, color: selectionne ? SSMPalette.indigo : SSMPalette.texte3, size: 22),
              const SizedBox(height: 6),
              Text(titre, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
              Text(sousTitre, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 10, color: SSMPalette.texte3)),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // DIALOG — GÉRER LES PÉRIODES
  // ══════════════════════════════════════════════════════

  void _dialogGererPeriodes(Map<String, dynamic> annee) async {
    List<dynamic> periodes = [];
    bool chargement = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          Future<void> charger() async {
            try {
              final data = await AnneeService.listerPeriodes(annee['id'] as int);
              setStateDialog(() {
                periodes = data;
                chargement = false;
              });
            } catch (e) {
              setStateDialog(() => chargement = false);
            }
          }

          if (chargement) {
            charger();
          }

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
            backgroundColor: SSMPalette.blanc,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Périodes — ${annee['libelle']}', style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
                    Text(
                      'Type : ${annee['type_periodes'] == 'semestres' ? 'Semestres' : 'Trimestres'}',
                      style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: chargement
                          ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
                          : ListView.separated(
                              itemCount: periodes.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                final p = periodes[i] as Map<String, dynamic>;
                                return _cartePeriodeDialog(p, setStateDialog, () {
                                  setStateDialog(() => chargement = true);
                                });
                              },
                            ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Fermer', style: GoogleFonts.inter(color: SSMPalette.texte2)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ).then((_) => _chargerTout());
  }

  Widget _cartePeriodeDialog(
    Map<String, dynamic> periode,
    void Function(void Function()) setStateDialog,
    VoidCallback recharger,
  ) {
    final statut = periode['statut']?.toString() ?? 'preparation';
    final couleur = _couleurStatutPeriode(statut);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        border: Border.all(color: couleur.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: couleur, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${periode['nom']} (${periode['code'] ?? '—'})',
                  style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: SSMPalette.texte1),
                ),
              ),
              SSMPill.couleur(label: _labelStatutPeriode(statut), couleur: couleur),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${_formatDateCourt(periode['date_debut']?.toString())} → ${_formatDateCourt(periode['date_fin']?.toString())}',
            style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _actionsPeriodeDialog(periode, statut, setStateDialog, recharger),
          ),
        ],
      ),
    );
  }

  List<Widget> _actionsPeriodeDialog(
    Map<String, dynamic> periode,
    String statut,
    void Function(void Function()) setStateDialog,
    VoidCallback recharger,
  ) {
    Future<void> executer(Future<void> Function() action) async {
      try {
        await action();
        _afficherSucces('Action effectuée avec succès');
        recharger();
      } catch (e) {
        _afficherErreur(e.toString().replaceAll('Exception: ', ''));
      }
    }

    switch (statut) {
      case 'preparation':
        return [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.teal, foregroundColor: Colors.white),
            onPressed: () => executer(() => AnneeService.ouvrirPeriode(periode['id'] as int)),
            child: const Text('Ouvrir'),
          ),
        ];
      case 'ouverte':
        return [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.ambre, foregroundColor: Colors.white),
            onPressed: () => executer(() => AnneeService.mettreEnValidation(periode['id'] as int)),
            child: const Text('Mettre en validation'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.rouge, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              _dialogCloturerPeriode(periode);
            },
            child: const Text('Fermer'),
          ),
        ];
      case 'en_veille':
        return [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.indigo, foregroundColor: Colors.white),
            onPressed: () => executer(() => AnneeService.ouvrirPeriode(periode['id'] as int)),
            child: const Text('Réactiver'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.rouge, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              _dialogCloturerPeriode(periode);
            },
            child: const Text('Fermer'),
          ),
        ];
      case 'en_validation':
        return [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.rouge, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              _dialogCloturerPeriode(periode);
            },
            child: const Text('Clôturer'),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: SSMPalette.ambre, side: const BorderSide(color: SSMPalette.ambre)),
            onPressed: () {
              Navigator.pop(context);
              _dialogReouvrirPeriode(periode);
            },
            child: const Text('Rouvrir'),
          ),
        ];
      case 'cloturee':
        return [
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: SSMPalette.ambre, side: const BorderSide(color: SSMPalette.ambre)),
            onPressed: () {
              Navigator.pop(context);
              _dialogReouvrirPeriode(periode);
            },
            child: const Text('Rouvrir (exceptionnel)'),
          ),
        ];
      default:
        return [];
    }
  }

  // ══════════════════════════════════════════════════════
  // DIALOG — RÉOUVRIR UNE PÉRIODE (exceptionnel)
  // ══════════════════════════════════════════════════════

  void _dialogReouvrirPeriode(Map<String, dynamic> periode) {
    final motifController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
            backgroundColor: SSMPalette.blanc,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber, color: SSMPalette.ambre, size: 48),
                  const SizedBox(height: 12),
                  Text('Réouverture exceptionnelle', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
                  Text(periode['nom']?.toString() ?? '', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
                  const SizedBox(height: 4),
                  Text('Cette action est enregistrée dans le journal.', style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: motifController,
                    maxLines: 3,
                    decoration: _decorationChamp('Motif de réouverture *').copyWith(hintText: 'Expliquez pourquoi...'),
                    onChanged: (_) => setStateDialog(() {}),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Annuler', style: GoogleFonts.inter(color: SSMPalette.texte2)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.ambre, foregroundColor: Colors.white),
                          onPressed: motifController.text.trim().isEmpty
                              ? null
                              : () async {
                                  try {
                                    await AnneeService.reouvrir(periode['id'] as int, motifController.text.trim());
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                    }
                                    _afficherSucces('Période rouverte');
                                    _chargerTout();
                                  } catch (e) {
                                    _afficherErreur(e.toString().replaceAll('Exception: ', ''));
                                  }
                                },
                          child: const Text('Rouvrir'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // DIALOG — CLÔTURER UNE PÉRIODE (stepper 3 étapes)
  // ══════════════════════════════════════════════════════

  void _dialogCloturerPeriode(Map<String, dynamic> periode) {
    int etape = 0;
    Map<String, dynamic>? verification;
    bool chargementVerif = true;
    bool genererBulletinsMaintenant = true;
    Map<String, dynamic>? resultat;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          Future<void> chargerVerification() async {
            try {
              final data = await AnneeService.verifierAvantCloture(periode['id'] as int);
              setStateDialog(() {
                verification = data;
                chargementVerif = false;
              });
            } catch (e) {
              setStateDialog(() => chargementVerif = false);
            }
          }

          if (chargementVerif && verification == null && etape == 0) {
            chargerVerification();
          }

          Widget contenu;
          if (etape == 0) {
            final incompletes = verification?['classes_incompletes'] as List? ?? [];
            final pret = verification?['pret_pour_cloture'] as bool? ?? false;

            contenu = chargementVerif
                ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: SSMPalette.indigo)))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(pret ? Icons.check_circle : Icons.error_outline, color: pret ? SSMPalette.teal : SSMPalette.rouge),
                          const SizedBox(width: 8),
                          Text(
                            pret ? 'Toutes les notes sont soumises' : 'Des notes sont manquantes',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: SSMPalette.texte1),
                          ),
                        ],
                      ),
                      if (!pret) ...[
                        const SizedBox(height: 12),
                        Text('Problèmes détectés', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: SSMPalette.rouge)),
                        const SizedBox(height: 6),
                        ...incompletes.map((c) {
                          final classe = c as Map<String, dynamic>;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.warning, color: SSMPalette.ambre, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${classe['classe_nom']} — ${classe['notes_manquantes']} note(s) manquante(s)',
                                    style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte1),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ] else ...[
                        const SizedBox(height: 12),
                        const Center(child: Icon(Icons.check_circle, color: SSMPalette.teal, size: 48)),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            'Tout est prêt pour la clôture !',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: SSMPalette.teal),
                          ),
                        ),
                      ],
                    ],
                  );
          } else if (etape == 1) {
            contenu = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('À la clôture, SSM va automatiquement :', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
                const SizedBox(height: 8),
                Text('✓ Calculer toutes les moyennes', style: GoogleFonts.inter(color: SSMPalette.texte1)),
                Text('✓ Calculer les rangs par classe', style: GoogleFonts.inter(color: SSMPalette.texte1)),
                Text('✓ Attribuer les mentions', style: GoogleFonts.inter(color: SSMPalette.texte1)),
                Text('✓ Préparer les bulletins', style: GoogleFonts.inter(color: SSMPalette.texte1)),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: genererBulletinsMaintenant,
                  activeThumbColor: SSMPalette.teal,
                  title: Text('Générer les bulletins maintenant', style: GoogleFonts.inter(color: SSMPalette.texte1)),
                  onChanged: (v) => setStateDialog(() => genererBulletinsMaintenant = v),
                ),
              ],
            );
          } else {
            contenu = Column(
              children: [
                const Icon(Icons.check_circle, color: SSMPalette.teal, size: 56),
                const SizedBox(height: 12),
                Text(
                  'Période clôturée avec succès !',
                  style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: SSMPalette.teal),
                ),
                const SizedBox(height: 12),
                Text('${resultat?['moyennes_calculees'] ?? 0} moyennes calculées', style: GoogleFonts.inter(color: SSMPalette.texte1)),
                Text('${resultat?['rangs_attribues'] ?? 0} rangs attribués', style: GoogleFonts.inter(color: SSMPalette.texte1)),
                if (genererBulletinsMaintenant && resultat?['bulletins_generes'] != null)
                  Text('${resultat?['bulletins_generes']} bulletins prêts', style: GoogleFonts.inter(color: SSMPalette.texte1)),
              ],
            );
          }

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
            backgroundColor: SSMPalette.blanc,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Clôturer — ${periode['nom']}', style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
                    const SizedBox(height: 16),
                    Flexible(child: SingleChildScrollView(child: contenu)),
                    const SizedBox(height: 20),
                    if (etape == 2)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.indigo, foregroundColor: Colors.white),
                          onPressed: () {
                            Navigator.pop(context);
                            _chargerTout();
                          },
                          child: const Text('Fermer'),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('Annuler', style: GoogleFonts.inter(color: SSMPalette.texte2)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: etape == 0 && !chargementVerif
                                    ? ((verification?['pret_pour_cloture'] == true) ? SSMPalette.indigo : SSMPalette.rouge)
                                    : SSMPalette.indigo,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: chargementVerif
                                  ? null
                                  : () async {
                                      if (etape == 0) {
                                        setStateDialog(() => etape = 1);
                                      } else if (etape == 1) {
                                        try {
                                          final res = await AnneeService.fermerPeriode(periode['id'] as int);
                                          if (genererBulletinsMaintenant) {
                                            final bulletinsRes = await AnneeService.genererBulletinsEnMasse(periode['id'] as int);
                                            res['bulletins_generes'] = bulletinsRes['bulletins_generes'];
                                          }
                                          setStateDialog(() {
                                            resultat = res;
                                            etape = 2;
                                          });
                                        } catch (e) {
                                          _afficherErreur(e.toString().replaceAll('Exception: ', ''));
                                        }
                                      }
                                    },
                              child: Text(
                                etape == 0
                                    ? (verification?['pret_pour_cloture'] == true ? 'Continuer' : 'Continuer quand même')
                                    : 'Clôturer la période',
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // DIALOG — PASSER LES ÉLÈVES (année déjà clôturée)
  // ══════════════════════════════════════════════════════

  void _dialogPasserEleves(Map<String, dynamic> annee) {
    _dialogPassageEleves(annee, cloturerApres: false);
  }

  // ══════════════════════════════════════════════════════
  // DIALOG — CLÔTURER L'ANNÉE (stepper 4 étapes)
  // ══════════════════════════════════════════════════════

  void _dialogCloturerAnnee(Map<String, dynamic> annee) {
    _dialogPassageEleves(annee, cloturerApres: true);
  }

  void _dialogPassageEleves(
    Map<String, dynamic> annee, {
    required bool cloturerApres,
  }) {
    int etape = 0;
    Map<String, dynamic>? stats;
    Map<String, dynamic>? apercu;
    bool chargement = true;
    bool passerAutomatique = true;
    final redoublants = <int>{};
    final diplomes = <int>{};
    Map<String, dynamic>? resultatPassage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          Future<void> charger() async {
            try {
              final resultats = await Future.wait([
                AnneeService.statistiquesAnnee(annee['id'] as int),
                AnneeService.apercuPassage(annee['id'] as int),
              ]);
              final apercuData = resultats[1];
              final eleves = apercuData['eleves'] as List? ?? [];
              setStateDialog(() {
                stats = resultats[0];
                apercu = apercuData;
                for (final e in eleves) {
                  final el = e as Map<String, dynamic>;
                  if (el['verdict'] == 'redoublant') {
                    redoublants.add(el['eleve_id'] as int);
                  }
                  if (el['est_terminale'] == true) {
                    diplomes.add(el['eleve_id'] as int);
                  }
                }
                chargement = false;
              });
            } catch (e) {
              setStateDialog(() => chargement = false);
            }
          }

          if (chargement && stats == null) {
            charger();
          }

          final eleves = (apercu?['eleves'] as List? ?? []).cast<Map<String, dynamic>>();
          final total = eleves.length;
          final passeront = total - redoublants.length - diplomes.length;

          Widget contenu;
          if (chargement) {
            contenu = const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: SSMPalette.indigo)));
          } else if (etape == 0) {
            contenu = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Bilan de l'année", style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
                const SizedBox(height: 12),
                Text('${stats?['nombre_eleves'] ?? 0} élèves', style: GoogleFonts.inter(color: SSMPalette.texte1)),
                Text('${stats?['nombre_classes'] ?? 0} classes', style: GoogleFonts.inter(color: SSMPalette.texte1)),
                Text('Taux de réussite : ${stats?['taux_reussite'] ?? 0}%', style: GoogleFonts.inter(color: SSMPalette.texte1)),
              ],
            );
          } else if (etape == 1) {
            contenu = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: passerAutomatique,
                  activeThumbColor: SSMPalette.indigo,
                  title: Text('Passage automatique selon les moyennes', style: GoogleFonts.inter(color: SSMPalette.texte1)),
                  onChanged: (v) => setStateDialog(() => passerAutomatique = v),
                ),
                if (passerAutomatique) ...[
                  Text(
                    'Règle : Moyenne ≥ ${annee['regle_passage_moyenne'] ?? 10}/20 → passage automatique',
                    style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2),
                  ),
                  const SizedBox(height: 8),
                  Text('$passeront élève(s) passeront automatiquement', style: GoogleFonts.inter(color: SSMPalette.texte1)),
                  Text('${redoublants.length} élève(s) redoubleront', style: GoogleFonts.inter(color: SSMPalette.texte1)),
                ],
                const SizedBox(height: 12),
                Text('Ajustements manuels', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: SSMPalette.texte1)),
                SizedBox(
                  height: 220,
                  child: ListView.builder(
                    itemCount: eleves.length,
                    itemBuilder: (context, i) {
                      final e = eleves[i];
                      final id = e['eleve_id'] as int;
                      return Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${e['nom']} ${e['prenom']}',
                              style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte1),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text('Redouble', style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte2)),
                          Checkbox(
                            value: redoublants.contains(id),
                            onChanged: (v) => setStateDialog(() {
                              if (v == true) {
                                redoublants.add(id);
                                diplomes.remove(id);
                              } else {
                                redoublants.remove(id);
                              }
                            }),
                          ),
                          Text('Diplômé', style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte2)),
                          Checkbox(
                            value: diplomes.contains(id),
                            onChanged: (v) => setStateDialog(() {
                              if (v == true) {
                                diplomes.add(id);
                                redoublants.remove(id);
                              } else {
                                diplomes.remove(id);
                              }
                            }),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          } else if (etape == 2) {
            contenu = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$passeront élève(s) passeront en classe supérieure', style: GoogleFonts.inter(color: SSMPalette.texte1)),
                Text('${redoublants.length} élève(s) redoubleront', style: GoogleFonts.inter(color: SSMPalette.texte1)),
                Text('${diplomes.length} élève(s) sont diplômés', style: GoogleFonts.inter(color: SSMPalette.texte1)),
              ],
            );
          } else {
            contenu = Column(
              children: [
                const Icon(Icons.check_circle, color: SSMPalette.teal, size: 56),
                const SizedBox(height: 12),
                Text(
                  cloturerApres ? 'Année "${annee['libelle']}" clôturée !' : 'Passage effectué avec succès !',
                  style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.teal),
                ),
                const SizedBox(height: 8),
                Text(
                  '${resultatPassage?['resultats']?['passes'] ?? 0} admis · '
                  '${resultatPassage?['resultats']?['redoublants'] ?? 0} redoublants · '
                  '${resultatPassage?['resultats']?['diplomes'] ?? 0} diplômés',
                  style: GoogleFonts.inter(color: SSMPalette.texte1),
                ),
              ],
            );
          }

          final derniereEtape = cloturerApres ? 3 : 2;

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
            backgroundColor: SSMPalette.blanc,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cloturerApres ? "Clôturer l'année" : 'Passage des élèves',
                      style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
                    ),
                    const SizedBox(height: 16),
                    Flexible(child: SingleChildScrollView(child: contenu)),
                    const SizedBox(height: 20),
                    if (etape == derniereEtape)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.indigo, foregroundColor: Colors.white),
                          onPressed: () {
                            Navigator.pop(context);
                            _chargerTout();
                          },
                          child: const Text('Fermer'),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('Annuler', style: GoogleFonts.inter(color: SSMPalette.texte2)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: (cloturerApres && etape == derniereEtape - 1) ? SSMPalette.rouge : SSMPalette.teal,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: chargement
                                  ? null
                                  : () async {
                                      final etapeFinale = cloturerApres ? 2 : 1;
                                      if (etape < etapeFinale) {
                                        setStateDialog(() => etape++);
                                        return;
                                      }
                                      try {
                                        final res = await AnneeService.passerEleves(
                                          annee['id'] as int,
                                          passerAutomatique: passerAutomatique,
                                          redoublants: redoublants.toList(),
                                          diplomes: diplomes.toList(),
                                        );
                                        if (cloturerApres) {
                                          await AnneeService.cloturerAnnee(annee['id'] as int);
                                        }
                                        setStateDialog(() {
                                          resultatPassage = res;
                                          etape = derniereEtape;
                                        });
                                      } catch (e) {
                                        _afficherErreur(e.toString().replaceAll('Exception: ', ''));
                                      }
                                    },
                              child: Text(
                                etape < (cloturerApres ? 2 : 1)
                                    ? 'Continuer'
                                    : (cloturerApres ? "Clôturer l'année" : 'Confirmer le passage'),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
