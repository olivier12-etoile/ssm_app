import 'package:flutter/material.dart';
import '../../services/paiement_service.dart';
import '../../services/classe_service.dart';
import '../../services/annee_service.dart';

class ListeRenvoiScreen extends StatefulWidget {
  const ListeRenvoiScreen({super.key});

  @override
  State<ListeRenvoiScreen> createState() => _ListeRenvoiScreenState();
}

class _ListeRenvoiScreenState extends State<ListeRenvoiScreen> {
  List<dynamic> _classes          = [];
  List<dynamic> _annees           = [];
  List<dynamic> _nonAJour         = [];
  bool _chargement                = true;
  bool _chargementListe           = false;
  int? _classeId;
  int? _anneeId;
  final _montantController        = TextEditingController();

  @override
  void initState() {
    super.initState();
    _chargerDonnees();
  }

  @override
  void dispose() {
    _montantController.dispose();
    super.dispose();
  }

  Future<void> _chargerDonnees() async {
    try {
      final resultats = await Future.wait([
        ClasseService.listerClasses(),
        AnneeService.listerAnnees(),
      ]);
      setState(() {
        _classes    = resultats[0] as List;
        _annees     = resultats[1] as List;
        _chargement = false;
      });
    } catch (e) {
      setState(() => _chargement = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _genererListe() async {
    if (_classeId == null || _anneeId == null ||
        _montantController.text.isEmpty) {
      _afficherErreur('Remplissez tous les champs');
      return;
    }

    final montant = double.tryParse(_montantController.text);
    if (montant == null || montant <= 0) {
      _afficherErreur('Montant invalide');
      return;
    }

    setState(() => _chargementListe = true);

    try {
      final data = await PaiementService.listeRenvoi(
        classeId:           _classeId!,
        anneeAcademiqueId:  _anneeId!,
        montantExige:       montant,
      );
      setState(() {
        _nonAJour        = data['non_a_jour'] as List;
        _chargementListe = false;
      });
    } catch (e) {
      setState(() => _chargementListe = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _afficherErreur(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liste de renvoi'),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Filtres ──────────────────────────────
                Container(
                  color: Colors.red[50],
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Classe
                      DropdownButtonFormField<int>(
                        value: _classeId,
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
                        onChanged: (v) => setState(() => _classeId = v),
                      ),
                      const SizedBox(height: 12),

                      // Année
                      DropdownButtonFormField<int>(
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
                        onChanged: (v) => setState(() => _anneeId = v),
                      ),
                      const SizedBox(height: 12),

                      // Montant exigé
                      TextField(
                        controller: _montantController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Montant exigé (FCFA)',
                          prefixIcon: Icon(Icons.attach_money),
                          border: OutlineInputBorder(),
                          hintText: 'Ex: 40000',
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Bouton générer
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _genererListe,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[700],
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.search),
                          label: const Text('Générer la liste'),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Résultat ─────────────────────────────
                if (_nonAJour.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: Colors.red[700],
                    child: Text(
                      '${_nonAJour.length} élève(s) non à jour',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                Expanded(
                  child: _chargementListe
                      ? const Center(child: CircularProgressIndicator())
                      : _nonAJour.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_outline,
                                      size: 64, color: Colors.green),
                                  SizedBox(height: 16),
                                  Text(
                                    'Tous les élèves sont à jour\nou remplissez les filtres',
                                    style:
                                        TextStyle(color: Colors.grey),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _nonAJour.length,
                              itemBuilder: (context, index) {
                                final e = _nonAJour[index];
                                return Card(
                                  margin: const EdgeInsets.only(
                                      bottom: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10),
                                    side: BorderSide(
                                        color: Colors.red.shade200),
                                  ),
                                  child: ListTile(
                                    contentPadding:
                                        const EdgeInsets.all(12),
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.red[700],
                                      child: Text(
                                        '${index + 1}',
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
                                      'Matricule : ${e['matricule']}\nPayé : ${e['total_paye']} FCFA',
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Text(
                                          'Doit',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey),
                                        ),
                                        Text(
                                          '${e['montant_du']} FCFA',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red[700],
                                            fontSize: 14,
                                          ),
                                        ),
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