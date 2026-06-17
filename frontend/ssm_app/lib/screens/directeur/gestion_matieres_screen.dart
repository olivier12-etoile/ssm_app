import 'package:flutter/material.dart';
import '../../services/matiere_service.dart';

class GestionMatieresScreen extends StatefulWidget {
  const GestionMatieresScreen({super.key});

  @override
  State<GestionMatieresScreen> createState() => _GestionMatieresScreenState();
}

class _GestionMatieresScreenState extends State<GestionMatieresScreen> {
  List<dynamic> _matieres = [];
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _chargerMatieres();
  }

  Future<void> _chargerMatieres() async {
    try {
      final liste = await MatiereService.listerMatieres();
      setState(() {
        _matieres   = liste;
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
    final nomController          = TextEditingController();
    final codeController         = TextEditingController();
    final coefficientController  = TextEditingController(text: '1');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter une matière'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomController,
              decoration: const InputDecoration(
                labelText: 'Nom (ex: Mathématiques)',
                prefixIcon: Icon(Icons.book),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Code (ex: MATH)',
                prefixIcon: Icon(Icons.code),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: coefficientController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Coefficient',
                prefixIcon: Icon(Icons.calculate),
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
              if (nomController.text.isEmpty) return;
              try {
                await MatiereService.creerMatiere(
                  nom:         nomController.text,
                  code:        codeController.text.isEmpty
                               ? null
                               : codeController.text.toUpperCase(),
                  coefficient: double.tryParse(coefficientController.text) ?? 1.0,
                );
                Navigator.pop(context);
                _afficherSucces('Matière créée avec succès');
                _chargerMatieres();
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
        title: const Text('Gestion des matières'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerMatieres,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _afficherDialogCreation,
        backgroundColor: Colors.purple,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : _matieres.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.book_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Aucune matière pour l\'instant',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _matieres.length,
                  itemBuilder: (context, index) {
                    final matiere = _matieres[index];
                    final coef    = matiere['coefficient'];
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
                            matiere['code'] != null
                                ? matiere['code'].toString().substring(0, 2)
                                : matiere['nom'].toString().substring(0, 2),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        title: Text(
                          matiere['nom'] as String,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: matiere['code'] != null
                            ? Text('Code : ${matiere['code']}')
                            : null,
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _couleurCoefficient(coef).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _couleurCoefficient(coef).withOpacity(0.5),
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
                      ),
                    );
                  },
                ),
    );
  }
}