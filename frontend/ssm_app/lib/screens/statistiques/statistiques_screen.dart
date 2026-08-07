import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/statistique_service.dart';
import '../../services/annee_service.dart';
import '../../services/absence_service.dart';
import '../../services/dashboard_frais_service.dart';
import '../../widgets/ssm_widgets.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _teal = Color(0xFF0D9488);
const Color _ambre = Color(0xFFD97706);
const Color _vert = Color(0xFF16A34A);
const Color _rouge = Color(0xFFDC2626);
const Color _orange = Color(0xFFEA580C);
const Color _bleuInfo = Color(0xFF0284C7);

String _formatMontant(num valeur) {
  final millions = valeur / 1000000;
  if (millions >= 1) {
    return '${millions.toStringAsFixed(1).replaceAll('.', ',')} M FCFA';
  }
  final milliers = valeur / 1000;
  return '${milliers.toStringAsFixed(0)} k FCFA';
}

const List<String> _nomsMois = [
  '',
  'Jan',
  'Fév',
  'Mar',
  'Avr',
  'Mai',
  'Jun',
  'Jul',
  'Aoû',
  'Sep',
  'Oct',
  'Nov',
  'Déc',
];

class StatistiquesScreen extends StatefulWidget {
  const StatistiquesScreen({super.key});

  @override
  State<StatistiquesScreen> createState() => _StatistiquesScreenState();
}

class _StatistiquesScreenState extends State<StatistiquesScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _absencesStats;
  Map<String, dynamic>? _rapportFinancier;

  List<dynamic> _periodes = [];
  int? _anneeId;
  String? _anneeLibelle;
  int? _periodeId;
  String? _heureMaj;

  bool _chargement = true;

  late final AnimationController _controller;
  late final Animation<double> _animEnTete;
  late final Animation<double> _animCartes;
  late final Animation<double> _animGraphiques;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animEnTete = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.25, curve: Curves.easeOut),
    );
    _animCartes = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.25, 0.625, curve: Curves.easeOut),
    );
    _animGraphiques = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.625, 1.0, curve: Curves.easeOut),
    );
    _chargerTout();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _chargerTout() async {
    setState(() => _chargement = true);
    try {
      final annees = await AnneeService.listerAnnees();
      final anneeEnCours = annees.firstWhere(
        (a) => a['statut'] == 'en_cours',
        orElse: () => annees.isNotEmpty ? annees.first : null,
      );
      final anneeId = anneeEnCours?['id'] as int?;
      final anneeLibelle = anneeEnCours?['libelle'] as String?;

      List<dynamic> periodes = [];
      if (anneeId != null) {
        try {
          periodes = await AnneeService.listerPeriodes(anneeId);
        } catch (_) {
          // Les chips de période restent limitées à "Toute l'année".
        }
      }

      setState(() {
        _anneeId = anneeId;
        _anneeLibelle = anneeLibelle;
        _periodes = periodes;
      });

      await _chargerStats();
    } catch (e) {
      setState(() => _chargement = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<Map<String, dynamic>> _chargerResumeFinancierSecurise() async {
    try {
      return await DashboardFraisService.resume();
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _chargerStats() async {
    setState(() => _chargement = true);
    try {
      final resultats = await Future.wait([
        StatistiqueService.chargerStatistiques(
          anneeId: _anneeId,
          periodeId: _periodeId,
        ),
        AbsenceService.statistiques(),
        _chargerResumeFinancierSecurise(),
      ]);

      setState(() {
        _stats = resultats[0];
        _absencesStats = resultats[1];
        _rapportFinancier = resultats[2];
        _heureMaj =
            '${TimeOfDay.now().hour.toString().padLeft(2, '0')}:${TimeOfDay.now().minute.toString().padLeft(2, '0')}';
        _chargement = false;
      });

      _controller.forward(from: 0);
    } catch (e) {
      setState(() => _chargement = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _changerPeriode(int? periodeId) {
    setState(() => _periodeId = periodeId);
    _chargerStats();
  }

  void _afficherErreur(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: _rouge));
  }

  // ══════════════════════════════════════════════════════
  // ACCESSEURS DE DONNÉES
  // ══════════════════════════════════════════════════════

  int get _totalEleves =>
      (_stats?['effectifs']?['total'] as num?)?.toInt() ?? 0;
  int get _garcons => (_stats?['effectifs']?['garcons'] as num?)?.toInt() ?? 0;
  int get _filles => (_stats?['effectifs']?['filles'] as num?)?.toInt() ?? 0;
  int get _nouveauxCeMois =>
      (_stats?['effectifs']?['nouveaux_ce_mois'] as num?)?.toInt() ?? 0;
  List<dynamic> get _effectifsParClasse =>
      (_stats?['effectifs']?['par_classe'] as List?) ?? [];

  double get _tauxReussite =>
      (_stats?['notes']?['taux_reussite'] as num?)?.toDouble() ?? 0;
  List<dynamic> get _moyennesClasses =>
      (_stats?['notes']?['moyennes_classes'] as List?) ?? [];
  List<dynamic> get _moyennesMatieres =>
      (_stats?['notes']?['moyennes_matieres'] as List?) ?? [];

  List<dynamic> get _paiementsMois =>
      (_stats?['finances']?['paiements_mois'] as List?) ?? [];

  int get _absentsAujourdhui =>
      (_absencesStats?['absents_aujourdhui'] as num?)?.toInt() ?? 0;
  int get _nonJustifieesAujourdhui =>
      (_absencesStats?['non_justifiees_aujourdhui'] as num?)?.toInt() ?? 0;
  List<dynamic> get _absencesParSemaine =>
      (_stats?['assiduite']?['par_semaine'] as List?) ?? [];
  List<dynamic> get _elevesPlusAbsents =>
      (_stats?['assiduite']?['plus_absents'] as List?) ?? [];

  double get _totalEncaisseMois {
    final now = DateTime.now();
    final entree = _paiementsMois.firstWhere(
      (p) => p['mois'] == now.month && p['annee'] == now.year,
      orElse: () => null,
    );
    return entree != null
        ? double.tryParse(entree['total'].toString()) ?? 0
        : 0;
  }

  double get _totalAttendu =>
      (_rapportFinancier?['montant_attendu'] as num?)?.toDouble() ?? 0;
  double get _totalEncaisseAnnee =>
      (_rapportFinancier?['montant_encaisse'] as num?)?.toDouble() ?? 0;
  double get _resteAPercevoir =>
      (_rapportFinancier?['montant_restant'] as num?)?.toDouble() ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF6FF),
      body: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: _blob(size: 300, couleur: _indigo.withValues(alpha: 0.08)),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: _blob(size: 200, couleur: _teal.withValues(alpha: 0.10)),
          ),
          Positioned(
            top: 340,
            left: 140,
            child: _blob(size: 150, couleur: _ambre.withValues(alpha: 0.05)),
          ),
          Positioned(
            top: 44,
            left: 8,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          SafeArea(
            child: _chargement && _stats == null
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _chargerTout,
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 40),
                      children: [
                        _enTeteAnime(),
                        _selecteurPeriode(),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionChiffresCles(),
                              const SizedBox(height: 28),
                              SSMSectionTitre(titre: 'Effectifs'),
                              _sectionEffectifs(),
                              const SizedBox(height: 28),
                              SSMSectionTitre(titre: 'Finances'),
                              _sectionFinances(),
                              const SizedBox(height: 28),
                              SSMSectionTitre(titre: 'Résultats scolaires'),
                              _sectionPedagogie(),
                              const SizedBox(height: 28),
                              SSMSectionTitre(titre: 'Assiduité'),
                              _sectionAssiduite(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
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

  Widget _carteGlass({
    required Widget child,
    double? hauteur,
    EdgeInsetsGeometry? padding,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: hauteur,
          width: double.infinity,
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.70),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // EN-TÊTE HERO
  // ══════════════════════════════════════════════════════

  Widget _enTeteAnime() {
    return AnimatedBuilder(
      animation: _animEnTete,
      builder: (context, child) => Opacity(
        opacity: _animEnTete.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, -30 * (1 - _animEnTete.value)),
          child: child,
        ),
      ),
      child: _enTete(),
    );
  }

  Widget _enTete() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_indigo, _teal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Statistiques',
                style: GoogleFonts.sora(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _anneeLibelle != null
                    ? 'Année $_anneeLibelle'
                    : 'Aucune année active',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _heureMaj != null ? 'Mis à jour à $_heureMaj' : '',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () => ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Export PDF à venir'))),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.picture_as_pdf,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Export',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // SÉLECTEUR DE PÉRIODE
  // ══════════════════════════════════════════════════════

  Widget _selecteurPeriode() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.white.withValues(alpha: 0.8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chipPeriode(
                  label: "Toute l'année",
                  actif: _periodeId == null,
                  onTap: () => _changerPeriode(null),
                ),
                for (final p in _periodes) ...[
                  const SizedBox(width: 8),
                  _chipPeriode(
                    label: p['nom'] as String,
                    actif: _periodeId == p['id'],
                    onTap: () => _changerPeriode(p['id'] as int),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chipPeriode({
    required String label,
    required bool actif,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: actif ? _indigo : Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(50),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: actif ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // SECTION 1 — CHIFFRES CLÉS
  // ══════════════════════════════════════════════════════

  Widget _sectionChiffresCles() {
    return AnimatedBuilder(
      animation: _animCartes,
      builder: (context, child) => Opacity(
        opacity: _animCartes.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - _animCartes.value)),
          child: child,
        ),
      ),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.15,
        children: [
          _carteChiffreCle(
            icone: Icons.people,
            couleur: _indigo,
            valeur: _totalEleves.toDouble(),
            suffixe: '',
            libelle: 'élèves inscrits',
            badge: '+$_nouveauxCeMois ce mois',
            couleurBadge: _vert,
          ),
          _carteChiffreCle(
            icone: Icons.school,
            couleur: _teal,
            valeur: _tauxReussite,
            suffixe: '%',
            libelle: '% de réussite',
            badge: '≥10/20',
            couleurBadge: _teal,
            fondBadgeLeger: true,
          ),
          _carteChiffreCle(
            icone: Icons.payments,
            couleur: _ambre,
            valeur: _totalEncaisseMois,
            texteFormate: _formatMontant(_totalEncaisseMois),
            libelle: 'encaissé ce mois',
            tailleValeur: 26,
          ),
          _carteChiffreCle(
            icone: Icons.event_busy,
            couleur: _orange,
            valeur: _absentsAujourdhui.toDouble(),
            suffixe: '',
            libelle: 'absences aujourd\'hui',
            badge: _nonJustifieesAujourdhui > 0
                ? '$_nonJustifieesAujourdhui non justifiées'
                : null,
            couleurBadge: _rouge,
          ),
        ],
      ),
    );
  }

  Widget _carteChiffreCle({
    required IconData icone,
    required Color couleur,
    required double valeur,
    String suffixe = '',
    String? texteFormate,
    required String libelle,
    String? badge,
    Color couleurBadge = _vert,
    bool fondBadgeLeger = false,
    double tailleValeur = 32,
  }) {
    return _carteGlass(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icone, color: couleur, size: 22),
          ),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: valeur),
            duration: const Duration(milliseconds: 1500),
            curve: Curves.easeOutCubic,
            builder: (context, v, child) {
              final texte = texteFormate ?? '${v.round()}$suffixe';
              return Text(
                texte,
                style: GoogleFonts.sora(
                  fontSize: tailleValeur,
                  fontWeight: FontWeight.w700,
                  color: couleur,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );
            },
          ),
          const SizedBox(height: 2),
          Text(
            libelle,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF334155),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (badge != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: couleurBadge.withValues(
                  alpha: fondBadgeLeger ? 0.1 : 0.12,
                ),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badge,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: couleurBadge,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // SECTION 2 — EFFECTIFS
  // ══════════════════════════════════════════════════════

  Widget _sectionEffectifs() {
    return AnimatedBuilder(
      animation: _animGraphiques,
      builder: (context, child) =>
          Opacity(opacity: _animGraphiques.value.clamp(0.0, 1.0), child: child),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final large = constraints.maxWidth > 800;
          final donut = _carteDonutEffectifs();
          final barres = _carteBarresEffectifClasse();
          if (large) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: donut),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: barres),
              ],
            );
          }
          return Column(children: [donut, const SizedBox(height: 16), barres]);
        },
      ),
    );
  }

  Widget _carteDonutEffectifs() {
    final total = _garcons + _filles;
    final pctGarcons = total > 0 ? (_garcons / total * 100) : 0;
    final pctFilles = total > 0 ? (_filles / total * 100) : 0;

    return _carteGlass(
      hauteur: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Répartition',
            style: GoogleFonts.sora(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
          ),
          Expanded(
            child: total == 0
                ? Center(
                    child: Text(
                      'Aucune donnée',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF334155),
                      ),
                    ),
                  )
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 0,
                          centerSpaceRadius: 45,
                          sections: [
                            PieChartSectionData(
                              value: _garcons.toDouble(),
                              color: _indigo,
                              showTitle: false,
                              radius: 24,
                            ),
                            PieChartSectionData(
                              value: _filles.toDouble(),
                              color: _teal,
                              showTitle: false,
                              radius: 24,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '$total',
                        style: GoogleFonts.sora(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _puceLegende(
                _indigo,
                'Garçons $_garcons (${pctGarcons.toStringAsFixed(0)}%)',
              ),
              const SizedBox(width: 16),
              _puceLegende(
                _teal,
                'Filles $_filles (${pctFilles.toStringAsFixed(0)}%)',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _puceLegende(Color couleur, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF334155),
          ),
        ),
      ],
    );
  }

  Widget _carteBarresEffectifClasse() {
    final classes = _effectifsParClasse;
    final effectifs = classes
        .map((c) => (c['effectif'] as num?)?.toDouble() ?? 0)
        .toList();
    final capacites = classes
        .map((c) => (c['capacite_max'] as num?)?.toDouble())
        .where((c) => c != null)
        .cast<double>()
        .toList();
    final capaciteMoyenne = capacites.isEmpty
        ? null
        : capacites.reduce((a, b) => a + b) / capacites.length;
    final maxY =
        ([...effectifs, capaciteMoyenne ?? 0].reduce((a, b) => a > b ? a : b)) *
        1.25;

    return _carteGlass(
      hauteur: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Effectif par classe',
            style: GoogleFonts.sora(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: classes.isEmpty
                ? Center(
                    child: Text(
                      'Aucune classe',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF334155),
                      ),
                    ),
                  )
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY <= 0 ? 10 : maxY,
                      groupsSpace: 10,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => Colors.transparent,
                          tooltipMargin: 0,
                          tooltipPadding: EdgeInsets.zero,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                              BarTooltipItem(
                                rod.toY.round().toString(),
                                GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF334155),
                                ),
                              ),
                        ),
                      ),
                      barGroups: [
                        for (var i = 0; i < classes.length; i++)
                          BarChartGroupData(
                            x: i,
                            showingTooltipIndicators: const [0],
                            barRods: [
                              BarChartRodData(
                                toY: effectifs[i],
                                width: 18,
                                borderRadius: BorderRadius.circular(4),
                                gradient: LinearGradient(
                                  colors: [
                                    _indigo,
                                    _indigo.withValues(alpha: 0.5),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ],
                          ),
                      ],
                      extraLinesData: capaciteMoyenne == null
                          ? const ExtraLinesData()
                          : ExtraLinesData(
                              horizontalLines: [
                                HorizontalLine(
                                  y: capaciteMoyenne,
                                  color: _rouge.withValues(alpha: 0.6),
                                  strokeWidth: 1.5,
                                  dashArray: [6, 4],
                                ),
                              ],
                            ),
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        horizontalInterval: (maxY <= 0 ? 10 : maxY) / 4,
                        getDrawingHorizontalLine: (v) => FlLine(
                          color: const Color(
                            0xFF0F172A,
                          ).withValues(alpha: 0.04),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 46,
                            getTitlesWidget: (value, meta) {
                              final i = value.toInt();
                              if (i < 0 || i >= classes.length)
                                return const SizedBox();
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Transform.rotate(
                                  angle: -45 * math.pi / 180,
                                  child: Text(
                                    classes[i]['nom'] as String,
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      color: const Color(0xFF334155),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // SECTION 3 — FINANCES
  // ══════════════════════════════════════════════════════

  Widget _sectionFinances() {
    final recouvrement = _totalAttendu > 0
        ? (_totalEncaisseAnnee / _totalAttendu).clamp(0.0, 1.0)
        : 0.0;
    final couleurRecouvrement = recouvrement > 0.8
        ? _vert
        : recouvrement > 0.5
        ? _orange
        : _rouge;

    return AnimatedBuilder(
      animation: _animGraphiques,
      builder: (context, child) =>
          Opacity(opacity: _animGraphiques.value.clamp(0.0, 1.0), child: child),
      child: Column(
        children: [
          _carteGlass(
            hauteur: 240,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Évolution des encaissements',
                      style: GoogleFonts.sora(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _bleuInfo.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.circle, size: 6, color: _bleuInfo),
                          const SizedBox(width: 4),
                          Text(
                            'Live',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: _bleuInfo,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _paiementsMois.isEmpty
                      ? Center(
                          child: Text(
                            'Aucune donnée',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF334155),
                            ),
                          ),
                        )
                      : _lineChartEncaissements(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _carteMetriqueFinance(
                  'Total attendu',
                  _totalAttendu,
                  const Color(0xFF334155),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _carteMetriqueFinance(
                  'Total encaissé',
                  _totalEncaisseAnnee,
                  _vert,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _carteMetriqueFinance(
                  'Reste à percevoir',
                  _resteAPercevoir,
                  _rouge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _carteGlass(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: recouvrement,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFF1F5F9),
                    color: couleurRecouvrement,
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${(recouvrement * 100).toStringAsFixed(0)}% de recouvrement',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _carteMetriqueFinance(String label, double valeur, Color couleur) {
    return _carteGlass(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Column(
        children: [
          Text(
            _formatMontant(valeur),
            style: GoogleFonts.sora(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: couleur,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lineChartEncaissements() {
    final valeurs = _paiementsMois
        .map((p) => double.tryParse(p['total'].toString()) ?? 0.0)
        .toList();
    final maxY = valeurs.isEmpty
        ? 100.0
        : valeurs.reduce((a, b) => a > b ? a : b) * 1.2;

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY <= 0 ? 100 : maxY,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: (maxY <= 0 ? 100 : maxY) / 4,
          getDrawingHorizontalLine: (v) => FlLine(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, meta) => Text(
                '${(value / 1000).toStringAsFixed(0)}k',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= _paiementsMois.length)
                  return const SizedBox();
                final p = _paiementsMois[i];
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _nomsMois[p['mois'] as int],
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: const Color(0xFF334155),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => _indigo,
            getTooltipItems: (spots) => spots
                .map(
                  (s) => LineTooltipItem(
                    _formatMontant(s.y),
                    const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                )
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < valeurs.length; i++)
                FlSpot(i.toDouble(), valeurs[i]),
            ],
            isCurved: true,
            color: _indigo,
            barWidth: 3,
            dotData: FlDotData(
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 4,
                color: Colors.white,
                strokeWidth: 2,
                strokeColor: _indigo,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _indigo.withValues(alpha: 0.18),
                  _indigo.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }

  // ══════════════════════════════════════════════════════
  // SECTION 4 — PÉDAGOGIE
  // ══════════════════════════════════════════════════════

  Widget _sectionPedagogie() {
    return AnimatedBuilder(
      animation: _animGraphiques,
      builder: (context, child) =>
          Opacity(opacity: _animGraphiques.value.clamp(0.0, 1.0), child: child),
      child: Column(
        children: [
          _carteMoyennesMatieres(),
          const SizedBox(height: 16),
          _carteClassementClasses(),
        ],
      ),
    );
  }

  Color _couleurMoyenne(double moyenne) {
    if (moyenne >= 14) return _vert;
    if (moyenne >= 10) return _teal;
    return _rouge;
  }

  Widget _carteMoyennesMatieres() {
    final matieres = List<dynamic>.from(_moyennesMatieres)
      ..sort(
        (a, b) => (double.tryParse(b['moyenne'].toString()) ?? 0).compareTo(
          double.tryParse(a['moyenne'].toString()) ?? 0,
        ),
      );

    return _carteGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Moyennes par matière',
            style: GoogleFonts.sora(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          if (matieres.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Aucune note validée',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF334155),
                ),
              ),
            )
          else
            ...matieres.map((m) {
              final moyenne = double.tryParse(m['moyenne'].toString()) ?? 0.0;
              final couleur = _couleurMoyenne(moyenne);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(
                        m['nom'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (moyenne / 20).clamp(0.0, 1.0),
                          minHeight: 10,
                          backgroundColor: const Color(0xFFF1F5F9),
                          color: couleur,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 44,
                      child: Text(
                        '${moyenne.toStringAsFixed(1)}/20',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: couleur,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _carteClassementClasses() {
    final classes = List<dynamic>.from(_moyennesClasses)
      ..sort(
        (a, b) => (double.tryParse(b['moyenne'].toString()) ?? 0).compareTo(
          double.tryParse(a['moyenne'].toString()) ?? 0,
        ),
      );

    const couleursRang = [
      Color(0xFFD4AF37),
      Color(0xFFA8A8A8),
      Color(0xFFB08D57),
    ];

    return _carteGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Classement des classes',
            style: GoogleFonts.sora(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          if (classes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Aucune moyenne disponible',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF334155),
                ),
              ),
            )
          else
            ...classes.asMap().entries.map((entry) {
              final rang = entry.key;
              final classe = entry.value;
              final moyenne =
                  double.tryParse(classe['moyenne'].toString()) ?? 0.0;
              final couleur = _couleurMoyenne(moyenne);
              final couleurRang = rang < 3
                  ? couleursRang[rang]
                  : const Color(0xFF94A3B8);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: couleurRang.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${rang + 1}',
                        style: GoogleFonts.sora(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: couleurRang,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        classe['nom'] as String,
                        style: GoogleFonts.sora(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (moyenne / 20).clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: const Color(0xFFF1F5F9),
                          color: couleur,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 44,
                      child: Text(
                        '${moyenne.toStringAsFixed(1)}/20',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: couleur,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // SECTION 5 — ASSIDUITÉ
  // ══════════════════════════════════════════════════════

  Widget _sectionAssiduite() {
    return AnimatedBuilder(
      animation: _animGraphiques,
      builder: (context, child) =>
          Opacity(opacity: _animGraphiques.value.clamp(0.0, 1.0), child: child),
      child: Column(
        children: [
          _carteBarresAbsencesSemaine(),
          const SizedBox(height: 16),
          _carteElevesASurveiller(),
        ],
      ),
    );
  }

  Widget _carteBarresAbsencesSemaine() {
    final semaines = _absencesParSemaine;
    final totaux = semaines
        .map((s) => (s['total'] as num?)?.toDouble() ?? 0)
        .toList();
    final maxY =
        (totaux.isEmpty ? 0.0 : totaux.reduce((a, b) => a > b ? a : b)) * 1.3;

    return _carteGlass(
      hauteur: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Absences par semaine',
                style: GoogleFonts.sora(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Row(
                children: [
                  _puceLegende(_indigo, 'Total'),
                  const SizedBox(width: 12),
                  _puceLegende(_rouge, 'Non justifiées'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: semaines.isEmpty
                ? Center(
                    child: Text(
                      'Aucune donnée',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF334155),
                      ),
                    ),
                  )
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY <= 0 ? 10 : maxY,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => Colors.transparent,
                          tooltipMargin: 0,
                          tooltipPadding: EdgeInsets.zero,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                              BarTooltipItem(
                                rod.toY.round().toString(),
                                GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF334155),
                                ),
                              ),
                        ),
                      ),
                      barGroups: [
                        for (var i = 0; i < semaines.length; i++)
                          BarChartGroupData(
                            x: i,
                            barsSpace: 4,
                            showingTooltipIndicators: const [0, 1],
                            barRods: [
                              BarChartRodData(
                                toY:
                                    (semaines[i]['total'] as num?)
                                        ?.toDouble() ??
                                    0,
                                width: 14,
                                color: _indigo,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              BarChartRodData(
                                toY:
                                    (semaines[i]['non_justifiees'] as num?)
                                        ?.toDouble() ??
                                    0,
                                width: 14,
                                color: _rouge,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          ),
                      ],
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        horizontalInterval: (maxY <= 0 ? 10 : maxY) / 4,
                        getDrawingHorizontalLine: (v) => FlLine(
                          color: const Color(
                            0xFF0F172A,
                          ).withValues(alpha: 0.04),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final i = value.toInt();
                              if (i < 0 || i >= semaines.length)
                                return const SizedBox();
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  semaines[i]['semaine'] as String,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: const Color(0xFF334155),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _carteElevesASurveiller() {
    final eleves = _elevesPlusAbsents;

    return _carteGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '⚠️ Élèves à surveiller',
            style: GoogleFonts.sora(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          if (eleves.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  const Icon(Icons.check_circle, color: _vert, size: 40),
                  const SizedBox(height: 8),
                  Text(
                    'Aucun élève avec absences excessives',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            )
          else
            ...eleves.map((e) {
              final photoUrl = e['photo_url'] as String?;
              final nom = e['nom'] as String? ?? '';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: _indigo.withValues(alpha: 0.15),
                      backgroundImage: photoUrl != null
                          ? NetworkImage(photoUrl)
                          : null,
                      child: photoUrl == null
                          ? Text(
                              nom.isNotEmpty ? nom[0].toUpperCase() : '?',
                              style: GoogleFonts.sora(
                                fontWeight: FontWeight.w700,
                                color: _indigo,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$nom ${e['prenom'] ?? ''}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (e['classe_nom'] != null) ...[
                      SSMBadge(
                        label: e['classe_nom'] as String,
                        couleur: const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 6),
                    ],
                    SSMBadge(
                      label: '${e['total_absences']} absences',
                      couleur: _rouge,
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
