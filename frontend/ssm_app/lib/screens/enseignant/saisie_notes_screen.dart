import 'package:flutter/material.dart';
import '../../services/note_service.dart';
import '../../services/classe_service.dart';
import '../../services/annee_service.dart';
import '../../services/matiere_service.dart';
import '../../services/eleve_service.dart';
import '../../services/auth_service.dart';

class SaisieNotesScreen extends StatefulWidget {
  const SaisieNotesScreen({super.key});

  @override
  State<SaisieNotesScreen> createState() => _SaisieNotesScreenState();
}

class _SaisieNotesScreenState extends State<SaisieNotesScreen> {
  // Données
  List<dynamic> _classes  = [];
  List<dynamic> _annees   = [];
  List<dynamic> _periodes = [];
  List<dynamic> _matieres = [];
  List<dynamic> _eleves   = [];
  List<dynamic> _notes    = [];

  // Sélections
  int? _classeId;
  int? _anneeId;
  int? _periodeId;
  int? _matiereId;

  bool _chargement      = true;
  bool _chargementNotes = false;

  // Contrôleurs des notes
  final Map<int, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _chargerDonnees();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _chargerDonnees() async {
    try {
      final resultats = await Future.wait([
        ClasseService.listerClasses(),
        AnneeService.listerAnnees(),
        MatiereService.listerMatieres(),
      ]);
      setState(() {
        _classes  = resultats[0] as List;
        _annees   = resultats[1] as List;
        _matieres = resultats[2] as List;
        _chargement = false;
      });
    } catch (e) {
      setState(() => _chargement = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _chargerPeriodes(int anneeId) async {
    try {
      final liste = await AnneeService.listerPeriodes(anneeId);
      setState(() {
        _periodes  = liste;
        _periodeId = null;
      });
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _chargerNotes() async {
    if (_classeId == null || _periodeId == null || _matiereId == null) return;

    setState(() => _chargementNotes = true);

    try {
      // Charger élèves et notes en parallèle
      final resultats = await Future.wait([
        EleveService.elevesParClasse(_classeId!, _anneeId!),
        NoteService.listerNotes(
          classeId:  _classeId!,
          periodeId: _periodeId!,
          matiereId: _matiereId!,
        ),
      ]);

      final eleves = resultats[0] as List;
      final notes  = resultats[1] as List;

      // Initialiser les contrôleurs
      _controllers.forEach((_, c) => c.dispose());
      _controllers.clear();

      for (final eleve in eleves) {
        final eleveId = eleve['id'] as int;
        final note    = notes.firstWhere(
          (n) => n['eleve_id'] == eleveId,
          orElse: () => null,
        );
        _controllers[eleveId] = TextEditingController(
          text: note != null ? note['valeur'].toString() : '',
        );
      }

      setState(() {
        _eleves          = eleves;
        _notes           = notes;
        _chargementNotes = false;
      });
    } catch (e) {
      setState(() => _chargementNotes = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  String _statutNote(int eleveId) {
    final note = _notes.firstWhere(
      (n) => n['eleve_id'] == eleveId,
      orElse: () => null,
    );
    return note?['statut'] ?? 'aucune';
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

  bool _peutModifier(String statut) {
    return statut == 'aucune' || statut == 'brouillon' || statut == 'rejete';
  }

  Future<void> _sauvegarderNote(int eleveId) async {
    final valeurStr = _controllers[eleveId]?.text ?? '';
    if (valeurStr.isEmpty) return;

    final valeur = double.tryParse(valeurStr);
    if (valeur == null || valeur < 0 || valeur > 20) {
      _afficherErreur('Note invalide (0 à 20)');
      return;
    }

    try {
      await NoteService.sauvegarderNote(
        eleveId:   eleveId,
        matiereId: _matiereId!,
        periodeId: _periodeId!,
        valeur:    valeur,
      );
      _afficherSucces('Note sauvegardée');
      _chargerNotes();
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _soumettreNotes() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Soumettre les notes'),
        content: const Text(
          'Voulez-vous soumettre toutes les notes ?\nVous ne pourrez plus les modifier.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Oui, soumettre',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirme == true) {
      try {
        await NoteService.soumettreNotes(
          classeId:  _classeId!,
          periodeId: _periodeId!,
          matiereId: _matiereId!,
        );
        _afficherSucces('Notes soumises pour validation');
        _chargerNotes();
      } catch (e) {
        _afficherErreur(e.toString().replaceAll('Exception: ', ''));
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saisie des notes'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          if (_eleves.isNotEmpty)
            TextButton.icon(
              onPressed: _soumettreNotes,
              icon: const Icon(Icons.send, color: Colors.white),
              label: const Text('Soumettre',
                  style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Filtres ──────────────────────────────────
                Container(
                  color: Colors.indigo.withOpacity(0.05),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Classe + Année
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
                                  _anneeId = v;
                                  _periodeId = null;
                                });
                                if (v != null) _chargerPeriodes(v);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Période + Matière
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

                      // Bouton charger
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
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.search),
                          label: const Text('Charger les élèves'),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Liste des élèves + notes ──────────────
                Expanded(
                  child: _chargementNotes
                      ? const Center(child: CircularProgressIndicator())
                      : _eleves.isEmpty
                          ? const Center(
                              child: Text(
                                'Sélectionnez une classe, une période\net une matière puis cliquez sur Charger',
                                style: TextStyle(color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _eleves.length,
                              itemBuilder: (context, index) {
                                final eleve  = _eleves[index];
                                final eleveId = eleve['id'] as int;
                                final statut  = _statutNote(eleveId);
                                final peutModifier = _peutModifier(statut);

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        // Avatar
                                        CircleAvatar(
                                          backgroundColor:
                                              eleve['sexe'] == 'M'
                                                  ? Colors.blue
                                                  : Colors.pink,
                                          child: Text(
                                            eleve['prenom']
                                                .toString()
                                                .substring(0, 1),
                                            style: const TextStyle(
                                                color: Colors.white),
                                          ),
                                        ),
                                        const SizedBox(width: 12),

                                        // Nom
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${eleve['nom']} ${eleve['prenom']}',
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                              Container(
                                                margin: const EdgeInsets
                                                    .only(top: 4),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: _couleurStatut(statut)
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  statut.toUpperCase(),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color:
                                                        _couleurStatut(statut),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Champ note
                                        SizedBox(
                                          width: 70,
                                          child: TextField(
                                            controller:
                                                _controllers[eleveId],
                                            enabled: peutModifier,
                                            keyboardType:
                                                TextInputType.number,
                                            textAlign: TextAlign.center,
                                            decoration: InputDecoration(
                                              hintText: '/20',
                                              border:
                                                  const OutlineInputBorder(),
                                              isDense: true,
                                              filled: !peutModifier,
                                              fillColor: Colors.grey[100],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // Bouton sauvegarder
                                        if (peutModifier)
                                          IconButton(
                                            icon: const Icon(Icons.save,
                                                color: Colors.indigo),
                                            onPressed: () =>
                                                _sauvegarderNote(eleveId),
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