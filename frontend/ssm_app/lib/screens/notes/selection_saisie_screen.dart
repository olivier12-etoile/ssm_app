import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/note_model.dart';
import '../../services/note_service.dart';
import '../../services/annee_service.dart';
import '../../services/affectation_service.dart';
import '../../services/auth_service.dart';
import 'saisie_notes_screen.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _teal = Color(0xFF0D9488);
const Color _ambre = Color(0xFFD97706);
const Color _vert = Color(0xFF16A34A);
const Color _rouge = Color(0xFFDC2626);
const Color _gris = Color(0xFF94A3B8);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);

Color _couleurStatut(StatutSaisie statut) {
  switch (statut) {
    case StatutSaisie.enCours:
      return _indigo;
    case StatutSaisie.terminee:
      return _teal;
    case StatutSaisie.enAttenteValidation:
      return _ambre;
    case StatutSaisie.validee:
      return _vert;
    case StatutSaisie.rejetee:
      return _rouge;
  }
}

class SelectionSaisieScreen extends StatefulWidget {
  const SelectionSaisieScreen({super.key});

  @override
  State<SelectionSaisieScreen> createState() => _SelectionSaisieScreenState();
}

class _SelectionSaisieScreenState extends State<SelectionSaisieScreen> {
  List<dynamic> _annees = [];
  List<dynamic> _periodes = [];
  List<dynamic> _affectations = [];
  List<SaisieNote> _progressions = [];

  int? _anneeId;
  int? _periodeId;
  int? _classeId;
  int? _matiereId;

  bool _chargementReferences = true;
  bool _chargementProgressions = true;
  bool _chargementPeriodes = false;
  bool _demarrageEnCours = false;

  @override
  void initState() {
    super.initState();
    _chargerReferences();
    _chargerProgressions();
  }

  Future<void> _chargerReferences() async {
    setState(() => _chargementReferences = true);
    try {
      final utilisateur = await AuthService.getUtilisateur();
      final resultats = await Future.wait([
        AnneeService.listerAnnees(),
        if (utilisateur != null) AffectationService.listerAffectations(utilisateur.id) else Future.value(<String, dynamic>{}),
      ]);

      final annees = resultats[0] as List<dynamic>;
      final affectationsData = resultats[1] as Map<String, dynamic>;

      final anneeActive = annees.firstWhere(
        (a) => a['statut'] == 'active',
        orElse: () => annees.isNotEmpty ? annees.first : null,
      );

      setState(() {
        _annees = annees;
        _affectations = (affectationsData['affectations'] as List?) ?? [];
        _anneeId = anneeActive?['id'] as int?;
        _chargementReferences = false;
      });

      if (_anneeId != null) await _chargerPeriodes(_anneeId!);
    } catch (e) {
      setState(() => _chargementReferences = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _chargerPeriodes(int anneeId) async {
    setState(() {
      _chargementPeriodes = true;
      _periodes = [];
      _periodeId = null;
    });
    try {
      final periodes = await AnneeService.listerPeriodes(anneeId);
      setState(() {
        _periodes = periodes;
        _chargementPeriodes = false;
      });
    } catch (e) {
      setState(() => _chargementPeriodes = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _chargerProgressions() async {
    setState(() => _chargementProgressions = true);
    try {
      final saisies = await NoteService.getProgression();
      setState(() {
        _progressions = saisies;
        _chargementProgressions = false;
      });
    } catch (e) {
      setState(() => _chargementProgressions = false);
    }
  }

  void _afficherErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: _rouge),
    );
  }

  // Classes distinctes issues des affectations de l'enseignant connecté.
  List<Map<String, dynamic>> get _classesDisponibles {
    final vues = <int>{};
    final resultat = <Map<String, dynamic>>[];
    for (final a in _affectations) {
      final id = a['classe_id'] as int;
      if (vues.add(id)) {
        resultat.add({'id': id, 'nom': a['classe_nom']});
      }
    }
    return resultat;
  }

  // Matières enseignées par l'enseignant dans la classe sélectionnée.
  List<Map<String, dynamic>> get _matieresDisponibles {
    if (_classeId == null) return [];
    return _affectations
        .where((a) => a['classe_id'] == _classeId)
        .map((a) => {'id': a['matiere_id'] as int, 'nom': a['matiere_nom']})
        .toList();
  }

  Future<void> _demarrerSaisie() async {
    if (_classeId == null || _matiereId == null || _periodeId == null) return;

    setState(() => _demarrageEnCours = true);
    try {
      final saisie = await NoteService.demarrerSaisie(
        classeId: _classeId!,
        matiereId: _matiereId!,
        periodeId: _periodeId!,
      );
      if (!mounted) return;
      await _ouvrirSaisie(saisie);
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _demarrageEnCours = false);
    }
  }

  Future<void> _ouvrirSaisie(SaisieNote saisie) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SaisieNotesScreen(saisie: saisie)),
    );
    _chargerProgressions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([_chargerReferences(), _chargerProgressions()]);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              _enTete(),
              const SizedBox(height: 16),
              _chargementReferences ? _carteChargement() : _carteSelecteurs(),
              const SizedBox(height: 24),
              Text(
                'MES SAISIES EN COURS',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _indigo, letterSpacing: 0.4),
              ),
              const SizedBox(height: 10),
              if (_chargementProgressions)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(child: CircularProgressIndicator(color: _indigo)),
                )
              else if (_progressions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text('Aucune saisie en cours', style: GoogleFonts.inter(color: _gris)),
                )
              else
                ..._progressions.map(_carteProgression),
            ],
          ),
        ),
      ),
    );
  }

  Widget _enTete() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_indigo, _teal], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Saisie des notes', style: GoogleFonts.sora(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 4),
          Text(
            'Choisissez une classe et une matière pour commencer',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  Widget _carteChargement() {
    return _carteGlass(
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(color: _indigo)),
      ),
    );
  }

  Widget _carteSelecteurs() {
    final classes = _classesDisponibles;
    final matieres = _matieresDisponibles;
    final peutDemarrer = _classeId != null && _matiereId != null && _periodeId != null;

    return _carteGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _selecteur<int>(
            label: 'Année scolaire',
            icone: Icons.calendar_today_outlined,
            valeur: _anneeId,
            actif: true,
            items: _annees
                .map((a) => DropdownMenuItem<int>(value: a['id'] as int, child: Text(a['libelle'] as String)))
                .toList(),
            onChanged: (v) {
              setState(() {
                _anneeId = v;
                _classeId = null;
                _matiereId = null;
              });
              if (v != null) _chargerPeriodes(v);
            },
          ),
          const SizedBox(height: 12),
          _selecteur<int>(
            label: 'Période',
            icone: Icons.event_note_outlined,
            valeur: _periodeId,
            actif: _anneeId != null && !_chargementPeriodes,
            items: _periodes
                .map((p) => DropdownMenuItem<int>(value: p['id'] as int, child: Text(p['nom'] as String)))
                .toList(),
            onChanged: (v) => setState(() => _periodeId = v),
          ),
          const SizedBox(height: 12),
          _selecteur<int>(
            label: 'Classe',
            icone: Icons.class_outlined,
            valeur: _classeId,
            actif: _periodeId != null && classes.isNotEmpty,
            hintVide: classes.isEmpty ? 'Aucune classe affectée' : null,
            items: classes.map((c) => DropdownMenuItem<int>(value: c['id'] as int, child: Text(c['nom'] as String))).toList(),
            onChanged: (v) => setState(() {
              _classeId = v;
              _matiereId = null;
            }),
          ),
          const SizedBox(height: 12),
          _selecteur<int>(
            label: 'Matière',
            icone: Icons.menu_book_outlined,
            valeur: _matiereId,
            actif: _classeId != null && matieres.isNotEmpty,
            hintVide: _classeId != null && matieres.isEmpty ? 'Aucune matière affectée' : null,
            items: matieres.map((m) => DropdownMenuItem<int>(value: m['id'] as int, child: Text(m['nom'] as String))).toList(),
            onChanged: (v) => setState(() => _matiereId = v),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: peutDemarrer && !_demarrageEnCours ? _demarrerSaisie : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: _demarrageEnCours
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.edit_note),
              label: Text(_demarrageEnCours ? 'Ouverture...' : 'Commencer / Continuer la saisie'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _selecteur<T>({
    required String label,
    required IconData icone,
    required T? valeur,
    required bool actif,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String? hintVide,
  }) {
    return Opacity(
      opacity: actif ? 1 : 0.5,
      child: DropdownButtonFormField<T>(
        initialValue: valeur,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icone, color: _indigo, size: 20),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        hint: Text(hintVide ?? 'Choisir', style: GoogleFonts.inter(fontSize: 13, color: _gris)),
        items: actif ? items : [],
        onChanged: actif ? onChanged : null,
      ),
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

  // ══════════════════════════════════════════════════════
  // CARTE PROGRESSION
  // ══════════════════════════════════════════════════════

  Widget _carteProgression(SaisieNote saisie) {
    final couleur = _couleurStatut(saisie.statut);
    final pourcentage = (saisie.pourcentageCompletion ?? 0) / 100;

    return GestureDetector(
      onTap: () => _ouvrirSaisie(saisie),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: couleur, width: 4)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
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
                      Text(
                        saisie.classeNom ?? 'Classe',
                        style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: _texteFonce),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${saisie.matiereNom ?? ''} · ${saisie.periodeNom ?? ''}',
                        style: GoogleFonts.inter(fontSize: 12, color: _texte),
                      ),
                    ],
                  ),
                ),
                _badge(saisie.statut.libelle, couleur),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pourcentage.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: const Color(0xFFF1F5F9),
                color: couleur,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(saisie.pourcentageCompletion ?? 0).toStringAsFixed(0)}% complété',
              style: GoogleFonts.jetBrainsMono(fontSize: 11, color: _texte),
            ),
          ],
        ),
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
