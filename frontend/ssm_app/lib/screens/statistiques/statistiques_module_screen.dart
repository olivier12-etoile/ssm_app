import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/utilisateur.dart';
import '../../models/statistique_generale_model.dart';
import '../../services/auth_service.dart';
import '../../services/annee_service.dart';
import '../../services/parametre_ecole_service.dart';
import '../../services/statistique_generale_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_page_scaffold.dart';
import '../../widgets/ssm/ssm_panel.dart';
import '../../widgets/ssm/ssm_quick_action_button.dart';
import '../../widgets/ssm/ssm_sidebar.dart';
import '../../widgets/ssm/ssm_stat_card.dart';
import 'inscriptions_detail_screen.dart';
import 'paiements_detail_screen.dart';
import 'pedagogique_detail_screen.dart';
import 'centre_decision_screen.dart';
import 'rapports_screen.dart';

// Tons supplémentaires pour le camembert à 5 tranches (répartition des
// moyennes) : dégradé rouge → indigo dans la même famille que la palette,
// même principe que le rouge foncé de SSMStatutFinancierBadge (4ᵉ état
// dérivé de la palette de base plutôt qu'une couleur totalement nouvelle).
const Color _ambreClair2 = Color(0xFFFBBF24);

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
  String _nomEcole = 'Mon établissement';
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

    unawaited(_chargerNomEcole());

    if (mounted) {
      setState(() {
        _utilisateur = utilisateur;
        _chargementUtilisateur = false;
      });
    }
    await _resoudreAnneeEtPeriode();
  }

  Future<void> _chargerNomEcole() async {
    try {
      final infos = await ParametreEcoleService.getInformationsEtablissement();
      final nom = infos.nomCourt ?? infos.nomOfficiel;
      if (mounted && nom != null) setState(() => _nomEcole = nom);
    } catch (_) {
      // Le nom générique de repli reste affiché si le chargement échoue.
    }
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

  void _naviguer(String route) {
    if (route == '/statistiques') return;
    Navigator.pushNamed(context, route);
  }

  void _ouvrir(Widget ecran) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ecran));
  }

  String _libelleRole(String? role) {
    switch (role) {
      case 'directeur':
        return 'Directeur';
      case 'censeur':
        return 'Censeur';
      default:
        return role ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_chargementUtilisateur) {
      return const Scaffold(
        backgroundColor: SSMPalette.fond,
        body: Center(child: CircularProgressIndicator(color: SSMPalette.indigo)),
      );
    }
    if (_utilisateur == null) {
      return Scaffold(
        backgroundColor: SSMPalette.fond,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Impossible de charger votre profil. Reconnectez-vous.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: SSMPalette.texte2),
            ),
          ),
        ),
      );
    }

    return SSMPageScaffold(
      nomEcole: _nomEcole,
      codeEcole: _utilisateur!.codeEcole,
      nomUtilisateur: _utilisateur!.nom,
      role: _libelleRole(_utilisateur!.role),
      sections: _sections(),
      routeActuelle: '/statistiques',
      onNavigate: _naviguer,
      onProfilTap: () => Navigator.pushNamed(context, '/profil'),
      breadcrumb: 'Accueil',
      breadcrumbActuel: 'Statistiques',
      actionsTopBar: [
        _pillSelecteur<int>(
          icone: Icons.calendar_today_outlined,
          valeur: _anneeId,
          items: _annees.map((a) => (a['id'] as int, a['libelle'] as String? ?? '—')).toList(),
          onChanged: _changerAnnee,
        ),
        const SizedBox(width: 8),
        _pillSelecteur<int>(
          icone: Icons.event_outlined,
          valeur: _periodeId,
          items: _periodes.map((p) => (p['id'] as int, p['nom'] as String? ?? '—')).toList(),
          onChanged: _periodes.isEmpty ? null : _changerPeriode,
        ),
      ],
      child: RefreshIndicator(
        onRefresh: _chargerDonnees,
        color: SSMPalette.indigo,
        child: _anneeId == null
            ? _etatMessage("Aucune année scolaire disponible pour l'instant.")
            : _chargementDonnees && _dashboard == null
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 100),
                    child: Center(child: CircularProgressIndicator(color: SSMPalette.indigo)),
                  )
                : _erreur != null && _dashboard == null
                    ? _carteErreur(_erreur!, _chargerDonnees)
                    : _dashboard != null
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _titreSection("Vue d'ensemble"),
                                const SizedBox(height: 12),
                                _grilleCategories(_dashboard!),
                                const SizedBox(height: 24),
                                _titreSection('Graphiques'),
                                const SizedBox(height: 4),
                                Text(
                                  "Aperçu visuel des effectifs, des finances et des résultats de l'année sélectionnée.",
                                  style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2),
                                ),
                                const SizedBox(height: 12),
                                _sectionGraphiques(_dashboard!),
                                const SizedBox(height: 24),
                                _titreSection('Modules détaillés'),
                                const SizedBox(height: 12),
                                _grilleNavigation(),
                              ],
                            ),
                          )
                        : const SizedBox(),
      ),
    );
  }

  // ── Barre latérale ──────────────────────────────────────

  List<SSMNavSection> _sections() {
    return [
      SSMNavSection(titre: 'Principal', items: const [
        SSMNavItem(icone: Icons.dashboard_outlined, label: 'Tableau de bord', route: '/tableau-de-bord'),
        SSMNavItem(icone: Icons.people_outline, label: 'Élèves', route: '/directeur/eleves'),
        SSMNavItem(icone: Icons.grade_outlined, label: 'Notes & évaluations', route: '/notes'),
        SSMNavItem(icone: Icons.price_change_outlined, label: 'Frais scolaires', route: '/directeur/frais'),
        SSMNavItem(icone: Icons.calendar_view_week_outlined, label: 'Emploi du temps', route: '/emploi-du-temps'),
        SSMNavItem(icone: Icons.description_outlined, label: 'Bulletins PDF', route: '/bulletins'),
      ]),
      SSMNavSection(titre: 'Pilotage', items: [
        const SSMNavItem(icone: Icons.bar_chart_outlined, label: 'Statistiques', route: '/statistiques'),
        SSMNavItem(
          icone: Icons.notifications_outlined,
          label: 'Notifications',
          route: '/notifications',
          badge: _nombreAlertes > 0 ? _nombreAlertes : null,
        ),
        const SSMNavItem(icone: Icons.settings_outlined, label: 'Paramètres école', route: '/parametres'),
      ]),
      if (_utilisateur?.role == 'directeur')
        const SSMNavSection(titre: 'Administration', items: [
          SSMNavItem(icone: Icons.people_alt_outlined, label: 'Utilisateurs', route: '/directeur/utilisateurs'),
          SSMNavItem(icone: Icons.class_outlined, label: 'Classes', route: '/directeur/classes'),
          SSMNavItem(icone: Icons.menu_book_outlined, label: 'Matières', route: '/directeur/matieres'),
          SSMNavItem(icone: Icons.calendar_month_outlined, label: 'Années & Périodes', route: '/directeur/annees'),
        ]),
    ];
  }

  // ── Sélecteur compact pour la topbar (année / période) ──

  Widget _pillSelecteur<T>({
    required IconData icone,
    required T? valeur,
    required List<(T, String)> items,
    required ValueChanged<T?>? onChanged,
  }) {
    final correspondances = items.where((i) => i.$1 == valeur);
    final libelleActuel = correspondances.isEmpty ? '—' : correspondances.first.$2;

    return PopupMenuButton<T>(
      enabled: onChanged != null && items.isNotEmpty,
      tooltip: '',
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final item in items) PopupMenuItem<T>(value: item.$1, child: Text(item.$2)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: SSMPalette.indigoClair,
          borderRadius: BorderRadius.circular(SSMRayons.petit),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 12, color: SSMPalette.indigo),
            const SizedBox(width: 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 100),
              child: Text(
                libelleActuel,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: SSMPalette.indigo),
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.expand_more, size: 13, color: SSMPalette.indigo),
          ],
        ),
      ),
    );
  }

  Widget _titreSection(String titre) {
    return Text(titre, style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.texte1));
  }

  Widget _etatMessage(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, color: SSMPalette.texte3, size: 36),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(message, textAlign: TextAlign.center, style: GoogleFonts.inter(color: SSMPalette.texte2)),
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
          const Icon(Icons.error_outline, color: SSMPalette.rouge, size: 32),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center, style: GoogleFonts.inter(color: SSMPalette.texte2)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onReessayer, child: const Text('Réessayer')),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // VUE D'ENSEMBLE — GRILLE DE SSMStatCard
  // ══════════════════════════════════════════════════════

  Widget _grilleCategories(DashboardGeneral d) {
    final tauxRecouvrement = d.financier.tauxRecouvrement;
    final moyenne = d.resultats.moyenneGenerale;

    final cartes = <Widget>[
      SSMStatCard(
        icone: Icons.people_outline,
        couleur: SSMPalette.indigo,
        valeur: '${d.effectifs.totalEleves}',
        label: 'Élèves inscrits',
        sousTexte: '${d.effectifs.garcons} garçons · ${d.effectifs.filles} filles',
      ),
      SSMStatCard(
        icone: Icons.school_outlined,
        couleur: SSMPalette.teal,
        valeur: '${d.enseignants.total}',
        label: 'Enseignants',
        sousTexte: '${d.enseignants.permanents} permanents · ${d.enseignants.vacataires} vacataires',
      ),
      SSMStatCard(
        icone: Icons.class_outlined,
        couleur: SSMPalette.ambre,
        valeur: '${d.classes.total}',
        label: 'Classes',
        sousTexte: 'Moy. ${d.classes.moyenneElevesParClasse.toStringAsFixed(1)} élèves / classe',
      ),
      SSMStatCard(
        icone: Icons.payments_outlined,
        couleur: SSMPalette.teal,
        valeur: '${tauxRecouvrement.toStringAsFixed(0)}%',
        label: 'Taux de recouvrement',
        sousTexte: '${_formatMontant(d.financier.encaisse)} / ${_formatMontant(d.financier.attendu)}',
        tendance: tauxRecouvrement >= 70
            ? SSMTendance.hausse
            : tauxRecouvrement < 50
                ? SSMTendance.baisse
                : SSMTendance.neutre,
      ),
      SSMStatCard(
        icone: Icons.grade_outlined,
        couleur: (moyenne ?? 0) >= 10 ? SSMPalette.teal : SSMPalette.rouge,
        valeur: moyenne != null ? '${moyenne.toStringAsFixed(1)}/20' : '—',
        label: 'Moyenne générale',
        sousTexte: 'Taux de réussite ${d.resultats.tauxReussite.toStringAsFixed(0)}%',
      ),
    ];

    return LayoutBuilder(builder: (context, contraintes) {
      final colonnes = contraintes.maxWidth >= 1100 ? 5 : (contraintes.maxWidth >= 760 ? 3 : (contraintes.maxWidth >= 480 ? 2 : 1));
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
  // GRAPHIQUES
  // ══════════════════════════════════════════════════════

  Widget _sectionGraphiques(DashboardGeneral d) {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final large = constraints.maxWidth > 900;
            final evolution = _graphiqueEvolution();
            final repartitionSexe = _graphiqueRepartitionSexe(d);
            if (large) {
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 2, child: evolution),
                    const SizedBox(width: 16),
                    Expanded(child: repartitionSexe),
                  ],
                ),
              );
            }
            return Column(children: [evolution, const SizedBox(height: 16), repartitionSexe]);
          },
        ),
        const SizedBox(height: 16),
        _graphiqueFinancier(d),
        const SizedBox(height: 16),
        _graphiqueRepartitionMoyennes(d),
      ],
    );
  }

  Widget _legende(Color couleur, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: couleur, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
      ],
    );
  }

  Widget _etatVide(String message) {
    return SizedBox(
      height: 140,
      child: Center(child: Text(message, style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2))),
    );
  }

  // ── Camembert garçons / filles ──────────────────────────

  Widget _graphiqueRepartitionSexe(DashboardGeneral d) {
    final garcons = d.effectifs.garcons;
    final filles = d.effectifs.filles;
    final total = garcons + filles;

    return SSMPanel(
      titre: 'Répartition garçons / filles',
      child: total == 0
          ? _etatVide('Aucune donnée')
          : Column(
              children: [
                SizedBox(
                  height: 170,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 0,
                          centerSpaceRadius: 42,
                          sections: [
                            PieChartSectionData(value: garcons.toDouble(), color: SSMPalette.indigo, showTitle: false, radius: 24),
                            PieChartSectionData(value: filles.toDouble(), color: SSMPalette.teal, showTitle: false, radius: 24),
                          ],
                        ),
                      ),
                      Text('$total', style: GoogleFonts.jetBrainsMono(fontSize: 20, fontWeight: FontWeight.w700, color: SSMPalette.texte1)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(spacing: 14, runSpacing: 6, alignment: WrapAlignment.center, children: [
                  _legende(SSMPalette.indigo, 'Garçons $garcons'),
                  _legende(SSMPalette.teal, 'Filles $filles'),
                ]),
              ],
            ),
    );
  }

  // ── Courbe évolution des effectifs ──────────────────────

  Widget _graphiqueEvolution() {
    final labels = (_evolution?['labels'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
    final valeurs = (_evolution?['valeurs'] as List?)?.map((v) => (v as num?)?.toDouble() ?? 0.0).toList() ?? const <double>[];
    final maxValeur = valeurs.isEmpty ? 0.0 : valeurs.reduce((a, b) => a > b ? a : b);
    final maxY = maxValeur <= 0 ? 10.0 : maxValeur * 1.2;

    return SSMPanel(
      titre: 'Évolution des effectifs',
      child: valeurs.isEmpty
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
                    getDrawingHorizontalLine: (v) => FlLine(color: SSMPalette.bordure, strokeWidth: 1),
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
                            child: Text(labels[i], style: GoogleFonts.inter(fontSize: 10, color: SSMPalette.texte2)),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => SSMPalette.indigo,
                      getTooltipItems: (spots) =>
                          spots.map((s) => LineTooltipItem(s.y.toStringAsFixed(0), const TextStyle(color: Colors.white, fontSize: 11))).toList(),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [for (var i = 0; i < valeurs.length; i++) FlSpot(i.toDouble(), valeurs[i])],
                      isCurved: true,
                      color: SSMPalette.indigo,
                      barWidth: 3,
                      dotData: FlDotData(
                        getDotPainter: (spot, percent, bar, index) =>
                            FlDotCirclePainter(radius: 4, color: SSMPalette.indigo, strokeWidth: 2, strokeColor: Colors.white),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [SSMPalette.indigo.withValues(alpha: 0.15), SSMPalette.indigo.withValues(alpha: 0.0)],
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
    const couleurs = [SSMPalette.indigo, SSMPalette.teal, SSMPalette.rouge];
    final maxValeur = valeurs.reduce((a, b) => a > b ? a : b);
    final maxY = maxValeur <= 0 ? 100.0 : maxValeur * 1.25;

    return SSMPanel(
      titre: 'Attendu / Encaissé / Restant',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Taux de recouvrement actuel : ${d.financier.tauxRecouvrement.toStringAsFixed(0)}%.',
            style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte2),
          ),
          const SizedBox(height: 12),
          SizedBox(
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
                      GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: SSMPalette.texte2),
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
                  getDrawingHorizontalLine: (v) => FlLine(color: SSMPalette.bordure, strokeWidth: 1),
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
                          child: Text(labels[i], style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte2)),
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

  // ── Camembert répartition par tranche de moyenne ────────

  Widget _graphiqueRepartitionMoyennes(DashboardGeneral d) {
    final repartition = d.resultats.repartitionMoyennes;
    final total = repartition?.values.fold<int>(0, (a, b) => a + b) ?? 0;

    final titreStyle = GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white);

    return SSMPanel(
      titre: 'Répartition par tranche de moyenne',
      child: repartition == null || total == 0
          ? _etatVide("Répartition non disponible pour l'instant")
          : Column(
              children: [
                SizedBox(
                  height: 190,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 38,
                      sections: [
                        PieChartSectionData(value: (repartition['<10'] ?? 0).toDouble(), color: SSMPalette.rouge, title: '<10', radius: 24, titleStyle: titreStyle),
                        PieChartSectionData(value: (repartition['10-12'] ?? 0).toDouble(), color: SSMPalette.ambre, title: '10-12', radius: 24, titleStyle: titreStyle),
                        PieChartSectionData(value: (repartition['12-14'] ?? 0).toDouble(), color: _ambreClair2, title: '12-14', radius: 24, titleStyle: titreStyle),
                        PieChartSectionData(value: (repartition['14-16'] ?? 0).toDouble(), color: SSMPalette.teal, title: '14-16', radius: 24, titleStyle: titreStyle),
                        PieChartSectionData(value: (repartition['>16'] ?? 0).toDouble(), color: SSMPalette.indigo, title: '>16', radius: 24, titleStyle: titreStyle),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(spacing: 14, runSpacing: 6, alignment: WrapAlignment.center, children: [
                  _legende(SSMPalette.rouge, '< 10'),
                  _legende(SSMPalette.ambre, '10-12'),
                  _legende(_ambreClair2, '12-14'),
                  _legende(SSMPalette.teal, '14-16'),
                  _legende(SSMPalette.indigo, '> 16'),
                ]),
              ],
            ),
    );
  }

  // ══════════════════════════════════════════════════════
  // NAVIGATION VERS LES MODULES DÉTAILLÉS
  // ══════════════════════════════════════════════════════

  Widget _grilleNavigation() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        SSMQuickActionButton(
          icone: Icons.groups_outlined,
          label: 'Inscriptions détaillées',
          variante: SSMActionVariante.primaire,
          onTap: () => _ouvrir(InscriptionsDetailScreen(anneeScolaireId: _anneeId)),
        ),
        SSMQuickActionButton(
          icone: Icons.payments_outlined,
          label: 'Paiements détaillés',
          variante: SSMActionVariante.teal,
          onTap: () => _ouvrir(PaiementsDetailScreen(anneeScolaireId: _anneeId)),
        ),
        SSMQuickActionButton(
          icone: Icons.grade_outlined,
          label: 'Résultats pédagogiques',
          variante: SSMActionVariante.ambre,
          onTap: () => _ouvrir(PedagogiqueDetailScreen(periodeId: _periodeId)),
        ),
        SSMQuickActionButton(
          icone: Icons.notifications_active_outlined,
          label: _nombreAlertes > 0 ? 'Centre de Décision ($_nombreAlertes)' : 'Centre de Décision',
          variante: SSMActionVariante.rouge,
          onTap: () => _ouvrir(CentreDecisionScreen(anneeScolaireId: _anneeId, periodeId: _periodeId)),
        ),
        SSMQuickActionButton(
          icone: Icons.picture_as_pdf_outlined,
          label: 'Rapports',
          variante: SSMActionVariante.gris,
          onTap: () => _ouvrir(const RapportsScreen()),
        ),
      ],
    );
  }
}
