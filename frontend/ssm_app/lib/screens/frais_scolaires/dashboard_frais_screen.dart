import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/dashboard_frais_model.dart';
import '../../services/dashboard_frais_service.dart';
import '../../widgets/ssm_widgets.dart';
import 'debiteurs_screen.dart';
import 'statistiques_frais_screen.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _teal = Color(0xFF0D9488);
const Color _ambre = Color(0xFFD97706);
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

class DashboardFraisScreen extends StatefulWidget {
  const DashboardFraisScreen({super.key});

  @override
  State<DashboardFraisScreen> createState() => _DashboardFraisScreenState();
}

class _DashboardFraisScreenState extends State<DashboardFraisScreen> {
  ResumeFinancier? _resume;
  bool _chargement = true;
  String? _erreur;
  bool _exportEnCours = false;

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
      final resume = await DashboardFraisService.getResume();
      setState(() {
        _resume = resume;
        _chargement = false;
      });
    } catch (e) {
      setState(() {
        _chargement = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _afficherErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: _rouge),
    );
  }

  Future<void> _genererRapport(String format) async {
    setState(() => _exportEnCours = true);
    try {
      final octets = await DashboardFraisService.getRapport(format: format);
      final dossier = await getTemporaryDirectory();
      final extension = format == 'excel' ? 'xlsx' : 'pdf';
      final fichier = File('${dossier.path}/rapport_financier.$extension');
      await fichier.writeAsBytes(octets);
      await OpenFile.open(fichier.path);
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _exportEnCours = false);
    }
  }

  Future<void> _choisirFormatRapport() async {
    final format = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Text('Générer le rapport financier', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: _rouge),
              title: const Text('Format PDF'),
              onTap: () => Navigator.pop(context, 'pdf'),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart, color: _vert),
              title: const Text('Format Excel'),
              onTap: () => Navigator.pop(context, 'excel'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (format != null) _genererRapport(format);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: _chargement
            ? const Center(child: CircularProgressIndicator(color: _indigo))
            : _erreur != null
                ? _vueErreur()
                : RefreshIndicator(
                    onRefresh: _charger,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      children: [
                        _enTete(),
                        const SizedBox(height: 16),
                        _grilleResume(),
                        const SizedBox(height: 16),
                        _carteTauxRecouvrement(),
                        const SizedBox(height: 16),
                        _carteEvolution(),
                        const SizedBox(height: 16),
                        _boutonsRapides(),
                      ],
                    ),
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

  // ══════════════════════════════════════════════════════
  // EN-TÊTE
  // ══════════════════════════════════════════════════════

  Widget _enTete() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_indigo, _teal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Frais Scolaires',
            style: GoogleFonts.sora(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            _resume?.anneeLibelle ?? 'Tableau de bord financier',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // GRILLE RÉSUMÉ 2×3
  // ══════════════════════════════════════════════════════

  Widget _grilleResume() {
    final r = _resume!;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.5,
      children: [
        SSMStatCard(
          titre: 'Montant attendu',
          valeur: _formatMontant(r.montantAttendu),
          icone: Icons.account_balance_wallet_outlined,
          couleurIcone: _indigo,
        ),
        SSMStatCard(
          titre: 'Encaissé',
          valeur: _formatMontant(r.montantEncaisse),
          icone: Icons.payments_outlined,
          couleurIcone: _teal,
        ),
        SSMStatCard(
          titre: 'Restant',
          valeur: _formatMontant(r.montantRestant),
          icone: Icons.error_outline,
          couleurIcone: _rouge,
        ),
        SSMStatCard(
          titre: 'Élèves à jour',
          valeur: '${r.nombreAJour}',
          icone: Icons.check_circle_outline,
          couleurIcone: _vert,
        ),
        SSMStatCard(
          titre: 'Partiels',
          valeur: '${r.nombrePartiel}',
          icone: Icons.hourglass_bottom,
          couleurIcone: _ambre,
        ),
        SSMStatCard(
          titre: 'Aucun paiement',
          valeur: '${r.nombreAucunPaiement}',
          icone: Icons.highlight_off,
          couleurIcone: _rouge,
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  // TAUX DE RECOUVREMENT
  // ══════════════════════════════════════════════════════

  Widget _carteTauxRecouvrement() {
    final taux = _resume!.tauxRecouvrement.clamp(0.0, 100.0);
    final couleur = taux >= 80 ? _vert : (taux >= 50 ? _ambre : _rouge);

    return _carteGlass(
      child: Row(
        children: [
          SizedBox(
            width: 84,
            height: 84,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 84,
                  height: 84,
                  child: CircularProgressIndicator(
                    value: taux / 100,
                    strokeWidth: 8,
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor: AlwaysStoppedAnimation(couleur),
                  ),
                ),
                Text(
                  '${taux.toStringAsFixed(0)}%',
                  style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.w700, color: couleur),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Taux de recouvrement',
                  style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: _texteFonce),
                ),
                const SizedBox(height: 4),
                Text(
                  'Part du montant attendu déjà encaissée pour l\'année en cours.',
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
  // ÉVOLUTION MENSUELLE
  // ══════════════════════════════════════════════════════

  Widget _carteEvolution() {
    final points = _resume!.evolutionMensuelle;
    final valeurs = points.map((p) => p.montant).toList();
    final maxY = valeurs.isEmpty ? 100.0 : (valeurs.reduce((a, b) => a > b ? a : b) * 1.2);

    return _carteGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Évolution des recettes',
            style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: _texteFonce),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: points.isEmpty
                ? Center(child: Text('Aucune donnée', style: GoogleFonts.inter(color: _gris)))
                : LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: maxY <= 0 ? 100 : maxY,
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        horizontalInterval: (maxY <= 0 ? 100 : maxY) / 4,
                        getDrawingHorizontalLine: (v) => FlLine(
                          color: _texteFonce.withValues(alpha: 0.03),
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
                            reservedSize: 28,
                            getTitlesWidget: (value, meta) {
                              final i = value.toInt();
                              if (i < 0 || i >= points.length) return const SizedBox();
                              final libelle = points[i].mois;
                              final court = libelle.length > 3 ? libelle.substring(0, 3) : libelle;
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(court, style: GoogleFonts.inter(fontSize: 9, color: _texte)),
                              );
                            },
                          ),
                        ),
                      ),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => _indigo,
                          getTooltipItems: (spots) => spots
                              .map((s) => LineTooltipItem(
                                    _formatMontant(s.y),
                                    const TextStyle(color: Colors.white, fontSize: 11),
                                  ))
                              .toList(),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [for (var i = 0; i < valeurs.length; i++) FlSpot(i.toDouble(), valeurs[i])],
                          isCurved: true,
                          color: _teal,
                          barWidth: 3,
                          dotData: FlDotData(
                            getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                              radius: 3,
                              color: Colors.white,
                              strokeWidth: 2,
                              strokeColor: _teal,
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [_teal.withValues(alpha: 0.18), _teal.withValues(alpha: 0.0)],
                            ),
                          ),
                        ),
                      ],
                    ),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                  ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // BOUTONS RAPIDES
  // ══════════════════════════════════════════════════════

  Widget _boutonsRapides() {
    return Row(
      children: [
        Expanded(
          child: SSMActionRapide(
            icone: Icons.people_outline,
            label: 'Voir débiteurs',
            couleur: _rouge,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebiteursScreen())),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SSMActionRapide(
            icone: Icons.bar_chart,
            label: 'Statistiques',
            couleur: _indigo,
            onTap: () =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => const StatistiquesFraisScreen())),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _exportEnCours
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _teal)),
                )
              : SSMActionRapide(
                  icone: Icons.description_outlined,
                  label: 'Générer rapport',
                  couleur: _teal,
                  onTap: _choisirFormatRapport,
                ),
        ),
      ],
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
