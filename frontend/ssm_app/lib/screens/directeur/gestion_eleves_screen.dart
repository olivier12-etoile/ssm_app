import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';
import '../../services/eleve_service.dart';
import '../../services/classe_service.dart';
import '../../services/annee_service.dart';
import '../../widgets/ssm_widgets.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _teal = Color(0xFF0D9488);
const Color _ambre = Color(0xFFD97706);
const Color _vert = Color(0xFF16A34A);
const Color _vertFonce = Color(0xFF15803D);
const Color _rouge = Color(0xFFDC2626);
const Color _rougeFonce = Color(0xFF991B1B);
const Color _orange = Color(0xFFEA580C);
const Color _gris = Color(0xFF94A3B8);

const List<Map<String, String>> _statutsEleve = [
  {'valeur': 'actif', 'label': 'Actif'},
  {'valeur': 'suspendu', 'label': 'Suspendu'},
  {'valeur': 'exclu', 'label': 'Exclu'},
  {'valeur': 'transfere', 'label': 'Transféré'},
  {'valeur': 'diplome', 'label': 'Diplômé'},
  {'valeur': 'abandon', 'label': 'Abandon'},
];

Color _couleurStatutEleve(String? statut) {
  switch (statut) {
    case 'actif':
      return _indigo;
    case 'suspendu':
      return _orange;
    case 'exclu':
      return _rouge;
    case 'diplome':
      return _vert;
    case 'transfere':
      return _teal;
    case 'abandon':
      return _gris;
    default:
      return _gris;
  }
}

class GestionElevesScreen extends StatefulWidget {
  const GestionElevesScreen({super.key});

  @override
  State<GestionElevesScreen> createState() => _GestionElevesScreenState();
}

class _GestionElevesScreenState extends State<GestionElevesScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  bool _chargementDashboard = true;
  Map<String, dynamic> _dashboard = {};

  List<dynamic> _classes = [];
  List<dynamic> _annees = [];
  Map<String, dynamic>? _anneeActive;

  bool _chargementListe = true;
  Map<String, dynamic> _elevesPage = {};
  int _page = 1;

  int? _filtreClasseId;
  String? _filtreSexe;
  String? _filtreStatut;
  bool? _filtreEnRegle;
  final _rechercheController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() => setState(() {}));
    _chargerTout();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _rechercheController.dispose();
    super.dispose();
  }

  Future<void> _chargerTout() async {
    setState(() {
      _chargementDashboard = true;
      _chargementListe = true;
    });
    try {
      final resultats = await Future.wait([
        EleveService.tableauDeBord(),
        ClasseService.listerClasses(),
        AnneeService.listerAnnees(),
      ]);
      final annees = resultats[1] as List<dynamic>;
      setState(() {
        _dashboard = resultats[0] as Map<String, dynamic>;
        _classes = resultats[1] as List<dynamic>;
        _annees = annees;
        _anneeActive = annees
            .cast<Map<String, dynamic>>()
            .firstWhere((a) => a['statut'] == 'active', orElse: () => {});
        _chargementDashboard = false;
      });
    } catch (e) {
      setState(() => _chargementDashboard = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
    await _chargerListe();
  }

  Future<void> _chargerListe() async {
    setState(() => _chargementListe = true);
    try {
      final data = await EleveService.lister(
        classeId: _filtreClasseId,
        sexe: _filtreSexe,
        statut: _filtreStatut,
        enRegle: _filtreEnRegle,
        recherche: _rechercheController.text.trim().isEmpty
            ? null
            : _rechercheController.text.trim(),
        page: _page,
      );
      setState(() {
        _elevesPage = data;
        _chargementListe = false;
      });
    } catch (e) {
      setState(() => _chargementListe = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _afficherErreur(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: _rouge));
  }

  Widget _blob({required double size, required Color couleur}) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: couleur),
        ),
      ),
    );
  }

  void _ouvrirListeIntelligente(String type, String titre) {
    Navigator.pushNamed(context, '/eleves/liste-intelligente', arguments: {'type': type, 'titre': titre});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
        title: Text('Élèves', style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: '📊 Tableau de bord'),
            Tab(text: '👥 Liste des élèves'),
          ],
        ),
      ),
      body: Stack(
        children: [
          Positioned(top: -80, right: -60, child: _blob(size: 300, couleur: _indigo.withValues(alpha: 0.08))),
          Positioned(bottom: -60, left: -60, child: _blob(size: 200, couleur: _teal.withValues(alpha: 0.10))),
          TabBarView(
            controller: _tabController,
            children: [_ongletTableauDeBord(), _ongletListe()],
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton.extended(
              backgroundColor: _indigo,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              onPressed: _dialogCreerEleve,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Nouvel élève'),
            )
          : null,
    );
  }

  // ══════════════════════════════════════════════════════
  // ONGLET 1 — TABLEAU DE BORD
  // ══════════════════════════════════════════════════════

  Widget _ongletTableauDeBord() {
    if (_chargementDashboard) {
      return const Center(child: CircularProgressIndicator(color: _indigo));
    }

    final total = _dashboard['total'] ?? 0;
    final garcons = _dashboard['garcons'] ?? 0;
    final filles = _dashboard['filles'] ?? 0;
    final parStatut = (_dashboard['par_statut'] as Map?) ?? {};

    return RefreshIndicator(
      onRefresh: _chargerTout,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          _hero(total, garcons, filles),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SSMSectionTitre(titre: 'Statistiques — Cliquez pour voir les listes'),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.3,
                  children: [
                    SSMStatInteractive(
                      label: 'En règle',
                      valeur: '${_dashboard['en_regle'] ?? 0}',
                      icone: Icons.check_circle,
                      couleur: _vert,
                      onTap: () => _ouvrirListeIntelligente('en_regle', 'En règle'),
                    ),
                    SSMStatInteractive(
                      label: 'En retard',
                      valeur: '${_dashboard['en_retard_paiement'] ?? 0}',
                      icone: Icons.money_off,
                      couleur: _rouge,
                      onTap: () => _ouvrirListeIntelligente('en_retard_paiement', 'En retard de paiement'),
                    ),
                    SSMStatInteractive(
                      label: "Absents aujourd'hui",
                      valeur: '${_dashboard['absents_aujourd_hui'] ?? 0}',
                      icone: Icons.event_busy,
                      couleur: _orange,
                      onTap: () => _ouvrirListeIntelligente('absents_aujourd_hui', "Absents aujourd'hui"),
                    ),
                    SSMStatInteractive(
                      label: 'Suspendus',
                      valeur: '${parStatut['suspendu'] ?? 0}',
                      icone: Icons.block,
                      couleur: _rougeFonce,
                      onTap: () => _ouvrirListeIntelligente('suspendus', 'Suspendus'),
                    ),
                    SSMStatInteractive(
                      label: 'Redoublants',
                      valeur: '${_dashboard['redoublants'] ?? 0}',
                      icone: Icons.replay,
                      couleur: _ambre,
                      onTap: () => _ouvrirListeIntelligente('redoublants', 'Redoublants'),
                    ),
                    SSMStatInteractive(
                      label: 'Diplômés',
                      valeur: '${parStatut['diplome'] ?? 0}',
                      icone: Icons.school,
                      couleur: _indigo,
                      onTap: () => _ouvrirListeIntelligente('diplomes', 'Diplômés'),
                    ),
                    SSMStatInteractive(
                      label: 'Transférés',
                      valeur: '${parStatut['transfere'] ?? 0}',
                      icone: Icons.transfer_within_a_station,
                      couleur: _teal,
                      onTap: () => _ouvrirListeIntelligente('transferes', 'Transférés'),
                    ),
                    SSMStatInteractive(
                      label: 'Abandons',
                      valeur: '${parStatut['abandon'] ?? 0}',
                      icone: Icons.exit_to_app,
                      couleur: _gris,
                      onTap: () => _ouvrirListeIntelligente('abandons', 'Abandons'),
                    ),
                    SSMStatInteractive(
                      label: 'Moyenne > 15',
                      valeur: '${_dashboard['moyenne_sup_15'] ?? 0}',
                      icone: Icons.star,
                      couleur: _vertFonce,
                      onTap: () => _ouvrirListeIntelligente('moyenne_sup_15', 'Moyenne > 15'),
                    ),
                    SSMStatInteractive(
                      label: 'En difficulté',
                      valeur: '${_dashboard['en_difficulte'] ?? 0}',
                      icone: Icons.trending_down,
                      couleur: _rouge,
                      onTap: () => _ouvrirListeIntelligente('en_difficulte', 'En difficulté'),
                    ),
                    SSMStatInteractive(
                      label: 'Sans photo',
                      valeur: '${_dashboard['sans_photo'] ?? 0}',
                      icone: Icons.no_photography,
                      couleur: _gris,
                      onTap: () => _ouvrirListeIntelligente('sans_photo', 'Sans photo'),
                    ),
                    SSMStatInteractive(
                      label: 'Sans téléphone parent',
                      valeur: '${_dashboard['sans_telephone_parent'] ?? 0}',
                      icone: Icons.phone_disabled,
                      couleur: _orange,
                      onTap: () => _ouvrirListeIntelligente('sans_telephone', 'Sans téléphone parent'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _rouge,
                          side: const BorderSide(color: _rouge),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => _exporter(pdf: true),
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Exporter PDF'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _vert,
                          side: const BorderSide(color: _vert),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => _exporter(pdf: false),
                        icon: const Icon(Icons.table_chart),
                        label: const Text('Exporter Excel'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero(dynamic total, dynamic garcons, dynamic filles) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_indigo, _teal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Élèves', style: GoogleFonts.sora(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 4),
                Text('$total élèves inscrits', style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.7))),
                if (_anneeActive != null && _anneeActive!.isNotEmpty)
                  Text('Année ${_anneeActive!['libelle']}', style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
              ],
            ),
          ),
          Row(
            children: [
              _pastilleSexe('$garcons', 'Garçons'),
              const SizedBox(width: 8),
              _pastilleSexe('$filles', 'Filles'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pastilleSexe(String valeur, String label) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(valeur, style: GoogleFonts.sora(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.white.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  Future<void> _exporter({required bool pdf}) async {
    try {
      final chemin = pdf
          ? await EleveService.exporterPdf()
          : await EleveService.exporterExcel();
      await OpenFile.open(chemin);
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ══════════════════════════════════════════════════════
  // ONGLET 2 — LISTE DES ÉLÈVES
  // ══════════════════════════════════════════════════════

  Widget _ongletListe() {
    final data = (_elevesPage['data'] as List?) ?? [];
    final currentPage = _elevesPage['current_page'] as int? ?? 1;
    final lastPage = _elevesPage['last_page'] as int? ?? 1;

    final groupes = <String, List<dynamic>>{};
    for (final e in data) {
      final classe = e['classe_actuelle'] as Map<String, dynamic>?;
      final nom = classe?['nom'] as String? ?? 'Non affecté';
      groupes.putIfAbsent(nom, () => []).add(e);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8),
              ],
            ),
            child: TextField(
              controller: _rechercheController,
              onSubmitted: (_) {
                _page = 1;
                _chargerListe();
              },
              decoration: InputDecoration(
                hintText: 'Rechercher (nom, matricule, téléphone parent)...',
                hintStyle: GoogleFonts.inter(fontSize: 13),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  onPressed: () {
                    _page = 1;
                    _chargerListe();
                  },
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _dropdownFiltre<int>(
                label: 'Classe',
                valeur: _filtreClasseId,
                items: _classes
                    .cast<Map<String, dynamic>>()
                    .map((c) => DropdownMenuItem(value: c['id'] as int, child: Text(c['nom'] as String)))
                    .toList(),
                onChanged: (v) {
                  setState(() => _filtreClasseId = v);
                  _page = 1;
                  _chargerListe();
                },
              ),
              const SizedBox(width: 8),
              _dropdownFiltre<String>(
                label: 'Sexe',
                valeur: _filtreSexe,
                items: const [
                  DropdownMenuItem(value: 'M', child: Text('Masculin')),
                  DropdownMenuItem(value: 'F', child: Text('Féminin')),
                ],
                onChanged: (v) {
                  setState(() => _filtreSexe = v);
                  _page = 1;
                  _chargerListe();
                },
              ),
              const SizedBox(width: 8),
              _dropdownFiltre<String>(
                label: 'Statut',
                valeur: _filtreStatut,
                items: _statutsEleve
                    .map((s) => DropdownMenuItem(value: s['valeur'], child: Text(s['label']!)))
                    .toList(),
                onChanged: (v) {
                  setState(() => _filtreStatut = v);
                  _page = 1;
                  _chargerListe();
                },
              ),
              const SizedBox(width: 8),
              _dropdownFiltre<bool>(
                label: 'Paiement',
                valeur: _filtreEnRegle,
                items: const [
                  DropdownMenuItem(value: true, child: Text('En règle')),
                  DropdownMenuItem(value: false, child: Text('En retard')),
                ],
                onChanged: (v) {
                  setState(() => _filtreEnRegle = v);
                  _page = 1;
                  _chargerListe();
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: _indigo, foregroundColor: Colors.white),
                  onPressed: _dialogCreerEleve,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter un élève'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                style: IconButton.styleFrom(backgroundColor: _rouge.withValues(alpha: 0.1), foregroundColor: _rouge),
                onPressed: () => _exporter(pdf: true),
                icon: const Icon(Icons.picture_as_pdf),
              ),
              const SizedBox(width: 4),
              IconButton(
                style: IconButton.styleFrom(backgroundColor: _vert.withValues(alpha: 0.1), foregroundColor: _vert),
                onPressed: () => _exporter(pdf: false),
                icon: const Icon(Icons.table_chart),
              ),
            ],
          ),
        ),
        Expanded(
          child: _chargementListe
              ? const Center(child: CircularProgressIndicator(color: _indigo))
              : groupes.isEmpty
              ? Center(child: Text('Aucun élève trouvé', style: GoogleFonts.inter(color: _gris)))
              : RefreshIndicator(
                  onRefresh: _chargerListe,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: groupes.entries.map((entry) => _sectionClasse(entry.key, entry.value)).toList(),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: currentPage > 1 ? () { _page = currentPage - 1; _chargerListe(); } : null,
                child: const Text('< Précédent'),
              ),
              const SizedBox(width: 8),
              Text('Page $currentPage sur $lastPage', style: GoogleFonts.inter(fontSize: 13, color: _gris)),
              const SizedBox(width: 8),
              TextButton(
                onPressed: currentPage < lastPage ? () { _page = currentPage + 1; _chargerListe(); } : null,
                child: const Text('Suivant >'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dropdownFiltre<T>({
    required String label,
    required T? valeur,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: valeur,
          hint: Text(label, style: GoogleFonts.inter(fontSize: 12)),
          items: [
            DropdownMenuItem<T>(value: null, child: Text('Tous · $label')),
            ...items,
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _sectionClasse(String classeNom, List eleves) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SSMSectionTitre(
            titre: '$classeNom (${eleves.length} élèves)',
            action: 'Voir classe →',
            onAction: () {
              final classeId = (eleves.first as Map)['classe_actuelle']?['id'];
              if (classeId != null) {
                Navigator.pushNamed(context, '/directeur/classe/fiche', arguments: {'classeId': classeId as int});
              }
            },
          ),
          ...eleves.map((e) => _carteEleve(e as Map<String, dynamic>)),
        ],
      ),
    );
  }

  Widget _carteEleve(Map<String, dynamic> eleve) {
    final statut = eleve['statut'] as String? ?? 'actif';
    final couleur = _couleurStatutEleve(statut);
    final dette = (eleve['dette'] as num?)?.toDouble() ?? 0;
    final sexe = eleve['sexe'] as String? ?? 'M';

    return Material(
      color: Colors.white.withValues(alpha: 0.70),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.pushNamed(context, '/eleve/fiche', arguments: {'eleveId': eleve['id'] as int}),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: couleur, width: 4)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: sexe == 'F' ? _teal : _indigo,
                backgroundImage: eleve['photo_url'] != null ? NetworkImage(eleve['photo_url'] as String) : null,
                child: eleve['photo_url'] == null
                    ? Text((eleve['nom'] as String? ?? '?').substring(0, 1),
                        style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: Colors.white))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${eleve['nom']} ${eleve['prenom']}', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600)),
                    Text('Matricule : ${eleve['matricule']}', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: _gris)),
                    if (eleve['numero_appel'] != null)
                      Text('N° appel : ${eleve['numero_appel']}', style: GoogleFonts.inter(fontSize: 11, color: _gris)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        SSMBadge(label: statut, couleur: couleur),
                        if (dette > 0) const SSMBadge(label: '💰 Dette', couleur: _rouge),
                      ],
                    ),
                  ],
                ),
              ),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Icon(Icons.chevron_right, color: _gris),
                  Text('Voir →', style: TextStyle(fontSize: 11, color: _indigo)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // DIALOG — CRÉER UN ÉLÈVE (stepper 3 étapes)
  // ══════════════════════════════════════════════════════

  void _dialogCreerEleve() {
    int etape = 0;
    File? photo;
    final nomController = TextEditingController();
    final prenomController = TextEditingController();
    String sexe = 'M';
    DateTime? dateNaissance;
    final lieuNaissanceController = TextEditingController();
    final nationaliteController = TextEditingController(text: 'Togolaise');

    int? classeId;
    int? anneeId = _anneeActive != null && _anneeActive!.isNotEmpty ? _anneeActive!['id'] as int : null;
    final numeroAppelController = TextEditingController();
    DateTime dateInscription = DateTime.now();
    String statut = 'actif';

    final parents = <Map<String, dynamic>>[
      {
        'lien_parente': 'pere',
        'nom': TextEditingController(),
        'prenom': TextEditingController(),
        'telephone_principal': TextEditingController(),
        'telephone_secondaire': TextEditingController(),
        'profession': TextEditingController(),
      },
    ];

    bool enCours = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          Future<void> choisirPhoto() async {
            final picker = ImagePicker();
            final image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 80);
            if (image != null) {
              setStateDialog(() => photo = File(image.path));
            }
          }

          Widget etape1() {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: GestureDetector(
                    onTap: choisirPhoto,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: _gris.withValues(alpha: 0.2),
                          backgroundImage: photo != null ? FileImage(photo!) : null,
                          child: photo == null ? const Icon(Icons.person, size: 40, color: _gris) : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(color: _indigo, shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Ajouter une photo', style: GoogleFonts.inter(fontSize: 12, color: _gris)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: TextField(controller: nomController, decoration: const InputDecoration(labelText: 'Nom *', border: OutlineInputBorder()))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: prenomController, decoration: const InputDecoration(labelText: 'Prénom *', border: OutlineInputBorder()))),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: sexe,
                        decoration: const InputDecoration(labelText: 'Sexe *', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'M', child: Text('Masculin')),
                          DropdownMenuItem(value: 'F', child: Text('Féminin')),
                        ],
                        onChanged: (v) => setStateDialog(() => sexe = v!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final d = await showDatePicker(context: context, initialDate: DateTime(2015), firstDate: DateTime(1995), lastDate: DateTime.now());
                          if (d != null) setStateDialog(() => dateNaissance = d);
                        },
                        child: Text(dateNaissance != null ? '${dateNaissance!.day}/${dateNaissance!.month}/${dateNaissance!.year}' : 'Naissance *'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(controller: lieuNaissanceController, decoration: const InputDecoration(labelText: 'Lieu de naissance', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: nationaliteController, decoration: const InputDecoration(labelText: 'Nationalité', border: OutlineInputBorder())),
              ],
            );
          }

          Widget etape2() {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: classeId,
                  decoration: const InputDecoration(labelText: 'Classe *', border: OutlineInputBorder()),
                  items: _classes.cast<Map<String, dynamic>>().map((c) => DropdownMenuItem(value: c['id'] as int, child: Text(c['nom'] as String))).toList(),
                  onChanged: (v) => setStateDialog(() => classeId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: anneeId,
                  decoration: const InputDecoration(labelText: 'Année académique *', border: OutlineInputBorder()),
                  items: _annees.cast<Map<String, dynamic>>().map((a) => DropdownMenuItem(value: a['id'] as int, child: Text(a['libelle'] as String))).toList(),
                  onChanged: (v) => setStateDialog(() => anneeId = v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: numeroAppelController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "N° d'appel", border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final d = await showDatePicker(context: context, initialDate: dateInscription, firstDate: DateTime(2020), lastDate: DateTime(2100));
                          if (d != null) setStateDialog(() => dateInscription = d);
                        },
                        child: Text('${dateInscription.day}/${dateInscription.month}/${dateInscription.year}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: statut,
                  decoration: const InputDecoration(labelText: 'Statut', border: OutlineInputBorder()),
                  items: _statutsEleve.map((s) => DropdownMenuItem(value: s['valeur'], child: Text(s['label']!))).toList(),
                  onChanged: (v) => setStateDialog(() => statut = v!),
                ),
              ],
            );
          }

          Widget carteParent(int index) {
            final p = parents[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _gris.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: p['lien_parente'] as String,
                    decoration: const InputDecoration(labelText: 'Lien', border: OutlineInputBorder(), isDense: true),
                    items: const [
                      DropdownMenuItem(value: 'pere', child: Text('Père')),
                      DropdownMenuItem(value: 'mere', child: Text('Mère')),
                      DropdownMenuItem(value: 'tuteur', child: Text('Tuteur')),
                      DropdownMenuItem(value: 'autre', child: Text('Autre')),
                    ],
                    onChanged: (v) => setStateDialog(() => p['lien_parente'] = v),
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: p['nom'] as TextEditingController, decoration: const InputDecoration(labelText: 'Nom *', border: OutlineInputBorder(), isDense: true)),
                  const SizedBox(height: 8),
                  TextField(controller: p['prenom'] as TextEditingController, decoration: const InputDecoration(labelText: 'Prénom', border: OutlineInputBorder(), isDense: true)),
                  const SizedBox(height: 8),
                  TextField(controller: p['telephone_principal'] as TextEditingController, decoration: const InputDecoration(labelText: 'Téléphone principal *', border: OutlineInputBorder(), isDense: true)),
                  const SizedBox(height: 8),
                  TextField(controller: p['telephone_secondaire'] as TextEditingController, decoration: const InputDecoration(labelText: 'Téléphone secondaire', border: OutlineInputBorder(), isDense: true)),
                  const SizedBox(height: 8),
                  TextField(controller: p['profession'] as TextEditingController, decoration: const InputDecoration(labelText: 'Profession', border: OutlineInputBorder(), isDense: true)),
                ],
              ),
            );
          }

          Widget etape3() {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SSMSectionTitre(titre: 'Parent / Tuteur'),
                Text('Ces informations serviront aux notifications WhatsApp', style: GoogleFonts.inter(fontSize: 12, color: _gris)),
                const SizedBox(height: 12),
                ...List.generate(parents.length, carteParent),
                if (parents.length < 2)
                  OutlinedButton.icon(
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
            );
          }

          Future<void> inscrire() async {
            if (nomController.text.trim().isEmpty || prenomController.text.trim().isEmpty || dateNaissance == null || classeId == null || anneeId == null) {
              _afficherErreur('Veuillez compléter les champs obligatoires');
              return;
            }
            setStateDialog(() => enCours = true);
            try {
              final resultat = await EleveService.creer(
                nom: nomController.text.trim(),
                prenom: prenomController.text.trim(),
                sexe: sexe,
                dateNaissance: '${dateNaissance!.year.toString().padLeft(4, '0')}-${dateNaissance!.month.toString().padLeft(2, '0')}-${dateNaissance!.day.toString().padLeft(2, '0')}',
                lieuNaissance: lieuNaissanceController.text.trim().isEmpty ? null : lieuNaissanceController.text.trim(),
                nationalite: nationaliteController.text.trim().isEmpty ? null : nationaliteController.text.trim(),
                classeId: classeId!,
                anneeAcademiqueId: anneeId!,
                numeroAppel: int.tryParse(numeroAppelController.text.trim()),
                dateInscription: '${dateInscription.year.toString().padLeft(4, '0')}-${dateInscription.month.toString().padLeft(2, '0')}-${dateInscription.day.toString().padLeft(2, '0')}',
                photo: photo,
              );

              final eleveId = resultat['eleve']['id'] as int;
              final matricule = resultat['eleve']['matricule'] as String;

              final parentsAEnvoyer = parents
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

              if (parentsAEnvoyer.isNotEmpty) {
                await EleveService.gererParents(eleveId, parentsAEnvoyer);
              }

              if (!context.mounted) return;
              Navigator.pop(context);
              _dialogSucces(eleveId, matricule, '${nomController.text.trim()} ${prenomController.text.trim()}', classeId!);
              _chargerTout();
            } catch (e) {
              setStateDialog(() => enCours = false);
              _afficherErreur(e.toString().replaceAll('Exception: ', ''));
            }
          }

          final contenu = [etape1(), etape2(), etape3()][etape];

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Inscrire un élève', style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    Flexible(child: SingleChildScrollView(child: contenu)),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        if (etape > 0)
                          Expanded(
                            child: TextButton(
                              onPressed: enCours ? null : () => setStateDialog(() => etape--),
                              child: const Text('← Retour'),
                            ),
                          )
                        else
                          Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler'))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: _indigo, foregroundColor: Colors.white),
                            onPressed: enCours
                                ? null
                                : etape < 2
                                    ? () => setStateDialog(() => etape++)
                                    : inscrire,
                            child: enCours
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Text(etape < 2 ? 'Suivant →' : "Inscrire l'élève"),
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

  void _dialogSucces(int eleveId, String matricule, String nomComplet, int classeId) {
    final classe = _classes.cast<Map<String, dynamic>>().firstWhere((c) => c['id'] == classeId, orElse: () => {});

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: _vert, size: 64),
              const SizedBox(height: 12),
              Text('Élève inscrit avec succès !', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Matricule : $matricule', style: GoogleFonts.jetBrainsMono(fontSize: 20, fontWeight: FontWeight.w700, color: _indigo)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                child: Column(
                  children: [
                    Text(nomComplet, style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600)),
                    Text(classe['nom']?.toString() ?? '', style: GoogleFonts.inter(fontSize: 13, color: _gris)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _indigo, foregroundColor: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/eleve/fiche', arguments: {'eleveId': eleveId});
                  },
                  child: const Text('Voir la fiche'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _dialogCreerEleve();
                  },
                  child: const Text('Inscrire un autre'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
