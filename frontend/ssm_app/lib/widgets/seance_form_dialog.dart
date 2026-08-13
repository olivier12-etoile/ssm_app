import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/emploi_du_temps_model.dart';
import '../services/emploi_du_temps_service.dart';
import '../services/classe_matiere_service.dart';
import '../services/affectation_service.dart';
import 'grille_emploi_du_temps_widget.dart' show couleurDepuisHex;

const List<Color> _couleursDisponibles = [
  Color(0xFF1E3A8A), // Indigo
  Color(0xFF0D9488), // Teal
  Color(0xFFD97706), // Ambre
  Color(0xFF16A34A), // Vert
  Color(0xFFDC2626), // Rouge
  Color(0xFFEA580C), // Orange
  Color(0xFF7C3AED), // Violet
  Color(0xFFDB2777), // Rose
  Color(0xFF0891B2), // Cyan
  Color(0xFF65A30D), // Lime
];

const Color _couleurParDefaut = Color(0xFF1E3A8A);

// ══════════════════════════════════════════════════════════
// SeanceFormDialog — création / modification d'une séance sur un
// créneau + jour donnés. Affiche les conflits renvoyés par le backend
// (422) sans fermer le dialog, pour que l'utilisateur puisse corriger.
// ══════════════════════════════════════════════════════════
class SeanceFormDialog extends StatefulWidget {
  final int classeId;
  final int emploiDuTempsId;
  final JourSemaine jour;
  final CreneauHoraire creneau;
  final Seance? seanceExistante;

  const SeanceFormDialog({
    super.key,
    required this.classeId,
    required this.emploiDuTempsId,
    required this.jour,
    required this.creneau,
    this.seanceExistante,
  });

  // Renvoie true si une séance a été créée, modifiée ou supprimée
  // (l'appelant doit alors recharger la grille), null sinon.
  static Future<bool?> afficher(
    BuildContext context, {
    required int classeId,
    required int emploiDuTempsId,
    required JourSemaine jour,
    required CreneauHoraire creneau,
    Seance? seanceExistante,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => SeanceFormDialog(
        classeId: classeId,
        emploiDuTempsId: emploiDuTempsId,
        jour: jour,
        creneau: creneau,
        seanceExistante: seanceExistante,
      ),
    );
  }

  @override
  State<SeanceFormDialog> createState() => _SeanceFormDialogState();
}

class _SeanceFormDialogState extends State<SeanceFormDialog> {
  late final TextEditingController _salleController;

  List<Map<String, dynamic>> _matieresClasse = [];
  List<Map<String, dynamic>> _enseignants = [];

  int? _matiereSelectionneeId;
  int? _enseignantSelectionneId;
  Color _couleurSelectionnee = _couleurParDefaut;
  bool _couleurModifieeManuellement = false;

  bool _chargementListes = true;
  bool _chargementEnseignants = false;
  bool _enregistrement = false;
  bool _suppression = false;
  String? _erreurChargement;
  List<ConflitDetecte> _conflits = [];

  bool get _estModification => widget.seanceExistante != null;

  @override
  void initState() {
    super.initState();
    _matiereSelectionneeId = widget.seanceExistante?.matiereId;
    _enseignantSelectionneId = widget.seanceExistante?.enseignantId;
    _salleController = TextEditingController(text: widget.seanceExistante?.salle ?? '');
    if (widget.seanceExistante?.couleur != null) {
      _couleurSelectionnee = couleurDepuisHex(widget.seanceExistante!.couleur);
      _couleurModifieeManuellement = true;
    }
    _chargerDonnees();
  }

  @override
  void dispose() {
    _salleController.dispose();
    super.dispose();
  }

  Future<void> _chargerDonnees() async {
    setState(() {
      _chargementListes = true;
      _erreurChargement = null;
    });
    try {
      final matieres = (await ClasseMatiereService.listerParClasse(widget.classeId))
          .map((m) => m as Map<String, dynamic>)
          .toList();

      // Garantit que la matière actuelle de la séance modifiée reste
      // sélectionnable même si elle a été retirée entre-temps de la classe.
      final seanceExistante = widget.seanceExistante;
      if (seanceExistante != null && !matieres.any((m) => m['matiere_id'] == seanceExistante.matiereId)) {
        matieres.add({
          'matiere_id': seanceExistante.matiereId,
          'matiere_nom': seanceExistante.nomMatiere ?? 'Matière',
          'matiere_couleur': seanceExistante.couleur,
        });
      }

      setState(() {
        _matieresClasse = matieres;
        _chargementListes = false;
      });

      if (_matiereSelectionneeId != null) {
        await _chargerEnseignants(_matiereSelectionneeId, conserverSelection: true);
      }
    } catch (e) {
      setState(() {
        _chargementListes = false;
        _erreurChargement = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _chargerEnseignants(int? matiereId, {bool conserverSelection = false}) async {
    if (matiereId == null) {
      setState(() {
        _enseignants = [];
        if (!conserverSelection) _enseignantSelectionneId = null;
      });
      return;
    }

    setState(() => _chargementEnseignants = true);
    try {
      var enseignants = _normaliserEnseignants(
        await AffectationService.listerParClasse(widget.classeId, matiereId: matiereId),
        depuisAffectations: true,
      );

      // Aucun enseignant encore affecté à cette matière pour cette classe :
      // on retombe sur la liste complète des enseignants de l'école.
      if (enseignants.isEmpty) {
        enseignants = _normaliserEnseignants(
          await AffectationService.listerEnseignants(),
          depuisAffectations: false,
        );
      }

      final seanceExistante = widget.seanceExistante;
      if (conserverSelection &&
          seanceExistante != null &&
          !enseignants.any((e) => e['id'] == seanceExistante.enseignantId)) {
        enseignants.add({
          'id': seanceExistante.enseignantId,
          'nom': seanceExistante.nomEnseignant ?? 'Enseignant',
        });
      }

      setState(() {
        _enseignants = enseignants;
        _chargementEnseignants = false;
        if (!conserverSelection) _enseignantSelectionneId = null;
      });
    } catch (e) {
      setState(() => _chargementEnseignants = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  List<Map<String, dynamic>> _normaliserEnseignants(List<dynamic> brut, {required bool depuisAffectations}) {
    return brut.map((e) {
      final m = e as Map<String, dynamic>;
      return {
        'id': (depuisAffectations ? m['enseignant_id'] : m['id']) as int,
        // Le modèle User (Laravel) porte la colonne "name".
        'nom': (depuisAffectations ? m['enseignant_nom'] : m['name']) as String,
      };
    }).toList();
  }

  void _onMatiereChangee(int? matiereId) {
    setState(() => _matiereSelectionneeId = matiereId);

    if (!_couleurModifieeManuellement && matiereId != null) {
      final matiere = _matieresClasse.firstWhere(
        (m) => m['matiere_id'] == matiereId,
        orElse: () => <String, dynamic>{},
      );
      final couleurMatiere = matiere['matiere_couleur'] as String?;
      if (couleurMatiere != null && couleurMatiere.isNotEmpty) {
        setState(() => _couleurSelectionnee = couleurDepuisHex(couleurMatiere));
      }
    }

    _chargerEnseignants(matiereId);
  }

  Future<void> _enregistrer() async {
    if (_matiereSelectionneeId == null || _enseignantSelectionneId == null) {
      _afficherErreur('Sélectionnez une matière et un enseignant.');
      return;
    }

    setState(() {
      _enregistrement = true;
      _conflits = [];
    });

    final matiere = _matieresClasse.firstWhere((m) => m['matiere_id'] == _matiereSelectionneeId);
    final enseignant = _enseignants.firstWhere((e) => e['id'] == _enseignantSelectionneId);
    final couleurHex =
        '#${_couleurSelectionnee.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

    final seance = Seance(
      id: widget.seanceExistante?.id,
      creneauHoraireId: widget.creneau.id!,
      jour: widget.jour.valeurApi,
      matiereId: _matiereSelectionneeId!,
      nomMatiere: matiere['matiere_nom'] as String?,
      enseignantId: _enseignantSelectionneId!,
      nomEnseignant: enseignant['nom'] as String?,
      salle: _salleController.text.trim().isEmpty ? null : _salleController.text.trim(),
      couleur: couleurHex,
    );

    try {
      if (_estModification) {
        await EmploiDuTempsService.modifierSeance(widget.seanceExistante!.id!, seance);
      } else {
        await EmploiDuTempsService.creerSeance(seance, emploiDuTempsId: widget.emploiDuTempsId);
      }
      if (mounted) Navigator.pop(context, true);
    } on ConflitEmploiDuTempsException catch (e) {
      setState(() {
        _conflits = e.conflits;
        _enregistrement = false;
      });
    } catch (e) {
      setState(() => _enregistrement = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _supprimer() async {
    final confirme = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Supprimer cette séance ?'),
            content: Text(
              '${widget.seanceExistante?.nomMatiere ?? 'Cette séance'} sera retirée '
              'de l\'emploi du temps du ${widget.jour.libelle.toLowerCase()}.',
              style: GoogleFonts.inter(fontSize: 13),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Supprimer'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirme) return;

    setState(() => _suppression = true);
    try {
      await EmploiDuTempsService.supprimerSeance(widget.seanceExistante!.id!);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _suppression = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _afficherErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFFDC2626)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _estModification ? 'Modifier la séance' : 'Nouvelle séance',
                style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 16),
              _enteteContexte(),
              const SizedBox(height: 16),
              Flexible(child: SingleChildScrollView(child: _corps())),
              if (_conflits.isNotEmpty) ...[
                const SizedBox(height: 14),
                _blocConflits(),
              ],
              const SizedBox(height: 20),
              if (_estModification) ...[
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: _suppression ? null : _supprimer,
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                    icon: _suppression
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Supprimer cette séance'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler'))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: (_chargementListes || _enregistrement) ? null : _enregistrer,
                      child: _enregistrement
                          ? const SizedBox(
                              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_estModification ? 'Enregistrer' : 'Créer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _enteteContexte() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          const Icon(Icons.schedule, size: 16, color: Color(0xFF1E3A8A)),
          const SizedBox(width: 8),
          Text(
            '${widget.jour.libelle} — ${widget.creneau.heureDebut} - ${widget.creneau.heureFin}',
            style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
          ),
        ],
      ),
    );
  }

  Widget _corps() {
    if (_chargementListes) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A))),
      );
    }

    if (_erreurChargement != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Text(_erreurChargement!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: const Color(0xFF334155))),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: _chargerDonnees, child: const Text('Réessayer')),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<int>(
          value: _matiereSelectionneeId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Matière *',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          hint: const Text('Choisir une matière'),
          items: _matieresClasse
              .map((m) => DropdownMenuItem<int>(
                    value: m['matiere_id'] as int,
                    child: Text(m['matiere_nom'] as String? ?? '', style: GoogleFonts.inter(fontSize: 14)),
                  ))
              .toList(),
          onChanged: _onMatiereChangee,
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<int>(
          value: _enseignants.any((e) => e['id'] == _enseignantSelectionneId) ? _enseignantSelectionneId : null,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Enseignant *',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            suffixIcon: _chargementEnseignants
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : null,
          ),
          hint: Text(_matiereSelectionneeId == null ? 'Choisir d\'abord une matière' : 'Choisir un enseignant'),
          items: _enseignants
              .map((e) => DropdownMenuItem<int>(
                    value: e['id'] as int,
                    child: Text(e['nom'] as String? ?? '', style: GoogleFonts.inter(fontSize: 14)),
                  ))
              .toList(),
          onChanged: (_matiereSelectionneeId == null || _chargementEnseignants)
              ? null
              : (id) => setState(() => _enseignantSelectionneId = id),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _salleController,
          decoration: InputDecoration(
            labelText: 'Salle (optionnel)',
            hintText: 'ex: Salle 12',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          style: GoogleFonts.inter(fontSize: 14),
        ),
        const SizedBox(height: 16),
        Text('Couleur d\'identification', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF334155))),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _couleursDisponibles.map((c) {
            final selectionnee = c.toARGB32() == _couleurSelectionnee.toARGB32();
            return GestureDetector(
              onTap: () => setState(() {
                _couleurSelectionnee = c;
                _couleurModifieeManuellement = true;
              }),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: selectionnee ? Border.all(color: Colors.white, width: 2) : null,
                  boxShadow: selectionnee
                      ? [BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 6, offset: const Offset(0, 2))]
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _blocConflits() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
              const SizedBox(width: 6),
              Text('Conflit détecté', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFFDC2626))),
            ],
          ),
          const SizedBox(height: 6),
          ..._conflits.map((c) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('• ${c.message}', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFDC2626))),
              )),
        ],
      ),
    );
  }
}
