import 'package:flutter/material.dart';
import '../../services/classe_service.dart';
import '../../services/annee_service.dart';
import '../../services/frais_scolaire_service.dart';

class GestionFraisScreen extends StatefulWidget {
  const GestionFraisScreen({super.key});

  @override
  State<GestionFraisScreen> createState() => _GestionFraisScreenState();
}

class _GestionFraisScreenState extends State<GestionFraisScreen> {
  List<dynamic> _classes = [];
  List<dynamic> _annees = [];
  int? _anneeId;

  // classeId -> {'inscription': row?, 'scolarite': row?}
  Map<int, Map<String, dynamic>> _fraisParClasse = {};

  bool _chargement = true;
  bool _chargementFrais = false;

  @override
  void initState() {
    super.initState();
    _chargerInitial();
  }

  Future<void> _chargerInitial() async {
    try {
      final resultats = await Future.wait([
        ClasseService.listerClasses(),
        AnneeService.listerAnnees(),
      ]);
      final classes = resultats[0];
      final annees = resultats[1];
      final anneeEnCours = annees.firstWhere(
        (a) => a['statut'] == 'en_cours',
        orElse: () => annees.isNotEmpty ? annees.first : null,
      );

      setState(() {
        _classes = classes;
        _annees = annees;
        _anneeId = anneeEnCours?['id'] as int?;
        _chargement = false;
      });

      if (_anneeId != null) await _chargerFrais();
    } catch (e) {
      setState(() => _chargement = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _chargerFrais() async {
    if (_anneeId == null || _classes.isEmpty) return;

    setState(() => _chargementFrais = true);

    try {
      final listes = await Future.wait(_classes.map((c) {
        return FraisScolaireService.listerFrais(
          classeId: c['id'] as int,
          anneeId: _anneeId!,
        );
      }));

      final fraisParClasse = <int, Map<String, dynamic>>{};
      for (var i = 0; i < _classes.length; i++) {
        final classeId = _classes[i]['id'] as int;
        final parType = <String, dynamic>{};
        for (final f in listes[i]) {
          parType[f['type'] as String] = f;
        }
        fraisParClasse[classeId] = parType;
      }

      setState(() {
        _fraisParClasse = fraisParClasse;
        _chargementFrais = false;
      });
    } catch (e) {
      setState(() => _chargementFrais = false);
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

  Future<void> _afficherDialogFrais(int classeId, String classeNom) async {
    if (_anneeId == null) return;

    final fraisExistants = _fraisParClasse[classeId] ?? {};
    String type = 'scolarite';

    final montantTotalController = TextEditingController();
    final montantT1Controller = TextEditingController();
    final montantT2Controller = TextEditingController();
    final montantT3Controller = TextEditingController();

    void preremplir(String typeChoisi) {
      final frais = fraisExistants[typeChoisi];
      montantTotalController.text =
          frais != null ? frais['montant_total'].toString() : '';
      montantT1Controller.text = frais?['montant_tranche_1']?.toString() ?? '';
      montantT2Controller.text = frais?['montant_tranche_2']?.toString() ?? '';
      montantT3Controller.text = frais?['montant_tranche_3']?.toString() ?? '';
    }

    preremplir(type);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text('Frais scolaires — $classeNom'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: type,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        prefixIcon: Icon(Icons.category),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'inscription', child: Text('Inscription')),
                        DropdownMenuItem(
                            value: 'scolarite', child: Text('Scolarité')),
                      ],
                      onChanged: (v) => setStateDialog(() {
                        type = v!;
                        preremplir(type);
                      }),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: montantTotalController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Montant total annuel',
                        prefixIcon: Icon(Icons.attach_money),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: montantT1Controller,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Montant Tranche 1 (optionnel)',
                        prefixIcon: Icon(Icons.looks_one),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: montantT2Controller,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Montant Tranche 2 (optionnel)',
                        prefixIcon: Icon(Icons.looks_two),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: montantT3Controller,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Montant Tranche 3 (optionnel)',
                        prefixIcon: Icon(Icons.looks_3),
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
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: montantTotalController.text.isEmpty
                    ? null
                    : () async {
                        final montantTotal =
                            double.tryParse(montantTotalController.text);
                        if (montantTotal == null || montantTotal < 0) {
                          _afficherErreur('Montant total invalide');
                          return;
                        }
                        try {
                          await FraisScolaireService.enregistrerFrais(
                            classeId: classeId,
                            anneeAcademiqueId: _anneeId!,
                            type: type,
                            montantTotal: montantTotal,
                            montantTranche1:
                                double.tryParse(montantT1Controller.text),
                            montantTranche2:
                                double.tryParse(montantT2Controller.text),
                            montantTranche3:
                                double.tryParse(montantT3Controller.text),
                          );
                          if (context.mounted) Navigator.pop(context);
                          _afficherSucces('Frais scolaires enregistrés');
                          _chargerFrais();
                        } catch (e) {
                          _afficherErreur(
                              e.toString().replaceAll('Exception: ', ''));
                        }
                      },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _ligneFrais(String libelle, dynamic frais) {
    final configure = frais != null;
    return Row(
      children: [
        Icon(
          configure ? Icons.check_circle : Icons.warning_amber,
          size: 16,
          color: configure ? Colors.green : Colors.orange,
        ),
        const SizedBox(width: 6),
        Text('$libelle : ', style: const TextStyle(fontSize: 13)),
        Text(
          configure ? '${frais['montant_total']} FCFA' : 'Non configuré',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: configure ? Colors.black87 : Colors.orange,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Frais scolaires'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerInitial,
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
                    value: _anneeId,
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
                      setState(() => _anneeId = v);
                      _chargerFrais();
                    },
                  ),
                ),
                Expanded(
                  child: _classes.isEmpty
                      ? const Center(
                          child: Text('Aucune classe pour l\'instant',
                              style: TextStyle(color: Colors.grey)),
                        )
                      : _chargementFrais
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: _classes.length,
                              itemBuilder: (context, index) {
                                final classe = _classes[index];
                                final classeId = classe['id'] as int;
                                final classeNom = classe['nom'] as String;
                                final frais = _fraisParClasse[classeId] ?? {};

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(12),
                                    title: Text(
                                      classeNom,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _ligneFrais(
                                              'Inscription', frais['inscription']),
                                          const SizedBox(height: 4),
                                          _ligneFrais(
                                              'Scolarité', frais['scolarite']),
                                        ],
                                      ),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.edit,
                                          color: Colors.green),
                                      tooltip: 'Modifier les frais',
                                      onPressed: () =>
                                          _afficherDialogFrais(classeId, classeNom),
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
