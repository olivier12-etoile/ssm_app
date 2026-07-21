import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import '../../services/utilisateur_service.dart';
import '../../widgets/ssm_widgets.dart';
import 'affectation_enseignant_screen.dart';
import 'fiche_utilisateur_screen.dart';

class GestionUtilisateursScreen extends StatefulWidget {
  const GestionUtilisateursScreen({super.key});

  @override
  State<GestionUtilisateursScreen> createState() =>
      _GestionUtilisateursScreenState();
}

class _GestionUtilisateursScreenState
    extends State<GestionUtilisateursScreen> {
  // ── Vue d'ensemble ──────────────────────────
  Map<String, dynamic>? _tableauDeBord;
  List<dynamic> _derniersInscrits = [];
  bool _chargementApercu = true;

  // ── Liste ────────────────────────────────────
  List<dynamic> _utilisateurs = [];
  int _pageActuelle = 1;
  int _dernierePage = 1;
  bool _chargementListe = true;
  String? _filtreRole;
  bool? _filtreActif;
  String _tri = 'created_at';
  String _recherche = '';
  Timer? _debounceRecherche;

  static const Map<String, String> _labelsTri = {
    'created_at':         'Date',
    'name':               'Nom',
    'role':               'Rôle',
    'derniere_connexion': 'Dernière connexion',
  };

  @override
  void initState() {
    super.initState();
    _chargerApercu();
    _chargerListe();
  }

  @override
  void dispose() {
    _debounceRecherche?.cancel();
    super.dispose();
  }

  Future<void> _chargerApercu() async {
    setState(() => _chargementApercu = true);
    try {
      final donnees  = await UtilisateurService.tableauDeBord();
      final derniers = await UtilisateurService.lister(tri: 'created_at', page: 1);
      setState(() {
        _tableauDeBord     = donnees;
        _derniersInscrits  = ((derniers['data'] as List?) ?? []).take(5).toList();
        _chargementApercu  = false;
      });
    } catch (e) {
      setState(() => _chargementApercu = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _chargerListe({int page = 1}) async {
    setState(() => _chargementListe = true);
    try {
      final resultat = await UtilisateurService.lister(
        role:      _filtreRole,
        actif:     _filtreActif,
        recherche: _recherche.isEmpty ? null : _recherche,
        tri:       _tri,
        page:      page,
      );
      setState(() {
        _utilisateurs     = resultat['data'] as List;
        _pageActuelle     = resultat['current_page'] as int;
        _dernierePage     = resultat['last_page'] as int;
        _chargementListe  = false;
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

  Color _couleurRole(String role) {
    switch (role) {
      case 'enseignant':  return const Color(0xFF1E3A8A); // indigo
      case 'censeur':     return const Color(0xFFD97706); // ambre
      case 'secretaire':  return const Color(0xFF0D9488); // teal
      case 'directeur':   return const Color(0xFF7C3AED); // violet
      default:            return const Color(0xFF94A3B8);
    }
  }

  IconData _iconeRole(String role) {
    switch (role) {
      case 'enseignant':  return Icons.school;
      case 'censeur':     return Icons.admin_panel_settings;
      case 'secretaire':  return Icons.assignment_ind;
      case 'directeur':   return Icons.workspace_premium;
      default:            return Icons.person;
    }
  }

  String _labelRole(String role) {
    switch (role) {
      case 'enseignant':  return 'Enseignant';
      case 'censeur':     return 'Censeur';
      case 'secretaire':  return 'Secrétaire';
      case 'directeur':   return 'Directeur';
      default:            return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text(
            'Gestion des utilisateurs',
            style: GoogleFonts.sora(fontWeight: FontWeight.w600, color: Colors.white),
          ),
          backgroundColor: const Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
          bottom: TabBar(
            indicatorColor: const Color(0xFFD97706),
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
            tabs: const [
              Tab(text: "Vue d'ensemble"),
              Tab(text: 'Liste des utilisateurs'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: const Color(0xFF1E3A8A),
          onPressed: () => _afficherDialogUtilisateur(),
          child: const Icon(Icons.add, color: Colors.white),
        ),
        body: TabBarView(
          children: [
            _ongletApercu(),
            _ongletListe(),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // ONGLET 1 — VUE D'ENSEMBLE
  // ══════════════════════════════════════════════════════

  Widget _ongletApercu() {
    if (_chargementApercu || _tableauDeBord == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final total      = _tableauDeBord!['total'] as int? ?? 0;
    final parRole     = _tableauDeBord!['par_role'] as Map<String, dynamic>? ?? {};
    final actifs      = _tableauDeBord!['actifs'] as int? ?? 0;
    final desactives  = _tableauDeBord!['desactives'] as int? ?? 0;

    final large = MediaQuery.of(context).size.width > 700;
    final grille = _grilleMiniCartes(parRole, total, actifs, desactives);
    final donut = _carteDonut(parRole);

    return RefreshIndicator(
      onRefresh: _chargerApercu,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── En-tête gradient ────────────────────
          Container(
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
                    Text(
                      'Utilisateurs',
                      style: GoogleFonts.sora(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$total membres au total',
                      style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$total', style: GoogleFonts.sora(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white)),
                      Text('utilisateurs', style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Mini-cartes stats + donut ───────────
          if (large)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: grille),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: donut),
              ],
            )
          else
            Column(
              children: [
                grille,
                const SizedBox(height: 20),
                donut,
              ],
            ),
          const SizedBox(height: 24),

          // ── Derniers inscrits ──────────────────
          SSMSectionTitre(titre: 'Derniers inscrits'),
          if (_derniersInscrits.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
              child: Text('Aucun utilisateur récent', style: GoogleFonts.inter(color: const Color(0xFF334155))),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                children: _derniersInscrits.map(_itemDernierInscrit).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _grilleMiniCartes(Map<String, dynamic> parRole, int total, int actifs, int desactives) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final largeurCarte = (constraints.maxWidth - 24) / 3;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _miniCarteStat('TOTAL', '$total', Icons.people, const Color(0xFF1E3A8A), largeurCarte),
            _miniCarteStat('ENSEIGNANTS', '${parRole['enseignant'] ?? 0}', Icons.school, const Color(0xFF0D9488), largeurCarte),
            _miniCarteStat('CENSEURS', '${parRole['censeur'] ?? 0}', Icons.verified_user, const Color(0xFFD97706), largeurCarte),
            _miniCarteStat('SECRÉTAIRES', '${parRole['secretaire'] ?? 0}', Icons.badge, const Color(0xFF7C3AED), largeurCarte),
            _miniCarteStat('ACTIFS', '$actifs', Icons.check_circle, const Color(0xFF16A34A), largeurCarte),
            _miniCarteStat('INACTIFS', '$desactives', Icons.block, const Color(0xFFDC2626), largeurCarte),
          ],
        );
      },
    );
  }

  Widget _miniCarteStat(String label, String valeur, IconData icone, Color couleur, double largeur) {
    return SizedBox(
      width: largeur,
      height: 80,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w600, letterSpacing: 0.3),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        valeur,
                        style: GoogleFonts.sora(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF1E3A8A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: couleur.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                  child: Icon(icone, color: couleur, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _carteDonut(Map<String, dynamic> parRole) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          Text('Répartition par rôle',
              style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
          const SizedBox(height: 8),
          SizedBox(height: 160, child: _donutRepartitionRole(parRole)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _legende('Directeur', const Color(0xFF1E3A8A)),
              _legende('Enseignants', const Color(0xFF0D9488)),
              _legende('Censeurs', const Color(0xFFD97706)),
              _legende('Secrétaires', const Color(0xFF7C3AED)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _itemDernierInscrit(dynamic u) {
    final role       = u['role'] as String;
    final couleur    = _couleurRole(role);
    final photoUrl   = u['photo_url'] as String?;
    final nomComplet = '${u['name']} ${u['prenom'] ?? ''}'.trim();
    final creeLe     = (u['created_at'] as String?)?.split('T').first;
    final actif      = u['actif'] == true;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: couleur.withValues(alpha: 0.15),
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            child: photoUrl == null ? Icon(_iconeRole(role), size: 16, color: couleur) : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nomComplet,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  creeLe != null ? '${_labelRole(role)} • $creeLe' : _labelRole(role),
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF334155)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SSMBadge(
            label: actif ? 'ACTIF' : 'INACTIF',
            couleur: actif ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
          ),
        ],
      ),
    );
  }

  Widget _donutRepartitionRole(Map<String, dynamic> parRole) {
    final directeur  = (parRole['directeur'] as num?)?.toInt() ?? 0;
    final enseignant = (parRole['enseignant'] as num?)?.toInt() ?? 0;
    final censeur    = (parRole['censeur'] as num?)?.toInt() ?? 0;
    final secretaire = (parRole['secretaire'] as num?)?.toInt() ?? 0;
    final total = directeur + enseignant + censeur + secretaire;

    if (total == 0) {
      return Center(child: Text('Aucune donnée', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF334155))));
    }

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: [
          if (directeur > 0)  PieChartSectionData(value: directeur.toDouble(),  color: const Color(0xFF1E3A8A), showTitle: false, radius: 24),
          if (enseignant > 0) PieChartSectionData(value: enseignant.toDouble(), color: const Color(0xFF0D9488), showTitle: false, radius: 24),
          if (censeur > 0)    PieChartSectionData(value: censeur.toDouble(),    color: const Color(0xFFD97706), showTitle: false, radius: 24),
          if (secretaire > 0) PieChartSectionData(value: secretaire.toDouble(), color: const Color(0xFF7C3AED), showTitle: false, radius: 24),
        ],
      ),
    );
  }

  Widget _legende(String label, Color couleur) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: couleur, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF334155))),
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  // ONGLET 2 — LISTE DES UTILISATEURS
  // ══════════════════════════════════════════════════════

  Widget _ongletListe() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: _barreRecherche(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _chipsFiltres(),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(child: _dropdownTri()),
              const SizedBox(width: 12),
              _boutonsExport(),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _chargementListe
              ? const Center(child: CircularProgressIndicator())
              : _utilisateurs.isEmpty
                  ? Center(child: Text('Aucun utilisateur trouvé', style: GoogleFonts.inter(color: const Color(0xFF334155))))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _utilisateurs.length,
                      itemBuilder: (context, index) =>
                          _carteUtilisateur(_utilisateurs[index] as Map<String, dynamic>),
                    ),
        ),
        _paginationBar(),
      ],
    );
  }

  Widget _barreRecherche() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(50),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 18, color: const Color(0xFF334155).withValues(alpha: 0.6)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  onChanged: _onRechercheChangee,
                  decoration: InputDecoration(
                    hintText: 'Rechercher...',
                    border: InputBorder.none,
                    isDense: true,
                    hintStyle: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF334155).withValues(alpha: 0.5)),
                  ),
                  style: GoogleFonts.inter(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chipsFiltres() {
    final chips = <Widget>[
      _chipFiltre('Tous', selectionne: _filtreRole == null && _filtreActif == null, onTap: () {
        setState(() { _filtreRole = null; _filtreActif = null; });
        _chargerListe();
      }),
      _chipFiltre('Enseignants', selectionne: _filtreRole == 'enseignant', onTap: () {
        setState(() { _filtreRole = 'enseignant'; _filtreActif = null; });
        _chargerListe();
      }),
      _chipFiltre('Censeurs', selectionne: _filtreRole == 'censeur', onTap: () {
        setState(() { _filtreRole = 'censeur'; _filtreActif = null; });
        _chargerListe();
      }),
      _chipFiltre('Secrétaires', selectionne: _filtreRole == 'secretaire', onTap: () {
        setState(() { _filtreRole = 'secretaire'; _filtreActif = null; });
        _chargerListe();
      }),
      _chipFiltre('Actifs', selectionne: _filtreActif == true, onTap: () {
        setState(() { _filtreActif = true; _filtreRole = null; });
        _chargerListe();
      }),
      _chipFiltre('Inactifs', selectionne: _filtreActif == false, onTap: () {
        setState(() { _filtreActif = false; _filtreRole = null; });
        _chargerListe();
      }),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips.map((c) => Padding(padding: const EdgeInsets.only(right: 8), child: c)).toList(),
      ),
    );
  }

  Widget _chipFiltre(String label, {required bool selectionne, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selectionne ? const Color(0xFF1E3A8A) : Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(50),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selectionne ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  Widget _dropdownTri() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(50),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _tri,
              isDense: true,
              isExpanded: true,
              icon: const Icon(Icons.sort, size: 18),
              items: _labelsTri.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: GoogleFonts.inter(fontSize: 13))))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _tri = v);
                _chargerListe();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _boutonsExport() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.picture_as_pdf),
          color: const Color(0xFFDC2626),
          tooltip: 'Exporter PDF',
          onPressed: _exporterPdf,
        ),
        IconButton(
          icon: const Icon(Icons.table_chart),
          color: const Color(0xFF16A34A),
          tooltip: 'Exporter Excel',
          onPressed: _exporterExcel,
        ),
        IconButton(
          icon: const Icon(Icons.upload_file),
          color: const Color(0xFFD97706),
          tooltip: 'Importer',
          onPressed: _importerExcel,
        ),
      ],
    );
  }

  Future<void> _exporterPdf() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Génération du PDF...')));
      final chemin = await UtilisateurService.exporterPdf(role: _filtreRole, actif: _filtreActif);
      await OpenFile.open(chemin);
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _exporterExcel() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Génération du fichier Excel...')));
      final chemin = await UtilisateurService.exporterExcel(role: _filtreRole);
      await OpenFile.open(chemin);
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _importerExcel() async {
    final resultat = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );
    if (resultat == null || resultat.files.single.path == null) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Import en cours...')));
      final fichier = File(resultat.files.single.path!);
      final rapport = await UtilisateurService.importerExcel(fichier);
      final crees   = (rapport['crees']   as List?)?.length ?? 0;
      final ignores = (rapport['ignores'] as List?)?.length ?? 0;
      final erreurs = (rapport['erreurs'] as List?)?.length ?? 0;
      _afficherSucces('$crees créé(s), $ignores ignoré(s), $erreurs erreur(s)');
      _chargerListe(page: _pageActuelle);
      _chargerApercu();
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Widget _carteUtilisateur(Map<String, dynamic> u) {
    final role       = u['role'] as String;
    final actif      = u['actif'] == true;
    final nomComplet = '${u['name']} ${u['prenom'] ?? ''}'.trim();
    final photoUrl   = u['photo_url'] as String?;
    final couleur    = _couleurRole(role);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FicheUtilisateurScreen(userId: u['id'] as int),
        ),
      ).then((_) {
        _chargerListe(page: _pageActuelle);
        _chargerApercu();
      }),
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.65),
              border: Border(
                top:    BorderSide(color: Colors.white.withValues(alpha: 0.7)),
                right:  BorderSide(color: Colors.white.withValues(alpha: 0.7)),
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
                left:   BorderSide(color: couleur, width: 4),
              ),
              boxShadow: [
                BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 6)),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [couleur, couleur.withValues(alpha: 0.7)]),
                    image: photoUrl != null
                        ? DecorationImage(image: NetworkImage(photoUrl), fit: BoxFit.cover)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: photoUrl == null
                      ? Text(
                          (u['name'] as String).isNotEmpty ? (u['name'] as String).substring(0, 1).toUpperCase() : '?',
                          style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nomComplet, style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                      if (u['fonction'] != null) ...[
                        const SizedBox(height: 2),
                        Text(u['fonction'] as String, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF334155))),
                      ],
                      const SizedBox(height: 2),
                      Text(u['email'] as String, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                      if (u['telephone'] != null) ...[
                        const SizedBox(height: 2),
                        Text(u['telephone'] as String, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        SSMBadge(label: _labelRole(role), couleur: couleur),
                        const SizedBox(width: 6),
                        SSMBadge(
                          label: actif ? 'ACTIF' : 'INACTIF',
                          couleur: actif ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                        ),
                      ],
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFF334155)),
                      onSelected: (valeur) => _gererActionMenu(valeur, u),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'modifier',
                          child: Row(children: [
                            Icon(Icons.edit, color: Color(0xFF1E3A8A), size: 18),
                            SizedBox(width: 8),
                            Text('Modifier'),
                          ]),
                        ),
                        if (role == 'enseignant')
                          const PopupMenuItem(
                            value: 'affectations',
                            child: Row(children: [
                              Icon(Icons.assignment, color: Color(0xFF0D9488), size: 18),
                              SizedBox(width: 8),
                              Text('Voir affectations'),
                            ]),
                          ),
                        const PopupMenuItem(
                          value: 'reset',
                          child: Row(children: [
                            Icon(Icons.lock_reset, color: Colors.orange, size: 18),
                            SizedBox(width: 8),
                            Text('Réinitialiser mot de passe'),
                          ]),
                        ),
                        PopupMenuItem(
                          value: actif ? 'desactiver' : 'reactiver',
                          child: Row(children: [
                            Icon(actif ? Icons.block : Icons.check_circle,
                                color: actif ? const Color(0xFFDC2626) : const Color(0xFF16A34A), size: 18),
                            const SizedBox(width: 8),
                            Text(actif ? 'Désactiver' : 'Réactiver'),
                          ]),
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
      ),
    );
  }

  Future<void> _gererActionMenu(String action, Map<String, dynamic> u) async {
    final id  = u['id'] as int;
    final nom = '${u['name']} ${u['prenom'] ?? ''}'.trim();

    switch (action) {
      case 'modifier':
        _afficherDialogUtilisateur(utilisateurExistant: u);
        break;
      case 'affectations':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AffectationEnseignantScreen(userId: id, userName: nom),
          ),
        );
        break;
      case 'reset':
        await _reinitialiserMotDePasse(id);
        break;
      case 'desactiver':
        await _confirmerDesactivation(id, nom);
        break;
      case 'reactiver':
        try {
          await UtilisateurService.reactiver(id);
          _afficherSucces('Utilisateur réactivé');
          _chargerListe(page: _pageActuelle);
          _chargerApercu();
        } catch (e) {
          _afficherErreur(e.toString().replaceAll('Exception: ', ''));
        }
        break;
    }
  }

  Future<void> _confirmerDesactivation(int id, String nom) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber, color: Color(0xFFD97706)),
            const SizedBox(width: 8),
            Expanded(child: Text('Désactiver $nom ?', style: GoogleFonts.sora(fontWeight: FontWeight.w700))),
          ],
        ),
        content: Text('Cet utilisateur ne pourra plus se connecter.', style: GoogleFonts.inter()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            child: const Text('Désactiver'),
          ),
        ],
      ),
    );

    if (confirme == true) {
      try {
        await UtilisateurService.desactiver(id);
        _afficherSucces('Utilisateur désactivé');
        _chargerListe(page: _pageActuelle);
        _chargerApercu();
      } catch (e) {
        _afficherErreur(e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> _reinitialiserMotDePasse(int id) async {
    try {
      final resultat = await UtilisateurService.reinitialiserMotDePasse(id);
      if (!mounted) return;
      _afficherDialogMotDePasse(
        resultat['mot_de_passe'] as String,
        titre: 'Nouveau mot de passe temporaire',
      );
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _afficherDialogMotDePasse(String motDePasse, {required String titre, bool succesCreation = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (succesCreation) ...[
              const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 64),
              const SizedBox(height: 12),
              Text('Compte créé avec succès !',
                  style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
              const SizedBox(height: 16),
            ] else
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(titre, style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
              ),
            Text('Mot de passe temporaire :', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF334155))),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
              alignment: Alignment.center,
              child: Text(
                motDePasse,
                style: GoogleFonts.jetBrainsMono(fontSize: 24, fontWeight: FontWeight.w700, color: const Color(0xFF1E3A8A)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Communiquez ce mot de passe à l\'utilisateur.',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF334155)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: motDePasse));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mot de passe copié')));
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copier'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _paginationBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.8))),
      ),
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
  // DIALOG CRÉER / MODIFIER UN UTILISATEUR
  // ══════════════════════════════════════════════════════

  Future<void> _afficherDialogUtilisateur({Map<String, dynamic>? utilisateurExistant}) async {
    final modification = utilisateurExistant != null;

    final nomController        = TextEditingController(text: utilisateurExistant?['name'] as String? ?? '');
    final prenomController     = TextEditingController(text: utilisateurExistant?['prenom'] as String? ?? '');
    final emailController      = TextEditingController(text: utilisateurExistant?['email'] as String? ?? '');
    final telephoneController  = TextEditingController(text: utilisateurExistant?['telephone'] as String? ?? '');
    final adresseController    = TextEditingController(text: utilisateurExistant?['adresse'] as String? ?? '');
    final fonctionController   = TextEditingController(text: utilisateurExistant?['fonction'] as String? ?? '');
    String? sexe    = utilisateurExistant?['sexe'] as String?;
    String role     = utilisateurExistant?['role'] as String? ?? 'enseignant';
    File? photo;
    final photoUrlExistante = utilisateurExistant?['photo_url'] as String?;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460, maxHeight: 640),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      modification ? "Modifier l'utilisateur" : 'Nouvel utilisateur',
                      style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: GestureDetector(
                                onTap: () async {
                                  final picker = ImagePicker();
                                  final image = await picker.pickImage(
                                    source: ImageSource.gallery,
                                    maxWidth: 800,
                                    maxHeight: 800,
                                    imageQuality: 80,
                                  );
                                  if (image != null) setStateDialog(() => photo = File(image.path));
                                },
                                child: Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 44,
                                      backgroundColor: const Color(0xFF1E3A8A).withValues(alpha: 0.15),
                                      backgroundImage: photo != null
                                          ? FileImage(photo!)
                                          : (photoUrlExistante != null
                                              ? NetworkImage(photoUrlExistante) as ImageProvider
                                              : null),
                                      child: (photo == null && photoUrlExistante == null)
                                          ? const Icon(Icons.person, size: 40, color: Color(0xFF1E3A8A))
                                          : null,
                                    ),
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(color: Color(0xFFD97706), shape: BoxShape.circle),
                                        child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: nomController,
                              decoration: const InputDecoration(labelText: 'Nom *', prefixIcon: Icon(Icons.person)),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: prenomController,
                              decoration: const InputDecoration(labelText: 'Prénom *', prefixIcon: Icon(Icons.person_outline)),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Text('Sexe :', style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF334155))),
                                const SizedBox(width: 12),
                                SegmentedButton<String>(
                                  segments: const [
                                    ButtonSegment(value: 'M', label: Text('M')),
                                    ButtonSegment(value: 'F', label: Text('F')),
                                  ],
                                  selected: sexe != null ? {sexe!} : {},
                                  emptySelectionAllowed: true,
                                  onSelectionChanged: (s) => setStateDialog(() => sexe = s.isEmpty ? null : s.first),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(labelText: 'Email *', prefixIcon: Icon(Icons.email)),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: telephoneController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(labelText: 'Téléphone', prefixIcon: Icon(Icons.phone)),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: adresseController,
                              decoration: const InputDecoration(labelText: 'Adresse', prefixIcon: Icon(Icons.location_on)),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: fonctionController,
                              decoration: const InputDecoration(labelText: 'Fonction', prefixIcon: Icon(Icons.work)),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: role,
                              decoration: const InputDecoration(labelText: 'Rôle *', prefixIcon: Icon(Icons.badge)),
                              items: const [
                                DropdownMenuItem(value: 'enseignant', child: Text('Enseignant')),
                                DropdownMenuItem(value: 'censeur', child: Text('Censeur')),
                                DropdownMenuItem(value: 'secretaire', child: Text('Secrétaire')),
                              ],
                              onChanged: (v) => setStateDialog(() => role = v ?? role),
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
                              if (nomController.text.isEmpty ||
                                  prenomController.text.isEmpty ||
                                  emailController.text.isEmpty) {
                                _afficherErreur('Veuillez remplir les champs obligatoires');
                                return;
                              }
                              try {
                                if (modification) {
                                  await UtilisateurService.modifier(
                                    utilisateurExistant['id'] as int,
                                    nom:       nomController.text,
                                    prenom:    prenomController.text,
                                    email:     emailController.text,
                                    telephone: telephoneController.text.isEmpty ? null : telephoneController.text,
                                    adresse:   adresseController.text.isEmpty ? null : adresseController.text,
                                    fonction:  fonctionController.text.isEmpty ? null : fonctionController.text,
                                    role:      role,
                                    photo:     photo,
                                  );
                                  if (context.mounted) Navigator.pop(context);
                                  _afficherSucces('Utilisateur modifié avec succès');
                                } else {
                                  final resultat = await UtilisateurService.creer(
                                    nom:       nomController.text,
                                    prenom:    prenomController.text,
                                    email:     emailController.text,
                                    role:      role,
                                    sexe:      sexe,
                                    telephone: telephoneController.text.isEmpty ? null : telephoneController.text,
                                    adresse:   adresseController.text.isEmpty ? null : adresseController.text,
                                    fonction:  fonctionController.text.isEmpty ? null : fonctionController.text,
                                    photo:     photo,
                                  );
                                  if (context.mounted) Navigator.pop(context);
                                  _afficherDialogMotDePasse(
                                    resultat['mot_de_passe'] as String,
                                    titre: 'Compte créé !',
                                    succesCreation: true,
                                  );
                                }
                                _chargerApercu();
                                _chargerListe(page: _pageActuelle);
                              } catch (e) {
                                _afficherErreur(e.toString().replaceAll('Exception: ', ''));
                              }
                            },
                            child: Text(modification ? 'Enregistrer' : "Créer l'utilisateur"),
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
    prenomController.dispose();
    emailController.dispose();
    telephoneController.dispose();
    adresseController.dispose();
    fonctionController.dispose();
  }
}
