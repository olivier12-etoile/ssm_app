import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/classe_service.dart';
import '../../services/annee_service.dart';
import '../../services/eleve_service.dart';
import '../../widgets/ssm_widgets.dart';
import 'eleves_par_classe_screen.dart';

class GestionClassesScreen extends StatefulWidget {
  const GestionClassesScreen({super.key});

  @override
  State<GestionClassesScreen> createState() => _GestionClassesScreenState();
}

class _GestionClassesScreenState extends State<GestionClassesScreen> {
  List<dynamic> _classes = [];
  Map<int, int> _effectifs = {};
  int? _anneeId;
  bool _chargement = true;
  bool _chargementEffectifs = false;

  @override
  void initState() {
    super.initState();
    _chargerClasses();
  }

  Future<void> _chargerClasses() async {
    try {
      final resultats = await Future.wait([
        ClasseService.listerClasses(),
        AnneeService.listerAnnees(),
      ]);
      final liste = resultats[0];
      final annees = resultats[1];
      final anneeEnCours = annees.firstWhere(
        (a) => a['statut'] == 'en_cours',
        orElse: () => annees.isNotEmpty ? annees.first : null,
      );

      setState(() {
        _classes    = liste;
        _anneeId    = anneeEnCours?['id'] as int?;
        _chargement = false;
      });

      if (_anneeId != null) await _chargerEffectifs();
    } catch (e) {
      setState(() => _chargement = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _chargerEffectifs() async {
    if (_anneeId == null || _classes.isEmpty) return;

    setState(() => _chargementEffectifs = true);

    try {
      final listes = await Future.wait(_classes.map((classe) {
        return EleveService.elevesParClasse(classe['id'] as int, _anneeId!);
      }));

      final effectifs = <int, int>{};
      for (var i = 0; i < _classes.length; i++) {
        effectifs[_classes[i]['id'] as int] = listes[i].length;
      }

      setState(() {
        _effectifs = effectifs;
        _chargementEffectifs = false;
      });
    } catch (e) {
      setState(() => _chargementEffectifs = false);
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Gestion des classes',
          style: GoogleFonts.sora(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E3A8A),
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
        backgroundColor: const Color(0xFF1E3A8A),
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
                    final classeId = classe['id'] as int;
                    final effectif = _effectifs[classeId] ?? 0;
                    final capaciteMax = (classe['capacite_max'] as int?) ?? 50;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _chargementEffectifs
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : SSMCarteClasse(
                              nom: classe['nom'] as String,
                              nombreEleves: effectif,
                              capaciteMax: capaciteMax,
                              onTap: () {
                                if (_anneeId == null) {
                                  _afficherErreur(
                                      'Aucune année académique active');
                                  return;
                                }
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ElevesParClasseScreen(
                                      classeId: classeId,
                                      anneeId: _anneeId!,
                                      nomClasse: classe['nom'] as String,
                                    ),
                                  ),
                                );
                              },
                            ),
                    );
                  },
                ),
    );
  }
}