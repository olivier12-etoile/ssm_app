import 'package:flutter/material.dart';
import '../../services/classe_matiere_service.dart';
import '../../services/classe_service.dart';
import '../../services/matiere_service.dart';

class MatieresParClasseScreen extends StatefulWidget {
  final int classeId;
  final String? nomClasse;

  const MatieresParClasseScreen({
    super.key,
    required this.classeId,
    this.nomClasse,
  });

  @override
  State<MatieresParClasseScreen> createState() =>
      _MatieresParClasseScreenState();
}

class _MatieresParClasseScreenState extends State<MatieresParClasseScreen> {
  List<dynamic> _matieresClasse = [];
  List<dynamic> _toutesMatieres = [];
  String? _nomClasse;
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _nomClasse = widget.nomClasse;
    _chargerDonnees();
    if (_nomClasse == null) _chargerNomClasse();
  }

  Future<void> _chargerNomClasse() async {
    try {
      final classes = await ClasseService.listerClasses();
      final classe = classes.firstWhere(
        (c) => c['id'] == widget.classeId,
        orElse: () => null,
      );
      if (classe != null && mounted) {
        setState(() => _nomClasse = classe['nom'] as String);
      }
    } catch (_) {
      // Le titre reste sur la valeur par défaut si la classe n'est pas trouvée.
    }
  }

  Future<void> _chargerDonnees() async {
    try {
      final resultats = await Future.wait([
        ClasseMatiereService.listerParClasse(widget.classeId),
        MatiereService.listerMatieres(),
      ]);
      setState(() {
        _matieresClasse = resultats[0];
        _toutesMatieres = resultats[1];
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

  Future<void> _confirmerSuppression(dynamic ligne) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer la matière'),
        content: Text(
          'Retirer "${ligne['matiere_nom']}" de cette classe ?',
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
      await ClasseMatiereService.supprimer(ligne['id'] as int);
      _afficherSucces('Matière retirée de la classe');
      _chargerDonnees();
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _afficherDialogAjout() async {
    if (_toutesMatieres.isEmpty) {
      _afficherErreur('Créez des matières d\'abord');
      return;
    }

    int? matiereSelectionnee;
    final coefficientController = TextEditingController(text: '1');

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text('Ajouter une matière — ${_nomClasse ?? "classe"}'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      value: matiereSelectionnee,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Matière',
                        prefixIcon: Icon(Icons.book),
                        border: OutlineInputBorder(),
                      ),
                      hint: const Text('Choisir une matière'),
                      items: _toutesMatieres.map((m) {
                        return DropdownMenuItem<int>(
                          value: m['id'] as int,
                          child: Text(m['nom'] as String),
                        );
                      }).toList(),
                      onChanged: (v) =>
                          setStateDialog(() => matiereSelectionnee = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: coefficientController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Coefficient',
                        prefixIcon: Icon(Icons.calculate),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
                onPressed: matiereSelectionnee == null
                    ? null
                    : () async {
                        try {
                          await ClasseMatiereService.ajouter(
                            widget.classeId,
                            matiereSelectionnee!,
                            double.tryParse(coefficientController.text) ?? 1.0,
                          );
                          Navigator.pop(context);
                          _afficherSucces('Matière ajoutée à la classe');
                          _chargerDonnees();
                        } catch (e) {
                          _afficherErreur(
                              e.toString().replaceAll('Exception: ', ''));
                        }
                      },
                child: const Text('Ajouter'),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _couleurCoefficient(dynamic coef) {
    final c = double.tryParse(coef.toString()) ?? 1.0;
    if (c >= 4) return Colors.red;
    if (c >= 3) return Colors.orange;
    if (c >= 2) return Colors.blue;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_nomClasse ?? 'Matières de la classe'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerDonnees,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _afficherDialogAjout,
        backgroundColor: Colors.purple,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter une matière'),
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
                    final ligne = _matieresClasse[index];
                    final coef = ligne['coefficient'];
                    final code = ligne['matiere_code'];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: CircleAvatar(
                          backgroundColor: Colors.purple,
                          child: Text(
                            code != null
                                ? code.toString().substring(0, 2)
                                : ligne['matiere_nom'].toString().substring(0, 2),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        title: Text(
                          ligne['matiere_nom'] as String,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: code != null ? Text('Code : $code') : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _couleurCoefficient(coef)
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _couleurCoefficient(coef)
                                      .withOpacity(0.5),
                                ),
                              ),
                              child: Text(
                                'Coef. $coef',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _couleurCoefficient(coef),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              onPressed: () => _confirmerSuppression(ligne),
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
