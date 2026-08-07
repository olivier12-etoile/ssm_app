import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/dashboard_frais_model.dart';
import '../../services/dashboard_frais_service.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _teal = Color(0xFF0D9488);
const Color _vert = Color(0xFF16A34A);
const Color _rouge = Color(0xFFDC2626);
const Color _gris = Color(0xFF94A3B8);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);

String _formatMontant(double m) {
  final entier = m.round();
  final texte = entier.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < texte.length; i++) {
    if (i > 0 && (texte.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(texte[i]);
  }
  return '$buffer FCFA';
}

class StatistiquesFraisScreen extends StatefulWidget {
  const StatistiquesFraisScreen({super.key});

  @override
  State<StatistiquesFraisScreen> createState() => _StatistiquesFraisScreenState();
}

class _StatistiquesFraisScreenState extends State<StatistiquesFraisScreen> {
  StatistiquesFrais? _stats;
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final stats = await DashboardFraisService.getStatistiques();
      setState(() {
        _stats = stats;
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
              child: _chargement
                  ? const Center(child: CircularProgressIndicator(color: _indigo))
                  : _erreur != null
                      ? _vueErreur()
                      : RefreshIndicator(
                          onRefresh: _charger,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                            children: [
                              _carteBarres(
                                titre: 'Recettes par classe',
                                serie: _stats!.recettesParClasse,
                                couleur: _indigo,
                              ),
                              const SizedBox(height: 16),
                              _carteBarres(
                                titre: 'Recettes par niveau',
                                serie: _stats!.recettesParNiveau,
                                couleur: _teal,
                              ),
                              const SizedBox(height: 20),
                              _titreSection('Top 5 classes à jour'),
                              if (_stats!.topClassesAJour.isEmpty)
                                _messageVide('Aucune classe avec un taux de recouvrement calculable.')
                              else
                                ..._stats!.topClassesAJour.map((c) => _carteClasseTaux(c, _vert)),
                              const SizedBox(height: 20),
                              _titreSection('Top 5 classes en retard'),
                              if (_stats!.topClassesRetard.isEmpty)
                                _messageVide('Aucune classe en retard.')
                              else
                                ..._stats!.topClassesRetard.map((c) => _carteClasseTaux(c, _rouge)),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vueErreur() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: _rouge, size: 40),
            const SizedBox(height: 12),
            Text(_erreur!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: _texte)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _charger,
              style: ElevatedButton.styleFrom(backgroundColor: _indigo, foregroundColor: Colors.white),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageVide(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(message, style: GoogleFonts.inter(color: _gris)),
    );
  }

  Widget _titreSection(String titre) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        titre,
        style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: _texteFonce),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // EN-TÊTE
  // ══════════════════════════════════════════════════════

  Widget _enTete() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_indigo, _teal], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              'Statistiques financières',
              style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // GRAPHIQUE BARRES
  // ══════════════════════════════════════════════════════

  Widget _carteBarres({required String titre, required SerieGraphique serie, required Color couleur}) {
    final maxY = serie.valeurs.isEmpty ? 100.0 : (serie.valeurs.reduce((a, b) => a > b ? a : b) * 1.2);

    return _carteGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titre, style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: _texteFonce)),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: serie.estVide
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
                            _formatMontant(rod.toY),
                            const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      barGroups: [
                        for (var i = 0; i < serie.valeurs.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: serie.valeurs[i],
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
                        getDrawingHorizontalLine: (v) => FlLine(
                          color: _texteFonce.withValues(alpha: 0.04),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 44,
                            getTitlesWidget: (value, meta) => Text(
                              '${(value / 1000).toStringAsFixed(0)}k',
                              style: GoogleFonts.inter(fontSize: 9, color: _gris),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 46,
                            getTitlesWidget: (value, meta) {
                              final i = value.toInt();
                              if (i < 0 || i >= serie.labels.length) return const SizedBox();
                              final libelle = serie.labels[i];
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

  // ══════════════════════════════════════════════════════
  // TOP CLASSES
  // ══════════════════════════════════════════════════════

  Widget _carteClasseTaux(ClasseTaux classe, Color couleur) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  classe.classeNom,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _texteFonce),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (classe.taux / 100).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: const Color(0xFFF1F5F9),
                    color: couleur,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${classe.taux.toStringAsFixed(0)}%',
            style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.w700, color: couleur),
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
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
