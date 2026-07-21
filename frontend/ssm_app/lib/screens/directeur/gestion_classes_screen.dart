import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_file/open_file.dart';
import '../../services/classe_service.dart';
import '../../services/annee_service.dart';
import '../../services/utilisateur_service.dart';
import '../../widgets/ssm_widgets.dart';
import 'fiche_classe_screen.dart';

class GestionClassesScreen extends StatefulWidget {
  const GestionClassesScreen({super.key});

  @override
  State<GestionClassesScreen> createState() => _GestionClassesScreenState();
}

class _GestionClassesScreenState extends State<GestionClassesScreen> {
  static const List<String> _niveaux = [
    '6ème', '5ème', '4ème', '3ème', 'Seconde', 'Première', 'Terminale',
  ];
  static const Map<String, String> _labelsTri = {
    'nom':      'Nom',
    'niveau':   'Niveau',
    'effectif': 'Effectif',
  };

  List<dynamic> _classes = [];
  int _pageActuelle = 1;
  int _dernierePage = 1;
  int _totalClasses = 0;
  int _totalActives = 0;

  bool _chargementListe = true;
  String? _filtreStatut;
  String? _filtreNiveau;
  String _tri = 'nom';
  String _recherche = '';
  Timer? _debounceRecherche;

  List<dynamic> _enseignants = [];
  List<dynamic> _annees = [];

  @override
  void initState() {
    super.initState();
    _chargerEnTete();
    _chargerListe();
    _chargerReferences();
  }

  @override
  void dispose() {
    _debounceRecherche?.cancel();
    super.dispose();
  }

  Future<void> _chargerEnTete() async {
    try {
      final resultats = await Future.wait([
        ClasseService.lister(page: 1),
        ClasseService.lister(statut: 'active', page: 1),
      ]);
      setState(() {
        _totalClasses = resultats[0]['total'] as int? ?? 0;
        _totalActives = resultats[1]['total'] as int? ?? 0;
      });
    } catch (_) {
      // En-tête non bloquant si les compteurs échouent à charger.
    }
  }

  Future<void> _chargerReferences() async {
    try {
      final enseignants = <dynamic>[];
      var page = 1;
      while (true) {
        final resultat = await UtilisateurService.lister(role: 'enseignant', page: page);
        enseignants.addAll((resultat['data'] as List?) ?? []);
        final dernierePage = resultat['last_page'] as int? ?? 1;
        if (page >= dernierePage) break;
        page++;
      }
      final annees = await AnneeService.listerAnnees();
      setState(() {
        _enseignants = enseignants;
        _annees      = annees;
      });
    } catch (_) {
      // Listes de référence non bloquantes pour l'affichage de la grille.
    }
  }

  Future<void> _chargerListe({int page = 1}) async {
    setState(() => _chargementListe = true);
    try {
      final resultat = await ClasseService.lister(
        statut:    _filtreStatut,
        niveau:    _filtreNiveau,
        recherche: _recherche.isEmpty ? null : _recherche,
        tri:       _tri,
        page:      page,
      );
      setState(() {
        _classes         = resultat['data'] as List;
        _pageActuelle    = resultat['current_page'] as int;
        _dernierePage    = resultat['last_page'] as int;
        _chargementListe = false;
      });
    } catch (e) {
      setState(() => _chargementListe = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _rafraichirTout() async {
    await Future.wait([_chargerEnTete(), _chargerListe(page: _pageActuelle)]);
  }

  void _onRechercheChangee(String valeur) {
    _debounceRecherche?.cancel();
    _debounceRecherche = Timer(const Duration(milliseconds: 400), () {
      _recherche = valeur;
      _chargerListe();
    });
  }

  void _afficherErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFFDC2626)),
    );
  }

  void _afficherSucces(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFF16A34A)),
    );
  }

  Future<void> _exporterPdf(int classeId) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Génération du PDF...')));
      final chemin = await ClasseService.exporterPdf(classeId);
      await OpenFile.open(chemin);
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _exporterExcel(int classeId) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Génération du fichier Excel...')));
      final chemin = await ClasseService.exporterExcel(classeId);
      await OpenFile.open(chemin);
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _afficherDialogCreation,
        backgroundColor: const Color(0xFF1E3A8A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Nouvelle classe', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _enTete(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _rafraichirTout,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _barreOutils(),
                    const SizedBox(height: 12),
                    _chipsNiveaux(),
                    const SizedBox(height: 16),
                    if (_chargementListe)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_classes.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text('Aucune classe trouvée', style: GoogleFonts.inter(color: const Color(0xFF334155))),
                        ),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _classes.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.72,
                        ),
                        itemBuilder: (context, index) => _carteClasse(_classes[index] as Map<String, dynamic>),
                      ),
                    const SizedBox(height: 12),
                    if (!_chargementListe && _classes.isNotEmpty) _paginationBar(),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // EN-TÊTE
  // ══════════════════════════════════════════════════════

  Widget _enTete() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF0D9488)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Classes', style: GoogleFonts.sora(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 4),
              Text(
                '$_totalActives classes actives',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.7)),
              ),
            ],
          ),
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$_totalClasses',
              style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // BARRE OUTILS
  // ══════════════════════════════════════════════════════

  Widget _barreOutils() {
    return Row(
      children: [
        Expanded(flex: 2, child: _barreRecherche()),
        const SizedBox(width: 8),
        Expanded(child: _dropdownStatut()),
        const SizedBox(width: 8),
        Expanded(child: _dropdownTri()),
      ],
    );
  }

  Widget _barreRecherche() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(50),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 16, color: const Color(0xFF334155).withValues(alpha: 0.6)),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  onChanged: _onRechercheChangee,
                  decoration: InputDecoration(
                    hintText: 'Rechercher une classe...',
                    border: InputBorder.none,
                    isDense: true,
                    hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF334155).withValues(alpha: 0.5)),
                  ),
                  style: GoogleFonts.inter(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dropdownStatut() {
    return _dropdownGlass<String?>(
      valeur: _filtreStatut,
      items: const [
        DropdownMenuItem(value: null, child: Text('Toutes')),
        DropdownMenuItem(value: 'active', child: Text('Actives')),
        DropdownMenuItem(value: 'inactive', child: Text('Inactives')),
      ],
      onChanged: (v) {
        setState(() => _filtreStatut = v);
        _chargerListe();
      },
    );
  }

  Widget _dropdownTri() {
    return _dropdownGlass<String>(
      valeur: _tri,
      items: _labelsTri.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: (v) {
        if (v == null) return;
        setState(() => _tri = v);
        _chargerListe();
      },
    );
  }

  Widget _dropdownGlass<T>({
    required T valeur,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(50),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: valeur,
              isDense: true,
              isExpanded: true,
              icon: const Icon(Icons.expand_more, size: 16),
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF334155)),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    );
  }

  Widget _chipsNiveaux() {
    final chips = <Widget>[
      _chipNiveau('Tous', null),
      ..._niveaux.map((n) => _chipNiveau(n, n)),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips.map((c) => Padding(padding: const EdgeInsets.only(right: 8), child: c)).toList(),
      ),
    );
  }

  Widget _chipNiveau(String label, String? valeur) {
    final selectionne = _filtreNiveau == valeur;
    return GestureDetector(
      onTap: () {
        setState(() => _filtreNiveau = valeur);
        _chargerListe();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selectionne ? const Color(0xFF1E3A8A) : const Color(0xFF1E3A8A).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selectionne ? Colors.white : const Color(0xFF1E3A8A),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // CARTE CLASSE
  // ══════════════════════════════════════════════════════

  Widget _carteClasse(Map<String, dynamic> classe) {
    final id            = classe['id'] as int;
    final nom           = classe['nom'] as String;
    final niveau        = classe['niveau'] as String? ?? '';
    final serie         = classe['serie'] as String?;
    final salle         = classe['salle'] as String?;
    final statut        = classe['statut'] as String? ?? 'active';
    final actif         = statut == 'active';
    final nombreEleves  = (classe['nombre_eleves'] as num?)?.toInt() ?? 0;
    final nombreMatieres = (classe['nombre_matieres'] as num?)?.toInt() ?? 0;
    final nombreProfs   = (classe['nombre_enseignants'] as num?)?.toInt() ?? 0;
    final capaciteMax   = (classe['capacite_max'] as num?)?.toInt() ?? 50;
    final profPrincipal = classe['professeur_principal'] as Map<String, dynamic>?;
    final pourcentage   = capaciteMax > 0 ? (nombreEleves / capaciteMax).clamp(0.0, 1.0) : 0.0;
    final couleurBordure = actif ? const Color(0xFF1E3A8A) : const Color(0xFF94A3B8);
    final couleurProgression = pourcentage >= 1.0
        ? const Color(0xFFDC2626)
        : pourcentage >= 0.8
            ? const Color(0xFFEA580C)
            : const Color(0xFF16A34A);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => FicheClasseScreen(classeId: id)),
      ).then((_) => _rafraichirTout()),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border(top: BorderSide(color: couleurBordure, width: 4)),
              boxShadow: [
                BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── En-tête carte ──────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A8A).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.class_, color: Color(0xFF1E3A8A), size: 18),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        SSMBadge(
                          label: actif ? 'ACTIVE' : 'INACTIVE',
                          couleur: actif ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                        ),
                        if (salle != null) ...[
                          const SizedBox(height: 4),
                          Text(salle, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  nom,
                  style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  serie != null ? '$niveau • $serie' : niveau,
                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF334155)),
                ),
                const SizedBox(height: 8),
                Divider(color: const Color(0xFF94A3B8).withValues(alpha: 0.2), height: 1),
                const SizedBox(height: 8),

                // ── Stats compactes ─────────────────────
                Row(
                  children: [
                    Expanded(child: _statCompacte(Icons.people, '$nombreEleves élèves')),
                    Expanded(child: _statCompacte(Icons.book, '$nombreMatieres matières')),
                    Expanded(child: _statCompacte(Icons.school, '$nombreProfs profs')),
                  ],
                ),
                const SizedBox(height: 10),

                // ── Progression effectif ────────────────
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pourcentage,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFF1F5F9),
                    color: couleurProgression,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$nombreEleves / $capaciteMax',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF334155)),
                ),

                if (profPrincipal != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 9,
                        backgroundColor: const Color(0xFF1E3A8A).withValues(alpha: 0.15),
                        backgroundImage: profPrincipal['photo_url'] != null
                            ? NetworkImage(profPrincipal['photo_url'] as String)
                            : null,
                        child: profPrincipal['photo_url'] == null
                            ? Text(
                                (profPrincipal['name'] as String).substring(0, 1).toUpperCase(),
                                style: GoogleFonts.sora(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF1E3A8A)),
                              )
                            : null,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          profPrincipal['name'] as String,
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF334155)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Voir détails →',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E3A8A)),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.picture_as_pdf, size: 16),
                          color: const Color(0xFFDC2626),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          onPressed: () => _exporterPdf(id),
                        ),
                        IconButton(
                          icon: const Icon(Icons.table_chart, size: 16),
                          color: const Color(0xFF16A34A),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          onPressed: () => _exporterExcel(id),
                        ),
                      ],
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

  Widget _statCompacte(IconData icone, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, size: 14, color: const Color(0xFF94A3B8)),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF334155)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _paginationBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            onPressed: _pageActuelle > 1 ? () => _chargerListe(page: _pageActuelle - 1) : null,
            icon: const Icon(Icons.chevron_left),
            label: const Text('Précédent'),
          ),
          Text('Page $_pageActuelle sur $_dernierePage', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF334155))),
          TextButton.icon(
            onPressed: _pageActuelle < _dernierePage ? () => _chargerListe(page: _pageActuelle + 1) : null,
            label: const Text('Suivant'),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // DIALOG CRÉATION
  // ══════════════════════════════════════════════════════

  Future<void> _afficherDialogCreation() async {
    final nomController      = TextEditingController();
    final serieController    = TextEditingController();
    final salleController    = TextEditingController();
    final capaciteController = TextEditingController(text: '50');
    String niveau = _niveaux.first;
    String statut = 'active';
    int? professeurPrincipalId;
    int? anneeAcademiqueId;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500, maxHeight: 680),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nouvelle classe',
                        style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                    const SizedBox(height: 4),
                    Text('Informations de la classe',
                        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF334155))),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _titreSection('Identification'),
                            TextField(
                              controller: nomController,
                              decoration: const InputDecoration(labelText: 'Nom *', prefixIcon: Icon(Icons.class_)),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: niveau,
                              decoration: const InputDecoration(labelText: 'Niveau *', prefixIcon: Icon(Icons.layers)),
                              items: _niveaux
                                  .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                                  .toList(),
                              onChanged: (v) => setStateDialog(() => niveau = v ?? niveau),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: serieController,
                              decoration: const InputDecoration(labelText: 'Série (ex: A, C, D, D2)', prefixIcon: Icon(Icons.bookmark_outline)),
                            ),
                            const SizedBox(height: 20),

                            _titreSection('Organisation'),
                            TextField(
                              controller: salleController,
                              decoration: const InputDecoration(labelText: 'Salle (ex: Salle 101)', prefixIcon: Icon(Icons.room)),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: capaciteController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Capacité max *', prefixIcon: Icon(Icons.people)),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Text('Statut :', style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF334155))),
                                const SizedBox(width: 12),
                                SegmentedButton<String>(
                                  segments: const [
                                    ButtonSegment(value: 'active', label: Text('Active')),
                                    ButtonSegment(value: 'inactive', label: Text('Inactive')),
                                  ],
                                  selected: {statut},
                                  onSelectionChanged: (s) => setStateDialog(() => statut = s.first),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            _titreSection('Responsable'),
                            DropdownButtonFormField<int>(
                              value: professeurPrincipalId,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Professeur principal', prefixIcon: Icon(Icons.school)),
                              hint: const Text('Aucun'),
                              items: _enseignants.map((e) {
                                return DropdownMenuItem<int>(value: e['id'] as int, child: Text(e['name'] as String));
                              }).toList(),
                              onChanged: (v) => setStateDialog(() => professeurPrincipalId = v),
                            ),
                            const SizedBox(height: 20),

                            _titreSection('Année'),
                            DropdownButtonFormField<int>(
                              value: anneeAcademiqueId,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Année académique', prefixIcon: Icon(Icons.calendar_month)),
                              hint: const Text('Aucune'),
                              items: _annees.map((a) {
                                return DropdownMenuItem<int>(value: a['id'] as int, child: Text(a['libelle'] as String));
                              }).toList(),
                              onChanged: (v) => setStateDialog(() => anneeAcademiqueId = v),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E3A8A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () async {
                              if (nomController.text.isEmpty) {
                                _afficherErreur('Le nom de la classe est obligatoire');
                                return;
                              }
                              try {
                                await ClasseService.creer(
                                  nom:                    nomController.text,
                                  niveau:                 niveau,
                                  serie:                  serieController.text.isEmpty ? null : serieController.text,
                                  salle:                  salleController.text.isEmpty ? null : salleController.text,
                                  capaciteMax:            int.tryParse(capaciteController.text) ?? 50,
                                  statut:                 statut,
                                  professeurPrincipalId:  professeurPrincipalId,
                                  anneeAcademiqueId:      anneeAcademiqueId,
                                );
                                if (context.mounted) Navigator.pop(context);
                                _afficherSucces('Classe créée avec succès');
                                _rafraichirTout();
                              } catch (e) {
                                _afficherErreur(e.toString().replaceAll('Exception: ', ''));
                              }
                            },
                            child: const Text('Créer la classe'),
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
    serieController.dispose();
    salleController.dispose();
    capaciteController.dispose();
  }

  Widget _titreSection(String titre) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        titre.toUpperCase(),
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1E3A8A), letterSpacing: 0.4),
      ),
    );
  }
}
