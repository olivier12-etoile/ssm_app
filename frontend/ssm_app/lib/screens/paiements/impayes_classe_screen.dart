import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../../models/rapport_paiement_model.dart';
import '../../services/rapport_paiement_service.dart';
import '../eleves/situation_financiere_screen.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _teal = Color(0xFF0D9488);
const Color _rouge = Color(0xFFDC2626);
const Color _gris = Color(0xFF94A3B8);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);

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
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: _chargement
            ? const Center(child: CircularProgressIndicator(color: _indigo))
            : _erreur != null
                ? _vueErreur()
                : RefreshIndicator(
                    onRefresh: _charger,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      children: [
                        _enTete(),
                        const SizedBox(height: 16),
                        _boutonsExport(),
                        const SizedBox(height: 20),
                        Text(
                          'Élèves non en règle (${_impayes.length})',
                          style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: _texteFonce),
                        ),
                        const SizedBox(height: 12),
                        if (_impayes.isEmpty)
                          _messageVide('Tous les élèves de cette classe sont en règle. 🎉')
                        else
                          ..._impayes.map(_carteEleve),
                      ],
                    ),
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
            IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
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

  Widget _messageVide(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Center(child: Text(message, textAlign: TextAlign.center, style: GoogleFonts.inter(color: _gris))),
    );
  }

  // ══════════════════════════════════════════════════════
  // EN-TÊTE
  // ══════════════════════════════════════════════════════

  Widget _enTete() {
    final s = _situation;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_indigo, _teal], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Impayés', style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
                const SizedBox(height: 4),
                Text(
                  widget.classeNom,
                  style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                if (s != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _statEnTete('Attendu', _formatMontant(s.montantAttendu)),
                      const SizedBox(width: 16),
                      _statEnTete('Encaissé', _formatMontant(s.montantEncaisse)),
                      const SizedBox(width: 16),
                      _statEnTete('Reste', _formatMontant(s.resteARecouvrer)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statEnTete(String label, String valeur) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.white.withValues(alpha: 0.7))),
        Text(valeur, style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
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
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _rouge))
                : const Icon(Icons.picture_as_pdf_outlined, size: 16),
            label: const Text('Exporter PDF'),
            style: OutlinedButton.styleFrom(foregroundColor: _rouge, side: const BorderSide(color: _rouge)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _exportExcelEnCours ? null : () => _exporter('excel'),
            icon: _exportExcelEnCours
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _teal))
                : const Icon(Icons.grid_on_outlined, size: 16),
            label: const Text('Exporter Excel'),
            style: OutlinedButton.styleFrom(foregroundColor: _teal, side: const BorderSide(color: _teal)),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  // Carte élève
  // ══════════════════════════════════════════════════════

  Widget _carteEleve(ImpayeClasse eleve) {
    return GestureDetector(
      onTap: () => _voirFicheEleve(eleve),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(14),
              border: const Border(left: BorderSide(color: _rouge, width: 4)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3)),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eleve.nomComplet,
                        style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: _texteFonce),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        eleve.matricule ?? '—',
                        style: GoogleFonts.inter(fontSize: 11, color: _gris),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Reste', style: GoogleFonts.inter(fontSize: 10, color: _gris)),
                    Text(
                      _formatMontant(eleve.resteAPayer),
                      style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w700, color: _rouge),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: _gris),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
