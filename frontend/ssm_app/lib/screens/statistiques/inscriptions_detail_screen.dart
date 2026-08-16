import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/statistique_detail_model.dart';
import '../../services/annee_service.dart';
import '../../services/statistique_detail_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_data_table.dart';
import '../../widgets/ssm/ssm_panel.dart';
import '../../widgets/ssm/ssm_sous_entete.dart';

// ══════════════════════════════════════════════════════════
// Écran détaillé "Inscriptions" du module Statistiques : évolution
// pluriannuelle, répartition par niveau (avec sous-répartition garçons /
// filles) et par classe, pour une année scolaire choisie.
// ══════════════════════════════════════════════════════════
class InscriptionsDetailScreen extends StatefulWidget {
  final int? anneeScolaireId;

  const InscriptionsDetailScreen({super.key, this.anneeScolaireId});

  @override
  State<InscriptionsDetailScreen> createState() => _InscriptionsDetailScreenState();
}

class _InscriptionsDetailScreenState extends State<InscriptionsDetailScreen> {
  List<dynamic> _annees = [];
  int? _anneeId;

  List<EvolutionEffectif> _evolution = [];
  List<RepartitionNiveau> _parNiveau = [];
  List<RepartitionClasse> _parClasse = [];

  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _initialiser();
  }

  Future<void> _initialiser() async {
    try {
      final annees = await AnneeService.listerAnnees();
      var anneeId = widget.anneeScolaireId;
      if (anneeId == null) {
        final data = await AnneeService.anneeActive();
        anneeId = (data['annee'] as Map<String, dynamic>?)?['id'] as int? ??
            (annees.isNotEmpty ? annees.first['id'] as int : null);
      }
      if (!mounted) return;
      setState(() {
        _annees = annees;
        _anneeId = anneeId;
      });
      await _charger();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _charger() async {
    if (_anneeId == null) {
      setState(() => _chargement = false);
      return;
    }
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final resultats = await Future.wait([
        StatistiqueDetailService.getInscriptionsEvolution(),
        StatistiqueDetailService.getInscriptionsParNiveau(_anneeId!),
        StatistiqueDetailService.getInscriptionsParClasse(_anneeId!),
      ]);
      if (!mounted) return;
      setState(() {
        _evolution = resultats[0] as List<EvolutionEffectif>;
        _parNiveau = resultats[1] as List<RepartitionNiveau>;
        _parClasse = resultats[2] as List<RepartitionClasse>;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _changerAnnee(int? id) {
    if (id == null || id == _anneeId) return;
    setState(() => _anneeId = id);
    _charger();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SSMPalette.fond,
      body: SafeArea(
        child: Column(
          children: [
            SSMSousEnTete(
              titre: 'Inscriptions détaillées',
              onRetour: () => Navigator.pop(context),
              complement: _selecteurAnnee(),
            ),
            Expanded(
              child: _chargement && _erreur == null
                  ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
                  : _erreur != null
                      ? _carteErreur(_erreur!, _charger)
                      : RefreshIndicator(
                          onRefresh: _charger,
                          color: SSMPalette.indigo,
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              _carteEvolution(),
                              const SizedBox(height: 16),
                              _carteRepartitionNiveau(),
                              const SizedBox(height: 16),
                              _carteRepartitionClasse(),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selecteurAnnee() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(SSMRayons.moyen),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _anneeId,
          isDense: true,
          icon: const Icon(Icons.expand_more, size: 16, color: SSMPalette.texte3),
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: SSMPalette.texte1),
          items: _annees
              .map((a) => DropdownMenuItem<int>(value: a['id'] as int, child: Text(a['libelle'] as String? ?? '—')))
              .toList(),
          onChanged: _changerAnnee,
        ),
      ),
    );
  }

  Widget _carteErreur(String message, Future<void> Function() onReessayer) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: SSMPalette.rouge, size: 36),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center, style: GoogleFonts.inter(color: SSMPalette.texte2)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onReessayer, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }

  // ── Évolution des effectifs ──────────────────────────────

  Widget _carteEvolution() {
    final maxValeur = _evolution.isEmpty ? 0 : _evolution.map((e) => e.total).reduce((a, b) => a > b ? a : b);
    final maxY = maxValeur <= 0 ? 10.0 : maxValeur * 1.2;

    return SSMPanel(
      titre: 'Évolution des effectifs',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Total des élèves inscrits sur les dernières années scolaires de l'établissement.",
            style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte2),
          ),
          const SizedBox(height: 12),
          if (_evolution.isEmpty)
            _etatVide('Aucune donnée')
          else
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY,
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4,
                    getDrawingHorizontalLine: (v) => FlLine(color: SSMPalette.bordure, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= _evolution.length) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(_evolution[i].annee, style: GoogleFonts.inter(fontSize: 10, color: SSMPalette.texte2)),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => SSMPalette.indigo,
                      getTooltipItems: (spots) =>
                          spots.map((s) => LineTooltipItem(s.y.toStringAsFixed(0), const TextStyle(color: Colors.white, fontSize: 11))).toList(),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [for (var i = 0; i < _evolution.length; i++) FlSpot(i.toDouble(), _evolution[i].total.toDouble())],
                      isCurved: true,
                      color: SSMPalette.indigo,
                      barWidth: 3,
                      dotData: FlDotData(
                        getDotPainter: (spot, percent, bar, index) =>
                            FlDotCirclePainter(radius: 4, color: SSMPalette.indigo, strokeWidth: 2, strokeColor: Colors.white),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [SSMPalette.indigo.withValues(alpha: 0.15), SSMPalette.indigo.withValues(alpha: 0.0)],
                        ),
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

  // ── Répartition par niveau (garçons / filles) ───────────

  Widget _carteRepartitionNiveau() {
    final maxValeur = _parNiveau.isEmpty ? 0 : _parNiveau.map((n) => n.total).reduce((a, b) => a > b ? a : b);
    final maxY = maxValeur <= 0 ? 10.0 : maxValeur * 1.3;

    return SSMPanel(
      titre: 'Répartition par niveau',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [_legende(SSMPalette.indigo, 'Garçons'), const SizedBox(width: 12), _legende(SSMPalette.teal, 'Filles')]),
          const SizedBox(height: 12),
          if (_parNiveau.isEmpty)
            _etatVide('Aucune donnée')
          else
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => Colors.transparent,
                      tooltipMargin: 0,
                      tooltipPadding: EdgeInsets.zero,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                          BarTooltipItem(rod.toY.round().toString(), GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: SSMPalette.texte2)),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < _parNiveau.length; i++)
                      BarChartGroupData(
                        x: i,
                        barsSpace: 4,
                        showingTooltipIndicators: const [0, 1],
                        barRods: [
                          BarChartRodData(toY: _parNiveau[i].garcons.toDouble(), width: 12, color: SSMPalette.indigo, borderRadius: BorderRadius.circular(4)),
                          BarChartRodData(toY: _parNiveau[i].filles.toDouble(), width: 12, color: SSMPalette.teal, borderRadius: BorderRadius.circular(4)),
                        ],
                      ),
                  ],
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4,
                    getDrawingHorizontalLine: (v) => FlLine(color: SSMPalette.bordure, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= _parNiveau.length) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(_parNiveau[i].niveau, style: GoogleFonts.inter(fontSize: 10, color: SSMPalette.texte2)),
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

  // ── Répartition par classe ───────────────────────────────

  Widget _carteRepartitionClasse() {
    return SSMPanel(
      titre: 'Répartition par classe',
      padding: EdgeInsets.zero,
      child: _parClasse.isEmpty
          ? Padding(padding: const EdgeInsets.all(16), child: _etatVide('Aucune classe'))
          : SSMDataTable(
              colonnes: const [SSMDataColumn('Classe'), SSMDataColumn('Effectif')],
              lignes: [
                for (final c in _parClasse)
                  [
                    Text(c.classe, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
                    Text('${c.total}', style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
                  ],
              ],
            ),
    );
  }

  Widget _legende(Color couleur, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: couleur, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte2)),
      ],
    );
  }

  Widget _etatVide(String message) {
    return SizedBox(height: 100, child: Center(child: Text(message, style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2))));
  }
}
