import 'package:flutter/material.dart';
import '../../services/annee_service.dart';

class GestionAnneesScreen extends StatefulWidget {
  const GestionAnneesScreen({super.key});

  @override
  State<GestionAnneesScreen> createState() => _GestionAnneesScreenState();
}

class _GestionAnneesScreenState extends State<GestionAnneesScreen> {
  List<dynamic> _annees   = [];
  bool _chargement        = true;

  @override
  void initState() {
    super.initState();
    _chargerAnnees();
  }

  Future<void> _chargerAnnees() async {
    try {
      final liste = await AnneeService.listerAnnees();
      setState(() {
        _annees     = liste;
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

  Future<void> _afficherDialogAnnee() async {
    final libelleController   = TextEditingController();
    DateTime? dateDebut;
    DateTime? dateFin;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Nouvelle année académique'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: libelleController,
                  decoration: const InputDecoration(
                    labelText: 'Libellé (ex: 2025-2026)',
                    prefixIcon: Icon(Icons.calendar_today),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                // Date début
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.date_range),
                  title: Text(dateDebut == null
                      ? 'Date de début'
                      : '${dateDebut!.day}/${dateDebut!.month}/${dateDebut!.year}'),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (d != null) setStateDialog(() => dateDebut = d);
                  },
                ),
                // Date fin
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.date_range),
                  title: Text(dateFin == null
                      ? 'Date de fin'
                      : '${dateFin!.day}/${dateFin!.month}/${dateFin!.year}'),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (d != null) setStateDialog(() => dateFin = d);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: libelleController.text.isEmpty ||
                        dateDebut == null ||
                        dateFin == null
                    ? null
                    : () async {
                        try {
                          await AnneeService.creerAnnee(
                            libelle:   libelleController.text,
                            dateDebut: '${dateDebut!.year}-${dateDebut!.month.toString().padLeft(2, '0')}-${dateDebut!.day.toString().padLeft(2, '0')}',
                            dateFin:   '${dateFin!.year}-${dateFin!.month.toString().padLeft(2, '0')}-${dateFin!.day.toString().padLeft(2, '0')}',
                          );
                          Navigator.pop(context);
                          _afficherSucces('Année créée avec succès');
                          _chargerAnnees();
                        } catch (e) {
                          _afficherErreur(
                              e.toString().replaceAll('Exception: ', ''));
                        }
                      },
                child: const Text('Créer'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _voirPeriodes(dynamic annee) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _PeriodeScreen(annee: annee),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Années académiques'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerAnnees,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _afficherDialogAnnee,
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle année'),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : _annees.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_month_outlined,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Aucune année académique',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _annees.length,
                  itemBuilder: (context, index) {
                    final annee  = _annees[index];
                    final nb     = (annee['periodes'] as List?)?.length ?? 0;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: const CircleAvatar(
                          backgroundColor: Colors.teal,
                          child: Icon(Icons.calendar_month,
                              color: Colors.white),
                        ),
                        title: Text(
                          annee['libelle'] as String,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('$nb période(s)'),
                        trailing: ElevatedButton(
                          onPressed: () => _voirPeriodes(annee),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Périodes'),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// ─── Écran des périodes ───────────────────────────────────
class _PeriodeScreen extends StatefulWidget {
  final dynamic annee;
  const _PeriodeScreen({required this.annee});

  @override
  State<_PeriodeScreen> createState() => _PeriodeScreenState();
}

class _PeriodeScreenState extends State<_PeriodeScreen> {
  List<dynamic> _periodes = [];
  bool _chargement        = true;

  @override
  void initState() {
    super.initState();
    _chargerPeriodes();
  }

  Future<void> _chargerPeriodes() async {
    try {
      final liste = await AnneeService.listerPeriodes(
          widget.annee['id'] as int);
      setState(() {
        _periodes   = liste;
        _chargement = false;
      });
    } catch (e) {
      setState(() => _chargement = false);
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

  Color _couleurStatut(String statut) {
    switch (statut) {
      case 'actif':    return Colors.green;
      case 'cloture':  return Colors.red;
      default:         return Colors.orange;
    }
  }

  Future<void> _afficherDialogPeriode() async {
    final nomController = TextEditingController();
    DateTime? dateDebut;
    DateTime? dateFin;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text('Nouvelle période — ${widget.annee['libelle']}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomController,
                  decoration: const InputDecoration(
                    labelText: 'Nom (ex: 1er Trimestre)',
                    prefixIcon: Icon(Icons.segment),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.date_range),
                  title: Text(dateDebut == null
                      ? 'Date de début'
                      : '${dateDebut!.day}/${dateDebut!.month}/${dateDebut!.year}'),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (d != null) setStateDialog(() => dateDebut = d);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.date_range),
                  title: Text(dateFin == null
                      ? 'Date de fin'
                      : '${dateFin!.day}/${dateFin!.month}/${dateFin!.year}'),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (d != null) setStateDialog(() => dateFin = d);
                  },
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
                  if (nomController.text.isEmpty ||
                      dateDebut == null ||
                      dateFin == null) return;
                  try {
                    await AnneeService.creerPeriode(
                      anneeAcademiqueId: widget.annee['id'] as int,
                      nom:               nomController.text,
                      dateDebut: '${dateDebut!.year}-${dateDebut!.month.toString().padLeft(2, '0')}-${dateDebut!.day.toString().padLeft(2, '0')}',
                      dateFin:   '${dateFin!.year}-${dateFin!.month.toString().padLeft(2, '0')}-${dateFin!.day.toString().padLeft(2, '0')}',
                    );
                    Navigator.pop(context);
                    _afficherSucces('Période créée');
                    _chargerPeriodes();
                  } catch (e) {
                    _afficherErreur(
                        e.toString().replaceAll('Exception: ', ''));
                  }
                },
                child: const Text('Créer'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _changerStatut(int id, String statutActuel) async {
    final statuts = ['planifie', 'actif', 'cloture'];
    String selectionne = statutActuel;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Changer le statut'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: statuts.map((s) {
                return RadioListTile<String>(
                  title: Text(s),
                  value: s,
                  groupValue: selectionne,
                  onChanged: (v) => setStateDialog(() => selectionne = v!),
                );
              }).toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await AnneeService.changerStatutPeriode(id, selectionne);
                    Navigator.pop(context);
                    _afficherSucces('Statut mis à jour');
                    _chargerPeriodes();
                  } catch (e) {
                    _afficherErreur(
                        e.toString().replaceAll('Exception: ', ''));
                  }
                },
                child: const Text('Confirmer'),
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
        title: Text('Périodes — ${widget.annee['libelle']}'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _afficherDialogPeriode,
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle période'),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : _periodes.isEmpty
              ? const Center(
                  child: Text('Aucune période',
                      style: TextStyle(color: Colors.grey)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _periodes.length,
                  itemBuilder: (context, index) {
                    final p      = _periodes[index];
                    final statut = p['statut'] as String;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: CircleAvatar(
                          backgroundColor: _couleurStatut(statut),
                          child: const Icon(Icons.segment,
                              color: Colors.white),
                        ),
                        title: Text(
                          p['nom'] as String,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                            '${p['date_debut']} → ${p['date_fin']}'),
                        trailing: GestureDetector(
                          onTap: () => _changerStatut(
                              p['id'] as int, statut),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _couleurStatut(statut).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color:
                                      _couleurStatut(statut).withOpacity(0.5)),
                            ),
                            child: Text(
                              statut.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                color: _couleurStatut(statut),
                                fontWeight: FontWeight.bold,
                              ),
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