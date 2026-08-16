import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/dashboard_frais_model.dart';
import '../../services/dashboard_frais_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_panel.dart';
import '../../widgets/ssm/ssm_quick_action_button.dart';
import '../../widgets/ssm/ssm_sous_entete.dart';
import '../../widgets/ssm/ssm_stat_card.dart';
import 'debiteurs_screen.dart';
import 'statistiques_frais_screen.dart';

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
      SnackBar(content: Text(message), backgroundColor: SSMPalette.rouge),
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
      backgroundColor: SSMPalette.blanc,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: SSMPalette.bordure, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('Générer le rapport financier', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: SSMPalette.rouge),
              title: const Text('Format PDF'),
              onTap: () => Navigator.pop(context, 'pdf'),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart, color: SSMPalette.teal),
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
      backgroundColor: SSMPalette.fond,
      body: SafeArea(
        child: Column(
          children: [
            SSMSousEnTete(
              titre: 'Frais Scolaires',
              sousTitre: _resume?.anneeLibelle ?? 'Tableau de bord financier',
              onRetour: () => Navigator.pop(context),
            ),
            Expanded(
              child: _chargement
                  ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
                  : _erreur != null
                      ? _vueErreur()
                      : RefreshIndicator(
                          onRefresh: _charger,
                          color: SSMPalette.indigo,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                            children: [
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

  // ══════════════════════════════════════════════════════
  // GRILLE RÉSUMÉ 2×3
  // ══════════════════════════════════════════════════════

  Widget _grilleResume() {
    final r = _resume!;
    final cartes = <Widget>[
      SSMStatCard(icone: Icons.account_balance_wallet_outlined, couleur: SSMPalette.indigo, valeur: _formatMontant(r.montantAttendu), label: 'Montant attendu'),
      SSMStatCard(icone: Icons.payments_outlined, couleur: SSMPalette.teal, valeur: _formatMontant(r.montantEncaisse), label: 'Encaissé'),
      SSMStatCard(icone: Icons.error_outline, couleur: SSMPalette.rouge, valeur: _formatMontant(r.montantRestant), label: 'Restant'),
      SSMStatCard(icone: Icons.check_circle_outline, couleur: SSMPalette.teal, valeur: '${r.nombreAJour}', label: 'Élèves à jour'),
      SSMStatCard(icone: Icons.hourglass_bottom, couleur: SSMPalette.ambre, valeur: '${r.nombrePartiel}', label: 'Partiels'),
      SSMStatCard(icone: Icons.highlight_off, couleur: SSMPalette.rouge, valeur: '${r.nombreAucunPaiement}', label: 'Aucun paiement'),
    ];

    return LayoutBuilder(builder: (context, contraintes) {
      final colonnes = contraintes.maxWidth >= 760 ? 3 : (contraintes.maxWidth >= 520 ? 2 : 1);
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: cartes.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: colonnes,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 168,
        ),
        itemBuilder: (context, i) => cartes[i],
      );
    });
  }

  // ══════════════════════════════════════════════════════
  // TAUX DE RECOUVREMENT — CircularProgressIndicator conservé, seules les
  // couleurs sont alignées sur SSMPalette.
  // ══════════════════════════════════════════════════════

  Widget _carteTauxRecouvrement() {
    final taux = _resume!.tauxRecouvrement.clamp(0.0, 100.0);
    final couleur = taux >= 80 ? SSMPalette.teal : (taux >= 50 ? SSMPalette.ambre : SSMPalette.rouge);

    return SSMPanel(
      titre: 'Taux de recouvrement',
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
            child: Text(
              'Part du montant attendu déjà encaissée pour l\'année en cours.',
              style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2),
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

    return SSMPanel(
      titre: 'Évolution des recettes',
      child: SizedBox(
        height: 200,
        child: points.isEmpty
            ? Center(child: Text('Aucune donnée', style: GoogleFonts.inter(color: SSMPalette.texte3)))
            : LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY <= 0 ? 100 : maxY,
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: (maxY <= 0 ? 100 : maxY) / 4,
                    getDrawingHorizontalLine: (v) => FlLine(
                      color: SSMPalette.texte1.withValues(alpha: 0.03),
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
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= points.length) return const SizedBox();
                          final libelle = points[i].mois;
                          final court = libelle.length > 3 ? libelle.substring(0, 3) : libelle;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(court, style: GoogleFonts.inter(fontSize: 9, color: SSMPalette.texte2)),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => SSMPalette.indigo,
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
                      color: SSMPalette.teal,
                      barWidth: 3,
                      dotData: FlDotData(
                        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                          radius: 3,
                          color: Colors.white,
                          strokeWidth: 2,
                          strokeColor: SSMPalette.teal,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [SSMPalette.teal.withValues(alpha: 0.18), SSMPalette.teal.withValues(alpha: 0.0)],
                        ),
                      ),
                    ),
                  ],
                ),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
              ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // ACTIONS RAPIDES
  // ══════════════════════════════════════════════════════

  Widget _boutonsRapides() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        SSMQuickActionButton(
          icone: Icons.people_outline,
          label: 'Voir débiteurs',
          variante: SSMActionVariante.rouge,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebiteursScreen())),
        ),
        SSMQuickActionButton(
          icone: Icons.bar_chart,
          label: 'Statistiques',
          variante: SSMActionVariante.primaire,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatistiquesFraisScreen())),
        ),
        _exportEnCours
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: SSMPalette.teal)),
              )
            : SSMQuickActionButton(
                icone: Icons.description_outlined,
                label: 'Générer rapport',
                variante: SSMActionVariante.teal,
                onTap: _choisirFormatRapport,
              ),
      ],
    );
  }
}
