import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/analyse_performance_model.dart';
import '../../services/validation_note_service.dart';
import '../../services/annee_service.dart';
import '../../services/classe_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_panel.dart';
import '../../widgets/ssm/ssm_pill.dart';
import '../../widgets/ssm/ssm_stat_card.dart';
import 'analyse_performance_screen.dart';
import 'validation_notes_screen.dart';

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
      return SSMPalette.ambre;
    case 'rejetee':
      return SSMPalette.rouge;
    default:
      return SSMPalette.indigo;
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
      SnackBar(content: Text(message), backgroundColor: SSMPalette.rouge),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _selecteurPeriode(),
        const SizedBox(height: 16),
        if (_chargementDonnees)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator(color: SSMPalette.indigo)),
          )
        else if (_erreur != null)
          _vueErreur()
        else if (_resume != null) ...[
          _carteTauxProgression(),
          const SizedBox(height: 16),
          _grilleResume(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _periodeId == null
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AnalysePerformanceScreen(periodeId: _periodeId!)),
                      ),
              style: ElevatedButton.styleFrom(
                backgroundColor: SSMPalette.indigo,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
              ),
              icon: const Icon(Icons.insights),
              label: const Text('Analyse des performances'),
            ),
          ),
          const SizedBox(height: 20),
          _panelProgressionEnseignants(),
        ],
      ],
    );
  }

  Widget _vueErreur() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: SSMPalette.rouge, size: 36),
          const SizedBox(height: 10),
          Text(_erreur!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: SSMPalette.texte2)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _chargerDonnees,
            style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.indigo, foregroundColor: Colors.white, elevation: 0),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // SÉLECTEUR DE PÉRIODE
  // ══════════════════════════════════════════════════════

  Widget _selecteurPeriode() {
    if (_chargementPeriodes) {
      return const Center(child: CircularProgressIndicator(color: SSMPalette.indigo));
    }
    if (_periodes.isEmpty) {
      return Text('Aucune période disponible', style: GoogleFonts.inter(color: SSMPalette.texte3));
    }

    return DropdownButtonFormField<int>(
      initialValue: _periodeId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Période',
        labelStyle: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2),
        prefixIcon: const Icon(Icons.event_note_outlined, color: SSMPalette.indigo),
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
    final couleur = taux >= 80 ? SSMPalette.teal : (taux >= 50 ? SSMPalette.ambre : SSMPalette.rouge);

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Taux global de progression', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
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
            style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte3),
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
    final cartes = <Widget>[
      SSMStatCard(icone: Icons.class_outlined, couleur: SSMPalette.rouge, valeur: '${r.nombreClassesIncompletes}', label: 'Classes incomplètes'),
      SSMStatCard(icone: Icons.hourglass_bottom, couleur: SSMPalette.ambre, valeur: '$_nombreMatieresEnAttente', label: 'Matières en attente'),
      SSMStatCard(icone: Icons.edit_note, couleur: SSMPalette.indigo, valeur: '$_nombreMatieresEnCours', label: 'Matières en cours'),
      SSMStatCard(icone: Icons.person_off_outlined, couleur: SSMPalette.rouge, valeur: '${r.nombreEnseignantsEnRetard}', label: 'Enseignants en retard'),
      SSMStatCard(icone: Icons.trending_down, couleur: SSMPalette.rouge, valeur: '${r.nombreElevesFaibles}', label: 'Élèves en difficulté'),
      SSMStatCard(icone: Icons.star_outline, couleur: SSMPalette.teal, valeur: '${r.nombreElevesExcellents}', label: 'Élèves excellents'),
    ];

    return LayoutBuilder(builder: (context, contraintes) {
      final colonnes = contraintes.maxWidth >= 760 ? 3 : (contraintes.maxWidth >= 520 ? 2 : 1);
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: cartes.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: colonnes,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 168,
        ),
        itemBuilder: (context, i) => cartes[i],
      );
    });
  }

  // ══════════════════════════════════════════════════════
  // PROGRESSION PAR ENSEIGNANT
  // ══════════════════════════════════════════════════════

  Widget _panelProgressionEnseignants() {
    return SSMPanel(
      titre: 'Progression par enseignant',
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: _progressionEnseignants.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Toutes les matières sont validées pour cette période.', style: GoogleFonts.inter(color: SSMPalette.teal)),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < _progressionEnseignants.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _carteProgressionEnseignant(_progressionEnseignants[i]),
                ],
              ],
            ),
    );
  }

  Widget _carteProgressionEnseignant(_LigneProgression ligne) {
    final couleur = _couleurStatutSaisie(ligne.statut);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(SSMRayons.grand),
      child: InkWell(
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ValidationNotesScreen())),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SSMRayons.grand),
            border: Border.all(color: SSMPalette.bordure),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${ligne.enseignant} — ${ligne.matiere} (${ligne.classe})',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: SSMPalette.texte1),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SSMPill.couleur(label: _libelleStatutSaisie(ligne.statut), couleur: couleur),
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
                Text('${ligne.pourcentage!.toStringAsFixed(0)}% complété', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: SSMPalette.texte3)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
