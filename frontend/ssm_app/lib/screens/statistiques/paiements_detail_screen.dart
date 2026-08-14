import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/statistique_detail_model.dart';
import '../../services/annee_service.dart';
import '../../services/classe_service.dart';
import '../../services/statistique_detail_service.dart';
import '../../services/whatsapp_service.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _vert = Color(0xFF16A34A);
const Color _ambre = Color(0xFFD97706);
const Color _rouge = Color(0xFFDC2626);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);
const Color _gris = Color(0xFF94A3B8);
const Color _fond = Color(0xFFEFF6FF);

String _formatMontant(num m) {
  final entier = m.round();
  final texte = entier.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < texte.length; i++) {
    if (i > 0 && (texte.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(texte[i]);
  }
  return '$buffer FCFA';
}

Color _couleurTaux(double taux) {
  if (taux >= 80) return _vert;
  if (taux >= 50) return _ambre;
  return _rouge;
}

// ══════════════════════════════════════════════════════════
// Écran détaillé "Paiements" du module Statistiques (Phase 5) : tableau par
// classe (coloré selon le taux de recouvrement), recettes par mois, et
// liste des élèves non en règle avec rappel WhatsApp / appel direct.
// ══════════════════════════════════════════════════════════
class PaiementsDetailScreen extends StatefulWidget {
  final int? anneeScolaireId;

  const PaiementsDetailScreen({super.key, this.anneeScolaireId});

  @override
  State<PaiementsDetailScreen> createState() => _PaiementsDetailScreenState();
}

class _PaiementsDetailScreenState extends State<PaiementsDetailScreen> {
  List<dynamic> _annees = [];
  int? _anneeId;

  List<PaiementClasse> _parClasse = [];
  List<PaiementMensuel> _parMois = [];

  List<dynamic> _classes = [];
  List<EleveNonEnRegle> _elevesNonEnRegle = [];
  int? _filtreClasseId;
  final TextEditingController _filtreNiveauCtrl = TextEditingController();
  final TextEditingController _filtreMontantMinCtrl = TextEditingController();

  bool _chargementPrincipal = true;
  bool _chargementEleves = true;
  bool _exportEnCours = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _initialiser();
  }

  @override
  void dispose() {
    _filtreNiveauCtrl.dispose();
    _filtreMontantMinCtrl.dispose();
    super.dispose();
  }

  Future<void> _initialiser() async {
    try {
      final resultats = await Future.wait([AnneeService.listerAnnees(), ClasseService.listerClasses()]);
      final annees = resultats[0];
      var anneeId = widget.anneeScolaireId;
      if (anneeId == null) {
        final data = await AnneeService.anneeActive();
        anneeId = (data['annee'] as Map<String, dynamic>?)?['id'] as int? ??
            (annees.isNotEmpty ? annees.first['id'] as int : null);
      }
      if (!mounted) return;
      setState(() {
        _annees = annees;
        _classes = resultats[1];
        _anneeId = anneeId;
      });
      await Future.wait([_charger(), _chargerElevesNonEnRegle()]);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargementPrincipal = false;
        _chargementEleves = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _charger() async {
    if (_anneeId == null) {
      setState(() => _chargementPrincipal = false);
      return;
    }
    setState(() {
      _chargementPrincipal = true;
      _erreur = null;
    });
    try {
      final resultats = await Future.wait([
        StatistiqueDetailService.getPaiementsParClasse(_anneeId!),
        StatistiqueDetailService.getPaiementsParMois(_anneeId!),
      ]);
      if (!mounted) return;
      setState(() {
        _parClasse = resultats[0] as List<PaiementClasse>;
        _parMois = resultats[1] as List<PaiementMensuel>;
        _chargementPrincipal = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargementPrincipal = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _chargerElevesNonEnRegle() async {
    setState(() => _chargementEleves = true);
    try {
      final montantMin = double.tryParse(_filtreMontantMinCtrl.text.replaceAll(' ', ''));
      final eleves = await StatistiqueDetailService.getElevesNonEnRegle(
        anneeScolaireId: _anneeId,
        classeId: _filtreClasseId,
        niveau: _filtreNiveauCtrl.text.trim().isEmpty ? null : _filtreNiveauCtrl.text.trim(),
        montantMin: montantMin,
      );
      if (!mounted) return;
      setState(() {
        _elevesNonEnRegle = eleves;
        _chargementEleves = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _chargementEleves = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _changerAnnee(int? id) {
    if (id == null || id == _anneeId) return;
    setState(() => _anneeId = id);
    Future.wait([_charger(), _chargerElevesNonEnRegle()]);
  }

  void _afficherErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: _rouge));
  }

  Future<void> _exporter(String format) async {
    setState(() => _exportEnCours = true);
    try {
      final octets = await StatistiqueDetailService.getRapport(
        'paiements',
        format,
        {'annee_scolaire_id': '$_anneeId'},
      );
      final dossier = await getTemporaryDirectory();
      final extension = format == 'excel' ? 'xlsx' : 'pdf';
      final fichier = File('${dossier.path}/rapport_paiements.$extension');
      await fichier.writeAsBytes(octets);
      await OpenFile.open(fichier.path);
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _exportEnCours = false);
    }
  }

  Future<void> _appeler(String telephone) async {
    final uri = Uri.parse('tel:$telephone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      _afficherErreur("Impossible de lancer l'appel.");
    }
  }

  Future<void> _envoyerWhatsApp(EleveNonEnRegle eleve) async {
    final message = 'Bonjour, nous vous rappelons que ${_formatMontant(eleve.resteAPayer)} '
        'reste dû pour ${eleve.nomComplet} (${eleve.classe}). Merci de régulariser rapidement.';
    final ouvert = await WhatsAppService.envoyerMessage(numeroTelephone: eleve.telephoneParent!, message: message);
    if (!ouvert && mounted) {
      _afficherErreur("Impossible d'ouvrir WhatsApp.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fond,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: Text('Paiements détaillés', style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: Colors.white)),
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Positioned(top: -80, right: -60, child: _blob(size: 240, couleur: _indigo.withValues(alpha: 0.08))),
          Positioned(bottom: -60, left: -60, child: _blob(size: 200, couleur: _vert.withValues(alpha: 0.08))),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () => Future.wait([_charger(), _chargerElevesNonEnRegle()]),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(child: _selecteurAnnee()),
                      const SizedBox(width: 10),
                      if (_exportEnCours)
                        const SizedBox(width: 40, height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _indigo)))
                      else
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.download_outlined, color: _indigo),
                          onSelected: _exporter,
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'pdf', child: Text('Exporter en PDF')),
                            PopupMenuItem(value: 'excel', child: Text('Exporter en Excel')),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_chargementPrincipal && _erreur == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 80),
                      child: Center(child: CircularProgressIndicator(color: _indigo)),
                    )
                  else if (_erreur != null)
                    _carteErreur(_erreur!, () => Future.wait([_charger(), _chargerElevesNonEnRegle()]))
                  else ...[
                    _cartePaiementsParClasse(),
                    const SizedBox(height: 16),
                    _carteRecettesParMois(),
                    const SizedBox(height: 16),
                    _sectionElevesNonEnRegle(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blob({required double size, required Color couleur}) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: couleur)),
      ),
    );
  }

  Widget _selecteurAnnee() {
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
          child: DropdownButtonFormField<int>(
            value: _anneeId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Année scolaire',
              labelStyle: GoogleFonts.inter(fontSize: 12, color: _texte),
              isDense: true,
              border: InputBorder.none,
            ),
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _texteFonce),
            items: _annees
                .map((a) => DropdownMenuItem<int>(value: a['id'] as int, child: Text(a['libelle'] as String? ?? '—')))
                .toList(),
            onChanged: _changerAnnee,
          ),
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

  Widget _carteGlass({required Widget child, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding ?? const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
            boxShadow: [BoxShadow(color: _texteFonce.withValues(alpha: 0.06), blurRadius: 32, offset: const Offset(0, 8))],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _etatVide(String message) {
    return SizedBox(height: 80, child: Center(child: Text(message, style: GoogleFonts.inter(fontSize: 12, color: _texte))));
  }

  // ── Tableau paiements par classe ─────────────────────────

  Widget _cartePaiementsParClasse() {
    return _carteGlass(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text('Paiements par classe', style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: _texteFonce)),
          ),
          const SizedBox(height: 10),
          if (_parClasse.isEmpty)
            _etatVide('Aucune donnée')
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 34,
                dataRowMinHeight: 44,
                dataRowMaxHeight: 52,
                columnSpacing: 20,
                headingTextStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _texte),
                columns: const [
                  DataColumn(label: Text('CLASSE')),
                  DataColumn(label: Text('À JOUR')),
                  DataColumn(label: Text('EN RETARD')),
                  DataColumn(label: Text('RESTE À PAYER')),
                  DataColumn(label: Text('TAUX')),
                ],
                rows: _parClasse.map((c) {
                  final couleur = _couleurTaux(c.tauxRecouvrement);
                  return DataRow(
                    color: WidgetStateProperty.all(couleur.withValues(alpha: 0.06)),
                    cells: [
                      DataCell(Text(c.classe, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _texteFonce))),
                      DataCell(Text('${c.elevesAJour}', style: GoogleFonts.jetBrainsMono(fontSize: 12, color: _vert))),
                      DataCell(Text('${c.elevesEnRetard}', style: GoogleFonts.jetBrainsMono(fontSize: 12, color: _rouge))),
                      DataCell(Text(_formatMontant(c.resteAPayer), style: GoogleFonts.jetBrainsMono(fontSize: 12, color: _texteFonce))),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: couleur.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
                          child: Text(
                            '${c.tauxRecouvrement.toStringAsFixed(0)}%',
                            style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w700, color: couleur),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // ── Recettes par mois ─────────────────────────────────────

  Widget _carteRecettesParMois() {
    final valeurs = _parMois.map((m) => m.montantEncaisse).toList();
    final maxValeur = valeurs.isEmpty ? 0.0 : valeurs.reduce((a, b) => a > b ? a : b);
    final maxY = maxValeur <= 0 ? 100.0 : maxValeur * 1.25;

    return _carteGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recettes par mois', style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: _texteFonce)),
          const SizedBox(height: 14),
          if (_parMois.isEmpty)
            _etatVide('Aucune donnée')
          else
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
                      getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                          BarTooltipItem(_formatMontant(rod.toY), GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: _texte)),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < _parMois.length; i++)
                      BarChartGroupData(
                        x: i,
                        showingTooltipIndicators: const [0],
                        barRods: [
                          BarChartRodData(toY: valeurs[i], width: 16, borderRadius: BorderRadius.circular(4), color: _vert),
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
                          if (i < 0 || i >= _parMois.length) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(_parMois[i].mois, style: GoogleFonts.inter(fontSize: 9, color: _texte)),
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

  // ── Élèves non en règle ───────────────────────────────────

  Widget _sectionElevesNonEnRegle() {
    return _carteGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Élèves non en règle', style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: _texteFonce)),
          const SizedBox(height: 12),
          _filtresElevesNonEnRegle(),
          const SizedBox(height: 12),
          if (_chargementEleves)
            const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: Center(child: CircularProgressIndicator(color: _indigo)))
          else if (_elevesNonEnRegle.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  const Icon(Icons.check_circle_outline, color: _vert, size: 36),
                  const SizedBox(height: 8),
                  Text('Aucun élève non en règle pour ce filtre.', style: GoogleFonts.inter(fontSize: 12, color: _texte)),
                ],
              ),
            )
          else
            ..._elevesNonEnRegle.map(_carteEleveNonEnRegle),
        ],
      ),
    );
  }

  Widget _filtresElevesNonEnRegle() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(50)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: _filtreClasseId,
                    isDense: true,
                    isExpanded: true,
                    icon: const Icon(Icons.expand_more, size: 16),
                    hint: Text('Toutes les classes', style: GoogleFonts.inter(fontSize: 12, color: _texte)),
                    style: GoogleFonts.inter(fontSize: 12, color: _texte),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Toutes les classes')),
                      ..._classes.map((c) => DropdownMenuItem<int?>(value: c['id'] as int, child: Text(c['nom'] as String))),
                    ],
                    onChanged: (v) {
                      setState(() => _filtreClasseId = v);
                      _chargerElevesNonEnRegle();
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _filtreNiveauCtrl,
                style: GoogleFonts.inter(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Niveau',
                  hintStyle: GoogleFonts.inter(fontSize: 12, color: _gris),
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(50), borderSide: BorderSide.none),
                ),
                onSubmitted: (_) => _chargerElevesNonEnRegle(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _filtreMontantMinCtrl,
                keyboardType: TextInputType.number,
                style: GoogleFonts.inter(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Montant minimum restant (FCFA)',
                  hintStyle: GoogleFonts.inter(fontSize: 12, color: _gris),
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(50), borderSide: BorderSide.none),
                ),
                onSubmitted: (_) => _chargerElevesNonEnRegle(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _chargerElevesNonEnRegle,
              icon: const Icon(Icons.filter_alt_outlined, color: _indigo),
              tooltip: 'Appliquer les filtres',
            ),
          ],
        ),
      ],
    );
  }

  Widget _carteEleveNonEnRegle(EleveNonEnRegle eleve) {
    final aTelephone = eleve.telephoneParent != null && eleve.telephoneParent!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
        border: const Border(left: BorderSide(color: _rouge, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(eleve.nomComplet, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: _texteFonce)),
                    const SizedBox(height: 2),
                    Text(eleve.classe, style: GoogleFonts.inter(fontSize: 12, color: _texte)),
                  ],
                ),
              ),
              Text(_formatMontant(eleve.resteAPayer), style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w700, color: _rouge)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.phone_outlined, size: 13, color: _gris),
              const SizedBox(width: 4),
              Text(
                aTelephone ? eleve.telephoneParent! : 'Aucun numéro enregistré',
                style: GoogleFonts.inter(fontSize: 12, color: _texte),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: aTelephone ? () => _appeler(eleve.telephoneParent!) : null,
                  style: OutlinedButton.styleFrom(foregroundColor: _indigo),
                  icon: const Icon(Icons.call_outlined, size: 15),
                  label: Text('Appeler', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: aTelephone ? () => _envoyerWhatsApp(eleve) : null,
                  style: OutlinedButton.styleFrom(foregroundColor: _vert),
                  icon: const Icon(Icons.chat_bubble_outline, size: 15),
                  label: Text('WhatsApp', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
