import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_file/open_file.dart';
import '../../models/frais_scolaire_model.dart';
import '../../services/paiement_service.dart';
import '../../services/frais_scolaire_service.dart';
import '../../services/dashboard_frais_service.dart';
import '../../services/eleve_service.dart';
import '../../services/classe_service.dart';
import '../../services/annee_service.dart';
import '../../services/whatsapp_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/ssm_widgets.dart';

const List<String> _moisFrancais = [
  'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
  'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
];

const Map<String, String> _libellesModePaiement = {
  'especes': 'Espèces',
  'moov_money': 'Moov Money',
  'wave': 'Wave',
  'virement': 'Virement',
  'cheque': 'Chèque',
};

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
    case 'en_regle': return SSMBadge.succes;
    case 'partiel':  return SSMBadge.avertissement;
    case 'non_paye': return SSMBadge.erreur;
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
  bool _chargementSituation = false;
  String _filtreStatut = 'tous';

  // ── Onglet 3 : Rapport financier ──────────────────────
  Map<String, dynamic>? _resume;
  bool _chargementResume = false;
  int? _rapportAnneeId;
  String _formatExport = 'pdf';
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

      await Future.wait([_chargerPaiements(), _chargerResume()]);
    } catch (e) {
      setState(() => _chargementInitial = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _afficherErreur(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFFDC2626)),
    );
  }

  void _afficherSucces(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFF16A34A)),
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
      final paiements = await PaiementService.lister();
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
    _chargerResume();
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
      tranche: resultat['frais_nom'] as String? ?? '',
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
          color: Colors.teal.withValues(alpha: 0.05),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int?>(
                  initialValue: _filtreClasseId,
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
                  initialValue: _filtreMois,
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
                        final creePar = p['cree_par'];
                        final photoUrl = eleve?['photo_url'] as String?;
                        final frais = p['frais_scolaire'] as Map<String, dynamic>?;
                        final echeance = p['echeance'] as Map<String, dynamic>?;
                        final estAnnule = p['statut'] == 'annule';
                        final libelle = [frais?['nom'], echeance?['libelle']]
                            .where((v) => v != null)
                            .join(' — ');

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            leading: CircleAvatar(
                              backgroundColor: estAnnule ? Colors.grey : Colors.teal,
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
                                Text('$libelle  •  ${p['date_paiement']}'),
                                if (creePar != null)
                                  Text(
                                    'Enregistré par ${creePar['name']}',
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.grey),
                                  ),
                              ],
                            ),
                            isThreeLine: creePar != null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${p['montant']} FCFA${estAnnule ? ' (annulé)' : ''}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: estAnnule ? Colors.red : Colors.green,
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
    if (_situationClasseId == null) return;

    setState(() => _chargementSituation = true);
    try {
      final resultats = await Future.wait([
        DashboardFraisService.debiteurs(classeId: _situationClasseId),
        DashboardFraisService.elevesAJour(classeId: _situationClasseId),
      ]);

      final debiteurs = (resultats[0]['debiteurs'] as List).map((d) {
        final montantPaye = double.tryParse(d['montant_paye'].toString()) ?? 0;
        return {
          'eleve_id': d['eleve_id'],
          'nom': d['nom'],
          'prenom': d['prenom'],
          'montant_du': d['montant_attendu'],
          'montant_paye': d['montant_paye'],
          'montant_restant': d['montant_restant'],
          'statut': montantPaye > 0 ? 'partiel' : 'non_paye',
          'telephone_parent': d['telephone_parent'],
        };
      }).toList();

      final aJour = (resultats[1]['eleves'] as List).map((e) {
        return {
          'eleve_id': e['eleve_id'],
          'nom': e['nom'],
          'prenom': e['prenom'],
          'montant_du': e['montant_attendu'],
          'montant_paye': e['montant_paye'],
          'montant_restant': 0,
          'statut': 'en_regle',
          'telephone_parent': null,
        };
      }).toList();

      final tousLesEleves = [...aJour, ...debiteurs];

      setState(() {
        _situationData = {
          'eleves': tousLesEleves,
          'statistiques': {
            'total_eleves': tousLesEleves.length,
            'en_regle': aJour.length,
            'partiel': debiteurs.where((e) => e['statut'] == 'partiel').length,
            'non_paye': debiteurs.where((e) => e['statut'] == 'non_paye').length,
          },
        };
        _chargementSituation = false;
      });
    } catch (e) {
      setState(() => _chargementSituation = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  List<dynamic> get _elevesFiltresParStatut {
    final eleves = (_situationData?['eleves'] as List?) ?? [];
    if (_filtreStatut == 'tous') return eleves;
    return eleves.where((e) => e['statut'] == _filtreStatut).toList();
  }

  Future<void> _notifierParent(dynamic eleveSituation) async {
    final telephoneParent = eleveSituation['telephone_parent'] as String?;

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
          color: Colors.purple.withValues(alpha: 0.05),
          padding: const EdgeInsets.all(16),
          child: DropdownButtonFormField<int>(
            initialValue: _situationClasseId,
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
                                        SSMBadge(
                                          label: _libelleStatut(statut),
                                          couleur: _couleurStatut(statut),
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

  Future<void> _chargerResume() async {
    setState(() => _chargementResume = true);
    try {
      final data = await DashboardFraisService.resume();
      setState(() {
        _resume = data;
        _chargementResume = false;
      });
    } catch (e) {
      setState(() => _chargementResume = false);
    }
  }

  Future<void> _exporterRapport() async {
    if (_rapportAnneeId == null) return;

    setState(() => _exportEnCours = true);
    try {
      final chemin = await DashboardFraisService.telechargerRapport(
        anneeScolaireId: _rapportAnneeId,
        format: _formatExport,
      );
      await OpenFile.open(chemin);
    } catch (e) {
      _afficherErreur('Erreur export du rapport : $e');
    } finally {
      if (mounted) setState(() => _exportEnCours = false);
    }
  }

  Widget _ongletRapport() {
    final montantAttendu = double.tryParse(_resume?['montant_attendu']?.toString() ?? '0') ?? 0;
    final montantEncaisse = double.tryParse(_resume?['montant_encaisse']?.toString() ?? '0') ?? 0;
    final montantRestant = double.tryParse(_resume?['montant_restant']?.toString() ?? '0') ?? 0;
    final tauxRecouvrement = double.tryParse(_resume?['taux_recouvrement']?.toString() ?? '0') ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Résumé — ${_resume?['annee_libelle'] ?? 'année en cours'}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          if (_chargementResume)
            const Center(child: CircularProgressIndicator())
          else if (_resume != null)
            Row(
              children: [
                Expanded(
                  child: SSMStatCard(
                    titre: 'Attendu',
                    valeur: '${montantAttendu.toStringAsFixed(0)} F',
                    icone: Icons.account_balance_wallet,
                    couleurIcone: const Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SSMStatCard(
                    titre: 'Encaissé',
                    valeur: '${montantEncaisse.toStringAsFixed(0)} F',
                    icone: Icons.payments,
                    couleurIcone: const Color(0xFF0D9488),
                    variation: '${tauxRecouvrement.toStringAsFixed(0)}% recouvré',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SSMStatCard(
                    titre: 'Restant',
                    valeur: '${montantRestant.toStringAsFixed(0)} F',
                    icone: Icons.warning_amber,
                    couleurIcone: const Color(0xFFEA580C),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 24),
          const Text('Télécharger un rapport',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            initialValue: _rapportAnneeId,
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('PDF'),
                  selected: _formatExport == 'pdf',
                  onSelected: (_) => setState(() => _formatExport = 'pdf'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Excel'),
                  selected: _formatExport == 'excel',
                  onSelected: (_) => setState(() => _formatExport = 'excel'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _rapportAnneeId == null || _exportEnCours ? null : _exporterRapport,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
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
                : Icon(_formatExport == 'excel' ? Icons.table_chart : Icons.picture_as_pdf),
            label: Text('Télécharger le rapport (${_formatExport.toUpperCase()})'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Gestion des paiements',
          style: GoogleFonts.sora(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0D9488),
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
              backgroundColor: const Color(0xFF0D9488),
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
  List<dynamic> _eleves = [];
  List<FraisScolaire> _frais = [];
  FraisScolaire? _fraisSelectionne;
  EcheanceFrais? _echeanceSelectionnee;
  String _modePaiement = 'especes';
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
        FraisScolaireService.getFrais(
          classeId: classeId,
          anneeScolaireId: widget.anneeIdEnCours,
          actif: true,
        ),
      ]);
      setState(() {
        _eleves = resultats[0];
        _frais = resultats[1] as List<FraisScolaire>;
        _fraisSelectionne = null;
        _echeanceSelectionnee = null;
        _chargementClasse = false;
      });
    } catch (e) {
      setState(() => _chargementClasse = false);
    }
  }

  void _recalculerMontant() {
    if (_fraisSelectionne == null) {
      _montantController.text = '';
      return;
    }
    final montant = _echeanceSelectionnee?.montant ?? _fraisSelectionne!.montant;
    _montantController.text = montant.toString();
  }

  Future<void> _enregistrer() async {
    final montant = double.tryParse(_montantController.text);
    if (_eleveId == null || _fraisSelectionne == null || montant == null || montant <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Veuillez choisir un frais et un montant valide'),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _enregistrement = true);

    try {
      await PaiementService.enregistrer(
        eleveId: _eleveId!,
        fraisScolaireId: _fraisSelectionne!.id!,
        echeanceId: _echeanceSelectionnee?.id,
        montant: montant,
        modePaiement: _modePaiement,
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
          'frais_nom': _fraisSelectionne!.nom,
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
                initialValue: _classeId,
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
                    _fraisSelectionne = null;
                    _echeanceSelectionnee = null;
                  });
                  if (v != null) _chargerClasse(v);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _eleveId,
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
              DropdownButtonFormField<FraisScolaire>(
                initialValue: _fraisSelectionne,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Frais scolaire',
                  prefixIcon: Icon(Icons.category),
                  border: OutlineInputBorder(),
                ),
                hint: const Text('Choisir un frais'),
                items: _frais.map((f) {
                  return DropdownMenuItem<FraisScolaire>(
                    value: f,
                    child: Text(f.nom),
                  );
                }).toList(),
                onChanged: _frais.isEmpty
                    ? null
                    : (v) => setState(() {
                          _fraisSelectionne = v;
                          _echeanceSelectionnee = null;
                          _recalculerMontant();
                        }),
              ),
              if (_fraisSelectionne != null && _fraisSelectionne!.echeances.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<EcheanceFrais?>(
                  initialValue: _echeanceSelectionnee,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Échéance',
                    prefixIcon: Icon(Icons.layers),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<EcheanceFrais?>(
                      value: null,
                      child: Text('Paiement complet'),
                    ),
                    ..._fraisSelectionne!.echeances.map((e) {
                      return DropdownMenuItem<EcheanceFrais?>(
                        value: e,
                        child: Text('${e.libelle} (${e.montant.toStringAsFixed(0)} F)'),
                      );
                    }),
                  ],
                  onChanged: (v) => setState(() {
                    _echeanceSelectionnee = v;
                    _recalculerMontant();
                  }),
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _modePaiement,
                decoration: const InputDecoration(
                  labelText: 'Mode de paiement',
                  prefixIcon: Icon(Icons.account_balance_wallet),
                  border: OutlineInputBorder(),
                ),
                items: _libellesModePaiement.entries.map((entry) {
                  return DropdownMenuItem(value: entry.key, child: Text(entry.value));
                }).toList(),
                onChanged: (v) => setState(() => _modePaiement = v!),
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
          onPressed: _eleveId == null || _fraisSelectionne == null || _enregistrement
              ? null
              : _enregistrer,
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
