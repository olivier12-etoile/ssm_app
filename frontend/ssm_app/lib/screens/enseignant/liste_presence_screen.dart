import 'package:flutter/material.dart';
import '../../services/absence_service.dart';
import '../../services/annee_service.dart';
import '../../services/eleve_service.dart';

class ListePresenceScreen extends StatefulWidget {
  final int classeId;
  final String classeNom;

  const ListePresenceScreen({
    super.key,
    required this.classeId,
    required this.classeNom,
  });

  @override
  State<ListePresenceScreen> createState() => _ListePresenceScreenState();
}

class _ListePresenceScreenState extends State<ListePresenceScreen> {
  List<dynamic> _eleves = [];
  int? _anneeId;
  DateTime _date = DateTime.now();

  // eleveId -> true si absent (false = présent, par défaut)
  final Map<int, bool> _absents = {};

  bool _chargement = true;
  bool _chargementListe = false;

  @override
  void initState() {
    super.initState();
    _initialiser();
  }

  Future<void> _initialiser() async {
    try {
      final annees = await AnneeService.listerAnnees();
      final anneeEnCours = annees.firstWhere(
        (a) => a['statut'] == 'en_cours',
        orElse: () => annees.isNotEmpty ? annees.first : null,
      );
      _anneeId = anneeEnCours?['id'] as int?;

      setState(() => _chargement = false);

      if (_anneeId != null) {
        await _chargerPresences();
      }
    } catch (e) {
      setState(() => _chargement = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  String _formatDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _chargerPresences() async {
    if (_anneeId == null) return;

    setState(() => _chargementListe = true);

    try {
      final resultats = await Future.wait([
        EleveService.elevesParClasse(widget.classeId, _anneeId!),
        AbsenceService.listerAbsences(
          classeId: widget.classeId,
          dateAbsence: _formatDate(_date),
        ),
      ]);

      final eleves = resultats[0];
      final absencesExistantes = resultats[1];

      _absents.clear();
      for (final e in eleves) {
        _absents[e['id'] as int] = false;
      }
      for (final a in absencesExistantes) {
        _absents[a['eleve_id'] as int] = true;
      }

      setState(() {
        _eleves = eleves;
        _chargementListe = false;
      });
    } catch (e) {
      setState(() => _chargementListe = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _enregistrer() async {
    final absentsListe = _absents.entries
        .where((e) => e.value)
        .map((e) => {'eleve_id': e.key})
        .toList();

    try {
      await AbsenceService.enregistrerAbsences(
        classeId: widget.classeId,
        dateAbsence: _formatDate(_date),
        absences: absentsListe,
      );
      _afficherSucces(
        '${absentsListe.length} absence(s) enregistrée(s). '
        'Notifications WhatsApp créées pour les parents disponibles.',
      );
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<Map<String, List<dynamic>>> _chargerHistorique30Jours() async {
    final dates = List.generate(
      30,
      (i) => DateTime.now().subtract(Duration(days: 29 - i)),
    );

    final resultats = await Future.wait(dates.map((d) {
      return AbsenceService.listerAbsences(
        classeId: widget.classeId,
        dateAbsence: _formatDate(d),
      );
    }));

    final historique = <String, List<dynamic>>{};
    for (var i = 0; i < dates.length; i++) {
      historique[_formatDate(dates[i])] = resultats[i];
    }
    return historique;
  }

  String _nomEleve(int eleveId) {
    final eleve = _eleves.firstWhere(
      (e) => e['id'] == eleveId,
      orElse: () => null,
    );
    return eleve != null ? '${eleve['nom']} ${eleve['prenom']}' : 'Élève #$eleveId';
  }

  Future<void> _afficherAbsentsDuJour(DateTime date, List<dynamic> absences) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Absents le ${date.day}/${date.month}/${date.year}'),
        content: SizedBox(
          width: 350,
          child: absences.isEmpty
              ? const Text('Aucun élève absent ce jour-là.')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: absences.map((a) {
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.cancel, color: Colors.red),
                      title: Text(_nomEleve(a['eleve_id'] as int)),
                    );
                  }).toList(),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _afficherHistorique() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Historique (30 derniers jours)'),
        content: SizedBox(
          width: 350,
          height: 400,
          child: FutureBuilder<Map<String, List<dynamic>>>(
            future: _chargerHistorique30Jours(),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Erreur de chargement de l\'historique',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              final historique = snapshot.data!;
              final dates = List.generate(
                30,
                (i) => DateTime.now().subtract(Duration(days: 29 - i)),
              );

              return GridView.count(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                children: dates.map((date) {
                  final absencesJour = historique[_formatDate(date)] ?? [];
                  final aDesAbsences = absencesJour.isNotEmpty;

                  return GestureDetector(
                    onTap: () => _afficherAbsentsDuJour(date, absencesJour),
                    child: Container(
                      decoration: BoxDecoration(
                        color: aDesAbsences ? Colors.red[100] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: aDesAbsences ? Colors.red : Colors.grey[300]!,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${date.day}',
                          style: TextStyle(
                            fontWeight:
                                aDesAbsences ? FontWeight.bold : FontWeight.normal,
                            color: aDesAbsences ? Colors.red[900] : Colors.black87,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
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
    final nombreAbsents = _absents.values.where((v) => v).length;
    final nombrePresents = _absents.length - nombreAbsents;

    return Scaffold(
      appBar: AppBar(
        title: Text('Présence — ${widget.classeNom}'),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Historique',
            onPressed: _afficherHistorique,
          ),
        ],
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Sélecteur de date ────────────────────────
                Container(
                  color: Colors.brown.withOpacity(0.05),
                  padding: const EdgeInsets.all(16),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: Text(
                      'Date : ${_date.day}/${_date.month}/${_date.year}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _date,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (d != null) setState(() => _date = d);
                          },
                          child: const Text('Changer'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _anneeId == null ? null : _chargerPresences,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.brown,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.search, size: 18),
                          label: const Text('Charger'),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Compteur ─────────────────────────────────
                if (_eleves.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    color: nombreAbsents > 0 ? Colors.orange[100] : Colors.green[100],
                    child: Text(
                      '$nombrePresents présent(s) — $nombreAbsents absent(s) sur ${_eleves.length} élèves',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: nombreAbsents > 0
                            ? Colors.orange[900]
                            : Colors.green[900],
                      ),
                    ),
                  ),

                // ── Liste des élèves ─────────────────────────
                Expanded(
                  child: _chargementListe
                      ? const Center(child: CircularProgressIndicator())
                      : _eleves.isEmpty
                          ? const Center(
                              child: Text(
                                'Aucun élève chargé pour cette date',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _eleves.length,
                              itemBuilder: (context, index) {
                                final eleve = _eleves[index];
                                final eleveId = eleve['id'] as int;
                                final sexe = eleve['sexe'] as String;
                                final photoUrl = eleve['photo_url'] as String?;
                                final estAbsent = _absents[eleveId] ?? false;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  color: estAbsent ? Colors.red[50] : null,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(8),
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          sexe == 'M' ? Colors.blue : Colors.pink,
                                      backgroundImage:
                                          photoUrl != null ? NetworkImage(photoUrl) : null,
                                      child: photoUrl == null
                                          ? Text(
                                              eleve['prenom'].toString().substring(0, 1),
                                              style:
                                                  const TextStyle(color: Colors.white),
                                            )
                                          : null,
                                    ),
                                    title: Text(
                                      '${eleve['nom']} ${eleve['prenom']}',
                                      style:
                                          const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ChoiceChip(
                                          label: const Text('✅ Présent'),
                                          selected: !estAbsent,
                                          selectedColor: Colors.green[200],
                                          onSelected: (_) {
                                            setState(() => _absents[eleveId] = false);
                                          },
                                        ),
                                        const SizedBox(width: 6),
                                        ChoiceChip(
                                          label: const Text('❌ Absent'),
                                          selected: estAbsent,
                                          selectedColor: Colors.red[200],
                                          onSelected: (_) {
                                            setState(() => _absents[eleveId] = true);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),

                // ── Bouton enregistrer ───────────────────────
                if (_eleves.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _enregistrer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.brown,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(14),
                        ),
                        icon: const Icon(Icons.save),
                        label: const Text('Enregistrer la présence'),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
