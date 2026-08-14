import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/rapport_paiement_model.dart';
import '../../services/rapport_paiement_service.dart';
import '../../services/annee_service.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _teal = Color(0xFF0D9488);
const Color _ambre = Color(0xFFD97706);
const Color _vert = Color(0xFF16A34A);
const Color _violet = Color(0xFF7C3AED);
const Color _rouge = Color(0xFFDC2626);
const Color _gris = Color(0xFF94A3B8);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);

const List<Color> _paletteModes = [_teal, _indigo, _ambre, _vert, _violet];

const List<String> _moisFrancais = [
  'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
  'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
];

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

String _formatDateApi(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _formatDateCourt(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

enum _TypeRapportSelection {
  journalier('journalier', 'Journalier', Icons.today),
  hebdomadaire('hebdomadaire', 'Hebdomadaire', Icons.view_week_outlined),
  mensuel('mensuel', 'Mensuel', Icons.calendar_month_outlined),
  annuel('annuel', 'Annuel', Icons.calendar_today_outlined),
  personnalise('personnalise', 'Personnalisé', Icons.date_range_outlined);

  final String valeurApi;
  final String libelle;
  final IconData icone;

  const _TypeRapportSelection(this.valeurApi, this.libelle, this.icone);
}

// ══════════════════════════════════════════════════════════
// Rapports de paiements — journalier / hebdomadaire / mensuel /
// annuel / personnalisé, avec graphiques et export PDF/Excel.
// ══════════════════════════════════════════════════════════
class RapportsPaiementsScreen extends StatefulWidget {
  const RapportsPaiementsScreen({super.key});

  @override
  State<RapportsPaiementsScreen> createState() => _RapportsPaiementsScreenState();
}

class _RapportsPaiementsScreenState extends State<RapportsPaiementsScreen> {
  _TypeRapportSelection _type = _TypeRapportSelection.journalier;

  DateTime _dateJournalier = DateTime.now();
  DateTime _dateDebutHebdo = DateTime.now();
  int _moisMensuel = DateTime.now().month;
  int _anneeMensuel = DateTime.now().year;
  List<dynamic> _annees = [];
  int? _anneeScolaireId;
  DateTimeRange? _plage;

  RapportPaiement? _rapport;
  bool _chargementRapport = false;
  bool _chargementAnnees = true;
  String? _erreur;
  bool _exportPdfEnCours = false;
  bool _exportExcelEnCours = false;

  @override
  void initState() {
    super.initState();
    _chargerAnnees();
    _genererRapport();
  }

  Future<void> _chargerAnnees() async {
    try {
      final annees = await AnneeService.listerAnnees();
      final active = annees.firstWhere(
        (a) => a['statut'] == 'active',
        orElse: () => annees.isNotEmpty ? annees.first : null,
      );
      if (!mounted) return;
      setState(() {
        _annees = annees;
        _anneeScolaireId = active?['id'] as int?;
        _chargementAnnees = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _chargementAnnees = false);
    }
  }

  Map<String, String> get _parametresActuels {
    switch (_type) {
      case _TypeRapportSelection.journalier:
        return {'date': _formatDateApi(_dateJournalier)};
      case _TypeRapportSelection.hebdomadaire:
        return {'date_debut': _formatDateApi(_dateDebutHebdo)};
      case _TypeRapportSelection.mensuel:
        return {'mois': '$_moisMensuel', 'annee': '$_anneeMensuel'};
      case _TypeRapportSelection.annuel:
        return {'annee_scolaire_id': '${_anneeScolaireId ?? ''}'};
      case _TypeRapportSelection.personnalise:
        return {
          'date_debut': _formatDateApi(_plage?.start ?? DateTime.now()),
          'date_fin': _formatDateApi(_plage?.end ?? DateTime.now()),
        };
    }
  }

  Future<void> _genererRapport() async {
    if (_type == _TypeRapportSelection.annuel && _anneeScolaireId == null) {
      setState(() => _erreur = 'Sélectionnez une année scolaire.');
      return;
    }
    if (_type == _TypeRapportSelection.personnalise && _plage == null) {
      setState(() => _erreur = 'Sélectionnez une plage de dates.');
      return;
    }

    setState(() {
      _chargementRapport = true;
      _erreur = null;
    });

    try {
      final RapportPaiement rapport;
      switch (_type) {
        case _TypeRapportSelection.journalier:
          rapport = await RapportPaiementService.getRapportJournalier(_formatDateApi(_dateJournalier));
          break;
        case _TypeRapportSelection.hebdomadaire:
          rapport = await RapportPaiementService.getRapportHebdomadaire(_formatDateApi(_dateDebutHebdo));
          break;
        case _TypeRapportSelection.mensuel:
          rapport = await RapportPaiementService.getRapportMensuel(_moisMensuel, _anneeMensuel);
          break;
        case _TypeRapportSelection.annuel:
          rapport = await RapportPaiementService.getRapportAnnuel(_anneeScolaireId!);
          break;
        case _TypeRapportSelection.personnalise:
          rapport = await RapportPaiementService.getRapportPersonnalise(
            _formatDateApi(_plage!.start),
            _formatDateApi(_plage!.end),
          );
          break;
      }
      if (!mounted) return;
      setState(() {
        _rapport = rapport;
        _chargementRapport = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargementRapport = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _afficherErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: _rouge),
    );
  }

  Future<void> _exporter(String format) async {
    setState(() {
      if (format == 'excel') {
        _exportExcelEnCours = true;
      } else {
        _exportPdfEnCours = true;
      }
    });

    try {
      final octets = await RapportPaiementService.exportRapport(
        type: _type.valeurApi,
        format: format,
        parametres: _parametresActuels,
      );

      final dossier = await getApplicationDocumentsDirectory();
      final extension = format == 'excel' ? 'xlsx' : 'pdf';
      final chemin = '${dossier.path}/rapport_paiements_${_type.valeurApi}.$extension';
      final fichier = File(chemin);
      await fichier.writeAsBytes(octets);

      if (!mounted) return;
      await _proposerOuvrirOuPartager(fichier);
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _exportPdfEnCours = false;
          _exportExcelEnCours = false;
        });
      }
    }
  }

  Future<void> _proposerOuvrirOuPartager(File fichier) async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Text('Fichier généré', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: _texteFonce)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.open_in_new, color: _indigo),
              title: const Text('Ouvrir'),
              onTap: () {
                Navigator.pop(context);
                OpenFile.open(fichier.path);
              },
            ),
            ListTile(
              leading: const Icon(Icons.ios_share, color: _teal),
              title: const Text('Partager'),
              onTap: () {
                Navigator.pop(context);
                Share.shareXFiles([XFile(fichier.path)]);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // Sélecteurs de date par type de rapport
  // ══════════════════════════════════════════════════════

  Future<void> _choisirDateJournalier() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateJournalier,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date == null) return;
    setState(() => _dateJournalier = date);
    _genererRapport();
  }

  Future<void> _choisirDateDebutHebdo() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateDebutHebdo,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date == null) return;
    setState(() => _dateDebutHebdo = date);
    _genererRapport();
  }

  Future<void> _choisirPlage() async {
    final plage = await showDateRangePicker(
      context: context,
      initialDateRange: _plage,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (plage == null) return;
    setState(() => _plage = plage);
    _genererRapport();
  }

  // ══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Rapports de paiements')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _genererRapport,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _selecteurType(),
              const SizedBox(height: 12),
              _selecteurDate(),
              const SizedBox(height: 16),
              if (_chargementRapport)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator(color: _indigo)),
                )
              else if (_erreur != null)
                _vueErreur()
              else if (_rapport != null) ...[
                _cartesResume(_rapport!),
                const SizedBox(height: 16),
                if (_rapport!.ventilationParMode.isNotEmpty) ...[
                  _carteVentilationMode(_rapport!),
                  const SizedBox(height: 16),
                ],
                if (_rapport!.ventilationParClasse.isNotEmpty) ...[
                  _carteVentilationClasse(_rapport!),
                  const SizedBox(height: 16),
                ],
                if (_rapport!.evolutionMensuelle.isNotEmpty) ...[
                  _carteEvolutionMensuelle(_rapport!),
                  const SizedBox(height: 16),
                ],
                _carteDetail(_rapport!),
                const SizedBox(height: 20),
                _boutonsExport(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _vueErreur() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: _rouge, size: 40),
            const SizedBox(height: 12),
            Text(_erreur!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: _texte)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _genererRapport,
              style: ElevatedButton.styleFrom(backgroundColor: _indigo, foregroundColor: Colors.white),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // Sélecteur de type (chips)
  // ══════════════════════════════════════════════════════

  Widget _selecteurType() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _TypeRapportSelection.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final type = _TypeRapportSelection.values[i];
          final selectionne = type == _type;
          return ChoiceChip(
            selected: selectionne,
            onSelected: (_) {
              setState(() {
                _type = type;
                _rapport = null;
                _erreur = null;
              });
              _genererRapport();
            },
            avatar: Icon(type.icone, size: 16, color: selectionne ? Colors.white : _indigo),
            label: Text(type.libelle),
            labelStyle: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selectionne ? Colors.white : _texte,
            ),
            selectedColor: _indigo,
            backgroundColor: Colors.white,
            side: BorderSide(color: selectionne ? _indigo : const Color(0xFFE2E8F0)),
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // Sélecteur de date (adapté au type)
  // ══════════════════════════════════════════════════════

  Widget _selecteurDate() {
    switch (_type) {
      case _TypeRapportSelection.journalier:
        return _champSelection(
          icone: Icons.today,
          texte: _formatDateCourt(_dateJournalier),
          onTap: _choisirDateJournalier,
        );
      case _TypeRapportSelection.hebdomadaire:
        final fin = _dateDebutHebdo.add(const Duration(days: 6));
        return _champSelection(
          icone: Icons.view_week_outlined,
          texte: 'Du ${_formatDateCourt(_dateDebutHebdo)} au ${_formatDateCourt(fin)}',
          onTap: _choisirDateDebutHebdo,
        );
      case _TypeRapportSelection.mensuel:
        return Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _moisMensuel,
                decoration: const InputDecoration(labelText: 'Mois', border: OutlineInputBorder()),
                items: [
                  for (var m = 1; m <= 12; m++)
                    DropdownMenuItem(value: m, child: Text(_moisFrancais[m - 1])),
                ],
                onChanged: (valeur) {
                  if (valeur == null) return;
                  setState(() => _moisMensuel = valeur);
                  _genererRapport();
                },
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 110,
              child: DropdownButtonFormField<int>(
                value: _anneeMensuel,
                decoration: const InputDecoration(labelText: 'Année', border: OutlineInputBorder()),
                items: [
                  for (var a = DateTime.now().year; a >= DateTime.now().year - 5; a--)
                    DropdownMenuItem(value: a, child: Text('$a')),
                ],
                onChanged: (valeur) {
                  if (valeur == null) return;
                  setState(() => _anneeMensuel = valeur);
                  _genererRapport();
                },
              ),
            ),
          ],
        );
      case _TypeRapportSelection.annuel:
        if (_chargementAnnees) {
          return const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)));
        }
        return DropdownButtonFormField<int>(
          value: _anneeScolaireId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Année scolaire', border: OutlineInputBorder()),
          items: _annees
              .map((a) => DropdownMenuItem<int>(value: a['id'] as int, child: Text(a['libelle'].toString())))
              .toList(),
          onChanged: (valeur) {
            if (valeur == null) return;
            setState(() => _anneeScolaireId = valeur);
            _genererRapport();
          },
        );
      case _TypeRapportSelection.personnalise:
        return _champSelection(
          icone: Icons.date_range_outlined,
          texte: _plage == null
              ? 'Choisir une plage de dates'
              : 'Du ${_formatDateCourt(_plage!.start)} au ${_formatDateCourt(_plage!.end)}',
          onTap: _choisirPlage,
        );
    }
  }

  Widget _champSelection({required IconData icone, required String texte, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF94A3B8)),
        ),
        child: Row(
          children: [
            Icon(icone, size: 18, color: _indigo),
            const SizedBox(width: 10),
            Text(texte, style: GoogleFonts.inter(fontSize: 14, color: _texteFonce)),
            const Spacer(),
            const Icon(Icons.edit_calendar_outlined, size: 16, color: _gris),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // Cards résumé
  // ══════════════════════════════════════════════════════

  Widget _cartesResume(RapportPaiement r) {
    final cards = <Widget>[
      _carteStat('Transactions', '${r.nombrePaiements}', Icons.receipt_long_outlined, _indigo),
      _carteStat('Total encaissé', _formatMontant(r.totalEncaisse), Icons.payments_outlined, _teal),
    ];
    if (r.resteARecouvrer != null) {
      cards.add(_carteStat('Reste à recouvrer', _formatMontant(r.resteARecouvrer!), Icons.error_outline, _rouge));
    }

    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: cards[i]),
        ],
      ],
    );
  }

  Widget _carteStat(String titre, String valeur, IconData icone, Color couleur) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: couleur, size: 20),
          const SizedBox(height: 8),
          Text(
            valeur,
            style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.w700, color: _texteFonce),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(titre, style: GoogleFonts.inter(fontSize: 11, color: _gris)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // Camembert — ventilation par mode de paiement
  // ══════════════════════════════════════════════════════

  Widget _carteVentilationMode(RapportPaiement r) {
    final entrees = r.ventilationParMode.entries.where((e) => e.value > 0).toList();
    final total = entrees.fold<double>(0, (t, e) => t + e.value);

    return _carteGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ventilation par mode de paiement', style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: _texteFonce)),
          const SizedBox(height: 16),
          if (entrees.isEmpty)
            Center(child: Text('Aucune donnée', style: GoogleFonts.inter(color: _gris)))
          else
            SizedBox(
              height: 190,
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: [
                          for (var i = 0; i < entrees.length; i++)
                            PieChartSectionData(
                              value: entrees[i].value,
                              color: _paletteModes[i % _paletteModes.length],
                              showTitle: false,
                              radius: 26,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 5,
                    child: ListView.builder(
                      itemCount: entrees.length,
                      itemBuilder: (context, i) {
                        final e = entrees[i];
                        final pct = total > 0 ? (e.value / total * 100) : 0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(width: 10, height: 10, decoration: BoxDecoration(color: _paletteModes[i % _paletteModes.length], shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(e.key, style: GoogleFonts.inter(fontSize: 12, color: _texte), overflow: TextOverflow.ellipsis),
                              ),
                              Text('${pct.toStringAsFixed(0)}%', style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w700, color: _texteFonce)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // Barres — ventilation par classe
  // ══════════════════════════════════════════════════════

  Widget _carteVentilationClasse(RapportPaiement r) {
    final entrees = r.ventilationParClasse.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxY = entrees.isEmpty ? 100.0 : entrees.map((e) => e.value).reduce((a, b) => a > b ? a : b) * 1.2;

    return _carteGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ventilation par classe', style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: _texteFonce)),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY <= 0 ? 10 : maxY,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => _indigo,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                      _formatMontant(rod.toY),
                      const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < entrees.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: entrees[i].value,
                          width: 18,
                          borderRadius: BorderRadius.circular(4),
                          gradient: const LinearGradient(colors: [_indigo, _teal], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                        ),
                      ],
                    ),
                ],
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: (maxY <= 0 ? 10 : maxY) / 4,
                  getDrawingHorizontalLine: (v) => FlLine(color: _texteFonce.withValues(alpha: 0.04), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (value, meta) => Text('${(value / 1000).toStringAsFixed(0)}k', style: GoogleFonts.inter(fontSize: 9, color: _gris)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 46,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= entrees.length) return const SizedBox();
                        final libelle = entrees[i].key;
                        final court = libelle.length > 8 ? '${libelle.substring(0, 7)}…' : libelle;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Transform.rotate(angle: -0.5, child: Text(court, style: GoogleFonts.inter(fontSize: 9, color: _texte))),
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

  // ══════════════════════════════════════════════════════
  // Évolution mensuelle (rapport annuel)
  // ══════════════════════════════════════════════════════

  Widget _carteEvolutionMensuelle(RapportPaiement r) {
    return _carteGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Évolution mensuelle', style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: _texteFonce)),
          const SizedBox(height: 12),
          ...r.evolutionMensuelle.map((m) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(m.libelle, style: GoogleFonts.inter(fontSize: 12, color: _texte)),
                    Text(_formatMontant(m.montant), style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: _texteFonce)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // Détail (transactions ou synthèse par jour selon le type)
  // ══════════════════════════════════════════════════════

  Widget _carteDetail(RapportPaiement r) {
    if (r.transactions.isNotEmpty) {
      return _carteGlass(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Transactions (${r.transactions.length})', style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: _texteFonce)),
            const SizedBox(height: 10),
            ...r.transactions.map(_ligneTransaction),
          ],
        ),
      );
    }

    if (r.parJour.isNotEmpty) {
      return _carteGlass(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Détail par jour', style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: _texteFonce)),
            const SizedBox(height: 10),
            ...r.parJour.map((j) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(j.libelle, style: GoogleFonts.inter(fontSize: 12, color: _texte)),
                      Text('${j.nombrePaiements} paiement(s) · ${_formatMontant(j.totalEncaisse)}',
                          style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w600, color: _texteFonce)),
                    ],
                  ),
                )),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _ligneTransaction(TransactionResume t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.eleve, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _texteFonce)),
                const SizedBox(height: 2),
                Text(
                  [t.numeroRecu, t.classe ?? t.fraisNom].whereType<String>().join(' · '),
                  style: GoogleFonts.inter(fontSize: 11, color: _gris),
                ),
              ],
            ),
          ),
          Text(_formatMontant(t.montant), style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700, color: _texteFonce)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // Boutons d'export
  // ══════════════════════════════════════════════════════

  Widget _boutonsExport() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _exportPdfEnCours ? null : () => _exporter('pdf'),
            icon: _exportPdfEnCours
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: const Text('Exporter PDF'),
            style: ElevatedButton.styleFrom(backgroundColor: _rouge, foregroundColor: Colors.white),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _exportExcelEnCours ? null : () => _exporter('excel'),
            icon: _exportExcelEnCours
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.grid_on_outlined, size: 18),
            label: const Text('Exporter Excel'),
            style: ElevatedButton.styleFrom(backgroundColor: _teal, foregroundColor: Colors.white),
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
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: child,
        ),
      ),
    );
  }
}
