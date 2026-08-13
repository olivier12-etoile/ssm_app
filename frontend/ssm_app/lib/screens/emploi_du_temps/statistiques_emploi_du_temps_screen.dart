import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/dashboard_emploi_du_temps_model.dart';
import '../../services/annee_service.dart';
import '../../services/dashboard_emploi_du_temps_service.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _teal = Color(0xFF0D9488);
const Color _ambre = Color(0xFFD97706);
const Color _vert = Color(0xFF16A34A);
const Color _rouge = Color(0xFFDC2626);
const Color _gris = Color(0xFF94A3B8);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);

// ══════════════════════════════════════════════════════════
// StatistiquesEmploiDuTempsScreen — répartition des heures programmées
// (enseignant / matière / classe) et taux de complétion global.
// ══════════════════════════════════════════════════════════
class StatistiquesEmploiDuTempsScreen extends StatefulWidget {
  final int periodeId;

  const StatistiquesEmploiDuTempsScreen({super.key, required this.periodeId});

  @override
  State<StatistiquesEmploiDuTempsScreen> createState() => _StatistiquesEmploiDuTempsScreenState();
}

class _StatistiquesEmploiDuTempsScreenState extends State<StatistiquesEmploiDuTempsScreen> {
  late int _periodeId;
  List<Map<String, dynamic>> _periodes = [];

  List<HeuresParEntite> _heuresEnseignant = [];
  List<HeuresParEntite> _heuresMatiere = [];
  List<HeuresParEntite> _heuresClasse = [];
  int _tauxCompletionMoyen = 0;

  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _periodeId = widget.periodeId;
    _chargerPeriodes();
    _chargerStatistiques();
  }

  Future<void> _chargerPeriodes() async {
    try {
      final data = await AnneeService.anneeActive();
      final anneeId = (data['annee'] as Map<String, dynamic>?)?['id'] as int?;
      if (anneeId == null) return;
      final periodes = (await AnneeService.listerPeriodes(anneeId)).map((p) => p as Map<String, dynamic>).toList();
      if (mounted) setState(() => _periodes = periodes);
    } catch (_) {
      // Le sélecteur reste vide si la résolution échoue — non bloquant.
    }
  }

  Future<void> _chargerStatistiques() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final resultats = await Future.wait([
        DashboardEmploiDuTempsService.getHeuresParEnseignant(_periodeId),
        DashboardEmploiDuTempsService.getHeuresParMatiere(_periodeId),
        DashboardEmploiDuTempsService.getHeuresParClasse(_periodeId),
        DashboardEmploiDuTempsService.getTauxCompletion(_periodeId),
      ]);
      setState(() {
        _heuresEnseignant = resultats[0] as List<HeuresParEntite>;
        _heuresMatiere = resultats[1] as List<HeuresParEntite>;
        _heuresClasse = resultats[2] as List<HeuresParEntite>;
        _tauxCompletionMoyen = (resultats[3] as Map<String, dynamic>)['taux_completion_moyen'] as int? ?? 0;
        _chargement = false;
      });
    } catch (e) {
      setState(() {
        _chargement = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _enTete(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _chargerStatistiques,
                child: _chargement
                    ? const Center(child: CircularProgressIndicator(color: _indigo))
                    : _erreur != null
                        ? _vueErreur()
                        : ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              _carteTauxCompletion(),
                              const SizedBox(height: 16),
                              _carteBarres(titre: 'Heures par enseignant', donnees: _heuresEnseignant, couleur: _indigo),
                              const SizedBox(height: 16),
                              _carteBarres(titre: 'Heures par matière', donnees: _heuresMatiere, couleur: _teal),
                              const SizedBox(height: 16),
                              _carteBarres(titre: 'Heures par classe', donnees: _heuresClasse, couleur: _ambre),
                              const SizedBox(height: 40),
                            ],
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // EN-TÊTE
  // ══════════════════════════════════════════════════════

  Widget _enTete() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_indigo, _teal], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
              Expanded(
                child: Text('Statistiques — Emploi du Temps',
                    style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _periodes.any((p) => p['id'] == _periodeId) ? _periodeId : null,
                hint: Text('Période', style: GoogleFonts.inter(color: Colors.white)),
                dropdownColor: _indigo,
                icon: const Icon(Icons.expand_more, color: Colors.white),
                items: _periodes
                    .map((p) => DropdownMenuItem<int>(
                          value: p['id'] as int,
                          child: Text(p['nom'] as String, style: GoogleFonts.inter(color: Colors.white)),
                        ))
                    .toList(),
                onChanged: (id) {
                  if (id == null) return;
                  setState(() => _periodeId = id);
                  _chargerStatistiques();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vueErreur() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: _rouge, size: 36),
          const SizedBox(height: 10),
          Text(_erreur!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: _texte)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _chargerStatistiques,
            style: ElevatedButton.styleFrom(backgroundColor: _indigo, foregroundColor: Colors.white),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // TAUX DE COMPLÉTION (indicateur circulaire)
  // ══════════════════════════════════════════════════════

  Widget _carteTauxCompletion() {
    final couleur = _tauxCompletionMoyen >= 90 ? _vert : (_tauxCompletionMoyen >= 50 ? _ambre : _rouge);

    return _carteGlass(
      child: Row(
        children: [
          SizedBox(
            width: 88,
            height: 88,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 0,
                    centerSpaceRadius: 30,
                    sections: [
                      PieChartSectionData(value: _tauxCompletionMoyen.toDouble(), color: couleur, showTitle: false, radius: 14),
                      PieChartSectionData(
                        value: (100 - _tauxCompletionMoyen).toDouble(),
                        color: const Color(0xFFF1F5F9),
                        showTitle: false,
                        radius: 14,
                      ),
                    ],
                  ),
                ),
                Text('$_tauxCompletionMoyen%', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: couleur)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Taux de complétion global', style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: _texteFonce)),
                const SizedBox(height: 4),
                Text(
                  'Moyenne du volume horaire programmé par rapport au volume attendu, sur toutes les classes.',
                  style: GoogleFonts.inter(fontSize: 12, color: _texte),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // GRAPHIQUES BARRES
  // ══════════════════════════════════════════════════════

  Widget _carteBarres({required String titre, required List<HeuresParEntite> donnees, required Color couleur}) {
    final maxY = donnees.isEmpty ? 10.0 : (donnees.map((d) => d.heures).reduce((a, b) => a > b ? a : b) * 1.2);

    return _carteGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titre, style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: _texteFonce)),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: donnees.isEmpty
                ? Center(child: Text('Aucune donnée', style: GoogleFonts.inter(color: _gris)))
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY <= 0 ? 10 : maxY,
                      groupsSpace: 10,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => couleur,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                            '${rod.toY.toStringAsFixed(1)} h',
                            const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      barGroups: [
                        for (var i = 0; i < donnees.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: donnees[i].heures,
                                width: 18,
                                borderRadius: BorderRadius.circular(4),
                                gradient: LinearGradient(
                                  colors: [couleur, couleur.withValues(alpha: 0.5)],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ],
                          ),
                      ],
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        horizontalInterval: (maxY <= 0 ? 10 : maxY) / 4,
                        getDrawingHorizontalLine: (v) => FlLine(color: _texteFonce.withValues(alpha: 0.04), strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 34,
                            getTitlesWidget: (value, meta) =>
                                Text('${value.toInt()}h', style: GoogleFonts.inter(fontSize: 9, color: _gris)),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 46,
                            getTitlesWidget: (value, meta) {
                              final i = value.toInt();
                              if (i < 0 || i >= donnees.length) return const SizedBox();
                              final libelle = donnees[i].nom;
                              final court = libelle.length > 8 ? '${libelle.substring(0, 7)}…' : libelle;
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Transform.rotate(
                                  angle: -0.5,
                                  child: Text(court, style: GoogleFonts.inter(fontSize: 9, color: _texte)),
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

  Widget _carteGlass({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: child,
        ),
      ),
    );
  }
}
