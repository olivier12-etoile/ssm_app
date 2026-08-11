import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/note_model.dart';
import '../../services/note_service.dart';
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
  if (v == null) return '';
  return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

String _cle(int eleveId, TypeEvaluation type) => '$eleveId-${type.valeurApi}';

class SaisieNotesScreen extends StatefulWidget {
  final SaisieNote saisie;

  const SaisieNotesScreen({super.key, required this.saisie});

  @override
  State<SaisieNotesScreen> createState() => _SaisieNotesScreenState();
}

class _SaisieNotesScreenState extends State<SaisieNotesScreen> {
  late SaisieNote _saisie;
  List<EleveSaisie> _eleves = [];
  bool _verrouillee = false;
  StatistiquesSaisie? _stats;
  TypeEvaluation _typeSelectionne = TypeEvaluation.devoir;

  final Map<String, TextEditingController> _controleurs = {};
  final Map<String, Timer> _debounces = {};

  bool _chargement = true;
  bool _enregistrementTout = false;
  bool _soumissionEnCours = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _saisie = widget.saisie;
    _charger();
  }

  @override
  void dispose() {
    for (final t in _debounces.values) {
      t.cancel();
    }
    for (final c in _controleurs.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final resultats = await Future.wait([
        NoteService.getElevesSaisie(_saisie.id),
        NoteService.getStatistiques(
          classeId: _saisie.classeId,
          matiereId: _saisie.matiereId,
          periodeId: _saisie.periodeId,
        ),
      ]);

      final elevesResultat = resultats[0] as ({bool verrouillee, List<EleveSaisie> eleves});
      final stats = resultats[1] as StatistiquesSaisie;

      _initControleurs(elevesResultat.eleves);

      setState(() {
        _eleves = elevesResultat.eleves;
        _verrouillee = elevesResultat.verrouillee;
        _stats = stats;
        _chargement = false;
      });
    } catch (e) {
      setState(() {
        _chargement = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _initControleurs(List<EleveSaisie> eleves) {
    for (final eleve in eleves) {
      for (final type in TypeEvaluation.values) {
        final cle = _cle(eleve.eleveId, type);
        final valeur = eleve.notePourType(type)?.valeur;
        _controleurs.putIfAbsent(cle, () => TextEditingController(text: _formatValeur(valeur)));
      }
    }
  }

  Future<void> _rafraichirStatistiques() async {
    try {
      final stats = await NoteService.getStatistiques(
        classeId: _saisie.classeId,
        matiereId: _saisie.matiereId,
        periodeId: _saisie.periodeId,
      );
      if (mounted) setState(() => _stats = stats);
    } catch (_) {
      // Rafraîchissement silencieux : une erreur ici n'empêche pas la saisie.
    }
  }

  void _afficherErreur(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: _rouge),
    );
  }

  void _afficherSucces(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: _vert),
    );
  }

  // ── Sauvegarde automatique (debounce) ──────────────────

  void _surChangementNote(EleveSaisie eleve, TypeEvaluation type, String texte) {
    final cle = _cle(eleve.eleveId, type);
    _debounces[cle]?.cancel();
    _debounces[cle] = Timer(const Duration(milliseconds: 800), () => _enregistrerNote(eleve, type));
    // Rafraîchit l'affichage (couleur du champ) immédiatement, sans attendre le debounce.
    setState(() {});
  }

  Future<void> _enregistrerNote(EleveSaisie eleve, TypeEvaluation type) async {
    final cle = _cle(eleve.eleveId, type);
    final texte = _controleurs[cle]!.text.trim();
    if (texte.isEmpty) return;

    final valeur = double.tryParse(texte.replaceAll(',', '.'));
    if (valeur == null || valeur < 0 || valeur > 20) return;

    try {
      final note = await NoteService.enregistrerNote(Note(
        eleveId: eleve.eleveId,
        matiereId: _saisie.matiereId,
        classeId: _saisie.classeId,
        periodeId: _saisie.periodeId,
        valeur: valeur,
        typeEvaluation: type,
      ));
      _remplacerNoteLocale(eleve.eleveId, type, note);
      _rafraichirStatistiques();
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _remplacerNoteLocale(int eleveId, TypeEvaluation type, Note note) {
    final index = _eleves.indexWhere((e) => e.eleveId == eleveId);
    if (index == -1) return;

    final ancien = _eleves[index];
    setState(() {
      _eleves[index] = EleveSaisie(
        eleveId: ancien.eleveId,
        nom: ancien.nom,
        prenom: ancien.prenom,
        matricule: ancien.matricule,
        noteDevoir: type == TypeEvaluation.devoir ? note : ancien.noteDevoir,
        noteComposition: type == TypeEvaluation.composition ? note : ancien.noteComposition,
      );
    });
  }

  // ── Enregistrer tout (bouton) ───────────────────────────

  Future<void> _enregistrerTout() async {
    final notes = <Note>[];
    for (final eleve in _eleves) {
      for (final type in TypeEvaluation.values) {
        final texte = _controleurs[_cle(eleve.eleveId, type)]!.text.trim();
        if (texte.isEmpty) continue;
        final valeur = double.tryParse(texte.replaceAll(',', '.'));
        if (valeur == null || valeur < 0 || valeur > 20) continue;
        notes.add(Note(
          eleveId: eleve.eleveId,
          matiereId: _saisie.matiereId,
          classeId: _saisie.classeId,
          periodeId: _saisie.periodeId,
          valeur: valeur,
          typeEvaluation: type,
        ));
      }
    }

    if (notes.isEmpty) {
      _afficherErreur('Aucune note valide à enregistrer.');
      return;
    }

    setState(() => _enregistrementTout = true);
    try {
      final enregistrees = await NoteService.enregistrerNotesBulk(
        classeId: _saisie.classeId,
        matiereId: _saisie.matiereId,
        periodeId: _saisie.periodeId,
        notes: notes,
      );
      for (final note in enregistrees) {
        _remplacerNoteLocale(note.eleveId, note.typeEvaluation, note);
      }
      await _rafraichirStatistiques();
      _afficherSucces('${enregistrees.length} note(s) enregistrée(s)');
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _enregistrementTout = false);
    }
  }

  // ── Soumission ───────────────────────────────────────────

  Future<void> _confirmerSoumission() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Terminer la saisie ?'),
        content: const Text(
          'Les notes seront transmises à la direction pour validation. Vous ne pourrez plus les modifier tant que la saisie n\'est pas rejetée ou déverrouillée.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _indigo, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Terminer'),
          ),
        ],
      ),
    );

    if (confirme != true) return;

    setState(() => _soumissionEnCours = true);
    try {
      final message = await NoteService.soumettreSaisie(_saisie.id);
      if (!mounted) return;
      _afficherSucces(message);
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _soumissionEnCours = false);
    }
  }

  // Motif de rejet (porté par les notes, pas par la saisie elle-même).
  String? get _motifRejet {
    for (final eleve in _eleves) {
      final motif = eleve.noteDevoir?.motifRejet ?? eleve.noteComposition?.motifRejet;
      if (motif != null && motif.isNotEmpty) return motif;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final lectureSeule = _verrouillee;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: (_chargement || lectureSeule)
          ? null
          : FloatingActionButton.extended(
              onPressed: _soumissionEnCours ? null : _confirmerSoumission,
              backgroundColor: _indigo,
              icon: _soumissionEnCours
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline, color: Colors.white),
              label: Text(
                'Terminer la saisie',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
      body: SafeArea(
        child: _chargement
            ? const Center(child: CircularProgressIndicator(color: _indigo))
            : _erreur != null
                ? _vueErreur()
                : Column(
                    children: [
                      _entete(),
                      if (lectureSeule) _banniereVerrouillee(),
                      if (!lectureSeule && _saisie.statut == StatutSaisie.rejetee) _banniereRejet(),
                      if (_stats != null && _stats!.anomalies.isNotEmpty) _banniereAnomalies(),
                      _barreStats(),
                      _toggleType(),
                      Expanded(child: _listeEleves(lectureSeule)),
                      if (!lectureSeule) _barreEnregistrerTout(),
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
  // EN-TÊTE (sticky : hors de la liste défilante)
  // ══════════════════════════════════════════════════════

  Widget _entete() {
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
                  _saisie.classeNom ?? 'Classe',
                  style: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                Text(
                  '${_saisie.matiereNom ?? ''} · ${_saisie.periodeNom ?? ''}',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.75)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _banniereVerrouillee() {
    return _banniere(
      icone: Icons.lock_outline,
      couleur: _vert,
      texte: 'Notes validées, lecture seule.',
    );
  }

  Widget _banniereRejet() {
    final motif = _motifRejet;
    return _banniere(
      icone: Icons.error_outline,
      couleur: _ambre,
      texte: motif != null ? 'Saisie rejetée par la direction : $motif' : 'Saisie rejetée par la direction.',
    );
  }

  Widget _banniereAnomalies() {
    final critique = _stats!.aDesAnomaliesCritiques;
    final couleur = critique ? _rouge : _ambre;

    return _banniere(
      icone: Icons.warning_amber_rounded,
      couleur: couleur,
      texte: _stats!.anomalies.join('\n'),
    );
  }

  Widget _banniere({required IconData icone, required Color couleur, required String texte}) {
    return Container(
      width: double.infinity,
      color: couleur.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: couleur, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(texte, style: GoogleFonts.inter(fontSize: 12, color: couleur))),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // BARRE STATS LIVE
  // ══════════════════════════════════════════════════════

  Widget _barreStats() {
    final s = _stats;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(child: _statCompacte('Moyenne', s?.moyenne, _indigo)),
          Expanded(child: _statCompacte('Meilleure', s?.meilleureNote, _vert)),
          Expanded(child: _statCompacte('Plus faible', s?.plusFaibleNote, _rouge)),
          Expanded(child: _statPourcentage('Réussite', s?.tauxReussite, _teal)),
        ],
      ),
    );
  }

  Widget _statCompacte(String label, double? valeur, Color couleur) {
    return Column(
      children: [
        Text(
          valeur != null ? valeur.toStringAsFixed(2) : '—',
          style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.w700, color: couleur),
        ),
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: _gris)),
      ],
    );
  }

  Widget _statPourcentage(String label, double? valeur, Color couleur) {
    return Column(
      children: [
        Text(
          valeur != null ? '${valeur.toStringAsFixed(0)}%' : '—',
          style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.w700, color: couleur),
        ),
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: _gris)),
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  // TOGGLE DEVOIR / COMPOSITION
  // ══════════════════════════════════════════════════════

  Widget _toggleType() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(50)),
        child: Row(
          children: TypeEvaluation.values.map((type) {
            final actif = _typeSelectionne == type;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _typeSelectionne = type),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: actif ? _indigo : Colors.transparent,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Text(
                    type.libelle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: actif ? Colors.white : _texte),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // LISTE DES ÉLÈVES
  // ══════════════════════════════════════════════════════

  Widget _listeEleves(bool lectureSeule) {
    if (_eleves.isEmpty) {
      return Center(child: Text('Aucun élève inscrit dans cette classe', style: GoogleFonts.inter(color: _gris)));
    }

    final autreType = _typeSelectionne == TypeEvaluation.devoir ? TypeEvaluation.composition : TypeEvaluation.devoir;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
      itemCount: _eleves.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final eleve = _eleves[index];
        final controleur = _controleurs[_cle(eleve.eleveId, _typeSelectionne)]!;
        final autreNote = eleve.notePourType(autreType);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text('${index + 1}', style: GoogleFonts.inter(fontSize: 12, color: _gris)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eleve.nomComplet,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _texteFonce),
                    ),
                    Text(
                      '${autreType.libelle} : ${autreNote != null ? _formatValeur(autreNote.valeur) : '—'}',
                      style: GoogleFonts.inter(fontSize: 11, color: _gris),
                    ),
                  ],
                ),
              ),
              NoteInputField(
                controller: controleur,
                lectureSeule: lectureSeule,
                onChanged: lectureSeule ? null : (texte) => _surChangementNote(eleve, _typeSelectionne, texte),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _barreEnregistrerTout() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: OutlinedButton.icon(
        onPressed: _enregistrementTout ? null : _enregistrerTout,
        style: OutlinedButton.styleFrom(
          foregroundColor: _indigo,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        icon: _enregistrementTout
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _indigo))
            : const Icon(Icons.save_outlined),
        label: const Text('Enregistrer tout'),
      ),
    );
  }
}
