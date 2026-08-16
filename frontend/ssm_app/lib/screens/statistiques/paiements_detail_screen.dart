import 'dart:io';
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
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_data_table.dart';
import '../../widgets/ssm/ssm_panel.dart';
import '../../widgets/ssm/ssm_pill.dart';
import '../../widgets/ssm/ssm_sous_entete.dart';

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
  if (taux >= 80) return SSMPalette.teal;
  if (taux >= 50) return SSMPalette.ambre;
  return SSMPalette.rouge;
}

// ══════════════════════════════════════════════════════════
// Écran détaillé "Paiements" du module Statistiques : tableau par classe
// (coloré selon le taux de recouvrement), recettes par mois, et liste des
// élèves non en règle avec rappel WhatsApp / appel direct.
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: SSMPalette.rouge));
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
      backgroundColor: SSMPalette.fond,
      body: SafeArea(
        child: Column(
          children: [
            SSMSousEnTete(
              titre: 'Paiements détaillés',
              onRetour: () => Navigator.pop(context),
              complement: _selecteurAnnee(),
              actions: [
                if (_exportEnCours)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: SSMPalette.indigo)),
                  )
                else
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.download_outlined, color: SSMPalette.indigo),
                    onSelected: _exporter,
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'pdf', child: Text('Exporter en PDF')),
                      PopupMenuItem(value: 'excel', child: Text('Exporter en Excel')),
                    ],
                  ),
              ],
            ),
            Expanded(
              child: _chargementPrincipal && _erreur == null
                  ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
                  : _erreur != null
                      ? _carteErreur(_erreur!, () => Future.wait([_charger(), _chargerElevesNonEnRegle()]))
                      : RefreshIndicator(
                          onRefresh: () => Future.wait([_charger(), _chargerElevesNonEnRegle()]),
                          color: SSMPalette.indigo,
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              _cartePaiementsParClasse(),
                              const SizedBox(height: 16),
                              _carteRecettesParMois(),
                              const SizedBox(height: 16),
                              _sectionElevesNonEnRegle(),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selecteurAnnee() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(SSMRayons.moyen),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _anneeId,
          isDense: true,
          icon: const Icon(Icons.expand_more, size: 16, color: SSMPalette.texte3),
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: SSMPalette.texte1),
          items: _annees
              .map((a) => DropdownMenuItem<int>(value: a['id'] as int, child: Text(a['libelle'] as String? ?? '—')))
              .toList(),
          onChanged: _changerAnnee,
        ),
      ),
    );
  }

  Widget _carteErreur(String message, Future<void> Function() onReessayer) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: SSMPalette.rouge, size: 36),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center, style: GoogleFonts.inter(color: SSMPalette.texte2)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onReessayer, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }

  Widget _etatVide(String message) {
    return SizedBox(height: 80, child: Center(child: Text(message, style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2))));
  }

  // ── Tableau paiements par classe ─────────────────────────

  Widget _cartePaiementsParClasse() {
    return SSMPanel(
      titre: 'Paiements par classe',
      padding: EdgeInsets.zero,
      child: _parClasse.isEmpty
          ? Padding(padding: const EdgeInsets.all(16), child: _etatVide('Aucune donnée'))
          : SSMDataTable(
              colonnes: const [
                SSMDataColumn('Classe'),
                SSMDataColumn('À jour'),
                SSMDataColumn('En retard'),
                SSMDataColumn('Reste à payer'),
                SSMDataColumn('Taux'),
              ],
              lignes: [
                for (final c in _parClasse)
                  [
                    Text(c.classe, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
                    Text('${c.elevesAJour}', style: GoogleFonts.jetBrainsMono(fontSize: 12, color: SSMPalette.teal)),
                    Text('${c.elevesEnRetard}', style: GoogleFonts.jetBrainsMono(fontSize: 12, color: SSMPalette.rouge)),
                    Text(
                      _formatMontant(c.resteAPayer),
                      style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: _couleurTaux(c.tauxRecouvrement)),
                    ),
                    SSMPill.couleur(label: '${c.tauxRecouvrement.toStringAsFixed(0)}%', couleur: _couleurTaux(c.tauxRecouvrement)),
                  ],
              ],
            ),
    );
  }

  // ── Recettes par mois ─────────────────────────────────────

  Widget _carteRecettesParMois() {
    final valeurs = _parMois.map((m) => m.montantEncaisse).toList();
    final maxValeur = valeurs.isEmpty ? 0.0 : valeurs.reduce((a, b) => a > b ? a : b);
    final maxY = maxValeur <= 0 ? 100.0 : maxValeur * 1.25;

    return SSMPanel(
      titre: 'Recettes par mois',
      child: _parMois.isEmpty
          ? _etatVide('Aucune donnée')
          : SizedBox(
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
                          BarTooltipItem(_formatMontant(rod.toY), GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: SSMPalette.texte2)),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < _parMois.length; i++)
                      BarChartGroupData(
                        x: i,
                        showingTooltipIndicators: const [0],
                        barRods: [
                          BarChartRodData(toY: valeurs[i], width: 16, borderRadius: BorderRadius.circular(4), color: SSMPalette.teal),
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
                          if (i < 0 || i >= _parMois.length) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(_parMois[i].mois, style: GoogleFonts.inter(fontSize: 9, color: SSMPalette.texte2)),
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

  // ── Élèves non en règle ───────────────────────────────────

  Widget _sectionElevesNonEnRegle() {
    return SSMPanel(
      titre: 'Élèves non en règle',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _filtresElevesNonEnRegle(),
          const SizedBox(height: 12),
          if (_chargementEleves)
            const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: Center(child: CircularProgressIndicator(color: SSMPalette.indigo)))
          else if (_elevesNonEnRegle.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  const Icon(Icons.check_circle_outline, color: SSMPalette.teal, size: 36),
                  const SizedBox(height: 8),
                  Text('Aucun élève non en règle pour ce filtre.', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
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
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  borderRadius: BorderRadius.circular(SSMRayons.moyen),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: _filtreClasseId,
                    isDense: true,
                    isExpanded: true,
                    icon: const Icon(Icons.expand_more, size: 16, color: SSMPalette.texte3),
                    hint: Text('Toutes les classes', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
                    style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte1),
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
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onSubmitted: (_) => _chargerElevesNonEnRegle(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _chargerElevesNonEnRegle,
              icon: const Icon(Icons.filter_alt_outlined, color: SSMPalette.indigo),
              tooltip: 'Appliquer les filtres',
            ),
          ],
        ),
      ],
    );
  }

  // Style aligné sur _carteDebiteur (debiteurs_screen.dart déjà migré) :
  // fond blanc, bordure gauche colorée, montant + pill, actions en bas.
  Widget _carteEleveNonEnRegle(EleveNonEnRegle eleve) {
    final aTelephone = eleve.telephoneParent != null && eleve.telephoneParent!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SSMPalette.blanc,
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        border: Border(
          top: BorderSide(color: SSMPalette.bordure),
          right: BorderSide(color: SSMPalette.bordure),
          bottom: BorderSide(color: SSMPalette.bordure),
          left: const BorderSide(color: SSMPalette.rouge, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(eleve.nomComplet, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
                    const SizedBox(height: 2),
                    Text(eleve.classe, style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
                  ],
                ),
              ),
              Text(_formatMontant(eleve.resteAPayer), style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w700, color: SSMPalette.rouge)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.phone_outlined, size: 13, color: SSMPalette.texte3),
              const SizedBox(width: 4),
              Text(
                aTelephone ? eleve.telephoneParent! : 'Aucun numéro enregistré',
                style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: aTelephone ? () => _appeler(eleve.telephoneParent!) : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SSMPalette.indigo,
                    side: const BorderSide(color: SSMPalette.indigo),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
                  ),
                  icon: const Icon(Icons.call_outlined, size: 15),
                  label: Text('Appeler', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: aTelephone ? () => _envoyerWhatsApp(eleve) : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SSMPalette.teal,
                    side: const BorderSide(color: SSMPalette.teal),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
                  ),
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
