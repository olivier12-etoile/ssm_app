import 'package:flutter/material.dart';
import '../../services/paiement_service.dart';
import '../../services/eleve_service.dart';
import '../../services/annee_service.dart';

class GestionPaiementsScreen extends StatefulWidget {
  const GestionPaiementsScreen({super.key});

  @override
  State<GestionPaiementsScreen> createState() =>
      _GestionPaiementsScreenState();
}

class _GestionPaiementsScreenState extends State<GestionPaiementsScreen> {
  List<dynamic> _paiements  = [];
  List<dynamic> _eleves     = [];
  List<dynamic> _annees     = [];
  bool _chargement          = true;
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _chargerDonnees();
  }

  Future<void> _chargerDonnees() async {
    try {
      final resultats = await Future.wait([
        PaiementService.listerPaiements(),
        EleveService.listerEleves(),
        AnneeService.listerAnnees(),
        PaiementService.statistiques(null),
      ]);
      setState(() {
        _paiements  = resultats[0] as List;
        _eleves     = resultats[1] as List;
        _annees     = resultats[2] as List;
        _stats      = resultats[3] as Map<String, dynamic>;
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

  Future<void> _afficherDialogPaiement() async {
    int? eleveSelectionne;
    int? anneeSelectionnee;
    final montantController    = TextEditingController();
    final referenceController  = TextEditingController();
    String trancheSelectionnee = 'Tranche 1';
    DateTime datePaiement      = DateTime.now();

    if (_eleves.isEmpty) {
      _afficherErreur('Aucun élève disponible');
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Enregistrer un paiement'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Élève
                    DropdownButtonFormField<int>(
                      value: eleveSelectionne,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Élève',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      hint: const Text('Choisir un élève'),
                      items: _eleves.map((e) {
                        return DropdownMenuItem<int>(
                          value: e['id'] as int,
                          child: Text('${e['nom']} ${e['prenom']}'),
                        );
                      }).toList(),
                      onChanged: (v) =>
                          setStateDialog(() => eleveSelectionne = v),
                    ),
                    const SizedBox(height: 12),

                    // Année
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

                    // Tranche
                    DropdownButtonFormField<String>(
                      value: trancheSelectionnee,
                      decoration: const InputDecoration(
                        labelText: 'Tranche',
                        prefixIcon: Icon(Icons.layers),
                        border: OutlineInputBorder(),
                      ),
                      items: ['Tranche 1', 'Tranche 2', 'Tranche 3']
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(t),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setStateDialog(() => trancheSelectionnee = v!),
                    ),
                    const SizedBox(height: 12),

                    // Montant
                    TextField(
                      controller: montantController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Montant (FCFA)',
                        prefixIcon: Icon(Icons.attach_money),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Date paiement
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.date_range),
                      title: Text(
                        'Date : ${datePaiement.day}/${datePaiement.month}/${datePaiement.year}',
                      ),
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (d != null) {
                          setStateDialog(() => datePaiement = d);
                        }
                      },
                    ),

                    // Référence
                    TextField(
                      controller: referenceController,
                      decoration: const InputDecoration(
                        labelText: 'Référence (optionnel)',
                        prefixIcon: Icon(Icons.receipt),
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
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
                onPressed: eleveSelectionne == null ||
                        anneeSelectionnee == null ||
                        montantController.text.isEmpty
                    ? null
                    : () async {
                        final montant =
                            double.tryParse(montantController.text);
                        if (montant == null || montant <= 0) {
                          _afficherErreur('Montant invalide');
                          return;
                        }
                        try {
                          await PaiementService.enregistrer(
                            eleveId:            eleveSelectionne!,
                            anneeAcademiqueId:  anneeSelectionnee!,
                            montant:            montant,
                            tranche:            trancheSelectionnee,
                            datePaiement:
                                '${datePaiement.year}-${datePaiement.month.toString().padLeft(2, '0')}-${datePaiement.day.toString().padLeft(2, '0')}',
                            reference: referenceController.text.isEmpty
                                ? null
                                : referenceController.text,
                          );
                          Navigator.pop(context);
                          _afficherSucces('Paiement enregistré');
                          _chargerDonnees();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des paiements'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerDonnees,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _afficherDialogPaiement,
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.add),
        label: const Text('Nouveau paiement'),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Statistiques ──────────────────────────
                if (_stats != null)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.teal,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statCard(
                          'Total encaissé',
                          '${_stats!['total_encaisse']} FCFA',
                          Icons.account_balance_wallet,
                        ),
                        _statCard(
                          'Paiements',
                          '${_stats!['nombre_paiements']}',
                          Icons.receipt_long,
                        ),
                      ],
                    ),
                  ),

                // ── Liste paiements ───────────────────────
                Expanded(
                  child: _paiements.isEmpty
                      ? const Center(
                          child: Text(
                            'Aucun paiement enregistré',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                          itemCount: _paiements.length,
                          itemBuilder: (context, index) {
                            final p     = _paiements[index];
                            final eleve = p['eleve'];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(12),
                                leading: const CircleAvatar(
                                  backgroundColor: Colors.teal,
                                  child: Icon(Icons.payment,
                                      color: Colors.white),
                                ),
                                title: Text(
                                  eleve != null
                                      ? '${eleve['nom']} ${eleve['prenom']}'
                                      : 'Élève inconnu',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  '${p['tranche']}  •  ${p['date_paiement']}',
                                ),
                                trailing: Text(
                                  '${p['montant']} FCFA',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal,
                                    fontSize: 14,
                                  ),
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

  Widget _statCard(String titre, String valeur, IconData icone) {
    return Column(
      children: [
        Icon(icone, color: Colors.white, size: 28),
        const SizedBox(height: 4),
        Text(
          valeur,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          titre,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}