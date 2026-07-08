import 'package:flutter/material.dart';
import '../../services/classe_service.dart';
import '../../services/classe_matiere_service.dart';
import '../../services/annee_service.dart';
import 'matieres_par_classe_screen.dart';

class GestionMatieresScreen extends StatefulWidget {
  const GestionMatieresScreen({super.key});

  @override
  State<GestionMatieresScreen> createState() => _GestionMatieresScreenState();
}

class _GestionMatieresScreenState extends State<GestionMatieresScreen> {
  List<dynamic> _classes = [];
  List<dynamic> _annees = [];
  Map<int, int> _nombreMatieres = {};
  int? _anneeSelectionnee;
  bool _chargement = true;
  bool _chargementCompteurs = false;

  @override
  void initState() {
    super.initState();
    _chargerDonnees();
  }

  Future<void> _chargerDonnees() async {
    try {
      final resultats = await Future.wait([
        ClasseService.listerClasses(),
        AnneeService.listerAnnees(),
      ]);
      final classes = resultats[0];
      final annees = resultats[1];

      setState(() {
        _classes = classes;
        _annees = annees;
        _anneeSelectionnee ??= _anneeParDefaut(annees);
        _chargement = false;
      });

      await _chargerCompteurs();
    } catch (e) {
      setState(() => _chargement = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  int? _anneeParDefaut(List<dynamic> annees) {
    if (annees.isEmpty) return null;
    final enCours = annees.firstWhere(
      (a) => a['statut'] == 'en_cours',
      orElse: () => annees.first,
    );
    return enCours['id'] as int;
  }

  Future<void> _chargerCompteurs() async {
    if (_classes.isEmpty) return;

    setState(() => _chargementCompteurs = true);

    try {
      final listes = await Future.wait(_classes.map((classe) {
        return ClasseMatiereService.listerParClasse(classe['id'] as int);
      }));

      final compteurs = <int, int>{};
      for (var i = 0; i < _classes.length; i++) {
        compteurs[_classes[i]['id'] as int] = listes[i].length;
      }

      setState(() {
        _nombreMatieres = compteurs;
        _chargementCompteurs = false;
      });
    } catch (e) {
      setState(() => _chargementCompteurs = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _afficherErreur(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _ouvrirClasse(dynamic classe) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/directeur/matieres/classe'),
        builder: (_) => MatieresParClasseScreen(
          classeId: classe['id'] as int,
          nomClasse: classe['nom'] as String,
        ),
      ),
    ).then((_) => _chargerCompteurs());
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
            onPressed: _chargerDonnees,
          ),
        ],
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: DropdownButtonFormField<int>(
                    value: _anneeSelectionnee,
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
                    onChanged: (v) => setState(() => _anneeSelectionnee = v),
                  ),
                ),
                Expanded(
                  child: _classes.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.class_outlined,
                                  size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('Aucune classe pour l\'instant',
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: _classes.length,
                          itemBuilder: (context, index) {
                            final classe = _classes[index];
                            final classeId = classe['id'] as int;
                            final nombre = _nombreMatieres[classeId];

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(12),
                                onTap: () => _ouvrirClasse(classe),
                                leading: CircleAvatar(
                                  backgroundColor: Colors.purple,
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
                                  style:
                                      const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text('Niveau : ${classe['niveau']}'),
                                trailing: _chargementCompteurs
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.book,
                                              size: 16, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${nombre ?? 0} matière${(nombre ?? 0) > 1 ? 's' : ''}',
                                            style: const TextStyle(
                                                color: Colors.grey),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.chevron_right),
                                        ],
                                      ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
