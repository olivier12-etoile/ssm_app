import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/frais_scolaire_model.dart';
import '../../services/eleve_service.dart';
import '../../services/annee_service.dart';
import '../../services/paiement_service.dart';
import '../../services/frais_scolaire_service.dart';
import '../../services/situation_financiere_service.dart';
import '../../models/bulletin_model.dart';
import '../../services/bulletin_service.dart';
import '../../services/discipline_service.dart';
import '../../services/whatsapp_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_alert_item.dart';
import '../../widgets/ssm/ssm_avatar.dart';
import '../../widgets/ssm/ssm_data_table.dart';
import '../../widgets/ssm/ssm_panel.dart';
import '../../widgets/ssm/ssm_pill.dart';
import '../../widgets/ssm/ssm_quick_action_button.dart';
import '../bulletins/apercu_bulletin_screen.dart';
import '../bulletins/historique_bulletins_eleve_screen.dart';
import '../presences/historique_presence_eleve_screen.dart';

Color _couleurStatutEleve(String? statut) {
  switch (statut) {
    case 'actif':
      return SSMPalette.indigo;
    case 'suspendu':
      return SSMPalette.ambre;
    case 'exclu':
      return SSMPalette.rouge;
    case 'diplome':
      return SSMPalette.teal;
    case 'transfere':
      return SSMPalette.teal;
    case 'abandon':
      return SSMPalette.texte3;
    default:
      return SSMPalette.texte3;
  }
}

Color _couleurMoyenne(double? m) {
  if (m == null) return SSMPalette.texte3;
  if (m >= 14) return SSMPalette.teal;
  if (m >= 10) return SSMPalette.ambre;
  return SSMPalette.rouge;
}

Color _couleurTypeDocument(String? type) {
  switch (type) {
    case 'acte_naissance':
      return SSMPalette.rouge;
    case 'certificat_scolarite':
      return SSMPalette.indigo;
    case 'photo':
      return SSMPalette.teal;
    case 'bulletin':
      return SSMPalette.ambre;
    case 'certificat_transfert':
      return SSMPalette.indigo;
    default:
      return SSMPalette.texte3;
  }
}

IconData _iconeTypeDocument(String? type) {
  switch (type) {
    case 'acte_naissance':
      return Icons.article;
    case 'certificat_scolarite':
      return Icons.school;
    case 'photo':
      return Icons.photo_camera;
    case 'bulletin':
      return Icons.description;
    case 'certificat_transfert':
      return Icons.transfer_within_a_station;
    default:
      return Icons.attach_file;
  }
}

Color _couleurTypeChronologie(String? type) {
  switch (type) {
    case 'inscription':
      return SSMPalette.indigo;
    case 'paiement':
      return SSMPalette.teal;
    case 'note_validee':
      return SSMPalette.teal;
    case 'bulletin_genere':
      return SSMPalette.ambre;
    case 'absence':
      return SSMPalette.ambre;
    case 'sanction':
      return SSMPalette.rouge;
    case 'document_ajoute':
      return SSMPalette.indigo;
    case 'message_envoye':
      return SSMPalette.teal;
    case 'passage':
    case 'transfert':
      return SSMPalette.indigo;
    default:
      return SSMPalette.texte3;
  }
}

IconData _iconeTypeChronologie(String? type) {
  switch (type) {
    case 'inscription':
      return Icons.school;
    case 'paiement':
      return Icons.payment;
    case 'note_validee':
      return Icons.check_circle;
    case 'bulletin_genere':
      return Icons.picture_as_pdf;
    case 'absence':
      return Icons.event_busy;
    case 'sanction':
      return Icons.gavel;
    case 'document_ajoute':
      return Icons.description;
    case 'message_envoye':
      return Icons.chat;
    case 'passage':
      return Icons.trending_up;
    case 'transfert':
      return Icons.transfer_within_a_station;
    default:
      return Icons.circle;
  }
}

SSMAlerteType _typeAlerteSanction(String? type) {
  switch (type) {
    case 'exclusion':
      return SSMAlerteType.danger;
    default:
      return SSMAlerteType.avertissement;
  }
}

IconData _iconeSanction(String? type) {
  switch (type) {
    case 'retard':
      return Icons.schedule;
    case 'avertissement':
      return Icons.warning_amber_rounded;
    case 'exclusion':
      return Icons.gavel;
    default:
      return Icons.info_outline;
  }
}

String _formatDate(DateTime d) {
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

String _formatDateCourt(String? iso) {
  if (iso == null) return '—';
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

String _formatDateHeure(String? iso) {
  if (iso == null) return '—';
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '${_formatDateCourt(iso)} à $h:$m';
}

// Champ de saisie flat commun aux dialogs de cet écran.
InputDecoration _decorationChamp(String label, {bool dense = false, IconData? icone}) {
  return InputDecoration(
    labelText: label,
    labelStyle: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2),
    prefixIcon: icone != null ? Icon(icone, size: 19, color: SSMPalette.texte3) : null,
    isDense: dense,
    filled: true,
    fillColor: const Color(0xFFF9FAFB),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(SSMRayons.moyen),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(SSMRayons.moyen),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(SSMRayons.moyen),
      borderSide: const BorderSide(color: SSMPalette.indigo, width: 1.5),
    ),
  );
}

ButtonStyle _stylePrimaire(Color couleur) => ElevatedButton.styleFrom(
      backgroundColor: couleur,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
    );

class FicheEleveScreen extends StatefulWidget {
  final int eleveId;

  const FicheEleveScreen({super.key, required this.eleveId});

  @override
  State<FicheEleveScreen> createState() => _FicheEleveScreenState();
}

class _FicheEleveScreenState extends State<FicheEleveScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool _chargement = true;
  Map<String, dynamic>? _details;

  Map<String, dynamic>? _situationFinanciere;
  List<dynamic> _paiements = [];

  List<dynamic> _periodes = [];
  int? _periodeSelectionneeId;
  // Résumés indexés par periode_id (voir BulletinService.getHistoriqueEleve) :
  // moyenne, rang, statut, décision du conseil déjà agrégés côté backend
  // (module Bulletins) — le rang n'a donc plus besoin d'un appel séparé.
  final Map<int, Map<String, dynamic>> _bulletins = {};

  List<dynamic> _sanctions = [];
  List<dynamic> _chronologieComplete = [];

  bool _uploadPhotoEnCours = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 9, vsync: this);
    _chargerTout();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Map<String, dynamic>? get _eleve => _details?['eleve'] as Map<String, dynamic>?;

  Map<String, dynamic>? get _inscriptionActuelle =>
      _details?['inscription_actuelle'] as Map<String, dynamic>?;

  Map<String, dynamic>? get _classeActuelle =>
      _inscriptionActuelle?['classe'] as Map<String, dynamic>?;

  int? get _anneeId => _inscriptionActuelle?['annee_academique_id'] as int?;

  int? get _classeId => _inscriptionActuelle?['classe_id'] as int?;

  Future<void> _chargerTout() async {
    setState(() => _chargement = true);
    try {
      final details = await EleveService.details(widget.eleveId);
      final inscription = details['inscription_actuelle'] as Map<String, dynamic>?;
      final anneeId = inscription?['annee_academique_id'] as int?;

      Map<String, dynamic>? situationFinanciere;
      List<dynamic> periodes = [];

      final taches = <Future>[
        DisciplineService.historiqueEleve(widget.eleveId),
        EleveService.chronologie(widget.eleveId),
        PaiementService.paiementsEleve(widget.eleveId),
      ];

      if (anneeId != null) {
        taches.add(SituationFinanciereService.getSituation(widget.eleveId, anneeScolaireId: anneeId));
        taches.add(AnneeService.listerPeriodes(anneeId));
      }

      final resultats = await Future.wait(taches);

      final sanctions = resultats[0] as List<dynamic>;
      final chronologie = resultats[1] as List<dynamic>;
      final paiementsData = resultats[2] as Map<String, dynamic>;

      if (anneeId != null) {
        situationFinanciere = resultats[3] as Map<String, dynamic>;
        periodes = resultats[4] as List<dynamic>;
      }

      setState(() {
        _details = details;
        _sanctions = sanctions;
        _chronologieComplete = chronologie;
        _paiements = (paiementsData['paiements'] as List?) ?? [];
        _situationFinanciere = situationFinanciere;
        _periodes = periodes;
        _periodeSelectionneeId ??= periodes.isNotEmpty
            ? (periodes.firstWhere((p) => p['statut'] == 'ouverte', orElse: () => periodes.first)['id'] as int)
            : null;
        _chargement = false;
      });

      unawaited(_chargerBulletins());
    } catch (e) {
      setState(() => _chargement = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _chargerBulletins() async {
    try {
      final parPeriode = await BulletinService.getHistoriqueEleve(widget.eleveId);
      if (!mounted) return;
      setState(() {
        _bulletins
          ..clear()
          ..addAll(parPeriode);
      });
    } catch (_) {
      // Non bloquant : les onglets Notes/Bulletins afficheront ce qui est disponible.
    }
  }

  Future<void> _rechargerFinances() async {
    if (_anneeId == null) return;
    try {
      final resultats = await Future.wait([
        SituationFinanciereService.getSituation(widget.eleveId, anneeScolaireId: _anneeId!),
        PaiementService.paiementsEleve(widget.eleveId),
      ]);
      setState(() {
        _situationFinanciere = resultats[0];
        _paiements = (resultats[1]['paiements'] as List?) ?? [];
      });
    } catch (_) {}
  }

  Future<void> _rechargerDocuments() async {
    try {
      final details = await EleveService.details(widget.eleveId);
      setState(() => _details = details);
    } catch (_) {}
  }

  Future<void> _rechargerChronologie() async {
    try {
      final chrono = await EleveService.chronologie(widget.eleveId);
      setState(() => _chronologieComplete = chrono);
    } catch (_) {}
  }

  void _afficherErreur(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: SSMPalette.rouge));
  }

  void _afficherSucces(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: SSMPalette.teal));
  }

  Future<void> _changerPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 80);
    if (image == null) return;

    setState(() => _uploadPhotoEnCours = true);
    try {
      await EleveService.uploaderPhoto(widget.eleveId, File(image.path));
      final details = await EleveService.details(widget.eleveId);
      setState(() {
        _details = details;
        _uploadPhotoEnCours = false;
      });
      _afficherSucces('Photo mise à jour');
      _rechargerChronologie();
    } catch (e) {
      setState(() => _uploadPhotoEnCours = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement || _eleve == null) {
      return const Scaffold(backgroundColor: SSMPalette.fond, body: Center(child: CircularProgressIndicator(color: SSMPalette.indigo)));
    }

    final sexe = _eleve!['sexe'] as String? ?? 'M';

    return Scaffold(
      backgroundColor: SSMPalette.fond,
      body: RefreshIndicator(
        onRefresh: _chargerTout,
        color: SSMPalette.indigo,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(child: _enTeteBarre()),
            SliverToBoxAdapter(child: _carteIdentite(sexe)),
            SliverPersistentHeader(pinned: true, delegate: _TabBarDelegate(_tabBar())),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _tabInfos(),
              _tabParents(),
              _tabFinances(),
              _tabNotes(),
              _tabBulletins(),
              _tabDiscipline(),
              _tabDocuments(),
              _tabChronologie(),
              _tabPresences(),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // EN-TÊTE — barre plate + carte d'identité (remplace le hero glass)
  // ══════════════════════════════════════════════════════

  Widget _enTeteBarre() {
    return Container(
      color: SSMPalette.blanc,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: SSMPalette.bordure))),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: SSMPalette.texte2),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Text(
                'Fiche élève',
                textAlign: TextAlign.center,
                style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: SSMPalette.texte2),
              onPressed: _dialogModifierInfos,
            ),
          ],
        ),
      ),
    );
  }

  Widget _carteIdentite(String sexe) {
    final eleve = _eleve!;
    final classe = _classeActuelle;
    final photoUrl = eleve['photo_url'] as String?;
    final telephoneParent = eleve['telephone_parent'] as String?;
    final statutAdmin = eleve['statut'] as String? ?? 'actif';
    final sf = _situationFinanciere;
    final resteAPayer = sf != null ? (double.tryParse(sf['reste_a_payer'].toString()) ?? 0) : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SSMPalette.blanc,
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        border: Border.all(color: SSMPalette.bordure),
      ),
      child: Column(
        children: [
          SSMAvatar(
            nom: eleve['prenom'] as String? ?? '?',
            photoUrl: photoUrl,
            sexe: sexe,
            rayon: 44,
            afficherBoutonCamera: true,
            enTeleversement: _uploadPhotoEnCours,
            onTap: _changerPhoto,
          ),
          const SizedBox(height: 10),
          Text(
            '${eleve['nom']}',
            textAlign: TextAlign.center,
            style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: SSMPalette.texte1),
          ),
          Text(
            '${eleve['prenom']}',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 14, color: SSMPalette.texte2),
          ),
          const SizedBox(height: 4),
          Text('Matricule : ${eleve['matricule']}', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: SSMPalette.texte3)),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              SSMPill.couleur(label: classe?['nom']?.toString() ?? 'Non affecté', couleur: SSMPalette.indigo),
              SSMPill.couleur(label: statutAdmin, couleur: _couleurStatutEleve(statutAdmin)),
              if (resteAPayer != null)
                (resteAPayer <= 0 ? const SSMPill.paye(label: 'En règle') : const SSMPill.retard(label: 'Dette')),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              SSMQuickActionButton(icone: Icons.edit_outlined, label: 'Modifier', variante: SSMActionVariante.primaire, onTap: _dialogModifierInfos),
              if (telephoneParent != null && telephoneParent.isNotEmpty)
                SSMQuickActionButton(icone: Icons.chat_bubble_outline, label: 'WhatsApp', variante: SSMActionVariante.teal, onTap: _dialogCommuniquer),
              SSMQuickActionButton(icone: Icons.picture_as_pdf_outlined, label: 'Bulletin', variante: SSMActionVariante.ambre, onTap: () => _tabController.animateTo(4)),
              SSMQuickActionButton(icone: Icons.event_available, label: 'Présences', variante: SSMActionVariante.teal, onTap: () => _tabController.animateTo(8)),
              SSMQuickActionButton(icone: Icons.more_horiz, label: 'Plus', variante: SSMActionVariante.gris, onTap: _dialogPlusActions),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tabBar() {
    return Container(
      color: SSMPalette.blanc,
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: SSMPalette.bordure))),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: SSMPalette.teal,
        labelColor: SSMPalette.indigo,
        unselectedLabelColor: SSMPalette.texte3,
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: '📋 Infos'),
          Tab(text: '👨‍👩‍👦 Parents'),
          Tab(text: '💰 Finances'),
          Tab(text: '📊 Notes'),
          Tab(text: '📄 Bulletins'),
          Tab(text: '🏛️ Discipline'),
          Tab(text: '📁 Docs'),
          Tab(text: '📅 Chronologie'),
          Tab(text: '✅ Présences'),
        ],
      ),
    );
  }

  void _dialogPlusActions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: SSMPalette.blanc,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.swap_horiz, color: SSMPalette.ambre),
              title: const Text('Changer le statut'),
              onTap: () {
                Navigator.pop(context);
                _dialogChangerStatut();
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh, color: SSMPalette.indigo),
              title: const Text('Rafraîchir'),
              onTap: () {
                Navigator.pop(context);
                _chargerTout();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // TAB 1 — INFORMATIONS
  // ══════════════════════════════════════════════════════

  Widget _tabInfos() {
    final eleve = _eleve!;
    final stats = (_details?['statistiques'] as Map?) ?? {};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SSMPanel(
          titre: 'Informations personnelles',
          child: Column(
            children: [
              _ligneInfo(Icons.cake_outlined, SSMPalette.indigo, 'Date de naissance', _formatDateCourt(eleve['date_naissance'] as String?)),
              _ligneInfo(Icons.place_outlined, SSMPalette.teal, 'Lieu de naissance', eleve['lieu_naissance']?.toString() ?? 'Non renseigné'),
              _ligneInfo(Icons.flag_outlined, SSMPalette.ambre, 'Nationalité', eleve['nationalite']?.toString() ?? 'Non renseignée'),
              _ligneInfo(Icons.wc, SSMPalette.indigo, 'Sexe', eleve['sexe'] == 'F' ? 'Féminin' : 'Masculin'),
              _ligneInfo(Icons.confirmation_number_outlined, SSMPalette.rouge, "N° d'appel", eleve['numero_appel']?.toString() ?? 'Non renseigné'),
              _ligneInfo(Icons.calendar_today_outlined, SSMPalette.texte2, "Date d'inscription", _formatDateCourt(eleve['date_inscription'] as String?), dernier: true),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _miniStat('${stats['nombre_absences_total'] ?? 0}', 'absences', SSMPalette.ambre)),
            const SizedBox(width: 10),
            Expanded(child: _miniStat(stats['rang_actuel'] != null ? 'Rang ${stats['rang_actuel']}' : '—', '', SSMPalette.indigo)),
            const SizedBox(width: 10),
            Expanded(child: _miniStat(stats['moyenne_generale_actuelle'] != null ? '${stats['moyenne_generale_actuelle']}/20' : '—', 'moy.', SSMPalette.teal)),
          ],
        ),
      ],
    );
  }

  Widget _ligneInfo(IconData icone, Color couleur, String titre, String valeur, {bool dernier = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: dernier ? null : const Border(bottom: BorderSide(color: SSMPalette.bordure)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: couleur.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
            child: Icon(icone, size: 17, color: couleur),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre, style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte3)),
                Text(valeur, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: SSMPalette.texte1)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String valeur, String label, Color couleur) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: SSMPalette.blanc,
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        border: Border.all(color: SSMPalette.bordure),
      ),
      child: Column(
        children: [
          Text(valeur, style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: couleur), textAlign: TextAlign.center),
          if (label.isNotEmpty) Text(label, style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte3)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // TAB 2 — PARENTS
  // ══════════════════════════════════════════════════════

  Widget _tabParents() {
    final parents = (_details?['parents'] as List?) ?? [];

    return Stack(
      children: [
        parents.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.family_restroom, size: 56, color: SSMPalette.texte3),
                    const SizedBox(height: 12),
                    Text('Aucun parent enregistré', style: GoogleFonts.inter(color: SSMPalette.texte3)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: _stylePrimaire(SSMPalette.indigo),
                      onPressed: _dialogGererParents,
                      child: const Text('Ajouter un parent'),
                    ),
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                children: parents.map((p) => _carteParent(p as Map<String, dynamic>)).toList(),
              ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            backgroundColor: SSMPalette.indigo,
            foregroundColor: Colors.white,
            onPressed: _dialogGererParents,
            icon: const Icon(Icons.edit),
            label: const Text('Modifier les parents'),
          ),
        ),
      ],
    );
  }

  Widget _carteParent(Map<String, dynamic> parent) {
    final lienLabels = {'pere': 'Père', 'mere': 'Mère', 'tuteur': 'Tuteur', 'autre': 'Autre'};
    final telPrincipal = parent['telephone_principal'] as String?;
    final telSecondaire = parent['telephone_secondaire'] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SSMPanel(
        titre: lienLabels[parent['lien_parente']] ?? 'Autre',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${parent['nom']} ${parent['prenom'] ?? ''}', style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
            if (parent['profession'] != null) Text(parent['profession'] as String, style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte3)),
            const SizedBox(height: 8),
            if (telPrincipal != null && telPrincipal.isNotEmpty) _ligneTelephone(telPrincipal),
            if (telSecondaire != null && telSecondaire.isNotEmpty) _ligneTelephone(telSecondaire),
          ],
        ),
      ),
    );
  }

  Widget _ligneTelephone(String tel) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(Icons.phone_outlined, size: 16, color: SSMPalette.texte3),
          const SizedBox(width: 6),
          Text(tel, style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte1)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.call, size: 18, color: SSMPalette.indigo),
            onPressed: () => launchUrl(Uri.parse('tel:$tel')),
          ),
          IconButton(
            icon: const Icon(Icons.chat, size: 18, color: SSMPalette.teal),
            onPressed: () => WhatsAppService.envoyerMessage(numeroTelephone: tel, message: 'Bonjour,'),
          ),
        ],
      ),
    );
  }

  void _dialogGererParents() {
    final parents = ((_details?['parents'] as List?) ?? [])
        .map((p) => <String, dynamic>{
              'lien_parente': p['lien_parente'],
              'nom': TextEditingController(text: p['nom']),
              'prenom': TextEditingController(text: p['prenom']),
              'telephone_principal': TextEditingController(text: p['telephone_principal']),
              'telephone_secondaire': TextEditingController(text: p['telephone_secondaire']),
              'profession': TextEditingController(text: p['profession']),
            })
        .toList();

    if (parents.isEmpty) {
      parents.add({
        'lien_parente': 'pere',
        'nom': TextEditingController(),
        'prenom': TextEditingController(),
        'telephone_principal': TextEditingController(),
        'telephone_secondaire': TextEditingController(),
        'profession': TextEditingController(),
      });
    }

    bool enCours = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          Widget carte(int index) {
            final p = parents[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(SSMRayons.grand),
                border: Border.all(color: SSMPalette.bordure),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: p['lien_parente'] as String,
                    decoration: _decorationChamp('Lien', dense: true),
                    items: const [
                      DropdownMenuItem(value: 'pere', child: Text('Père')),
                      DropdownMenuItem(value: 'mere', child: Text('Mère')),
                      DropdownMenuItem(value: 'tuteur', child: Text('Tuteur')),
                      DropdownMenuItem(value: 'autre', child: Text('Autre')),
                    ],
                    onChanged: (v) => setStateDialog(() => p['lien_parente'] = v),
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: p['nom'] as TextEditingController, decoration: _decorationChamp('Nom *', dense: true)),
                  const SizedBox(height: 8),
                  TextField(controller: p['prenom'] as TextEditingController, decoration: _decorationChamp('Prénom', dense: true)),
                  const SizedBox(height: 8),
                  TextField(controller: p['telephone_principal'] as TextEditingController, decoration: _decorationChamp('Téléphone principal *', dense: true)),
                  const SizedBox(height: 8),
                  TextField(controller: p['telephone_secondaire'] as TextEditingController, decoration: _decorationChamp('Téléphone secondaire', dense: true)),
                  const SizedBox(height: 8),
                  TextField(controller: p['profession'] as TextEditingController, decoration: _decorationChamp('Profession', dense: true)),
                ],
              ),
            );
          }

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
            backgroundColor: SSMPalette.blanc,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Parents / Tuteurs', style: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
                    const SizedBox(height: 16),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            ...List.generate(parents.length, carte),
                            if (parents.length < 2)
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: SSMPalette.indigo,
                                  side: const BorderSide(color: SSMPalette.indigo),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
                                ),
                                onPressed: () => setStateDialog(() => parents.add({
                                      'lien_parente': 'mere',
                                      'nom': TextEditingController(),
                                      'prenom': TextEditingController(),
                                      'telephone_principal': TextEditingController(),
                                      'telephone_secondaire': TextEditingController(),
                                      'profession': TextEditingController(),
                                    })),
                                icon: const Icon(Icons.add),
                                label: const Text('Ajouter un 2ème parent'),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('Annuler', style: GoogleFonts.inter(color: SSMPalette.texte2)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: _stylePrimaire(SSMPalette.indigo),
                            onPressed: enCours
                                ? null
                                : () async {
                                    setStateDialog(() => enCours = true);
                                    try {
                                      final data = parents
                                          .where((p) => (p['nom'] as TextEditingController).text.trim().isNotEmpty)
                                          .map((p) => {
                                                'lien_parente': p['lien_parente'],
                                                'nom': (p['nom'] as TextEditingController).text.trim(),
                                                'prenom': (p['prenom'] as TextEditingController).text.trim(),
                                                'telephone_principal': (p['telephone_principal'] as TextEditingController).text.trim(),
                                                'telephone_secondaire': (p['telephone_secondaire'] as TextEditingController).text.trim(),
                                                'profession': (p['profession'] as TextEditingController).text.trim(),
                                              })
                                          .toList();
                                      await EleveService.gererParents(widget.eleveId, data);
                                      if (!context.mounted) return;
                                      Navigator.pop(context);
                                      _afficherSucces('Parents mis à jour');
                                      final details = await EleveService.details(widget.eleveId);
                                      setState(() => _details = details);
                                    } catch (e) {
                                      setStateDialog(() => enCours = false);
                                      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
                                    }
                                  },
                            child: const Text('Enregistrer'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // TAB 3 — FINANCES
  // ══════════════════════════════════════════════════════

  Widget _tabFinances() {
    final s = _situationFinanciere;
    if (s == null) {
      return Center(child: Text('Situation financière indisponible', style: GoogleFonts.inter(color: SSMPalette.texte3)));
    }

    final montantDu = double.tryParse(s['montant_attendu'].toString()) ?? 0;
    final montantPaye = double.tryParse(s['montant_paye'].toString()) ?? 0;
    final montantRestant = double.tryParse(s['reste_a_payer'].toString()) ?? 0;
    final enRegle = montantRestant <= 0;
    final progression = montantDu > 0 ? (montantPaye / montantDu).clamp(0.0, 1.0) : 1.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SSMPanel(
          titre: 'Situation financière',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SSMPill.couleur(label: enRegle ? 'En règle' : 'En retard de paiement', couleur: enRegle ? SSMPalette.teal : SSMPalette.rouge),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _colonneMontant('Total dû', montantDu),
                  _colonneMontant('Payé', montantPaye),
                  _colonneMontant('Reste', montantRestant),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(value: progression, minHeight: 8, backgroundColor: const Color(0xFFF1F5F9), color: enRegle ? SSMPalette.teal : SSMPalette.rouge),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: _stylePrimaire(SSMPalette.teal),
                  onPressed: _dialogPaiementRapide,
                  icon: const Icon(Icons.payment),
                  label: const Text('Enregistrer un paiement'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SSMPanel(
          titre: 'Historique des paiements',
          padding: EdgeInsets.zero,
          child: _paiements.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Aucun paiement enregistré', style: GoogleFonts.inter(color: SSMPalette.texte3)),
                )
              : SSMDataTable(
                  colonnes: const [
                    SSMDataColumn('Paiement'),
                    SSMDataColumn('Montant'),
                    SSMDataColumn('Date'),
                    SSMDataColumn('Reçu'),
                  ],
                  lignes: [for (final p in _paiements) _lignePaiement(p as Map<String, dynamic>)],
                ),
        ),
      ],
    );
  }

  List<Widget> _lignePaiement(Map<String, dynamic> p) {
    final frais = p['frais_scolaire'] as Map<String, dynamic>?;
    final echeance = p['echeance'] as Map<String, dynamic>?;
    final estAnnule = p['statut'] == 'annule';
    final libelle = [frais?['nom'], echeance?['libelle']].where((v) => v != null).join(' — ');

    return [
      Text(libelle.isEmpty ? '—' : libelle, style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte1)),
      Text(
        '${p['montant']} FCFA${estAnnule ? ' (annulé)' : ''}',
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: estAnnule ? SSMPalette.texte3 : SSMPalette.texte1),
      ),
      Text(_formatDateCourt(p['date_paiement'] as String?), style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
      IconButton(
        icon: const Icon(Icons.receipt_long_outlined, size: 18, color: SSMPalette.indigo),
        onPressed: () async {
          try {
            final chemin = await PaiementService.telechargerRecuPdf(p['id'] as int);
            await OpenFile.open(chemin);
          } catch (e) {
            _afficherErreur(e.toString().replaceAll('Exception: ', ''));
          }
        },
      ),
    ];
  }

  Widget _colonneMontant(String label, double valeur) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte3)),
        Text(valeur.toStringAsFixed(0), style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: SSMPalette.texte1)),
      ],
    );
  }

  Future<void> _dialogPaiementRapide() async {
    final classe = _classeActuelle;
    if (classe == null || _anneeId == null) {
      _afficherErreur('Classe ou année académique introuvable');
      return;
    }
    final resultat = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _DialogPaiementRapide(eleveId: widget.eleveId, classeId: classe['id'] as int, anneeId: _anneeId!),
    );
    if (resultat == null || !mounted) return;
    _afficherSucces('Paiement enregistré avec succès');
    _rechargerFinances();
    _rechargerChronologie();
  }

  // ══════════════════════════════════════════════════════
  // TAB 4 — NOTES
  // ══════════════════════════════════════════════════════

  // Le détail par matière (coefficients, notes, appréciations) n'est plus
  // disponible ici : il n'existe pas d'endpoint renvoyant un bulletin avec
  // ses bulletin_details en dehors du moment de sa génération (voir le
  // commentaire en tête de apercu_bulletin_screen.dart). Cet onglet
  // affiche donc le résumé du module Bulletins (moyenne, rang, statut) et
  // renvoie vers l'onglet Bulletins pour le PDF complet.
  Widget _tabNotes() {
    if (_periodes.isEmpty) {
      return Center(child: Text('Aucune période académique disponible', style: GoogleFonts.inter(color: SSMPalette.texte3)));
    }

    final periodeId = _periodeSelectionneeId ?? (_periodes.first['id'] as int);
    final bulletin = _bulletins[periodeId];
    final moyenneGenerale = bulletin != null ? double.tryParse(bulletin['moyenne_generale'].toString()) : null;
    final rang = bulletin?['rang'] as int?;
    final effectif = bulletin?['effectif_classe'] as int?;
    final statut = bulletin != null ? StatutBulletin.depuisApi(bulletin['statut'] as String) : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<int>(
          initialValue: periodeId,
          decoration: _decorationChamp('Période', dense: true),
          items: _periodes.cast<Map<String, dynamic>>().map((p) => DropdownMenuItem(value: p['id'] as int, child: Text(p['nom'] as String))).toList(),
          onChanged: (v) => setState(() => _periodeSelectionneeId = v),
        ),
        const SizedBox(height: 16),
        if (bulletin == null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Aucun bulletin généré pour cette période.', style: GoogleFonts.inter(color: SSMPalette.texte3)),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SSMPalette.indigoClair,
              borderRadius: BorderRadius.circular(SSMRayons.grand),
              border: Border.all(color: SSMPalette.indigo.withValues(alpha: 0.15)),
            ),
            child: Column(
              children: [
                Text('Moyenne générale', style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
                Text('${bulletin['moyenne_generale']}/20',
                    style: GoogleFonts.sora(fontSize: 32, fontWeight: FontWeight.w700, color: _couleurMoyenne(moyenneGenerale))),
                if (statut != null) SSMPill.couleur(label: statut.libelle, couleur: statut.couleur),
                if (rang != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Rang $rangème / ${effectif ?? '—'} élèves', style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2)),
                  ),
                const SizedBox(height: 8),
                Text('Détail par matière disponible dans le PDF (onglet Bulletins).',
                    style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte3)),
              ],
            ),
          ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  // TAB 5 — BULLETINS
  // ══════════════════════════════════════════════════════

  Widget _tabBulletins() {
    final periodesAvecBulletin = _periodes.where((p) => _bulletins[p['id'] as int] != null).toList();

    if (periodesAvecBulletin.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _boutonHistoriqueComplet(),
          const SizedBox(height: 40),
          Center(child: Text('Aucun bulletin disponible pour le moment', style: GoogleFonts.inter(color: SSMPalette.texte3))),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _boutonHistoriqueComplet(),
        const SizedBox(height: 12),
        ...periodesAvecBulletin.map((p) {
        final periodeId = p['id'] as int;
        final periodeNom = p['nom'] as String;
        final bulletin = _bulletins[periodeId]!;
        final bulletinId = bulletin['bulletin_id'] as int;
        final rang = bulletin['rang'] as int?;
        final effectif = bulletin['effectif_classe'] as int?;
        final statut = StatutBulletin.depuisApi(bulletin['statut'] as String);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SSMPanel(
            titre: periodeNom,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SSMPill.couleur(label: statut.libelle, couleur: statut.couleur),
                const SizedBox(height: 6),
                Text('${bulletin['moyenne_generale']}/20', style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2)),
                if (rang != null) Text('Rang $rang / ${effectif ?? '—'} élèves', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte3)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: SSMPalette.indigo, side: const BorderSide(color: SSMPalette.indigo)),
                        onPressed: () => _ouvrirApercuBulletin(bulletinId, periodeId, periodeNom, bulletin),
                        child: const Text('Aperçu'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: SSMPalette.indigo, side: const BorderSide(color: SSMPalette.indigo)),
                        onPressed: () => _telechargerBulletinPdf(bulletinId),
                        child: const Text('PDF'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: SSMPalette.teal, side: const BorderSide(color: SSMPalette.teal)),
                        onPressed: () => _envoyerBulletinWhatsApp(periodeNom, bulletin),
                        child: const Text('WhatsApp'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
        }),
      ],
    );
  }

  void _ouvrirHistoriqueComplet() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HistoriqueBulletinsEleveScreen(
          eleveId: widget.eleveId,
          nomEleve: '${_eleve?['nom'] ?? ''} ${_eleve?['prenom'] ?? ''}'.trim(),
        ),
      ),
    );
  }

  Widget _boutonHistoriqueComplet() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _ouvrirHistoriqueComplet,
        style: OutlinedButton.styleFrom(foregroundColor: SSMPalette.indigo, side: const BorderSide(color: SSMPalette.indigo)),
        icon: const Icon(Icons.history, size: 18),
        label: const Text("Voir l'historique complet (toutes années)"),
      ),
    );
  }

  // Réutilise l'écran de prévisualisation du module Bulletins plutôt que de
  // dupliquer un rendu ad hoc ici : le résumé connu (moyenne, rang, statut,
  // décision) est reconstruit à partir de ce qu'expose l'historique, le
  // détail par matière restant réservé au PDF (voir apercu_bulletin_screen.dart).
  void _ouvrirApercuBulletin(int bulletinId, int periodeId, String periodeNom, Map<String, dynamic> bulletin) {
    final resume = Bulletin(
      id: bulletinId,
      eleveId: widget.eleveId,
      nomEleve: '${_eleve?['nom'] ?? ''} ${_eleve?['prenom'] ?? ''}'.trim(),
      matriculeEleve: _eleve?['matricule'] as String?,
      classeId: _classeId ?? 0,
      nomClasse: bulletin['classe_nom'] as String?,
      periodeId: periodeId,
      nomPeriode: periodeNom,
      moyenneGenerale: double.tryParse(bulletin['moyenne_generale'].toString()) ?? 0,
      rang: bulletin['rang'] as int?,
      rangExAequo: bulletin['rang_ex_aequo'] as bool? ?? false,
      effectifClasse: (bulletin['effectif_classe'] as num?)?.toInt() ?? 0,
      totalCoefficients: 0,
      totalPoints: 0,
      statut: StatutBulletin.depuisApi(bulletin['statut'] as String),
      decisionConseil: DecisionConseil.depuisApi(bulletin['decision_conseil'] as String?),
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ApercuBulletinScreen(bulletinId: bulletinId, resume: resume)),
    ).then((_) => _chargerBulletins());
  }

  Future<void> _telechargerBulletinPdf(int bulletinId) async {
    try {
      final octets = await BulletinService.telechargerPdf(bulletinId);
      final dossier = await getTemporaryDirectory();
      final fichier = File('${dossier.path}/bulletin_$bulletinId.pdf');
      await fichier.writeAsBytes(octets);
      await OpenFile.open(fichier.path);
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // Barème d'appréciation par défaut du module Bulletins (voir
  // RegleAppreciationSeeder côté backend) — approximation client uniquement
  // pour le texte du message WhatsApp, la mention officielle par matière
  // n'étant plus disponible ici (voir commentaire de _tabNotes()).
  String _mentionApproximative(double? moyenne) {
    if (moyenne == null) return '—';
    if (moyenne >= 16) return 'Excellent';
    if (moyenne >= 14) return 'Très bien';
    if (moyenne >= 12) return 'Bien';
    if (moyenne >= 10) return 'Passable';
    return 'Insuffisant';
  }

  Future<void> _envoyerBulletinWhatsApp(String periodeNom, Map<String, dynamic> bulletin) async {
    final tel = _eleve?['telephone_parent'] as String?;
    if (tel == null || tel.isEmpty) {
      _afficherErreur('Aucun numéro de téléphone parent enregistré');
      return;
    }
    final moyenne = double.tryParse(bulletin['moyenne_generale'].toString());
    final message = WhatsAppService.messageBulletin(
      nomParent: 'Cher parent',
      nomEleve: '${_eleve?['nom']} ${_eleve?['prenom']}',
      classe: _classeActuelle?['nom']?.toString() ?? '',
      periode: periodeNom,
      moyenne: '${bulletin['moyenne_generale']}',
      mention: _mentionApproximative(moyenne),
      nomEcole: "L'établissement",
    );
    await WhatsAppService.envoyerMessage(numeroTelephone: tel, message: message);
  }

  // ══════════════════════════════════════════════════════
  // TAB 6 — DISCIPLINE
  // ══════════════════════════════════════════════════════

  Widget _tabDiscipline() {
    final retards = _sanctions.where((s) => s['type'] == 'retard').length;
    final avertissements = _sanctions.where((s) => s['type'] == 'avertissement').length;
    final exclusions = _sanctions.where((s) => s['type'] == 'exclusion').length;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            Row(
              children: [
                Expanded(child: _miniStat('$retards', 'retards', SSMPalette.ambre)),
                const SizedBox(width: 10),
                Expanded(child: _miniStat('$avertissements', 'avertissements', SSMPalette.ambre)),
                const SizedBox(width: 10),
                Expanded(child: _miniStat('$exclusions', 'exclusions', SSMPalette.rouge)),
              ],
            ),
            const SizedBox(height: 16),
            if (_sanctions.isEmpty)
              Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('Aucune sanction enregistrée', style: GoogleFonts.inter(color: SSMPalette.texte3))))
            else
              ..._sanctions.map((s) => _carteSanction(s as Map<String, dynamic>)),
          ],
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            backgroundColor: SSMPalette.rouge,
            foregroundColor: Colors.white,
            onPressed: _dialogAjouterSanction,
            icon: const Icon(Icons.add),
            label: const Text('Ajouter une sanction'),
          ),
        ),
      ],
    );
  }

  Widget _carteSanction(Map<String, dynamic> s) {
    final type = s['type'] as String?;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SSMAlertItem(
        type: _typeAlerteSanction(type),
        icone: _iconeSanction(type),
        titre: '${_formatDateCourt(s['date_sanction'] as String?)} · ${(type ?? '').toUpperCase()}',
        sousTitre: s['description'] as String? ?? '',
      ),
    );
  }

  void _dialogAjouterSanction() {
    final descriptionController = TextEditingController();
    String type = 'retard';
    DateTime date = DateTime.now();
    bool enCours = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: SSMPalette.blanc,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
          title: Text('Ajouter une sanction', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: _decorationChamp('Type'),
                  items: const [
                    DropdownMenuItem(value: 'retard', child: Text('Retard')),
                    DropdownMenuItem(value: 'avertissement', child: Text('Avertissement')),
                    DropdownMenuItem(value: 'exclusion', child: Text('Exclusion')),
                    DropdownMenuItem(value: 'observation', child: Text('Observation')),
                    DropdownMenuItem(value: 'conseil_discipline', child: Text('Conseil de discipline')),
                  ],
                  onChanged: (v) => setStateDialog(() => type = v!),
                ),
                const SizedBox(height: 12),
                TextField(controller: descriptionController, maxLines: 3, decoration: _decorationChamp('Description *')),
                const SizedBox(height: 12),
                Material(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(SSMRayons.moyen),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(SSMRayons.moyen),
                    onTap: () async {
                      final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2100));
                      if (d != null) setStateDialog(() => date = d);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(SSMRayons.moyen), border: Border.all(color: const Color(0xFFE5E7EB))),
                      child: Row(
                        children: [
                          const Icon(Icons.date_range, size: 19, color: SSMPalette.texte3),
                          const SizedBox(width: 10),
                          Text('Date : ${date.day}/${date.month}/${date.year}', style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte1)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler', style: GoogleFonts.inter(color: SSMPalette.texte2))),
            ElevatedButton(
              style: _stylePrimaire(SSMPalette.rouge),
              onPressed: enCours || _classeId == null
                  ? null
                  : () async {
                      if (descriptionController.text.trim().isEmpty) return;
                      setStateDialog(() => enCours = true);
                      try {
                        await DisciplineService.creer(
                          eleveId: widget.eleveId,
                          classeId: _classeId!,
                          type: type,
                          description: descriptionController.text.trim(),
                          dateSanction: _formatDate(date),
                        );
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        _afficherSucces('Sanction enregistrée');
                        final sanctions = await DisciplineService.historiqueEleve(widget.eleveId);
                        setState(() => _sanctions = sanctions);
                        _rechargerChronologie();
                      } catch (e) {
                        setStateDialog(() => enCours = false);
                        _afficherErreur(e.toString().replaceAll('Exception: ', ''));
                      }
                    },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // TAB 7 — DOCUMENTS
  // ══════════════════════════════════════════════════════

  Widget _tabDocuments() {
    final documents = (_details?['documents'] as List?) ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GestureDetector(
          onTap: _dialogUploadDocument,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(SSMRayons.grand),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1.4),
            ),
            child: Column(
              children: [
                Icon(Icons.upload_file, size: 40, color: SSMPalette.texte3),
                const SizedBox(height: 8),
                Text('Ajouter un document', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
                Text('Tap pour sélectionner', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte3)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (documents.isEmpty)
          Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('Aucun document', style: GoogleFonts.inter(color: SSMPalette.texte3))))
        else
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.95,
            children: documents.map((d) => _carteDocument(d as Map<String, dynamic>)).toList(),
          ),
      ],
    );
  }

  Widget _carteDocument(Map<String, dynamic> doc) {
    final couleur = _couleurTypeDocument(doc['type'] as String?);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SSMPalette.blanc,
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        border: Border.all(color: SSMPalette.bordure),
      ),
      child: Column(
        children: [
          Icon(_iconeTypeDocument(doc['type'] as String?), size: 48, color: couleur),
          const SizedBox(height: 8),
          Text(doc['nom'] as String? ?? '', textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
          Text(doc['type'] as String? ?? '', style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte3)),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.download, size: 18, color: SSMPalette.indigo),
                onPressed: () => launchUrl(Uri.parse(doc['url_fichier'] as String)),
              ),
              IconButton(
                icon: const Icon(Icons.delete, size: 18, color: SSMPalette.rouge),
                onPressed: () async {
                  try {
                    await EleveService.supprimerDocument(widget.eleveId, doc['id'] as int);
                    _afficherSucces('Document supprimé');
                    _rechargerDocuments();
                  } catch (e) {
                    _afficherErreur(e.toString().replaceAll('Exception: ', ''));
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _dialogUploadDocument() {
    final nomController = TextEditingController();
    String type = 'autre';
    File? fichier;
    String? nomFichier;
    bool enCours = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: SSMPalette.blanc,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
          title: Text('Ajouter un document', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nomController, decoration: _decorationChamp('Nom du document *')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: _decorationChamp('Type *'),
                  items: const [
                    DropdownMenuItem(value: 'acte_naissance', child: Text('Acte de naissance')),
                    DropdownMenuItem(value: 'certificat_scolarite', child: Text('Certificat de scolarité')),
                    DropdownMenuItem(value: 'photo', child: Text('Photo')),
                    DropdownMenuItem(value: 'bulletin', child: Text('Bulletin')),
                    DropdownMenuItem(value: 'certificat_transfert', child: Text('Certificat de transfert')),
                    DropdownMenuItem(value: 'autre', child: Text('Autre')),
                  ],
                  onChanged: (v) => setStateDialog(() => type = v!),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SSMPalette.indigo,
                    side: const BorderSide(color: SSMPalette.indigo),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
                  ),
                  onPressed: () async {
                    final resultat = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png']);
                    if (resultat != null && resultat.files.single.path != null) {
                      setStateDialog(() {
                        fichier = File(resultat.files.single.path!);
                        nomFichier = resultat.files.single.name;
                      });
                    }
                  },
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Choisir le fichier'),
                ),
                if (nomFichier != null)
                  Padding(padding: const EdgeInsets.only(top: 8), child: Text(nomFichier!, style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte3))),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler', style: GoogleFonts.inter(color: SSMPalette.texte2))),
            ElevatedButton(
              style: _stylePrimaire(SSMPalette.indigo),
              onPressed: enCours
                  ? null
                  : () async {
                      if (nomController.text.trim().isEmpty || fichier == null) return;
                      setStateDialog(() => enCours = true);
                      try {
                        await EleveService.uploaderDocument(widget.eleveId, nom: nomController.text.trim(), type: type, fichier: fichier!);
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        _afficherSucces('Document ajouté avec succès');
                        _rechargerDocuments();
                        _rechargerChronologie();
                      } catch (e) {
                        setStateDialog(() => enCours = false);
                        _afficherErreur(e.toString().replaceAll('Exception: ', ''));
                      }
                    },
              child: const Text('Envoyer'),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // TAB 8 — CHRONOLOGIE
  // ══════════════════════════════════════════════════════

  Widget _tabChronologie() {
    if (_chronologieComplete.isEmpty) {
      return Center(child: Text('Aucun événement enregistré', style: GoogleFonts.inter(color: SSMPalette.texte3)));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _chronologieComplete.length,
      itemBuilder: (context, i) {
        final evt = _chronologieComplete[i] as Map<String, dynamic>;
        final couleur = _couleurTypeChronologie(evt['type'] as String?);
        final estDernier = i == _chronologieComplete.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(width: 14, height: 14, decoration: BoxDecoration(color: couleur, shape: BoxShape.circle)),
                  if (!estDernier) Expanded(child: Container(width: 2, color: couleur.withValues(alpha: 0.2))),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SSMPalette.blanc,
                    borderRadius: BorderRadius.circular(SSMRayons.grand),
                    border: Border.all(color: SSMPalette.bordure),
                  ),
                  child: Row(
                    children: [
                      Icon(_iconeTypeChronologie(evt['type'] as String?), color: couleur, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(evt['titre'] as String? ?? '', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
                            if (evt['description'] != null)
                              Text(evt['description'] as String, style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte3)),
                            Text(_formatDateHeure(evt['created_at'] as String?), style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte3)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tabPresences() {
    return HistoriquePresenceEleveScreen(
      eleveId: widget.eleveId,
      eleveNom: _eleve != null ? '${_eleve!['nom']} ${_eleve!['prenom']}' : null,
    );
  }

  // ══════════════════════════════════════════════════════
  // DIALOGS COMMUNS
  // ══════════════════════════════════════════════════════

  void _dialogCommuniquer() {
    final tel = _eleve?['telephone_parent'] as String?;
    if (tel == null || tel.isEmpty) {
      _afficherErreur('Aucun numéro de téléphone parent enregistré');
      return;
    }
    final nomEleve = '${_eleve?['nom']} ${_eleve?['prenom']}';
    final classeNom = _classeActuelle?['nom']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: SSMPalette.blanc,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.money_off, color: SSMPalette.rouge),
              title: const Text('Rappel de paiement'),
              onTap: () async {
                Navigator.pop(context);
                final message = WhatsAppService.messageRappelPaiement(
                  nomParent: 'Cher parent',
                  nomEleve: nomEleve,
                  classe: classeNom,
                  montantDu: '${_situationFinanciere?['reste_a_payer'] ?? 0}',
                  dateLimit: 'dès que possible',
                  nomEcole: "L'établissement",
                );
                await WhatsAppService.envoyerMessage(numeroTelephone: tel, message: message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: SSMPalette.ambre),
              title: const Text('Envoyer le bulletin'),
              onTap: () {
                Navigator.pop(context);
                _tabController.animateTo(4);
              },
            ),
            ListTile(
              leading: const Icon(Icons.event, color: SSMPalette.ambre),
              title: const Text('Convocation'),
              onTap: () async {
                Navigator.pop(context);
                final message = 'Bonjour,\n\nNous souhaitons vous rencontrer au sujet de $nomEleve ($classeNom). '
                    'Merci de vous présenter à l\'établissement dès que possible.';
                await WhatsAppService.envoyerMessage(numeroTelephone: tel, message: message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat, color: SSMPalette.teal),
              title: const Text('Information générale'),
              onTap: () async {
                Navigator.pop(context);
                await WhatsAppService.envoyerMessage(numeroTelephone: tel, message: 'Bonjour,');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _dialogModifierInfos() {
    final eleve = _eleve!;
    final nomController = TextEditingController(text: eleve['nom'] as String?);
    final prenomController = TextEditingController(text: eleve['prenom'] as String?);
    final lieuController = TextEditingController(text: eleve['lieu_naissance'] as String?);
    final nationaliteController = TextEditingController(text: eleve['nationalite'] as String?);
    final telephoneController = TextEditingController(text: eleve['telephone_parent'] as String?);
    final numeroAppelController = TextEditingController(text: eleve['numero_appel']?.toString());
    bool enCours = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: SSMPalette.blanc,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
          title: Text('Modifier les informations', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nomController, decoration: _decorationChamp('Nom *')),
                  const SizedBox(height: 10),
                  TextField(controller: prenomController, decoration: _decorationChamp('Prénom *')),
                  const SizedBox(height: 10),
                  TextField(controller: lieuController, decoration: _decorationChamp('Lieu de naissance')),
                  const SizedBox(height: 10),
                  TextField(controller: nationaliteController, decoration: _decorationChamp('Nationalité')),
                  const SizedBox(height: 10),
                  TextField(controller: telephoneController, decoration: _decorationChamp('Téléphone parent')),
                  const SizedBox(height: 10),
                  TextField(controller: numeroAppelController, keyboardType: TextInputType.number, decoration: _decorationChamp("N° d'appel")),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler', style: GoogleFonts.inter(color: SSMPalette.texte2))),
            ElevatedButton(
              style: _stylePrimaire(SSMPalette.indigo),
              onPressed: enCours
                  ? null
                  : () async {
                      setStateDialog(() => enCours = true);
                      try {
                        await EleveService.modifier(widget.eleveId, {
                          'nom': nomController.text.trim(),
                          'prenom': prenomController.text.trim(),
                          'sexe': eleve['sexe'],
                          'lieu_naissance': lieuController.text.trim(),
                          'nationalite': nationaliteController.text.trim(),
                          'telephone_parent': telephoneController.text.trim(),
                          'numero_appel': int.tryParse(numeroAppelController.text.trim()),
                        });
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        _afficherSucces('Informations mises à jour');
                        _chargerTout();
                      } catch (e) {
                        setStateDialog(() => enCours = false);
                        _afficherErreur(e.toString().replaceAll('Exception: ', ''));
                      }
                    },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  void _dialogChangerStatut() {
    String statut = _eleve!['statut'] as String? ?? 'actif';
    final motifController = TextEditingController();
    bool enCours = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: SSMPalette.blanc,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
          title: Text('Changer le statut', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: statut,
                decoration: _decorationChamp('Statut'),
                items: const [
                  DropdownMenuItem(value: 'actif', child: Text('Actif')),
                  DropdownMenuItem(value: 'suspendu', child: Text('Suspendu')),
                  DropdownMenuItem(value: 'exclu', child: Text('Exclu')),
                  DropdownMenuItem(value: 'transfere', child: Text('Transféré')),
                  DropdownMenuItem(value: 'diplome', child: Text('Diplômé')),
                  DropdownMenuItem(value: 'abandon', child: Text('Abandon')),
                ],
                onChanged: (v) => setStateDialog(() => statut = v!),
              ),
              const SizedBox(height: 12),
              TextField(controller: motifController, decoration: _decorationChamp('Motif (optionnel)')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler', style: GoogleFonts.inter(color: SSMPalette.texte2))),
            ElevatedButton(
              style: _stylePrimaire(SSMPalette.ambre),
              onPressed: enCours
                  ? null
                  : () async {
                      setStateDialog(() => enCours = true);
                      try {
                        await EleveService.changerStatut(widget.eleveId, statut, motif: motifController.text.trim().isEmpty ? null : motifController.text.trim());
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        _afficherSucces('Statut mis à jour');
                        _chargerTout();
                      } catch (e) {
                        setStateDialog(() => enCours = false);
                        _afficherErreur(e.toString().replaceAll('Exception: ', ''));
                      }
                    },
              child: const Text('Confirmer'),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// Delegate — TabBar sticky
// ══════════════════════════════════════════════════════════

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget tabBar;
  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => tabBar;

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}

// ══════════════════════════════════════════════════════════
// Dialog : Enregistrer un paiement rapide pour cet élève
// ══════════════════════════════════════════════════════════

class _DialogPaiementRapide extends StatefulWidget {
  final int eleveId;
  final int classeId;
  final int anneeId;

  const _DialogPaiementRapide({required this.eleveId, required this.classeId, required this.anneeId});

  @override
  State<_DialogPaiementRapide> createState() => _DialogPaiementRapideState();
}

class _DialogPaiementRapideState extends State<_DialogPaiementRapide> {
  List<FraisScolaire> _frais = [];
  FraisScolaire? _fraisSelectionne;
  EcheanceFrais? _echeanceSelectionnee;
  String _modePaiement = 'especes';
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
      final frais = await FraisScolaireService.getFrais(
        classeId: widget.classeId,
        anneeScolaireId: widget.anneeId,
        actif: true,
      );
      setState(() {
        _frais = frais;
        _fraisSelectionne = frais.isNotEmpty ? frais.first : null;
        _chargement = false;
      });
      _recalculerMontant();
    } catch (e) {
      setState(() => _chargement = false);
    }
  }

  void _recalculerMontant() {
    final montant = _echeanceSelectionnee?.montant ?? _fraisSelectionne?.montant;
    _montantController.text = montant != null
        ? (montant == montant.roundToDouble() ? montant.toInt().toString() : montant.toString())
        : '';
  }

  Future<void> _enregistrer() async {
    final montant = double.tryParse(_montantController.text.replaceAll(',', '.'));
    if (_fraisSelectionne == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sélectionnez un frais'), backgroundColor: SSMPalette.rouge));
      return;
    }
    if (montant == null || montant <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Montant invalide'), backgroundColor: SSMPalette.rouge));
      return;
    }

    setState(() => _enregistrement = true);

    try {
      await PaiementService.enregistrer(
        eleveId: widget.eleveId,
        fraisScolaireId: _fraisSelectionne!.id!,
        echeanceId: _echeanceSelectionnee?.id,
        montant: montant,
        modePaiement: _modePaiement,
        datePaiement: formatDateApi(_date),
        reference: _referenceController.text.isEmpty ? null : _referenceController.text,
      );
      if (mounted) {
        Navigator.pop(context, {
          'montant': montant,
          'tranche_label': _echeanceSelectionnee?.libelle ?? _fraisSelectionne!.nom,
        });
      }
    } catch (e) {
      setState(() => _enregistrement = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: SSMPalette.rouge));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final echeances = _fraisSelectionne?.echeances ?? [];

    return AlertDialog(
      backgroundColor: SSMPalette.blanc,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
      title: Text('Enregistrer un paiement', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_chargement)
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: LinearProgressIndicator(color: SSMPalette.indigo))
              else if (_frais.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('Aucun frais configuré pour cette classe', style: GoogleFonts.inter(color: SSMPalette.texte3)),
                )
              else ...[
                DropdownButtonFormField<FraisScolaire>(
                  initialValue: _fraisSelectionne,
                  isExpanded: true,
                  decoration: _decorationChamp('Frais *', icone: Icons.category_outlined),
                  items: _frais.map((f) => DropdownMenuItem(value: f, child: Text(f.nom))).toList(),
                  onChanged: (v) => setState(() {
                    _fraisSelectionne = v;
                    _echeanceSelectionnee = null;
                    _recalculerMontant();
                  }),
                ),
                if (echeances.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<EcheanceFrais?>(
                    initialValue: _echeanceSelectionnee,
                    isExpanded: true,
                    decoration: _decorationChamp('Échéance', icone: Icons.layers_outlined),
                    items: [
                      const DropdownMenuItem<EcheanceFrais?>(value: null, child: Text('Paiement complet')),
                      ...echeances.map((e) => DropdownMenuItem(value: e, child: Text(e.libelle))),
                    ],
                    onChanged: (v) => setState(() {
                      _echeanceSelectionnee = v;
                      _recalculerMontant();
                    }),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _montantController,
                  keyboardType: TextInputType.number,
                  decoration: _decorationChamp('Montant (FCFA)', icone: Icons.attach_money),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _modePaiement,
                  decoration: _decorationChamp('Mode de paiement *', icone: Icons.payment),
                  items: const [
                    DropdownMenuItem(value: 'especes', child: Text('Espèces')),
                    DropdownMenuItem(value: 'moov_money', child: Text('Moov Money')),
                    DropdownMenuItem(value: 'wave', child: Text('Wave')),
                    DropdownMenuItem(value: 'virement', child: Text('Virement')),
                    DropdownMenuItem(value: 'cheque', child: Text('Chèque')),
                  ],
                  onChanged: (v) => setState(() => _modePaiement = v!),
                ),
                const SizedBox(height: 12),
                Material(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(SSMRayons.moyen),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(SSMRayons.moyen),
                    onTap: () async {
                      final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2030));
                      if (d != null) setState(() => _date = d);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(SSMRayons.moyen), border: Border.all(color: const Color(0xFFE5E7EB))),
                      child: Row(
                        children: [
                          const Icon(Icons.date_range, size: 19, color: SSMPalette.texte3),
                          const SizedBox(width: 10),
                          Text('Date : ${_date.day}/${_date.month}/${_date.year}', style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte1)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _referenceController,
                  decoration: _decorationChamp('Référence (optionnel)', icone: Icons.receipt_outlined),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler', style: GoogleFonts.inter(color: SSMPalette.texte2))),
        ElevatedButton(
          style: _stylePrimaire(SSMPalette.teal),
          onPressed: _enregistrement || _frais.isEmpty ? null : _enregistrer,
          child: _enregistrement
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Enregistrer'),
        ),
      ],
    );
  }
}
