import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../../models/rapport_paiement_model.dart';
import '../../services/rapport_paiement_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_data_table.dart';
import '../../widgets/ssm/ssm_sous_entete.dart';
import '../eleves/situation_financiere_screen.dart';

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

// ══════════════════════════════════════════════════════════
// Détail des élèves non en règle d'une classe
// ══════════════════════════════════════════════════════════
class ImpayesClasseScreen extends StatefulWidget {
  final int classeId;
  final String classeNom;

  const ImpayesClasseScreen({super.key, required this.classeId, required this.classeNom});

  @override
  State<ImpayesClasseScreen> createState() => _ImpayesClasseScreenState();
}

class _ImpayesClasseScreenState extends State<ImpayesClasseScreen> {
  SituationClasse? _situation;
  List<ImpayeClasse> _impayes = [];
  bool _chargement = true;
  String? _erreur;
  bool _exportPdfEnCours = false;
  bool _exportExcelEnCours = false;

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
      final resultats = await Future.wait([
        RapportPaiementService.getSituationClasse(widget.classeId),
        RapportPaiementService.getImpayesClasse(widget.classeId),
      ]);
      setState(() {
        _situation = resultats[0] as SituationClasse;
        _impayes = resultats[1] as List<ImpayeClasse>;
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

  Future<void> _exporter(String format) async {
    setState(() {
      if (format == 'excel') {
        _exportExcelEnCours = true;
      } else {
        _exportPdfEnCours = true;
      }
    });
    try {
      final octets = format == 'excel'
          ? await RapportPaiementService.exportSituationClasseExcel(widget.classeId)
          : await RapportPaiementService.exportSituationClassePdf(widget.classeId);

      final dossier = await getApplicationDocumentsDirectory();
      final nomFichierSur = widget.classeNom.replaceAll(RegExp(r'\s+'), '_');
      final extension = format == 'excel' ? 'xlsx' : 'pdf';
      final chemin = '${dossier.path}/situation_$nomFichierSur.$extension';
      await File(chemin).writeAsBytes(octets);
      await OpenFile.open(chemin);
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

  void _voirFicheEleve(ImpayeClasse eleve) {
    final anneeScolaireId = _situation?.anneeScolaireId;
    if (anneeScolaireId == null) {
      _afficherErreur('Année scolaire introuvable pour cette classe.');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SituationFinanciereScreen(
          eleveId: eleve.eleveId,
          classeId: widget.classeId,
          anneeScolaireId: anneeScolaireId,
          eleveNomComplet: eleve.nomComplet,
          classeNom: widget.classeNom,
        ),
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
                              _boutonsExport(),
                              const SizedBox(height: 20),
                              Text(
                                'Élèves non en règle (${_impayes.length})',
                                style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
                              ),
                              const SizedBox(height: 12),
                              if (_impayes.isEmpty)
                                _messageVide('Tous les élèves de cette classe sont en règle. 🎉')
                              else
                                LayoutBuilder(builder: (context, contraintes) {
                                  return contraintes.maxWidth >= 620 ? _tableImpayes() : _listeCartes();
                                }),
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

  Widget _messageVide(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Center(child: Text(message, textAlign: TextAlign.center, style: GoogleFonts.inter(color: SSMPalette.texte3))),
    );
  }

  // ══════════════════════════════════════════════════════
  // EN-TÊTE
  // ══════════════════════════════════════════════════════

  Widget _entete() {
    final s = _situation;
    return SSMSousEnTete(
      titre: widget.classeNom,
      sousTitre: 'Impayés',
      onRetour: () => Navigator.pop(context),
      complement: s == null
          ? null
          : Row(
              children: [
                _statEnTete('Attendu', _formatMontant(s.montantAttendu)),
                const SizedBox(width: 16),
                _statEnTete('Encaissé', _formatMontant(s.montantEncaisse)),
                const SizedBox(width: 16),
                _statEnTete('Reste', _formatMontant(s.resteARecouvrer)),
              ],
            ),
    );
  }

  Widget _statEnTete(String label, String valeur) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: SSMPalette.texte3)),
        Text(valeur, style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: SSMPalette.texte1)),
      ],
    );
  }

  Widget _boutonsExport() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _exportPdfEnCours ? null : () => _exporter('pdf'),
            icon: _exportPdfEnCours
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: SSMPalette.rouge))
                : const Icon(Icons.picture_as_pdf_outlined, size: 16),
            label: const Text('Exporter PDF'),
            style: OutlinedButton.styleFrom(
              foregroundColor: SSMPalette.rouge,
              side: const BorderSide(color: SSMPalette.rouge),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _exportExcelEnCours ? null : () => _exporter('excel'),
            icon: _exportExcelEnCours
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: SSMPalette.teal))
                : const Icon(Icons.grid_on_outlined, size: 16),
            label: const Text('Exporter Excel'),
            style: OutlinedButton.styleFrom(
              foregroundColor: SSMPalette.teal,
              side: const BorderSide(color: SSMPalette.teal),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  // TABLEAU (desktop large)
  // ══════════════════════════════════════════════════════

  Widget _tableImpayes() {
    return SSMDataTable(
      colonnes: const [
        SSMDataColumn('Élève'),
        SSMDataColumn('Matricule'),
        SSMDataColumn('Reste à payer'),
      ],
      onLigneTap: (i) => _voirFicheEleve(_impayes[i]),
      lignes: [
        for (final e in _impayes)
          [
            Text(e.nomComplet, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
            Text(e.matricule ?? '—', style: GoogleFonts.jetBrainsMono(fontSize: 12, color: SSMPalette.texte2)),
            Text(_formatMontant(e.resteAPayer), style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700, color: SSMPalette.rouge)),
          ],
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  // CARTES (mobile / tablette étroite)
  // ══════════════════════════════════════════════════════

  Widget _listeCartes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final e in _impayes) _carteEleve(e)],
    );
  }

  Widget _carteEleve(ImpayeClasse eleve) {
    return Material(
      color: SSMPalette.blanc,
      borderRadius: BorderRadius.circular(SSMRayons.grand),
      child: InkWell(
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        onTap: () => _voirFicheEleve(eleve),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SSMRayons.grand),
            border: Border(
              top: BorderSide(color: SSMPalette.bordure),
              right: BorderSide(color: SSMPalette.bordure),
              bottom: BorderSide(color: SSMPalette.bordure),
              left: const BorderSide(color: SSMPalette.rouge, width: 3),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eleve.nomComplet,
                      style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: SSMPalette.texte1),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      eleve.matricule ?? '—',
                      style: GoogleFonts.jetBrainsMono(fontSize: 11, color: SSMPalette.texte3),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Reste', style: GoogleFonts.inter(fontSize: 10, color: SSMPalette.texte3)),
                  Text(
                    _formatMontant(eleve.resteAPayer),
                    style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w700, color: SSMPalette.rouge),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: SSMPalette.texte3),
            ],
          ),
        ),
      ),
    );
  }
}
