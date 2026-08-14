import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/statistique_detail_model.dart';
import '../../services/annee_service.dart';
import '../../services/statistique_detail_service.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _teal = Color(0xFF0D9488);
const Color _rouge = Color(0xFFDC2626);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);
const Color _gris = Color(0xFF94A3B8);
const Color _fond = Color(0xFFEFF6FF);

// ══════════════════════════════════════════════════════════
// Écran détaillé "Inscriptions" du module Statistiques (Phase 5) : évolution
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
      backgroundColor: _fond,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: Text('Inscriptions détaillées', style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: Colors.white)),
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Positioned(top: -80, right: -60, child: _blob(size: 240, couleur: _indigo.withValues(alpha: 0.08))),
          Positioned(bottom: -60, left: -60, child: _blob(size: 200, couleur: _teal.withValues(alpha: 0.10))),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _charger,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _selecteurAnnee(),
                  const SizedBox(height: 20),
                  if (_chargement && _erreur == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 80),
                      child: Center(child: CircularProgressIndicator(color: _indigo)),
                    )
                  else if (_erreur != null)
                    _carteErreur(_erreur!, _charger)
                  else ...[
                    _carteEvolution(),
                    const SizedBox(height: 16),
                    _carteRepartitionNiveau(),
                    const SizedBox(height: 16),
                    _carteRepartitionClasse(),
                  ],
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
        child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: couleur)),
      ),
    );
  }

  Widget _selecteurAnnee() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
          ),
          child: DropdownButtonFormField<int>(
            value: _anneeId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Année scolaire',
              labelStyle: GoogleFonts.inter(fontSize: 12, color: _texte),
              isDense: true,
              border: InputBorder.none,
            ),
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _texteFonce),
            items: _annees
                .map((a) => DropdownMenuItem<int>(value: a['id'] as int, child: Text(a['libelle'] as String? ?? '—')))
                .toList(),
            onChanged: _changerAnnee,
          ),
        ),
      ),
    );
  }

  Widget _carteErreur(String message, Future<void> Function() onReessayer) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: _rouge, size: 36),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center, style: GoogleFonts.inter(color: _texte)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onReessayer,
            style: ElevatedButton.styleFrom(backgroundColor: _indigo, foregroundColor: Colors.white),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _carteGlass({required Widget child, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding ?? const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
            boxShadow: [BoxShadow(color: _texteFonce.withValues(alpha: 0.06), blurRadius: 32, offset: const Offset(0, 8))],
          ),
          child: child,
        ),
      ),
    );
  }

  // ── Évolution des effectifs ──────────────────────────────

  Widget _carteEvolution() {
    final maxValeur = _evolution.isEmpty ? 0 : _evolution.map((e) => e.total).reduce((a, b) => a > b ? a : b);
    final maxY = maxValeur <= 0 ? 10.0 : maxValeur * 1.2;

    return _carteGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Évolution des effectifs', style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: _texteFonce)),
          const SizedBox(height: 4),
          Text(
            "Total des élèves inscrits sur les dernières années scolaires de l'établissement.",
            style: GoogleFonts.inter(fontSize: 11, color: _texte),
          ),
          const SizedBox(height: 14),
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
                    getDrawingHorizontalLine: (v) => FlLine(color: _texteFonce.withValues(alpha: 0.03), strokeWidth: 1),
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
                            child: Text(_evolution[i].annee, style: GoogleFonts.inter(fontSize: 10, color: _texte)),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => _indigo,
                      getTooltipItems: (spots) =>
                          spots.map((s) => LineTooltipItem(s.y.toStringAsFixed(0), const TextStyle(color: Colors.white, fontSize: 11))).toList(),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [for (var i = 0; i < _evolution.length; i++) FlSpot(i.toDouble(), _evolution[i].total.toDouble())],
                      isCurved: true,
                      color: _indigo,
                      barWidth: 3,
                      dotData: FlDotData(
                        getDotPainter: (spot, percent, bar, index) =>
                            FlDotCirclePainter(radius: 4, color: _indigo, strokeWidth: 2, strokeColor: Colors.white),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [_indigo.withValues(alpha: 0.15), _indigo.withValues(alpha: 0.0)],
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

    return _carteGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Répartition par niveau', style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: _texteFonce)),
              Row(children: [_legende(_indigo, 'Garçons'), const SizedBox(width: 10), _legende(_teal, 'Filles')]),
            ],
          ),
          const SizedBox(height: 14),
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
                          BarTooltipItem(rod.toY.round().toString(), GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _texte)),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < _parNiveau.length; i++)
                      BarChartGroupData(
                        x: i,
                        barsSpace: 4,
                        showingTooltipIndicators: const [0, 1],
                        barRods: [
                          BarChartRodData(toY: _parNiveau[i].garcons.toDouble(), width: 12, color: _indigo, borderRadius: BorderRadius.circular(4)),
                          BarChartRodData(toY: _parNiveau[i].filles.toDouble(), width: 12, color: _teal, borderRadius: BorderRadius.circular(4)),
                        ],
                      ),
                  ],
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4,
                    getDrawingHorizontalLine: (v) => FlLine(color: _texteFonce.withValues(alpha: 0.04), strokeWidth: 1),
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
                            child: Text(_parNiveau[i].niveau, style: GoogleFonts.inter(fontSize: 10, color: _texte)),
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
    return _carteGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Répartition par classe', style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: _texteFonce)),
          const SizedBox(height: 14),
          if (_parClasse.isEmpty)
            _etatVide('Aucune classe')
          else
            ..._parClasse.map((c) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(c.classe, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _texteFonce)),
                      ),
                      Text('${c.total}', style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700, color: _indigo)),
                      const SizedBox(width: 4),
                      Text('élève(s)', style: GoogleFonts.inter(fontSize: 11, color: _gris)),
                    ],
                  ),
                )),
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
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: _texte)),
      ],
    );
  }

  Widget _etatVide(String message) {
    return SizedBox(height: 100, child: Center(child: Text(message, style: GoogleFonts.inter(fontSize: 12, color: _texte))));
  }
}
