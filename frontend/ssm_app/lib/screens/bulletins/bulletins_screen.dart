import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import '../../services/bulletin_service.dart';
import '../../services/eleve_service.dart';
import '../../services/classe_service.dart';
import '../../services/annee_service.dart';
import '../../services/appreciation_service.dart';

class BulletinsScreen extends StatefulWidget {
  const BulletinsScreen({super.key});

  @override
  State<BulletinsScreen> createState() => _BulletinsScreenState();
}

class _BulletinsScreenState extends State<BulletinsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Données
  List<dynamic> _eleves   = [];
  List<dynamic> _classes  = [];
  List<dynamic> _annees   = [];
  List<dynamic> _periodes = [];
  bool _chargement        = true;

  // Sélections bulletin élève
  int? _eleveId;
  int? _periodeIdEleve;
  int? _anneeIdEleve;
  Map<String, dynamic>? _bulletin;
  bool _chargementBulletin = false;
  bool _telechargementPdf  = false;
  bool _envoiNotification  = false;

  // Sélections bulletin classe
  int? _classeId;
  int? _periodeIdClasse;
  int? _anneeIdClasse;
  Map<String, dynamic>? _bulletinsClasse;
  bool _chargementClasse = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _chargerDonnees();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _chargerDonnees() async {
    try {
      final resultats = await Future.wait([
        EleveService.listerEleves(),
        ClasseService.listerClasses(),
        AnneeService.listerAnnees(),
      ]);
      setState(() {
        _eleves    = resultats[0] as List;
        _classes   = resultats[1] as List;
        _annees    = resultats[2] as List;
        _chargement = false;
      });
    } catch (e) {
      setState(() => _chargement = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _chargerPeriodes(int anneeId, bool pourClasse) async {
    try {
      final liste = await AnneeService.listerPeriodes(anneeId);
      setState(() {
        _periodes = liste;
        if (pourClasse) {
          _periodeIdClasse = null;
        } else {
          _periodeIdEleve = null;
        }
      });
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _genererBulletinEleve() async {
    if (_eleveId == null || _periodeIdEleve == null) {
      _afficherErreur('Sélectionnez un élève et une période');
      return;
    }

    setState(() => _chargementBulletin = true);

    try {
      final data = await BulletinService.genererBulletin(
        eleveId:   _eleveId!,
        periodeId: _periodeIdEleve!,
      );
      setState(() {
        _bulletin           = data;
        _chargementBulletin = false;
      });
    } catch (e) {
      setState(() => _chargementBulletin = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _genererBulletinsClasse() async {
    if (_classeId == null || _periodeIdClasse == null) {
      _afficherErreur('Sélectionnez une classe et une période');
      return;
    }

    setState(() => _chargementClasse = true);

    try {
      final data = await BulletinService.bulletinsClasse(
        classeId:  _classeId!,
        periodeId: _periodeIdClasse!,
      );
      setState(() {
        _bulletinsClasse  = data;
        _chargementClasse = false;
      });
    } catch (e) {
      setState(() => _chargementClasse = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ── Télécharger et ouvrir le PDF ────────────────────────
  Future<void> _telechargerPdf(Map<String, dynamic> bulletin) async {
    setState(() => _telechargementPdf = true);

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Génération du PDF...')),
      );

      final chemin = await BulletinService.telechargerPdf(
        eleveId:   bulletin['eleve']['id'] as int,
        periodeId: _periodeIdEleve!,
      );

      await OpenFile.open(chemin);
    } catch (e) {
      _afficherErreur('Erreur téléchargement PDF: $e');
    } finally {
      if (mounted) setState(() => _telechargementPdf = false);
    }
  }

  // ── Notifier le parent (ajoute à la file d'attente) ─────
  Future<void> _notifierParent(Map<String, dynamic> bulletin) async {
    setState(() => _envoiNotification = true);
    try {
      await BulletinService.notifierBulletin(
        eleveId:   bulletin['eleve']['id'] as int,
        periodeId: _periodeIdEleve!,
      );
      _afficherSucces(
          'Notification ajoutée — à retrouver dans "Notifications à envoyer"');
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _envoiNotification = false);
    }
  }

  // ── Dialog appréciations ────────────────────────────────
  Future<void> _afficherDialogAppreciation(
      Map<String, dynamic> bulletin) async {
    final eleveId   = bulletin['eleve']['id'] as int;
    final periodeId = _periodeIdEleve!;
    final moyenne   = (bulletin['moyenne_generale'] as num).toDouble();

    final enseignantController = TextEditingController(
      text: bulletin['appreciation_enseignant'] as String? ?? '',
    );
    final directeurController = TextEditingController(
      text: bulletin['appreciation_directeur'] as String? ?? '',
    );
    String? observationSelectionnee = bulletin['observation'] as String?;

    // Suggestion automatique si vide
    if (observationSelectionnee == null) {
      try {
        observationSelectionnee =
            await AppreciationService.suggererObservation(moyenne);
      } catch (_) {}
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Appréciations du bulletin'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Observation suggérée
                    DropdownButtonFormField<String>(
                      value: observationSelectionnee,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Observation',
                        prefixIcon: Icon(Icons.star),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        'Félicitations',
                        'Encouragements',
                        'Tableau d\'honneur',
                        'Travail satisfaisant',
                        'Doit fournir davantage d\'efforts',
                        'Avertissement - Travail insuffisant',
                      ].map((o) {
                        return DropdownMenuItem(value: o, child: Text(o));
                      }).toList(),
                      onChanged: (v) =>
                          setStateDialog(() => observationSelectionnee = v),
                    ),
                    const SizedBox(height: 16),

                    // Appréciation enseignant
                    TextField(
                      controller: enseignantController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Appréciation Enseignant',
                        hintText: 'Ex: Élève sérieux et appliqué...',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Appréciation directeur
                    TextField(
                      controller: directeurController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Appréciation Directeur',
                        hintText: 'Ex: Bon trimestre, continuez ainsi...',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
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
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  try {
                    await AppreciationService.enregistrer(
                      eleveId:                 eleveId,
                      periodeId:               periodeId,
                      appreciationEnseignant:  enseignantController.text,
                      appreciationDirecteur:   directeurController.text,
                      observation:             observationSelectionnee,
                    );
                    Navigator.pop(context);
                    _afficherSucces('Appréciation enregistrée');
                    // Recharger le bulletin pour voir les changements
                    _genererBulletinEleve();
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

  Color _couleurMention(String mention) {
    switch (mention) {
      case 'Excellent':   return Colors.green[700]!;
      case 'Très Bien':   return Colors.green;
      case 'Bien':        return Colors.lightGreen;
      case 'Assez Bien':  return Colors.orange;
      case 'Passable':    return Colors.amber;
      default:            return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulletins'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: 'Par élève'),
            Tab(icon: Icon(Icons.class_), text: 'Par classe'),
          ],
        ),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _ongletEleve(),
                _ongletClasse(),
              ],
            ),
    );
  }

  // ── Onglet Bulletin par élève ───────────────────────────
  Widget _ongletEleve() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filtres
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Élève
                  DropdownButtonFormField<int>(
                    value: _eleveId,
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
                    onChanged: (v) => setState(() => _eleveId = v),
                  ),
                  const SizedBox(height: 12),

                  // Année
                  DropdownButtonFormField<int>(
                    value: _anneeIdEleve,
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
                    onChanged: (v) {
                      setState(() => _anneeIdEleve = v);
                      if (v != null) _chargerPeriodes(v, false);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Période
                  DropdownButtonFormField<int>(
                    value: _periodeIdEleve,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Période',
                      prefixIcon: Icon(Icons.segment),
                      border: OutlineInputBorder(),
                    ),
                    hint: const Text('Choisir une période'),
                    items: _periodes.map((p) {
                      return DropdownMenuItem<int>(
                        value: p['id'] as int,
                        child: Text(p['nom'] as String),
                      );
                    }).toList(),
                    onChanged: (v) =>
                        setState(() => _periodeIdEleve = v),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _genererBulletinEleve,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.description),
                      label: const Text('Générer le bulletin'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Résultat bulletin
          if (_chargementBulletin)
            const Center(child: CircularProgressIndicator())
          else if (_bulletin != null)
            _afficherBulletin(_bulletin!),
        ],
      ),
    );
  }

  Widget _afficherBulletin(Map<String, dynamic> bulletin) {
    final moyenneGenerale = bulletin['moyenne_generale'] as num;
    final mention         = bulletin['mention_generale'] as String;
    final notes           = bulletin['notes'] as List;
    final aAppreciation   = bulletin['appreciation_enseignant'] != null ||
        bulletin['appreciation_directeur'] != null;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête école
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.deepPurple,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bulletin['ecole']['nom'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Code : ${bulletin['ecole']['code_ecole']}',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Infos élève
            _ligneInfo('Élève',
                '${bulletin['eleve']['nom']} ${bulletin['eleve']['prenom']}'),
            _ligneInfo('Matricule', bulletin['eleve']['matricule']),
            _ligneInfo('Classe', bulletin['classe']),
            _ligneInfo('Période', bulletin['periode']['nom']),
            _ligneInfo('Année', bulletin['annee']),
            const Divider(height: 24),

            // Tableau des notes
            const Text(
              'Relevé de notes',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),

            // En-tête tableau
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.deepPurple,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text('Matière',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text('Coef',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center),
                  ),
                  SizedBox(
                    width: 50,
                    child: Text('Note',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text('Mention',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // Lignes notes
            ...notes.asMap().entries.map((entry) {
              final i    = entry.key;
              final note = entry.value;
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: i % 2 == 0
                      ? Colors.deepPurple.withOpacity(0.05)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(note['matiere'] as String),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '${note['coefficient']}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(
                      width: 50,
                      child: Text(
                        '${note['note']}/20',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      child: Text(
                        note['mention'] as String,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: _couleurMention(
                              note['mention'] as String),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

            const Divider(height: 24),

            // Moyenne générale
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _couleurMention(mention).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: _couleurMention(mention).withOpacity(0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Moyenne Générale',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$moyenneGenerale/20',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: _couleurMention(mention),
                        ),
                      ),
                      Text(
                        mention,
                        style: TextStyle(
                          color: _couleurMention(mention),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Aperçu appréciations si déjà saisies ──────
            if (aAppreciation) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.deepPurple.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (bulletin['observation'] != null) ...[
                      Text(
                        (bulletin['observation'] as String).toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (bulletin['appreciation_enseignant'] != null) ...[
                      const Text('Enseignant :',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey)),
                      Text(
                          bulletin['appreciation_enseignant'] as String),
                      const SizedBox(height: 6),
                    ],
                    if (bulletin['appreciation_directeur'] != null) ...[
                      const Text('Directeur :',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey)),
                      Text(
                          bulletin['appreciation_directeur'] as String),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Bouton appréciations
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _afficherDialogAppreciation(bulletin),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.deepPurple,
                  side: const BorderSide(color: Colors.deepPurple),
                  padding: const EdgeInsets.all(14),
                ),
                icon: const Icon(Icons.rate_review),
                label: Text(
                  aAppreciation
                      ? 'Modifier les appréciations'
                      : 'Ajouter des appréciations',
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ← AJOUTÉ : Bouton notifier le parent
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _envoiNotification
                    ? null
                    : () => _notifierParent(bulletin),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green[700],
                  side: BorderSide(color: Colors.green[700]!),
                  padding: const EdgeInsets.all(14),
                ),
                icon: _envoiNotification
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.green[700],
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.notifications_active),
                label: Text(_envoiNotification
                    ? 'Ajout en cours...'
                    : 'Notifier le parent'),
              ),
            ),

            const SizedBox(height: 12),

            // Bouton télécharger PDF
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _telechargementPdf
                    ? null
                    : () => _telechargerPdf(bulletin),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(14),
                ),
                icon: _telechargementPdf
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.picture_as_pdf),
                label: Text(_telechargementPdf
                    ? 'Génération...'
                    : 'Télécharger le PDF'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ligneInfo(String label, String valeur) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label :',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          Text(
            valeur,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // ── Onglet Bulletins par classe ─────────────────────────
  Widget _ongletClasse() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Filtres
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: Padding(
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
                    value: _anneeIdClasse,
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
                    onChanged: (v) {
                      setState(() => _anneeIdClasse = v);
                      if (v != null) _chargerPeriodes(v, true);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Période
                  DropdownButtonFormField<int>(
                    value: _periodeIdClasse,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Période',
                      prefixIcon: Icon(Icons.segment),
                      border: OutlineInputBorder(),
                    ),
                    hint: const Text('Choisir une période'),
                    items: _periodes.map((p) {
                      return DropdownMenuItem<int>(
                        value: p['id'] as int,
                        child: Text(p['nom'] as String),
                      );
                    }).toList(),
                    onChanged: (v) =>
                        setState(() => _periodeIdClasse = v),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _genererBulletinsClasse,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.list_alt),
                      label: const Text('Générer les bulletins'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Résultat classe
          if (_chargementClasse)
            const Center(child: CircularProgressIndicator())
          else if (_bulletinsClasse != null)
            _afficherBulletinsClasse(_bulletinsClasse!),
        ],
      ),
    );
  }

  Widget _afficherBulletinsClasse(Map<String, dynamic> data) {
    final bulletins = data['bulletins'] as List;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Palmarès — ${data['periode']}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${bulletins.length} élève(s)',
              style: const TextStyle(color: Colors.grey),
            ),
            const Divider(height: 16),

            // En-tête
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.deepPurple,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Text('Rang',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center),
                  ),
                  Expanded(
                    child: Text('Élève',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ),
                  SizedBox(
                    width: 70,
                    child: Text('Moyenne',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text('Mention',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // Lignes élèves
            ...bulletins.asMap().entries.map((entry) {
              final i = entry.key;
              final b = entry.value;
              final rang    = b['rang'] as int;
              final moyenne = b['moyenne'] as num;
              final mention = b['mention'] as String;

              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: rang <= 3
                      ? Colors.amber.withOpacity(0.1)
                      : i % 2 == 0
                          ? Colors.deepPurple.withOpacity(0.03)
                          : Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: rang <= 3
                            ? Colors.amber
                            : Colors.deepPurple.withOpacity(0.1),
                        child: Text(
                          '$rang',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: rang <= 3
                                ? Colors.white
                                : Colors.deepPurple,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${b['nom']} ${b['prenom']}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                    SizedBox(
                      width: 70,
                      child: Text(
                        '$moyenne/20',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _couleurMention(mention),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      child: Text(
                        mention,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: _couleurMention(mention),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}