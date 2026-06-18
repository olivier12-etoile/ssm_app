import 'package:flutter/material.dart';
import '../../services/note_service.dart';
import '../../services/classe_service.dart';
import '../../services/annee_service.dart';
import '../../services/matiere_service.dart';

class ValidationNotesScreen extends StatefulWidget {
  const ValidationNotesScreen({super.key});

  @override
  State<ValidationNotesScreen> createState() => _ValidationNotesScreenState();
}

class _ValidationNotesScreenState extends State<ValidationNotesScreen> {
  List<dynamic> _classes  = [];
  List<dynamic> _annees   = [];
  List<dynamic> _periodes = [];
  List<dynamic> _matieres = [];
  List<dynamic> _notes    = [];

  int? _classeId;
  int? _anneeId;
  int? _periodeId;
  int? _matiereId;

  bool _chargement      = true;
  bool _chargementNotes = false;

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
        MatiereService.listerMatieres(),
      ]);
      setState(() {
        _classes    = resultats[0] as List;
        _annees     = resultats[1] as List;
        _matieres   = resultats[2] as List;
        _chargement = false;
      });
    } catch (e) {
      setState(() => _chargement = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _chargerPeriodes(int anneeId) async {
    final liste = await AnneeService.listerPeriodes(anneeId);
    setState(() {
      _periodes  = liste;
      _periodeId = null;
    });
  }

  Future<void> _chargerNotes() async {
    if (_classeId == null || _periodeId == null || _matiereId == null) return;
    setState(() => _chargementNotes = true);
    try {
      final notes = await NoteService.listerNotes(
        classeId:  _classeId!,
        periodeId: _periodeId!,
        matiereId: _matiereId!,
      );
      setState(() {
        _notes           = notes;
        _chargementNotes = false;
      });
    } catch (e) {
      setState(() => _chargementNotes = false);
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

  Color _couleurStatut(String statut) {
    switch (statut) {
      case 'valide':    return Colors.green;
      case 'soumis':    return Colors.blue;
      case 'rejete':    return Colors.red;
      case 'brouillon': return Colors.orange;
      default:          return Colors.grey;
    }
  }

  bool _aNotesSoumises() {
    return _notes.any((n) => n['statut'] == 'soumis');
  }

  Future<void> _valider() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Valider les notes'),
        content: const Text(
          'Voulez-vous valider toutes les notes soumises ?\nCette action est définitive.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Valider',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirme == true) {
      try {
        await NoteService.validerNotes(
          classeId:  _classeId!,
          periodeId: _periodeId!,
          matiereId: _matiereId!,
        );
        _afficherSucces('Notes validées définitivement');
        _chargerNotes();
      } catch (e) {
        _afficherErreur(e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> _rejeter() async {
    final motifController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rejeter les notes'),
        content: TextField(
          controller: motifController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Motif du rejet',
            hintText: 'Ex: Notes incohérentes, vérifier la classe...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (motifController.text.isEmpty) return;
              try {
                await NoteService.rejeterNotes(
                  classeId:   _classeId!,
                  periodeId:  _periodeId!,
                  matiereId:  _matiereId!,
                  motifRejet: motifController.text,
                );
                Navigator.pop(context);
                _afficherSucces('Notes rejetées — l\'enseignant doit corriger');
                _chargerNotes();
              } catch (e) {
                _afficherErreur(
                    e.toString().replaceAll('Exception: ', ''));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Rejeter',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Validation des notes'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Filtres ──────────────────────────────
                Container(
                  color: Colors.orange.withOpacity(0.05),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _classeId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Classe',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              hint: const Text('Classe'),
                              items: _classes.map((c) {
                                return DropdownMenuItem<int>(
                                  value: c['id'] as int,
                                  child: Text(c['nom'] as String),
                                );
                              }).toList(),
                              onChanged: (v) =>
                                  setState(() => _classeId = v),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _anneeId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Année',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              hint: const Text('Année'),
                              items: _annees.map((a) {
                                return DropdownMenuItem<int>(
                                  value: a['id'] as int,
                                  child: Text(a['libelle'] as String),
                                );
                              }).toList(),
                              onChanged: (v) {
                                setState(() {
                                  _anneeId   = v;
                                  _periodeId = null;
                                });
                                if (v != null) _chargerPeriodes(v);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _periodeId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Période',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              hint: const Text('Période'),
                              items: _periodes.map((p) {
                                return DropdownMenuItem<int>(
                                  value: p['id'] as int,
                                  child: Text(p['nom'] as String),
                                );
                              }).toList(),
                              onChanged: (v) =>
                                  setState(() => _periodeId = v),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _matiereId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Matière',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              hint: const Text('Matière'),
                              items: _matieres.map((m) {
                                return DropdownMenuItem<int>(
                                  value: m['id'] as int,
                                  child: Text(m['nom'] as String),
                                );
                              }).toList(),
                              onChanged: (v) =>
                                  setState(() => _matiereId = v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _classeId == null ||
                                  _anneeId == null ||
                                  _periodeId == null ||
                                  _matiereId == null
                              ? null
                              : _chargerNotes,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.search),
                          label: const Text('Charger les notes'),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Boutons Valider / Rejeter ─────────────
                if (_aNotesSoumises())
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _valider,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.check),
                            label: const Text('Valider'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _rejeter,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.close),
                            label: const Text('Rejeter'),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Liste des notes ───────────────────────
                Expanded(
                  child: _chargementNotes
                      ? const Center(child: CircularProgressIndicator())
                      : _notes.isEmpty
                          ? const Center(
                              child: Text(
                                'Aucune note trouvée\nSélectionnez les filtres et cliquez sur Charger',
                                style: TextStyle(color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _notes.length,
                              itemBuilder: (context, index) {
                                final note   = _notes[index];
                                final statut = note['statut'] as String;
                                final eleve  = note['eleve'];
                                return Card(
                                  margin:
                                      const EdgeInsets.only(bottom: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10),
                                  ),
                                  child: ListTile(
                                    contentPadding:
                                        const EdgeInsets.all(12),
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          _couleurStatut(statut),
                                      child: Text(
                                        note['valeur'].toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      eleve != null
                                          ? '${eleve['nom']} ${eleve['prenom']}'
                                          : 'Élève inconnu',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: note['motif_rejet'] != null
                                        ? Text(
                                            'Motif : ${note['motif_rejet']}',
                                            style: const TextStyle(
                                                color: Colors.red),
                                          )
                                        : null,
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _couleurStatut(statut)
                                            .withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _couleurStatut(statut)
                                              .withOpacity(0.5),
                                        ),
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
                                );
                              },
                            ),
                ),
              ],
            ),
    );
  }
}