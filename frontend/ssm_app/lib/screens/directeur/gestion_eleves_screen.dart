import 'package:flutter/material.dart';
import '../../services/eleve_service.dart';
import '../../services/classe_service.dart';
import '../../services/annee_service.dart';

class GestionElevesScreen extends StatefulWidget {
  const GestionElevesScreen({super.key});

  @override
  State<GestionElevesScreen> createState() => _GestionElevesScreenState();
}

class _GestionElevesScreenState extends State<GestionElevesScreen> {
  List<dynamic> _eleves   = [];
  List<dynamic> _classes  = [];
  List<dynamic> _annees   = [];
  bool _chargement        = true;

  @override
  void initState() {
    super.initState();
    _chargerDonnees();
  }

  Future<void> _chargerDonnees() async {
    try {
      final resultats = await Future.wait([
        EleveService.listerEleves(),
        ClasseService.listerClasses(),
        AnneeService.listerAnnees(),
      ]);
      setState(() {
        _eleves    = resultats[0] as List;
        _classes   = resultats[1] as List;
        _annees    = resultats[2] as List;
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

  Future<void> _afficherDialogCreation() async {
    final nomController      = TextEditingController();
    final prenomController   = TextEditingController();
    final telParentController = TextEditingController();
    String sexeSelectionne   = 'M';
    int? classeSelectionnee;
    int? anneeSelectionnee;

    if (_classes.isEmpty) {
      _afficherErreur('Créez des classes d\'abord');
      return;
    }
    if (_annees.isEmpty) {
      _afficherErreur('Créez une année académique d\'abord');
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Inscrire un élève'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Nom
                    TextField(
                      controller: nomController,
                      decoration: const InputDecoration(
                        labelText: 'Nom',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Prénom
                    TextField(
                      controller: prenomController,
                      decoration: const InputDecoration(
                        labelText: 'Prénom',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Sexe
                    DropdownButtonFormField<String>(
                      value: sexeSelectionne,
                      decoration: const InputDecoration(
                        labelText: 'Sexe',
                        prefixIcon: Icon(Icons.wc),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'M', child: Text('Masculin')),
                        DropdownMenuItem(value: 'F', child: Text('Féminin')),
                      ],
                      onChanged: (v) =>
                          setStateDialog(() => sexeSelectionne = v!),
                    ),
                    const SizedBox(height: 12),

                    // Classe
                    DropdownButtonFormField<int>(
                      value: classeSelectionnee,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Classe',
                        prefixIcon: Icon(Icons.class_),
                        border: OutlineInputBorder(),
                      ),
                      hint: const Text('Choisir une classe'),
                      items: _classes.map((c) {
                        return DropdownMenuItem<int>(
                          value: c['id'] as int,
                          child: Text(c['nom'] as String),
                        );
                      }).toList(),
                      onChanged: (v) =>
                          setStateDialog(() => classeSelectionnee = v),
                    ),
                    const SizedBox(height: 12),

                    // Année académique
                    DropdownButtonFormField<int>(
                      value: anneeSelectionnee,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Année académique',
                        prefixIcon: Icon(Icons.calendar_month),
                        border: OutlineInputBorder(),
                      ),
                      hint: const Text('Choisir une année'),
                      items: _annees.map((a) {
                        return DropdownMenuItem<int>(
                          value: a['id'] as int,
                          child: Text(a['libelle'] as String),
                        );
                      }).toList(),
                      onChanged: (v) =>
                          setStateDialog(() => anneeSelectionnee = v),
                    ),
                    const SizedBox(height: 12),

                    // Téléphone parent
                    TextField(
                      controller: telParentController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Téléphone parent (optionnel)',
                        prefixIcon: Icon(Icons.phone),
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
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                ),
                onPressed: nomController.text.isEmpty ||
                        prenomController.text.isEmpty ||
                        classeSelectionnee == null ||
                        anneeSelectionnee == null
                    ? null
                    : () async {
                        try {
                          await EleveService.creerEleve(
                            nom:                  nomController.text,
                            prenom:               prenomController.text,
                            sexe:                 sexeSelectionne,
                            classeId:             classeSelectionnee!,
                            anneeAcademiqueId:    anneeSelectionnee!,
                            telephoneParent:      telParentController.text.isEmpty
                                ? null
                                : telParentController.text,
                          );
                          Navigator.pop(context);
                          _afficherSucces('Élève inscrit avec succès');
                          _chargerDonnees();
                        } catch (e) {
                          _afficherErreur(
                              e.toString().replaceAll('Exception: ', ''));
                        }
                      },
                child: const Text('Inscrire'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des élèves'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerDonnees,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _afficherDialogCreation,
        backgroundColor: Colors.deepOrange,
        icon: const Icon(Icons.add),
        label: const Text('Inscrire un élève'),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : _eleves.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Aucun élève inscrit',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _eleves.length,
                  itemBuilder: (context, index) {
                    final e   = _eleves[index];
                    final sexe = e['sexe'] as String;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: CircleAvatar(
                          backgroundColor: sexe == 'M'
                              ? Colors.blue
                              : Colors.pink,
                          child: Text(
                            e['prenom'].toString().substring(0, 1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          '${e['nom']} ${e['prenom']}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Matricule : ${e['matricule']}  •  Sexe : $sexe',
                        ),
                        trailing: Icon(
                          sexe == 'M'
                              ? Icons.boy
                              : Icons.girl,
                          color: sexe == 'M'
                              ? Colors.blue
                              : Colors.pink,
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}