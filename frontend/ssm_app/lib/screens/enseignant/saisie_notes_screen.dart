import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/affectation_service.dart';
import '../../services/annee_service.dart';
import '../../services/eleve_service.dart';
import '../../services/evaluation_service.dart';
import '../../services/note_service.dart';

class SaisieNotesScreen extends StatefulWidget {
  final int? classeIdPreselectionne;

  const SaisieNotesScreen({super.key, this.classeIdPreselectionne});

  @override
  State<SaisieNotesScreen> createState() => _SaisieNotesScreenState();
}

class _SaisieNotesScreenState extends State<SaisieNotesScreen> {
  // ── Niveau 1 : filtres ──────────────────────────────────
  int? _enseignantId;
  List<dynamic> _affectations = [];
  List<dynamic> _periodes = [];

  int? _classeId;
  int? _matiereId;
  int? _periodeId;

  bool _chargementFiltres = true;

  // ── Niveau 2/3 : tableau ────────────────────────────────
  List<dynamic> _eleves = [];
  List<dynamic> _evaluations = [];
  bool _chargementTableau = false;

  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _chargerFiltres();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _chargerFiltres() async {
    setState(() => _chargementFiltres = true);
    try {
      final utilisateur = await AuthService.getUtilisateur();
      _enseignantId = utilisateur!.id;

      final donneesAffectations =
          await AffectationService.listerAffectations(_enseignantId!);
      final annees = await AnneeService.listerAnnees();

      final periodesParAnnee = await Future.wait(
        annees.map((a) => AnneeService.listerPeriodes(a['id'] as int)),
      );

      final periodes = <dynamic>[];
      for (var i = 0; i < annees.length; i++) {
        for (final periode in periodesParAnnee[i]) {
          periodes.add({
            ...periode as Map<String, dynamic>,
            'annee_libelle': annees[i]['libelle'],
          });
        }
      }

      _affectations = donneesAffectations['affectations'] as List;

      final classePreselectionneeValide = widget.classeIdPreselectionne != null &&
          _affectations
              .any((a) => a['classe_id'] == widget.classeIdPreselectionne);

      setState(() {
        _periodes = periodes;
        if (classePreselectionneeValide) {
          _classeId = widget.classeIdPreselectionne;
        }
        _chargementFiltres = false;
      });
    } catch (e) {
      setState(() => _chargementFiltres = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  List<Map<String, dynamic>> get _classesDisponibles {
    final vues = <int>{};
    final liste = <Map<String, dynamic>>[];
    for (final a in _affectations) {
      final id = a['classe_id'] as int;
      if (vues.add(id)) {
        liste.add({'id': id, 'nom': a['classe_nom']});
      }
    }
    return liste;
  }

  List<Map<String, dynamic>> get _matieresDisponibles {
    if (_classeId == null) return [];
    final vues = <int>{};
    final liste = <Map<String, dynamic>>[];
    for (final a in _affectations) {
      if (a['classe_id'] != _classeId) continue;
      final id = a['matiere_id'] as int;
      if (vues.add(id)) {
        liste.add({'id': id, 'nom': a['matiere_nom']});
      }
    }
    return liste;
  }

  void _afficherErreur(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _afficherSucces(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green),
    );
  }

  String _cle(int eleveId, int evaluationId) => '${eleveId}_$evaluationId';

  List<dynamic> _trierEvaluations(List<dynamic> evaluations) {
    final devoirs = evaluations.where((e) => e['type'] == 'devoir').toList()
      ..sort((a, b) => (a['numero'] as int).compareTo(b['numero'] as int));
    final compositions =
        evaluations.where((e) => e['type'] == 'composition').toList()
          ..sort((a, b) => (a['numero'] as int).compareTo(b['numero'] as int));
    return [...devoirs, ...compositions];
  }

  void _reconstruireControleurs() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();

    for (final eleve in _eleves) {
      final eleveId = eleve['id'] as int;
      for (final evaluation in _evaluations) {
        final evaluationId = evaluation['id'] as int;
        final note = (evaluation['notes'] as List).firstWhere(
          (n) => n['eleve_id'] == eleveId,
          orElse: () => null,
        );
        _controllers[_cle(eleveId, evaluationId)] = TextEditingController(
          text: note != null ? note['valeur'].toString() : '',
        );
      }
    }
  }

  Future<void> _chargerTableau() async {
    if (_classeId == null || _matiereId == null || _periodeId == null) return;

    setState(() => _chargementTableau = true);

    try {
      final periode = _periodes.firstWhere((p) => p['id'] == _periodeId);
      final anneeId = periode['annee_academique_id'] as int;

      final resultats = await Future.wait([
        EleveService.elevesParClasse(_classeId!, anneeId),
        EvaluationService.listerEvaluations(
          classeId: _classeId!,
          matiereId: _matiereId!,
          periodeId: _periodeId!,
        ),
      ]);

      setState(() {
        _eleves = resultats[0];
        _evaluations = _trierEvaluations(resultats[1]);
        _reconstruireControleurs();
        _chargementTableau = false;
      });
    } catch (e) {
      setState(() => _chargementTableau = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _afficherDialogAjoutEvaluation(String type) async {
    final memeType =
        _evaluations.where((e) => e['type'] == type).length;
    final numeroParDefaut = type == 'devoir' ? memeType + 1 : 1;

    final numeroController =
        TextEditingController(text: numeroParDefaut.toString());
    final libelleController = TextEditingController(
      text: type == 'devoir' ? 'Devoir $numeroParDefaut' : 'Composition',
    );
    DateTime dateSelectionnee = DateTime.now();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(
              type == 'devoir' ? 'Ajouter un devoir' : 'Ajouter une composition',
            ),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: numeroController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Numéro',
                      prefixIcon: Icon(Icons.tag),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: libelleController,
                    decoration: const InputDecoration(
                      labelText: 'Libellé',
                      prefixIcon: Icon(Icons.label_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_month),
                    title: const Text('Date de l\'évaluation'),
                    subtitle: Text(_formatDate(dateSelectionnee)),
                    onTap: () async {
                      final choisie = await showDatePicker(
                        context: context,
                        initialDate: dateSelectionnee,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (choisie != null) {
                        setStateDialog(() => dateSelectionnee = choisie);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
                onPressed: libelleController.text.isEmpty
                    ? null
                    : () async {
                        try {
                          await EvaluationService.creerEvaluation(
                            classeId: _classeId!,
                            matiereId: _matiereId!,
                            periodeId: _periodeId!,
                            type: type,
                            numero: int.tryParse(numeroController.text) ??
                                numeroParDefaut,
                            libelle: libelleController.text,
                            dateEvaluation: _formatDate(dateSelectionnee),
                          );
                          Navigator.pop(context);
                          _afficherSucces('Évaluation créée avec succès');
                          _chargerTableau();
                        } catch (e) {
                          Navigator.pop(context);
                          _afficherErreur(
                              e.toString().replaceAll('Exception: ', ''));
                        }
                      },
                child: const Text('Créer'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _enregistrerColonne(int evaluationId) async {
    final notes = <Map<String, dynamic>>[];

    for (final eleve in _eleves) {
      final texte =
          _controllers[_cle(eleve['id'] as int, evaluationId)]?.text.trim() ??
              '';
      if (texte.isEmpty) continue;

      final valeur = double.tryParse(texte);
      if (valeur == null || valeur < 0 || valeur > 20) {
        _afficherErreur(
            'Note invalide pour ${eleve['nom']} ${eleve['prenom']} (0 à 20)');
        return;
      }
      notes.add({'eleve_id': eleve['id'], 'valeur': valeur});
    }

    if (notes.isEmpty) {
      _afficherErreur('Aucune note à enregistrer pour cette colonne');
      return;
    }

    try {
      await EvaluationService.saisirNotes(
        evaluationId: evaluationId,
        notes: notes,
      );
      _afficherSucces('Notes enregistrées');
      _chargerTableau();
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Map<String, double?> _moyennePourEleve(int eleveId) {
    final notesDevoirs = <double>[];
    double? noteComposition;

    for (final evaluation in _evaluations) {
      final note = (evaluation['notes'] as List).firstWhere(
        (n) => n['eleve_id'] == eleveId,
        orElse: () => null,
      );
      if (note == null) continue;

      final valeur = double.tryParse(note['valeur'].toString()) ?? 0;
      if (evaluation['type'] == 'devoir') {
        notesDevoirs.add(valeur);
      } else {
        noteComposition = valeur;
      }
    }

    final moyenneDevoirs = notesDevoirs.isEmpty
        ? null
        : notesDevoirs.reduce((a, b) => a + b) / notesDevoirs.length;

    double? moyenneFinale;
    if (moyenneDevoirs != null && noteComposition != null) {
      moyenneFinale = (moyenneDevoirs + noteComposition) / 2;
    } else if (moyenneDevoirs != null) {
      moyenneFinale = moyenneDevoirs;
    } else if (noteComposition != null) {
      moyenneFinale = noteComposition;
    }

    return {
      'moyenne_devoirs': moyenneDevoirs,
      'note_composition': noteComposition,
      'moyenne_finale': moyenneFinale,
    };
  }

  Color _couleurMoyenne(double? m) {
    if (m == null) return Colors.grey;
    if (m >= 14) return Colors.green;
    if (m >= 10) return Colors.orange;
    return Colors.red;
  }

  Future<void> _soumettrePourValidation() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Soumettre pour validation'),
        content: const Text(
          'Voulez-vous soumettre les moyennes finales de tous les élèves ?\nVous ne pourrez plus les modifier après validation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Oui, soumettre',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirme != true) return;

    try {
      var nombreEnvoyees = 0;
      for (final eleve in _eleves) {
        final moyenneFinale =
            _moyennePourEleve(eleve['id'] as int)['moyenne_finale'];
        if (moyenneFinale == null) continue;

        await NoteService.sauvegarderNote(
          eleveId: eleve['id'] as int,
          matiereId: _matiereId!,
          periodeId: _periodeId!,
          valeur: moyenneFinale,
        );
        nombreEnvoyees++;
      }

      if (nombreEnvoyees == 0) {
        _afficherErreur('Aucune moyenne calculable pour le moment');
        return;
      }

      await NoteService.soumettreNotes(
        classeId: _classeId!,
        periodeId: _periodeId!,
        matiereId: _matiereId!,
      );

      _afficherSucces('Notes soumises pour validation');
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saisie des notes'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerFiltres,
          ),
        ],
      ),
      body: _chargementFiltres
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Niveau 1 : filtres ──────────────────────
                Container(
                  color: Colors.indigo.withOpacity(0.05),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      DropdownButtonFormField<int>(
                        value: _classeId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Classe',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        hint: const Text('Choisir une classe'),
                        items: _classesDisponibles.map((c) {
                          return DropdownMenuItem<int>(
                            value: c['id'] as int,
                            child: Text(c['nom'] as String),
                          );
                        }).toList(),
                        onChanged: (v) {
                          setState(() {
                            _classeId = v;
                            _matiereId = null;
                            _eleves = [];
                            _evaluations = [];
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: _matiereId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Matière',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        hint: const Text('Choisir une matière'),
                        items: _matieresDisponibles.map((m) {
                          return DropdownMenuItem<int>(
                            value: m['id'] as int,
                            child: Text(m['nom'] as String),
                          );
                        }).toList(),
                        onChanged: (v) {
                          setState(() {
                            _matiereId = v;
                            _eleves = [];
                            _evaluations = [];
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: _periodeId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Période',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        hint: const Text('Choisir une période'),
                        items: _periodes.map((p) {
                          return DropdownMenuItem<int>(
                            value: p['id'] as int,
                            child: Text('${p['nom']} (${p['annee_libelle']})'),
                          );
                        }).toList(),
                        onChanged: (v) {
                          setState(() {
                            _periodeId = v;
                            _eleves = [];
                            _evaluations = [];
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _classeId == null ||
                                  _matiereId == null ||
                                  _periodeId == null
                              ? null
                              : _chargerTableau,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.search),
                          label: const Text('Charger les notes'),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Niveau 2/3 : tableau ─────────────────────
                if (_chargementTableau)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_eleves.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Sélectionnez une classe, une matière et une période\npuis cliquez sur "Charger les notes"',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _afficherDialogAjoutEvaluation('devoir'),
                            icon: const Icon(Icons.add),
                            label: const Text('Ajouter un devoir'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _afficherDialogAjoutEvaluation('composition'),
                            icon: const Icon(Icons.add),
                            label: const Text('Ajouter une composition'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _evaluations.isEmpty
                        ? const Center(
                            child: Text(
                              'Aucune évaluation pour cette matière/période.\nAjoutez un devoir ou une composition.',
                              style: TextStyle(color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : SingleChildScrollView(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.all(16),
                              child: DataTable(
                                columns: [
                                  const DataColumn(label: Text('Élève')),
                                  ..._evaluations.map((evaluation) {
                                    return DataColumn(
                                      label: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(evaluation['libelle'] as String),
                                          IconButton(
                                            icon: const Icon(Icons.save,
                                                size: 18, color: Colors.indigo),
                                            tooltip: 'Enregistrer la colonne',
                                            onPressed: () =>
                                                _enregistrerColonne(
                                                    evaluation['id'] as int),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                  const DataColumn(label: Text('Moyenne')),
                                ],
                                rows: _eleves.map((eleve) {
                                  final eleveId = eleve['id'] as int;
                                  final resultat = _moyennePourEleve(eleveId);
                                  final moyenneFinale =
                                      resultat['moyenne_finale'];
                                  final couleurMoyenne =
                                      _couleurMoyenne(moyenneFinale);

                                  return DataRow(cells: [
                                    DataCell(
                                        Text('${eleve['nom']} ${eleve['prenom']}')),
                                    ..._evaluations.map((evaluation) {
                                      final evaluationId =
                                          evaluation['id'] as int;
                                      return DataCell(
                                        SizedBox(
                                          width: 64,
                                          child: TextField(
                                            controller: _controllers[
                                                _cle(eleveId, evaluationId)],
                                            keyboardType: TextInputType.number,
                                            textAlign: TextAlign.center,
                                            decoration: const InputDecoration(
                                              hintText: '/20',
                                              isDense: true,
                                              border: OutlineInputBorder(),
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                    DataCell(
                                      Text(
                                        moyenneFinale != null
                                            ? moyenneFinale.toStringAsFixed(2)
                                            : '-',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: couleurMoyenne,
                                        ),
                                      ),
                                    ),
                                  ]);
                                }).toList(),
                              ),
                            ),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _evaluations.isEmpty
                            ? null
                            : _soumettrePourValidation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.send),
                        label: const Text('Soumettre pour validation'),
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
