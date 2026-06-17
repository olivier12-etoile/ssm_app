import 'package:flutter/material.dart';
import '../../services/classe_service.dart';

class GestionClassesScreen extends StatefulWidget {
  const GestionClassesScreen({super.key});

  @override
  State<GestionClassesScreen> createState() => _GestionClassesScreenState();
}

class _GestionClassesScreenState extends State<GestionClassesScreen> {
  List<dynamic> _classes = [];
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _chargerClasses();
  }

  Future<void> _chargerClasses() async {
    try {
      final liste = await ClasseService.listerClasses();
      setState(() {
        _classes   = liste;
        _chargement = false;
      });
    } catch (e) {
      setState(() => _chargement = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
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

  Future<void> _afficherDialogCreation() async {
    final nomController      = TextEditingController();
    final niveauController   = TextEditingController();
    final capaciteController = TextEditingController(text: '50');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter une classe'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: niveauController,
              decoration: const InputDecoration(
                labelText: 'Niveau (ex: 3ème)',
                prefixIcon: Icon(Icons.layers),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nomController,
              decoration: const InputDecoration(
                labelText: 'Nom (ex: 3ème A)',
                prefixIcon: Icon(Icons.class_),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: capaciteController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Capacité max',
                prefixIcon: Icon(Icons.people),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nomController.text.isEmpty || niveauController.text.isEmpty) {
                return;
              }
              try {
                await ClasseService.creerClasse(
                  nom:         nomController.text,
                  niveau:      niveauController.text,
                  capaciteMax: int.tryParse(capaciteController.text) ?? 50,
                );
                Navigator.pop(context);
                _afficherSucces('Classe créée avec succès');
                _chargerClasses();
              } catch (e) {
                _afficherErreur(e.toString().replaceAll('Exception: ', ''));
              }
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des classes'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerClasses,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _afficherDialogCreation,
        backgroundColor: Colors.green,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : _classes.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.class_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Aucune classe pour l\'instant',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _classes.length,
                  itemBuilder: (context, index) {
                    final classe = _classes[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Text(
                            classe['niveau'].toString().substring(0, 1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          classe['nom'] as String,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('Niveau : ${classe['niveau']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              '${classe['capacite_max']} élèves max',
                              style: const TextStyle(color: Colors.grey),
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