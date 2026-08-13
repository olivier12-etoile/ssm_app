import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/analyse_performance_model.dart';
import '../../services/validation_note_service.dart';
import '../../services/annee_service.dart';
import '../../services/classe_service.dart';
import 'analyse_performance_screen.dart';
import 'validation_notes_screen.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _teal = Color(0xFF0D9488);
const Color _ambre = Color(0xFFD97706);
const Color _vert = Color(0xFF16A34A);
const Color _rouge = Color(0xFFDC2626);
const Color _gris = Color(0xFF94A3B8);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);

// Ligne de progression d'un enseignant sur une matière/classe, construite en
// combinant matieres-non-validees (toujours disponible) et
// enseignants-en-retard (pourcentage réel, mais seulement une fois la
// période dépassée — voir _chargerProgressionEnseignants).
class _LigneProgression {
  final String enseignant;
  final String classe;
  final String matiere;
  final String statut;
  final double? pourcentage;

  _LigneProgression({
    required this.enseignant,
    required this.classe,
    required this.matiere,
    required this.statut,
    this.pourcentage,
  });
}

String _libelleStatutSaisie(String statut) {
  switch (statut) {
    case 'en_cours':
      return 'En cours';
    case 'en_attente_validation':
      return 'En attente';
    case 'rejetee':
      return 'Rejetée';
    default:
      return statut;
  }
}

Color _couleurStatutSaisie(String statut) {
  switch (statut) {
    case 'en_attente_validation':
      return _ambre;
    case 'rejetee':
      return _rouge;
    default:
      return _indigo;
  }
}

class DashboardNotesScreen extends StatefulWidget {
  const DashboardNotesScreen({super.key});

  @override
  State<DashboardNotesScreen> createState() => _DashboardNotesScreenState();
}

class _DashboardNotesScreenState extends State<DashboardNotesScreen> {
  List<dynamic> _periodes = [];
  int? _periodeId;

  ResumeAnalyse? _resume;
  List<ClasseMatieresNonValidees> _matieresNonValidees = [];
  List<_LigneProgression> _progressionEnseignants = [];
  int _totalClasses = 0;

  bool _chargementPeriodes = true;
  bool _chargementDonnees = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _chargerPeriodes();
  }

  Future<void> _chargerPeriodes() async {
    setState(() => _chargementPeriodes = true);
    try {
      // La réponse de /annees/active est enveloppée : {annee, periode_active,
      // jours_restants_periode, alertes} — pas directement l'année elle-même.
      final anneeActiveData = await AnneeService.anneeActive();
      final anneeId = (anneeActiveData['annee'] as Map<String, dynamic>?)?['id'] as int?;
      if (anneeId == null) {
        setState(() => _chargementPeriodes = false);
        return;
      }

      final periodes = await AnneeService.listerPeriodes(anneeId);
      final periodeActiveId = (anneeActiveData['periode_active'] as Map<String, dynamic>?)?['id'] as int?;

      setState(() {
        _periodes = periodes;
        _periodeId = periodeActiveId ?? (periodes.isNotEmpty ? periodes.first['id'] as int : null);
        _chargementPeriodes = false;
      });

      if (_periodeId != null) await _chargerDonnees();
    } catch (e) {
      setState(() => _chargementPeriodes = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _chargerDonnees() async {
    if (_periodeId == null) return;

    setState(() {
      _chargementDonnees = true;
      _erreur = null;
    });
    try {
      final resultats = await Future.wait([
        ValidationNoteService.getResumeAnalyse(_periodeId!),
        ValidationNoteService.getMatieresNonValidees(_periodeId!),
        ValidationNoteService.getEnseignantsEnRetard(_periodeId!),
        ClasseService.listerClasses(),
      ]);

      final resume = resultats[0] as ResumeAnalyse;
      final matieresNonValidees = resultats[1] as List<ClasseMatieresNonValidees>;
      final enseignantsEnRetard = resultats[2] as List<EnseignantRetard>;
      final classes = resultats[3] as List<dynamic>;

      setState(() {
        _resume = resume;
        _matieresNonValidees = matieresNonValidees;
        _totalClasses = classes.length;
        _progressionEnseignants = _construireProgression(matieresNonValidees, enseignantsEnRetard);
        _chargementDonnees = false;
      });
    } catch (e) {
      setState(() {
        _chargementDonnees = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  List<_LigneProgression> _construireProgression(
    List<ClasseMatieresNonValidees> matieresNonValidees,
    List<EnseignantRetard> enseignantsEnRetard,
  ) {
    final lignes = <_LigneProgression>[];
    for (final classe in matieresNonValidees) {
      for (final m in classe.matieres) {
        final retard = enseignantsEnRetard.where(
          (e) => e.classe == classe.classeNom && e.matiere == m.matiereNom && e.nom == m.enseignantNom,
        );
        lignes.add(_LigneProgression(
          enseignant: m.enseignantNom,
          classe: classe.classeNom,
          matiere: m.matiereNom,
          statut: m.statut,
          pourcentage: retard.isNotEmpty ? retard.first.pourcentageCompletion : null,
        ));
      }
    }
    lignes.sort((a, b) => a.enseignant.compareTo(b.enseignant));
    return lignes;
  }

  void _afficherErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: _rouge),
    );
  }

  int get _nombreMatieresEnAttente =>
      _matieresNonValidees.fold(0, (s, c) => s + c.matieres.where((m) => m.statut == 'en_attente_validation').length);

  int get _nombreMatieresEnCours =>
      _matieresNonValidees.fold(0, (s, c) => s + c.matieres.where((m) => m.statut != 'en_attente_validation').length);

  double get _tauxGlobalProgression {
    if (_totalClasses == 0 || _resume == null) return 0;
    final complet = _totalClasses - _resume!.nombreClassesIncompletes;
    return (complet / _totalClasses * 100).clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _chargerDonnees,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              _enTete(),
              const SizedBox(height: 16),
              _selecteurPeriode(),
              const SizedBox(height: 16),
              if (_chargementDonnees)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator(color: _indigo)),
                )
              else if (_erreur != null)
                _vueErreur()
              else if (_resume != null) ...[
                _carteTauxProgression(),
                const SizedBox(height: 16),
                _grilleResume(),
                const SizedBox(height: 20),
                _boutonAnalyse(),
                const SizedBox(height: 20),
                Text(
                  'PROGRESSION PAR ENSEIGNANT',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _indigo, letterSpacing: 0.4),
                ),
                const SizedBox(height: 10),
                if (_progressionEnseignants.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('Toutes les matières sont validées pour cette période.', style: GoogleFonts.inter(color: _vert)),
                  )
                else
                  ..._progressionEnseignants.map(_carteProgressionEnseignant),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _vueErreur() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: _rouge, size: 36),
          const SizedBox(height: 10),
          Text(_erreur!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: _texte)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _chargerDonnees,
            style: ElevatedButton.styleFrom(backgroundColor: _indigo, foregroundColor: Colors.white),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // EN-TÊTE + SÉLECTEUR DE PÉRIODE
  // ══════════════════════════════════════════════════════

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
          Text('Notes & Évaluations', style: GoogleFonts.sora(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 4),
          Text(
            'Suivi académique de l\'établissement',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  Widget _selecteurPeriode() {
    if (_chargementPeriodes) {
      return const Center(child: CircularProgressIndicator(color: _indigo));
    }
    if (_periodes.isEmpty) {
      return Text('Aucune période disponible', style: GoogleFonts.inter(color: _gris));
    }

    return DropdownButtonFormField<int>(
      initialValue: _periodeId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Période',
        prefixIcon: Icon(Icons.event_note_outlined, color: _indigo),
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
      items: _periodes.map((p) => DropdownMenuItem<int>(value: p['id'] as int, child: Text(p['nom'] as String))).toList(),
      onChanged: (v) {
        setState(() => _periodeId = v);
        if (v != null) _chargerDonnees();
      },
    );
  }

  // ══════════════════════════════════════════════════════
  // TAUX GLOBAL DE PROGRESSION
  // ══════════════════════════════════════════════════════

  Widget _carteTauxProgression() {
    final taux = _tauxGlobalProgression;
    final couleur = taux >= 80 ? _vert : (taux >= 50 ? _ambre : _rouge);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Taux global de progression', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: _texteFonce)),
              Text('${taux.toStringAsFixed(0)}%', style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.w700, color: couleur)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: taux / 100, minHeight: 10, backgroundColor: const Color(0xFFF1F5F9), color: couleur),
          ),
          const SizedBox(height: 6),
          Text(
            '${_totalClasses - (_resume?.nombreClassesIncompletes ?? 0)} / $_totalClasses classes ont toutes leurs matières validées',
            style: GoogleFonts.inter(fontSize: 11, color: _gris),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // GRILLE RÉSUMÉ
  // ══════════════════════════════════════════════════════

  Widget _grilleResume() {
    final r = _resume!;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: [
        _carteStat('Classes incomplètes', '${r.nombreClassesIncompletes}', Icons.class_outlined, _rouge),
        _carteStat('Matières en attente', '$_nombreMatieresEnAttente', Icons.hourglass_bottom, _ambre),
        _carteStat('Matières en cours', '$_nombreMatieresEnCours', Icons.edit_note, _indigo),
        _carteStat('Enseignants en retard', '${r.nombreEnseignantsEnRetard}', Icons.person_off_outlined, _rouge),
        _carteStat('Élèves en difficulté', '${r.nombreElevesFaibles}', Icons.trending_down, _rouge),
        _carteStat('Élèves excellents', '${r.nombreElevesExcellents}', Icons.star_outline, _vert),
      ],
    );
  }

  Widget _carteStat(String titre, String valeur, IconData icone, Color couleur) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: couleur.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(icone, color: couleur, size: 16),
          ),
          const Spacer(),
          Text(valeur, style: GoogleFonts.jetBrainsMono(fontSize: 20, fontWeight: FontWeight.w700, color: _texteFonce)),
          Text(titre, style: GoogleFonts.inter(fontSize: 10, color: _gris), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _boutonAnalyse() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _periodeId == null
            ? null
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AnalysePerformanceScreen(periodeId: _periodeId!)),
                ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _indigo,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        icon: const Icon(Icons.insights),
        label: const Text('Analyse des performances'),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // PROGRESSION PAR ENSEIGNANT
  // ══════════════════════════════════════════════════════

  Widget _carteProgressionEnseignant(_LigneProgression ligne) {
    final couleur = _couleurStatutSaisie(ligne.statut);

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ValidationNotesScreen())),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${ligne.enseignant} — ${ligne.matiere} (${ligne.classe})',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _texteFonce),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _badge(_libelleStatutSaisie(ligne.statut), couleur),
              ],
            ),
            if (ligne.pourcentage != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (ligne.pourcentage! / 100).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: const Color(0xFFF1F5F9),
                  color: couleur,
                ),
              ),
              const SizedBox(height: 4),
              Text('${ligne.pourcentage!.toStringAsFixed(0)}% complété', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: _gris)),
            ],
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
