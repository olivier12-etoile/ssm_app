import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import '../../services/emploi_du_temps_service.dart';
import '../../services/classe_matiere_service.dart';
import '../../services/affectation_service.dart';
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

const List<Color> _paletteMatieres = [
  Color(0xFFBBDEFB), // bleu clair
  Color(0xFFC8E6C9), // vert clair
  Color(0xFFFFE0B2), // orange clair
  Color(0xFFF8BBD0), // rose clair
  Color(0xFFD1C4E9), // violet clair
  Color(0xFFB2EBF2), // cyan clair
  Color(0xFFFFF9C4), // jaune clair
  Color(0xFFD7CCC8), // marron clair
  Color(0xFFC5CAE9), // indigo clair
  Color(0xFFDCEDC8), // vert lime clair
];

Color _couleurMatiere(int matiereId) {
  return _paletteMatieres[matiereId % _paletteMatieres.length];
}

class EmploiDuTempsClasseScreen extends StatefulWidget {
  final int classeId;
  final String classeNom;

  const EmploiDuTempsClasseScreen({
    super.key,
    required this.classeId,
    required this.classeNom,
  });

  @override
  State<EmploiDuTempsClasseScreen> createState() =>
      _EmploiDuTempsClasseScreenState();
}

class _EmploiDuTempsClasseScreenState
    extends State<EmploiDuTempsClasseScreen> {
  List<dynamic> _annees = [];
  int? _anneeId;
  Color _couleurPrimaire = Colors.indigo;

  List<dynamic> _matieresClasse = [];
  List<dynamic> _affectations = [];
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
      final resultats = await Future.wait([
        AnneeService.listerAnnees(),
        ClasseMatiereService.listerParClasse(widget.classeId),
        AffectationService.listerParClasse(widget.classeId),
      ]);

      final annees = resultats[0];
      final anneeEnCours = annees.firstWhere(
        (a) => a['statut'] == 'en_cours',
        orElse: () => annees.isNotEmpty ? annees.first : null,
      );

      setState(() {
        _annees = annees;
        _anneeId = anneeEnCours?['id'] as int?;
        _matieresClasse = resultats[1];
        _affectations = resultats[2];
        if (utilisateur != null) {
          _couleurPrimaire = Color(
            int.parse(utilisateur.couleurPrimaire.replaceAll('#', '0xFF')),
          );
        }
        _chargement = false;
      });

      if (_anneeId != null) await _chargerGrille();
    } catch (e) {
      setState(() => _chargement = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _chargerGrille() async {
    if (_anneeId == null) return;
    setState(() => _chargementGrille = true);
    try {
      final data = await EmploiDuTempsService.parClasse(
        classeId: widget.classeId,
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

  void _afficherSucces(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green),
    );
  }

  dynamic _creneauPourCellule(String jour, String heureDebut) {
    final liste = (_emploiDuTemps[jour] as List?) ?? [];
    return liste.firstWhere(
      (c) => (c['heure_debut'] as String).substring(0, 5) == heureDebut,
      orElse: () => null,
    );
  }

  List<dynamic> _enseignantsPourMatiere(int? matiereId) {
    if (matiereId == null) return [];
    final vues = <int>{};
    final liste = <dynamic>[];
    for (final a in _affectations) {
      if (a['matiere_id'] != matiereId) continue;
      final id = a['enseignant_id'] as int;
      if (vues.add(id)) liste.add(a);
    }
    return liste;
  }

  Future<void> _exporterPdf() async {
    if (_anneeId == null) return;
    setState(() => _exportEnCours = true);
    try {
      final chemin = await EmploiDuTempsService.telechargerPdf(
        classeId: widget.classeId,
        anneeId: _anneeId!,
      );
      await OpenFile.open(chemin);
    } catch (e) {
      _afficherErreur('Erreur export PDF : $e');
    } finally {
      if (mounted) setState(() => _exportEnCours = false);
    }
  }

  Future<void> _afficherDialogCellule(
    String jour,
    String jourLabel,
    String heureDebut,
    String heureFin,
  ) async {
    final creneau = _creneauPourCellule(jour, heureDebut);

    if (creneau != null) {
      await _afficherDialogCreneauOccupe(
          jour, jourLabel, heureDebut, heureFin, creneau);
    } else {
      await _afficherDialogAjout(jour, jourLabel, heureDebut, heureFin);
    }
  }

  Future<void> _afficherDialogCreneauOccupe(
    String jour,
    String jourLabel,
    String heureDebut,
    String heureFin,
    dynamic creneau,
  ) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$jourLabel $heureDebut - $heureFin'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Matière : ${creneau['matiere_nom']}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Enseignant : ${creneau['enseignant_nom']}'),
            if (creneau['salle'] != null) ...[
              const SizedBox(height: 4),
              Text('Salle : ${creneau['salle']}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            icon: const Icon(Icons.delete, size: 18),
            label: const Text('Supprimer'),
            onPressed: () async {
              Navigator.pop(context);
              await _confirmerSuppression(creneau);
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Modifier'),
            onPressed: () {
              Navigator.pop(context);
              _afficherDialogAjout(jour, jourLabel, heureDebut, heureFin,
                  creneauExistant: creneau);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmerSuppression(dynamic creneau) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce cours'),
        content: Text(
          'Supprimer le cours de ${creneau['matiere_nom']} avec ${creneau['enseignant_nom']} ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirme != true) return;

    try {
      await EmploiDuTempsService.supprimer(creneau['id'] as int);
      _afficherSucces('Cours supprimé avec succès');
      _chargerGrille();
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _afficherDialogAjout(
    String jour,
    String jourLabel,
    String heureDebut,
    String heureFin, {
    dynamic creneauExistant,
  }) async {
    if (_anneeId == null) {
      _afficherErreur('Aucune année académique active');
      return;
    }

    int? matiereId = creneauExistant?['matiere_id'] as int?;
    int? enseignantId = creneauExistant?['enseignant_id'] as int?;
    final salleController =
        TextEditingController(text: creneauExistant?['salle'] as String? ?? '');
    bool verificationEnCours = false;
    bool? disponible;
    String? messageConflit;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final enseignants = _enseignantsPourMatiere(matiereId);

          return AlertDialog(
            title: Text(
              creneauExistant != null
                  ? 'Modifier — $jourLabel $heureDebut-$heureFin'
                  : 'Ajouter un cours — $jourLabel $heureDebut-$heureFin',
            ),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      value: matiereId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Matière',
                        prefixIcon: Icon(Icons.book),
                        border: OutlineInputBorder(),
                      ),
                      hint: const Text('Choisir une matière'),
                      items: _matieresClasse.map((m) {
                        return DropdownMenuItem<int>(
                          value: m['matiere_id'] as int,
                          child: Text(m['matiere_nom'] as String),
                        );
                      }).toList(),
                      onChanged: (v) => setStateDialog(() {
                        matiereId = v;
                        enseignantId = null;
                        disponible = null;
                        messageConflit = null;
                      }),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: enseignantId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Enseignant',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      hint: const Text('Choisir un enseignant'),
                      items: enseignants.map((a) {
                        return DropdownMenuItem<int>(
                          value: a['enseignant_id'] as int,
                          child: Text(a['enseignant_nom'] as String),
                        );
                      }).toList(),
                      onChanged: enseignants.isEmpty
                          ? null
                          : (v) => setStateDialog(() {
                                enseignantId = v;
                                disponible = null;
                                messageConflit = null;
                              }),
                    ),
                    if (matiereId != null && enseignants.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'Aucun enseignant affecté à cette matière pour cette classe',
                          style: TextStyle(color: Colors.orange, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: salleController,
                      decoration: const InputDecoration(
                        labelText: 'Salle (optionnel)',
                        prefixIcon: Icon(Icons.room),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (messageConflit != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Text(
                          messageConflit!,
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    ],
                    if (disponible == true) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: const Text(
                          'Créneau disponible ✓',
                          style: TextStyle(color: Colors.green, fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              if (disponible != true)
                OutlinedButton(
                  onPressed: matiereId == null ||
                          enseignantId == null ||
                          verificationEnCours
                      ? null
                      : () async {
                          setStateDialog(() => verificationEnCours = true);
                          try {
                            final resultat =
                                await EmploiDuTempsService.verifierConflits(
                              enseignantId: enseignantId!,
                              anneeAcademiqueId: _anneeId!,
                              jour: jour,
                              heureDebut: heureDebut,
                              heureFin: heureFin,
                              excludeId: creneauExistant?['id'] as int?,
                            );
                            setStateDialog(() {
                              verificationEnCours = false;
                              disponible = resultat['disponible'] as bool;
                              messageConflit = disponible == true
                                  ? null
                                  : resultat['message'] as String?;
                            });
                          } catch (e) {
                            setStateDialog(() => verificationEnCours = false);
                          }
                        },
                  child: verificationEnCours
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Vérifier disponibilité'),
                ),
              if (disponible == true)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    try {
                      await EmploiDuTempsService.enregistrer(
                        classeId: widget.classeId,
                        anneeAcademiqueId: _anneeId!,
                        jour: jour,
                        heureDebut: heureDebut,
                        heureFin: heureFin,
                        matiereId: matiereId!,
                        enseignantId: enseignantId!,
                        salle: salleController.text.isEmpty
                            ? null
                            : salleController.text,
                      );
                      if (context.mounted) Navigator.pop(context);
                      _afficherSucces('Cours enregistré avec succès');
                      _chargerGrille();
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

  Widget _celluleCreneau(String jour, String heureDebut, String heureFin) {
    final creneau = _creneauPourCellule(jour, heureDebut);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          final jourLabel =
              _jours.firstWhere((j) => j['cle'] == jour)['label']!;
          _afficherDialogCellule(jour, jourLabel, heureDebut, heureFin);
        },
        child: Container(
          height: 66,
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: creneau != null
                ? _couleurMatiere(creneau['matiere_id'] as int)
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
                      creneau['matiere_nom'] as String,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      creneau['enseignant_nom'] as String,
                      style: const TextStyle(fontSize: 9, color: Colors.black87),
                      maxLines: 1,
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
              : const Center(
                  child: Icon(Icons.add, color: Colors.grey, size: 20),
                ),
        ),
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
        // ── En-tête jours ──────────────────────────────
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
        // ── Lignes de créneaux ──────────────────────────
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
                  padding: const EdgeInsets.only(top: 22),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Emploi du temps — ${widget.classeNom}'),
        backgroundColor: _couleurPrimaire,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _exportEnCours
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child:
                        CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.picture_as_pdf),
            tooltip: 'Imprimer PDF',
            onPressed: _exportEnCours ? null : _exporterPdf,
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
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: 80 + (5 * 140),
                              child: _grilleEmploiDuTemps(),
                            ),
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
