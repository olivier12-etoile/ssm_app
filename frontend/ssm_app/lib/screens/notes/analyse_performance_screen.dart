import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/analyse_performance_model.dart';
import '../../services/validation_note_service.dart';
import '../../services/classe_service.dart';
import '../../services/matiere_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_alert_item.dart';
import '../../widgets/ssm/ssm_data_table.dart';
import '../../widgets/ssm/ssm_panel.dart';
import '../../widgets/ssm/ssm_pill.dart';
import '../../widgets/ssm/ssm_quick_action_button.dart';
import '../../widgets/ssm/ssm_sous_entete.dart';

String _libelleStatutSaisie(String statut) {
  switch (statut) {
    case 'en_cours':
      return 'En cours';
    case 'en_attente_validation':
      return 'En attente';
    case 'rejetee':
      return 'Rejetée';
    default:
      return statut;
  }
}

Color _couleurStatutSaisie(String statut) {
  switch (statut) {
    case 'en_attente_validation':
      return SSMPalette.ambre;
    case 'rejetee':
      return SSMPalette.rouge;
    default:
      return SSMPalette.indigo;
  }
}

Color _couleurTaux(double taux) {
  if (taux >= 70) return SSMPalette.teal;
  if (taux >= 40) return SSMPalette.ambre;
  return SSMPalette.rouge;
}

class AnalysePerformanceScreen extends StatefulWidget {
  final int periodeId;

  const AnalysePerformanceScreen({super.key, required this.periodeId});

  @override
  State<AnalysePerformanceScreen> createState() => _AnalysePerformanceScreenState();
}

class _AnalysePerformanceScreenState extends State<AnalysePerformanceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<ClasseIncomplete> _classesIncompletes = [];
  List<ClasseMatieresNonValidees> _matieresNonValidees = [];
  List<EnseignantRetard> _enseignantsEnRetard = [];
  List<EleveNiveau> _elevesFaibles = [];
  List<EleveNiveau> _elevesExcellents = [];
  List<ClassementClasse> _classementClasses = [];

  double _seuilFaible = 8;
  double _seuilExcellent = 16;

  bool _chargement = true;
  bool _exportEnCours = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _charger();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final resultats = await Future.wait([
        ValidationNoteService.getClassesIncompletes(widget.periodeId),
        ValidationNoteService.getMatieresNonValidees(widget.periodeId),
        ValidationNoteService.getEnseignantsEnRetard(widget.periodeId),
        ValidationNoteService.getElevesFaibles(widget.periodeId, seuil: _seuilFaible),
        ValidationNoteService.getElevesExcellents(widget.periodeId, seuil: _seuilExcellent),
        ValidationNoteService.getClassementClasses(widget.periodeId),
      ]);

      setState(() {
        _classesIncompletes = resultats[0] as List<ClasseIncomplete>;
        _matieresNonValidees = resultats[1] as List<ClasseMatieresNonValidees>;
        _enseignantsEnRetard = resultats[2] as List<EnseignantRetard>;
        _elevesFaibles = resultats[3] as List<EleveNiveau>;
        _elevesExcellents = resultats[4] as List<EleveNiveau>;
        _classementClasses = resultats[5] as List<ClassementClasse>;
        _chargement = false;
      });
    } catch (e) {
      setState(() {
        _chargement = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _rechargerElevesFaibles() async {
    try {
      final eleves = await ValidationNoteService.getElevesFaibles(widget.periodeId, seuil: _seuilFaible);
      if (mounted) setState(() => _elevesFaibles = eleves);
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _rechargerElevesExcellents() async {
    try {
      final eleves = await ValidationNoteService.getElevesExcellents(widget.periodeId, seuil: _seuilExcellent);
      if (mounted) setState(() => _elevesExcellents = eleves);
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _afficherErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: SSMPalette.rouge),
    );
  }

  void _afficherSucces(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: SSMPalette.teal),
    );
  }

  // ── Export PDF/Excel ─────────────────────────────────────
  // L'export backend couvre élèves faibles + élèves excellents + classement
  // des classes (seules données que /notes/export/analyse-performance
  // produit) : les onglets "Classes incomplètes", "Matières non validées"
  // et "Enseignants en retard" ne sont pas inclus dans ce fichier.
  Future<void> _exporter(String format) async {
    setState(() => _exportEnCours = true);
    try {
      final octets = await ValidationNoteService.exporterAnalysePerformance(
        periodeId: widget.periodeId,
        format: format,
      );
      final dossier = await getTemporaryDirectory();
      final extension = format == 'excel' ? 'xlsx' : 'pdf';
      final fichier = File('${dossier.path}/analyse_performance.$extension');
      await fichier.writeAsBytes(octets);
      await OpenFile.open(fichier.path);
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _exportEnCours = false);
    }
  }

  // ── Déverrouillage ───────────────────────────────────────
  Future<void> _ouvrirDialogDeverrouillage() async {
    final classes = await ClasseService.listerClasses();
    final matieres = await MatiereService.listerMatieres();
    if (!mounted) return;

    int? classeId;
    int? matiereId;
    final motifController = TextEditingController();

    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: SSMPalette.blanc,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
          title: Text('Déverrouiller une saisie', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'À utiliser si une saisie a été validée par erreur : elle repassera "en cours" et l\'enseignant pourra corriger.',
                  style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: classeId,
                  isExpanded: true,
                  decoration: _decorationChamp('Classe'),
                  items: classes.map((c) => DropdownMenuItem<int>(value: c['id'] as int, child: Text(c['nom'] as String))).toList(),
                  onChanged: (v) => setDialogState(() => classeId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: matiereId,
                  isExpanded: true,
                  decoration: _decorationChamp('Matière'),
                  items: matieres.map((m) => DropdownMenuItem<int>(value: m['id'] as int, child: Text(m['nom'] as String))).toList(),
                  onChanged: (v) => setDialogState(() => matiereId = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: motifController,
                  maxLines: 2,
                  decoration: _decorationChamp('Motif du déverrouillage *'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Annuler', style: GoogleFonts.inter(color: SSMPalette.texte2))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.ambre, foregroundColor: Colors.white, elevation: 0),
              onPressed: (classeId == null || matiereId == null || motifController.text.trim().isEmpty)
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Déverrouiller'),
            ),
          ],
        ),
      ),
    );

    if (confirme != true || classeId == null || matiereId == null) return;

    try {
      await ValidationNoteService.deverrouiller(
        classeId: classeId!,
        matiereId: matiereId!,
        periodeId: widget.periodeId,
        motif: motifController.text.trim(),
      );
      _afficherSucces('Saisie déverrouillée avec succès');
      _charger();
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  InputDecoration _decorationChamp(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2),
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SSMRayons.moyen),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SSMRayons.moyen),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SSMRayons.moyen),
        borderSide: const BorderSide(color: SSMPalette.indigo, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SSMPalette.fond,
      body: SafeArea(
        child: Column(
          children: [
            _entete(),
            _barreExport(),
            Expanded(
              child: _chargement
                  ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
                  : _erreur != null
                      ? _vueErreur()
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _ongletClassesIncompletes(),
                            _ongletMatieresNonValidees(),
                            _ongletEnseignantsEnRetard(),
                            _ongletEleves(_elevesFaibles, _seuilFaible, (v) => setState(() => _seuilFaible = v), _rechercherElevesFaibles),
                            _ongletEleves(_elevesExcellents, _seuilExcellent, (v) => setState(() => _seuilExcellent = v), _rechercherElevesExcellents),
                            _ongletClassementClasses(),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void Function(double) get _rechercherElevesFaibles => (_) => _rechargerElevesFaibles();
  void Function(double) get _rechercherElevesExcellents => (_) => _rechargerElevesExcellents();

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
  // EN-TÊTE
  // ══════════════════════════════════════════════════════

  Widget _entete() {
    return Column(
      children: [
        SSMSousEnTete(titre: 'Analyse des performances', onRetour: () => Navigator.pop(context)),
        Container(
          color: SSMPalette.blanc,
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: SSMPalette.bordure))),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: SSMPalette.teal,
            labelColor: SSMPalette.indigo,
            unselectedLabelColor: SSMPalette.texte3,
            labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Classes incomplètes'),
              Tab(text: 'Matières non validées'),
              Tab(text: 'Enseignants en retard'),
              Tab(text: 'Élèves faibles'),
              Tab(text: 'Élèves excellents'),
              Tab(text: 'Classement classes'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _barreExport() {
    return Container(
      color: SSMPalette.blanc,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: _exportEnCours
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: SSMPalette.indigo)),
            )
          : Row(
              children: [
                Expanded(
                  child: SSMQuickActionButton(
                    icone: Icons.picture_as_pdf,
                    label: 'Exporter PDF',
                    variante: SSMActionVariante.rouge,
                    onTap: () => _exporter('pdf'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SSMQuickActionButton(
                    icone: Icons.table_chart,
                    label: 'Exporter Excel',
                    variante: SSMActionVariante.teal,
                    onTap: () => _exporter('excel'),
                  ),
                ),
              ],
            ),
    );
  }

  // ══════════════════════════════════════════════════════
  // ONGLET : CLASSES INCOMPLÈTES
  // ══════════════════════════════════════════════════════

  Widget _ongletClassesIncompletes() {
    if (_classesIncompletes.isEmpty) return _messageVide('Toutes les classes ont leurs matières complètes.');

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _classesIncompletes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final c = _classesIncompletes[index];
        return SSMAlertItem(
          type: SSMAlerteType.avertissement,
          icone: Icons.class_outlined,
          titre: '${c.nomClasse} — ${c.matieresManquantes.length} matière(s) manquante(s)',
          sousTitre: c.matieresManquantes.join(', '),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════
  // ONGLET : MATIÈRES NON VALIDÉES
  // ══════════════════════════════════════════════════════

  Widget _ongletMatieresNonValidees() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SSMQuickActionButton(
          icone: Icons.lock_open_outlined,
          label: 'Déverrouiller une saisie',
          variante: SSMActionVariante.ambre,
          onTap: _ouvrirDialogDeverrouillage,
        ),
        const SizedBox(height: 12),
        if (_matieresNonValidees.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text('Toutes les matières sont validées.', style: GoogleFonts.inter(color: SSMPalette.teal)),
          )
        else
          ..._matieresNonValidees.map((classe) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SSMPanel(
                  titre: classe.classeNom,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < classe.matieres.length; i++) ...[
                        if (i > 0) const Divider(height: 16, color: SSMPalette.bordure),
                        _ligneMatiere(classe.matieres[i]),
                      ],
                    ],
                  ),
                ),
              )),
      ],
    );
  }

  Widget _ligneMatiere(dynamic m) {
    final couleur = _couleurStatutSaisie(m.statut as String);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(m.matiereNom as String, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
              Text(m.enseignantNom as String, style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte3)),
            ],
          ),
        ),
        SSMPill.couleur(label: _libelleStatutSaisie(m.statut as String), couleur: couleur),
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  // ONGLET : ENSEIGNANTS EN RETARD
  // ══════════════════════════════════════════════════════

  Widget _ongletEnseignantsEnRetard() {
    if (_enseignantsEnRetard.isEmpty) return _messageVide('Aucun enseignant en retard (ou la date limite de la période n\'est pas encore dépassée).');

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _enseignantsEnRetard.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final e = _enseignantsEnRetard[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: SSMPalette.blanc, borderRadius: BorderRadius.circular(SSMRayons.grand), border: Border.all(color: SSMPalette.bordure)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('${e.nom} — ${e.matiere} (${e.classe})', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
                  ),
                  SSMPill.couleur(label: '${e.joursDeRetard} j de retard', couleur: SSMPalette.rouge),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: (e.pourcentageCompletion / 100).clamp(0.0, 1.0), minHeight: 6, backgroundColor: const Color(0xFFF1F5F9), color: SSMPalette.rouge),
              ),
              const SizedBox(height: 4),
              Text('${e.pourcentageCompletion.toStringAsFixed(0)}% complété', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: SSMPalette.texte3)),
            ],
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════
  // ONGLET : ÉLÈVES FAIBLES / EXCELLENTS
  // ══════════════════════════════════════════════════════

  Widget _ongletEleves(List<EleveNiveau> eleves, double seuil, ValueChanged<double> onSeuilChange, ValueChanged<double> onSeuilChangeEnd) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Text('Seuil : ${seuil.toStringAsFixed(0)}/20', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
              Expanded(
                child: Slider(
                  value: seuil,
                  min: 0,
                  max: 20,
                  divisions: 20,
                  activeColor: SSMPalette.indigo,
                  label: seuil.toStringAsFixed(0),
                  onChanged: onSeuilChange,
                  onChangeEnd: onSeuilChangeEnd,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: eleves.isEmpty
              ? _messageVide('Aucun élève pour ce seuil.')
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SSMDataTable(
                    colonnes: const [
                      SSMDataColumn('Rang', largeur: 40),
                      SSMDataColumn('Élève'),
                      SSMDataColumn('Classe'),
                      SSMDataColumn('Moyenne'),
                    ],
                    lignes: [
                      for (final e in eleves)
                        [
                          Text('${e.rang}', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
                          Text(e.nomComplet, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
                          Text(e.classe, style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
                          Text(e.moyenne.toStringAsFixed(2), style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700, color: SSMPalette.texte1)),
                        ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  // ONGLET : CLASSEMENT DES CLASSES
  // ══════════════════════════════════════════════════════

  Widget _ongletClassementClasses() {
    if (_classementClasses.isEmpty) return _messageVide('Aucune donnée de classement disponible.');

    const maxY = 100.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: SSMPalette.blanc, borderRadius: BorderRadius.circular(SSMRayons.grand), border: Border.all(color: SSMPalette.bordure)),
          child: SizedBox(
            height: 240,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => SSMPalette.indigo,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                      '${rod.toY.toStringAsFixed(0)}%',
                      const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < _classementClasses.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: _classementClasses[i].tauxReussite,
                          width: 18,
                          borderRadius: BorderRadius.circular(4),
                          gradient: LinearGradient(
                            colors: [_couleurTaux(_classementClasses[i].tauxReussite), _couleurTaux(_classementClasses[i].tauxReussite).withValues(alpha: 0.5)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ],
                    ),
                ],
                gridData: FlGridData(drawVerticalLine: false, horizontalInterval: 25, getDrawingHorizontalLine: (v) => FlLine(color: SSMPalette.texte1.withValues(alpha: 0.04), strokeWidth: 1)),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 36, getTitlesWidget: (value, meta) => Text('${value.toInt()}%', style: GoogleFonts.inter(fontSize: 9, color: SSMPalette.texte3))),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 46,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= _classementClasses.length) return const SizedBox();
                        final nom = _classementClasses[i].classe;
                        final court = nom.length > 6 ? '${nom.substring(0, 5)}…' : nom;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(court, style: GoogleFonts.inter(fontSize: 9, color: SSMPalette.texte2)),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SSMDataTable(
          colonnes: const [
            SSMDataColumn('Classe'),
            SSMDataColumn('Moyenne'),
            SSMDataColumn('Taux'),
          ],
          lignes: [
            for (final c in _classementClasses)
              [
                Text(c.classe, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
                Text(c.moyenneGenerale != null ? '${c.moyenneGenerale!.toStringAsFixed(2)}/20' : '—', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
                SSMPill.couleur(label: '${c.tauxReussite.toStringAsFixed(0)}%', couleur: _couleurTaux(c.tauxReussite)),
              ],
          ],
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  // AIDES COMMUNES
  // ══════════════════════════════════════════════════════

  Widget _messageVide(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center, style: GoogleFonts.inter(color: SSMPalette.texte3)),
      ),
    );
  }
}
