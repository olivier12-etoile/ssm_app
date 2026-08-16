import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/notification_model.dart';
import '../../models/statistique_notification_model.dart';
import '../../services/statistique_notification_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_panel.dart';
import '../../widgets/ssm/ssm_sous_entete.dart';
import '../../widgets/ssm/ssm_stat_card.dart';

// Couleurs de catégorie alignées sur la palette générale du thème (indigo /
// teal / ambre / rouge uniquement — voir SSMPalette).
const Map<CategorieNotification, Color> _couleursCategorie = {
  CategorieNotification.scolarite: SSMPalette.indigo,
  CategorieNotification.finances: SSMPalette.teal,
  CategorieNotification.presence: SSMPalette.ambre,
  CategorieNotification.administration: SSMPalette.indigo,
  CategorieNotification.discipline: SSMPalette.rouge,
  CategorieNotification.vieScolaire: SSMPalette.teal,
};

const Color _bleuInfo = Color(0xFF0284C7);

String _formatDateCourt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ══════════════════════════════════════════════════════════
// Statistiques d'envoi : résumé, répartitions par canal/catégorie,
// évolution dans le temps (fl_chart).
// ══════════════════════════════════════════════════════════
class StatistiquesNotificationsScreen extends StatefulWidget {
  const StatistiquesNotificationsScreen({super.key});

  @override
  State<StatistiquesNotificationsScreen> createState() => _StatistiquesNotificationsScreenState();
}

class _StatistiquesNotificationsScreenState extends State<StatistiquesNotificationsScreen> {
  String _periode = 'mois'; // 'semaine' | 'mois' | 'personnalise'
  DateTime? _dateDebutPerso;
  DateTime? _dateFinPerso;

  StatistiqueNotification? _stats;
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  (DateTime, DateTime) get _plage {
    final maintenant = DateTime.now();
    switch (_periode) {
      case 'semaine':
        return (maintenant.subtract(const Duration(days: 7)), maintenant);
      case 'personnalise':
        return (_dateDebutPerso ?? maintenant.subtract(const Duration(days: 30)), _dateFinPerso ?? maintenant);
      default:
        return (maintenant.subtract(const Duration(days: 30)), maintenant);
    }
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final (debut, fin) = _plage;
      final stats = await StatistiqueNotificationService.getStatistiques(
        dateDebut: _formatDateCourt(debut),
        dateFin: _formatDateCourt(fin),
      );
      if (!mounted) return;
      setState(() {
        _stats = stats;
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

  Future<void> _choisirPeriodePersonnalisee() async {
    final plage = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _dateDebutPerso ?? DateTime.now().subtract(const Duration(days: 30)),
        end: _dateFinPerso ?? DateTime.now(),
      ),
    );
    if (plage == null) return;
    setState(() {
      _periode = 'personnalise';
      _dateDebutPerso = plage.start;
      _dateFinPerso = plage.end;
    });
    _charger();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SSMPalette.fond,
      body: SafeArea(
        child: Column(
          children: [
            SSMSousEnTete(titre: 'Statistiques des notifications', onRetour: () => Navigator.pop(context)),
            _selecteurPeriode(),
            Expanded(
              child: _chargement
                  ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
                  : _erreur != null
                      ? _vueErreur(_erreur!)
                      : _stats == null
                          ? const SizedBox.shrink()
                          : RefreshIndicator(
                              onRefresh: _charger,
                              color: SSMPalette.indigo,
                              child: ListView(
                                padding: const EdgeInsets.all(16),
                                children: [
                                  _cartesResume(_stats!),
                                  const SizedBox(height: 20),
                                  _cartePie(
                                    titre: 'Répartition par canal',
                                    donnees: _stats!.parCanal.map((k, v) => MapEntry(
                                          CanalNotification.depuisApi(k).libelle,
                                          _EntreePie(v, CanalNotification.depuisApi(k).couleur),
                                        )),
                                  ),
                                  const SizedBox(height: 16),
                                  _cartePie(
                                    titre: 'Répartition par catégorie',
                                    donnees: _stats!.parCategorie.map((k, v) => MapEntry(
                                          CategorieNotification.depuisApi(k).libelle,
                                          _EntreePie(v, _couleursCategorie[CategorieNotification.depuisApi(k)] ?? SSMPalette.teal),
                                        )),
                                  ),
                                  const SizedBox(height: 16),
                                  _carteEvolution(_stats!.parPeriode),
                                ],
                              ),
                            ),
            ),
          ],
        ),
      ),
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
            OutlinedButton(onPressed: _charger, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }

  Widget _selecteurPeriode() {
    return Container(
      color: SSMPalette.blanc,
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: SSMPalette.bordure))),
      child: Row(
        children: [
          Expanded(child: _chipPeriode('semaine', 'Semaine')),
          const SizedBox(width: 8),
          Expanded(child: _chipPeriode('mois', 'Mois')),
          const SizedBox(width: 8),
          Expanded(
            child: ChoiceChip(
              selected: _periode == 'personnalise',
              onSelected: (_) => _choisirPeriodePersonnalisee(),
              label: Text(
                _periode == 'personnalise' && _dateDebutPerso != null
                    ? '${_formatDateCourt(_dateDebutPerso!)} → ${_formatDateCourt(_dateFinPerso!)}'
                    : 'Personnalisé',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
              selectedColor: SSMPalette.indigo,
              backgroundColor: const Color(0xFFF1F5F9),
              side: BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.pilule)),
              labelStyle: TextStyle(color: _periode == 'personnalise' ? Colors.white : SSMPalette.texte2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipPeriode(String valeur, String label) {
    final selectionne = _periode == valeur;
    return ChoiceChip(
      selected: selectionne,
      onSelected: (_) {
        setState(() => _periode = valeur);
        _charger();
      },
      label: Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
      selectedColor: SSMPalette.indigo,
      backgroundColor: const Color(0xFFF1F5F9),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.pilule)),
      labelStyle: TextStyle(color: selectionne ? Colors.white : SSMPalette.texte2),
    );
  }

  Widget _cartesResume(StatistiqueNotification s) {
    final cartes = <Widget>[
      SSMStatCard(icone: Icons.send_outlined, couleur: _bleuInfo, valeur: '${s.totalEnvoyees}', label: 'Total envoyées'),
      SSMStatCard(icone: Icons.check_circle_outline, couleur: SSMPalette.teal, valeur: '${s.totalDelivrees}', label: 'Délivrées'),
      SSMStatCard(icone: Icons.error_outline, couleur: SSMPalette.rouge, valeur: '${s.totalEchouees}', label: 'Échouées'),
      SSMStatCard(
        icone: Icons.trending_up,
        couleur: SSMPalette.ambre,
        valeur: '${s.tauxReussite.toStringAsFixed(1)}%',
        label: 'Taux de réussite',
      ),
    ];

    return LayoutBuilder(builder: (context, contraintes) {
      final colonnes = contraintes.maxWidth >= 760 ? 4 : (contraintes.maxWidth >= 480 ? 2 : 1);
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: cartes.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: colonnes,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 118,
        ),
        itemBuilder: (context, i) => cartes[i],
      );
    });
  }

  Widget _cartePie({required String titre, required Map<String, _EntreePie> donnees}) {
    final total = donnees.values.fold<int>(0, (s, e) => s + e.valeur);

    return SSMPanel(
      titre: titre,
      child: total == 0
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Aucune donnée sur cette période.', style: GoogleFonts.inter(color: SSMPalette.texte3))),
            )
          : Row(
              children: [
                SizedBox(
                  width: 110,
                  height: 110,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 28,
                      sections: donnees.entries.map((e) {
                        return PieChartSectionData(
                          value: e.value.valeur.toDouble(),
                          color: e.value.couleur,
                          showTitle: false,
                          radius: 22,
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: donnees.entries.map((e) {
                      final pourcentage = total > 0 ? (e.value.valeur / total * 100) : 0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Container(width: 9, height: 9, decoration: BoxDecoration(color: e.value.couleur, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(e.key, style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2), overflow: TextOverflow.ellipsis),
                            ),
                            Text(
                              '${e.value.valeur} (${pourcentage.toStringAsFixed(0)}%)',
                              style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w600, color: SSMPalette.texte1),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _carteEvolution(List<PointEvolution> points) {
    return SSMPanel(
      titre: 'Évolution sur la période',
      child: points.isEmpty
          ? Center(child: Text('Aucune donnée sur cette période.', style: GoogleFonts.inter(color: SSMPalette.texte3)))
          : _graphiqueEvolution(points),
    );
  }

  Widget _graphiqueEvolution(List<PointEvolution> points) {
    final maxY = points
        .expand((p) => [p.envoyees, p.delivrees, p.echouees])
        .fold<int>(0, (m, v) => v > m ? v : m)
        .toDouble();
    final plafond = maxY <= 0 ? 5.0 : maxY * 1.3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 14,
          children: [
            _legendeLigne('Envoyées', _bleuInfo),
            _legendeLigne('Délivrées', SSMPalette.teal),
            _legendeLigne('Échouées', SSMPalette.rouge),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: plafond,
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: plafond / 4,
                getDrawingHorizontalLine: (v) => FlLine(color: SSMPalette.bordure, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (value, meta) => Text(
                      value.toInt().toString(),
                      style: GoogleFonts.inter(fontSize: 9, color: SSMPalette.texte3),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: (points.length / 5).clamp(1, points.length).toDouble(),
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= points.length) return const SizedBox();
                      final d = points[i].date;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('${d.day}/${d.month}', style: GoogleFonts.inter(fontSize: 9, color: SSMPalette.texte3)),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => SSMPalette.indigo,
                  getTooltipItems: (spots) => spots
                      .map((s) => LineTooltipItem('${s.y.toInt()}', const TextStyle(color: Colors.white, fontSize: 11)))
                      .toList(),
                ),
              ),
              lineBarsData: [
                _ligne(points, (p) => p.envoyees.toDouble(), _bleuInfo),
                _ligne(points, (p) => p.delivrees.toDouble(), SSMPalette.teal),
                _ligne(points, (p) => p.echouees.toDouble(), SSMPalette.rouge),
              ],
            ),
            duration: const Duration(milliseconds: 400),
          ),
        ),
      ],
    );
  }

  LineChartBarData _ligne(List<PointEvolution> points, double Function(PointEvolution) valeur, Color couleur) {
    return LineChartBarData(
      spots: [for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), valeur(points[i]))],
      isCurved: true,
      color: couleur,
      barWidth: 2.5,
      dotData: const FlDotData(show: false),
    );
  }

  Widget _legendeLigne(String label, Color couleur) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 3, color: couleur),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte2)),
      ],
    );
  }
}

class _EntreePie {
  final int valeur;
  final Color couleur;
  _EntreePie(this.valeur, this.couleur);
}
