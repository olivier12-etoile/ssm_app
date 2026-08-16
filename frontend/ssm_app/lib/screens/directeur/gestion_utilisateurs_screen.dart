import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import '../../models/utilisateur.dart';
import '../../services/auth_service.dart';
import '../../services/utilisateur_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_avatar.dart';
import '../../widgets/ssm/ssm_data_table.dart';
import '../../widgets/ssm/ssm_page_scaffold.dart';
import '../../widgets/ssm/ssm_panel.dart';
import '../../widgets/ssm/ssm_pill.dart';
import '../../widgets/ssm/ssm_quick_action_button.dart';
import '../../widgets/ssm/ssm_sidebar.dart';
import '../../widgets/ssm/ssm_stat_card.dart';
import 'affectation_enseignant_screen.dart';
import 'fiche_utilisateur_screen.dart';

Color _couleurRole(String role) {
  switch (role) {
    case 'enseignant':
      return SSMPalette.indigo;
    case 'censeur':
      return SSMPalette.ambre;
    case 'secretaire':
      return SSMPalette.teal;
    case 'directeur':
      return SSMPalette.rouge;
    default:
      return SSMPalette.texte3;
  }
}

String _labelRole(String role) {
  switch (role) {
    case 'enseignant':
      return 'Enseignant';
    case 'censeur':
      return 'Censeur';
    case 'secretaire':
      return 'Secrétaire';
    case 'directeur':
      return 'Directeur';
    default:
      return role;
  }
}

enum _OngletUtilisateurs { tableauDeBord, liste }

class GestionUtilisateursScreen extends StatefulWidget {
  const GestionUtilisateursScreen({super.key});

  @override
  State<GestionUtilisateursScreen> createState() =>
      _GestionUtilisateursScreenState();
}

class _GestionUtilisateursScreenState
    extends State<GestionUtilisateursScreen> {
  _OngletUtilisateurs _onglet = _OngletUtilisateurs.tableauDeBord;

  Utilisateur? _utilisateur;

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
    AuthService.getUtilisateur().then((u) {
      if (mounted) setState(() => _utilisateur = u);
    });
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
    if (route == '/directeur/utilisateurs') return;
    Navigator.pushNamed(context, route);
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
    final total = _tableauDeBord?['total'] as int?;
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
          SSMNavItem(
            icone: Icons.people_alt_outlined,
            label: 'Utilisateurs',
            route: '/directeur/utilisateurs',
            badge: (!_chargementApercu && (total ?? 0) > 0) ? total : null,
          ),
          const SSMNavItem(icone: Icons.class_outlined, label: 'Classes', route: '/directeur/classes'),
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
      routeActuelle: '/directeur/utilisateurs',
      onNavigate: (route) => _naviguer(context, route),
      onProfilTap: () => Navigator.pushNamed(context, '/profil'),
      breadcrumb: 'Accueil',
      breadcrumbActuel: 'Utilisateurs',
      floatingActionButton: _onglet == _OngletUtilisateurs.liste
          ? FloatingActionButton.extended(
              backgroundColor: SSMPalette.indigo,
              foregroundColor: Colors.white,
              onPressed: () => _afficherDialogUtilisateur(),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Nouvel utilisateur'),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Utilisateurs',
            style: GoogleFonts.sora(fontSize: 19, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
          ),
          const SizedBox(height: 12),
          _segments(),
          const SizedBox(height: 16),
          if (_onglet == _OngletUtilisateurs.tableauDeBord) _ongletApercu() else _ongletListe(),
        ],
      ),
    );
  }

  // ── Sélecteur d'onglet ──
  Widget _segments() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(SSMRayons.moyen)),
      child: Row(
        children: [
          Expanded(child: _segment("📊 Vue d'ensemble", _OngletUtilisateurs.tableauDeBord)),
          Expanded(child: _segment('👥 Liste des utilisateurs', _OngletUtilisateurs.liste)),
        ],
      ),
    );
  }

  Widget _segment(String label, _OngletUtilisateurs valeur) {
    final actif = _onglet == valeur;
    return GestureDetector(
      onTap: () => setState(() => _onglet = valeur),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: actif ? SSMPalette.blanc : Colors.transparent,
          borderRadius: BorderRadius.circular(SSMRayons.petit),
          boxShadow: actif ? SSMOmbres.legere : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: actif ? FontWeight.w600 : FontWeight.w400,
            color: actif ? SSMPalette.indigo : SSMPalette.texte2,
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // ONGLET 1 — VUE D'ENSEMBLE
  // ══════════════════════════════════════════════════════

  Widget _ongletApercu() {
    if (_chargementApercu || _tableauDeBord == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator(color: SSMPalette.indigo)),
      );
    }

    final total      = _tableauDeBord!['total'] as int? ?? 0;
    final parRole    = _tableauDeBord!['par_role'] as Map<String, dynamic>? ?? {};
    final actifs     = _tableauDeBord!['actifs'] as int? ?? 0;
    final desactives = _tableauDeBord!['desactives'] as int? ?? 0;

    final cartes = <_CarteStat>[
      _CarteStat('TOTAL', '$total', Icons.people, SSMPalette.indigo),
      _CarteStat('ENSEIGNANTS', '${parRole['enseignant'] ?? 0}', Icons.school, _couleurRole('enseignant')),
      _CarteStat('CENSEURS', '${parRole['censeur'] ?? 0}', Icons.verified_user, _couleurRole('censeur')),
      _CarteStat('SECRÉTAIRES', '${parRole['secretaire'] ?? 0}', Icons.badge, _couleurRole('secretaire')),
      _CarteStat('ACTIFS', '$actifs', Icons.check_circle, SSMPalette.teal),
      _CarteStat('INACTIFS', '$desactives', Icons.block, SSMPalette.rouge),
    ];

    return RefreshIndicator(
      onRefresh: _chargerApercu,
      color: SSMPalette.indigo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$total utilisateurs · $actifs actifs · $desactives inactifs',
            style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, contraintes) {
            final large = contraintes.maxWidth >= 760;
            final grille = LayoutBuilder(builder: (context, c) {
              final colonnes = c.maxWidth >= 560 ? 3 : (c.maxWidth >= 360 ? 2 : 1);
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
                  final c2 = cartes[i];
                  return SSMStatCard(icone: c2.icone, couleur: c2.couleur, valeur: c2.valeur, label: c2.label);
                },
              );
            });
            final donut = _carteDonut(parRole);

            return large
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: grille),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: donut),
                    ],
                  )
                : Column(children: [grille, const SizedBox(height: 16), donut]);
          }),
          const SizedBox(height: 20),
          SSMPanel(
            titre: 'Derniers inscrits',
            padding: EdgeInsets.zero,
            child: _derniersInscrits.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Aucun utilisateur récent', style: GoogleFonts.inter(color: SSMPalette.texte3)),
                  )
                : Column(children: _derniersInscrits.map((u) => _itemDernierInscrit(u as Map<String, dynamic>)).toList()),
          ),
        ],
      ),
    );
  }

  Widget _carteDonut(Map<String, dynamic> parRole) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SSMPalette.blanc,
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        border: Border.all(color: SSMPalette.bordure),
      ),
      child: Column(
        children: [
          Text('Répartition par rôle',
              style: GoogleFonts.sora(fontSize: 12.5, fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
          const SizedBox(height: 8),
          SizedBox(height: 150, child: _donutRepartitionRole(parRole)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _legende('Directeur', _couleurRole('directeur')),
              _legende('Enseignants', _couleurRole('enseignant')),
              _legende('Censeurs', _couleurRole('censeur')),
              _legende('Secrétaires', _couleurRole('secretaire')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _itemDernierInscrit(Map<String, dynamic> u) {
    final role       = u['role'] as String;
    final photoUrl   = u['photo_url'] as String?;
    final nomComplet = '${u['name']} ${u['prenom'] ?? ''}'.trim();
    final creeLe     = (u['created_at'] as String?)?.split('T').first;
    final actif      = u['actif'] == true;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SSMAvatar(nom: nomComplet, photoUrl: photoUrl, couleur: _couleurRole(role), rayon: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nomComplet,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: SSMPalette.texte1),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  creeLe != null ? '${_labelRole(role)} · $creeLe' : _labelRole(role),
                  style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SSMPill.couleur(label: actif ? 'Actif' : 'Inactif', couleur: actif ? SSMPalette.teal : SSMPalette.rouge),
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
      return Center(child: Text('Aucune donnée', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte3)));
    }

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 38,
        sections: [
          if (directeur > 0)  PieChartSectionData(value: directeur.toDouble(),  color: _couleurRole('directeur'),  showTitle: false, radius: 22),
          if (enseignant > 0) PieChartSectionData(value: enseignant.toDouble(), color: _couleurRole('enseignant'), showTitle: false, radius: 22),
          if (censeur > 0)    PieChartSectionData(value: censeur.toDouble(),    color: _couleurRole('censeur'),    showTitle: false, radius: 22),
          if (secretaire > 0) PieChartSectionData(value: secretaire.toDouble(), color: _couleurRole('secretaire'), showTitle: false, radius: 22),
        ],
      ),
    );
  }

  Widget _legende(String label, Color couleur) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: couleur, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.inter(fontSize: 11.5, color: SSMPalette.texte2)),
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  // ONGLET 2 — LISTE DES UTILISATEURS
  // ══════════════════════════════════════════════════════

  Widget _ongletListe() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _barreRecherche(),
        const SizedBox(height: 10),
        SizedBox(height: 36, child: _chipsFiltres()),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _dropdownTri()),
            const SizedBox(width: 8),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SSMQuickActionButton(
              icone: Icons.person_add_alt_1,
              label: 'Ajouter',
              variante: SSMActionVariante.primaire,
              onTap: () => _afficherDialogUtilisateur(),
            ),
            SSMQuickActionButton(
              icone: Icons.picture_as_pdf,
              label: 'PDF',
              variante: SSMActionVariante.gris,
              onTap: _exporterPdf,
            ),
            SSMQuickActionButton(
              icone: Icons.table_chart,
              label: 'Excel',
              variante: SSMActionVariante.teal,
              onTap: _exporterExcel,
            ),
            SSMQuickActionButton(
              icone: Icons.upload_file,
              label: 'Importer',
              variante: SSMActionVariante.ambre,
              onTap: _importerExcel,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_chargementListe)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator(color: SSMPalette.indigo)),
          )
        else if (_utilisateurs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Text('Aucun utilisateur trouvé', style: GoogleFonts.inter(color: SSMPalette.texte3))),
          )
        else
          LayoutBuilder(builder: (context, contraintes) {
            return contraintes.maxWidth >= 760 ? _tableUtilisateurs() : _listeCartes();
          }),
        const SizedBox(height: 12),
        _paginationBar(),
      ],
    );
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
          hintText: 'Rechercher un utilisateur...',
          hintStyle: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte3),
          prefixIcon: const Icon(Icons.search, size: 18, color: SSMPalette.texte3),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
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

    return ListView(
      scrollDirection: Axis.horizontal,
      children: chips.map((c) => Padding(padding: const EdgeInsets.only(right: 8), child: c)).toList(),
    );
  }

  Widget _chipFiltre(String label, {required bool selectionne, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selectionne ? SSMPalette.indigo : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(SSMRayons.pilule),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selectionne ? Colors.white : SSMPalette.texte2,
          ),
        ),
      ),
    );
  }

  Widget _dropdownTri() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(SSMRayons.moyen),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _tri,
          isDense: true,
          isExpanded: true,
          icon: const Icon(Icons.sort, size: 18, color: SSMPalette.texte3),
          style: GoogleFonts.inter(fontSize: 12.5, color: SSMPalette.texte1),
          items: _labelsTri.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text('Trier par : ${e.value}')))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() => _tri = v);
            _chargerListe();
          },
        ),
      ),
    );
  }

  Future<void> _exporterPdf() async {
    try {
      final chemin = await UtilisateurService.exporterPdf(role: _filtreRole, actif: _filtreActif);
      await OpenFile.open(chemin);
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _exporterExcel() async {
    try {
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

  // ── Vue desktop large : tableau ──
  Widget _tableUtilisateurs() {
    return SSMDataTable(
      colonnes: const [
        SSMDataColumn(''),
        SSMDataColumn('Utilisateur'),
        SSMDataColumn('Rôle'),
        SSMDataColumn('Statut'),
        SSMDataColumn('Actions'),
      ],
      onLigneTap: (i) => _ouvrirFiche(_utilisateurs[i] as Map<String, dynamic>),
      lignes: [
        for (final u in _utilisateurs) _ligneUtilisateur(u as Map<String, dynamic>),
      ],
    );
  }

  List<Widget> _ligneUtilisateur(Map<String, dynamic> u) {
    final role       = u['role'] as String;
    final actif      = u['actif'] == true;
    final nomComplet = '${u['name']} ${u['prenom'] ?? ''}'.trim();
    final photoUrl   = u['photo_url'] as String?;
    final couleur    = _couleurRole(role);

    return [
      SSMAvatar(nom: nomComplet, photoUrl: photoUrl, couleur: couleur, rayon: 16),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(nomComplet, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
          const SizedBox(height: 2),
          Text(u['email'] as String, style: GoogleFonts.inter(fontSize: 10.5, color: SSMPalette.texte3)),
        ],
      ),
      SSMPill.couleur(label: _labelRole(role), couleur: couleur),
      SSMPill.couleur(label: actif ? 'Actif' : 'Inactif', couleur: actif ? SSMPalette.teal : SSMPalette.rouge),
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 18, color: SSMPalette.texte3),
        onSelected: (valeur) => _gererActionMenu(valeur, u),
        itemBuilder: (context) => _entreesMenuAction(role, actif),
      ),
    ];
  }

  // ── Vue mobile/étroite : cartes ──
  Widget _listeCartes() {
    return Column(children: _utilisateurs.map((u) => _carteUtilisateur(u as Map<String, dynamic>)).toList());
  }

  Widget _carteUtilisateur(Map<String, dynamic> u) {
    final role       = u['role'] as String;
    final actif      = u['actif'] == true;
    final nomComplet = '${u['name']} ${u['prenom'] ?? ''}'.trim();
    final photoUrl   = u['photo_url'] as String?;
    final couleur    = _couleurRole(role);

    return Material(
      color: SSMPalette.blanc,
      borderRadius: BorderRadius.circular(SSMRayons.grand),
      child: InkWell(
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        onTap: () => _ouvrirFiche(u),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SSMRayons.grand),
            border: Border(
              top: BorderSide(color: SSMPalette.bordure),
              right: BorderSide(color: SSMPalette.bordure),
              bottom: BorderSide(color: SSMPalette.bordure),
              left: BorderSide(color: couleur, width: 3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SSMAvatar(nom: nomComplet, photoUrl: photoUrl, couleur: couleur, rayon: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nomComplet, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
                    if (u['fonction'] != null)
                      Text(u['fonction'] as String, style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte3)),
                    Text(u['email'] as String, style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte3)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        SSMPill.couleur(label: _labelRole(role), couleur: couleur),
                        SSMPill.couleur(label: actif ? 'Actif' : 'Inactif', couleur: actif ? SSMPalette.teal : SSMPalette.rouge),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20, color: SSMPalette.texte3),
                onSelected: (valeur) => _gererActionMenu(valeur, u),
                itemBuilder: (context) => _entreesMenuAction(role, actif),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _ouvrirFiche(Map<String, dynamic> u) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FicheUtilisateurScreen(userId: u['id'] as int)),
    ).then((_) {
      _chargerListe(page: _pageActuelle);
      _chargerApercu();
    });
  }

  List<PopupMenuEntry<String>> _entreesMenuAction(String role, bool actif) {
    return [
      const PopupMenuItem(
        value: 'modifier',
        child: Row(children: [
          Icon(Icons.edit, color: SSMPalette.indigo, size: 18),
          SizedBox(width: 8),
          Text('Modifier'),
        ]),
      ),
      if (role == 'enseignant')
        const PopupMenuItem(
          value: 'affectations',
          child: Row(children: [
            Icon(Icons.assignment, color: SSMPalette.teal, size: 18),
            SizedBox(width: 8),
            Text('Voir affectations'),
          ]),
        ),
      const PopupMenuItem(
        value: 'reset',
        child: Row(children: [
          Icon(Icons.lock_reset, color: SSMPalette.ambre, size: 18),
          SizedBox(width: 8),
          Text('Réinitialiser mot de passe'),
        ]),
      ),
      PopupMenuItem(
        value: actif ? 'desactiver' : 'reactiver',
        child: Row(children: [
          Icon(actif ? Icons.block : Icons.check_circle,
              color: actif ? SSMPalette.rouge : SSMPalette.teal, size: 18),
          const SizedBox(width: 8),
          Text(actif ? 'Désactiver' : 'Réactiver'),
        ]),
      ),
    ];
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
        backgroundColor: SSMPalette.blanc,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber, color: SSMPalette.ambre),
            const SizedBox(width: 8),
            Expanded(child: Text('Désactiver $nom ?', style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: SSMPalette.indigo))),
          ],
        ),
        content: Text('Cet utilisateur ne pourra plus se connecter.', style: GoogleFonts.inter(color: SSMPalette.texte2)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Annuler', style: GoogleFonts.inter(color: SSMPalette.texte2))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.rouge, foregroundColor: Colors.white, elevation: 0),
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
        backgroundColor: SSMPalette.blanc,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (succesCreation) ...[
              const Icon(Icons.check_circle, color: SSMPalette.teal, size: 56),
              const SizedBox(height: 12),
              Text('Compte créé avec succès !',
                  style: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w700, color: SSMPalette.indigo), textAlign: TextAlign.center),
              const SizedBox(height: 16),
            ] else
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(titre, style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.indigo), textAlign: TextAlign.center),
              ),
            Text('Mot de passe temporaire :', style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(SSMRayons.moyen), border: Border.all(color: SSMPalette.bordure)),
              alignment: Alignment.center,
              child: Text(
                motDePasse,
                style: GoogleFonts.jetBrainsMono(fontSize: 22, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Communiquez ce mot de passe à l'utilisateur.",
              style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: motDePasse));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Mot de passe copié')),
              );
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copier'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.indigo, foregroundColor: Colors.white, elevation: 0),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _paginationBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          onPressed: _pageActuelle > 1 ? () => _chargerListe(page: _pageActuelle - 1) : null,
          child: const Text('< Précédent'),
        ),
        const SizedBox(width: 8),
        Text('Page $_pageActuelle sur $_dernierePage', style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte3)),
        const SizedBox(width: 8),
        TextButton(
          onPressed: _pageActuelle < _dernierePage ? () => _chargerListe(page: _pageActuelle + 1) : null,
          child: const Text('Suivant >'),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  // DIALOG CRÉER / MODIFIER UN UTILISATEUR
  // ══════════════════════════════════════════════════════

  InputDecoration _decorationChamp(String label, {IconData? icone}) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2),
      prefixIcon: icone != null ? Icon(icone, size: 19, color: SSMPalette.texte3) : null,
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
            backgroundColor: SSMPalette.blanc,
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
                      style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
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
                                      backgroundColor: SSMPalette.indigo.withValues(alpha: 0.15),
                                      backgroundImage: photo != null
                                          ? FileImage(photo!)
                                          : (photoUrlExistante != null
                                              ? NetworkImage(photoUrlExistante) as ImageProvider
                                              : null),
                                      child: (photo == null && photoUrlExistante == null)
                                          ? Icon(Icons.person, size: 40, color: SSMPalette.indigo)
                                          : null,
                                    ),
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(color: SSMPalette.ambre, shape: BoxShape.circle),
                                        child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextField(controller: nomController, decoration: _decorationChamp('Nom *', icone: Icons.person)),
                            const SizedBox(height: 12),
                            TextField(controller: prenomController, decoration: _decorationChamp('Prénom *', icone: Icons.person_outline)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Text('Sexe :', style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2)),
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
                              decoration: _decorationChamp('Email *', icone: Icons.email_outlined),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: telephoneController,
                              keyboardType: TextInputType.phone,
                              decoration: _decorationChamp('Téléphone', icone: Icons.phone_outlined),
                            ),
                            const SizedBox(height: 12),
                            TextField(controller: adresseController, decoration: _decorationChamp('Adresse', icone: Icons.location_on_outlined)),
                            const SizedBox(height: 12),
                            TextField(controller: fonctionController, decoration: _decorationChamp('Fonction', icone: Icons.work_outline)),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: role,
                              decoration: _decorationChamp('Rôle *', icone: Icons.badge_outlined),
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

class _CarteStat {
  final String label;
  final String valeur;
  final IconData icone;
  final Color couleur;

  const _CarteStat(this.label, this.valeur, this.icone, this.couleur);
}
