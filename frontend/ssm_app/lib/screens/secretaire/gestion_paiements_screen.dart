import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import '../../services/paiement_service.dart';
import '../../services/frais_scolaire_service.dart';
import '../../services/eleve_service.dart';
import '../../services/classe_service.dart';
import '../../services/annee_service.dart';
import '../../services/whatsapp_service.dart';
import '../../services/auth_service.dart';

const List<String> _moisFrancais = [
  'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
  'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
];

String _libelleStatut(String statut) {
  switch (statut) {
    case 'en_regle': return 'En règle ✅';
    case 'partiel':  return 'Partiel ⚠️';
    case 'non_paye': return 'Non payé ❌';
    default:         return statut;
  }
}

Color _couleurStatut(String statut) {
  switch (statut) {
    case 'en_regle': return Colors.green;
    case 'partiel':  return Colors.orange;
    case 'non_paye': return Colors.red;
    default:         return Colors.grey;
  }
}

String _formatDate(DateTime d) {
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

class GestionPaiementsScreen extends StatefulWidget {
  const GestionPaiementsScreen({super.key});

  @override
  State<GestionPaiementsScreen> createState() =>
      _GestionPaiementsScreenState();
}

class _GestionPaiementsScreenState extends State<GestionPaiementsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<dynamic> _classes = [];
  List<dynamic> _annees = [];
  int? _anneeIdEnCours;
  String _nomEcole = '';
  bool _chargementInitial = true;

  // ── Onglet 1 : Paiements ──────────────────────────────
  List<dynamic> _paiements = [];
  int? _filtreClasseId;
  int? _filtreMois;
  List<dynamic> _elevesFiltre = [];
  bool _chargementPaiements = false;
  int? _telechargementEnCours;

  // ── Onglet 2 : Situation des élèves ───────────────────
  int? _situationClasseId;
  Map<String, dynamic>? _situationData;
  List<dynamic> _elevesInfoClasse = [];
  bool _chargementSituation = false;
  String _filtreStatut = 'tous';

  // ── Onglet 3 : Rapport financier ──────────────────────
  int? _rapportAnneeId;
  int? _rapportMois;
  Map<String, dynamic>? _rapportData;
  bool _chargementRapport = false;
  bool _exportEnCours = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _chargerInitial();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _chargerInitial() async {
    try {
      final utilisateur = await AuthService.getUtilisateur();
      final resultats = await Future.wait([
        ClasseService.listerClasses(),
        AnneeService.listerAnnees(),
      ]);
      final classes = resultats[0];
      final annees = resultats[1];
      final anneeEnCours = annees.firstWhere(
        (a) => a['statut'] == 'en_cours',
        orElse: () => annees.isNotEmpty ? annees.first : null,
      );

      setState(() {
        _classes = classes;
        _annees = annees;
        _anneeIdEnCours = anneeEnCours?['id'] as int?;
        _rapportAnneeId = _anneeIdEnCours;
        _nomEcole = utilisateur?.codeEcole ?? '';
        _chargementInitial = false;
      });

      await _chargerPaiements();
    } catch (e) {
      setState(() => _chargementInitial = false);
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

  String _nomClasse(int? classeId) {
    final classe = _classes.firstWhere(
      (c) => c['id'] == classeId,
      orElse: () => null,
    );
    return classe != null ? classe['nom'] as String : '';
  }

  // ══════════════════════════════════════════════════════
  // ONGLET 1 — Paiements
  // ══════════════════════════════════════════════════════

  Future<void> _chargerPaiements() async {
    setState(() => _chargementPaiements = true);
    try {
      final paiements = await PaiementService.listerPaiements();
      setState(() {
        _paiements = paiements;
        _chargementPaiements = false;
      });
    } catch (e) {
      setState(() => _chargementPaiements = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _onFiltreClasseChange(int? classeId) async {
    setState(() {
      _filtreClasseId = classeId;
      _elevesFiltre = [];
    });
    if (classeId != null && _anneeIdEnCours != null) {
      final liste =
          await EleveService.elevesParClasse(classeId, _anneeIdEnCours!);
      setState(() => _elevesFiltre = liste);
    }
  }

  List<dynamic> get _paiementsFiltres {
    var liste = _paiements;
    if (_filtreClasseId != null) {
      final ids = _elevesFiltre.map((e) => e['id']).toSet();
      liste = liste.where((p) => ids.contains(p['eleve']?['id'])).toList();
    }
    if (_filtreMois != null) {
      liste = liste.where((p) {
        final d = DateTime.tryParse(p['date_paiement'].toString());
        return d != null && d.month == _filtreMois;
      }).toList();
    }
    return liste;
  }

  Future<void> _telechargerRecu(int paiementId) async {
    setState(() => _telechargementEnCours = paiementId);
    try {
      final chemin = await PaiementService.telechargerRecuPdf(paiementId);
      await OpenFile.open(chemin);
    } catch (e) {
      _afficherErreur('Erreur téléchargement reçu : $e');
    } finally {
      if (mounted) setState(() => _telechargementEnCours = null);
    }
  }

  Future<void> _afficherDialogPaiement({
    int? classeIdPreselectionne,
    int? eleveIdPreselectionne,
  }) async {
    if (_anneeIdEnCours == null) {
      _afficherErreur('Aucune année académique active');
      return;
    }

    final resultat = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _DialogNouveauPaiement(
        classes: _classes,
        anneeIdEnCours: _anneeIdEnCours!,
        classeIdPreselectionne: classeIdPreselectionne,
        eleveIdPreselectionne: eleveIdPreselectionne,
      ),
    );

    if (resultat == null || !mounted) return;

    _afficherSucces('Paiement enregistré avec succès');
    _chargerPaiements();
    if (_situationClasseId != null) _chargerSituationClasse();

    final eleve = resultat['eleve'];
    final telephoneParent = eleve?['telephone_parent'] as String?;
    if (eleve == null || telephoneParent == null || telephoneParent.isEmpty) {
      return;
    }

    final envoyer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Envoyer un reçu WhatsApp ?'),
        content: Text(
          'Envoyer une confirmation de paiement à ${eleve['nom']} ${eleve['prenom']} par WhatsApp ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Oui, envoyer',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (envoyer != true) return;

    final message = WhatsAppService.messageRecuPaiement(
      nomParent: 'Cher parent',
      nomEleve: '${eleve['nom']} ${eleve['prenom']}',
      classe: resultat['classe_nom'] as String? ?? '',
      montant: '${resultat['montant']}',
      tranche: resultat['tranche_label'] as String? ?? '',
      nomEcole: 'École (Code : $_nomEcole)',
    );

    final succes = await WhatsAppService.envoyerMessage(
      numeroTelephone: telephoneParent,
      message: message,
    );

    if (!succes && mounted) {
      _afficherErreur('Impossible d\'ouvrir WhatsApp');
    }
  }

  Widget _ongletPaiements() {
    return Column(
      children: [
        Container(
          color: Colors.teal.withOpacity(0.05),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int?>(
                  value: _filtreClasseId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Classe',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Toutes les classes'),
                    ),
                    ..._classes.map((c) => DropdownMenuItem<int?>(
                          value: c['id'] as int,
                          child: Text(c['nom'] as String),
                        )),
                  ],
                  onChanged: _onFiltreClasseChange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int?>(
                  value: _filtreMois,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Mois',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Tous les mois'),
                    ),
                    ...List.generate(12, (i) => i + 1).map((m) {
                      return DropdownMenuItem<int?>(
                        value: m,
                        child: Text(_moisFrancais[m - 1]),
                      );
                    }),
                  ],
                  onChanged: (v) => setState(() => _filtreMois = v),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _chargementPaiements
              ? const Center(child: CircularProgressIndicator())
              : _paiementsFiltres.isEmpty
                  ? const Center(
                      child: Text('Aucun paiement trouvé',
                          style: TextStyle(color: Colors.grey)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: _paiementsFiltres.length,
                      itemBuilder: (context, index) {
                        final p = _paiementsFiltres[index];
                        final eleve = p['eleve'];
                        final paiementId = p['id'] as int;
                        final enregistrePar = p['enregistre_par'];
                        final photoUrl = eleve?['photo_url'] as String?;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            leading: CircleAvatar(
                              backgroundColor: Colors.teal,
                              backgroundImage:
                                  photoUrl != null ? NetworkImage(photoUrl) : null,
                              child: photoUrl == null
                                  ? const Icon(Icons.payment, color: Colors.white)
                                  : null,
                            ),
                            title: Text(
                              eleve != null
                                  ? '${eleve['nom']} ${eleve['prenom']}'
                                  : 'Élève inconnu',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${p['tranche']}  •  ${p['date_paiement']}'),
                                if (enregistrePar != null)
                                  Text(
                                    'Enregistré par ${enregistrePar['name']}',
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.grey),
                                  ),
                              ],
                            ),
                            isThreeLine: enregistrePar != null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${p['montant']} FCFA',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _telechargementEnCours == paiementId
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child:
                                            CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : IconButton(
                                        icon: const Icon(Icons.receipt_long,
                                            color: Colors.teal),
                                        tooltip: 'Télécharger le reçu',
                                        onPressed: () => _telechargerRecu(paiementId),
                                      ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  // ONGLET 2 — Situation des élèves
  // ══════════════════════════════════════════════════════

  Future<void> _chargerSituationClasse() async {
    if (_situationClasseId == null || _anneeIdEnCours == null) return;

    setState(() => _chargementSituation = true);
    try {
      final resultats = await Future.wait([
        FraisScolaireService.situationClasse(
          classeId: _situationClasseId!,
          anneeId: _anneeIdEnCours!,
        ),
        EleveService.elevesParClasse(_situationClasseId!, _anneeIdEnCours!),
      ]);

      setState(() {
        _situationData = resultats[0] as Map<String, dynamic>;
        _elevesInfoClasse = resultats[1] as List;
        _chargementSituation = false;
      });
    } catch (e) {
      setState(() => _chargementSituation = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  dynamic _infoEleve(int eleveId) {
    return _elevesInfoClasse.firstWhere(
      (e) => e['id'] == eleveId,
      orElse: () => null,
    );
  }

  List<dynamic> get _elevesFiltresParStatut {
    final eleves = (_situationData?['eleves'] as List?) ?? [];
    if (_filtreStatut == 'tous') return eleves;
    return eleves.where((e) => e['statut'] == _filtreStatut).toList();
  }

  Future<void> _notifierParent(dynamic eleveSituation) async {
    final info = _infoEleve(eleveSituation['eleve_id'] as int);
    final telephoneParent = info?['telephone_parent'] as String?;

    if (telephoneParent == null || telephoneParent.isEmpty) {
      _afficherErreur('Aucun numéro de téléphone parent enregistré');
      return;
    }

    final message = WhatsAppService.messageRappelPaiement(
      nomParent: 'Cher parent',
      nomEleve: '${eleveSituation['nom']} ${eleveSituation['prenom']}',
      classe: _nomClasse(_situationClasseId),
      montantDu: '${eleveSituation['montant_restant']}',
      dateLimit: 'dès que possible',
      nomEcole: 'École (Code : $_nomEcole)',
    );

    final succes = await WhatsAppService.envoyerMessage(
      numeroTelephone: telephoneParent,
      message: message,
    );

    if (!succes && mounted) {
      _afficherErreur('Impossible d\'ouvrir WhatsApp');
    }
  }

  Widget _ongletSituation() {
    final stats = _situationData?['statistiques'] as Map<String, dynamic>?;

    return Column(
      children: [
        Container(
          color: Colors.purple.withOpacity(0.05),
          padding: const EdgeInsets.all(16),
          child: DropdownButtonFormField<int>(
            value: _situationClasseId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Classe',
              prefixIcon: Icon(Icons.class_),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            hint: const Text('Choisir une classe'),
            items: _classes.map((c) {
              return DropdownMenuItem<int>(
                value: c['id'] as int,
                child: Text(c['nom'] as String),
              );
            }).toList(),
            onChanged: (v) {
              setState(() => _situationClasseId = v);
              if (v != null) _chargerSituationClasse();
            },
          ),
        ),
        if (stats != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  label: Text('Tous (${stats['total_eleves']})'),
                  selected: _filtreStatut == 'tous',
                  onSelected: (_) => setState(() => _filtreStatut = 'tous'),
                ),
                ChoiceChip(
                  label: Text('En règle ✅ (${stats['en_regle']})'),
                  selected: _filtreStatut == 'en_regle',
                  selectedColor: Colors.green[200],
                  onSelected: (_) => setState(() => _filtreStatut = 'en_regle'),
                ),
                ChoiceChip(
                  label: Text('Partiel ⚠️ (${stats['partiel']})'),
                  selected: _filtreStatut == 'partiel',
                  selectedColor: Colors.orange[200],
                  onSelected: (_) => setState(() => _filtreStatut = 'partiel'),
                ),
                ChoiceChip(
                  label: Text('Non payé ❌ (${stats['non_paye']})'),
                  selected: _filtreStatut == 'non_paye',
                  selectedColor: Colors.red[200],
                  onSelected: (_) => setState(() => _filtreStatut = 'non_paye'),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: _chargementSituation
              ? const Center(child: CircularProgressIndicator())
              : _situationClasseId == null
                  ? const Center(
                      child: Text('Sélectionnez une classe',
                          style: TextStyle(color: Colors.grey)),
                    )
                  : _elevesFiltresParStatut.isEmpty
                      ? const Center(
                          child: Text('Aucun élève pour ce filtre',
                              style: TextStyle(color: Colors.grey)),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _elevesFiltresParStatut.length,
                          itemBuilder: (context, index) {
                            final e = _elevesFiltresParStatut[index];
                            final montantDu =
                                double.tryParse(e['montant_du'].toString()) ?? 0;
                            final montantPaye =
                                double.tryParse(e['montant_paye'].toString()) ?? 0;
                            final progression =
                                montantDu > 0 ? (montantPaye / montantDu).clamp(0.0, 1.0) : 1.0;
                            final statut = e['statut'] as String;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${e['nom']} ${e['prenom']}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _couleurStatut(statut)
                                                .withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            _libelleStatut(statut),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: _couleurStatut(statut),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: progression,
                                        minHeight: 8,
                                        backgroundColor: Colors.grey[200],
                                        color: _couleurStatut(statut),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$montantPaye / $montantDu FCFA',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () => _afficherDialogPaiement(
                                              classeIdPreselectionne:
                                                  _situationClasseId,
                                              eleveIdPreselectionne:
                                                  e['eleve_id'] as int,
                                            ),
                                            icon: const Icon(Icons.payment, size: 16),
                                            label: const Text('Enregistrer paiement'),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: statut == 'en_regle'
                                                ? null
                                                : () => _notifierParent(e),
                                            icon: const Icon(Icons.message, size: 16),
                                            label: const Text('Notifier parent'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  // ONGLET 3 — Rapport financier
  // ══════════════════════════════════════════════════════

  Future<void> _chargerRapport() async {
    if (_rapportAnneeId == null) return;

    setState(() => _chargementRapport = true);
    try {
      final data = await FraisScolaireService.rapportFinancier(
        anneeId: _rapportAnneeId!,
        mois: _rapportMois,
      );
      setState(() {
        _rapportData = data;
        _chargementRapport = false;
      });
    } catch (e) {
      setState(() => _chargementRapport = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _exporterPdf() async {
    if (_rapportAnneeId == null) return;

    setState(() => _exportEnCours = true);
    try {
      final chemin = await FraisScolaireService.telechargerRapportPdf(
        anneeId: _rapportAnneeId!,
        mois: _rapportMois,
      );
      await OpenFile.open(chemin);
    } catch (e) {
      _afficherErreur('Erreur export PDF : $e');
    } finally {
      if (mounted) setState(() => _exportEnCours = false);
    }
  }

  Widget _ongletRapport() {
    final totalGlobal = _rapportData?['total_global'] as Map<String, dynamic>?;
    final parClasse = (_rapportData?['par_classe'] as List?) ?? [];

    final totalAttendu = double.tryParse(
            totalGlobal?['total_attendu']?.toString() ?? '0') ??
        0;
    final totalEncaisse = double.tryParse(
            totalGlobal?['total_encaisse']?.toString() ?? '0') ??
        0;
    final totalRestant = double.tryParse(
            totalGlobal?['total_restant']?.toString() ?? '0') ??
        0;
    final pourcentageRecouvrement =
        totalAttendu > 0 ? (totalEncaisse / totalAttendu * 100) : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _rapportAnneeId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Année académique',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _annees.map((a) {
                    return DropdownMenuItem<int>(
                      value: a['id'] as int,
                      child: Text(a['libelle'] as String),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _rapportAnneeId = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int?>(
                  value: _rapportMois,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Mois (optionnel)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Toute l\'année'),
                    ),
                    ...List.generate(12, (i) => i + 1).map((m) {
                      return DropdownMenuItem<int?>(
                        value: m,
                        child: Text(_moisFrancais[m - 1]),
                      );
                    }),
                  ],
                  onChanged: (v) => setState(() => _rapportMois = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _rapportAnneeId == null ? null : _chargerRapport,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.search),
            label: const Text('Charger le rapport'),
          ),
          const SizedBox(height: 20),
          if (_chargementRapport)
            const Center(child: CircularProgressIndicator())
          else if (_rapportData != null) ...[
            // ── Carte résumé ────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.indigo,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statRapport('Attendu', totalAttendu),
                      _statRapport('Encaissé', totalEncaisse),
                      _statRapport('Restant', totalRestant),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Recouvrement : ${pourcentageRecouvrement.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Tableau par classe ──────────────────────
            const Text('Détail par classe',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Classe')),
                  DataColumn(label: Text('Attendu')),
                  DataColumn(label: Text('Encaissé')),
                  DataColumn(label: Text('Restant')),
                  DataColumn(label: Text('%')),
                ],
                rows: parClasse.map((c) {
                  final attendu =
                      double.tryParse(c['total_attendu'].toString()) ?? 0;
                  final encaisse =
                      double.tryParse(c['total_encaisse'].toString()) ?? 0;
                  final restant =
                      double.tryParse(c['total_restant'].toString()) ?? 0;
                  final pourcentage = attendu > 0 ? (encaisse / attendu * 100) : 0;

                  return DataRow(cells: [
                    DataCell(Text(c['classe_nom'] as String)),
                    DataCell(Text('$attendu')),
                    DataCell(Text('$encaisse')),
                    DataCell(Text('$restant')),
                    DataCell(Text('${pourcentage.toStringAsFixed(0)}%')),
                  ]);
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _exportEnCours ? null : _exporterPdf,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: _exportEnCours
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.picture_as_pdf),
              label: const Text('Exporter en PDF'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statRapport(String label, double valeur) {
    return Column(
      children: [
        Text(
          valeur.toStringAsFixed(0),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
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
            onPressed: _chargerInitial,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.payment), text: 'Paiements'),
            Tab(icon: Icon(Icons.people), text: 'Situation des élèves'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Rapport financier'),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: () => _afficherDialogPaiement(),
              backgroundColor: Colors.teal,
              icon: const Icon(Icons.add),
              label: const Text('Nouveau paiement'),
            )
          : null,
      body: _chargementInitial
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _ongletPaiements(),
                _ongletSituation(),
                _ongletRapport(),
              ],
            ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// Dialog : Nouveau paiement
// ══════════════════════════════════════════════════════════

class _DialogNouveauPaiement extends StatefulWidget {
  final List<dynamic> classes;
  final int anneeIdEnCours;
  final int? classeIdPreselectionne;
  final int? eleveIdPreselectionne;

  const _DialogNouveauPaiement({
    required this.classes,
    required this.anneeIdEnCours,
    this.classeIdPreselectionne,
    this.eleveIdPreselectionne,
  });

  @override
  State<_DialogNouveauPaiement> createState() =>
      _DialogNouveauPaiementState();
}

class _DialogNouveauPaiementState extends State<_DialogNouveauPaiement> {
  int? _classeId;
  int? _eleveId;
  String _type = 'scolarite';
  String _tranche = 'Tranche 1';
  List<dynamic> _eleves = [];
  List<dynamic> _frais = [];
  bool _chargementClasse = false;
  bool _enregistrement = false;
  DateTime _date = DateTime.now();

  final _montantController = TextEditingController();
  final _referenceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _classeId = widget.classeIdPreselectionne;
    _eleveId = widget.eleveIdPreselectionne;
    if (_classeId != null) _chargerClasse(_classeId!);
  }

  @override
  void dispose() {
    _montantController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _chargerClasse(int classeId) async {
    setState(() => _chargementClasse = true);
    try {
      final resultats = await Future.wait([
        EleveService.elevesParClasse(classeId, widget.anneeIdEnCours),
        FraisScolaireService.listerFrais(
          classeId: classeId,
          anneeId: widget.anneeIdEnCours,
        ),
      ]);
      setState(() {
        _eleves = resultats[0];
        _frais = resultats[1];
        _chargementClasse = false;
        _recalculerMontant();
      });
    } catch (e) {
      setState(() => _chargementClasse = false);
    }
  }

  void _recalculerMontant() {
    final frais = _frais.firstWhere(
      (f) => f['type'] == _type,
      orElse: () => null,
    );
    if (frais == null) {
      _montantController.text = '';
      return;
    }
    final montant = switch (_tranche) {
      'Tranche 1' => frais['montant_tranche_1'],
      'Tranche 2' => frais['montant_tranche_2'],
      'Tranche 3' => frais['montant_tranche_3'],
      _ => frais['montant_total'],
    };
    _montantController.text = montant != null ? montant.toString() : '';
  }

  Future<void> _enregistrer() async {
    final montant = double.tryParse(_montantController.text);
    if (_eleveId == null || montant == null || montant <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Montant invalide'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _enregistrement = true);

    final typeLabel = _type == 'inscription' ? 'Inscription' : 'Scolarité';

    try {
      await PaiementService.enregistrer(
        eleveId: _eleveId!,
        anneeAcademiqueId: widget.anneeIdEnCours,
        montant: montant,
        tranche: '$typeLabel — $_tranche',
        datePaiement: _formatDate(_date),
        reference: _referenceController.text.isEmpty
            ? null
            : _referenceController.text,
      );

      final eleve = _eleves.firstWhere(
        (e) => e['id'] == _eleveId,
        orElse: () => null,
      );
      final classe = widget.classes.firstWhere(
        (c) => c['id'] == _classeId,
        orElse: () => null,
      );

      if (mounted) {
        Navigator.pop(context, {
          'eleve': eleve,
          'classe_nom': classe?['nom'],
          'montant': montant,
          'tranche_label': '$typeLabel ($_tranche)',
        });
      }
    } catch (e) {
      setState(() => _enregistrement = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouveau paiement'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: _classeId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Classe',
                  prefixIcon: Icon(Icons.class_),
                  border: OutlineInputBorder(),
                ),
                hint: const Text('Choisir une classe'),
                items: widget.classes.map((c) {
                  return DropdownMenuItem<int>(
                    value: c['id'] as int,
                    child: Text(c['nom'] as String),
                  );
                }).toList(),
                onChanged: (v) {
                  setState(() {
                    _classeId = v;
                    _eleveId = null;
                    _eleves = [];
                    _frais = [];
                  });
                  if (v != null) _chargerClasse(v);
                },
              ),
              const SizedBox(height: 12),
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
                onChanged: _eleves.isEmpty
                    ? null
                    : (v) => setState(() => _eleveId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  prefixIcon: Icon(Icons.category),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'inscription', child: Text('Inscription')),
                  DropdownMenuItem(
                      value: 'scolarite', child: Text('Scolarité')),
                ],
                onChanged: (v) => setState(() {
                  _type = v!;
                  _recalculerMontant();
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _tranche,
                decoration: const InputDecoration(
                  labelText: 'Tranche',
                  prefixIcon: Icon(Icons.layers),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Tranche 1', child: Text('Tranche 1')),
                  DropdownMenuItem(value: 'Tranche 2', child: Text('Tranche 2')),
                  DropdownMenuItem(value: 'Tranche 3', child: Text('Tranche 3')),
                  DropdownMenuItem(
                      value: 'Paiement complet', child: Text('Paiement complet')),
                ],
                onChanged: (v) => setState(() {
                  _tranche = v!;
                  _recalculerMontant();
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _montantController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Montant (FCFA)',
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.date_range),
                title: Text(
                  'Date : ${_date.day}/${_date.month}/${_date.year}',
                ),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (d != null) setState(() => _date = d);
                },
              ),
              TextField(
                controller: _referenceController,
                decoration: const InputDecoration(
                  labelText: 'Référence (optionnel)',
                  prefixIcon: Icon(Icons.receipt),
                  border: OutlineInputBorder(),
                ),
              ),
              if (_chargementClasse)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
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
          onPressed: _eleveId == null || _enregistrement ? null : _enregistrer,
          child: _enregistrement
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Enregistrer'),
        ),
      ],
    );
  }
}
