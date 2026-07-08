import 'package:flutter/material.dart';
import '../../services/affectation_service.dart';
import '../../services/classe_matiere_service.dart';

class AffectationsClasseScreen extends StatefulWidget {
  final int classeId;
  final String classeNom;

  const AffectationsClasseScreen({
    super.key,
    required this.classeId,
    required this.classeNom,
  });

  @override
  State<AffectationsClasseScreen> createState() =>
      _AffectationsClasseScreenState();
}

class _AffectationsClasseScreenState extends State<AffectationsClasseScreen> {
  List<dynamic> _matieresClasse = [];
  List<dynamic> _affectations = [];
  List<dynamic> _enseignants = [];
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _chargerDonnees();
  }

  Future<void> _chargerDonnees() async {
    try {
      final resultats = await Future.wait([
        ClasseMatiereService.listerParClasse(widget.classeId),
        AffectationService.listerParClasse(widget.classeId),
        AffectationService.listerEnseignants(),
      ]);
      setState(() {
        _matieresClasse = resultats[0];
        _affectations = resultats[1];
        _enseignants = resultats[2];
        _chargement = false;
      });
    } catch (e) {
      setState(() => _chargement = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
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

  dynamic _affectationPourMatiere(int matiereId) {
    return _affectations.firstWhere(
      (a) => a['matiere_id'] == matiereId,
      orElse: () => null,
    );
  }

  Future<void> _afficherDialogAffectation(
      int matiereId, String matiereNom, dynamic affectationActuelle) async {
    if (_enseignants.isEmpty) {
      _afficherErreur('Aucun enseignant disponible. Créez des enseignants d\'abord.');
      return;
    }

    int? enseignantSelectionne = affectationActuelle?['enseignant_id'] as int?;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text('Affecter un enseignant — $matiereNom'),
            content: SizedBox(
              width: 400,
              child: DropdownButtonFormField<int>(
                value: enseignantSelectionne,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Enseignant',
                  prefixIcon: Icon(Icons.school),
                  border: OutlineInputBorder(),
                ),
                hint: const Text('Choisir un enseignant'),
                items: _enseignants.map((e) {
                  return DropdownMenuItem<int>(
                    value: e['id'] as int,
                    child: Text(e['name'] as String),
                  );
                }).toList(),
                onChanged: (v) =>
                    setStateDialog(() => enseignantSelectionne = v),
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
                onPressed: enseignantSelectionne == null
                    ? null
                    : () async {
                        final navigator = Navigator.of(context);
                        try {
                          if (affectationActuelle != null) {
                            await AffectationService.supprimerAffectation(
                                affectationActuelle['id'] as int);
                          }
                          await AffectationService.ajouterAffectation(
                            enseignantId: enseignantSelectionne!,
                            classeId: widget.classeId,
                            matiereId: matiereId,
                          );
                          navigator.pop();
                          _afficherSucces('Enseignant affecté avec succès');
                          _chargerDonnees();
                        } catch (e) {
                          navigator.pop();
                          _afficherErreur(
                              e.toString().replaceAll('Exception: ', ''));
                        }
                      },
                child: const Text('Affecter'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmerRetrait(dynamic affectation) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer l\'affectation'),
        content: Text(
          'Retirer ${affectation['enseignant_nom']} de "${affectation['matiere_nom']}" ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );

    if (confirme != true) return;

    try {
      await AffectationService.supprimerAffectation(affectation['id'] as int);
      _afficherSucces('Affectation retirée');
      _chargerDonnees();
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.classeNom),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerDonnees,
          ),
        ],
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : _matieresClasse.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.book_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Aucune matière assignée à cette classe',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _matieresClasse.length,
                  itemBuilder: (context, index) {
                    final matiere = _matieresClasse[index];
                    final matiereId = matiere['matiere_id'] as int;
                    final matiereNom = matiere['matiere_nom'] as String;
                    final coefficient = matiere['coefficient'];
                    final affectation = _affectationPourMatiere(matiereId);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: CircleAvatar(
                          backgroundColor: Colors.indigo,
                          child: Text(
                            matiereNom.substring(0, 1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          matiereNom,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Row(
                          children: [
                            Text('Coef. $coefficient'),
                            const SizedBox(width: 8),
                            Expanded(
                              child: affectation != null
                                  ? Text(
                                      affectation['enseignant_nom'] as String,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : const Text(
                                      'Non affecté',
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              tooltip: 'Affecter / changer l\'enseignant',
                              onPressed: () => _afficherDialogAffectation(
                                  matiereId, matiereNom, affectation),
                            ),
                            if (affectation != null)
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red),
                                tooltip: 'Retirer l\'affectation',
                                onPressed: () => _confirmerRetrait(affectation),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
