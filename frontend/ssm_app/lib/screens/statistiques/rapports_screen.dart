import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/annee_service.dart';
import '../../services/statistique_detail_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_panel.dart';
import '../../widgets/ssm/ssm_quick_action_button.dart';
import '../../widgets/ssm/ssm_sous_entete.dart';

class _RapportDef {
  final String type; // slug attendu par l'API (/statistiques/rapports/{type})
  final String titre;
  final String description;
  final IconData icone;
  final Color couleur;
  final bool anneeRequise;
  final bool periodeRequise;
  final bool limiteDisponible;
  final bool seuilDisponible;

  const _RapportDef({
    required this.type,
    required this.titre,
    required this.description,
    required this.icone,
    required this.couleur,
    this.anneeRequise = false,
    this.periodeRequise = false,
    this.limiteDisponible = false,
    this.seuilDisponible = false,
  });
}

const List<_RapportDef> _rapports = [
  _RapportDef(
    type: 'inscriptions',
    titre: 'Inscriptions',
    description: 'Effectifs généraux, répartition par niveau, classe et sexe.',
    icone: Icons.groups_outlined,
    couleur: SSMPalette.indigo,
    anneeRequise: true,
  ),
  _RapportDef(
    type: 'financier',
    titre: 'Financier',
    description: 'Résumé financier global et liste des élèves débiteurs.',
    icone: Icons.account_balance_wallet_outlined,
    couleur: SSMPalette.teal,
    anneeRequise: true,
  ),
  _RapportDef(
    type: 'paiements',
    titre: 'Paiements',
    description: 'Paiements par classe, par niveau et recettes par mois.',
    icone: Icons.payments_outlined,
    couleur: SSMPalette.teal,
    anneeRequise: true,
  ),
  _RapportDef(
    type: 'resultats',
    titre: 'Résultats',
    description: 'Résumé des résultats scolaires, par classe et par matière.',
    icone: Icons.grade_outlined,
    couleur: SSMPalette.rouge,
    anneeRequise: true,
    periodeRequise: true,
  ),
  _RapportDef(
    type: 'meilleurs-eleves',
    titre: 'Meilleurs élèves',
    description: "Classement des meilleurs élèves de l'établissement.",
    icone: Icons.emoji_events_outlined,
    couleur: Color(0xFFD4AF37),
    periodeRequise: true,
    limiteDisponible: true,
  ),
  _RapportDef(
    type: 'eleves-en-difficulte',
    titre: 'Élèves en difficulté',
    description: 'Liste des élèves sous le seuil de moyenne choisi.',
    icone: Icons.warning_amber_rounded,
    couleur: SSMPalette.ambre,
    periodeRequise: true,
    seuilDisponible: true,
  ),
];

// ══════════════════════════════════════════════════════════
// Écran "Rapports" du module Statistiques : génération PDF/Excel des 6
// rapports exposés par RapportStatistiqueController, avec filtres
// contextuels (année, période, limite, seuil) avant génération.
// ══════════════════════════════════════════════════════════
class RapportsScreen extends StatefulWidget {
  const RapportsScreen({super.key});

  @override
  State<RapportsScreen> createState() => _RapportsScreenState();
}

class _RapportsScreenState extends State<RapportsScreen> {
  List<dynamic> _annees = [];
  int? _anneeId;
  List<dynamic> _periodes = [];
  int? _periodeId;

  bool _chargementContexte = true;
  String? _typeEnCours;

  @override
  void initState() {
    super.initState();
    _initialiser();
  }

  Future<void> _initialiser() async {
    try {
      final annees = await AnneeService.listerAnnees();
      final data = await AnneeService.anneeActive();
      final annee = data['annee'] as Map<String, dynamic>?;
      final periodeActive = data['periode_active'] as Map<String, dynamic>?;

      final anneeId = annee?['id'] as int? ?? (annees.isNotEmpty ? annees.first['id'] as int : null);
      List<dynamic> periodes = [];
      if (anneeId != null) {
        periodes = await AnneeService.listerPeriodes(anneeId);
      }

      if (!mounted) return;
      setState(() {
        _annees = annees;
        _anneeId = anneeId;
        _periodes = periodes;
        _periodeId = periodeActive?['id'] as int? ?? (periodes.isNotEmpty ? periodes.first['id'] as int : null);
        _chargementContexte = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _chargementContexte = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _afficherErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: SSMPalette.rouge));
  }

  Future<void> _ouvrirFiltres(_RapportDef def) async {
    final resultat = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FeuilleFiltresRapport(
        def: def,
        annees: _annees,
        periodes: _periodes,
        anneeIdInitiale: _anneeId,
        periodeIdInitiale: _periodeId,
      ),
    );
    if (resultat == null) return;

    final format = resultat.remove('format')!;
    await _genererRapport(def, format, resultat);
  }

  Future<void> _genererRapport(_RapportDef def, String format, Map<String, String> filtres) async {
    setState(() => _typeEnCours = def.type);
    try {
      final octets = await StatistiqueDetailService.getRapport(def.type, format, filtres);
      final dossier = await getTemporaryDirectory();
      final extension = format == 'excel' ? 'xlsx' : 'pdf';
      final nomFichier = 'rapport_${def.type.replaceAll('-', '_')}.$extension';
      final fichier = File('${dossier.path}/$nomFichier');
      await fichier.writeAsBytes(octets);
      if (mounted) _proposerActions(fichier.path, def.titre);
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _typeEnCours = null);
    }
  }

  void _proposerActions(String chemin, String titreRapport) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rapport généré', style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
        content: Text('Le rapport "$titreRapport" est prêt.', style: GoogleFonts.inter(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Le partage direct nécessite le paquet share_plus, non
              // installé dans ce projet — on guide vers "Ouvrir" en attendant.
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text("Partage indisponible pour l'instant : utilisez \"Ouvrir\" puis partagez depuis l'application ouverte."),
              ));
            },
            child: const Text('Partager'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              OpenFile.open(chemin);
            },
            child: const Text('Ouvrir'),
          ),
        ],
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
            SSMSousEnTete(titre: 'Rapports', onRetour: () => Navigator.pop(context)),
            Expanded(
              child: _chargementContexte
                  ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          'Choisissez un rapport et un format ; les filtres pertinents (année, période...) vous seront demandés avant la génération.',
                          style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2),
                        ),
                        const SizedBox(height: 16),
                        ..._rapports.map((def) => Padding(padding: const EdgeInsets.only(bottom: 14), child: _carteRapport(def))),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _carteRapport(_RapportDef def) {
    final enCours = _typeEnCours == def.type;

    return SSMPanel(
      titre: def.titre,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: def.couleur.withValues(alpha: 0.14), shape: BoxShape.circle),
                child: Icon(def.icone, color: def.couleur, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(def.description, style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (enCours)
            const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: CircularProgressIndicator(strokeWidth: 2, color: SSMPalette.indigo)))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SSMQuickActionButton(
                  icone: Icons.picture_as_pdf_outlined,
                  label: 'PDF',
                  variante: SSMActionVariante.gris,
                  onTap: () => _ouvrirFiltres(def),
                ),
                SSMQuickActionButton(
                  icone: Icons.table_chart_outlined,
                  label: 'Excel',
                  variante: SSMActionVariante.gris,
                  onTap: () => _ouvrirFiltres(def),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// Feuille modale : filtres contextuels + choix du format, avant génération.
// ══════════════════════════════════════════════════════════
class _FeuilleFiltresRapport extends StatefulWidget {
  final _RapportDef def;
  final List<dynamic> annees;
  final List<dynamic> periodes;
  final int? anneeIdInitiale;
  final int? periodeIdInitiale;

  const _FeuilleFiltresRapport({
    required this.def,
    required this.annees,
    required this.periodes,
    required this.anneeIdInitiale,
    required this.periodeIdInitiale,
  });

  @override
  State<_FeuilleFiltresRapport> createState() => _FeuilleFiltresRapportState();
}

class _FeuilleFiltresRapportState extends State<_FeuilleFiltresRapport> {
  int? _anneeId;
  int? _periodeId;
  double _limite = 10;
  double _seuil = 8;

  @override
  void initState() {
    super.initState();
    _anneeId = widget.anneeIdInitiale;
    _periodeId = widget.periodeIdInitiale;
  }

  Map<String, String> _construireFiltres(String format) {
    final filtres = <String, String>{'format': format};
    if (widget.def.anneeRequise && _anneeId != null) filtres['annee_scolaire_id'] = '$_anneeId';
    if (widget.def.periodeRequise && _periodeId != null) filtres['periode_id'] = '$_periodeId';
    if (widget.def.limiteDisponible) filtres['limite'] = _limite.round().toString();
    if (widget.def.seuilDisponible) filtres['seuil'] = _seuil.toString();
    return filtres;
  }

  @override
  Widget build(BuildContext context) {
    final def = widget.def;
    final filtresIncomplets = (def.anneeRequise && _anneeId == null) || (def.periodeRequise && _periodeId == null);

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(color: SSMPalette.fond, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: SSMPalette.bordure, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('Filtres — ${def.titre}', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.texte1)),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  if (def.anneeRequise) ...[
                    Text('Année scolaire', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<int>(
                      initialValue: _anneeId,
                      isExpanded: true,
                      items: widget.annees.map((a) => DropdownMenuItem<int>(value: a['id'] as int, child: Text(a['libelle'] as String? ?? '—'))).toList(),
                      onChanged: (v) => setState(() => _anneeId = v),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (def.periodeRequise) ...[
                    Text('Période', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<int>(
                      initialValue: _periodeId,
                      isExpanded: true,
                      items: widget.periodes.map((p) => DropdownMenuItem<int>(value: p['id'] as int, child: Text(p['nom'] as String? ?? '—'))).toList(),
                      onChanged: (v) => setState(() => _periodeId = v),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (def.limiteDisponible) ...[
                    Text('Nombre d\'élèves : ${_limite.round()}', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
                    Slider(value: _limite, min: 5, max: 50, divisions: 9, activeColor: SSMPalette.indigo, onChanged: (v) => setState(() => _limite = v)),
                    const SizedBox(height: 8),
                  ],
                  if (def.seuilDisponible) ...[
                    Text('Seuil de moyenne : ${_seuil.toStringAsFixed(0)}/20', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
                    Slider(value: _seuil, min: 0, max: 15, divisions: 15, activeColor: SSMPalette.ambre, onChanged: (v) => setState(() => _seuil = v)),
                    const SizedBox(height: 8),
                  ],
                  if (filtresIncomplets)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Sélectionnez les filtres requis pour générer ce rapport.',
                        style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.rouge),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: filtresIncomplets ? null : () => Navigator.pop(context, _construireFiltres('pdf')),
                          style: OutlinedButton.styleFrom(foregroundColor: SSMPalette.rouge, side: const BorderSide(color: SSMPalette.rouge)),
                          icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                          label: Text('Générer PDF', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: filtresIncomplets ? null : () => Navigator.pop(context, _construireFiltres('excel')),
                          style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.teal, foregroundColor: Colors.white),
                          icon: const Icon(Icons.table_chart_outlined, size: 16),
                          label: Text('Générer Excel', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
