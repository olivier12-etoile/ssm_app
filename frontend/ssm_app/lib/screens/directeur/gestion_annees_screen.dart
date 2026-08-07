import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/annee_service.dart';
import '../../widgets/ssm_widgets.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _teal = Color(0xFF0D9488);
const Color _ambre = Color(0xFFD97706);
const Color _vert = Color(0xFF16A34A);
const Color _rouge = Color(0xFFDC2626);
const Color _orange = Color(0xFFEA580C);
const Color _violet = Color(0xFF7C3AED);
const Color _gris = Color(0xFF94A3B8);
const Color _grisFonce = Color(0xFF475569);
const Color _bleuInfo = Color(0xFF0284C7);

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
      return _vert;
    case 'cloturee':
      return _ambre;
    case 'archivee':
      return _grisFonce;
    default:
      return _gris;
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
      return _vert;
    case 'en_veille':
      return _ambre;
    case 'en_validation':
      return _orange;
    case 'cloturee':
      return _rouge;
    case 'archivee':
      return _grisFonce;
    default:
      return _gris;
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
      return _indigo;
    case 'activation':
      return _vert;
    case 'ouverture':
      return _teal;
    case 'cloture':
      return _rouge;
    case 'reouverture':
      return _orange;
    case 'generation_bulletins':
      return _ambre;
    case 'passage_eleves':
      return _violet;
    default:
      return _gris;
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

class GestionAnneesScreen extends StatefulWidget {
  const GestionAnneesScreen({super.key});

  @override
  State<GestionAnneesScreen> createState() => _GestionAnneesScreenState();
}

class _GestionAnneesScreenState extends State<GestionAnneesScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  late final AnimationController _pulseController;

  bool _chargement = true;
  Map<String, dynamic>? _tableauDeBord;
  List<dynamic> _annees = [];
  List<dynamic> _journal = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _chargerTout();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pulseController.dispose();
    super.dispose();
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: _rouge));
  }

  void _afficherSucces(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: _vert));
  }

  Widget _blob({required double size, required Color couleur}) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: couleur),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
        title: Text(
          'Années & Périodes',
          style: GoogleFonts.sora(fontWeight: FontWeight.w700),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: '📊 Tableau de bord'),
            Tab(text: '📅 Années'),
            Tab(text: '📋 Journal'),
          ],
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: _blob(
              size: 300,
              couleur: _indigo.withValues(alpha: 0.08),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: _blob(size: 200, couleur: _teal.withValues(alpha: 0.10)),
          ),
          Positioned(
            top: 320,
            left: 140,
            child: _blob(size: 150, couleur: _ambre.withValues(alpha: 0.04)),
          ),
          _chargement
              ? const Center(child: CircularProgressIndicator(color: _indigo))
              : RefreshIndicator(
                  onRefresh: _chargerTout,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _ongletTableauDeBord(),
                      _ongletAnnees(),
                      _ongletJournal(),
                    ],
                  ),
                ),
        ],
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
    final progression = tdb['progression_barre'] as int?;
    final classesTerminees = tdb['classes_notes_terminees'] as int? ?? 0;
    final totalClasses = tdb['total_classes'] as int? ?? 0;
    final bulletinsGeneres = tdb['bulletins_generes'] as int? ?? 0;
    final totalEleves = tdb['total_eleves'] as int? ?? 0;
    final alertes = tdb['alertes'] as List? ?? [];
    final enseignantsRetard = tdb['enseignants_en_retard'] as List? ?? [];

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (annee == null)
            _carteAucuneAnneeActive()
          else ...[
            _banniereAnneeActive(annee, periode, joursRestants),
            const SizedBox(height: 20),
            _grilleStats(
              annee: annee,
              periode: periode,
              joursRestants: joursRestants,
              progression: progression,
              classesTerminees: classesTerminees,
              totalClasses: totalClasses,
              bulletinsGeneres: bulletinsGeneres,
              totalEleves: totalEleves,
            ),
          ],
          if (alertes.isNotEmpty) ...[
            const SizedBox(height: 24),
            const SSMSectionTitre(titre: '⚠️ Alertes'),
            ...alertes.map((a) => _carteAlerte(a as Map<String, dynamic>)),
          ],
          if (enseignantsRetard.isNotEmpty) ...[
            const SizedBox(height: 24),
            SSMSectionTitre(
              titre: 'Enseignants — Saisie des notes',
              action: periode != null ? 'Voir tout' : null,
              onAction: periode != null
                  ? () => _dialogEtatEnseignants(periode['id'] as int)
                  : null,
            ),
            _tableauEnseignants(enseignantsRetard),
          ],
          if (periode != null && periode['statut'] == 'ouverte') ...[
            const SizedBox(height: 24),
            _carteActionsPeriode(periode),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _carteAucuneAnneeActive() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _rouge.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _rouge.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: _rouge, size: 48),
          const SizedBox(height: 12),
          Text(
            'Aucune année scolaire active',
            style: GoogleFonts.sora(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _rouge,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _indigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
            ),
            onPressed: _dialogCreerAnnee,
            icon: const Icon(Icons.add),
            label: const Text('Créer une année'),
          ),
        ],
      ),
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
        gradient: const LinearGradient(
          colors: [_indigo, _teal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Opacity(
                        opacity: 0.5 + (_pulseController.value * 0.5),
                        child: const Icon(
                          Icons.circle,
                          size: 10,
                          color: _vert,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'ANNÉE ACTIVE',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  annee['libelle']?.toString() ?? '',
                  style: GoogleFonts.sora(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatDateCourt(annee['date_debut']?.toString())} → ${_formatDateCourt(annee['date_fin']?.toString())}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            constraints: const BoxConstraints(minWidth: 140),
            child: periode != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        periode['nom']?.toString() ?? '',
                        style: GoogleFonts.sora(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SSMBadge(
                        label: _labelStatutPeriode(
                          periode['statut']?.toString() ?? '',
                        ),
                        couleur: Colors.white,
                        icone: Icons.circle,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        joursRestants != null ? '$joursRestants j.' : '—',
                        style: GoogleFonts.sora(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (joursRestants != null && joursRestants > 0)
                              ? null
                              : 0,
                          minHeight: 4,
                          backgroundColor: Colors.white.withValues(
                            alpha: 0.25,
                          ),
                          color: Colors.white,
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      const Icon(
                        Icons.warning_amber,
                        color: _ambre,
                        size: 28,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Aucune période active',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white,
                        ),
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
    required int? progression,
    required int classesTerminees,
    required int totalClasses,
    required int bulletinsGeneres,
    required int totalEleves,
  }) {
    final pourcentageNotes = totalClasses > 0
        ? (classesTerminees / totalClasses * 100).round()
        : 0;
    final couleurNotes = pourcentageNotes >= 100
        ? _vert
        : (pourcentageNotes > 50 ? _orange : _rouge);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _carteStatMini(
          icone: Icons.calendar_today,
          couleur: _indigo,
          label: 'Année',
          valeur: annee['libelle']?.toString() ?? 'Aucune',
          badge: _labelStatutAnnee(annee['statut']?.toString() ?? ''),
          badgeCouleur: _couleurStatutAnnee(annee['statut']?.toString() ?? ''),
        ),
        _carteStatMini(
          icone: Icons.segment,
          couleur: _teal,
          label: 'Période',
          valeur: periode?['nom']?.toString() ?? 'Aucune',
          badge: periode != null
              ? _labelStatutPeriode(periode['statut']?.toString() ?? '')
              : null,
          badgeCouleur: _couleurStatutPeriode(
            periode?['statut']?.toString() ?? '',
          ),
        ),
        _carteJoursRestants(joursRestants),
        _carteProgression(
          icone: Icons.assignment,
          couleur: couleurNotes,
          label: 'Notes terminées',
          valeurPrincipale: '$classesTerminees/$totalClasses classes',
          pourcentage: pourcentageNotes,
        ),
        _carteProgression(
          icone: Icons.description,
          couleur: _teal,
          label: 'Bulletins générés',
          valeurPrincipale: '$bulletinsGeneres/$totalEleves',
          pourcentage: totalEleves > 0
              ? (bulletinsGeneres / totalEleves * 100).round()
              : 0,
        ),
      ],
    );
  }

  Widget _carteBase({required Widget child}) {
    return Container(
      width: 168,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _carteStatMini({
    required IconData icone,
    required Color couleur,
    required String label,
    required String valeur,
    String? badge,
    Color? badgeCouleur,
  }) {
    return _carteBase(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icone, color: couleur, size: 16),
          ),
          const SizedBox(height: 10),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10,
              color: _gris,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            valeur,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.sora(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          if (badge != null) ...[
            const SizedBox(height: 6),
            SSMBadge(label: badge, couleur: badgeCouleur ?? _gris),
          ],
        ],
      ),
    );
  }

  Widget _carteJoursRestants(int? joursRestants) {
    return _carteBase(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _ambre.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.hourglass_empty,
              color: _ambre,
              size: 16,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'JOURS RESTANTS',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: _gris,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            joursRestants != null ? '$joursRestants' : '—',
            style: GoogleFonts.sora(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: _ambre,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: joursRestants != null
                  ? (joursRestants.clamp(0, 90) / 90)
                  : 0,
              minHeight: 4,
              backgroundColor: const Color(0xFFF1F5F9),
              color: _ambre,
            ),
          ),
        ],
      ),
    );
  }

  Widget _carteProgression({
    required IconData icone,
    required Color couleur,
    required String label,
    required String valeurPrincipale,
    required int pourcentage,
  }) {
    return _carteBase(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icone, color: couleur, size: 16),
          ),
          const SizedBox(height: 10),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10,
              color: _gris,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            valeurPrincipale,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.sora(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pourcentage / 100,
              minHeight: 4,
              backgroundColor: const Color(0xFFF1F5F9),
              color: couleur,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$pourcentage%',
            style: GoogleFonts.inter(fontSize: 11, color: _gris),
          ),
        ],
      ),
    );
  }

  Widget _carteAlerte(Map<String, dynamic> alerte) {
    final type = alerte['type']?.toString() ?? 'info';
    Color couleur;
    IconData icone;
    switch (type) {
      case 'critique':
        couleur = _rouge;
        icone = Icons.error_outline;
        break;
      case 'avertissement':
        couleur = _orange;
        icone = Icons.warning_amber;
        break;
      default:
        couleur = _bleuInfo;
        icone = Icons.info_outline;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icone, color: couleur, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              alerte['message']?.toString() ?? '',
              style: GoogleFonts.inter(fontSize: 13, color: _grisFonce),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableauEnseignants(List enseignants) {
    final lignes = enseignants.take(6).toList();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: lignes.map((e) {
          final ligne = e as Map<String, dynamic>;
          final pourcentage = ligne['pourcentage'] as int? ?? 0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    ligne['enseignant_nom']?.toString() ?? '',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    ligne['matiere_nom']?.toString() ?? '',
                    style: GoogleFonts.inter(fontSize: 12, color: _gris),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    ligne['classe_nom']?.toString() ?? '',
                    style: GoogleFonts.inter(fontSize: 12, color: _gris),
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
                            color: pourcentage >= 100 ? _vert : _orange,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$pourcentage%',
                        style: GoogleFonts.inter(fontSize: 11, color: _gris),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _carteActionsPeriode(Map<String, dynamic> periode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SSMSectionTitre(titre: 'Actions sur la période'),
          _boutonAction(
            label: 'Mettre en validation',
            icone: Icons.pending_actions,
            couleur: _orange,
            onTap: () => _confirmerMettreEnValidation(periode),
          ),
          const SizedBox(height: 10),
          _boutonAction(
            label: 'Générer les bulletins en masse',
            icone: Icons.picture_as_pdf,
            couleur: _teal,
            onTap: () => _confirmerGenererBulletins(periode),
          ),
          const SizedBox(height: 10),
          _boutonAction(
            label: 'Clôturer la période',
            icone: Icons.lock,
            couleur: _rouge,
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: onTap,
        icon: Icon(icone, size: 18),
        label: Text(label),
      ),
    );
  }

  Future<void> _confirmerMettreEnValidation(
    Map<String, dynamic> periode,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Mettre en validation'),
        content: const Text(
          "Les enseignants ne pourront plus modifier leurs notes. Continuer ?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _orange),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Confirmer',
              style: TextStyle(color: Colors.white),
            ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Générer les bulletins'),
        content: const Text(
          'Générer les bulletins pour tous les élèves de la période ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _teal),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Générer',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: _teal)),
    );
    try {
      final res = await AnneeService.genererBulletinsEnMasse(
        periode['id'] as int,
      );
      if (mounted) Navigator.pop(context);
      _afficherSucces(
        '${res['bulletins_generes']} bulletins générés avec succès',
      );
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
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: _indigo)),
    );
    try {
      final data = await AnneeService.etatEnseignants(periodeId);
      if (mounted) Navigator.pop(context);
      final lignes = data['enseignants'] as List? ?? [];
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
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
                Text(
                  'État des enseignants',
                  style: GoogleFonts.sora(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
                                Text(
                                  l['enseignant_nom']?.toString() ?? '',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${l['matiere_nom']} · ${l['classe_nom']}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: _gris,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SSMBadge(
                            label: '$pourcentage%',
                            couleur: pourcentage >= 100 ? _vert : _orange,
                          ),
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

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _indigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: _dialogCreerAnnee,
            icon: const Icon(Icons.add),
            label: const Text('Nouvelle année'),
          ),
        ),
        const SizedBox(height: 16),
        ...triees.map((a) => _carteAnnee(a as Map<String, dynamic>)),
      ],
    );
  }

  Widget _carteAnnee(Map<String, dynamic> annee) {
    final statut = annee['statut']?.toString() ?? 'en_preparation';
    final couleur = _couleurStatutAnnee(statut);
    final periodes = annee['periodes'] as List? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: couleur, width: 6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.pushNamed(
          context,
          '/directeur/annee/fiche',
          arguments: {
            'anneeId': annee['id'] as int,
            'libelle': annee['libelle']?.toString() ?? '',
            'statut': statut,
          },
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
                      style: GoogleFonts.sora(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SSMBadge(label: _labelStatutAnnee(statut), couleur: couleur),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${_formatDateCourt(annee['date_debut']?.toString())} → ${_formatDateCourt(annee['date_fin']?.toString())}',
                style: GoogleFonts.inter(fontSize: 12, color: _gris),
              ),
              Text(
                'Type : ${annee['type_periodes'] == 'semestres' ? 'Semestres' : 'Trimestres'}',
                style: GoogleFonts.inter(fontSize: 12, color: _gris),
              ),
              if (periodes.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: periodes.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final p = periodes[i] as Map<String, dynamic>;
                      final pc = _couleurStatutPeriode(
                        p['statut']?.toString() ?? '',
                      );
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: pc.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: pc,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${p['code'] ?? ''} ${p['nom'] ?? ''}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    '${annee['nombre_eleves'] ?? 0} élèves',
                    style: GoogleFonts.inter(fontSize: 11, color: _gris),
                  ),
                  const SizedBox(width: 8),
                  Text('·', style: GoogleFonts.inter(color: _gris)),
                  const SizedBox(width: 8),
                  Text(
                    '${annee['nombre_classes'] ?? 0} classes',
                    style: GoogleFonts.inter(fontSize: 11, color: _gris),
                  ),
                  const SizedBox(width: 8),
                  Text('·', style: GoogleFonts.inter(color: _gris)),
                  const SizedBox(width: 8),
                  Text(
                    '${annee['nombre_enseignants'] ?? 0} enseignants',
                    style: GoogleFonts.inter(fontSize: 11, color: _gris),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _actionsAnnee(annee, statut),
            ],
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
            style: ElevatedButton.styleFrom(
              backgroundColor: _vert,
              foregroundColor: Colors.white,
            ),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: _indigo,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _dialogGererPeriodes(annee),
                icon: const Icon(Icons.segment, size: 18),
                label: const Text('Gérer les périodes'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: _rouge),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: _teal,
                foregroundColor: Colors.white,
              ),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: _indigo,
                foregroundColor: Colors.white,
              ),
              onPressed: () => _dialogPasserEleves(annee),
              icon: const Icon(Icons.trending_up, size: 18),
              label: const Text('Passer les élèves'),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: _grisFonce),
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
            style: OutlinedButton.styleFrom(foregroundColor: _grisFonce),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Activer cette année'),
        content: Text(
          'Activer "${annee['libelle']}" ? Une seule année peut être active à la fois.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _vert),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Activer',
              style: TextStyle(color: Colors.white),
            ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Archiver cette année'),
        content: Text('Archiver "${annee['libelle']}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _grisFonce),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Archiver',
              style: TextStyle(color: Colors.white),
            ),
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
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Text(
                'Aucune action enregistrée pour le moment.',
                style: GoogleFonts.inter(color: _gris),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      itemCount: _journal.length,
      itemBuilder: (context, i) {
        final j = _journal[i] as Map<String, dynamic>;
        final action = j['action']?.toString() ?? '';
        final couleur = _couleurAction(action);
        final details = j['details'] as Map<String, dynamic>?;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: couleur.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_iconeAction(action), color: couleur, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _labelAction(action),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${j['entite_type']}${details != null && details['libelle'] != null ? ' : ${details['libelle']}' : details != null && details['periode_nom'] != null ? ' : ${details['periode_nom']}' : ''}',
                      style: GoogleFonts.inter(fontSize: 12, color: _gris),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Par ${j['utilisateur_nom'] ?? '—'} · ${_formatDateHeure(j['created_at']?.toString())}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: _gris.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════
  // DIALOG — CRÉER UNE ANNÉE
  // ══════════════════════════════════════════════════════

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

          final typeAffiche = typePeriodes == 'semestres'
              ? 'semestres'
              : 'trimestres';
          final apercu = _definitionsPeriodes[typeAffiche]!;

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nouvelle année scolaire',
                      style: GoogleFonts.sora(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: libelleController,
                            decoration: const InputDecoration(
                              labelText: 'Libellé *',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
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
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (d != null) {
                                setStateDialog(() => dateDebut = d);
                              }
                            },
                            child: Text(
                              dateDebut != null
                                  ? _formatDateLongue(dateDebut!)
                                  : 'Date de début *',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate:
                                    dateDebut?.add(
                                      const Duration(days: 300),
                                    ) ??
                                    DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (d != null) {
                                setStateDialog(() => dateFin = d);
                              }
                            },
                            child: Text(
                              dateFin != null
                                  ? _formatDateLongue(dateFin!)
                                  : 'Date de fin *',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Type de périodes *',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _grisFonce,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _optionType(
                          icone: Icons.auto_awesome,
                          titre: 'Automatique',
                          sousTitre: 'SSM détecte selon vos classes',
                          selectionne: typePeriodes == 'auto',
                          onTap: () =>
                              setStateDialog(() => typePeriodes = 'auto'),
                        ),
                        const SizedBox(width: 8),
                        _optionType(
                          icone: Icons.grid_view,
                          titre: '3 Trimestres',
                          sousTitre: 'Collège & Primaire',
                          selectionne: typePeriodes == 'trimestres',
                          onTap: () => setStateDialog(
                            () => typePeriodes = 'trimestres',
                          ),
                        ),
                        const SizedBox(width: 8),
                        _optionType(
                          icone: Icons.calendar_view_month,
                          titre: '2 Semestres',
                          sousTitre: 'Lycée',
                          selectionne: typePeriodes == 'semestres',
                          onTap: () =>
                              setStateDialog(() => typePeriodes = 'semestres'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _gris.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            typePeriodes == 'auto'
                                ? 'Périodes créées automatiquement (selon détection) :'
                                : 'Périodes créées automatiquement :',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: _gris,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ...apercu.map(
                            (p) => Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                '📅 ${p['nom']} (${p['code']})',
                                style: GoogleFonts.inter(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Moyenne minimale de passage :',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _grisFonce,
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: reglePassage,
                            min: 0,
                            max: 20,
                            divisions: 40,
                            activeColor: _indigo,
                            onChanged: (v) =>
                                setStateDialog(() => reglePassage = v),
                          ),
                        ),
                        Text(
                          '${reglePassage.toStringAsFixed(1)}/20',
                          style: GoogleFonts.sora(
                            fontWeight: FontWeight.w700,
                            color: _indigo,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Annuler'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _indigo,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                            ),
                            onPressed:
                                libelleController.text.trim().isEmpty ||
                                    dateDebut == null ||
                                    dateFin == null
                                ? null
                                : () async {
                                    try {
                                      await AnneeService.creerAnnee(
                                        libelle: libelleController.text
                                            .trim(),
                                        dateDebut: _formatDateApi(dateDebut!),
                                        dateFin: _formatDateApi(dateFin!),
                                        typePeriodes: typePeriodes,
                                      );
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                      }
                                      _afficherSucces(
                                        'Année créée avec succès',
                                      );
                                      _chargerTout();
                                    } catch (e) {
                                      _afficherErreur(
                                        e.toString().replaceAll(
                                          'Exception: ',
                                          '',
                                        ),
                                      );
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
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: selectionne ? _indigo.withValues(alpha: 0.08) : null,
            border: Border.all(
              color: selectionne ? _indigo : _gris.withValues(alpha: 0.3),
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(icone, color: selectionne ? _indigo : _gris, size: 22),
              const SizedBox(height: 6),
              Text(
                titre,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                sousTitre,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 10, color: _gris),
              ),
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
              final data = await AnneeService.listerPeriodes(
                annee['id'] as int,
              );
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Périodes — ${annee['libelle']}',
                      style: GoogleFonts.sora(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Type : ${annee['type_periodes'] == 'semestres' ? 'Semestres' : 'Trimestres'}',
                      style: GoogleFonts.inter(fontSize: 12, color: _gris),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: chargement
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: _indigo,
                              ),
                            )
                          : ListView.separated(
                              itemCount: periodes.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                final p = periodes[i] as Map<String, dynamic>;
                                return _cartePeriodeDialog(
                                  p,
                                  setStateDialog,
                                  () {
                                    setStateDialog(() => chargement = true);
                                  },
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Fermer'),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: couleur.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${periode['nom']} (${periode['code'] ?? '—'})',
                  style: GoogleFonts.sora(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SSMBadge(label: _labelStatutPeriode(statut), couleur: couleur),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${_formatDateCourt(periode['date_debut']?.toString())} → ${_formatDateCourt(periode['date_fin']?.toString())}',
            style: GoogleFonts.inter(fontSize: 12, color: _gris),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _actionsPeriodeDialog(
              periode,
              statut,
              setStateDialog,
              recharger,
            ),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: _vert,
              foregroundColor: Colors.white,
            ),
            onPressed: () => executer(
              () => AnneeService.ouvrirPeriode(periode['id'] as int),
            ),
            child: const Text('Ouvrir'),
          ),
        ];
      case 'ouverte':
        return [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () => executer(
              () => AnneeService.mettreEnValidation(periode['id'] as int),
            ),
            child: const Text('Mettre en validation'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _rouge,
              foregroundColor: Colors.white,
            ),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: _indigo,
              foregroundColor: Colors.white,
            ),
            onPressed: () => executer(
              () => AnneeService.ouvrirPeriode(periode['id'] as int),
            ),
            child: const Text('Réactiver'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _rouge,
              foregroundColor: Colors.white,
            ),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: _rouge,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              _dialogCloturerPeriode(periode);
            },
            child: const Text('Clôturer'),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: _orange),
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
            style: OutlinedButton.styleFrom(foregroundColor: _orange),
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber, color: _ambre, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Réouverture exceptionnelle',
                    style: GoogleFonts.sora(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    periode['nom']?.toString() ?? '',
                    style: GoogleFonts.sora(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cette action est enregistrée dans le journal.',
                    style: GoogleFonts.inter(fontSize: 13, color: _gris),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: motifController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Motif de réouverture *',
                      hintText: 'Expliquez pourquoi...',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setStateDialog(() {}),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Annuler'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _orange,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: motifController.text.trim().isEmpty
                              ? null
                              : () async {
                                  try {
                                    await AnneeService.reouvrir(
                                      periode['id'] as int,
                                      motifController.text.trim(),
                                    );
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                    }
                                    _afficherSucces('Période rouverte');
                                    _chargerTout();
                                  } catch (e) {
                                    _afficherErreur(
                                      e.toString().replaceAll(
                                        'Exception: ',
                                        '',
                                      ),
                                    );
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
              final data = await AnneeService.verifierAvantCloture(
                periode['id'] as int,
              );
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
            final incompletes =
                verification?['classes_incompletes'] as List? ?? [];
            final pret = verification?['pret_pour_cloture'] as bool? ?? false;

            contenu = chargementVerif
                ? const SizedBox(
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(color: _indigo),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            pret ? Icons.check_circle : Icons.error_outline,
                            color: pret ? _vert : _rouge,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            pret
                                ? 'Toutes les notes sont soumises'
                                : 'Des notes sont manquantes',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if (!pret) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Problèmes détectés',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            color: _rouge,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...incompletes.map((c) {
                          final classe = c as Map<String, dynamic>;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning,
                                  color: _orange,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${classe['classe_nom']} — ${classe['notes_manquantes']} note(s) manquante(s)',
                                    style: GoogleFonts.inter(fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ] else ...[
                        const SizedBox(height: 12),
                        const Center(
                          child: Icon(
                            Icons.check_circle,
                            color: _vert,
                            size: 48,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            'Tout est prêt pour la clôture !',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: _vert,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
          } else if (etape == 1) {
            contenu = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'À la clôture, SSM va automatiquement :',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text('✓ Calculer toutes les moyennes'),
                const Text('✓ Calculer les rangs par classe'),
                const Text('✓ Attribuer les mentions'),
                const Text('✓ Préparer les bulletins'),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: genererBulletinsMaintenant,
                  activeThumbColor: _teal,
                  title: const Text('Générer les bulletins maintenant'),
                  onChanged: (v) =>
                      setStateDialog(() => genererBulletinsMaintenant = v),
                ),
              ],
            );
          } else {
            contenu = Column(
              children: [
                const Icon(Icons.check_circle, color: _vert, size: 56),
                const SizedBox(height: 12),
                Text(
                  'Période clôturée avec succès !',
                  style: GoogleFonts.sora(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _vert,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${resultat?['moyennes_calculees'] ?? 0} moyennes calculées',
                ),
                Text('${resultat?['rangs_attribues'] ?? 0} rangs attribués'),
                if (genererBulletinsMaintenant &&
                    resultat?['bulletins_generes'] != null)
                  Text('${resultat?['bulletins_generes']} bulletins prêts'),
              ],
            );
          }

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Clôturer — ${periode['nom']}',
                      style: GoogleFonts.sora(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Flexible(child: SingleChildScrollView(child: contenu)),
                    const SizedBox(height: 20),
                    if (etape == 2)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _indigo,
                            foregroundColor: Colors.white,
                          ),
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
                              child: const Text('Annuler'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: etape == 0 && !chargementVerif
                                    ? ((verification?['pret_pour_cloture'] ==
                                              true)
                                          ? _indigo
                                          : _rouge)
                                    : _indigo,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: chargementVerif
                                  ? null
                                  : () async {
                                      if (etape == 0) {
                                        setStateDialog(() => etape = 1);
                                      } else if (etape == 1) {
                                        try {
                                          final res =
                                              await AnneeService.fermerPeriode(
                                                periode['id'] as int,
                                              );
                                          if (genererBulletinsMaintenant) {
                                            final bulletinsRes =
                                                await AnneeService.genererBulletinsEnMasse(
                                                  periode['id'] as int,
                                                );
                                            res['bulletins_generes'] =
                                                bulletinsRes['bulletins_generes'];
                                          }
                                          setStateDialog(() {
                                            resultat = res;
                                            etape = 2;
                                          });
                                        } catch (e) {
                                          _afficherErreur(
                                            e.toString().replaceAll(
                                              'Exception: ',
                                              '',
                                            ),
                                          );
                                        }
                                      }
                                    },
                              child: Text(
                                etape == 0
                                    ? (verification?['pret_pour_cloture'] ==
                                              true
                                          ? 'Continuer'
                                          : 'Continuer quand même')
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

          final eleves = (apercu?['eleves'] as List? ?? [])
              .cast<Map<String, dynamic>>();
          final total = eleves.length;
          final passeront = total - redoublants.length - diplomes.length;

          Widget contenu;
          if (chargement) {
            contenu = const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator(color: _indigo)),
            );
          } else if (etape == 0) {
            contenu = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bilan de l\'année',
                  style: GoogleFonts.sora(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text('${stats?['nombre_eleves'] ?? 0} élèves'),
                Text('${stats?['nombre_classes'] ?? 0} classes'),
                Text(
                  'Taux de réussite : ${stats?['taux_reussite'] ?? 0}%',
                ),
              ],
            );
          } else if (etape == 1) {
            contenu = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: passerAutomatique,
                  activeThumbColor: _indigo,
                  title: const Text(
                    'Passage automatique selon les moyennes',
                  ),
                  onChanged: (v) =>
                      setStateDialog(() => passerAutomatique = v),
                ),
                if (passerAutomatique) ...[
                  Text(
                    'Règle : Moyenne ≥ ${annee['regle_passage_moyenne'] ?? 10}/20 → passage automatique',
                    style: GoogleFonts.inter(fontSize: 12, color: _gris),
                  ),
                  const SizedBox(height: 8),
                  Text('$passeront élève(s) passeront automatiquement'),
                  Text('${redoublants.length} élève(s) redoubleront'),
                ],
                const SizedBox(height: 12),
                Text(
                  'Ajustements manuels',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
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
                              style: GoogleFonts.inter(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Text(
                            'Redouble',
                            style: TextStyle(fontSize: 11),
                          ),
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
                          const Text(
                            'Diplômé',
                            style: TextStyle(fontSize: 11),
                          ),
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
                Text('$passeront élève(s) passeront en classe supérieure'),
                Text('${redoublants.length} élève(s) redoubleront'),
                Text('${diplomes.length} élève(s) sont diplômés'),
              ],
            );
          } else {
            contenu = Column(
              children: [
                const Icon(Icons.check_circle, color: _vert, size: 56),
                const SizedBox(height: 12),
                Text(
                  cloturerApres
                      ? 'Année "${annee['libelle']}" clôturée !'
                      : 'Passage effectué avec succès !',
                  style: GoogleFonts.sora(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _vert,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${resultatPassage?['resultats']?['passes'] ?? 0} admis · '
                  '${resultatPassage?['resultats']?['redoublants'] ?? 0} redoublants · '
                  '${resultatPassage?['resultats']?['diplomes'] ?? 0} diplômés',
                ),
              ],
            );
          }

          final derniereEtape = cloturerApres ? 3 : 2;

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cloturerApres
                          ? "Clôturer l'année"
                          : 'Passage des élèves',
                      style: GoogleFonts.sora(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Flexible(child: SingleChildScrollView(child: contenu)),
                    const SizedBox(height: 20),
                    if (etape == derniereEtape)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _indigo,
                            foregroundColor: Colors.white,
                          ),
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
                              child: const Text('Annuler'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    (cloturerApres && etape == derniereEtape - 1)
                                        ? _rouge
                                        : _teal,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: chargement
                                  ? null
                                  : () async {
                                      final etapeFinale =
                                          cloturerApres ? 2 : 1;
                                      if (etape < etapeFinale) {
                                        setStateDialog(() => etape++);
                                        return;
                                      }
                                      try {
                                        final res =
                                            await AnneeService.passerEleves(
                                              annee['id'] as int,
                                              passerAutomatique:
                                                  passerAutomatique,
                                              redoublants: redoublants
                                                  .toList(),
                                              diplomes: diplomes.toList(),
                                            );
                                        if (cloturerApres) {
                                          await AnneeService.cloturerAnnee(
                                            annee['id'] as int,
                                          );
                                        }
                                        setStateDialog(() {
                                          resultatPassage = res;
                                          etape = derniereEtape;
                                        });
                                      } catch (e) {
                                        _afficherErreur(
                                          e.toString().replaceAll(
                                            'Exception: ',
                                            '',
                                          ),
                                        );
                                      }
                                    },
                              child: Text(
                                etape < (cloturerApres ? 2 : 1)
                                    ? 'Continuer'
                                    : (cloturerApres
                                          ? "Clôturer l'année"
                                          : 'Confirmer le passage'),
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
