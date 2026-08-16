import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/utilisateur.dart';
import '../../services/auth_service.dart';
import '../../services/classe_service.dart';
import '../../services/annee_service.dart';
import '../../services/utilisateur_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_data_table.dart';
import '../../widgets/ssm/ssm_page_scaffold.dart';
import '../../widgets/ssm/ssm_pill.dart';
import '../../widgets/ssm/ssm_sidebar.dart';
import '../../widgets/ssm/ssm_stat_card.dart';
import 'fiche_classe_screen.dart';

const Map<String, List<String>> _niveauxParCycle = {
  'college': ['6ème', '5ème', '4ème', '3ème'],
  'lycee_moderne': ['Seconde', 'Première', 'Terminale'],
  'lycee_technique': ['Seconde', 'Première', 'Terminale'],
};

const Map<String, List<String>> _seriesParCycle = {
  'college': [],
  'lycee_moderne': ['A4', 'D', 'C', 'A', 'B'],
  'lycee_technique': ['G1', 'G2', 'G3', 'F3', 'TH', 'TP', 'H', 'F1'],
};

const Map<String, String> _labelsCycle = {
  'college': 'Collège',
  'lycee_moderne': 'Lycée Moderne',
  'lycee_technique': 'Lycée Technique',
};

const Map<String, String> _emojisCycle = {
  'college': '🏫',
  'lycee_moderne': '🎓',
  'lycee_technique': '🔧',
};

const Map<String, Color> _couleursCycle = {
  'college': SSMPalette.teal,
  'lycee_moderne': SSMPalette.indigo,
  'lycee_technique': SSMPalette.ambre,
};

const List<String> _ordreCycles = [
  'college',
  'lycee_moderne',
  'lycee_technique',
];

String _genererNom(String cycle, String niveau, String? serie, String indice) {
  if (cycle == 'college') {
    return '$niveau $indice'.trim();
  }
  return '$niveau ${serie ?? ''} $indice'
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class GestionClassesScreen extends StatefulWidget {
  const GestionClassesScreen({super.key});

  @override
  State<GestionClassesScreen> createState() => _GestionClassesScreenState();
}

class _GestionClassesScreenState extends State<GestionClassesScreen> {
  static const Map<String, String> _labelsTri = {
    'nom': 'Nom',
    'niveau': 'Niveau',
    'effectif': 'Effectif',
  };

  Utilisateur? _utilisateur;

  // college : {niveau: [classes]} — lycées : {niveau: {serie: [classes]}}
  Map<String, dynamic> _groupes = {
    'college': {},
    'lycee_moderne': {},
    'lycee_technique': {},
  };
  int _totalClasses = 0;
  int _totalActives = 0;
  List<String> _cyclesDisponibles = [];
  String? _filtreCycle;

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
    AuthService.getUtilisateur().then((u) {
      if (mounted) setState(() => _utilisateur = u);
    });
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
        final resultat = await UtilisateurService.lister(
          role: 'enseignant',
          page: page,
        );
        enseignants.addAll((resultat['data'] as List?) ?? []);
        final dernierePage = resultat['last_page'] as int? ?? 1;
        if (page >= dernierePage) break;
        page++;
      }
      final annees = await AnneeService.listerAnnees();
      setState(() {
        _enseignants = enseignants;
        _annees = annees;
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
        statut: _filtreStatut,
        recherche: _recherche.isEmpty ? null : _recherche,
        tri: _tri,
      );

      final groupes = <String, dynamic>{
        'college': resultat['college'] is Map ? resultat['college'] : {},
        'lycee_moderne': resultat['lycee_moderne'] is Map
            ? resultat['lycee_moderne']
            : {},
        'lycee_technique': resultat['lycee_technique'] is Map
            ? resultat['lycee_technique']
            : {},
      };
      final toutes = _aplatir(groupes);

      final cyclesDisponibles = _ordreCycles
          .where((cycle) => toutes.any((c) => c['cycle'] == cycle))
          .toList();

      setState(() {
        _groupes = groupes;
        _totalClasses = toutes.length;
        _totalActives = toutes.where((c) => c['statut'] == 'active').length;
        _cyclesDisponibles = cyclesDisponibles;
        if (_filtreCycle != null && !cyclesDisponibles.contains(_filtreCycle)) {
          _filtreCycle = null;
        }
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

  void _naviguer(BuildContext context, String route) {
    if (route == '/directeur/classes') return;
    Navigator.pushNamed(context, route);
  }

  void _ouvrirFiche(int classeId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FicheClasseScreen(classeId: classeId)),
    ).then((_) => _chargerListe());
  }

  String _libelleRole(String? role) {
    switch (role) {
      case 'directeur':
        return 'Directeur';
      case 'censeur':
        return 'Censeur';
      case 'secretaire':
        return 'Secrétaire';
      case 'enseignant':
        return 'Enseignant';
      case 'comptable':
        return 'Comptable';
      case 'super_admin':
        return 'Super admin';
      default:
        return role ?? '';
    }
  }

  List<SSMNavSection> _sections() {
    return [
      SSMNavSection(titre: 'Principal', items: [
        const SSMNavItem(icone: Icons.dashboard_outlined, label: 'Tableau de bord', route: '/tableau-de-bord'),
        const SSMNavItem(icone: Icons.people_outline, label: 'Élèves', route: '/directeur/eleves'),
        const SSMNavItem(icone: Icons.grade_outlined, label: 'Notes & évaluations', route: '/notes'),
        const SSMNavItem(icone: Icons.price_change_outlined, label: 'Frais scolaires', route: '/directeur/frais'),
        const SSMNavItem(icone: Icons.calendar_view_week_outlined, label: 'Emploi du temps', route: '/emploi-du-temps'),
        const SSMNavItem(icone: Icons.description_outlined, label: 'Bulletins PDF', route: '/bulletins'),
      ]),
      SSMNavSection(titre: 'Pilotage', items: [
        const SSMNavItem(icone: Icons.bar_chart_outlined, label: 'Statistiques', route: '/statistiques'),
        const SSMNavItem(icone: Icons.notifications_outlined, label: 'Notifications', route: '/notifications'),
        const SSMNavItem(icone: Icons.settings_outlined, label: 'Paramètres école', route: '/parametres'),
      ]),
      if (_utilisateur?.role == 'directeur')
        SSMNavSection(titre: 'Administration', items: [
          const SSMNavItem(icone: Icons.people_alt_outlined, label: 'Utilisateurs', route: '/directeur/utilisateurs'),
          SSMNavItem(
            icone: Icons.class_outlined,
            label: 'Classes',
            route: '/directeur/classes',
            badge: (!_chargementListe && _totalClasses > 0) ? _totalClasses : null,
          ),
          const SSMNavItem(icone: Icons.menu_book_outlined, label: 'Matières', route: '/directeur/matieres'),
          const SSMNavItem(icone: Icons.calendar_month_outlined, label: 'Années & Périodes', route: '/directeur/annees'),
        ]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return SSMPageScaffold(
      nomEcole: _utilisateur?.codeEcole ?? 'Mon établissement',
      codeEcole: _utilisateur?.codeEcole ?? '—',
      nomUtilisateur: _utilisateur?.nom ?? '…',
      role: _libelleRole(_utilisateur?.role),
      sections: _sections(),
      routeActuelle: '/directeur/classes',
      onNavigate: (route) => _naviguer(context, route),
      onProfilTap: () => Navigator.pushNamed(context, '/profil'),
      breadcrumb: 'Accueil',
      breadcrumbActuel: 'Classes',
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: SSMPalette.indigo,
        foregroundColor: Colors.white,
        onPressed: _afficherDialogCreation,
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle classe'),
      ),
      child: RefreshIndicator(
        onRefresh: _chargerListe,
        color: SSMPalette.indigo,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Classes',
                style: GoogleFonts.sora(fontSize: 19, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
              ),
              const SizedBox(height: 4),
              Text(
                '$_totalClasses classes · $_totalActives actives',
                style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2),
              ),
              const SizedBox(height: 16),
              _cartesStats(),
              const SizedBox(height: 16),
              _barreOutils(),
              const SizedBox(height: 10),
              if (_cyclesDisponibles.isNotEmpty) ...[
                _chipsCycles(),
                const SizedBox(height: 16),
              ] else
                const SizedBox(height: 6),
              _contenuListe(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // STATISTIQUES
  // ══════════════════════════════════════════════════════

  Widget _cartesStats() {
    final inactives = _totalClasses - _totalActives;
    final cartes = <(IconData, Color, String, String)>[
      (Icons.class_outlined, SSMPalette.indigo, '$_totalClasses', 'Total classes'),
      (Icons.check_circle_outline, SSMPalette.teal, '$_totalActives', 'Classes actives'),
      (Icons.pause_circle_outline, SSMPalette.ambre, '$inactives', 'Classes inactives'),
      (Icons.account_tree_outlined, SSMPalette.teal, '${_cyclesDisponibles.length}', 'Cycles utilisés'),
    ];

    return LayoutBuilder(builder: (context, contraintes) {
      final colonnes = contraintes.maxWidth >= 760 ? 4 : (contraintes.maxWidth >= 520 ? 2 : 1);
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: cartes.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: colonnes,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 168,
        ),
        itemBuilder: (context, i) {
          final c = cartes[i];
          return SSMStatCard(icone: c.$1, couleur: c.$2, valeur: c.$3, label: c.$4);
        },
      );
    });
  }

  // ══════════════════════════════════════════════════════
  // BARRE OUTILS (recherche + filtres)
  // ══════════════════════════════════════════════════════

  Widget _barreOutils() {
    return LayoutBuilder(builder: (context, contraintes) {
      if (contraintes.maxWidth >= 640) {
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _barreRecherche(),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _dropdownStatut()),
              const SizedBox(width: 8),
              Expanded(child: _dropdownTri()),
            ],
          ),
        ],
      );
    });
  }

  Widget _barreRecherche() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(SSMRayons.moyen),
      ),
      child: TextField(
        onChanged: _onRechercheChangee,
        style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte1),
        decoration: InputDecoration(
          hintText: 'Rechercher une classe...',
          hintStyle: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte3),
          prefixIcon: const Icon(Icons.search, size: 18, color: SSMPalette.texte3),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _dropdownStatut() {
    return _dropdownFlat<String?>(
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
    return _dropdownFlat<String>(
      valeur: _tri,
      items: _labelsTri.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text('Trier : ${e.value}')))
          .toList(),
      onChanged: (v) {
        if (v == null) return;
        setState(() => _tri = v);
        _chargerListe();
      },
    );
  }

  Widget _dropdownFlat<T>({
    required T valeur,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(SSMRayons.moyen),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: valeur,
          isDense: true,
          isExpanded: true,
          icon: const Icon(Icons.expand_more, size: 16, color: SSMPalette.texte3),
          style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte1),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // CHIPS DE FILTRAGE PAR CYCLE (dynamiques)
  // ══════════════════════════════════════════════════════

  Widget _chipsCycles() {
    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _chipCycle(
            label: 'Tous',
            actif: _filtreCycle == null,
            couleur: SSMPalette.indigo,
            onTap: () => setState(() => _filtreCycle = null),
          ),
          for (final cycle in _cyclesDisponibles) ...[
            const SizedBox(width: 8),
            _chipCycle(
              label: '${_emojisCycle[cycle]} ${_labelsCycle[cycle]}',
              actif: _filtreCycle == cycle,
              couleur: _couleursCycle[cycle]!,
              onTap: () => setState(() => _filtreCycle = cycle),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chipCycle({
    required String label,
    required bool actif,
    required Color couleur,
    required VoidCallback onTap,
  }) {
    return Material(
      color: actif ? couleur : const Color(0xFFF9FAFB),
      borderRadius: BorderRadius.circular(SSMRayons.pilule),
      child: InkWell(
        borderRadius: BorderRadius.circular(SSMRayons.pilule),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SSMRayons.pilule),
            border: actif ? null : Border.all(color: const Color(0xFFE5E7EB)),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: actif ? Colors.white : SSMPalette.texte2,
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // LISTE — SECTIONS PAR CYCLE → NIVEAU → (SÉRIE)
  // ══════════════════════════════════════════════════════

  Widget _contenuListe() {
    if (_chargementListe) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator(color: SSMPalette.indigo)),
      );
    }
    if (_totalClasses == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(child: Text('Aucune classe trouvée', style: GoogleFonts.inter(color: SSMPalette.texte3))),
      );
    }

    return LayoutBuilder(builder: (context, contraintes) {
      final desktop = contraintes.maxWidth >= 760;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _ordreCycles
            .where((c) => (_groupes[c] as Map).isNotEmpty)
            .where((c) => _filtreCycle == null || _filtreCycle == c)
            .map((cycle) => _sectionCycle(cycle, _groupes[cycle] as Map, desktop))
            .toList(),
      );
    });
  }

  Widget _sectionCycle(String cycle, Map niveauxData, bool desktop) {
    final couleur = _couleursCycle[cycle]!;
    final classesDuCycle = _aplatir(niveauxData);
    final niveauxPresents = _niveauxParCycle[cycle]!
        .where((n) => niveauxData.containsKey(n))
        .toList();
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
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(color: couleur, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 8),
              Text(
                _labelsCycle[cycle]!.toUpperCase(),
                style: GoogleFonts.sora(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: couleur,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 8),
              SSMPill.couleur(label: '${classesDuCycle.length} classe(s)', couleur: couleur),
            ],
          ),
          const SizedBox(height: 12),
          ...niveauxPresents.map(
            (niveau) => _sectionNiveau(niveau, niveauxData[niveau], couleur, desktop),
          ),
        ],
      ),
    );
  }

  Widget _sectionNiveau(String niveau, dynamic donnees, Color couleur, bool desktop) {
    final estListeSimple = donnees is List;

    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            niveau,
            style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: SSMPalette.texte1),
          ),
          const SizedBox(height: 6),
          if (estListeSimple)
            _groupeClasses((donnees as List? ?? []).cast<Map<String, dynamic>>(), couleur, desktop)
          else
            ...(donnees is Map ? donnees.entries : <MapEntry>[]).map((entry) {
              final serie = entry.key as String;
              final classes = (entry.value as List).cast<Map<String, dynamic>>();
              return Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Série $serie',
                      style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: SSMPalette.texte3),
                    ),
                    const SizedBox(height: 4),
                    _groupeClasses(classes, couleur, desktop),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── Regroupe une liste de classes en tableau (desktop) ou cartes (mobile) ──
  Widget _groupeClasses(List<Map<String, dynamic>> classes, Color couleurCycle, bool desktop) {
    if (classes.isEmpty) return const SizedBox.shrink();
    if (desktop) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SSMDataTable(
          colonnes: const [
            SSMDataColumn(''),
            SSMDataColumn('Classe'),
            SSMDataColumn('Effectif'),
            SSMDataColumn('Matières'),
            SSMDataColumn('Statut'),
            SSMDataColumn(''),
          ],
          onLigneTap: (i) => _ouvrirFiche(classes[i]['id'] as int),
          lignes: [for (final c in classes) _ligneClasse(c, couleurCycle)],
        ),
      );
    }
    return Column(children: [for (final c in classes) _carteClasse(c, couleurCycle)]);
  }

  List<Widget> _ligneClasse(Map<String, dynamic> classe, Color couleurCycle) {
    final nom = classe['nom'] as String;
    final salle = classe['salle'] as String?;
    final statut = classe['statut'] as String? ?? 'active';
    final actif = statut == 'active';
    final nombreEleves = (classe['nombre_eleves'] as num?)?.toInt() ?? 0;
    final nombreMatieres = (classe['nombre_matieres'] as num?)?.toInt() ?? 0;
    final capaciteMax = (classe['capacite_max'] as num?)?.toInt() ?? 40;
    final pourcentage = capaciteMax > 0 ? (nombreEleves / capaciteMax).clamp(0.0, 1.0) : 0.0;

    return [
      Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(color: couleurCycle.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
        child: Icon(Icons.school, size: 15, color: couleurCycle),
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(nom, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
          if (salle != null)
            Text(salle, style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte3)),
        ],
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$nombreEleves/$capaciteMax', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte1)),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              width: 60,
              height: 4,
              child: LinearProgressIndicator(
                value: pourcentage,
                backgroundColor: SSMPalette.bordure,
                color: pourcentage >= 1
                    ? SSMPalette.rouge
                    : pourcentage >= 0.8
                        ? SSMPalette.ambre
                        : SSMPalette.teal,
              ),
            ),
          ),
        ],
      ),
      Text('$nombreMatieres', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte1)),
      SSMPill.couleur(label: actif ? 'active' : 'inactive', couleur: actif ? SSMPalette.teal : SSMPalette.texte3),
      const Icon(Icons.chevron_right, size: 18, color: SSMPalette.texte3),
    ];
  }

  Widget _carteClasse(Map<String, dynamic> classe, Color couleurCycle) {
    final id = classe['id'] as int;
    final nom = classe['nom'] as String;
    final salle = classe['salle'] as String?;
    final statut = classe['statut'] as String? ?? 'active';
    final actif = statut == 'active';
    final nombreEleves = (classe['nombre_eleves'] as num?)?.toInt() ?? 0;
    final nombreMatieres = (classe['nombre_matieres'] as num?)?.toInt() ?? 0;
    final capaciteMax = (classe['capacite_max'] as num?)?.toInt() ?? 40;

    return Material(
      color: SSMPalette.blanc,
      borderRadius: BorderRadius.circular(SSMRayons.grand),
      child: InkWell(
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        onTap: () => _ouvrirFiche(id),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SSMRayons.grand),
            border: Border(
              top: BorderSide(color: SSMPalette.bordure),
              right: BorderSide(color: SSMPalette.bordure),
              bottom: BorderSide(color: SSMPalette.bordure),
              left: BorderSide(color: couleurCycle, width: 3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: couleurCycle.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.school, color: couleurCycle, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nom, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
                    if (salle != null)
                      Text(salle, style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte3)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        SSMPill.couleur(label: '$nombreEleves/$capaciteMax élèves', couleur: SSMPalette.indigo),
                        SSMPill.couleur(label: '$nombreMatieres matières', couleur: SSMPalette.texte2),
                        SSMPill.couleur(label: actif ? 'active' : 'inactive', couleur: actif ? SSMPalette.teal : SSMPalette.texte3),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: SSMPalette.texte3),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // DIALOG CRÉATION — nom généré automatiquement
  // ══════════════════════════════════════════════════════

  InputDecoration _decorationChamp(String label, {IconData? icone}) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2),
      prefixIcon: icone != null ? Icon(icone, color: SSMPalette.texte3, size: 20) : null,
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

  Future<void> _afficherDialogCreation() async {
    final salleController = TextEditingController();
    final capaciteController = TextEditingController(text: '40');
    final serieCustomController = TextEditingController();

    String cycle = 'college';
    String niveau = _niveauxParCycle['college']!.first;
    String? serie;
    bool serieEstPersonnalisee = false;
    String indice = 'A';
    int? professeurPrincipalId;
    int? anneeAcademiqueId;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final niveaux = _niveauxParCycle[cycle]!;
          final series = _seriesParCycle[cycle]!;
          final estCollege = cycle == 'college';
          final indices = estCollege
              ? ['A', 'B', 'C', 'D']
              : ['1', '2', '3', '4'];
          final serieActuelle = serieEstPersonnalisee
              ? serieCustomController.text
              : serie;
          final nomGenere = _genererNom(
            cycle,
            niveau,
            estCollege ? null : serieActuelle,
            indice,
          );

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
            backgroundColor: SSMPalette.blanc,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540, maxHeight: 760),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nouvelle classe',
                      style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Le nom est généré automatiquement',
                      style: GoogleFonts.inter(fontSize: 12.5, color: SSMPalette.texte3),
                    ),
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
                                color: SSMPalette.indigoClair,
                                borderRadius: BorderRadius.circular(SSMRayons.grand),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Nom généré :',
                                    style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    nomGenere.isEmpty ? '—' : nomGenere,
                                    style: GoogleFonts.sora(fontSize: 22, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
                                  ),
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
                                      .map(
                                        (c) => ButtonSegment(
                                          value: c,
                                          label: Text(
                                            '${_emojisCycle[c]} ${_labelsCycle[c]}',
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  selected: {cycle},
                                  onSelectionChanged: (s) => setStateDialog(() {
                                    cycle = s.first;
                                    niveau = _niveauxParCycle[cycle]!.first;
                                    serie = null;
                                    serieEstPersonnalisee = false;
                                    serieCustomController.clear();
                                    indice = cycle == 'college' ? 'A' : '1';
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
                                segments: niveaux
                                    .map(
                                      (n) => ButtonSegment(
                                        value: n,
                                        label: Text(n),
                                      ),
                                    )
                                    .toList(),
                                selected: {
                                  niveaux.contains(niveau)
                                      ? niveau
                                      : niveaux.first,
                                },
                                onSelectionChanged: (s) =>
                                    setStateDialog(() => niveau = s.first),
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
                                  ...series.map(
                                    (s) => ChoiceChip(
                                      label: Text(s),
                                      selected:
                                          !serieEstPersonnalisee && serie == s,
                                      onSelected: (_) => setStateDialog(() {
                                        serie = s;
                                        serieEstPersonnalisee = false;
                                      }),
                                      selectedColor: SSMPalette.indigo,
                                      labelStyle: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        color:
                                            !serieEstPersonnalisee && serie == s
                                                ? Colors.white
                                                : SSMPalette.texte2,
                                      ),
                                    ),
                                  ),
                                  ChoiceChip(
                                    label: const Text('+ Autre'),
                                    selected: serieEstPersonnalisee,
                                    onSelected: (_) => setStateDialog(() {
                                      serieEstPersonnalisee = true;
                                      serie = null;
                                    }),
                                    selectedColor: SSMPalette.ambre,
                                    labelStyle: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      color: serieEstPersonnalisee
                                          ? Colors.white
                                          : SSMPalette.texte2,
                                    ),
                                  ),
                                ],
                              ),
                              if (serieEstPersonnalisee) ...[
                                const SizedBox(height: 8),
                                TextField(
                                  controller: serieCustomController,
                                  textCapitalization: TextCapitalization.characters,
                                  decoration: _decorationChamp('Série personnalisée', icone: Icons.edit),
                                  onChanged: (_) => setStateDialog(() {}),
                                ),
                              ],
                            ],

                            const SizedBox(height: 20),
                            // ── Étape 4 : Indice ─────────────────
                            _titreSection('Étape 4 — Numéro de la classe (si plusieurs)'),
                            SegmentedButton<String>(
                              segments: indices
                                  .map(
                                    (i) =>
                                        ButtonSegment(value: i, label: Text(i)),
                                  )
                                  .toList(),
                              selected: {indice},
                              onSelectionChanged: (s) =>
                                  setStateDialog(() => indice = s.first),
                            ),
                            const SizedBox(height: 20),

                            // ── Étape 5 : Informations complémentaires ──
                            _titreSection('Étape 5 — Informations complémentaires'),
                            TextField(
                              controller: salleController,
                              decoration: _decorationChamp('Salle (ex: Salle 101)', icone: Icons.room_outlined),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: capaciteController,
                              keyboardType: TextInputType.number,
                              decoration: _decorationChamp('Capacité max *', icone: Icons.people_outline),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<int>(
                              initialValue: professeurPrincipalId,
                              isExpanded: true,
                              decoration: _decorationChamp('Professeur principal', icone: Icons.school_outlined),
                              hint: Text('Aucun', style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte3)),
                              items: _enseignants
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
                            const SizedBox(height: 12),
                            DropdownButtonFormField<int>(
                              initialValue: anneeAcademiqueId,
                              isExpanded: true,
                              decoration: _decorationChamp('Année académique', icone: Icons.calendar_month_outlined),
                              hint: Text('Aucune', style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte3)),
                              items: _annees
                                  .map(
                                    (a) => DropdownMenuItem<int>(
                                      value: a['id'] as int,
                                      child: Text(a['libelle'] as String),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setStateDialog(() => anneeAcademiqueId = v),
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
                            style: ElevatedButton.styleFrom(
                              backgroundColor: SSMPalette.indigo,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
                            ),
                            onPressed: () async {
                              if (!estCollege &&
                                  (serieActuelle == null ||
                                      serieActuelle.isEmpty)) {
                                _afficherErreur(
                                  'Veuillez sélectionner ou saisir une série',
                                );
                                return;
                              }
                              try {
                                await ClasseService.creer(
                                  niveau: niveau,
                                  serie: estCollege ? null : serieActuelle,
                                  indice: indice,
                                  salle: salleController.text.isEmpty
                                      ? null
                                      : salleController.text,
                                  capaciteMax:
                                      int.tryParse(capaciteController.text) ??
                                          40,
                                  statut: 'active',
                                  cycle: cycle,
                                  professeurPrincipalId: professeurPrincipalId,
                                  anneeAcademiqueId: anneeAcademiqueId,
                                );
                                if (context.mounted) Navigator.pop(context);
                                _afficherSucces(
                                  'Classe "$nomGenere" créée avec succès',
                                );
                                _chargerListe();
                              } catch (e) {
                                _afficherErreur(
                                  e.toString().replaceAll('Exception: ', ''),
                                );
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
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: SSMPalette.indigo,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
