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

const Color _indigo = Color(0xFF1E3A8A);
const Color _teal = Color(0xFF0D9488);
const Color _ambre = Color(0xFFD97706);
const Color _vert = Color(0xFF16A34A);
const Color _rouge = Color(0xFFDC2626);
const Color _gris = Color(0xFF94A3B8);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);

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
      return _ambre;
    case 'rejetee':
      return _rouge;
    default:
      return _indigo;
  }
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
      SnackBar(content: Text(message), backgroundColor: _rouge),
    );
  }

  void _afficherSucces(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: _vert),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Déverrouiller une saisie'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'À utiliser si une saisie a été validée par erreur : elle repassera "en cours" et l\'enseignant pourra corriger.',
                  style: GoogleFonts.inter(fontSize: 12, color: _texte),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: classeId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Classe', border: OutlineInputBorder(), isDense: true),
                  items: classes.map((c) => DropdownMenuItem<int>(value: c['id'] as int, child: Text(c['nom'] as String))).toList(),
                  onChanged: (v) => setDialogState(() => classeId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: matiereId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Matière', border: OutlineInputBorder(), isDense: true),
                  items: matieres.map((m) => DropdownMenuItem<int>(value: m['id'] as int, child: Text(m['nom'] as String))).toList(),
                  onChanged: (v) => setDialogState(() => matiereId = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: motifController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Motif du déverrouillage *', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _ambre, foregroundColor: Colors.white),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _enTete(),
            _barreExport(),
            Expanded(
              child: _chargement
                  ? const Center(child: CircularProgressIndicator(color: _indigo))
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_indigo, _teal], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
                Expanded(
                  child: Text(
                    'Analyse des performances',
                    style: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
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
        ],
      ),
    );
  }

  Widget _barreExport() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: _exportEnCours
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _indigo)),
            )
          : Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _exporter('pdf'),
                    icon: const Icon(Icons.picture_as_pdf, size: 18, color: _rouge),
                    label: Text('Exporter PDF', style: GoogleFonts.inter(fontSize: 12, color: _texte)),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _exporter('excel'),
                    icon: const Icon(Icons.table_chart, size: 18, color: _vert),
                    label: Text('Exporter Excel', style: GoogleFonts.inter(fontSize: 12, color: _texte)),
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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _classesIncompletes.length,
      itemBuilder: (context, index) {
        final c = _classesIncompletes[index];
        return _carteListe(
          titre: c.nomClasse,
          couleur: _rouge,
          sousTitre: c.matieresManquantes.join(', '),
          trailing: _badge('${c.matieresManquantes.length}', _rouge),
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
        OutlinedButton.icon(
          onPressed: _ouvrirDialogDeverrouillage,
          style: OutlinedButton.styleFrom(foregroundColor: _ambre),
          icon: const Icon(Icons.lock_open_outlined),
          label: const Text('Déverrouiller une saisie'),
        ),
        const SizedBox(height: 12),
        if (_matieresNonValidees.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text('Toutes les matières sont validées.', style: GoogleFonts.inter(color: _vert)),
          )
        else
          ..._matieresNonValidees.map((classe) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(classe.classeNom, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: _texteFonce)),
                    const SizedBox(height: 6),
                    ...classe.matieres.map((m) => _carteListe(
                          titre: m.matiereNom,
                          sousTitre: m.enseignantNom,
                          couleur: _couleurStatutSaisie(m.statut),
                          trailing: _badge(_libelleStatutSaisie(m.statut), _couleurStatutSaisie(m.statut)),
                        )),
                  ],
                ),
              )),
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  // ONGLET : ENSEIGNANTS EN RETARD
  // ══════════════════════════════════════════════════════

  Widget _ongletEnseignantsEnRetard() {
    if (_enseignantsEnRetard.isEmpty) return _messageVide('Aucun enseignant en retard (ou la date limite de la période n\'est pas encore dépassée).');

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _enseignantsEnRetard.length,
      itemBuilder: (context, index) {
        final e = _enseignantsEnRetard[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('${e.nom} — ${e.matiere} (${e.classe})', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _texteFonce)),
                  ),
                  _badge('${e.joursDeRetard} j de retard', _rouge),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: (e.pourcentageCompletion / 100).clamp(0.0, 1.0), minHeight: 6, backgroundColor: const Color(0xFFF1F5F9), color: _rouge),
              ),
              const SizedBox(height: 4),
              Text('${e.pourcentageCompletion.toStringAsFixed(0)}% complété', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: _gris)),
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
              Text('Seuil : ${seuil.toStringAsFixed(0)}/20', style: GoogleFonts.inter(fontSize: 12, color: _texte)),
              Expanded(
                child: Slider(
                  value: seuil,
                  min: 0,
                  max: 20,
                  divisions: 20,
                  activeColor: _indigo,
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
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: eleves.length,
                  itemBuilder: (context, index) {
                    final e = eleves[index];
                    return _carteListe(
                      titre: '${e.rang}. ${e.nomComplet}',
                      sousTitre: e.classe,
                      couleur: _indigo,
                      trailing: Text(
                        e.moyenne.toStringAsFixed(2),
                        style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w700, color: _texteFonce),
                      ),
                    );
                  },
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

    final maxY = 100.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))]),
          child: SizedBox(
            height: 240,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => _indigo,
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
                gridData: FlGridData(drawVerticalLine: false, horizontalInterval: 25, getDrawingHorizontalLine: (v) => FlLine(color: _texteFonce.withValues(alpha: 0.04), strokeWidth: 1)),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 36, getTitlesWidget: (value, meta) => Text('${value.toInt()}%', style: GoogleFonts.inter(fontSize: 9, color: _gris))),
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
                          child: Text(court, style: GoogleFonts.inter(fontSize: 9, color: _texte)),
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
        ..._classementClasses.map((c) => _carteListe(
              titre: c.classe,
              sousTitre: c.moyenneGenerale != null ? 'Moyenne : ${c.moyenneGenerale!.toStringAsFixed(2)}/20' : 'Moyenne : —',
              couleur: _couleurTaux(c.tauxReussite),
              trailing: Text('${c.tauxReussite.toStringAsFixed(0)}%', style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w700, color: _couleurTaux(c.tauxReussite))),
            )),
      ],
    );
  }

  Color _couleurTaux(double taux) {
    if (taux >= 70) return _vert;
    if (taux >= 40) return _ambre;
    return _rouge;
  }

  // ══════════════════════════════════════════════════════
  // AIDES COMMUNES
  // ══════════════════════════════════════════════════════

  Widget _messageVide(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center, style: GoogleFonts.inter(color: _gris)),
      ),
    );
  }

  Widget _carteListe({required String titre, String? sousTitre, required Color couleur, Widget? trailing}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: couleur, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _texteFonce)),
                if (sousTitre != null && sousTitre.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(sousTitre, style: GoogleFonts.inter(fontSize: 11, color: _gris), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );
  }

  Widget _badge(String label, Color couleur) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: couleur.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: couleur)),
    );
  }
}
