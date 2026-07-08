import 'package:flutter/material.dart';
import '../../services/affectation_service.dart';
import '../../services/classe_matiere_service.dart';
import '../../services/classe_service.dart';
import 'affectations_classe_screen.dart';

class GestionAffectationsScreen extends StatefulWidget {
  const GestionAffectationsScreen({super.key});

  @override
  State<GestionAffectationsScreen> createState() =>
      _GestionAffectationsScreenState();
}

class _GestionAffectationsScreenState
    extends State<GestionAffectationsScreen> {
  List<dynamic> _classes = [];
  Map<int, int> _totalMatieres = {};
  Map<int, int> _matieresAffectees = {};
  bool _chargement = true;
  bool _chargementCompteurs = false;

  @override
  void initState() {
    super.initState();
    _chargerDonnees();
  }

  Future<void> _chargerDonnees() async {
    try {
      final classes = await ClasseService.listerClasses();
      setState(() {
        _classes = classes;
        _chargement = false;
      });
      await _chargerCompteurs();
    } catch (e) {
      setState(() => _chargement = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _chargerCompteurs() async {
    if (_classes.isEmpty) return;

    setState(() => _chargementCompteurs = true);

    try {
      final resultats = await Future.wait(_classes.map((classe) {
        final classeId = classe['id'] as int;
        return Future.wait([
          ClasseMatiereService.listerParClasse(classeId),
          AffectationService.listerParClasse(classeId),
        ]);
      }));

      final totaux = <int, int>{};
      final affectees = <int, int>{};

      for (var i = 0; i < _classes.length; i++) {
        final classeId = _classes[i]['id'] as int;
        final matieresClasse = resultats[i][0];
        final affectations = resultats[i][1];

        totaux[classeId] = matieresClasse.length;
        affectees[classeId] =
            affectations.map((a) => a['matiere_id']).toSet().length;
      }

      setState(() {
        _totalMatieres = totaux;
        _matieresAffectees = affectees;
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
        settings: const RouteSettings(name: '/directeur/affectations/classe'),
        builder: (_) => AffectationsClasseScreen(
          classeId: classe['id'] as int,
          classeNom: classe['nom'] as String,
        ),
      ),
    ).then((_) => _chargerCompteurs());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Affectations enseignants'),
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
          : _classes.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.class_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Aucune classe pour l\'instant',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _classes.length,
                  itemBuilder: (context, index) {
                    final classe = _classes[index];
                    final classeId = classe['id'] as int;
                    final total = _totalMatieres[classeId];
                    final affectees = _matieresAffectees[classeId];
                    final complet = total != null &&
                        total > 0 &&
                        affectees != null &&
                        affectees >= total;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        onTap: () => _ouvrirClasse(classe),
                        leading: CircleAvatar(
                          backgroundColor: Colors.indigo,
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
                        trailing: _chargementCompteurs
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    complet
                                        ? Icons.check_circle
                                        : Icons.warning_amber,
                                    size: 16,
                                    color:
                                        complet ? Colors.green : Colors.orange,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${affectees ?? 0}/${total ?? 0} affectées',
                                    style: TextStyle(
                                      color: complet
                                          ? Colors.green
                                          : Colors.orange,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                      ),
                    );
                  },
                ),
    );
  }
}
