import 'package:flutter/material.dart';
import '../../services/absence_service.dart';
import '../../services/classe_service.dart';
import '../../services/eleve_service.dart';
import '../../services/annee_service.dart';
import '../../services/whatsapp_service.dart';
import '../../services/auth_service.dart';

class SaisieAbsencesScreen extends StatefulWidget {
  const SaisieAbsencesScreen({super.key});

  @override
  State<SaisieAbsencesScreen> createState() => _SaisieAbsencesScreenState();
}

class _SaisieAbsencesScreenState extends State<SaisieAbsencesScreen> {
  List<dynamic> _classes  = [];
  List<dynamic> _annees   = [];
  List<dynamic> _eleves   = [];
  List<dynamic> _absencesExistantes = [];

  int? _classeId;
  int? _anneeId;
  DateTime _date = DateTime.now();

  // eleveId -> true si absent
  final Map<int, bool> _absents = {};
  // eleveId -> absenceId (si déjà enregistrée)
  final Map<int, int> _absenceIds = {};
  // eleveId -> notifié
  final Map<int, bool> _notifies = {};

  bool _chargement      = true;
  bool _chargementListe = false;
  String? _nomEcole;

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
      final utilisateur = await AuthService.getUtilisateur();
      setState(() {
        _classes    = resultats[0] as List;
        _annees     = resultats[1] as List;
        _nomEcole   = utilisateur?.codeEcole;
        _chargement = false;
      });
    } catch (e) {
      setState(() => _chargement = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _chargerEleves() async {
    if (_classeId == null || _anneeId == null) return;

    setState(() => _chargementListe = true);

    try {
      final eleves = await EleveService.elevesParClasse(
          _classeId!, _anneeId!);

      final dateStr =
          '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

      final absences = await AbsenceService.listerAbsences(
        classeId:    _classeId!,
        dateAbsence: dateStr,
      );

      _absents.clear();
      _absenceIds.clear();
      _notifies.clear();

      for (final e in eleves) {
        final eleveId = e['id'] as int;
        _absents[eleveId] = false;
      }

      for (final a in absences) {
        final eleveId = a['eleve_id'] as int;
        _absents[eleveId]    = true;
        _absenceIds[eleveId] = a['id'] as int;
        _notifies[eleveId]   = a['notifie'] as bool;
      }

      setState(() {
        _eleves              = eleves;
        _absencesExistantes  = absences;
        _chargementListe     = false;
      });
    } catch (e) {
      setState(() => _chargementListe = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _enregistrer() async {
    final dateStr =
        '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

    final absentsList = _absents.entries
        .where((e) => e.value == true)
        .map((e) => {'eleve_id': e.key})
        .toList();

    try {
      final nouvelles = await AbsenceService.enregistrerAbsences(
        classeId:     _classeId!,
        dateAbsence:  dateStr,
        absences:     absentsList,
      );

      // Mettre à jour les IDs d'absence
      _absenceIds.clear();
      for (final a in nouvelles) {
        _absenceIds[a['eleve_id'] as int] = a['id'] as int;
      }

      _afficherSucces('${absentsList.length} absence(s) enregistrée(s)');
      _chargerEleves();
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _notifierParent(dynamic eleve) async {
    final eleveId = eleve['id'] as int;
    final telephoneParent = eleve['telephone_parent'] as String?;

    if (telephoneParent == null || telephoneParent.isEmpty) {
      _afficherErreur('Aucun numéro de téléphone enregistré pour ce parent');
      return;
    }

    final classe = _classes.firstWhere(
      (c) => c['id'] == _classeId,
      orElse: () => {'nom': 'Classe'},
    );

    final message = WhatsAppService.messageAbsence(
      nomParent: 'Cher parent',
      nomEleve:  '${eleve['nom']} ${eleve['prenom']}',
      classe:    classe['nom'] as String,
      heure:     '${TimeOfDay.now().format(context)}',
      nomEcole:  'École (Code: $_nomEcole)',
    );

    final succes = await WhatsAppService.envoyerMessage(
      numeroTelephone: telephoneParent,
      message:         message,
    );

    if (succes) {
      // Marquer comme notifié si l'absence existe en base
      if (_absenceIds.containsKey(eleveId)) {
        await AbsenceService.marquerNotifie(_absenceIds[eleveId]!);
        setState(() => _notifies[eleveId] = true);
      }
    } else {
      _afficherErreur('Impossible d\'ouvrir WhatsApp');
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
    final nombreAbsents =
        _absents.values.where((v) => v == true).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saisie des absences'),
        backgroundColor: Colors.brown,
        foregroundColor: Colors.white,
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Filtres ──────────────────────────────
                Container(
                  color: Colors.brown.withOpacity(0.05),
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
                              onChanged: (v) =>
                                  setState(() => _anneeId = v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_today),
                        title: Text(
                          'Date : ${_date.day}/${_date.month}/${_date.year}',
                        ),
                        trailing: TextButton(
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
                      ),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _classeId == null || _anneeId == null
                              ? null
                              : _chargerEleves,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.brown,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.search),
                          label: const Text('Charger les élèves'),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Compteur ─────────────────────────────
                if (_eleves.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    color: nombreAbsents > 0
                        ? Colors.orange[100]
                        : Colors.green[100],
                    child: Text(
                      '$nombreAbsents absent(s) sur ${_eleves.length} élève(s)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: nombreAbsents > 0
                            ? Colors.orange[900]
                            : Colors.green[900],
                      ),
                    ),
                  ),

                // ── Liste élèves ─────────────────────────
                Expanded(
                  child: _chargementListe
                      ? const Center(child: CircularProgressIndicator())
                      : _eleves.isEmpty
                          ? const Center(
                              child: Text(
                                'Sélectionnez une classe et une date',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _eleves.length,
                              itemBuilder: (context, index) {
                                final eleve  = _eleves[index];
                                final eleveId = eleve['id'] as int;
                                final estAbsent = _absents[eleveId] ?? false;
                                final estNotifie = _notifies[eleveId] ?? false;
                                final aTelephone =
                                    eleve['telephone_parent'] != null &&
                                    (eleve['telephone_parent'] as String)
                                        .isNotEmpty;

                                return Card(
                                  margin:
                                      const EdgeInsets.only(bottom: 8),
                                  color: estAbsent
                                      ? Colors.red[50]
                                      : null,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Row(
                                      children: [
                                        Checkbox(
                                          value: estAbsent,
                                          activeColor: Colors.red,
                                          onChanged: (v) {
                                            setState(() {
                                              _absents[eleveId] = v ?? false;
                                            });
                                          },
                                        ),
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
                                              if (!aTelephone)
                                                const Text(
                                                  'Pas de numéro parent',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.orange,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        // Bouton WhatsApp si absent
                                        if (estAbsent && aTelephone)
                                          estNotifie
                                              ? const Chip(
                                                  label: Text(
                                                    'Notifié ✓',
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.white),
                                                  ),
                                                  backgroundColor:
                                                      Colors.green,
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                )
                                              : IconButton(
                                                  icon: const Icon(
                                                    Icons.message,
                                                    color: Colors.green,
                                                  ),
                                                  tooltip:
                                                      'Notifier via WhatsApp',
                                                  onPressed: () =>
                                                      _notifierParent(eleve),
                                                ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),

                // ── Bouton enregistrer ───────────────────
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
                        label: const Text('Enregistrer les absences'),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}