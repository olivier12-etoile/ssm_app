import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/utilisateur.dart';
import '../../services/auth_service.dart';
import '../../services/matiere_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_data_table.dart';
import '../../widgets/ssm/ssm_page_scaffold.dart';
import '../../widgets/ssm/ssm_pill.dart';
import '../../widgets/ssm/ssm_sidebar.dart';
import '../../widgets/ssm/ssm_stat_card.dart';

const List<Color> _couleursMatiere = [
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

const Color _couleurParDefaut = SSMPalette.indigo;

Color _couleurMatiere(dynamic matiere) {
  final couleur = matiere['couleur'] as String?;
  if (couleur == null || couleur.isEmpty) return _couleurParDefaut;
  try {
    return Color(int.parse(couleur.replaceAll('#', '0xFF')));
  } catch (_) {
    return _couleurParDefaut;
  }
}

enum _OngletMatieres { liste, statistiques }

class GestionMatieresScreen extends StatefulWidget {
  const GestionMatieresScreen({super.key});

  @override
  State<GestionMatieresScreen> createState() => _GestionMatieresScreenState();
}

class _GestionMatieresScreenState extends State<GestionMatieresScreen> {
  _OngletMatieres _onglet = _OngletMatieres.liste;

  Utilisateur? _utilisateur;

  List<dynamic> _matieres = [];
  bool _chargementListe = true;
  String _recherche = '';
  Timer? _debounceRecherche;
  final _rechercheController = TextEditingController();

  Map<String, dynamic>? _statistiques;
  bool _chargementStats = true;

  @override
  void initState() {
    super.initState();
    AuthService.getUtilisateur().then((u) {
      if (mounted) setState(() => _utilisateur = u);
    });
    _chargerListe();
    _chargerStatistiques();
  }

  @override
  void dispose() {
    _debounceRecherche?.cancel();
    _rechercheController.dispose();
    super.dispose();
  }

  Future<void> _chargerListe() async {
    setState(() => _chargementListe = true);
    try {
      final matieres = await MatiereService.listerMatieres(
        recherche: _recherche.isEmpty ? null : _recherche,
      );
      setState(() {
        _matieres = matieres;
        _chargementListe = false;
      });
    } catch (e) {
      setState(() => _chargementListe = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _chargerStatistiques() async {
    setState(() => _chargementStats = true);
    try {
      final stats = await MatiereService.statistiques();
      setState(() {
        _statistiques = stats;
        _chargementStats = false;
      });
    } catch (e) {
      setState(() => _chargementStats = false);
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
    if (route == '/directeur/matieres') return;
    Navigator.pushNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    return SSMPageScaffold(
      nomEcole: _utilisateur?.codeEcole ?? 'Mon établissement',
      codeEcole: _utilisateur?.codeEcole ?? '—',
      nomUtilisateur: _utilisateur?.nom ?? '…',
      role: _libelleRole(_utilisateur?.role),
      sections: _sections(),
      routeActuelle: '/directeur/matieres',
      onNavigate: (route) => _naviguer(context, route),
      onProfilTap: () => Navigator.pushNamed(context, '/profil'),
      breadcrumb: 'Accueil',
      breadcrumbActuel: 'Matières',
      floatingActionButton: _onglet == _OngletMatieres.liste
          ? FloatingActionButton.extended(
              backgroundColor: SSMPalette.indigo,
              foregroundColor: Colors.white,
              onPressed: () => _afficherDialogMatiere(),
              icon: const Icon(Icons.add),
              label: const Text('Nouvelle matière'),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Matières',
            style: GoogleFonts.sora(fontSize: 19, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
          ),
          const SizedBox(height: 4),
          Text(
            '${_matieres.length} matière${_matieres.length > 1 ? 's' : ''} configurée${_matieres.length > 1 ? 's' : ''}',
            style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2),
          ),
          const SizedBox(height: 12),
          _segments(),
          const SizedBox(height: 16),
          if (_onglet == _OngletMatieres.liste) _ongletListe() else _ongletStatistiques(),
        ],
      ),
    );
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
          const SSMNavItem(icone: Icons.class_outlined, label: 'Classes', route: '/directeur/classes'),
          SSMNavItem(
            icone: Icons.menu_book_outlined,
            label: 'Matières',
            route: '/directeur/matieres',
            badge: (!_chargementListe && _matieres.isNotEmpty) ? _matieres.length : null,
          ),
          const SSMNavItem(icone: Icons.calendar_month_outlined, label: 'Années & Périodes', route: '/directeur/annees'),
        ]),
    ];
  }

  // ── Sélecteur d'onglet ──
  Widget _segments() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(SSMRayons.moyen)),
      child: Row(
        children: [
          Expanded(child: _segment('Matières', _OngletMatieres.liste)),
          Expanded(child: _segment('Statistiques', _OngletMatieres.statistiques)),
        ],
      ),
    );
  }

  Widget _segment(String label, _OngletMatieres valeur) {
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
  // ONGLET 1 — LISTE
  // ══════════════════════════════════════════════════════

  Widget _ongletListe() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _barreRecherche(),
        const SizedBox(height: 16),
        if (_chargementListe)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator(color: SSMPalette.indigo)),
          )
        else if (_matieres.isEmpty)
          _etatVide()
        else
          LayoutBuilder(builder: (context, contraintes) {
            return contraintes.maxWidth >= 760 ? _tableMatieres() : _listeCartesMatieres();
          }),
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
        controller: _rechercheController,
        onChanged: _onRechercheChangee,
        style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte1),
        decoration: InputDecoration(
          hintText: 'Rechercher une matière...',
          hintStyle: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte3),
          prefixIcon: const Icon(Icons.search, size: 18, color: SSMPalette.texte3),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _etatVide() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.menu_book_outlined, size: 56, color: SSMPalette.texte3),
            const SizedBox(height: 14),
            Text('Aucune matière créée', style: GoogleFonts.inter(fontSize: 13.5, color: SSMPalette.texte2)),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: SSMPalette.indigo,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
              ),
              onPressed: () => _afficherDialogMatiere(),
              child: const Text('Créer la première matière'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Vue desktop large : tableau ──
  Widget _tableMatieres() {
    return SSMDataTable(
      colonnes: const [
        SSMDataColumn(''),
        SSMDataColumn('Matière'),
        SSMDataColumn('Classes'),
        SSMDataColumn('Enseignants'),
        SSMDataColumn('Actions'),
      ],
      lignes: [for (final m in _matieres) _ligneMatiere(m)],
    );
  }

  List<Widget> _ligneMatiere(dynamic matiere) {
    final id = matiere['id'] as int;
    final nom = matiere['nom'] as String;
    final code = matiere['code'] as String?;
    final couleur = _couleurMatiere(matiere);
    final nombreClasses = (matiere['nombre_classes'] as num?)?.toInt() ?? 0;
    final enseignants = (matiere['enseignants'] as List?) ?? [];

    return [
      Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(color: couleur.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(SSMRayons.petit + 2)),
        child: Icon(Icons.menu_book_outlined, size: 15, color: couleur),
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(nom, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
          if (code != null && code.isNotEmpty)
            Text(code, style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: SSMPalette.texte3)),
        ],
      ),
      SSMPill.couleur(label: '$nombreClasses classe${nombreClasses > 1 ? 's' : ''}', couleur: SSMPalette.indigo),
      Text('${enseignants.length} prof${enseignants.length > 1 ? 's' : ''}', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
      _menuActionsMatiere(id, nom, nombreClasses, matiere),
    ];
  }

  // ── Vue mobile/étroite : cartes ──
  Widget _listeCartesMatieres() {
    return Column(children: _matieres.map((m) => _carteMatiere(m)).toList());
  }

  Widget _carteMatiere(dynamic matiere) {
    final id = matiere['id'] as int;
    final nom = matiere['nom'] as String;
    final code = matiere['code'] as String?;
    final couleur = _couleurMatiere(matiere);
    final nombreClasses = (matiere['nombre_classes'] as num?)?.toInt() ?? 0;
    final enseignants = (matiere['enseignants'] as List?) ?? [];

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
          left: BorderSide(color: couleur, width: 3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: couleur.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(SSMRayons.moyen)),
            child: Icon(Icons.menu_book_outlined, color: couleur, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nom, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
                if (code != null && code.isNotEmpty)
                  Text(code, style: GoogleFonts.jetBrainsMono(fontSize: 11, color: SSMPalette.texte3)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    SSMPill.couleur(label: '$nombreClasses classe${nombreClasses > 1 ? 's' : ''}', couleur: SSMPalette.indigo),
                    SSMPill.couleur(label: '${enseignants.length} prof${enseignants.length > 1 ? 's' : ''}', couleur: SSMPalette.teal),
                  ],
                ),
              ],
            ),
          ),
          _menuActionsMatiere(id, nom, nombreClasses, matiere),
        ],
      ),
    );
  }

  Widget _menuActionsMatiere(int id, String nom, int nombreClasses, dynamic matiere) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: SSMPalette.texte3),
      onSelected: (valeur) {
        if (valeur == 'modifier') _afficherDialogMatiere(matiere: matiere);
        if (valeur == 'statistiques') setState(() => _onglet = _OngletMatieres.statistiques);
        if (valeur == 'supprimer') _confirmerSuppression(id, nom, nombreClasses);
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'modifier',
          child: Row(children: [
            Icon(Icons.edit, color: SSMPalette.indigo, size: 18),
            SizedBox(width: 8),
            Text('Modifier'),
          ]),
        ),
        const PopupMenuItem(
          value: 'statistiques',
          child: Row(children: [
            Icon(Icons.bar_chart, color: SSMPalette.teal, size: 18),
            SizedBox(width: 8),
            Text('Statistiques'),
          ]),
        ),
        const PopupMenuItem(
          value: 'supprimer',
          child: Row(children: [
            Icon(Icons.delete, color: SSMPalette.rouge, size: 18),
            SizedBox(width: 8),
            Text('Supprimer'),
          ]),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  // ONGLET 2 — STATISTIQUES
  // ══════════════════════════════════════════════════════

  Widget _ongletStatistiques() {
    if (_chargementStats) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator(color: SSMPalette.indigo)),
      );
    }
    final stats = _statistiques;
    if (stats == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(child: Text('Erreur chargement statistiques', style: GoogleFonts.inter(color: SSMPalette.texte3))),
      );
    }

    final matieres = (stats['matieres'] as List?) ?? [];
    final plusFacile = stats['matiere_plus_facile'] as Map<String, dynamic>?;
    final plusDifficile = stats['matiere_plus_difficile'] as Map<String, dynamic>?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(builder: (context, contraintes) {
          final colonnes = contraintes.maxWidth >= 520 ? 2 : 1;
          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: colonnes,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 168,
            ),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 2,
            itemBuilder: (context, i) => [
              _carteExtreme(titre: 'La plus facile', donnees: plusFacile, couleur: SSMPalette.teal, icone: Icons.trending_up),
              _carteExtreme(titre: 'La plus difficile', donnees: plusDifficile, couleur: SSMPalette.rouge, icone: Icons.trending_down),
            ][i],
          );
        }),
        const SizedBox(height: 16),
        Text(
          'Moyenne par matière',
          style: GoogleFonts.sora(fontSize: 12.5, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
        ),
        const SizedBox(height: 10),
        if (matieres.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Text('Aucune statistique disponible', style: GoogleFonts.inter(color: SSMPalette.texte3))),
          )
        else
          ...matieres.map((m) => _carteStatMatiere(m as Map<String, dynamic>)),
      ],
    );
  }

  Widget _carteExtreme({
    required String titre,
    required Map<String, dynamic>? donnees,
    required Color couleur,
    required IconData icone,
  }) {
    final nom = donnees?['matiere_nom'] as String?;
    final moyenne = donnees?['moyenne_generale'];

    return SSMStatCard(
      icone: icone,
      couleur: couleur,
      valeur: moyenne != null ? '$moyenne/20' : '—',
      label: nom ?? '—',
      sousTexte: titre,
      tendance: SSMTendance.neutre,
    );
  }

  Widget _carteStatMatiere(Map<String, dynamic> matiere) {
    final nom = matiere['matiere_nom'] as String? ?? '';
    final moyenne = (matiere['moyenne_generale'] as num?)?.toDouble();
    final moyennesParClasse = (matiere['moyennes_par_classe'] as List?) ?? [];
    final couleur = moyenne == null
        ? SSMPalette.texte3
        : moyenne > 12
            ? SSMPalette.teal
            : moyenne > 8
                ? SSMPalette.ambre
                : SSMPalette.rouge;

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
              Icon(Icons.menu_book_outlined, size: 18, color: couleur),
              const SizedBox(width: 8),
              Expanded(
                child: Text(nom, style: GoogleFonts.sora(fontSize: 13.5, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
              ),
              Text(
                moyenne != null ? '${moyenne.toStringAsFixed(2)}/20' : '—/20',
                style: GoogleFonts.sora(fontSize: 13.5, fontWeight: FontWeight.w700, color: couleur),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: moyenne != null ? (moyenne / 20).clamp(0.0, 1.0) : 0,
              minHeight: 6,
              backgroundColor: const Color(0xFFF1F5F9),
              color: couleur,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${moyennesParClasse.length} classe${moyennesParClasse.length > 1 ? 's' : ''} concernée${moyennesParClasse.length > 1 ? 's' : ''}',
            style: GoogleFonts.inter(fontSize: 11.5, color: SSMPalette.texte2),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // DIALOG CRÉER / MODIFIER
  // ══════════════════════════════════════════════════════

  InputDecoration _decorationChamp(String label, {bool dense = false}) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2),
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

  Future<void> _afficherDialogMatiere({dynamic matiere}) async {
    final estModification = matiere != null;
    final nomController = TextEditingController(text: estModification ? matiere['nom'] as String? : '');
    final codeController = TextEditingController(text: estModification ? (matiere['code'] as String? ?? '') : '');
    Color couleurSelectionnee = estModification ? _couleurMatiere(matiere) : _couleurParDefaut;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
            backgroundColor: SSMPalette.blanc,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      estModification ? 'Modifier' : 'Nouvelle matière',
                      style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: nomController,
                      decoration: _decorationChamp('Nom *').copyWith(hintText: 'ex: Mathématiques, Français, SVT...'),
                      style: GoogleFonts.inter(fontSize: 14, color: SSMPalette.texte1),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: codeController,
                      decoration: _decorationChamp('Code (optionnel)').copyWith(hintText: 'ex: MATH, FR, SVT'),
                      style: GoogleFonts.jetBrainsMono(fontSize: 14, color: SSMPalette.texte1),
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 16),
                    Text("Couleur d'identification", style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _couleursMatiere.map((c) {
                        final selectionnee = c.toARGB32() == couleurSelectionnee.toARGB32();
                        return GestureDetector(
                          onTap: () => setStateDialog(() => couleurSelectionnee = c),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: selectionnee ? Border.all(color: Colors.white, width: 2) : null,
                              boxShadow: selectionnee
                                  ? [BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 6, offset: const Offset(0, 2))]
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: couleurSelectionnee.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(SSMRayons.petit),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(color: couleurSelectionnee, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            nomController.text.isEmpty ? 'Aperçu' : nomController.text,
                            style: GoogleFonts.inter(fontSize: 14, color: SSMPalette.texte1),
                          ),
                        ],
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
                            style: ElevatedButton.styleFrom(
                              backgroundColor: SSMPalette.indigo,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
                            ),
                            onPressed: () async {
                              if (nomController.text.trim().isEmpty) {
                                _afficherErreur('Le nom de la matière est obligatoire');
                                return;
                              }
                              final couleurHex =
                                  '#${couleurSelectionnee.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
                              try {
                                if (estModification) {
                                  await MatiereService.modifierMatiere(
                                    matiere['id'] as int,
                                    nom: nomController.text.trim(),
                                    code: codeController.text.trim().isEmpty ? null : codeController.text.trim(),
                                    couleur: couleurHex,
                                  );
                                  if (context.mounted) Navigator.pop(context);
                                  _afficherSucces('Matière modifiée avec succès');
                                } else {
                                  await MatiereService.creerMatiere(
                                    nom: nomController.text.trim(),
                                    code: codeController.text.trim().isEmpty ? null : codeController.text.trim(),
                                    couleur: couleurHex,
                                  );
                                  if (context.mounted) Navigator.pop(context);
                                  _afficherSucces('Matière créée avec succès');
                                }
                                _chargerListe();
                                _chargerStatistiques();
                              } catch (e) {
                                _afficherErreur(e.toString().replaceAll('Exception: ', ''));
                              }
                            },
                            child: Text(estModification ? 'Modifier' : 'Créer'),
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
  }

  // ══════════════════════════════════════════════════════
  // DIALOG SUPPRESSION
  // ══════════════════════════════════════════════════════

  Future<void> _confirmerSuppression(int id, String nom, int nombreClasses) async {
    await showDialog(
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
                const Icon(Icons.warning_amber_rounded, color: SSMPalette.ambre, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Supprimer "$nom" ?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w700, color: SSMPalette.texte1),
                ),
                if (nombreClasses > 0) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Cette matière est utilisée dans $nombreClasses classe(s). '
                    'La supprimer retirera également ses données de ces classes.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.rouge),
                  ),
                ],
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SSMPalette.rouge,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
                        ),
                        onPressed: () async {
                          try {
                            await MatiereService.supprimerMatiere(id);
                            if (context.mounted) Navigator.pop(context);
                            _afficherSucces('Matière supprimée avec succès');
                            _chargerListe();
                            _chargerStatistiques();
                          } catch (e) {
                            _afficherErreur(e.toString().replaceAll('Exception: ', ''));
                          }
                        },
                        child: const Text('Supprimer quand même'),
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
}
