import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/analyse_performance_model.dart';
import '../../services/validation_note_service.dart';
import '../../widgets/note_input_field.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _teal = Color(0xFF0D9488);
const Color _ambre = Color(0xFFD97706);
const Color _vert = Color(0xFF16A34A);
const Color _rouge = Color(0xFFDC2626);
const Color _gris = Color(0xFF94A3B8);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);

String _formatValeur(double? v) {
  if (v == null) return '—';
  return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}

class DetailValidationScreen extends StatefulWidget {
  final int saisieId;

  const DetailValidationScreen({super.key, required this.saisieId});

  @override
  State<DetailValidationScreen> createState() => _DetailValidationScreenState();
}

class _DetailValidationScreenState extends State<DetailValidationScreen> {
  DetailSaisieValidation? _detail;
  bool _chargement = true;
  bool _actionEnCours = false;
  String? _erreur;

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
      final detail = await ValidationNoteService.getDetailSaisie(widget.saisieId);
      setState(() {
        _detail = detail;
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

  Future<void> _confirmerValidation() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Valider cette saisie ?'),
        content: const Text(
          'Les notes seront verrouillées et ne pourront plus être modifiées par l\'enseignant sans déverrouillage explicite.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _vert, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Valider'),
          ),
        ],
      ),
    );

    if (confirme != true) return;

    setState(() => _actionEnCours = true);
    try {
      await ValidationNoteService.valider(widget.saisieId);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _actionEnCours = false);
    }
  }

  Future<void> _demanderRejet() async {
    final motifController = TextEditingController();

    final motif = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Rejeter cette saisie'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "L'enseignant devra corriger et resoumettre ses notes.",
              style: GoogleFonts.inter(fontSize: 13, color: _texte),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: motifController,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Motif du rejet *',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _rouge, foregroundColor: Colors.white),
            onPressed: () {
              if (motifController.text.trim().isEmpty) return;
              Navigator.pop(context, motifController.text.trim());
            },
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );

    if (motif == null || motif.isEmpty) return;

    setState(() => _actionEnCours = true);
    try {
      await ValidationNoteService.rejeter(widget.saisieId, motif);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _actionEnCours = false);
    }
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
                : Column(
                    children: [
                      _entete(),
                      if (_detail!.statistiques.anomalies.isNotEmpty) _banniereAnomalies(),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          children: [
                            _cartesStats(),
                            const SizedBox(height: 20),
                            Text(
                              'NOTES DES ÉLÈVES',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _indigo, letterSpacing: 0.4),
                            ),
                            const SizedBox(height: 10),
                            _tableauNotes(),
                          ],
                        ),
                      ),
                      _barreActions(),
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

  Widget _entete() {
    final saisie = _detail!.saisie;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_indigo, _teal], begin: Alignment.topLeft, end: Alignment.bottomRight),
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
                Text(
                  saisie.classeNom ?? 'Classe',
                  style: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                Text(
                  '${saisie.matiereNom ?? ''} · ${saisie.periodeNom ?? ''}',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.75)),
                ),
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 12, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(
                      _detail!.enseignantNom,
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.75)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _banniereAnomalies() {
    final critique = _detail!.statistiques.aDesAnomaliesCritiques;
    final couleur = critique ? _rouge : _ambre;

    return Container(
      width: double.infinity,
      color: couleur.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: couleur, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _detail!.statistiques.anomalies.join('\n'),
              style: GoogleFonts.inter(fontSize: 12, color: couleur),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // STATS
  // ══════════════════════════════════════════════════════

  Widget _cartesStats() {
    final s = _detail!.statistiques;
    return Row(
      children: [
        Expanded(child: _carteStat('Moyenne', _formatValeur(s.moyenne), _indigo)),
        const SizedBox(width: 8),
        Expanded(child: _carteStat('Meilleure', _formatValeur(s.meilleureNote), _vert)),
        const SizedBox(width: 8),
        Expanded(child: _carteStat('Plus faible', _formatValeur(s.plusFaibleNote), _rouge)),
        const SizedBox(width: 8),
        Expanded(child: _carteStat('Réussite', '${s.tauxReussite.toStringAsFixed(0)}%', _teal)),
      ],
    );
  }

  Widget _carteStat(String label, String valeur, Color couleur) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Text(valeur, style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.w700, color: couleur)),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: _gris)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // TABLEAU DES NOTES (lecture seule)
  // ══════════════════════════════════════════════════════

  Widget _tableauNotes() {
    if (_detail!.eleves.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text('Aucune note saisie', style: GoogleFonts.inter(color: _gris)),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('Élève', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _gris))),
                Expanded(child: Text('Devoir', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _gris))),
                Expanded(child: Text('Composition', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _gris))),
              ],
            ),
          ),
          const Divider(height: 1),
          ..._detail!.eleves.map((eleve) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        eleve.nomComplet,
                        style: GoogleFonts.inter(fontSize: 13, color: _texteFonce),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: NoteInputField(
                          controller: TextEditingController(text: _formatValeur(eleve.noteDevoir?.valeur)),
                          lectureSeule: true,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: NoteInputField(
                          controller: TextEditingController(text: _formatValeur(eleve.noteComposition?.valeur)),
                          lectureSeule: true,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // ACTIONS
  // ══════════════════════════════════════════════════════

  Widget _barreActions() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: _actionEnCours
          ? const Center(child: CircularProgressIndicator(color: _indigo))
          : Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _demanderRejet,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _rouge,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: const BorderSide(color: _rouge),
                    ),
                    icon: const Text('❌'),
                    label: Text('Rejeter', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _confirmerValidation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _vert,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Text('✅'),
                    label: Text('Valider', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
    );
  }
}
