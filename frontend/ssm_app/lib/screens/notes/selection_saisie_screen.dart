import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/note_model.dart';
import '../../services/note_service.dart';
import '../../services/annee_service.dart';
import '../../services/affectation_service.dart';
import '../../services/auth_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_panel.dart';
import '../../widgets/ssm/ssm_pill.dart';
import 'saisie_notes_screen.dart';

Color _couleurStatut(StatutSaisie statut) {
  switch (statut) {
    case StatutSaisie.enCours:
      return SSMPalette.indigo;
    case StatutSaisie.terminee:
      return SSMPalette.teal;
    case StatutSaisie.enAttenteValidation:
      return SSMPalette.ambre;
    case StatutSaisie.validee:
      return SSMPalette.teal;
    case StatutSaisie.rejetee:
      return SSMPalette.rouge;
  }
}

class SelectionSaisieScreen extends StatefulWidget {
  // À false quand cet écran est embarqué dans notes_module_screen.dart : le
  // conteneur (ssm_page_scaffold) fournit déjà navigation et titre de page.
  final bool independant;

  const SelectionSaisieScreen({super.key, this.independant = true});

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
      SnackBar(content: Text(message), backgroundColor: SSMPalette.rouge),
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
    // Embarqué dans notes_module_screen.dart : celui-ci défile déjà toute la
    // page dans un SingleChildScrollView (hauteur non bornée) — un ListView
    // ou un Expanded planterait ici. On rend donc un contenu "plat" (Column)
    // sans scroll ni RefreshIndicator propres.
    if (!widget.independant) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _chargementReferences ? _carteChargement() : _carteSelecteurs(),
          const SizedBox(height: 20),
          _panelSaisiesEnCours(),
        ],
      );
    }

    return Scaffold(
      backgroundColor: SSMPalette.fond,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([_chargerReferences(), _chargerProgressions()]);
          },
          color: SSMPalette.indigo,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text('Saisie des notes', style: GoogleFonts.sora(fontSize: 19, fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
              const SizedBox(height: 3),
              Text(
                'Choisissez une classe et une matière pour commencer',
                style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2),
              ),
              const SizedBox(height: 16),
              _chargementReferences ? _carteChargement() : _carteSelecteurs(),
              const SizedBox(height: 20),
              _panelSaisiesEnCours(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _panelSaisiesEnCours() {
    return SSMPanel(
      titre: 'Mes saisies en cours',
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: _chargementProgressions
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: CircularProgressIndicator(color: SSMPalette.indigo)),
            )
          : _progressions.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text('Aucune saisie en cours', style: GoogleFonts.inter(color: SSMPalette.texte3)),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < _progressions.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      _carteProgression(_progressions[i]),
                    ],
                  ],
                ),
    );
  }

  Widget _carteChargement() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: SSMPalette.blanc,
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        border: Border.all(color: SSMPalette.bordure),
      ),
      child: const Center(child: CircularProgressIndicator(color: SSMPalette.indigo)),
    );
  }

  Widget _carteSelecteurs() {
    final classes = _classesDisponibles;
    final matieres = _matieresDisponibles;
    final peutDemarrer = _classeId != null && _matiereId != null && _periodeId != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SSMPalette.blanc,
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        border: Border.all(color: SSMPalette.bordure),
      ),
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
                backgroundColor: SSMPalette.indigo,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
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
          labelStyle: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2),
          prefixIcon: Icon(icone, color: SSMPalette.indigo, size: 20),
          isDense: true,
          filled: true,
          fillColor: const Color(0xFFF9FAFB),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SSMRayons.moyen),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SSMRayons.moyen),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SSMRayons.moyen),
            borderSide: const BorderSide(color: SSMPalette.indigo, width: 1.5),
          ),
        ),
        hint: Text(hintVide ?? 'Choisir', style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte3)),
        items: actif ? items : [],
        onChanged: actif ? onChanged : null,
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // CARTE PROGRESSION
  // ══════════════════════════════════════════════════════

  Widget _carteProgression(SaisieNote saisie) {
    final couleur = _couleurStatut(saisie.statut);
    final pourcentage = (saisie.pourcentageCompletion ?? 0) / 100;

    return Material(
      color: SSMPalette.blanc,
      borderRadius: BorderRadius.circular(SSMRayons.grand),
      child: InkWell(
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        onTap: () => _ouvrirSaisie(saisie),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SSMRayons.grand),
            border: Border(
              top: BorderSide(color: SSMPalette.bordure),
              right: BorderSide(color: SSMPalette.bordure),
              bottom: BorderSide(color: SSMPalette.bordure),
              left: BorderSide(color: couleur, width: 3),
            ),
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
                          style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: SSMPalette.texte1),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${saisie.matiereNom ?? ''} · ${saisie.periodeNom ?? ''}',
                          style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2),
                        ),
                      ],
                    ),
                  ),
                  SSMPill.couleur(label: saisie.statut.libelle, couleur: couleur),
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
                style: GoogleFonts.jetBrainsMono(fontSize: 11, color: SSMPalette.texte2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
