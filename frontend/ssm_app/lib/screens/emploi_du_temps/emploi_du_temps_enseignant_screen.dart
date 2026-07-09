import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import '../../services/emploi_du_temps_service.dart';
import '../../services/annee_service.dart';
import '../../services/auth_service.dart';

const List<Map<String, dynamic>> _grilleHoraire = [
  {'debut': '07:00', 'fin': '08:00', 'recreation': false},
  {'debut': '08:00', 'fin': '09:00', 'recreation': false},
  {'debut': '09:00', 'fin': '10:00', 'recreation': false},
  {'debut': '10:00', 'fin': '10:15', 'recreation': true},
  {'debut': '10:00', 'fin': '11:00', 'recreation': false},
  {'debut': '11:00', 'fin': '12:00', 'recreation': false},
];

const List<Map<String, String>> _jours = [
  {'cle': 'lundi', 'label': 'Lundi'},
  {'cle': 'mardi', 'label': 'Mardi'},
  {'cle': 'mercredi', 'label': 'Mercredi'},
  {'cle': 'jeudi', 'label': 'Jeudi'},
  {'cle': 'vendredi', 'label': 'Vendredi'},
];

const List<Color> _paletteClasses = [
  Color(0xFFBBDEFB),
  Color(0xFFC8E6C9),
  Color(0xFFFFE0B2),
  Color(0xFFF8BBD0),
  Color(0xFFD1C4E9),
  Color(0xFFB2EBF2),
  Color(0xFFFFF9C4),
  Color(0xFFD7CCC8),
  Color(0xFFC5CAE9),
  Color(0xFFDCEDC8),
];

Color _couleurClasse(int classeId) {
  return _paletteClasses[classeId % _paletteClasses.length];
}

int _versMinutes(String hhmmss) {
  final parts = hhmmss.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

double _dureeHeures(String debut, String fin) {
  return (_versMinutes(fin) - _versMinutes(debut)) / 60.0;
}

class EmploiDuTempsEnseignantScreen extends StatefulWidget {
  const EmploiDuTempsEnseignantScreen({super.key});

  @override
  State<EmploiDuTempsEnseignantScreen> createState() =>
      _EmploiDuTempsEnseignantScreenState();
}

class _EmploiDuTempsEnseignantScreenState
    extends State<EmploiDuTempsEnseignantScreen> {
  int? _enseignantId;
  Color _couleurPrimaire = Colors.indigo;

  List<dynamic> _annees = [];
  int? _anneeId;
  Map<String, dynamic> _emploiDuTemps = {};

  bool _chargement = true;
  bool _chargementGrille = false;
  bool _exportEnCours = false;

  @override
  void initState() {
    super.initState();
    _chargerInitial();
  }

  Future<void> _chargerInitial() async {
    try {
      final utilisateur = await AuthService.getUtilisateur();
      _enseignantId = utilisateur!.id;

      final annees = await AnneeService.listerAnnees();
      final anneeEnCours = annees.firstWhere(
        (a) => a['statut'] == 'en_cours',
        orElse: () => annees.isNotEmpty ? annees.first : null,
      );

      setState(() {
        _annees = annees;
        _anneeId = anneeEnCours?['id'] as int?;
        _couleurPrimaire = Color(
          int.parse(utilisateur.couleurPrimaire.replaceAll('#', '0xFF')),
        );
        _chargement = false;
      });

      if (_anneeId != null) await _chargerGrille();
    } catch (e) {
      setState(() => _chargement = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _chargerGrille() async {
    if (_anneeId == null || _enseignantId == null) return;
    setState(() => _chargementGrille = true);
    try {
      final data = await EmploiDuTempsService.parEnseignant(
        enseignantId: _enseignantId!,
        anneeId: _anneeId!,
      );
      setState(() {
        _emploiDuTemps = data;
        _chargementGrille = false;
      });
    } catch (e) {
      setState(() => _chargementGrille = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _afficherErreur(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  dynamic _creneauPourCellule(String jour, String heureDebut) {
    final liste = (_emploiDuTemps[jour] as List?) ?? [];
    return liste.firstWhere(
      (c) => (c['heure_debut'] as String).substring(0, 5) == heureDebut,
      orElse: () => null,
    );
  }

  List<dynamic> get _tousCreneaux {
    return _emploiDuTemps.values.expand((l) => (l as List)).toList();
  }

  double get _totalHeures {
    var total = 0.0;
    for (final c in _tousCreneaux) {
      total += _dureeHeures(c['heure_debut'] as String, c['heure_fin'] as String);
    }
    return total;
  }

  Map<String, double> get _heuresParClasse {
    final map = <String, double>{};
    for (final c in _tousCreneaux) {
      final nom = c['classe_nom'] as String;
      map[nom] = (map[nom] ?? 0) +
          _dureeHeures(c['heure_debut'] as String, c['heure_fin'] as String);
    }
    return map;
  }

  String _formatHeures(double h) {
    return h == h.roundToDouble() ? '${h.toInt()}h' : '${h.toStringAsFixed(1)}h';
  }

  Future<void> _exporterPdf() async {
    if (_anneeId == null) return;
    setState(() => _exportEnCours = true);
    try {
      final chemin = await EmploiDuTempsService.telechargerPdfEnseignant(
        anneeId: _anneeId!,
      );
      await OpenFile.open(chemin);
    } catch (e) {
      _afficherErreur('Erreur export PDF : $e');
    } finally {
      if (mounted) setState(() => _exportEnCours = false);
    }
  }

  Widget _celluleCreneau(String jour, String heureDebut, String heureFin) {
    final creneau = _creneauPourCellule(jour, heureDebut);

    return Expanded(
      child: Container(
        height: 60,
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: creneau != null
              ? _couleurClasse(creneau['classe_id'] as int)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: creneau != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${creneau['matiere_nom']} — ${creneau['classe_nom']}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 10),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (creneau['salle'] != null)
                    Text(
                      creneau['salle'] as String,
                      style: const TextStyle(fontSize: 8, color: Colors.black54),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              )
            : null,
      ),
    );
  }

  Widget _ligneRecreation(String debut, String fin) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amber[100],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          '🔶 $debut - $fin RÉCRÉATION',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
            color: Colors.amber[900],
          ),
        ),
      ),
    );
  }

  Widget _grilleEmploiDuTemps() {
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 80),
            ..._jours.map((j) => Expanded(
                  child: Center(
                    child: Text(
                      j['label']!,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                )),
          ],
        ),
        const SizedBox(height: 4),
        ..._grilleHoraire.map((row) {
          final debut = row['debut'] as String;
          final fin = row['fin'] as String;
          final recreation = row['recreation'] as bool;

          if (recreation) return _ligneRecreation(debut, fin);

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 80,
                child: Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(
                    '$debut\n$fin',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
              ),
              ..._jours.map((j) => _celluleCreneau(j['cle']!, debut, fin)),
            ],
          );
        }),
      ],
    );
  }

  Widget _sectionResume() {
    final heuresParClasse = _heuresParClasse;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _couleurPrimaire.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _couleurPrimaire.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total : ${_formatHeures(_totalHeures)} par semaine',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: _couleurPrimaire,
            ),
          ),
          const SizedBox(height: 10),
          if (heuresParClasse.isEmpty)
            const Text('Aucun cours cette semaine',
                style: TextStyle(color: Colors.grey))
          else
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: heuresParClasse.entries.map((entry) {
                return Text(
                  '${entry.key} : ${_formatHeures(entry.value)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon emploi du temps'),
        backgroundColor: _couleurPrimaire,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _exportEnCours
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.picture_as_pdf),
            tooltip: 'Mon emploi du temps PDF',
            onPressed: _exportEnCours || _anneeId == null ? null : _exporterPdf,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerGrille,
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
                      isDense: true,
                    ),
                    items: _annees.map((a) {
                      return DropdownMenuItem<int>(
                        value: a['id'] as int,
                        child: Text(a['libelle'] as String),
                      );
                    }).toList(),
                    onChanged: (v) {
                      setState(() => _anneeId = v);
                      _chargerGrille();
                    },
                  ),
                ),
                Expanded(
                  child: _chargementGrille
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SizedBox(
                                  width: 80 + (5 * 130),
                                  child: _grilleEmploiDuTemps(),
                                ),
                              ),
                              const SizedBox(height: 20),
                              _sectionResume(),
                            ],
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
