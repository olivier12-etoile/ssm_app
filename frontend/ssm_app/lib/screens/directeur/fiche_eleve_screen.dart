import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/eleve_service.dart';
import '../../services/frais_scolaire_service.dart';
import '../../services/paiement_service.dart';
import '../../services/bulletin_service.dart';
import '../../services/absence_service.dart';
import '../../services/annee_service.dart';
import '../../services/whatsapp_service.dart';

Color _couleurStatut(String statut) {
  switch (statut) {
    case 'en_regle': return Colors.green;
    case 'partiel':  return Colors.orange;
    case 'non_paye': return Colors.red;
    default:         return Colors.grey;
  }
}

String _libelleStatut(String statut) {
  switch (statut) {
    case 'en_regle': return 'En règle ✅';
    case 'partiel':  return 'Partiel ⚠️';
    case 'non_paye': return 'Non payé ❌';
    default:         return statut;
  }
}

Color _couleurMoyenne(double? m) {
  if (m == null) return Colors.grey;
  if (m >= 14) return Colors.green;
  if (m >= 10) return Colors.orange;
  return Colors.red;
}

String _formatDate(DateTime d) {
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

class FicheEleveScreen extends StatefulWidget {
  final int eleveId;

  const FicheEleveScreen({super.key, required this.eleveId});

  @override
  State<FicheEleveScreen> createState() => _FicheEleveScreenState();
}

class _FicheEleveScreenState extends State<FicheEleveScreen> {
  Map<String, dynamic>? _eleve;
  int? _anneeIdEnCours;
  List<dynamic> _periodes = [];
  Map<String, dynamic>? _situationFinanciere;
  List<dynamic> _paiements = [];
  Map<int, Map<String, dynamic>> _bulletins = {};
  Map<String, dynamic>? _absencesData;

  bool _chargement = true;
  bool _uploadPhotoEnCours = false;

  @override
  void initState() {
    super.initState();
    _chargerTout();
  }

  dynamic get _classeActuelle {
    final inscriptions = (_eleve?['inscriptions'] as List?) ?? [];
    if (inscriptions.isEmpty) return null;
    final inscription = inscriptions.firstWhere(
      (i) => i['annee_academique_id'] == _anneeIdEnCours,
      orElse: () => inscriptions.last,
    );
    return inscription['classe'];
  }

  Future<void> _chargerTout() async {
    setState(() => _chargement = true);
    try {
      final resultats = await Future.wait([
        EleveService.getEleve(widget.eleveId),
        AnneeService.listerAnnees(),
        PaiementService.paiementsEleve(widget.eleveId),
        AbsenceService.historiqueEleve(widget.eleveId),
      ]);

      final eleve = resultats[0] as Map<String, dynamic>;
      final annees = resultats[1] as List;
      final paiementsData = resultats[2] as Map<String, dynamic>;
      final absencesData = resultats[3] as Map<String, dynamic>;

      final anneeEnCours = annees.firstWhere(
        (a) => a['statut'] == 'en_cours',
        orElse: () => annees.isNotEmpty ? annees.first : null,
      );
      final anneeId = anneeEnCours?['id'] as int?;

      List<dynamic> periodes = [];
      Map<String, dynamic>? situationFinanciere;
      final bulletins = <int, Map<String, dynamic>>{};

      if (anneeId != null) {
        final resultatsAnnee = await Future.wait([
          AnneeService.listerPeriodes(anneeId),
          FraisScolaireService.situationEleve(
            eleveId: widget.eleveId,
            anneeId: anneeId,
          ),
        ]);
        periodes = resultatsAnnee[0] as List;
        situationFinanciere = resultatsAnnee[1] as Map<String, dynamic>;

        final bulletinsListe = await Future.wait(periodes.map((p) {
          return BulletinService.genererBulletin(
            eleveId: widget.eleveId,
            periodeId: p['id'] as int,
          );
        }));
        for (var i = 0; i < periodes.length; i++) {
          bulletins[periodes[i]['id'] as int] = bulletinsListe[i];
        }
      }

      setState(() {
        _eleve = eleve;
        _anneeIdEnCours = anneeId;
        _periodes = periodes;
        _situationFinanciere = situationFinanciere;
        _paiements = (paiementsData['paiements'] as List?) ?? [];
        _bulletins = bulletins;
        _absencesData = absencesData;
        _chargement = false;
      });
    } catch (e) {
      setState(() => _chargement = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _rechargerFinances() async {
    if (_anneeIdEnCours == null) return;
    try {
      final resultats = await Future.wait([
        FraisScolaireService.situationEleve(
          eleveId: widget.eleveId,
          anneeId: _anneeIdEnCours!,
        ),
        PaiementService.paiementsEleve(widget.eleveId),
      ]);
      setState(() {
        _situationFinanciere = resultats[0];
        _paiements = (resultats[1]['paiements'] as List?) ?? [];
      });
    } catch (_) {
      // Silencieux : les données restent celles du dernier chargement réussi.
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

  Future<void> _changerPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );
    if (image == null) return;

    setState(() => _uploadPhotoEnCours = true);
    try {
      await EleveService.uploaderPhoto(widget.eleveId, File(image.path));
      final eleve = await EleveService.getEleve(widget.eleveId);
      setState(() {
        _eleve = eleve;
        _uploadPhotoEnCours = false;
      });
      _afficherSucces('Photo mise à jour');
    } catch (e) {
      setState(() => _uploadPhotoEnCours = false);
      _afficherErreur('Erreur upload photo : $e');
    }
  }

  Future<void> _contacterWhatsApp() async {
    final tel = _eleve?['telephone_parent'] as String?;
    if (tel == null || tel.isEmpty) {
      _afficherErreur('Aucun numéro de téléphone parent enregistré');
      return;
    }
    final nomEcole = _eleve?['ecole']?['nom'] ?? 'l\'école';
    final message =
        'Bonjour, ceci est un message de $nomEcole concernant '
        '${_eleve?['nom']} ${_eleve?['prenom']}.';

    final succes = await WhatsAppService.envoyerMessage(
      numeroTelephone: tel,
      message: message,
    );
    if (!succes && mounted) _afficherErreur('Impossible d\'ouvrir WhatsApp');
  }

  Future<void> _afficherDialogPaiementRapide() async {
    final classe = _classeActuelle;
    if (classe == null || _anneeIdEnCours == null) {
      _afficherErreur('Classe ou année académique introuvable');
      return;
    }

    final resultat = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _DialogPaiementRapide(
        eleveId: widget.eleveId,
        classeId: classe['id'] as int,
        anneeId: _anneeIdEnCours!,
      ),
    );

    if (resultat == null || !mounted) return;

    _afficherSucces('Paiement enregistré avec succès');
    _rechargerFinances();

    final telephoneParent = _eleve?['telephone_parent'] as String?;
    if (telephoneParent == null || telephoneParent.isEmpty) return;

    final envoyer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Envoyer un reçu WhatsApp ?'),
        content: const Text(
            'Envoyer une confirmation de paiement au parent par WhatsApp ?'),
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
      nomEleve: '${_eleve?['nom']} ${_eleve?['prenom']}',
      classe: classe['nom'] as String? ?? '',
      montant: '${resultat['montant']}',
      tranche: resultat['tranche_label'] as String? ?? '',
      nomEcole: _eleve?['ecole']?['nom'] ?? '',
    );

    final succes = await WhatsAppService.envoyerMessage(
      numeroTelephone: telephoneParent,
      message: message,
    );
    if (!succes && mounted) _afficherErreur('Impossible d\'ouvrir WhatsApp');
  }

  Future<void> _envoyerRappelWhatsApp() async {
    final telephoneParent = _eleve?['telephone_parent'] as String?;
    if (telephoneParent == null || telephoneParent.isEmpty) {
      _afficherErreur('Aucun numéro de téléphone parent enregistré');
      return;
    }

    final classe = _classeActuelle;
    final montantRestant = _situationFinanciere?['montant_restant'];

    final message = WhatsAppService.messageRappelPaiement(
      nomParent: 'Cher parent',
      nomEleve: '${_eleve?['nom']} ${_eleve?['prenom']}',
      classe: classe?['nom'] as String? ?? '',
      montantDu: '$montantRestant',
      dateLimit: 'dès que possible',
      nomEcole: _eleve?['ecole']?['nom'] ?? '',
    );

    final succes = await WhatsAppService.envoyerMessage(
      numeroTelephone: telephoneParent,
      message: message,
    );
    if (!succes && mounted) _afficherErreur('Impossible d\'ouvrir WhatsApp');
  }

  Future<void> _afficherHistoriqueComplet() async {
    final absences = (_absencesData?['absences'] as List?) ?? [];
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Historique complet des absences'),
        content: SizedBox(
          width: 350,
          child: absences.isEmpty
              ? const Text('Aucune absence enregistrée')
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: absences.map((a) {
                      final justifiee = a['justifiee'] == true;
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          justifiee ? Icons.check_circle : Icons.cancel,
                          color: justifiee ? Colors.green : Colors.red,
                        ),
                        title: Text('${a['date_absence']}'),
                        subtitle: a['motif'] != null
                            ? Text(a['motif'] as String)
                            : Text(justifiee ? 'Justifiée' : 'Non justifiée'),
                      );
                    }).toList(),
                  ),
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

  // ══════════════════════════════════════════════════════
  // SECTION 1 — Informations personnelles
  // ══════════════════════════════════════════════════════

  Widget _sectionInfosPersonnelles() {
    final eleve = _eleve!;
    final sexe = eleve['sexe'] as String;
    final photoUrl = eleve['photo_url'] as String?;
    final telephoneParent = eleve['telephone_parent'] as String?;
    final classe = _classeActuelle;

    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: sexe == 'M' ? Colors.blue : Colors.pink,
                backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                child: _uploadPhotoEnCours
                    ? const CircularProgressIndicator(color: Colors.white)
                    : photoUrl == null
                        ? Text(
                            eleve['prenom'].toString().substring(0, 1),
                            style: const TextStyle(
                                fontSize: 36,
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          )
                        : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _changerPhoto,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 3)],
                    ),
                    child: const Icon(Icons.camera_alt,
                        size: 18, color: Colors.deepOrange),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${eleve['nom']} ${eleve['prenom']}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text('Matricule : ${eleve['matricule']}',
              style: const TextStyle(color: Colors.grey)),
          Text('Classe : ${classe?['nom'] ?? 'Non définie'}'),
          Text(
              'Né(e) le : ${eleve['date_naissance'] ?? 'Non renseignée'}'),
          Text('Sexe : ${sexe == 'M' ? 'Masculin' : 'Féminin'}'),
          const SizedBox(height: 10),
          if (telephoneParent != null && telephoneParent.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.phone, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(telephoneParent),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.chat, color: Colors.green),
                  tooltip: 'Contacter via WhatsApp',
                  onPressed: _contacterWhatsApp,
                ),
              ],
            )
          else
            const Text('Aucun numéro de téléphone parent',
                style: TextStyle(color: Colors.orange, fontSize: 12)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // SECTION 2 — Situation financière
  // ══════════════════════════════════════════════════════

  Widget _sectionSituationFinanciere() {
    final s = _situationFinanciere;
    if (s == null) {
      return const Text('Situation financière indisponible',
          style: TextStyle(color: Colors.grey));
    }

    final statut = s['statut'] as String;
    final montantDu = double.tryParse(s['montant_total_du'].toString()) ?? 0;
    final montantPaye = double.tryParse(s['montant_paye'].toString()) ?? 0;
    final montantRestant =
        double.tryParse(s['montant_restant'].toString()) ?? 0;
    final progression =
        montantDu > 0 ? (montantPaye / montantDu).clamp(0.0, 1.0) : 1.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _couleurStatut(statut).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _couleurStatut(statut).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _libelleStatut(statut),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: _couleurStatut(statut),
            ),
          ),
          const SizedBox(height: 10),
          Text('Montant total dû : ${montantDu.toStringAsFixed(0)} FCFA'),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progression,
              minHeight: 10,
              backgroundColor: Colors.grey[300],
              color: _couleurStatut(statut),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${montantPaye.toStringAsFixed(0)} / ${montantDu.toStringAsFixed(0)} FCFA payé',
          ),
          Text(
            'Restant : ${montantRestant.toStringAsFixed(0)} FCFA',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _couleurStatut(statut),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Historique des paiements',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          if (_paiements.isEmpty)
            const Text('Aucun paiement enregistré',
                style: TextStyle(color: Colors.grey))
          else
            ..._paiements.map((p) {
              final enregistrePar = p['enregistre_par'];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${p['montant']} FCFA — ${p['tranche']}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${p['date_paiement']}'
                            '${enregistrePar != null ? ' • Par ${enregistrePar['name']}' : ''}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _afficherDialogPaiementRapide,
                  icon: const Icon(Icons.payment, size: 18),
                  label: const Text('Enregistrer un paiement'),
                ),
              ),
              if (montantRestant > 0) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _envoyerRappelWhatsApp,
                    icon: const Icon(Icons.message, size: 18, color: Colors.green),
                    label: const Text('Rappel WhatsApp'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // SECTION 3 — Résultats scolaires
  // ══════════════════════════════════════════════════════

  Widget _sectionResultatsScolaires() {
    if (_periodes.isEmpty) {
      return const Text('Aucune période académique disponible',
          style: TextStyle(color: Colors.grey));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _periodes.map((periode) {
        final bulletin = _bulletins[periode['id'] as int];
        final estActif = periode['statut'] == 'actif';
        final moyenneGenerale = bulletin != null
            ? double.tryParse(bulletin['moyenne_generale'].toString())
            : null;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: estActif
                ? const BorderSide(color: Colors.blue, width: 2)
                : BorderSide.none,
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      periode['nom'] as String,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (estActif) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'En cours',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                if (bulletin == null)
                  const Text('Chargement...', style: TextStyle(color: Colors.grey))
                else ...[
                  Text(
                    'Moyenne générale : ${bulletin['moyenne_generale']}/20 — ${bulletin['mention_generale']}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _couleurMoyenne(moyenneGenerale),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...((bulletin['notes'] as List).map((n) {
                    final moyenneFinale = n['moyenne_finale'];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(n['matiere'] as String,
                                style: const TextStyle(fontSize: 12)),
                          ),
                          Expanded(
                            child: Text(
                              moyenneFinale != null
                                  ? 'Moy : $moyenneFinale'
                                  : 'Moy : -',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Expanded(
                            child: Text('Coef ${n['coefficient']}',
                                style: const TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    );
                  })),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ══════════════════════════════════════════════════════
  // SECTION 4 — Absences
  // ══════════════════════════════════════════════════════

  Widget _sectionAbsences() {
    final total = (_absencesData?['total'] as int?) ?? 0;
    final nonJustifiees = (_absencesData?['non_justifiees'] as int?) ?? 0;
    final justifiees = total - nonJustifiees;
    final dernieres =
        ((_absencesData?['absences'] as List?) ?? []).take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _miniStatAbsence('Total', total, Colors.grey),
            _miniStatAbsence('Justifiées', justifiees, Colors.green),
            _miniStatAbsence('Non justifiées', nonJustifiees, Colors.red),
          ],
        ),
        const SizedBox(height: 12),
        if (dernieres.isEmpty)
          const Text('Aucune absence enregistrée',
              style: TextStyle(color: Colors.grey))
        else
          ...dernieres.map((a) {
            final justifiee = a['justifiee'] == true;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                justifiee ? Icons.check_circle : Icons.cancel,
                color: justifiee ? Colors.green : Colors.red,
              ),
              title: Text('${a['date_absence']}'),
              subtitle: Text(justifiee ? 'Justifiée' : 'Non justifiée'),
            );
          }),
        Center(
          child: TextButton(
            onPressed: _afficherHistoriqueComplet,
            child: Text('Voir tout l\'historique ($total)'),
          ),
        ),
      ],
    );
  }

  Widget _miniStatAbsence(String label, int valeur, Color couleur) {
    return Column(
      children: [
        Text(
          '$valeur',
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: couleur),
        ),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _titreSection(String titre) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        titre,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_eleve != null
            ? '${_eleve!['nom']} ${_eleve!['prenom']}'
            : 'Fiche élève'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerTout,
          ),
        ],
      ),
      body: _chargement || _eleve == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _chargerTout,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _sectionInfosPersonnelles(),
                  const Divider(height: 32),
                  _titreSection('Situation financière'),
                  _sectionSituationFinanciere(),
                  const Divider(height: 32),
                  _titreSection('Résultats scolaires'),
                  _sectionResultatsScolaires(),
                  const Divider(height: 32),
                  _titreSection('Absences'),
                  _sectionAbsences(),
                ],
              ),
            ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// Dialog : Enregistrer un paiement rapide pour cet élève
// ══════════════════════════════════════════════════════════

class _DialogPaiementRapide extends StatefulWidget {
  final int eleveId;
  final int classeId;
  final int anneeId;

  const _DialogPaiementRapide({
    required this.eleveId,
    required this.classeId,
    required this.anneeId,
  });

  @override
  State<_DialogPaiementRapide> createState() => _DialogPaiementRapideState();
}

class _DialogPaiementRapideState extends State<_DialogPaiementRapide> {
  String _type = 'scolarite';
  String _tranche = 'Tranche 1';
  List<dynamic> _frais = [];
  bool _chargement = true;
  bool _enregistrement = false;
  DateTime _date = DateTime.now();

  final _montantController = TextEditingController();
  final _referenceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _chargerFrais();
  }

  @override
  void dispose() {
    _montantController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _chargerFrais() async {
    try {
      final frais = await FraisScolaireService.listerFrais(
        classeId: widget.classeId,
        anneeId: widget.anneeId,
      );
      setState(() {
        _frais = frais;
        _chargement = false;
        _recalculerMontant();
      });
    } catch (e) {
      setState(() => _chargement = false);
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
    if (montant == null || montant <= 0) {
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
        eleveId: widget.eleveId,
        anneeAcademiqueId: widget.anneeId,
        montant: montant,
        tranche: '$typeLabel — $_tranche',
        datePaiement: _formatDate(_date),
        reference: _referenceController.text.isEmpty
            ? null
            : _referenceController.text,
      );

      if (mounted) {
        Navigator.pop(context, {
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
      title: const Text('Enregistrer un paiement'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                title: Text('Date : ${_date.day}/${_date.month}/${_date.year}'),
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
              if (_chargement)
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
          onPressed: _enregistrement ? null : _enregistrer,
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
