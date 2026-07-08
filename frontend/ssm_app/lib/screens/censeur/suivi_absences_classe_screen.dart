import 'package:flutter/material.dart';
import '../../services/absence_service.dart';
import '../../services/annee_service.dart';
import '../../services/eleve_service.dart';

class SuiviAbsencesClasseScreen extends StatefulWidget {
  final int classeId;
  final String classeNom;

  const SuiviAbsencesClasseScreen({
    super.key,
    required this.classeId,
    required this.classeNom,
  });

  @override
  State<SuiviAbsencesClasseScreen> createState() =>
      _SuiviAbsencesClasseScreenState();
}

class _SuiviAbsencesClasseScreenState
    extends State<SuiviAbsencesClasseScreen> {
  List<dynamic> _eleves = [];
  int? _anneeId;

  DateTime _date = DateTime.now();
  Map<int, bool> _absentsDuJour = {};

  Map<String, List<dynamic>> _absencesDuMois = {};

  bool _chargement = true;
  bool _chargementJour = false;
  bool _chargementStats = false;

  @override
  void initState() {
    super.initState();
    _initialiser();
  }

  String _formatDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
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
        await Future.wait([_chargerJour(), _chargerStatsMois()]);
      }
    } catch (e) {
      setState(() => _chargement = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _chargerJour() async {
    if (_anneeId == null) return;

    setState(() => _chargementJour = true);

    try {
      final resultats = await Future.wait([
        EleveService.elevesParClasse(widget.classeId, _anneeId!),
        AbsenceService.listerAbsences(
          classeId: widget.classeId,
          dateAbsence: _formatDate(_date),
        ),
      ]);

      final eleves = resultats[0];
      final absences = resultats[1];

      final absents = <int, bool>{};
      for (final e in eleves) {
        absents[e['id'] as int] = false;
      }
      for (final a in absences) {
        absents[a['eleve_id'] as int] = true;
      }

      setState(() {
        _eleves = eleves;
        _absentsDuJour = absents;
        _chargementJour = false;
      });
    } catch (e) {
      setState(() => _chargementJour = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _chargerStatsMois() async {
    setState(() => _chargementStats = true);

    try {
      final aujourdhui = DateTime.now();
      final dates = List.generate(
        aujourdhui.day,
        (i) => DateTime(aujourdhui.year, aujourdhui.month, i + 1),
      );

      final resultats = await Future.wait(dates.map((d) {
        return AbsenceService.listerAbsences(
          classeId: widget.classeId,
          dateAbsence: _formatDate(d),
        );
      }));

      final absencesDuMois = <String, List<dynamic>>{};
      for (var i = 0; i < dates.length; i++) {
        absencesDuMois[_formatDate(dates[i])] = resultats[i];
      }

      setState(() {
        _absencesDuMois = absencesDuMois;
        _chargementStats = false;
      });
    } catch (e) {
      setState(() => _chargementStats = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  List<dynamic> get _toutesAbsencesMois =>
      _absencesDuMois.values.expand((l) => l).toList();

  DateTime get _lundiSemaine {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day - (n.weekday - 1));
  }

  int get _totalSemaine {
    final lundi = _lundiSemaine;
    return _toutesAbsencesMois.where((a) {
      final d = DateTime.tryParse(a['date_absence'].toString());
      return d != null && !d.isBefore(lundi);
    }).length;
  }

  int get _totalMois => _toutesAbsencesMois.length;

  List<dynamic> get _cinqDernieresAbsences {
    final liste = List<dynamic>.from(_toutesAbsencesMois);
    liste.sort((a, b) =>
        b['date_absence'].toString().compareTo(a['date_absence'].toString()));
    return liste.take(5).toList();
  }

  List<Map<String, dynamic>> get _topAbsences {
    final compteurs = <int, int>{};
    for (final a in _toutesAbsencesMois) {
      final id = a['eleve_id'] as int;
      compteurs[id] = (compteurs[id] ?? 0) + 1;
    }
    final entries = compteurs.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries
        .take(5)
        .map((e) => {'eleve_id': e.key, 'total': e.value})
        .toList();
  }

  String _nomEleve(int eleveId) {
    final eleve = _eleves.firstWhere(
      (e) => e['id'] == eleveId,
      orElse: () => null,
    );
    return eleve != null ? '${eleve['nom']} ${eleve['prenom']}' : 'Élève #$eleveId';
  }

  Future<void> _justifierAbsence(dynamic absence) async {
    final motifController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Justifier l\'absence — ${_nomEleve(absence['eleve_id'] as int)}'),
        content: TextField(
          controller: motifController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Motif',
            hintText: 'Ex : Certificat médical fourni',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              if (motifController.text.isEmpty) return;
              try {
                await AbsenceService.justifier(
                  absence['id'] as int,
                  motifController.text,
                );
                Navigator.pop(context);
                _afficherSucces('Absence justifiée');
                _chargerStatsMois();
              } catch (e) {
                _afficherErreur(e.toString().replaceAll('Exception: ', ''));
              }
            },
            child: const Text('Justifier', style: TextStyle(color: Colors.white)),
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Suivi absences — ${widget.classeNom}'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => Future.wait([_chargerJour(), _chargerStatsMois()]),
          ),
        ],
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Sélecteur de date ────────────────────────
                Container(
                  color: Colors.deepPurple.withOpacity(0.05),
                  padding: const EdgeInsets.all(12),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: Text('Date : ${_date.day}/${_date.month}/${_date.year}'),
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
                        ElevatedButton(
                          onPressed: _chargerJour,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Charger'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Statut du jour ───────────────────────────
                const Text(
                  'Statut du jour',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                _chargementJour
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : Column(
                        children: _eleves.map((eleve) {
                          final eleveId = eleve['id'] as int;
                          final estAbsent = _absentsDuJour[eleveId] ?? false;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                backgroundColor:
                                    eleve['sexe'] == 'M' ? Colors.blue : Colors.pink,
                                backgroundImage: eleve['photo_url'] != null
                                    ? NetworkImage(eleve['photo_url'] as String)
                                    : null,
                                child: eleve['photo_url'] == null
                                    ? Text(
                                        eleve['prenom'].toString().substring(0, 1),
                                        style: const TextStyle(color: Colors.white),
                                      )
                                    : null,
                              ),
                              title: Text('${eleve['nom']} ${eleve['prenom']}'),
                              trailing: estAbsent
                                  ? const Chip(
                                      label: Text('❌ Absent',
                                          style: TextStyle(color: Colors.white)),
                                      backgroundColor: Colors.red,
                                    )
                                  : const Chip(
                                      label: Text('✅ Présent',
                                          style: TextStyle(color: Colors.white)),
                                      backgroundColor: Colors.green,
                                    ),
                            ),
                          );
                        }).toList(),
                      ),
                const SizedBox(height: 24),

                // ── Statistiques ─────────────────────────────
                const Text(
                  'Statistiques',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                _chargementStats
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: _carteStat('Cette semaine', _totalSemaine,
                                Colors.orange),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _carteStat('Ce mois', _totalMois, Colors.brown),
                          ),
                        ],
                      ),
                const SizedBox(height: 24),

                // ── Historique 5 dernières absences ──────────
                const Text(
                  '5 dernières absences',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                if (!_chargementStats && _cinqDernieresAbsences.isEmpty)
                  const Text('Aucune absence ce mois-ci',
                      style: TextStyle(color: Colors.grey))
                else if (!_chargementStats)
                  ..._cinqDernieresAbsences.map((a) {
                    final justifiee = a['justifiee'] == true;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        dense: true,
                        leading: const Icon(Icons.event_busy, color: Colors.red),
                        title: Text(_nomEleve(a['eleve_id'] as int)),
                        subtitle: Text('${a['date_absence']}'),
                        trailing: justifiee
                            ? const Chip(
                                label: Text('Justifiée', style: TextStyle(fontSize: 11)),
                                backgroundColor: Colors.green,
                                labelStyle: TextStyle(color: Colors.white),
                              )
                            : TextButton(
                                onPressed: () => _justifierAbsence(a),
                                child: const Text('Justifier'),
                              ),
                      ),
                    );
                  }),
                const SizedBox(height: 24),

                // ── Top absences ─────────────────────────────
                const Text(
                  'Élèves les plus absents (ce mois)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                if (!_chargementStats && _topAbsences.isEmpty)
                  const Text('Aucune absence ce mois-ci',
                      style: TextStyle(color: Colors.grey))
                else if (!_chargementStats)
                  ..._topAbsences.asMap().entries.map((entry) {
                    final i = entry.key;
                    final t = entry.value;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          backgroundColor: i == 0 ? Colors.amber : Colors.grey[300],
                          child: Text('${i + 1}'),
                        ),
                        title: Text(_nomEleve(t['eleve_id'] as int)),
                        trailing: Text(
                          '${t['total']} absence(s)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  }),
              ],
            ),
    );
  }

  Widget _carteStat(String label, int valeur, Color couleur) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Text(
              '$valeur',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: couleur,
              ),
            ),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
