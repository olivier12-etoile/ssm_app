import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/eleve_service.dart';
import '../../services/classe_service.dart';
import '../../services/annee_service.dart';
import '../../widgets/ssm_widgets.dart';
import 'eleves_par_classe_screen.dart';

class GestionElevesScreen extends StatefulWidget {
  const GestionElevesScreen({super.key});

  @override
  State<GestionElevesScreen> createState() => _GestionElevesScreenState();
}

class _GestionElevesScreenState extends State<GestionElevesScreen> {
  List<dynamic> _classes = [];
  List<dynamic> _annees = [];
  Map<int, int> _effectifs = {};
  int? _anneeSelectionnee;
  bool _chargement = true;
  bool _chargementEffectifs = false;

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

      if (_anneeSelectionnee != null) {
        await _chargerEffectifs();
      }
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

  Future<void> _chargerEffectifs() async {
    if (_anneeSelectionnee == null || _classes.isEmpty) return;

    setState(() => _chargementEffectifs = true);

    try {
      final listes = await Future.wait(_classes.map((classe) {
        return EleveService.elevesParClasse(
          classe['id'] as int,
          _anneeSelectionnee!,
        );
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

  void _afficherErreur(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _ouvrirClasse(dynamic classe) {
    if (_anneeSelectionnee == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/directeur/eleves/classe'),
        builder: (_) => ElevesParClasseScreen(
          classeId: classe['id'] as int,
          anneeId: _anneeSelectionnee!,
          nomClasse: classe['nom'] as String,
        ),
      ),
    ).then((_) => _chargerEffectifs());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Gestion des élèves',
          style: GoogleFonts.sora(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E3A8A),
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
                    onChanged: (v) {
                      setState(() => _anneeSelectionnee = v);
                      _chargerEffectifs();
                    },
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
                            final effectif = _effectifs[classeId] ?? 0;
                            final capaciteMax =
                                (classe['capacite_max'] as int?) ?? 50;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _chargementEffectifs
                                  ? const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(12),
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      ),
                                    )
                                  : SSMCarteClasse(
                                      nom: classe['nom'] as String,
                                      nombreEleves: effectif,
                                      capaciteMax: capaciteMax,
                                      onTap: () => _ouvrirClasse(classe),
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
