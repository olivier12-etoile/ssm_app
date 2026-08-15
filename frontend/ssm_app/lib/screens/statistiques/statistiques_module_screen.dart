import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/utilisateur.dart';
import '../../models/statistique_generale_model.dart';
import '../../services/auth_service.dart';
import '../../services/annee_service.dart';
import '../../services/statistique_generale_service.dart';
import 'inscriptions_detail_screen.dart';
import 'paiements_detail_screen.dart';
import 'pedagogique_detail_screen.dart';
import 'centre_decision_screen.dart';
import 'rapports_screen.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _teal = Color(0xFF0D9488);
const Color _ambre = Color(0xFFD97706);
const Color _vert = Color(0xFF16A34A);
const Color _rouge = Color(0xFFDC2626);
const Color _orange = Color(0xFFEA580C);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);
const Color _gris = Color(0xFF94A3B8);
const Color _fond = Color(0xFFEFF6FF);

String _formatMontant(num valeur) {
  final millions = valeur / 1000000;
  if (millions >= 1) {
    return '${millions.toStringAsFixed(1).replaceAll('.', ',')} M FCFA';
  }
  final milliers = valeur / 1000;
  return '${milliers.toStringAsFixed(0)} k FCFA';
}

// ══════════════════════════════════════════════════════════
// Point d'entrée unique du module Statistiques (même logique que
// notes_module_screen.dart / emploi_du_temps_module_screen.dart) : tableau
// de bord général, réservé au directeur/censeur, avec navigation vers les 5
// écrans détaillés déjà existants (inscriptions, paiements, résultats,
// centre de décision, rapports).
// ══════════════════════════════════════════════════════════
class StatistiquesModuleScreen extends StatefulWidget {
  const StatistiquesModuleScreen({super.key});

  @override
  State<StatistiquesModuleScreen> createState() => _StatistiquesModuleScreenState();
}

class _StatistiquesModuleScreenState extends State<StatistiquesModuleScreen> {
  Utilisateur? _utilisateur;
  bool _chargementUtilisateur = true;

  List<dynamic> _annees = [];
  int? _anneeId;
  List<dynamic> _periodes = [];
  int? _periodeId;

  DashboardGeneral? _dashboard;
  Map<String, dynamic>? _evolution;
  int _nombreAlertes = 0;

  bool _chargementDonnees = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _initialiser();
  }

  Future<void> _initialiser() async {
    final utilisateur = await AuthService.getUtilisateur();

    if (utilisateur == null) {
      if (mounted) setState(() => _chargementUtilisateur = false);
      return;
    }

    if (!(utilisateur.estDirecteur || utilisateur.estCenseur)) {
      if (mounted) Navigator.pushReplacementNamed(context, _routeDashboard(utilisateur));
      return;
    }

    if (mounted) {
      setState(() {
        _utilisateur = utilisateur;
        _chargementUtilisateur = false;
      });
    }
    await _resoudreAnneeEtPeriode();
  }

  Future<void> _resoudreAnneeEtPeriode() async {
    setState(() {
      _chargementDonnees = true;
      _erreur = null;
    });
    try {
      final annees = await AnneeService.listerAnnees();
      final data = await AnneeService.anneeActive();
      final anneeActive = data['annee'] as Map<String, dynamic>?;
      final periodeActive = data['periode_active'] as Map<String, dynamic>?;

      final anneeId = anneeActive?['id'] as int? ?? (annees.isNotEmpty ? annees.first['id'] as int : null);

      if (!mounted) return;
      setState(() {
        _annees = annees;
        _anneeId = anneeId;
      });

      if (anneeId != null) {
        final periodes = await AnneeService.listerPeriodes(anneeId);
        if (!mounted) return;
        setState(() {
          _periodes = periodes;
          _periodeId = periodeActive?['id'] as int? ?? (periodes.isNotEmpty ? periodes.first['id'] as int : null);
        });
      }

      await _chargerDonnees();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargementDonnees = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _changerAnnee(int? id) async {
    if (id == null || id == _anneeId) return;
    setState(() {
      _anneeId = id;
      _periodes = [];
      _periodeId = null;
      _dashboard = null;
    });
    try {
      final periodes = await AnneeService.listerPeriodes(id);
      if (!mounted) return;
      setState(() {
        _periodes = periodes;
        _periodeId = periodes.isNotEmpty ? periodes.first['id'] as int : null;
      });
    } catch (_) {
      // Le sélecteur de période reste simplement vide si le chargement échoue.
    }
    await _chargerDonnees();
  }

  void _changerPeriode(int? id) {
    setState(() => _periodeId = id);
    _chargerDonnees();
  }

  Future<void> _chargerDonnees() async {
    if (_anneeId == null) {
      setState(() => _chargementDonnees = false);
      return;
    }
    setState(() {
      _chargementDonnees = true;
      _erreur = null;
    });
    try {
      final anneeId = _anneeId!;
      final periodeId = _periodeId;

      final resultats = await Future.wait([
        StatistiqueGeneraleService.getDashboardGeneral(anneeScolaireId: anneeId, periodeId: periodeId),
        StatistiqueGeneraleService.getEvolutionEffectifs(),
        periodeId != null
            ? StatistiqueGeneraleService.getNombreAlertes(anneeScolaireId: anneeId, periodeId: periodeId)
            : Future.value(0),
      ]);

      if (!mounted) return;
      setState(() {
        _dashboard = resultats[0] as DashboardGeneral;
        _evolution = resultats[1] as Map<String, dynamic>;
        _nombreAlertes = resultats[2] as int;
        _chargementDonnees = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargementDonnees = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  // ── Navigation ────────────────────────────────────────

  String _routeDashboard(Utilisateur u) {
    switch (u.role) {
      case 'enseignant':
        return '/dashboard/enseignant';
      case 'censeur':
        return '/dashboard/censeur';
      case 'secretaire':
        return '/dashboard/secretaire';
      default: // directeur, super_admin
        return '/tableau-de-bord';
    }
  }

  void _retour() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else if (_utilisateur != null) {
      Navigator.pushReplacementNamed(context, _routeDashboard(_utilisateur!));
    } else {
      Navigator.pushReplacementNamed(context, '/tableau-de-bord');
    }
  }

  void _ouvrir(Widget ecran) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ecran));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fond,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _retour),
        title: Text('Statistiques', style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: Colors.white)),
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
      ),
      body: _chargementUtilisateur
          ? const Center(child: CircularProgressIndicator(color: _indigo))
          : _utilisateur == null
              ? _vueMessage('Impossible de charger votre profil. Reconnectez-vous.')
              : _corps(),
    );
  }

  Widget _corps() {
    return Stack(
      children: [
        Positioned(top: -80, right: -60, child: _blob(size: 260, couleur: _indigo.withValues(alpha: 0.08))),
        Positioned(bottom: -60, left: -60, child: _blob(size: 200, couleur: _teal.withValues(alpha: 0.10))),
        Positioned(top: 360, left: 140, child: _blob(size: 150, couleur: _ambre.withValues(alpha: 0.05))),
        SafeArea(
          child: RefreshIndicator(
            onRefresh: _chargerDonnees,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _selecteurs(),
                const SizedBox(height: 20),
                if (_anneeId == null)
                  _vueMessage("Aucune année scolaire disponible pour l'instant.")
                else if (_chargementDonnees && _dashboard == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 80),
                    child: Center(child: CircularProgressIndicator(color: _indigo)),
                  )
                else if (_erreur != null && _dashboard == null)
                  _carteErreur(_erreur!, _chargerDonnees)
                else if (_dashboard != null) ...[
                  _titreSection('Vue d\'ensemble'),
                  const SizedBox(height: 12),
                  _grilleCategories(_dashboard!),
                  const SizedBox(height: 28),
                  _titreSection('Graphiques'),
                  const SizedBox(height: 6),
                  Text(
                    "Aperçu visuel des effectifs, des finances et des résultats de l'année sélectionnée.",
                    style: GoogleFonts.inter(fontSize: 13, color: _texte),
                  ),
                  const SizedBox(height: 14),
                  _sectionGraphiques(_dashboard!),
                  const SizedBox(height: 28),
                  _titreSection('Modules détaillés'),
                  const SizedBox(height: 12),
                  _grilleNavigation(),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
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

  Widget _titreSection(String titre) {
    return Text(titre, style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: _texteFonce));
  }

  Widget _vueMessage(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, color: _gris, size: 40),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(message, textAlign: TextAlign.center, style: GoogleFonts.inter(color: _texte)),
            ),
          ],
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

  // ══════════════════════════════════════════════════════
  // SÉLECTEURS (ANNÉE / PÉRIODE)
  // ══════════════════════════════════════════════════════

  Widget _selecteurs() {
    return Row(
      children: [
        Expanded(
          child: _dropdownGlass<int>(
            label: 'Année scolaire',
            value: _anneeId,
            items: _annees
                .map((a) => DropdownMenuItem<int>(
                      value: a['id'] as int,
                      child: Text(a['libelle'] as String? ?? '—', overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: _changerAnnee,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _dropdownGlass<int>(
            label: 'Période',
            value: _periodeId,
            items: _periodes
                .map((p) => DropdownMenuItem<int>(
                      value: p['id'] as int,
                      child: Text(p['nom'] as String? ?? '—', overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: _periodes.isEmpty ? null : _changerPeriode,
          ),
        ),
      ],
    );
  }

  Widget _dropdownGlass<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
  }) {
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
          child: DropdownButtonFormField<T>(
            value: value,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: label,
              labelStyle: GoogleFonts.inter(fontSize: 12, color: _texte),
              isDense: true,
              border: InputBorder.none,
            ),
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _texteFonce),
            items: items,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // VUE D'ENSEMBLE — CARDS PAR CATÉGORIE
  // ══════════════════════════════════════════════════════

  Widget _grilleCategories(DashboardGeneral d) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final colonnes = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 560 ? 2 : 1);
        const espacement = 16.0;
        final largeur = colonnes == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - espacement * (colonnes - 1)) / colonnes;

        final cartes = <Widget>[
          _carteCategorie(
            icone: Icons.people_outline,
            titre: 'Élèves',
            couleur: _indigo,
            metriques: [
              ('Total', '${d.effectifs.totalEleves}'),
              ('Garçons', '${d.effectifs.garcons}'),
              ('Filles', '${d.effectifs.filles}'),
            ],
          ),
          _carteCategorie(
            icone: Icons.school_outlined,
            titre: 'Enseignants',
            couleur: _teal,
            metriques: [
              ('Total', '${d.enseignants.total}'),
              ('Permanents', '${d.enseignants.permanents}'),
              ('Vacataires', '${d.enseignants.vacataires}'),
            ],
          ),
          _carteCategorie(
            icone: Icons.class_outlined,
            titre: 'Classes',
            couleur: _ambre,
            metriques: [
              ('Total', '${d.classes.total}'),
              ('Moy. / classe', d.classes.moyenneElevesParClasse.toStringAsFixed(1)),
            ],
          ),
          _carteCategorie(
            icone: Icons.payments_outlined,
            titre: 'Financier',
            couleur: _vert,
            metriques: [
              ('Attendu', _formatMontant(d.financier.attendu)),
              ('Encaissé', _formatMontant(d.financier.encaisse)),
              ('Reste', _formatMontant(d.financier.reste)),
              ('Recouvrement', '${d.financier.tauxRecouvrement.toStringAsFixed(0)}%'),
            ],
          ),
          _carteCategorie(
            icone: Icons.grade_outlined,
            titre: 'Résultats',
            couleur: _rouge,
            metriques: [
              (
                'Moyenne générale',
                d.resultats.moyenneGenerale != null ? '${d.resultats.moyenneGenerale!.toStringAsFixed(1)}/20' : '—',
              ),
              ('Taux réussite', '${d.resultats.tauxReussite.toStringAsFixed(0)}%'),
            ],
          ),
        ];

        return Wrap(
          spacing: espacement,
          runSpacing: espacement,
          children: cartes.map((c) => SizedBox(width: largeur, child: c)).toList(),
        );
      },
    );
  }

  Widget _carteCategorie({
    required IconData icone,
    required String titre,
    required Color couleur,
    required List<(String, String)> metriques,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
            boxShadow: [
              BoxShadow(color: _texteFonce.withValues(alpha: 0.06), blurRadius: 32, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: couleur.withValues(alpha: 0.14), shape: BoxShape.circle),
                    child: Icon(icone, color: couleur, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(titre, style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: _texteFonce)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 20,
                runSpacing: 10,
                children: metriques
                    .map((m) => SizedBox(
                          width: 86,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.$2,
                                style: GoogleFonts.jetBrainsMono(fontSize: 17, fontWeight: FontWeight.w700, color: couleur),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                m.$1,
                                style: GoogleFonts.inter(fontSize: 11, color: _texte),
                                maxLines: 2,
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // GRAPHIQUES
  // ══════════════════════════════════════════════════════

  Widget _sectionGraphiques(DashboardGeneral d) {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final large = constraints.maxWidth > 900;
            final repartitionSexe = _graphiqueRepartitionSexe(d);
            final evolution = _graphiqueEvolution();
            if (large) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: evolution),
                  const SizedBox(width: 16),
                  Expanded(child: repartitionSexe),
                ],
              );
            }
            return Column(children: [repartitionSexe, const SizedBox(height: 16), evolution]);
          },
        ),
        const SizedBox(height: 20),
        Text(
          'Le graphique ci-dessous compare la situation financière globale de l\'année.',
          style: GoogleFonts.inter(fontSize: 13, color: _texte),
        ),
        const SizedBox(height: 12),
        _graphiqueFinancier(d),
        const SizedBox(height: 20),
        _graphiqueRepartitionMoyennes(d),
      ],
    );
  }

  Widget _carteGraphique({
    required String titre,
    String? sousTitre,
    required Widget enfant,
    List<Widget>? legende,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
            boxShadow: [
              BoxShadow(color: _texteFonce.withValues(alpha: 0.06), blurRadius: 32, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titre, style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: _texteFonce)),
              if (sousTitre != null) ...[
                const SizedBox(height: 4),
                Text(sousTitre, style: GoogleFonts.inter(fontSize: 11, color: _texte)),
              ],
              const SizedBox(height: 14),
              enfant,
              if (legende != null) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 14, runSpacing: 6, alignment: WrapAlignment.center, children: legende),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _legende(Color couleur, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: couleur, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: _texte)),
      ],
    );
  }

  Widget _etatVide(String message) {
    return SizedBox(
      height: 140,
      child: Center(child: Text(message, style: GoogleFonts.inter(fontSize: 12, color: _texte))),
    );
  }

  // ── Camembert garçons / filles ──────────────────────────

  Widget _graphiqueRepartitionSexe(DashboardGeneral d) {
    final garcons = d.effectifs.garcons;
    final filles = d.effectifs.filles;
    final total = garcons + filles;
    final pctGarcons = total > 0 ? (garcons / total * 100) : 0;

    return _carteGraphique(
      titre: 'Répartition garçons / filles',
      sousTitre: total > 0
          ? 'Sur $total élève(s) inscrit(s), ${pctGarcons.toStringAsFixed(0)}% sont des garçons.'
          : "Aucun élève inscrit pour l'année sélectionnée.",
      enfant: total == 0
          ? _etatVide('Aucune donnée')
          : SizedBox(
              height: 170,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 0,
                      centerSpaceRadius: 42,
                      sections: [
                        PieChartSectionData(value: garcons.toDouble(), color: _indigo, showTitle: false, radius: 24),
                        PieChartSectionData(value: filles.toDouble(), color: _teal, showTitle: false, radius: 24),
                      ],
                    ),
                  ),
                  Text('$total', style: GoogleFonts.jetBrainsMono(fontSize: 20, fontWeight: FontWeight.w700, color: _texteFonce)),
                ],
              ),
            ),
      legende: [
        _legende(_indigo, 'Garçons $garcons'),
        _legende(_teal, 'Filles $filles'),
      ],
    );
  }

  // ── Courbe évolution des effectifs ──────────────────────

  Widget _graphiqueEvolution() {
    final labels = (_evolution?['labels'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
    final valeurs = (_evolution?['valeurs'] as List?)?.map((v) => (v as num).toDouble()).toList() ?? const <double>[];
    final maxValeur = valeurs.isEmpty ? 0.0 : valeurs.reduce((a, b) => a > b ? a : b);
    final maxY = maxValeur <= 0 ? 10.0 : maxValeur * 1.2;

    return _carteGraphique(
      titre: 'Évolution des effectifs',
      sousTitre: labels.length > 1
          ? "Total des élèves inscrits sur les ${labels.length} dernières années scolaires."
          : 'Historique limité pour le moment.',
      enfant: valeurs.isEmpty
          ? _etatVide('Aucune donnée')
          : SizedBox(
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
                          if (i < 0 || i >= labels.length) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(labels[i], style: GoogleFonts.inter(fontSize: 10, color: _texte)),
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
                      spots: [for (var i = 0; i < valeurs.length; i++) FlSpot(i.toDouble(), valeurs[i])],
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
    );
  }

  // ── Barres attendu / encaissé / restant ─────────────────

  Widget _graphiqueFinancier(DashboardGeneral d) {
    final valeurs = [d.financier.attendu, d.financier.encaisse, d.financier.reste];
    const labels = ['Attendu', 'Encaissé', 'Restant'];
    const couleurs = [_indigo, _vert, _rouge];
    final maxValeur = valeurs.reduce((a, b) => a > b ? a : b);
    final maxY = maxValeur <= 0 ? 100.0 : maxValeur * 1.25;

    return _carteGraphique(
      titre: 'Attendu / Encaissé / Restant',
      sousTitre: 'Taux de recouvrement actuel : ${d.financier.tauxRecouvrement.toStringAsFixed(0)}%.',
      enfant: SizedBox(
        height: 200,
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
                getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                  _formatMontant(rod.toY),
                  GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _texte),
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < valeurs.length; i++)
                BarChartGroupData(
                  x: i,
                  showingTooltipIndicators: const [0],
                  barRods: [
                    BarChartRodData(toY: valeurs[i], width: 34, borderRadius: BorderRadius.circular(6), color: couleurs[i]),
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
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= labels.length) return const SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(labels[i], style: GoogleFonts.inter(fontSize: 11, color: _texte)),
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

  // ── Camembert répartition par tranche de moyenne ────────

  Widget _graphiqueRepartitionMoyennes(DashboardGeneral d) {
    final repartition = d.resultats.repartitionMoyennes;
    final total = repartition?.values.fold<int>(0, (a, b) => a + b) ?? 0;

    final titreStyle = GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white);

    return _carteGraphique(
      titre: 'Répartition par tranche de moyenne',
      sousTitre: repartition != null && total > 0
          ? 'Répartition des élèves selon leur moyenne générale de la période.'
          : "Répartition non disponible pour l'instant — nécessite une évolution de l'API.",
      enfant: repartition == null || total == 0
          ? _etatVide('Données non disponibles')
          : SizedBox(
              height: 190,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 38,
                  sections: [
                    PieChartSectionData(value: (repartition['<10'] ?? 0).toDouble(), color: _rouge, title: '<10', radius: 24, titleStyle: titreStyle),
                    PieChartSectionData(value: (repartition['10-12'] ?? 0).toDouble(), color: _orange, title: '10-12', radius: 24, titleStyle: titreStyle),
                    PieChartSectionData(value: (repartition['12-14'] ?? 0).toDouble(), color: _ambre, title: '12-14', radius: 24, titleStyle: titreStyle),
                    PieChartSectionData(value: (repartition['14-16'] ?? 0).toDouble(), color: _teal, title: '14-16', radius: 24, titleStyle: titreStyle),
                    PieChartSectionData(value: (repartition['>16'] ?? 0).toDouble(), color: _vert, title: '>16', radius: 24, titleStyle: titreStyle),
                  ],
                ),
              ),
            ),
      legende: [
        _legende(_rouge, '< 10'),
        _legende(_orange, '10-12'),
        _legende(_ambre, '12-14'),
        _legende(_teal, '14-16'),
        _legende(_vert, '> 16'),
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  // NAVIGATION VERS LES MODULES DÉTAILLÉS
  // ══════════════════════════════════════════════════════

  Widget _grilleNavigation() {
    final items = <_NavItem>[
      _NavItem(
        'Inscriptions détaillées',
        Icons.groups_outlined,
        _indigo,
        onTap: () => _ouvrir(InscriptionsDetailScreen(anneeScolaireId: _anneeId)),
      ),
      _NavItem(
        'Paiements détaillés',
        Icons.payments_outlined,
        _vert,
        onTap: () => _ouvrir(PaiementsDetailScreen(anneeScolaireId: _anneeId)),
      ),
      _NavItem(
        'Résultats pédagogiques',
        Icons.grade_outlined,
        _teal,
        onTap: () => _ouvrir(PedagogiqueDetailScreen(periodeId: _periodeId)),
      ),
      _NavItem(
        'Centre de Décision',
        Icons.notifications_active_outlined,
        _rouge,
        badge: _nombreAlertes > 0 ? '$_nombreAlertes' : null,
        onTap: () => _ouvrir(CentreDecisionScreen(anneeScolaireId: _anneeId, periodeId: _periodeId)),
      ),
      _NavItem(
        'Rapports',
        Icons.picture_as_pdf_outlined,
        _ambre,
        onTap: () => _ouvrir(const RapportsScreen()),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final colonnes = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 560 ? 2 : 1);
        const espacement = 12.0;
        final largeur = colonnes == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - espacement * (colonnes - 1)) / colonnes;

        return Wrap(
          spacing: espacement,
          runSpacing: espacement,
          children: items.map((i) => SizedBox(width: largeur, child: _carteNavigation(i))).toList(),
        );
      },
    );
  }

  Widget _carteNavigation(_NavItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: item.onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
                boxShadow: [
                  BoxShadow(color: _texteFonce.withValues(alpha: 0.06), blurRadius: 24, offset: const Offset(0, 6)),
                ],
              ),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: item.couleur.withValues(alpha: 0.14), shape: BoxShape.circle),
                        child: Icon(item.icone, color: item.couleur, size: 20),
                      ),
                      if (item.badge != null)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: _rouge, borderRadius: BorderRadius.circular(999)),
                            child: Text(
                              item.badge!,
                              style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.titre,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _texteFonce),
                      maxLines: 2,
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: _gris, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String titre;
  final IconData icone;
  final Color couleur;
  final String? badge;
  final VoidCallback onTap;

  const _NavItem(this.titre, this.icone, this.couleur, {this.badge, required this.onTap});
}
