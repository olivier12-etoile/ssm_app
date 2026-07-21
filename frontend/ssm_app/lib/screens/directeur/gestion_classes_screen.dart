import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/classe_service.dart';
import '../../services/annee_service.dart';
import '../../services/utilisateur_service.dart';
import 'fiche_classe_screen.dart';

const Map<String, List<String>> _niveauxParCycle = {
  'college':          ['6ème', '5ème', '4ème', '3ème'],
  'lycee_moderne':    ['Seconde', 'Première', 'Terminale'],
  'lycee_technique':  ['Seconde', 'Première', 'Terminale'],
};

const Map<String, List<String>> _seriesParCycle = {
  'college':          [],
  'lycee_moderne':    ['A4', 'D', 'C', 'A', 'B'],
  'lycee_technique':  ['G1', 'G2', 'G3', 'F3', 'TH', 'TP', 'H', 'F1'],
};

const Map<String, String> _labelsCycle = {
  'college':         'Collège',
  'lycee_moderne':   'Lycée Moderne',
  'lycee_technique': 'Lycée Technique',
};

const Map<String, String> _emojisCycle = {
  'college':         '🏫',
  'lycee_moderne':   '🎓',
  'lycee_technique': '🔧',
};

const Map<String, Color> _couleursCycle = {
  'college':         Color(0xFF0D9488),
  'lycee_moderne':   Color(0xFF1E3A8A),
  'lycee_technique': Color(0xFFD97706),
};

const List<String> _ordreCycles = ['college', 'lycee_moderne', 'lycee_technique'];

String _genererNom(String cycle, String niveau, String? serie, String indice) {
  if (cycle == 'college') {
    return '$niveau $indice'.trim();
  }
  return '$niveau ${serie ?? ''} $indice'.replaceAll(RegExp(r'\s+'), ' ').trim();
}

class GestionClassesScreen extends StatefulWidget {
  const GestionClassesScreen({super.key});

  @override
  State<GestionClassesScreen> createState() => _GestionClassesScreenState();
}

class _GestionClassesScreenState extends State<GestionClassesScreen> {
  static const Map<String, String> _labelsTri = {
    'nom':      'Nom',
    'niveau':   'Niveau',
    'effectif': 'Effectif',
  };

  // college : {niveau: [classes]} — lycées : {niveau: {serie: [classes]}}
  Map<String, dynamic> _groupes = {
    'college': {}, 'lycee_moderne': {}, 'lycee_technique': {},
  };
  int _totalClasses = 0;
  int _totalActives = 0;

  bool _chargementListe = true;
  String? _filtreStatut;
  String _tri = 'nom';
  String _recherche = '';
  Timer? _debounceRecherche;

  List<dynamic> _enseignants = [];
  List<dynamic> _annees = [];

  @override
  void initState() {
    super.initState();
    _chargerListe();
    _chargerReferences();
  }

  @override
  void dispose() {
    _debounceRecherche?.cancel();
    super.dispose();
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
      // Listes de référence non bloquantes pour l'affichage.
    }
  }

  // Aplatit récursivement {niveau: [...]} ou {niveau: {serie: [...]}} en liste.
  List<dynamic> _aplatir(dynamic valeur) {
    final resultat = <dynamic>[];
    void parcourir(dynamic v) {
      if (v is List) {
        resultat.addAll(v);
      } else if (v is Map) {
        for (final sous in v.values) {
          parcourir(sous);
        }
      }
    }
    parcourir(valeur);
    return resultat;
  }

  Future<void> _chargerListe() async {
    setState(() => _chargementListe = true);
    try {
      final resultat = await ClasseService.lister(
        statut:    _filtreStatut,
        recherche: _recherche.isEmpty ? null : _recherche,
        tri:       _tri,
      );

      final groupes = <String, dynamic>{
        'college':         resultat['college'] is Map ? resultat['college'] : {},
        'lycee_moderne':   resultat['lycee_moderne'] is Map ? resultat['lycee_moderne'] : {},
        'lycee_technique': resultat['lycee_technique'] is Map ? resultat['lycee_technique'] : {},
      };
      final toutes = _aplatir(groupes);

      setState(() {
        _groupes         = groupes;
        _totalClasses    = toutes.length;
        _totalActives    = toutes.where((c) => c['statut'] == 'active').length;
        _chargementListe = false;
      });
    } catch (e) {
      setState(() => _chargementListe = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
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
                onRefresh: _chargerListe,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _barreOutils(),
                    const SizedBox(height: 16),
                    if (_chargementListe)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_totalClasses == 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text('Aucune classe trouvée', style: GoogleFonts.inter(color: const Color(0xFF334155))),
                        ),
                      )
                    else
                      ..._ordreCycles
                          .where((c) => (_groupes[c] as Map).isNotEmpty)
                          .map((cycle) => _sectionCycle(cycle, _groupes[cycle] as Map)),
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
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Classes', style: GoogleFonts.sora(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 4),
              Text('$_totalActives classes actives', style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.7))),
            ],
          ),
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Text('$_totalClasses', style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
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
      items: _labelsTri.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
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

  // ══════════════════════════════════════════════════════
  // SECTIONS PAR CYCLE → NIVEAU → (SÉRIE)
  // ══════════════════════════════════════════════════════

  Widget _sectionCycle(String cycle, Map niveauxData) {
    final couleur = _couleursCycle[cycle]!;
    final classesDuCycle = _aplatir(niveauxData);
    final niveauxPresents = _niveauxParCycle[cycle]!.where((n) => niveauxData.containsKey(n)).toList();
    // Inclut aussi d'éventuels niveaux hors liste canonique (données historiques).
    for (final n in niveauxData.keys) {
      if (!niveauxPresents.contains(n)) niveauxPresents.add(n);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 4, height: 20, decoration: BoxDecoration(color: couleur, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Text(
                _labelsCycle[cycle]!.toUpperCase(),
                style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: couleur, letterSpacing: 1.2),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: couleur.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                child: Text('${classesDuCycle.length} classe(s)', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: couleur)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...niveauxPresents.map((niveau) => _sectionNiveau(cycle, niveau, niveauxData[niveau], couleur)),
        ],
      ),
    );
  }

  Widget _sectionNiveau(String cycle, String niveau, dynamic donnees, Color couleur) {
    final estCollege = cycle == 'college';

    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(niveau, style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
          const SizedBox(height: 6),
          if (estCollege)
            ...(donnees as List? ?? []).map((c) => _carteClasseCompacte(c as Map<String, dynamic>, couleur))
          else
            ...(donnees is Map ? donnees.entries : <MapEntry>[]).map((entry) {
              final serie = entry.key as String;
              final classes = entry.value as List;
              return Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Série $serie', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8))),
                    const SizedBox(height: 4),
                    ...classes.map((c) => _carteClasseCompacte(c as Map<String, dynamic>, couleur)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _carteClasseCompacte(Map<String, dynamic> classe, Color couleurCycle) {
    final id           = classe['id'] as int;
    final nom          = classe['nom'] as String;
    final salle        = classe['salle'] as String?;
    final statut       = classe['statut'] as String? ?? 'active';
    final actif        = statut == 'active';
    final nombreEleves = (classe['nombre_eleves'] as num?)?.toInt() ?? 0;
    final nombreMatieres = (classe['nombre_matieres'] as num?)?.toInt() ?? 0;
    final capaciteMax  = (classe['capacite_max'] as num?)?.toInt() ?? 40;
    final pourcentage  = capaciteMax > 0 ? (nombreEleves / capaciteMax).clamp(0.0, 1.0) : 0.0;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => FicheClasseScreen(classeId: id)),
      ).then((_) => _chargerListe()),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 90),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border(left: BorderSide(color: couleurCycle, width: 4)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: couleurCycle.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.school, color: couleurCycle, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(nom, style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (salle != null)
                        Text(salle, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF334155)), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.people, size: 12, color: const Color(0xFF94A3B8)),
                          const SizedBox(width: 2),
                          Text('$nombreEleves', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
                          const SizedBox(width: 8),
                          Icon(Icons.book, size: 12, color: const Color(0xFF94A3B8)),
                          const SizedBox(width: 2),
                          Text('$nombreMatieres matières', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
                          const SizedBox(width: 8),
                          Icon(actif ? Icons.check_circle : Icons.pause_circle, size: 12, color: actif ? const Color(0xFF16A34A) : const Color(0xFF94A3B8)),
                          const SizedBox(width: 2),
                          Text(actif ? 'active' : 'inactive', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$nombreEleves/$capaciteMax', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1E3A8A))),
                    Text('élèves', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: SizedBox(
                        width: 60,
                        height: 4,
                        child: LinearProgressIndicator(
                          value: pourcentage,
                          backgroundColor: const Color(0xFFF1F5F9),
                          color: pourcentage >= 1
                              ? const Color(0xFFDC2626)
                              : pourcentage >= 0.8
                                  ? const Color(0xFFEA580C)
                                  : const Color(0xFF16A34A),
                        ),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => FicheClasseScreen(classeId: id)),
                  ).then((_) => _chargerListe()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // DIALOG CRÉATION — nom généré automatiquement
  // ══════════════════════════════════════════════════════

  Future<void> _afficherDialogCreation() async {
    final salleController    = TextEditingController();
    final capaciteController = TextEditingController(text: '40');
    final serieCustomController = TextEditingController();

    String cycle    = 'college';
    String niveau   = _niveauxParCycle['college']!.first;
    String? serie;
    bool serieEstPersonnalisee = false;
    String indice   = 'A';
    int? professeurPrincipalId;
    int? anneeAcademiqueId;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final niveaux = _niveauxParCycle[cycle]!;
          final series  = _seriesParCycle[cycle]!;
          final estCollege = cycle == 'college';
          final indices = estCollege ? ['A', 'B', 'C', 'D'] : ['1', '2', '3', '4'];
          final serieActuelle = serieEstPersonnalisee ? serieCustomController.text : serie;
          final nomGenere = _genererNom(cycle, niveau, estCollege ? null : serieActuelle, indice);

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540, maxHeight: 760),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nouvelle classe',
                        style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                    const SizedBox(height: 4),
                    Text('Le nom est généré automatiquement',
                        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF334155))),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Aperçu du nom généré ─────────────
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E3A8A).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Nom généré :', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF334155))),
                                  const SizedBox(height: 2),
                                  Text(nomGenere.isEmpty ? '—' : nomGenere,
                                      style: GoogleFonts.sora(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF1E3A8A))),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // ── Étape 1 : Cycle ──────────────────
                            _titreSection('Étape 1 — Cycle'),
                            SizedBox(
                              width: double.infinity,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SegmentedButton<String>(
                                  segments: _ordreCycles
                                      .map((c) => ButtonSegment(value: c, label: Text('${_emojisCycle[c]} ${_labelsCycle[c]}')))
                                      .toList(),
                                  selected: {cycle},
                                  onSelectionChanged: (s) => setStateDialog(() {
                                    cycle   = s.first;
                                    niveau  = _niveauxParCycle[cycle]!.first;
                                    serie   = null;
                                    serieEstPersonnalisee = false;
                                    serieCustomController.clear();
                                    indice  = cycle == 'college' ? 'A' : '1';
                                  }),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // ── Étape 2 : Niveau ─────────────────
                            _titreSection('Étape 2 — Niveau'),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SegmentedButton<String>(
                                segments: niveaux.map((n) => ButtonSegment(value: n, label: Text(n))).toList(),
                                selected: {niveaux.contains(niveau) ? niveau : niveaux.first},
                                onSelectionChanged: (s) => setStateDialog(() => niveau = s.first),
                              ),
                            ),

                            // ── Étape 3 : Série (lycées uniquement) ──
                            if (!estCollege) ...[
                              const SizedBox(height: 20),
                              _titreSection('Étape 3 — Série'),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ...series.map((s) => ChoiceChip(
                                        label: Text(s),
                                        selected: !serieEstPersonnalisee && serie == s,
                                        onSelected: (_) => setStateDialog(() {
                                          serie = s;
                                          serieEstPersonnalisee = false;
                                        }),
                                        selectedColor: const Color(0xFF1E3A8A),
                                        labelStyle: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600,
                                          color: !serieEstPersonnalisee && serie == s ? Colors.white : const Color(0xFF334155),
                                        ),
                                      )),
                                  ChoiceChip(
                                    label: const Text('+ Autre'),
                                    selected: serieEstPersonnalisee,
                                    onSelected: (_) => setStateDialog(() {
                                      serieEstPersonnalisee = true;
                                      serie = null;
                                    }),
                                    selectedColor: const Color(0xFFD97706),
                                    labelStyle: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      color: serieEstPersonnalisee ? Colors.white : const Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ),
                              if (serieEstPersonnalisee) ...[
                                const SizedBox(height: 8),
                                TextField(
                                  controller: serieCustomController,
                                  textCapitalization: TextCapitalization.characters,
                                  decoration: const InputDecoration(labelText: 'Série personnalisée', prefixIcon: Icon(Icons.edit)),
                                  onChanged: (_) => setStateDialog(() {}),
                                ),
                              ],
                            ],

                            const SizedBox(height: 20),
                            // ── Étape 4 : Indice ─────────────────
                            _titreSection('Étape 4 — Numéro de la classe (si plusieurs)'),
                            SegmentedButton<String>(
                              segments: indices.map((i) => ButtonSegment(value: i, label: Text(i))).toList(),
                              selected: {indice},
                              onSelectionChanged: (s) => setStateDialog(() => indice = s.first),
                            ),
                            const SizedBox(height: 20),

                            // ── Étape 5 : Informations complémentaires ──
                            _titreSection('Étape 5 — Informations complémentaires'),
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
                            DropdownButtonFormField<int>(
                              value: professeurPrincipalId,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Professeur principal', prefixIcon: Icon(Icons.school)),
                              hint: const Text('Aucun'),
                              items: _enseignants.map((e) => DropdownMenuItem<int>(value: e['id'] as int, child: Text(e['name'] as String))).toList(),
                              onChanged: (v) => setStateDialog(() => professeurPrincipalId = v),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<int>(
                              value: anneeAcademiqueId,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Année académique', prefixIcon: Icon(Icons.calendar_month)),
                              hint: const Text('Aucune'),
                              items: _annees.map((a) => DropdownMenuItem<int>(value: a['id'] as int, child: Text(a['libelle'] as String))).toList(),
                              onChanged: (v) => setStateDialog(() => anneeAcademiqueId = v),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler'))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E3A8A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () async {
                              if (!estCollege && (serieActuelle == null || serieActuelle.isEmpty)) {
                                _afficherErreur('Veuillez sélectionner ou saisir une série');
                                return;
                              }
                              try {
                                await ClasseService.creer(
                                  niveau:                 niveau,
                                  serie:                  estCollege ? null : serieActuelle,
                                  indice:                 indice,
                                  salle:                  salleController.text.isEmpty ? null : salleController.text,
                                  capaciteMax:            int.tryParse(capaciteController.text) ?? 40,
                                  statut:                 'active',
                                  cycle:                  cycle,
                                  professeurPrincipalId:  professeurPrincipalId,
                                  anneeAcademiqueId:      anneeAcademiqueId,
                                );
                                if (context.mounted) Navigator.pop(context);
                                _afficherSucces('Classe "$nomGenere" créée avec succès');
                                _chargerListe();
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

    salleController.dispose();
    capaciteController.dispose();
    serieCustomController.dispose();
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
