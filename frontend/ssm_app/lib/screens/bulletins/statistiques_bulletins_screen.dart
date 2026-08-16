import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/historique_statistique_bulletin_model.dart';
import '../../services/annee_service.dart';
import '../../services/classe_service.dart';
import '../../services/historique_statistique_bulletin_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_panel.dart';
import '../../widgets/ssm/ssm_quick_action_button.dart';
import '../../widgets/ssm/ssm_sous_entete.dart';
import '../../widgets/ssm/ssm_stat_card.dart';

// Teinte dérivée de SSMPalette.teal pour distinguer la meilleure tranche de
// moyennes (16-20) de la tranche 14-16 — même principe que le rouge foncé
// de SSMStatutFinancierBadge (état supplémentaire dérivé de la palette de
// base plutôt qu'une couleur totalement nouvelle).
const Color _tealFonce = Color(0xFF0F766E);

Color _couleurTranche(String tranche) {
  switch (tranche) {
    case '< 10':
      return SSMPalette.rouge;
    case '10-12':
      return SSMPalette.ambre;
    case '12-14':
      return Colors.orange;
    case '14-16':
      return SSMPalette.teal;
    default: // '16-20'
      return _tealFonce;
  }
}

class StatistiquesBulletinsScreen extends StatefulWidget {
  final int anneeScolaireId;
  final int? classeIdInitiale;
  final int? periodeIdInitiale;

  const StatistiquesBulletinsScreen({
    super.key,
    required this.anneeScolaireId,
    this.classeIdInitiale,
    this.periodeIdInitiale,
  });

  @override
  State<StatistiquesBulletinsScreen> createState() => _StatistiquesBulletinsScreenState();
}

class _StatistiquesBulletinsScreenState extends State<StatistiquesBulletinsScreen> {
  List<dynamic> _classes = [];
  List<dynamic> _periodes = [];
  int? _classeId;
  int? _periodeId;
  bool _chargementListes = true;

  StatistiqueClasseBulletin? _statistique;
  List<DistributionMoyenne> _distribution = [];
  bool _chargementStats = false;
  String? _erreur;

  // Comparaison entre périodes
  int? _periodeComparaison1;
  int? _periodeComparaison2;
  ComparaisonPeriodesBulletin? _comparaison;
  bool _chargementComparaison = false;
  String? _erreurComparaison;

  @override
  void initState() {
    super.initState();
    _classeId = widget.classeIdInitiale;
    _periodeId = widget.periodeIdInitiale;
    _charger();
  }

  Future<void> _charger() async {
    try {
      final resultats = await Future.wait([
        ClasseService.lister(anneeId: widget.anneeScolaireId),
        AnneeService.listerPeriodes(widget.anneeScolaireId),
      ]);
      if (!mounted) return;
      setState(() {
        _classes = _aplatirClasses(resultats[0]);
        _periodes = resultats[1] as List<dynamic>;
        _chargementListes = false;
      });
      if (_classeId != null && _periodeId != null) _chargerStatistiques();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargementListes = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  List<dynamic> _aplatirClasses(dynamic valeur) {
    final toutes = <dynamic>[];
    void parcourir(dynamic v) {
      if (v is List) {
        toutes.addAll(v);
      } else if (v is Map) {
        for (final sous in v.values) {
          parcourir(sous);
        }
      }
    }

    parcourir(valeur);
    return toutes;
  }

  void _changerClasse(int? classeId) {
    setState(() {
      _classeId = classeId;
      _statistique = null;
      _distribution = [];
      _comparaison = null;
    });
    if (classeId != null && _periodeId != null) _chargerStatistiques();
  }

  void _changerPeriode(int? periodeId) {
    setState(() {
      _periodeId = periodeId;
      _statistique = null;
      _distribution = [];
    });
    if (periodeId != null && _classeId != null) _chargerStatistiques();
  }

  Future<void> _chargerStatistiques() async {
    setState(() {
      _chargementStats = true;
      _erreur = null;
    });
    try {
      final resultats = await Future.wait([
        HistoriqueStatistiqueBulletinService.getStatistiqueClasse(classeId: _classeId!, periodeId: _periodeId!),
        HistoriqueStatistiqueBulletinService.getDistributionMoyennes(classeId: _classeId!, periodeId: _periodeId!),
      ]);
      if (!mounted) return;
      setState(() {
        _statistique = resultats[0] as StatistiqueClasseBulletin;
        _distribution = resultats[1] as List<DistributionMoyenne>;
        _chargementStats = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargementStats = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _comparer() async {
    if (_classeId == null || _periodeComparaison1 == null || _periodeComparaison2 == null) {
      setState(() => _erreurComparaison = 'Sélectionnez deux périodes à comparer.');
      return;
    }
    if (_periodeComparaison1 == _periodeComparaison2) {
      setState(() => _erreurComparaison = 'Choisissez deux périodes différentes.');
      return;
    }

    setState(() {
      _chargementComparaison = true;
      _erreurComparaison = null;
      _comparaison = null;
    });
    try {
      final comparaison = await HistoriqueStatistiqueBulletinService.getComparaisonPeriodes(
        classeId: _classeId!,
        periodeId1: _periodeComparaison1!,
        periodeId2: _periodeComparaison2!,
      );
      if (!mounted) return;
      setState(() {
        _comparaison = comparaison;
        _chargementComparaison = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargementComparaison = false;
        _erreurComparaison = e.toString().replaceAll('Exception: ', '');
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
            SSMSousEnTete(titre: 'Statistiques des bulletins', onRetour: () => Navigator.pop(context)),
            Expanded(
              child: _chargementListes
                  ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _carteSelecteurs(),
                        const SizedBox(height: 16),
                        if (_chargementStats)
                          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: SSMPalette.indigo)))
                        else if (_erreur != null)
                          Center(child: Text(_erreur!, style: GoogleFonts.inter(color: SSMPalette.rouge)))
                        else if (_statistique != null) ...[
                          _grilleResume(_statistique!),
                          const SizedBox(height: 20),
                          _carteDistribution(),
                        ] else
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text('Sélectionnez une classe et une période.', style: GoogleFonts.inter(color: SSMPalette.texte3)),
                            ),
                          ),
                        const SizedBox(height: 24),
                        _carteComparaison(),
                        const SizedBox(height: 24),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _carteSelecteurs() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SSMPalette.blanc,
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        border: Border.all(color: SSMPalette.bordure),
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              value: _classeId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Classe', isDense: true),
              items: _classes.map((c) => DropdownMenuItem<int>(value: c['id'] as int, child: Text(c['nom'] as String))).toList(),
              onChanged: _changerClasse,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<int>(
              value: _periodeId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Période', isDense: true),
              items: _periodes.map((p) => DropdownMenuItem<int>(value: p['id'] as int, child: Text(p['nom'] as String))).toList(),
              onChanged: _changerPeriode,
            ),
          ),
        ],
      ),
    );
  }

  Widget _grilleResume(StatistiqueClasseBulletin s) {
    final cartes = <Widget>[
      SSMStatCard(icone: Icons.groups_outlined, couleur: SSMPalette.indigo, valeur: '${s.effectif}', label: 'Effectif'),
      SSMStatCard(
        icone: Icons.functions,
        couleur: SSMPalette.teal,
        valeur: s.moyenneClasse != null ? '${s.moyenneClasse!.toStringAsFixed(2)}/20' : '—',
        label: 'Moyenne de classe',
      ),
      SSMStatCard(
        icone: Icons.trending_up,
        couleur: _tealFonce,
        valeur: s.meilleureMoyenne != null ? '${s.meilleureMoyenne!.toStringAsFixed(2)}/20' : '—',
        label: 'Meilleure moyenne',
      ),
      SSMStatCard(
        icone: Icons.trending_down,
        couleur: SSMPalette.rouge,
        valeur: s.plusFaibleMoyenne != null ? '${s.plusFaibleMoyenne!.toStringAsFixed(2)}/20' : '—',
        label: 'Plus faible moyenne',
      ),
      SSMStatCard(icone: Icons.check_circle_outline, couleur: SSMPalette.teal, valeur: '${s.nombreAuDessusDe10}', label: 'Moyenne ≥ 10'),
      SSMStatCard(icone: Icons.cancel_outlined, couleur: SSMPalette.rouge, valeur: '${s.nombreEnDessousDe10}', label: 'Moyenne < 10'),
      SSMStatCard(icone: Icons.emoji_events_outlined, couleur: SSMPalette.ambre, valeur: '${s.tauxReussite.toStringAsFixed(1)}%', label: 'Taux de réussite'),
    ];

    return LayoutBuilder(builder: (context, contraintes) {
      final colonnes = contraintes.maxWidth >= 900 ? 3 : (contraintes.maxWidth >= 560 ? 2 : 1);
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

  Widget _carteDistribution() {
    if (_distribution.isEmpty) {
      return Center(child: Text('Aucune donnée de distribution.', style: GoogleFonts.inter(color: SSMPalette.texte3)));
    }
    final maxY = (_distribution.map((d) => d.nombre).fold<int>(0, (a, b) => a > b ? a : b)) * 1.3;

    return SSMPanel(
      titre: 'Distribution des moyennes',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY <= 0 ? 5 : maxY,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => SSMPalette.indigo,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                      '${rod.toY.toInt()} élève(s)',
                      const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < _distribution.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: _distribution[i].nombre.toDouble(),
                          width: 28,
                          borderRadius: BorderRadius.circular(4),
                          color: _couleurTranche(_distribution[i].tranche),
                        ),
                      ],
                    ),
                ],
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) => FlLine(color: SSMPalette.texte1.withValues(alpha: 0.04), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) => Text('${value.toInt()}', style: GoogleFonts.inter(fontSize: 9, color: SSMPalette.texte3)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= _distribution.length) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(_distribution[i].tranche, style: GoogleFonts.inter(fontSize: 9, color: SSMPalette.texte2)),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: _distribution.map((d) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: _couleurTranche(d.tranche), shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text('${d.tranche} (${d.nombre})', style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte2)),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Comparaison entre périodes ─────────────────────────────

  Widget _carteComparaison() {
    return SSMPanel(
      titre: 'Comparaison entre périodes',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nécessite une classe sélectionnée ci-dessus.', style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte3)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _periodeComparaison1,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Période 1', isDense: true),
                  items: _periodes.map((p) => DropdownMenuItem<int>(value: p['id'] as int, child: Text(p['nom'] as String))).toList(),
                  onChanged: (v) => setState(() => _periodeComparaison1 = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _periodeComparaison2,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Période 2', isDense: true),
                  items: _periodes.map((p) => DropdownMenuItem<int>(value: p['id'] as int, child: Text(p['nom'] as String))).toList(),
                  onChanged: (v) => setState(() => _periodeComparaison2 = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: _chargementComparaison
                ? const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: SSMPalette.indigo)))
                : SSMQuickActionButton(
                    icone: Icons.compare_arrows,
                    label: 'Comparer',
                    variante: SSMActionVariante.primaire,
                    onTap: _classeId == null ? null : _comparer,
                  ),
          ),
          if (_erreurComparaison != null) ...[
            const SizedBox(height: 8),
            Text(_erreurComparaison!, style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.rouge)),
          ],
          if (_comparaison != null) ...[
            const SizedBox(height: 14),
            _resultatComparaison(_comparaison!),
          ],
        ],
      ),
    );
  }

  Widget _resultatComparaison(ComparaisonPeriodesBulletin c) {
    final evolution = c.evolutionMoyenneClasse;
    final couleur = switch (c.progression) {
      'hausse' => SSMPalette.teal,
      'baisse' => SSMPalette.rouge,
      _ => SSMPalette.texte3,
    };
    final icone = switch (c.progression) {
      'hausse' => Icons.arrow_upward,
      'baisse' => Icons.arrow_downward,
      _ => Icons.remove,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: couleur.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(SSMRayons.grand)),
      child: Row(
        children: [
          Icon(icone, color: couleur),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${c.periode1.moyenneClasse?.toStringAsFixed(2) ?? '—'}/20  →  ${c.periode2.moyenneClasse?.toStringAsFixed(2) ?? '—'}/20',
                  style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w700, color: SSMPalette.texte1),
                ),
                const SizedBox(height: 2),
                Text(
                  evolution != null
                      ? '${evolution >= 0 ? '+' : ''}${evolution.toStringAsFixed(2)} point(s) — ${_libelleProgression(c.progression)}'
                      : 'Évolution indisponible',
                  style: GoogleFonts.inter(fontSize: 12, color: couleur, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _libelleProgression(String? progression) {
    switch (progression) {
      case 'hausse':
        return 'en hausse';
      case 'baisse':
        return 'en baisse';
      case 'stable':
        return 'stable';
      default:
        return '—';
    }
  }
}
