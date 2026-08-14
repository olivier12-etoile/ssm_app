import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/notification_model.dart';
import '../../models/statistique_notification_model.dart';
import '../../services/statistique_notification_service.dart';
import '../../widgets/ssm_widgets.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _teal = Color(0xFF0D9488);
const Color _ambre = Color(0xFFD97706);
const Color _vert = Color(0xFF16A34A);
const Color _rouge = Color(0xFFDC2626);
const Color _violet = Color(0xFF7C3AED);
const Color _gris = Color(0xFF94A3B8);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);
const Color _fond = Color(0xFFF8FAFC);

const Map<CategorieNotification, Color> _couleursCategorie = {
  CategorieNotification.scolarite: _indigo,
  CategorieNotification.finances: _vert,
  CategorieNotification.presence: _ambre,
  CategorieNotification.administration: _violet,
  CategorieNotification.discipline: _rouge,
  CategorieNotification.vieScolaire: _teal,
};

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
      backgroundColor: _fond,
      appBar: AppBar(
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
        title: Text('Statistiques des notifications', style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          _selecteurPeriode(),
          Expanded(
            child: _chargement
                ? const Center(child: CircularProgressIndicator(color: _indigo))
                : _erreur != null
                    ? _vueErreur(_erreur!)
                    : _stats == null
                        ? const SizedBox.shrink()
                        : RefreshIndicator(
                            onRefresh: _charger,
                            child: ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                _cartesResume(_stats!),
                                const SizedBox(height: 24),
                                SSMSectionTitre(titre: 'Répartition par canal'),
                                _cartePie(
                                  _stats!.parCanal.map((k, v) => MapEntry(
                                        CanalNotification.depuisApi(k).libelle,
                                        _EntreePie(v, CanalNotification.depuisApi(k).couleur),
                                      )),
                                ),
                                const SizedBox(height: 24),
                                SSMSectionTitre(titre: 'Répartition par catégorie'),
                                _cartePie(
                                  _stats!.parCategorie.map((k, v) => MapEntry(
                                        CategorieNotification.depuisApi(k).libelle,
                                        _EntreePie(v, _couleursCategorie[CategorieNotification.depuisApi(k)] ?? _gris),
                                      )),
                                ),
                                const SizedBox(height: 24),
                                SSMSectionTitre(titre: 'Évolution sur la période'),
                                _carteEvolution(_stats!.parPeriode),
                              ],
                            ),
                          ),
          ),
        ],
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
            const Icon(Icons.error_outline, color: _rouge, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: GoogleFonts.inter(color: _texte)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _charger, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }

  Widget _selecteurPeriode() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
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
              selectedColor: _indigo,
              labelStyle: TextStyle(color: _periode == 'personnalise' ? Colors.white : _texte),
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
      selectedColor: _indigo,
      labelStyle: TextStyle(color: selectionne ? Colors.white : _texte),
    );
  }

  Widget _cartesResume(StatistiqueNotification s) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        SSMStatCard(titre: 'Total envoyées', valeur: '${s.totalEnvoyees}', icone: Icons.send_outlined, couleurIcone: const Color(0xFF0284C7)),
        SSMStatCard(titre: 'Délivrées', valeur: '${s.totalDelivrees}', icone: Icons.check_circle_outline, couleurIcone: _vert),
        SSMStatCard(titre: 'Échouées', valeur: '${s.totalEchouees}', icone: Icons.error_outline, couleurIcone: _rouge),
        SSMStatCard(
          titre: 'Taux de réussite',
          valeur: '${s.tauxReussite.toStringAsFixed(1)}%',
          icone: Icons.trending_up,
          couleurIcone: _teal,
        ),
      ],
    );
  }

  Widget _cartePie(Map<String, _EntreePie> donnees) {
    final total = donnees.values.fold<int>(0, (s, e) => s + e.valeur);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: total == 0
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Aucune donnée sur cette période.', style: GoogleFonts.inter(color: _gris))),
            )
          : Row(
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                      sections: donnees.entries.map((e) {
                        return PieChartSectionData(
                          value: e.value.valeur.toDouble(),
                          color: e.value.couleur,
                          showTitle: false,
                          radius: 24,
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
                            Container(width: 10, height: 10, decoration: BoxDecoration(color: e.value.couleur, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(e.key, style: GoogleFonts.inter(fontSize: 12, color: _texte), overflow: TextOverflow.ellipsis),
                            ),
                            Text(
                              '${e.value.valeur} (${pourcentage.toStringAsFixed(0)}%)',
                              style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w600, color: _texteFonce),
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
    if (points.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Center(child: Text('Aucune donnée sur cette période.', style: GoogleFonts.inter(color: _gris))),
      );
    }

    final maxY = points
        .expand((p) => [p.envoyees, p.delivrees, p.echouees])
        .fold<int>(0, (m, v) => v > m ? v : m)
        .toDouble();
    final plafond = maxY <= 0 ? 5.0 : maxY * 1.3;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 12),
            child: Wrap(
              spacing: 14,
              children: [
                _legendeLigne('Envoyées', const Color(0xFF0284C7)),
                _legendeLigne('Délivrées', _vert),
                _legendeLigne('Échouées', _rouge),
              ],
            ),
          ),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: plafond,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: plafond / 4,
                  getDrawingHorizontalLine: (v) => FlLine(color: _texteFonce.withValues(alpha: 0.05), strokeWidth: 1),
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
                        style: GoogleFonts.inter(fontSize: 9, color: _gris),
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
                          child: Text('${d.day}/${d.month}', style: GoogleFonts.inter(fontSize: 9, color: _gris)),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => _indigo,
                    getTooltipItems: (spots) => spots
                        .map((s) => LineTooltipItem('${s.y.toInt()}', const TextStyle(color: Colors.white, fontSize: 11)))
                        .toList(),
                  ),
                ),
                lineBarsData: [
                  _ligne(points, (p) => p.envoyees.toDouble(), const Color(0xFF0284C7)),
                  _ligne(points, (p) => p.delivrees.toDouble(), _vert),
                  _ligne(points, (p) => p.echouees.toDouble(), _rouge),
                ],
              ),
              duration: const Duration(milliseconds: 400),
            ),
          ),
        ],
      ),
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
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: _texte)),
      ],
    );
  }
}

class _EntreePie {
  final int valeur;
  final Color couleur;
  _EntreePie(this.valeur, this.couleur);
}
