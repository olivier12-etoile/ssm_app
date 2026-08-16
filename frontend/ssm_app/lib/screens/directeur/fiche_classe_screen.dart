import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/classe_service.dart';
import '../../services/annee_service.dart';
import '../../services/eleve_service.dart';
import '../../services/absence_service.dart';
import '../../services/classe_matiere_service.dart';
import '../../services/affectation_service.dart';
import '../../services/matiere_service.dart';
import '../../services/utilisateur_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_avatar.dart';
import '../../widgets/ssm/ssm_panel.dart';
import '../../widgets/ssm/ssm_pill.dart';
import '../../widgets/ssm/ssm_quick_action_button.dart';
import '../../widgets/ssm/ssm_stat_card.dart';
import '../../widgets/ssm_widgets.dart' show SSMSectionTitre;
import 'fiche_utilisateur_screen.dart';

ButtonStyle _stylePrimaire(Color couleur) => ElevatedButton.styleFrom(
      backgroundColor: couleur,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
    );

InputDecoration _decorationChamp(String label, {bool dense = false, IconData? icone}) {
  return InputDecoration(
    labelText: label,
    labelStyle: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2),
    prefixIcon: icone != null ? Icon(icone, color: SSMPalette.texte3) : null,
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

Color _couleurMatiere(int matiereId) =>
    _paletteMatieres[matiereId % _paletteMatieres.length];

const List<Color> _couleursSuggerees = [
  Color(0xFF1E3A8A), // Indigo
  Color(0xFF0D9488), // Teal
  Color(0xFFD97706), // Ambre
  Color(0xFF16A34A), // Vert
  Color(0xFFDC2626), // Rouge
  Color(0xFFEA580C), // Orange
  Color(0xFF7C3AED), // Violet
  Color(0xFFDB2777), // Rose
  Color(0xFF0891B2), // Cyan
  Color(0xFF65A30D), // Lime
];

const List<String> _suggestionsMatieres = [
  'Mathématiques',
  'Français',
  'Anglais',
  'SVT',
  'Physique-Chimie',
  'Histoire-Géo',
  'Philosophie',
  'EPS',
  'Informatique',
  'Espagnol',
  'Économie',
  'Comptabilité',
  'Dessin',
  'Musique',
];

const List<String> _niveaux = [
  '6ème',
  '5ème',
  '4ème',
  '3ème',
  'Seconde',
  'Première',
  'Terminale',
];

class FicheClasseScreen extends StatefulWidget {
  final int classeId;

  const FicheClasseScreen({super.key, required this.classeId});

  @override
  State<FicheClasseScreen> createState() => _FicheClasseScreenState();
}

class _FicheClasseScreenState extends State<FicheClasseScreen> {
  Map<String, dynamic>? _classe;
  List<dynamic> _enseignants = [];
  List<dynamic> _matieresClasse = [];
  Map<String, dynamic>? _statistiques;

  List<dynamic> _eleves = [];
  Map<String, dynamic> _emploiDuTemps = {};

  List<dynamic> _toutesMatieres = [];
  List<dynamic> _tousEnseignants = [];
  List<dynamic> _toutesClasses = [];
  int? _anneeId;

  bool _chargement = true;
  String _rechercheEleve = '';

  // ── Présence (onglet Élèves) ─────────────────────────
  DateTime _dateSelectionnee = DateTime.now();
  Map<int, String> _presences = {};
  bool _chargementPresences = false;

  @override
  void initState() {
    super.initState();
    _chargerTout();
    _chargerPresences();
  }

  Future<void> _chargerTout() async {
    setState(() => _chargement = true);
    try {
      final resultatsInit = await Future.wait([
        ClasseService.details(widget.classeId),
        AffectationService.listerParClasse(widget.classeId),
      ]);
      final details = resultatsInit[0] as Map<String, dynamic>;
      final affectations = resultatsInit[1] as List;
      final classe = details['classe'] as Map<String, dynamic>;

      final annees = await AnneeService.listerAnnees();
      int? anneeId = classe['annee_academique_id'] as int?;
      if (anneeId == null) {
        final anneeEnCours = annees.firstWhere(
          (a) => a['statut'] == 'en_cours',
          orElse: () => annees.isNotEmpty ? annees.first : null,
        );
        anneeId = anneeEnCours?['id'] as int?;
      }

      List<dynamic> eleves = [];
      // L'emploi du temps est désormais géré par le nouveau module
      // (lib/screens/emploi_du_temps/) — cette fiche n'affiche plus la
      // mini-grille intégrée, qui reposait sur l'ancienne API.
      const Map<String, dynamic> emploi = {};
      if (anneeId != null) {
        eleves = await EleveService.elevesParClasse(widget.classeId, anneeId);
      }

      setState(() {
        _classe = classe;
        _enseignants = affectations;
        _matieresClasse = details['matieres'] as List;
        _statistiques = details['statistiques'] as Map<String, dynamic>;
        _anneeId = anneeId;
        _eleves = eleves;
        _emploiDuTemps = emploi;
        _chargement = false;
      });

      _chargerReferences();
    } catch (e) {
      setState(() => _chargement = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _chargerReferences() async {
    try {
      final toutesMatieres = await MatiereService.listerMatieres();

      final tousEnseignants = <dynamic>[];
      var page = 1;
      while (true) {
        final resultat = await UtilisateurService.lister(
          role: 'enseignant',
          page: page,
        );
        tousEnseignants.addAll((resultat['data'] as List?) ?? []);
        final dernierePage = resultat['last_page'] as int? ?? 1;
        if (page >= dernierePage) break;
        page++;
      }

      final toutesClasses = await ClasseService.listerClasses();

      setState(() {
        _toutesMatieres = toutesMatieres;
        _tousEnseignants = tousEnseignants;
        _toutesClasses = toutesClasses;
      });
    } catch (_) {
      // Listes de référence non bloquantes.
    }
  }

  // ── Présence (onglet Élèves) ─────────────────────────

  String _formatDateApi(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatDateAffichee(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _chargerPresences() async {
    setState(() => _chargementPresences = true);
    try {
      final absences = await AbsenceService.listerAbsences(
        classeId: widget.classeId,
        dateAbsence: _formatDateApi(_dateSelectionnee),
      );
      setState(() {
        _presences = {for (final a in absences) a['eleve_id'] as int: 'absent'};
        _chargementPresences = false;
      });
    } catch (e) {
      setState(() => _chargementPresences = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _choisirDatePresence() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dateSelectionnee,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (d != null) {
      setState(() => _dateSelectionnee = d);
      _chargerPresences();
    }
  }

  Future<void> _enregistrerPresence() async {
    final absents = _presences.entries
        .where((e) => e.value == 'absent')
        .map((e) => {'eleve_id': e.key})
        .toList();
    final nombrePresents = _presences.values
        .where((v) => v == 'present')
        .length;
    final nombreAbsents = absents.length;

    try {
      await AbsenceService.enregistrerAbsences(
        classeId: widget.classeId,
        dateAbsence: _formatDateApi(_dateSelectionnee),
        absences: absents,
      );
      _afficherSucces(
        'Présence enregistrée — $nombrePresents présents, $nombreAbsents absents',
      );
      _chargerPresences();
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _afficherErreur(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: SSMPalette.rouge),
    );
  }

  void _afficherSucces(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: SSMPalette.teal),
    );
  }

  void _bientot() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Fonctionnalité à venir')));
  }

  dynamic _affectationPourMatiere(int matiereId) {
    try {
      return _enseignants.firstWhere((a) => a['matiere_id'] == matiereId);
    } catch (_) {
      return null;
    }
  }

  Map<int, List<dynamic>> get _matieresParEnseignant {
    final map = <int, List<dynamic>>{};
    for (final a in _enseignants) {
      final id = a['enseignant_id'] as int;
      map.putIfAbsent(id, () => []).add(a);
    }
    return map;
  }

  List<dynamic> _creneauxPour({int? enseignantId, int? matiereId}) {
    final resultat = <dynamic>[];
    for (final jour in _jours) {
      final liste = (_emploiDuTemps[jour['cle']] as List?) ?? [];
      for (final c in liste) {
        if (enseignantId != null && c['enseignant_id'] != enseignantId)
          continue;
        if (matiereId != null && c['matiere_id'] != matiereId) continue;
        resultat.add({...c, 'jour_label': jour['label']});
      }
    }
    return resultat;
  }

  Future<void> _appeler(String telephone) async {
    final uri = Uri.parse('tel:$telephone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        backgroundColor: SSMPalette.fond,
        appBar: AppBar(
          backgroundColor: SSMPalette.blanc,
          foregroundColor: SSMPalette.texte2,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          iconTheme: const IconThemeData(color: SSMPalette.texte2),
          title: Text(
            _classe?['nom'] as String? ?? 'Fiche classe',
            style: GoogleFonts.sora(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: SSMPalette.indigo,
            ),
          ),
        ),
        body: _chargement || _classe == null
            ? const Center(
                child: CircularProgressIndicator(color: SSMPalette.indigo),
              )
            : NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverToBoxAdapter(child: _carteEnTeteClasse(context)),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _TabBarDelegate(_tabBar()),
                  ),
                ],
                body: TabBarView(
                  children: [
                    _tabInfos(),
                    _tabEleves(),
                    _tabProfesseurs(),
                    _tabMatieres(),
                    _tabEmploiDuTemps(),
                    _tabStatistiques(),
                  ],
                ),
              ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // EN-TÊTE — carte d'identité de la classe
  // ══════════════════════════════════════════════════════

  Widget _carteEnTeteClasse(BuildContext context) {
    final classe = _classe!;
    final nom = classe['nom'] as String;
    final niveau = classe['niveau'] as String? ?? '';
    final serie = classe['serie'] as String?;
    final salle = classe['salle'] as String?;
    final nombreEleves = (classe['nombre_eleves'] as num?)?.toInt() ?? 0;
    final capaciteMax = (classe['capacite_max'] as num?)?.toInt() ?? 50;
    final nombreMatieres = _matieresClasse.length;
    final nombreProfs = _enseignants
        .map((e) => e['enseignant_id'])
        .toSet()
        .length;
    final pourcentage = capaciteMax > 0
        ? (nombreEleves / capaciteMax).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SSMPalette.blanc,
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        border: Border.all(color: SSMPalette.bordure),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: SSMPalette.indigo.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(SSMRayons.grand),
                ),
                child: const Icon(Icons.class_, color: SSMPalette.indigo),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nom,
                      style: GoogleFonts.sora(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: SSMPalette.texte1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        SSMPill.couleur(label: niveau, couleur: SSMPalette.indigo),
                        if (serie != null) SSMPill.couleur(label: serie, couleur: SSMPalette.teal),
                        if (salle != null) SSMPill.couleur(label: salle, couleur: SSMPalette.texte2),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _statEnTete(Icons.people_outline, '$nombreEleves élèves')),
              Expanded(child: _statEnTete(Icons.menu_book_outlined, '$nombreMatieres matières')),
              Expanded(child: _statEnTete(Icons.school_outlined, '$nombreProfs profs')),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pourcentage,
              minHeight: 6,
              backgroundColor: SSMPalette.bordure,
              color: pourcentage >= 1
                  ? SSMPalette.rouge
                  : pourcentage >= 0.8
                  ? SSMPalette.ambre
                  : SSMPalette.teal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$nombreEleves / $capaciteMax places',
            style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte3),
          ),
        ],
      ),
    );
  }

  Widget _statEnTete(IconData icone, String label) {
    return Row(
      children: [
        Icon(icone, size: 15, color: SSMPalette.texte3),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _tabBar() {
    return Container(
      color: SSMPalette.blanc,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: SSMPalette.bordure)),
      ),
      child: TabBar(
        isScrollable: true,
        labelColor: SSMPalette.indigo,
        unselectedLabelColor: SSMPalette.texte3,
        indicatorColor: SSMPalette.ambre,
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w400, fontSize: 13),
        tabs: const [
          Tab(text: '📋 Infos'),
          Tab(text: '👥 Élèves'),
          Tab(text: '👨‍🏫 Profs'),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.menu_book, size: 16),
                SizedBox(width: 6),
                Text('Matières & Profs'),
              ],
            ),
          ),
          Tab(text: '📅 EDT'),
          Tab(text: '📊 Stats'),
        ],
      ),
    );
  }

  Widget _carteGlass({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SSMPalette.blanc,
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        border: Border.all(color: SSMPalette.bordure),
      ),
      child: child,
    );
  }

  // ══════════════════════════════════════════════════════
  // TAB 1 — INFOS GÉNÉRALES
  // ══════════════════════════════════════════════════════

  Widget _tabInfos() {
    final classe = _classe!;
    final prof = classe['professeur_principal'] as Map<String, dynamic>?;
    final annee = classe['annee'] as Map<String, dynamic>?;
    final statut = classe['statut'] as String? ?? 'active';
    final actif = statut == 'active';
    final createdAt = (classe['created_at'] as String?)?.split('T').first;
    final nombreEleves = (classe['nombre_eleves'] as num?)?.toInt() ?? 0;
    final capaciteMax = (classe['capacite_max'] as num?)?.toInt() ?? 50;
    final pourcentage = capaciteMax > 0
        ? (nombreEleves / capaciteMax).clamp(0.0, 1.0)
        : 0.0;

    return RefreshIndicator(
      onRefresh: _chargerTout,
      color: SSMPalette.indigo,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SSMPanel(
            titre: 'Informations générales',
            child: Column(
              children: [
                _ligneInfo(Icons.class_outlined, 'Nom', classe['nom'] as String),
                _ligneInfo(
                  Icons.layers_outlined,
                  'Niveau',
                  classe['niveau'] as String? ?? '—',
                ),
                _ligneInfo(
                  Icons.bookmark_outline,
                  'Série',
                  classe['serie'] as String? ?? '—',
                ),
                _ligneInfo(
                  Icons.room_outlined,
                  'Salle',
                  classe['salle'] as String? ?? '—',
                  dernier: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SSMPanel(
            titre: 'Capacité',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pourcentage,
                    minHeight: 8,
                    backgroundColor: SSMPalette.bordure,
                    color: pourcentage >= 1
                        ? SSMPalette.rouge
                        : pourcentage >= 0.8
                        ? SSMPalette.ambre
                        : SSMPalette.teal,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$nombreEleves / $capaciteMax élèves',
                  style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SSMPanel(
            titre: 'Professeur principal',
            child: prof != null
                ? Row(
                    children: [
                      SSMAvatar(
                        nom: prof['name'] as String,
                        photoUrl: prof['photo_url'] as String?,
                        rayon: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        prof['name'] as String,
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: SSMPalette.texte1),
                      ),
                    ],
                  )
                : Text(
                    'Non défini',
                    style: GoogleFonts.inter(fontSize: 14, color: SSMPalette.texte3),
                  ),
          ),
          const SizedBox(height: 16),
          SSMPanel(
            titre: 'Autres informations',
            child: Column(
              children: [
                _ligneInfo(
                  Icons.calendar_month_outlined,
                  'Année académique',
                  annee?['libelle'] as String? ?? '—',
                ),
                _ligneInfo(Icons.event_outlined, 'Créée le', createdAt ?? '—'),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: SSMPalette.texte3.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(Icons.info_outline, size: 17, color: SSMPalette.texte3),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Statut',
                        style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte3),
                      ),
                      const Spacer(),
                      SSMPill.couleur(
                        label: actif ? 'Active' : 'Inactive',
                        couleur: actif ? SSMPalette.teal : SSMPalette.texte3,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _afficherDialogModifierClasse,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Modifier'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: actif
                    ? OutlinedButton.icon(
                        onPressed: _archiverClasse,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: SSMPalette.rouge,
                          side: const BorderSide(color: SSMPalette.rouge),
                        ),
                        icon: const Icon(Icons.archive_outlined, size: 16),
                        label: const Text('Archiver'),
                      )
                    : OutlinedButton.icon(
                        onPressed: _activerClasse,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: SSMPalette.teal,
                          side: const BorderSide(color: SSMPalette.teal),
                        ),
                        icon: const Icon(Icons.check_circle_outline, size: 16),
                        label: const Text('Activer'),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _ligneInfo(IconData icone, String label, String valeur, {bool dernier = false}) {
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
            decoration: BoxDecoration(
              color: SSMPalette.indigo.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icone, size: 17, color: SSMPalette.indigo),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte3)),
                Text(
                  valeur,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: SSMPalette.texte1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _archiverClasse() async {
    try {
      await ClasseService.archiver(widget.classeId);
      _afficherSucces('Classe archivée');
      _chargerTout();
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _activerClasse() async {
    try {
      await ClasseService.activer(widget.classeId);
      _afficherSucces('Classe réactivée');
      _chargerTout();
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _afficherDialogModifierClasse() async {
    final classe = _classe!;
    final nomController = TextEditingController(text: classe['nom'] as String);
    final serieController = TextEditingController(
      text: classe['serie'] as String? ?? '',
    );
    final salleController = TextEditingController(
      text: classe['salle'] as String? ?? '',
    );
    final capaciteController = TextEditingController(
      text: '${classe['capacite_max'] ?? 50}',
    );
    String niveau = classe['niveau'] as String? ?? _niveaux.first;
    String statut = classe['statut'] as String? ?? 'active';
    int? professeurPrincipalId = classe['professeur_principal_id'] as int?;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SSMRayons.grand),
            ),
            backgroundColor: SSMPalette.blanc,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500, maxHeight: 640),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Modifier la classe',
                      style: GoogleFonts.sora(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: SSMPalette.indigo,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: nomController,
                              decoration: _decorationChamp('Nom *', icone: Icons.class_outlined),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _niveaux.contains(niveau) ? niveau : null,
                              decoration: _decorationChamp('Niveau *', icone: Icons.layers_outlined),
                              items: _niveaux
                                  .map(
                                    (n) => DropdownMenuItem(
                                      value: n,
                                      child: Text(n),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setStateDialog(() => niveau = v ?? niveau),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: serieController,
                              decoration: _decorationChamp('Série', icone: Icons.bookmark_outline),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: salleController,
                              decoration: _decorationChamp('Salle', icone: Icons.room_outlined),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: capaciteController,
                              keyboardType: TextInputType.number,
                              decoration: _decorationChamp('Capacité max *', icone: Icons.people_outline),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Text(
                                  'Statut :',
                                  style: GoogleFonts.inter(fontSize: 14, color: SSMPalette.texte2),
                                ),
                                const SizedBox(width: 12),
                                SegmentedButton<String>(
                                  style: SegmentedButton.styleFrom(
                                    selectedBackgroundColor: SSMPalette.indigo,
                                    selectedForegroundColor: Colors.white,
                                    foregroundColor: SSMPalette.texte2,
                                  ),
                                  segments: const [
                                    ButtonSegment(
                                      value: 'active',
                                      label: Text('Active'),
                                    ),
                                    ButtonSegment(
                                      value: 'inactive',
                                      label: Text('Inactive'),
                                    ),
                                  ],
                                  selected: {statut},
                                  onSelectionChanged: (s) =>
                                      setStateDialog(() => statut = s.first),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<int>(
                              value: professeurPrincipalId,
                              isExpanded: true,
                              decoration: _decorationChamp('Professeur principal', icone: Icons.school_outlined),
                              hint: const Text('Aucun'),
                              items: _tousEnseignants
                                  .map(
                                    (e) => DropdownMenuItem<int>(
                                      value: e['id'] as int,
                                      child: Text(e['name'] as String),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setStateDialog(
                                () => professeurPrincipalId = v,
                              ),
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
                            onPressed: () async {
                              try {
                                await ClasseService.modifier(
                                  widget.classeId,
                                  nom: nomController.text,
                                  niveau: niveau,
                                  serie: serieController.text.isEmpty
                                      ? null
                                      : serieController.text,
                                  salle: salleController.text.isEmpty
                                      ? null
                                      : salleController.text,
                                  capaciteMax: int.tryParse(
                                    capaciteController.text,
                                  ),
                                  statut: statut,
                                  professeurPrincipalId: professeurPrincipalId,
                                );
                                if (context.mounted) Navigator.pop(context);
                                _afficherSucces('Classe modifiée avec succès');
                                _chargerTout();
                              } catch (e) {
                                _afficherErreur(
                                  e.toString().replaceAll('Exception: ', ''),
                                );
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
  // TAB 2 — ÉLÈVES
  // ══════════════════════════════════════════════════════

  List<dynamic> get _elevesFiltres {
    if (_rechercheEleve.isEmpty) return _eleves;
    final q = _rechercheEleve.toLowerCase();
    return _eleves.where((e) {
      return (e['nom'] as String).toLowerCase().contains(q) ||
          (e['prenom'] as String).toLowerCase().contains(q) ||
          (e['matricule'] as String).toLowerCase().contains(q);
    }).toList();
  }

  Widget _tabEleves() {
    return RefreshIndicator(
      onRefresh: _chargerTout,
      color: SSMPalette.indigo,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${_eleves.length} élève(s) inscrit(s)',
            style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
          ),
          const SizedBox(height: 16),
          _sectionPresence(),
          const SizedBox(height: 16),
          TextField(
            onChanged: (v) => setState(() => _rechercheEleve = v),
            decoration: _decorationChamp('Rechercher un élève', icone: Icons.search),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SSMQuickActionButton(
                icone: Icons.person_add_alt_1,
                label: 'Ajouter un élève',
                variante: SSMActionVariante.primaire,
                onTap: _afficherDialogAjouterEleve,
              ),
              SSMQuickActionButton(
                icone: Icons.compare_arrows,
                label: 'Transférer',
                variante: SSMActionVariante.teal,
                onTap: () => _afficherDialogTransfert(),
              ),
              SSMQuickActionButton(
                icone: Icons.picture_as_pdf,
                label: 'Imprimer liste',
                variante: SSMActionVariante.rouge,
                onTap: () async {
                  try {
                    final chemin = await ClasseService.exporterPdf(
                      widget.classeId,
                    );
                    await OpenFile.open(chemin);
                  } catch (e) {
                    _afficherErreur(e.toString().replaceAll('Exception: ', ''));
                  }
                },
              ),
              SSMQuickActionButton(
                icone: Icons.table_chart,
                label: 'Export Excel',
                variante: SSMActionVariante.gris,
                onTap: () async {
                  try {
                    final chemin = await ClasseService.exporterExcel(
                      widget.classeId,
                    );
                    await OpenFile.open(chemin);
                  } catch (e) {
                    _afficherErreur(e.toString().replaceAll('Exception: ', ''));
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_elevesFiltres.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Aucun élève',
                  style: GoogleFonts.inter(color: SSMPalette.texte3),
                ),
              ),
            )
          else
            ..._elevesFiltres.map(_carteEleve),
        ],
      ),
    );
  }

  // ── Présence ──────────────────────────────────────────

  Widget _sectionPresence() {
    final nombrePresents = _presences.values
        .where((v) => v == 'present')
        .length;
    final nombreAbsents = _presences.values.where((v) => v == 'absent').length;
    final nombreNonMarques = _eleves.length - _presences.length;
    final auMoinsUnMarque = _presences.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.calendar_today,
              color: SSMPalette.indigo,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Présence du ${_formatDateAffichee(_dateSelectionnee)}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: SSMPalette.texte2,
                ),
              ),
            ),
            TextButton(
              onPressed: _choisirDatePresence,
              child: Text(
                'Changer',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: SSMPalette.indigo,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: SSMPalette.blanc,
            borderRadius: BorderRadius.circular(SSMRayons.grand),
            border: Border.all(color: SSMPalette.bordure),
          ),
          child: _chargementPresences
              ? const Center(
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: SSMPalette.indigo),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: SSMPalette.tealClair,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: SSMPalette.teal,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$nombrePresents présents',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: SSMPalette.teal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: SSMPalette.rougeClair,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.cancel,
                                color: SSMPalette.rouge,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$nombreAbsents absents',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: SSMPalette.rouge,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '$nombreNonMarques non marqués',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: nombreNonMarques > 0
                            ? SSMPalette.ambre
                            : SSMPalette.texte3,
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: auMoinsUnMarque ? _enregistrerPresence : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: SSMPalette.indigo,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
              disabledBackgroundColor: SSMPalette.indigo.withValues(alpha: 0.3),
            ),
            icon: const Icon(Icons.save, size: 18),
            label: const Text('Enregistrer la présence'),
          ),
        ),
      ],
    );
  }

  Widget _carteEleve(dynamic eleve) {
    final photoUrl = eleve['photo_url'] as String?;
    final sexe = eleve['sexe'] as String?;
    final statut = eleve['inscription_statut'] as String?;
    final eleveId = eleve['id'] as int;
    final presence = _presences[eleveId];
    final couleurBordure = presence == 'present'
        ? SSMPalette.teal
        : presence == 'absent'
        ? SSMPalette.rouge
        : SSMPalette.bordure;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SSMPalette.blanc,
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        border: Border(
          top: BorderSide(color: SSMPalette.bordure),
          right: BorderSide(color: SSMPalette.bordure),
          bottom: BorderSide(color: SSMPalette.bordure),
          left: BorderSide(color: couleurBordure, width: 4),
        ),
      ),
      child: Row(
        children: [
          SSMAvatar(nom: eleve['nom'] as String? ?? '?', photoUrl: photoUrl, sexe: sexe, rayon: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${eleve['nom']} ${eleve['prenom']}',
                  style: GoogleFonts.sora(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: SSMPalette.texte1,
                  ),
                ),
                Text(
                  'Matricule: ${eleve['matricule']}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: SSMPalette.texte3,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      sexe == 'M' ? Icons.boy : Icons.girl,
                      color: sexe == 'M' ? SSMPalette.indigo : SSMPalette.teal,
                      size: 16,
                    ),
                    if (statut != null) ...[
                      const SizedBox(width: 6),
                      SSMPill.couleur(label: statut, couleur: SSMPalette.teal),
                    ],
                  ],
                ),
              ],
            ),
          ),
          _boutonPresence(
            eleveId: eleveId,
            etat: 'present',
            actif: presence == 'present',
            icone: Icons.check,
            couleur: SSMPalette.teal,
          ),
          const SizedBox(width: 8),
          _boutonPresence(
            eleveId: eleveId,
            etat: 'absent',
            actif: presence == 'absent',
            icone: Icons.close,
            couleur: SSMPalette.rouge,
          ),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert,
              size: 20,
              color: SSMPalette.texte2,
            ),
            onSelected: (action) {
                  switch (action) {
                    case 'fiche':
                      Navigator.pushNamed(
                        context,
                        '/eleve/fiche',
                        arguments: {'eleveId': eleve['id']},
                      );
                      break;
                    case 'transferer':
                      _afficherDialogTransfert(
                        eleveIdPreselectionne: eleve['id'] as int,
                      );
                      break;
                    case 'retirer':
                      _bientot();
                      break;
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'fiche', child: Text('Voir fiche')),
                  PopupMenuItem(value: 'transferer', child: Text('Transférer')),
                  PopupMenuItem(value: 'retirer', child: Text('Retirer')),
                ],
              ),
            ],
          ),
        );
  }

  Widget _boutonPresence({
    required int eleveId,
    required String etat,
    required bool actif,
    required IconData icone,
    required Color couleur,
  }) {
    return GestureDetector(
      onTap: () => setState(() => _presences[eleveId] = etat),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: actif ? couleur : couleur.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icone,
          color: actif ? Colors.white : couleur.withValues(alpha: 0.5),
          size: 20,
        ),
      ),
    );
  }

  Future<void> _afficherDialogAjouterEleve() async {
    final nomController = TextEditingController();
    final prenomController = TextEditingController();
    String sexe = 'M';
    DateTime? dateNaissance;

    if (_anneeId == null) {
      _afficherErreur('Aucune année académique active');
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: SSMPalette.blanc,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
            title: Text(
              'Ajouter un élève',
              style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
            ),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nomController,
                    decoration: _decorationChamp('Nom'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: prenomController,
                    decoration: _decorationChamp('Prénom'),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: SSMPalette.indigo,
                      selectedForegroundColor: Colors.white,
                      foregroundColor: SSMPalette.texte2,
                    ),
                    segments: const [
                      ButtonSegment(value: 'M', label: Text('M')),
                      ButtonSegment(value: 'F', label: Text('F')),
                    ],
                    selected: {sexe},
                    onSelectionChanged: (s) =>
                        setStateDialog(() => sexe = s.first),
                  ),
                  const SizedBox(height: 12),
                  Material(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(SSMRayons.moyen),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(SSMRayons.moyen),
                      onTap: () async {
                        final choisie = await showDatePicker(
                          context: context,
                          initialDate: DateTime(2015),
                          firstDate: DateTime(1995),
                          lastDate: DateTime.now(),
                        );
                        if (choisie != null) {
                          setStateDialog(() => dateNaissance = choisie);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(SSMRayons.moyen),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.cake_outlined, size: 19, color: SSMPalette.texte3),
                            const SizedBox(width: 10),
                            Text(
                              dateNaissance != null
                                  ? '${dateNaissance!.day}/${dateNaissance!.month}/${dateNaissance!.year}'
                                  : 'Date de naissance',
                              style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Annuler', style: GoogleFonts.inter(color: SSMPalette.texte2)),
              ),
              ElevatedButton(
                style: _stylePrimaire(SSMPalette.indigo),
                onPressed: () async {
                  if (nomController.text.isEmpty ||
                      prenomController.text.isEmpty ||
                      dateNaissance == null) {
                    return;
                  }
                  try {
                    await EleveService.creer(
                      nom: nomController.text,
                      prenom: prenomController.text,
                      sexe: sexe,
                      dateNaissance:
                          '${dateNaissance!.year.toString().padLeft(4, '0')}-'
                          '${dateNaissance!.month.toString().padLeft(2, '0')}-'
                          '${dateNaissance!.day.toString().padLeft(2, '0')}',
                      classeId: widget.classeId,
                      anneeAcademiqueId: _anneeId!,
                    );
                    if (context.mounted) Navigator.pop(context);
                    _afficherSucces('Élève ajouté avec succès');
                    _chargerTout();
                  } catch (e) {
                    _afficherErreur(e.toString().replaceAll('Exception: ', ''));
                  }
                },
                child: const Text('Ajouter'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _afficherDialogTransfert({int? eleveIdPreselectionne}) async {
    int? eleveId = eleveIdPreselectionne;
    int? classeDestinationId;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: SSMPalette.blanc,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
            title: Text(
              'Transférer un élève',
              style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
            ),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (eleveIdPreselectionne == null)
                    DropdownButtonFormField<int>(
                      value: eleveId,
                      isExpanded: true,
                      decoration: _decorationChamp('Élève'),
                      items: _eleves
                          .map(
                            (e) => DropdownMenuItem<int>(
                              value: e['id'] as int,
                              child: Text('${e['nom']} ${e['prenom']}'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setStateDialog(() => eleveId = v),
                    ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: classeDestinationId,
                    isExpanded: true,
                    decoration: _decorationChamp('Classe de destination'),
                    items: _toutesClasses
                        .where((c) => c['id'] != widget.classeId)
                        .map(
                          (c) => DropdownMenuItem<int>(
                            value: c['id'] as int,
                            child: Text(c['nom'] as String),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setStateDialog(() => classeDestinationId = v),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Annuler', style: GoogleFonts.inter(color: SSMPalette.texte2)),
              ),
              ElevatedButton(
                style: _stylePrimaire(SSMPalette.teal),
                onPressed: eleveId == null || classeDestinationId == null
                    ? null
                    : () async {
                        try {
                          await ClasseService.transfererEleve(
                            eleveId: eleveId!,
                            classeSourceId: widget.classeId,
                            classeDestinationId: classeDestinationId!,
                          );
                          if (context.mounted) Navigator.pop(context);
                          _afficherSucces('Élève transféré avec succès');
                          _chargerTout();
                        } catch (e) {
                          _afficherErreur(
                            e.toString().replaceAll('Exception: ', ''),
                          );
                        }
                      },
                child: const Text('Confirmer'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // TAB 3 — PROFESSEURS
  // ══════════════════════════════════════════════════════

  Widget _tabProfesseurs() {
    final prof = _classe!['professeur_principal'] as Map<String, dynamic>?;
    final matieresProfPrincipal = prof != null
        ? _enseignants
              .where(
                (e) =>
                    e['enseignant_id'] == _classe!['professeur_principal_id'],
              )
              .toList()
        : <dynamic>[];

    final matieresNonAffectees = _matieresClasse
        .where((m) => _affectationPourMatiere(m['matiere_id'] as int) == null)
        .toList();

    return RefreshIndicator(
      onRefresh: _chargerTout,
      color: SSMPalette.indigo,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (prof != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SSMPalette.ambreClair,
                borderRadius: BorderRadius.circular(SSMRayons.grand),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SSMPill(
                    label: 'PROFESSEUR PRINCIPAL',
                    couleur: SSMPalette.ambre,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SSMAvatar(
                        nom: prof['name'] as String,
                        photoUrl: prof['photo_url'] as String?,
                        couleur: SSMPalette.ambre,
                        rayon: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              prof['name'] as String,
                              style: GoogleFonts.sora(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: SSMPalette.texte1,
                              ),
                            ),
                            if (matieresProfPrincipal.isNotEmpty)
                              Wrap(
                                spacing: 6,
                                children: matieresProfPrincipal
                                    .map(
                                      (m) => Text(
                                        '${m['matiere_nom']} ',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: SSMPalette.texte2,
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          SSMSectionTitre(titre: 'Enseignants'),
          if (_matieresParEnseignant.isEmpty)
            Text(
              'Aucun enseignant affecté',
              style: GoogleFonts.inter(color: SSMPalette.texte2),
            )
          else
            ..._matieresParEnseignant.entries.map(
              (entry) => _carteEnseignant(entry.key, entry.value),
            ),

          if (matieresNonAffectees.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SSMPalette.ambreClair,
                borderRadius: BorderRadius.circular(SSMRayons.grand),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Non affectées',
                    style: GoogleFonts.sora(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: SSMPalette.ambre,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...matieresNonAffectees.map(
                    (m) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              m['matiere_nom'] as String,
                              style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte1),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _afficherDialogAffecterMatiere(
                              m['matiere_id'] as int,
                              m['matiere_nom'] as String,
                            ),
                            child: Text('Affecter', style: GoogleFonts.inter(color: SSMPalette.indigo)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _carteEnseignant(int enseignantId, List<dynamic> matieres) {
    final premiere = matieres.first;
    final telephone = premiere['enseignant_telephone'] as String?;
    final photoUrl = premiere['enseignant_photo_url'] as String?;
    final horaires = _creneauxPour(enseignantId: enseignantId);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SSMPalette.blanc,
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        border: Border.all(color: SSMPalette.bordure),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SSMAvatar(nom: premiere['enseignant_nom'] as String, photoUrl: photoUrl, rayon: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  premiere['enseignant_nom'] as String,
                  style: GoogleFonts.sora(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: SSMPalette.texte1,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        FicheUtilisateurScreen(userId: enseignantId),
                  ),
                ),
                child: Text('Voir profil', style: GoogleFonts.inter(color: SSMPalette.indigo)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: matieres.map((m) {
              final coef = m['coefficient'];
              return SSMPill.couleur(
                label: coef != null
                    ? '${m['matiere_nom']} (coef $coef)'
                    : '${m['matiere_nom']}',
                couleur: SSMPalette.teal,
              );
            }).toList(),
          ),
          if (horaires.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              horaires
                  .map(
                    (h) =>
                        '${h['jour_label']} ${(h['heure_debut'] as String).substring(0, 5)}',
                  )
                  .join(' • '),
              style: GoogleFonts.inter(
                fontSize: 11,
                color: SSMPalette.texte3,
              ),
            ),
          ],
          if (telephone != null) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => _appeler(telephone),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.phone, size: 13, color: SSMPalette.indigo),
                  const SizedBox(width: 4),
                  Text(
                    telephone,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: SSMPalette.indigo,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _afficherDialogAffecterMatiere(
    int matiereId,
    String matiereNom,
  ) async {
    int? enseignantId;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: SSMPalette.blanc,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
            title: Text(
              'Affecter — $matiereNom',
              style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
            ),
            content: DropdownButtonFormField<int>(
              value: enseignantId,
              isExpanded: true,
              decoration: _decorationChamp('Enseignant'),
              items: _tousEnseignants
                  .map(
                    (e) => DropdownMenuItem<int>(
                      value: e['id'] as int,
                      child: Text(e['name'] as String),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setStateDialog(() => enseignantId = v),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Annuler', style: GoogleFonts.inter(color: SSMPalette.texte2)),
              ),
              ElevatedButton(
                style: _stylePrimaire(SSMPalette.indigo),
                onPressed: enseignantId == null
                    ? null
                    : () async {
                        try {
                          await AffectationService.ajouterAffectation(
                            enseignantId: enseignantId!,
                            classeId: widget.classeId,
                            matiereId: matiereId,
                          );
                          if (context.mounted) Navigator.pop(context);
                          _afficherSucces('Enseignant affecté');
                          _chargerTout();
                        } catch (e) {
                          _afficherErreur(
                            e.toString().replaceAll('Exception: ', ''),
                          );
                        }
                      },
                child: const Text('Affecter'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // TAB 4 — MATIÈRES & PROFS (centre de contrôle)
  // ══════════════════════════════════════════════════════

  Color _couleurReelleMatiere(int matiereId) {
    final matiere = _toutesMatieres.firstWhere(
      (m) => m['id'] == matiereId,
      orElse: () => null,
    );
    return _couleurDepuisHex(matiere?['couleur'] as String?);
  }

  String? _codeReelMatiere(int matiereId) {
    final matiere = _toutesMatieres.firstWhere(
      (m) => m['id'] == matiereId,
      orElse: () => null,
    );
    return matiere?['code'] as String?;
  }

  Color _couleurDepuisHex(String? hex) {
    if (hex == null || hex.isEmpty) return SSMPalette.indigo;
    try {
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return SSMPalette.indigo;
    }
  }

  Widget _tabMatieres() {
    final nombreMatieres = _matieresClasse.length;
    final nombreAffectees = _matieresClasse
        .where((m) => _affectationPourMatiere(m['matiere_id'] as int) != null)
        .length;
    final nombreSansProf = nombreMatieres - nombreAffectees;

    return RefreshIndicator(
      onRefresh: _chargerTout,
      color: SSMPalette.indigo,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: SSMStatCard(
                  icone: Icons.menu_book_outlined,
                  couleur: SSMPalette.indigo,
                  valeur: '$nombreMatieres',
                  label: 'matières',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SSMStatCard(
                  icone: Icons.check_circle_outline,
                  couleur: SSMPalette.teal,
                  valeur: '$nombreAffectees',
                  label: 'affectées',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SSMStatCard(
                  icone: Icons.warning_amber_outlined,
                  couleur: nombreSansProf > 0 ? SSMPalette.ambre : SSMPalette.texte3,
                  valeur: '$nombreSansProf',
                  label: 'sans prof',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _boutonAjouterMatiere(),
          const SizedBox(height: 16),
          if (_matieresClasse.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Aucune matière configurée',
                  style: GoogleFonts.inter(color: SSMPalette.texte2),
                ),
              ),
            )
          else
            ..._matieresClasse.map((m) => _carteMatiere(m)),
        ],
      ),
    );
  }

  Widget _boutonAjouterMatiere() {
    return Material(
      color: SSMPalette.indigoClair,
      borderRadius: BorderRadius.circular(SSMRayons.grand),
      child: InkWell(
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        onTap: _afficherDialogAjouterMatiere,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SSMRayons.grand),
            border: Border.all(color: SSMPalette.indigo.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_circle_outline, color: SSMPalette.indigo),
              const SizedBox(width: 8),
              Text(
                'Ajouter une matière à cette classe',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: SSMPalette.indigo,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _carteMatiere(dynamic matiere) {
    final matiereId = matiere['matiere_id'] as int;
    final nom = matiere['matiere_nom'] as String;
    final coef = matiere['coefficient'];
    final code = _codeReelMatiere(matiereId);
    final couleur = _couleurReelleMatiere(matiereId);
    final affectation = _affectationPourMatiere(matiereId);
    final nomEnseignant = affectation != null
        ? affectation['enseignant_nom'] as String?
        : null;
    final photoEnseignant = affectation != null
        ? affectation['enseignant_photo_url'] as String?
        : null;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(SSMRayons.grand),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _ouvrirFicheMatiere(matiere, couleur),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: SSMPalette.blanc,
            borderRadius: BorderRadius.circular(SSMRayons.grand),
            border: Border(
              top: BorderSide(color: SSMPalette.bordure),
              right: BorderSide(color: SSMPalette.bordure),
              bottom: BorderSide(color: SSMPalette.bordure),
              left: BorderSide(color: couleur, width: 4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: couleur.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.book, color: couleur, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nom,
                          style: GoogleFonts.sora(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: SSMPalette.texte1,
                          ),
                        ),
                        if (code != null && code.isNotEmpty)
                          Text(
                            code,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              color: SSMPalette.texte3,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: SSMPalette.indigoClair,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Coef.',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: SSMPalette.texte3,
                          ),
                        ),
                        Text(
                          '$coef',
                          style: GoogleFonts.sora(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: SSMPalette.indigo,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: SSMPalette.indigo,
                    ),
                    tooltip: 'Modifier le coefficient',
                    onPressed: () =>
                        _afficherDialogModifierCoefficient(matiere),
                  ),
                ],
              ),
              const Divider(height: 20, color: SSMPalette.bordure),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Enseignant : ',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: SSMPalette.texte3,
                        ),
                      ),
                      if (nomEnseignant != null) ...[
                        SSMAvatar(nom: nomEnseignant, photoUrl: photoEnseignant, couleur: SSMPalette.teal, rayon: 14),
                        const SizedBox(width: 6),
                        Text(
                          nomEnseignant,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: SSMPalette.teal,
                          ),
                        ),
                      ] else ...[
                        const Icon(
                          Icons.warning_amber_outlined,
                          color: SSMPalette.ambre,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Non affecté',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: SSMPalette.ambre,
                          ),
                        ),
                      ],
                    ],
                  ),
                  TextButton(
                    onPressed: () => _afficherDialogAffecterEnseignant(matiere),
                    child: Text(
                      nomEnseignant != null ? 'Changer' : 'Affecter',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: SSMPalette.indigo,
                      ),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _confirmerRetraitMatiere(matiere),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: SSMPalette.rouge,
                    size: 16,
                  ),
                  label: Text(
                    'Retirer de la classe',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: SSMPalette.rouge,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _ouvrirFicheMatiere(dynamic matiere, Color couleur) {
    final matiereId = matiere['matiere_id'] as int;
    final affectation = _affectationPourMatiere(matiereId);
    Navigator.pushNamed(
      context,
      '/directeur/matiere/fiche',
      arguments: {
        'classeId': widget.classeId,
        'classeNom': _classe?['nom'] as String? ?? '',
        'matiereId': matiereId,
        'matiereNom': matiere['matiere_nom'] as String,
        'couleurMatiere': couleur,
        'coefficient': _coefficientDouble(matiere['coefficient']),
        'enseignantNom': affectation != null
            ? affectation['enseignant_nom'] as String?
            : null,
      },
    ).then((_) => _chargerTout());
  }

  double _coefficientDouble(dynamic valeur) =>
      double.tryParse(valeur.toString()) ?? 1.0;

  Future<void> _afficherDialogModifierCoefficient(dynamic matiere) async {
    final controller = TextEditingController(
      text: '${matiere['coefficient'] ?? 1}',
    );
    final nomClasse = _classe?['nom'] as String? ?? '';

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
        backgroundColor: SSMPalette.blanc,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Coefficient de ${matiere['matiere_nom']}',
                  style: GoogleFonts.sora(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: SSMPalette.indigo,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _decorationChamp('Coefficient').copyWith(hintText: 'ex: 3, 4.5, 7'),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ce coefficient est spécifique à $nomClasse',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: SSMPalette.texte3,
                  ),
                ),
                const SizedBox(height: 20),
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
                        onPressed: () async {
                          final coef = double.tryParse(
                            controller.text.replaceAll(',', '.'),
                          );
                          if (coef == null || coef < 0.5 || coef > 10) {
                            _afficherErreur(
                              'Le coefficient doit être compris entre 0.5 et 10',
                            );
                            return;
                          }
                          try {
                            await ClasseMatiereService.ajouter(
                              classeId: widget.classeId,
                              matiereId: matiere['matiere_id'] as int,
                              coefficient: coef,
                            );
                            if (context.mounted) Navigator.pop(context);
                            _afficherSucces('Coefficient mis à jour');
                            _chargerTout();
                          } catch (e) {
                            _afficherErreur(
                              e.toString().replaceAll('Exception: ', ''),
                            );
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
      ),
    );
  }

  Future<void> _afficherDialogAffecterEnseignant(dynamic matiere) async {
    final matiereId = matiere['matiere_id'] as int;
    final matiereNom = matiere['matiere_nom'] as String;
    final nomClasse = _classe?['nom'] as String? ?? '';
    final affectationActuelle = _affectationPourMatiere(matiereId);
    int? enseignantId = affectationActuelle?['enseignant_id'] as int?;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SSMRayons.grand),
            ),
            backgroundColor: SSMPalette.blanc,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enseignant pour $matiereNom',
                      style: GoogleFonts.sora(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: SSMPalette.indigo,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      nomClasse,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: SSMPalette.texte2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int?>(
                      value: enseignantId,
                      isExpanded: true,
                      decoration: _decorationChamp('Enseignant'),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text("Aucun (retirer l'affectation)"),
                        ),
                        ..._tousEnseignants.map((e) {
                          final id = e['id'] as int;
                          final matieresDeja =
                              (_matieresParEnseignant[id] ?? [])
                                  .map((a) => a['matiere_nom'] as String)
                                  .toSet()
                                  .join(', ');
                          return DropdownMenuItem<int?>(
                            value: id,
                            child: Text(
                              matieresDeja.isEmpty
                                  ? e['name'] as String
                                  : '${e['name']} ($matieresDeja)',
                            ),
                          );
                        }),
                      ],
                      onChanged: (v) => setStateDialog(() => enseignantId = v),
                    ),
                    const SizedBox(height: 20),
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
                            onPressed: () async {
                              try {
                                final ancienId =
                                    affectationActuelle?['id'] as int?;
                                if (ancienId != null) {
                                  await AffectationService.supprimerAffectation(
                                    ancienId,
                                  );
                                }
                                if (enseignantId != null) {
                                  await AffectationService.ajouterAffectation(
                                    enseignantId: enseignantId!,
                                    classeId: widget.classeId,
                                    matiereId: matiereId,
                                  );
                                }
                                if (context.mounted) Navigator.pop(context);
                                _afficherSucces(
                                  enseignantId != null
                                      ? 'Enseignant affecté'
                                      : 'Affectation retirée',
                                );
                                _chargerTout();
                              } catch (e) {
                                _afficherErreur(
                                  e.toString().replaceAll('Exception: ', ''),
                                );
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

  Future<void> _confirmerRetraitMatiere(dynamic matiere) async {
    final matiereId = matiere['matiere_id'] as int;
    final matiereNom = matiere['matiere_nom'] as String;
    final classeMatiereId = matiere['id'] as int;
    final nomClasse = _classe?['nom'] as String? ?? '';

    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
        backgroundColor: SSMPalette.blanc,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: SSMPalette.ambre,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Retirer $matiereNom de $nomClasse ?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.sora(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: SSMPalette.texte1,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Le coefficient et l'affectation de l'enseignant seront supprimés. Les notes saisies ne seront pas affectées.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: SSMPalette.texte2,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text('Annuler', style: GoogleFonts.inter(color: SSMPalette.texte2)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: _stylePrimaire(SSMPalette.rouge),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Retirer'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirme != true) return;

    try {
      final affectation = _affectationPourMatiere(matiereId);
      if (affectation != null) {
        await AffectationService.supprimerAffectation(affectation['id'] as int);
      }
      await ClasseMatiereService.supprimer(classeMatiereId);
      _afficherSucces('Matière retirée de la classe');
      _chargerTout();
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _afficherDialogAjouterMatiere() async {
    final nomController = TextEditingController();
    final codeController = TextEditingController();
    final coefController = TextEditingController();
    Color couleurSelectionnee = _couleursSuggerees.first;
    Map<String, dynamic>? enseignantSelectionne;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final nom = nomController.text.trim();
          final coef = double.tryParse(
            coefController.text.replaceAll(',', '.'),
          );

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SSMRayons.grand),
            ),
            backgroundColor: SSMPalette.blanc,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460, maxHeight: 760),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ajouter une matière',
                      style: GoogleFonts.sora(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: SSMPalette.indigo,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nom de la matière *',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: SSMPalette.texte2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: nomController,
                              decoration: _decorationChamp('').copyWith(
                                labelText: null,
                                hintText: 'ex: Mathématiques, Français, SVT...',
                              ),
                              style: GoogleFonts.sora(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: SSMPalette.texte1,
                              ),
                              onChanged: (_) => setStateDialog(() {}),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                ..._suggestionsMatieres.map(
                                  (label) => GestureDetector(
                                    onTap: () => setStateDialog(
                                      () => nomController.text = label,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: SSMPalette.indigoClair,
                                        borderRadius: BorderRadius.circular(
                                          SSMRayons.pilule,
                                        ),
                                      ),
                                      child: Text(
                                        label,
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: SSMPalette.indigo,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => setStateDialog(
                                    () => nomController.clear(),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: SSMPalette.texte3.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(SSMRayons.pilule),
                                    ),
                                    child: Text(
                                      '+ Autre',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: SSMPalette.texte2,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Code (optionnel)',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: SSMPalette.texte2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: codeController,
                              textCapitalization: TextCapitalization.words,
                              decoration: _decorationChamp('').copyWith(
                                labelText: null,
                                hintText: 'ex: MATH, FR, SVT',
                              ),
                              style: GoogleFonts.jetBrainsMono(fontSize: 14),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Couleur',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: SSMPalette.texte2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: _couleursSuggerees.map((c) {
                                final selectionnee =
                                    c.toARGB32() ==
                                    couleurSelectionnee.toARGB32();
                                return GestureDetector(
                                  onTap: () => setStateDialog(
                                    () => couleurSelectionnee = c,
                                  ),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: c,
                                      shape: BoxShape.circle,
                                      border: selectionnee
                                          ? Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            )
                                          : null,
                                      boxShadow: selectionnee
                                          ? [
                                              BoxShadow(
                                                color: c.withValues(alpha: 0.6),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Coefficient *',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: SSMPalette.texte2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: coefController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: _decorationChamp('').copyWith(
                                labelText: null,
                                hintText: 'ex: 3, 4.5, 7',
                              ),
                              onChanged: (_) => setStateDialog(() {}),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Enseignant responsable',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: SSMPalette.texte2,
                              ),
                            ),
                            Text(
                              "(optionnel — peut être défini plus tard)",
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: SSMPalette.texte3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (enseignantSelectionne == null)
                              Autocomplete<Map<String, dynamic>>(
                                optionsBuilder: (textEditingValue) {
                                  if (textEditingValue.text.isEmpty) {
                                    return const Iterable<
                                      Map<String, dynamic>
                                    >.empty();
                                  }
                                  final recherche = textEditingValue.text
                                      .toLowerCase();
                                  return _tousEnseignants
                                      .cast<Map<String, dynamic>>()
                                      .where((e) {
                                        final nomComplet =
                                            '${e['name']} ${e['prenom'] ?? ''}'
                                                .toLowerCase();
                                        return nomComplet.contains(recherche);
                                      });
                                },
                                displayStringForOption: (e) =>
                                    '${e['name']} ${e['prenom'] ?? ''}'.trim(),
                                fieldViewBuilder:
                                    (context, controller, focusNode, onSubmit) {
                                      return TextField(
                                        controller: controller,
                                        focusNode: focusNode,
                                        decoration: _decorationChamp('').copyWith(
                                          labelText: null,
                                          hintText: 'Rechercher un enseignant...',
                                          prefixIcon: const Icon(
                                            Icons.search,
                                            color: SSMPalette.indigo,
                                          ),
                                        ),
                                        style: GoogleFonts.inter(fontSize: 14, color: SSMPalette.texte1),
                                      );
                                    },
                                optionsViewBuilder: (context, onSelected, options) {
                                  final liste = options.toList();
                                  return Align(
                                    alignment: Alignment.topLeft,
                                    child: Material(
                                      elevation: 8,
                                      borderRadius: BorderRadius.circular(12),
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 380,
                                          maxHeight: 200,
                                        ),
                                        child: ListView.builder(
                                          padding: EdgeInsets.zero,
                                          itemCount: liste.length,
                                          itemBuilder: (context, index) {
                                            final e = liste[index];
                                            final photoUrl =
                                                e['photo_url'] as String?;
                                            final nomAffiche =
                                                e['name'] as String;
                                            return ListTile(
                                              leading: SSMAvatar(nom: nomAffiche, photoUrl: photoUrl, couleur: SSMPalette.teal, rayon: 18),
                                              title: Text(
                                                '${e['name']} ${e['prenom'] ?? ''}',
                                                style: GoogleFonts.sora(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                  color: SSMPalette.texte1,
                                                ),
                                              ),
                                              subtitle: Text(
                                                (e['fonction'] as String?) ??
                                                    (e['role'] as String?) ??
                                                    '',
                                                style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  color: SSMPalette.texte2,
                                                ),
                                              ),
                                              onTap: () => onSelected(e),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                onSelected: (e) => setStateDialog(() {
                                  enseignantSelectionne = e;
                                }),
                              )
                            else
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: SSMPalette.tealClair,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    SSMAvatar(
                                      nom: enseignantSelectionne!['name'] as String,
                                      photoUrl: enseignantSelectionne!['photo_url'] as String?,
                                      couleur: SSMPalette.teal,
                                      rayon: 18,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${enseignantSelectionne!['name']} ${enseignantSelectionne!['prenom'] ?? ''}',
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: SSMPalette.texte1,
                                            ),
                                          ),
                                          Text(
                                            (enseignantSelectionne!['fonction']
                                                    as String?) ??
                                                (enseignantSelectionne!['role']
                                                    as String?) ??
                                                '',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: SSMPalette.texte2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.close,
                                        size: 18,
                                        color: SSMPalette.texte2,
                                      ),
                                      onPressed: () => setStateDialog(() {
                                        enseignantSelectionne = null;
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 20),
                            if (nom.isNotEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: SSMPalette.indigoClair,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: couleurSelectionnee,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            nom,
                                            style: GoogleFonts.sora(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: SSMPalette.texte1,
                                            ),
                                          ),
                                          Text(
                                            'Coefficient ${coef?.toStringAsFixed(1) ?? '—'} · ${enseignantSelectionne != null ? enseignantSelectionne!['name'] : 'Non affecté'}',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: SSMPalette.texte2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
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
                            onPressed: () async {
                              if (nom.length < 2) {
                                _afficherErreur(
                                  'Le nom de la matière doit contenir au moins 2 caractères',
                                );
                                return;
                              }
                              if (coef == null || coef < 0.5 || coef > 10) {
                                _afficherErreur(
                                  'Le coefficient doit être compris entre 0.5 et 10',
                                );
                                return;
                              }
                              final couleurHex =
                                  '#${couleurSelectionnee.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
                              try {
                                await ClasseMatiereService.ajouter(
                                  classeId: widget.classeId,
                                  matiereNom: nom,
                                  matiereCode:
                                      codeController.text.trim().isEmpty
                                      ? null
                                      : codeController.text.trim(),
                                  matiereCouleur: couleurHex,
                                  coefficient: coef,
                                  enseignantId:
                                      enseignantSelectionne?['id'] as int?,
                                );
                                if (context.mounted) Navigator.pop(context);
                                _afficherSucces('Matière ajoutée à la classe');
                                _chargerTout();
                              } catch (e) {
                                _afficherErreur(
                                  e.toString().replaceAll('Exception: ', ''),
                                );
                              }
                            },
                            child: const Text('Ajouter à la classe'),
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

    nomController.dispose();
    codeController.dispose();
    coefController.dispose();
  }

  // ══════════════════════════════════════════════════════
  // TAB 5 — EMPLOI DU TEMPS
  // ══════════════════════════════════════════════════════

  dynamic _creneauPourCellule(String jour, String heureDebut) {
    final liste = (_emploiDuTemps[jour] as List?) ?? [];
    try {
      return liste.firstWhere(
        (c) => (c['heure_debut'] as String).substring(0, 5) == heureDebut,
      );
    } catch (_) {
      return null;
    }
  }

  Widget _tabEmploiDuTemps() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: SSMPalette.indigoClair,
            borderRadius: BorderRadius.circular(SSMRayons.grand),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 18, color: SSMPalette.indigo),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Utilisez le module Emploi du Temps pour créer, modifier et exporter la grille de cette classe.',
                  style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte1),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: SSMPalette.blanc,
            borderRadius: BorderRadius.circular(SSMRayons.grand),
            border: Border.all(color: SSMPalette.bordure),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 60 + (5 * 120),
              child: Column(
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 60),
                      ..._jours.map(
                        (j) => Expanded(
                          child: Center(
                            child: Text(
                              j['label']!,
                              style: GoogleFonts.sora(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: SSMPalette.texte1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ..._grilleHoraire.map((row) {
                    final debut = row['debut'] as String;
                    final fin = row['fin'] as String;
                    final recreation = row['recreation'] as bool;

                    if (recreation) {
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: SSMPalette.ambreClair,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            '🔶 RÉCRÉATION',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: SSMPalette.ambre,
                            ),
                          ),
                        ),
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 60,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: Text(
                              '$debut\n$fin',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: SSMPalette.texte3,
                              ),
                            ),
                          ),
                        ),
                        ..._jours.map((j) {
                          final c = _creneauPourCellule(j['cle']!, debut);
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Utilisez le module Emploi du Temps pour modifier cette grille.'),
                                ),
                              ),
                              child: Container(
                                height: 60,
                                margin: const EdgeInsets.all(2),
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: c != null
                                      ? _couleurMatiere(
                                          c['matiere_id'] as int,
                                        )
                                      : SSMPalette.fond,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: c != null
                                    ? Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c['matiere_nom'] as String,
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: SSMPalette.texte1,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            c['enseignant_nom'] as String,
                                            style: GoogleFonts.inter(
                                              fontSize: 9,
                                              color: SSMPalette.texte1,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      )
                                    : Center(
                                        child: Icon(
                                          Icons.add,
                                          size: 16,
                                          color: SSMPalette.texte3,
                                        ),
                                      ),
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  // TAB 6 — STATISTIQUES
  // ══════════════════════════════════════════════════════

  Widget _tabStatistiques() {
    final stats = _statistiques ?? {};
    final garcons = (stats['garcons'] as num?)?.toInt() ?? 0;
    final filles = (stats['filles'] as num?)?.toInt() ?? 0;
    final moyenne = (stats['moyenne_generale'] as num?)?.toDouble();
    final tauxReussite = (stats['taux_reussite'] as num?)?.toDouble() ?? 0;
    final totalAbsences = (stats['total_absences'] as num?)?.toInt() ?? 0;
    final totalPaiements = (stats['total_paiements'] as num?)?.toDouble() ?? 0;
    final elevesEnDifficulte = (stats['eleves_en_difficulte'] as List?) ?? [];

    return RefreshIndicator(
      onRefresh: _chargerTout,
      color: SSMPalette.indigo,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: 168,
            ),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 4,
            itemBuilder: (context, i) => [
              SSMStatCard(
                icone: Icons.people_outline,
                couleur: SSMPalette.indigo,
                valeur: '${garcons + filles}',
                label: 'Effectif',
                sousTexte: 'G: $garcons · F: $filles',
              ),
              _carteStatGraphMoyenne(moyenne),
              _carteStatProgression(
                'Taux de réussite',
                tauxReussite / 100,
                '${tauxReussite.toStringAsFixed(0)}%',
                SSMPalette.teal,
              ),
              SSMStatCard(
                icone: Icons.event_busy_outlined,
                couleur: SSMPalette.ambre,
                valeur: '$totalAbsences',
                label: 'Absences',
                sousTexte: 'total enregistrées',
              ),
            ][i],
          ),
          const SizedBox(height: 16),
          _carteGlass(
            child: Row(
              children: [
                const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: SSMPalette.teal,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Total encaissé',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: SSMPalette.texte2,
                    ),
                  ),
                ),
                Text(
                  '${totalPaiements.toStringAsFixed(0)} FCFA',
                  style: GoogleFonts.sora(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: SSMPalette.teal,
                  ),
                ),
              ],
            ),
          ),
          SSMSectionTitre(titre: 'Élèves en difficulté (moyenne < 8)'),
          if (elevesEnDifficulte.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SSMPalette.tealClair,
                borderRadius: BorderRadius.circular(SSMRayons.grand),
              ),
              child: Text(
                'Aucun élève en difficulté 🎉',
                style: GoogleFonts.inter(color: SSMPalette.teal),
              ),
            )
          else
            ...elevesEnDifficulte.map(
              (e) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: SSMPalette.blanc,
                  borderRadius: BorderRadius.circular(SSMRayons.grand),
                  border: Border.all(color: SSMPalette.bordure),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${e['nom']} ${e['prenom']}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: SSMPalette.texte1,
                        ),
                      ),
                    ),
                    SSMPill.couleur(
                      label: '${e['moyenne']}/20',
                      couleur: SSMPalette.rouge,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _voirLeClassement,
              icon: const Icon(Icons.emoji_events_outlined),
              label: const Text('Voir le classement'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _voirLeClassement() async {
    if (_anneeId == null) return;
    try {
      final periodes = await AnneeService.listerPeriodes(_anneeId!);
      final periode = periodes.cast<Map<String, dynamic>>().firstWhere(
        (p) => p['statut'] == 'ouverte',
        orElse: () => periodes.isNotEmpty
            ? periodes.first as Map<String, dynamic>
            : <String, dynamic>{},
      );
      if (periode.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucune période disponible pour cette classe')),
        );
        return;
      }
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        '/directeur/rangs',
        arguments: {
          'classeId': widget.classeId,
          'classeNom': _classe?['nom'] as String? ?? '',
          'periodeId': periode['id'] as int,
          'periodeNom': periode['nom'] as String? ?? '',
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  Widget _carteStatGraphMoyenne(double? moyenne) {
    return _carteGlass(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Moyenne générale',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: SSMPalette.texte2,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: moyenne == null
                ? Center(
                    child: Text(
                      '—',
                      style: GoogleFonts.sora(
                        fontSize: 18,
                        color: SSMPalette.texte3,
                      ),
                    ),
                  )
                : Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 0,
                              centerSpaceRadius: 20,
                              sections: [
                                PieChartSectionData(
                                  value: moyenne,
                                  color: SSMPalette.indigo,
                                  showTitle: false,
                                  radius: 11,
                                ),
                                PieChartSectionData(
                                  value: (20 - moyenne).clamp(0, 20),
                                  color: SSMPalette.bordure,
                                  showTitle: false,
                                  radius: 11,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Text(
                          moyenne.toStringAsFixed(1),
                          style: GoogleFonts.sora(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: SSMPalette.texte1,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _carteStatProgression(
    String label,
    double valeur,
    String texte,
    Color couleur,
  ) {
    return _carteGlass(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: SSMPalette.texte2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            texte,
            style: GoogleFonts.sora(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: couleur,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: valeur.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: SSMPalette.bordure,
              color: couleur,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget tabBar;
  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => tabBar;

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}
