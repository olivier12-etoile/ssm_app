import 'package:flutter/material.dart';
import '../../services/affectation_service.dart';
import '../../services/classe_service.dart';
import '../../services/matiere_service.dart';

class AffectationEnseignantScreen extends StatefulWidget {
  final int enseignantId;
  final String enseignantNom;

  const AffectationEnseignantScreen({
    super.key,
    required this.enseignantId,
    required this.enseignantNom,
  });

  @override
  State<AffectationEnseignantScreen> createState() =>
      _AffectationEnseignantScreenState();
}

class _AffectationEnseignantScreenState
    extends State<AffectationEnseignantScreen> {
  List<dynamic> _affectations = [];
  List<dynamic> _classes      = [];
  List<dynamic> _matieres     = [];
  bool _chargement            = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _chargerDonnees();
  }

  Future<void> _chargerDonnees() async {
    setState(() {
      _chargement = true;
      _erreur     = null;
    });

    try {
      // Charger classes et matières en parallèle
      final resultats = await Future.wait([
        ClasseService.listerClasses(),
        MatiereService.listerMatieres(),
      ]);

      _classes  = resultats[0] as List;
      _matieres = resultats[1] as List;

      // Charger les affectations séparément pour mieux gérer l'erreur
      try {
        final data = await AffectationService.listerAffectations(
            widget.enseignantId);
        _affectations = data['affectations'] as List? ?? [];
      } catch (e) {
        _affectations = [];
      }

      setState(() => _chargement = false);
    } catch (e) {
      setState(() {
        _chargement = false;
        _erreur     = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _afficherErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _afficherSucces(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Future<void> _afficherDialogAffectation() async {
    // ✅ Variables LOCALES au dialog — c'est ça qui corrige le dropdown
    int? classeSelectionnee;
    int? matiereSelectionnee;

    if (_classes.isEmpty) {
      _afficherErreur('Aucune classe disponible. Créez des classes d\'abord.');
      return;
    }

    if (_matieres.isEmpty) {
      _afficherErreur('Aucune matière disponible. Créez des matières d\'abord.');
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nouvelle affectation'),
                Text(
                  widget.enseignantNom,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ✅ Dropdown Classe
                  DropdownButtonFormField<int>(
                    value: classeSelectionnee,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Choisir une classe',
                      prefixIcon: Icon(Icons.class_),
                      border: OutlineInputBorder(),
                    ),
                    hint: const Text('Sélectionner une classe'),
                    items: _classes.map((c) {
                      return DropdownMenuItem<int>(
                        value: c['id'] as int,
                        child: Text(c['nom'] as String),
                      );
                    }).toList(),
                    onChanged: (v) {
                      setStateDialog(() => classeSelectionnee = v);
                    },
                  ),
                  const SizedBox(height: 16),

                  // ✅ Dropdown Matière
                  DropdownButtonFormField<int>(
                    value: matiereSelectionnee,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Choisir une matière',
                      prefixIcon: Icon(Icons.book),
                      border: OutlineInputBorder(),
                    ),
                    hint: const Text('Sélectionner une matière'),
                    items: _matieres.map((m) {
                      return DropdownMenuItem<int>(
                        value: m['id'] as int,
                        child: Text(m['nom'] as String),
                      );
                    }).toList(),
                    onChanged: (v) {
                      setStateDialog(() => matiereSelectionnee = v);
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
                onPressed: classeSelectionnee == null || matiereSelectionnee == null
                    ? null
                    : () async {
                        try {
                          await AffectationService.ajouterAffectation(
                            enseignantId: widget.enseignantId,
                            classeId:     classeSelectionnee!,
                            matiereId:    matiereSelectionnee!,
                          );
                          if (context.mounted) Navigator.pop(context);
                          _afficherSucces('Affectation ajoutée avec succès');
                          _chargerDonnees();
                        } catch (e) {
                          if (context.mounted) Navigator.pop(context);
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

  Future<void> _supprimer(int id) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Voulez-vous supprimer cette affectation ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Oui', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirme == true) {
      try {
        await AffectationService.supprimerAffectation(id);
        _afficherSucces('Affectation supprimée');
        _chargerDonnees();
      } catch (e) {
        _afficherErreur(e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Affectations',
                style: TextStyle(fontSize: 18)),
            Text(
              widget.enseignantNom,
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerDonnees,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _afficherDialogAffectation,
        backgroundColor: Colors.indigo,
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle affectation'),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : _erreur != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_erreur!,
                          style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _chargerDonnees,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : _affectations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.assignment_outlined,
                              size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            'Aucune affectation pour\n${widget.enseignantNom}',
                            style: const TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _afficherDialogAffectation,
                            icon: const Icon(Icons.add),
                            label: const Text('Ajouter une affectation'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _affectations.length,
                      itemBuilder: (context, index) {
                        final a = _affectations[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            leading: const CircleAvatar(
                              backgroundColor: Colors.indigo,
                              child: Icon(Icons.link, color: Colors.white),
                            ),
                            title: Text(
                              a['classe_nom'] as String,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(a['matiere_nom'] as String),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.red),
                              onPressed: () =>
                                  _supprimer(a['id'] as int),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}