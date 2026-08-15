import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/dashboard_frais_model.dart';
import '../../services/dashboard_frais_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_panel.dart';
import '../../widgets/ssm/ssm_sous_entete.dart';

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
      backgroundColor: SSMPalette.fond,
      body: SafeArea(
        child: Column(
          children: [
            SSMSousEnTete(titre: 'Statistiques financières', onRetour: () => Navigator.pop(context)),
            Expanded(
              child: _chargement
                  ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
                  : _erreur != null
                      ? _vueErreur()
                      : RefreshIndicator(
                          onRefresh: _charger,
                          color: SSMPalette.indigo,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                            children: [
                              _carteBarres(
                                titre: 'Recettes par classe',
                                serie: _stats!.recettesParClasse,
                                couleur: SSMPalette.indigo,
                              ),
                              const SizedBox(height: 16),
                              _carteBarres(
                                titre: 'Recettes par niveau',
                                serie: _stats!.recettesParNiveau,
                                couleur: SSMPalette.teal,
                              ),
                              const SizedBox(height: 16),
                              SSMPanel(
                                titre: 'Top 5 classes à jour',
                                child: _stats!.topClassesAJour.isEmpty
                                    ? _messageVide('Aucune classe avec un taux de recouvrement calculable.')
                                    : Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          for (var i = 0; i < _stats!.topClassesAJour.length; i++) ...[
                                            if (i > 0) const SizedBox(height: 8),
                                            _ligneClasseTaux(_stats!.topClassesAJour[i], SSMPalette.teal),
                                          ],
                                        ],
                                      ),
                              ),
                              const SizedBox(height: 16),
                              SSMPanel(
                                titre: 'Top 5 classes en retard',
                                child: _stats!.topClassesRetard.isEmpty
                                    ? _messageVide('Aucune classe en retard.')
                                    : Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          for (var i = 0; i < _stats!.topClassesRetard.length; i++) ...[
                                            if (i > 0) const SizedBox(height: 8),
                                            _ligneClasseTaux(_stats!.topClassesRetard[i], SSMPalette.rouge),
                                          ],
                                        ],
                                      ),
                              ),
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
            Icon(Icons.error_outline, color: SSMPalette.rouge, size: 40),
            const SizedBox(height: 12),
            Text(_erreur!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: SSMPalette.texte2)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _charger,
              style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.indigo, foregroundColor: Colors.white, elevation: 0),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageVide(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(message, style: GoogleFonts.inter(color: SSMPalette.texte3)),
    );
  }

  // ══════════════════════════════════════════════════════
  // GRAPHIQUE BARRES
  // ══════════════════════════════════════════════════════

  Widget _carteBarres({required String titre, required SerieGraphique serie, required Color couleur}) {
    final maxY = serie.valeurs.isEmpty ? 100.0 : (serie.valeurs.reduce((a, b) => a > b ? a : b) * 1.2);

    return SSMPanel(
      titre: titre,
      child: SizedBox(
        height: 220,
        child: serie.estVide
            ? Center(child: Text('Aucune donnée', style: GoogleFonts.inter(color: SSMPalette.texte3)))
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
                      color: SSMPalette.texte1.withValues(alpha: 0.04),
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
                          style: GoogleFonts.inter(fontSize: 9, color: SSMPalette.texte3),
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
                              child: Text(court, style: GoogleFonts.inter(fontSize: 9, color: SSMPalette.texte2)),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // TOP CLASSES
  // ══════════════════════════════════════════════════════

  Widget _ligneClasseTaux(ClasseTaux classe, Color couleur) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(SSMRayons.moyen),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  classe.classeNom,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: SSMPalette.texte1),
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
}
