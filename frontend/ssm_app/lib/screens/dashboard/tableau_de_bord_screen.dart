import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/utilisateur.dart';
import '../../services/auth_service.dart';
import '../../services/annee_service.dart';
import '../../services/statistique_service.dart';
import '../../services/absence_service.dart';
import '../../services/paiement_service.dart';
import '../../services/notification_attente_service.dart';

class TableauDeBordScreen extends StatefulWidget {
  const TableauDeBordScreen({super.key});

  @override
  State<TableauDeBordScreen> createState() => _TableauDeBordScreenState();
}

class _TableauDeBordScreenState extends State<TableauDeBordScreen>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Utilisateur? _utilisateur;

  String? _anneeLibelle;
  Map<String, dynamic>? _statistiques;
  Map<String, dynamic>? _statsAbsences;
  List<dynamic> _derniersPaiements = [];
  int _totalNotifications = 0;
  bool _chargementDonnees = true;

  late final AnimationController _controller;
  late final List<Animation<double>> _cardAnims;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _cardAnims = List.generate(4, (i) {
      final debut = i * 0.08;
      return CurvedAnimation(
        parent: _controller,
        curve: Interval(debut, debut + 0.6, curve: Curves.easeOutCubic),
      );
    });
    _chargerUtilisateur();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _chargerUtilisateur() async {
    final u = await AuthService.getUtilisateur();

    if (u != null && !u.motDePasseChange && mounted) {
      Navigator.pushReplacementNamed(context, '/changer-mot-de-passe');
      return;
    }

    setState(() => _utilisateur = u);
    _chargerDonneesTableauDeBord();
  }

  Future<void> _chargerDonneesTableauDeBord() async {
    setState(() => _chargementDonnees = true);
    try {
      final annees = await AnneeService.listerAnnees();
      final anneeEnCours = annees.firstWhere(
        (a) => a['statut'] == 'en_cours',
        orElse: () => annees.isNotEmpty ? annees.first : null,
      );
      final anneeId = anneeEnCours?['id'] as int?;

      final resultats = await Future.wait([
        StatistiqueService.chargerStatistiques(anneeId: anneeId),
        AbsenceService.statistiques(),
        PaiementService.listerPaiements(),
        NotificationAttenteService.lister(),
      ]);

      setState(() {
        _anneeLibelle       = anneeEnCours?['libelle'] as String?;
        _statistiques       = resultats[0] as Map<String, dynamic>;
        _statsAbsences      = resultats[1] as Map<String, dynamic>;
        _derniersPaiements  = (resultats[2] as List).take(5).toList();
        _totalNotifications =
            (resultats[3] as Map<String, dynamic>)['total'] as int? ?? 0;
        _chargementDonnees = false;
      });

      _controller.forward(from: 0);
    } catch (e) {
      setState(() => _chargementDonnees = false);
    }
  }

  int get _totalEleves =>
      (_statistiques?['effectifs']?['total'] as num?)?.toInt() ?? 0;

  int get _garcons =>
      (_statistiques?['effectifs']?['garcons'] as num?)?.toInt() ?? 0;

  int get _filles =>
      (_statistiques?['effectifs']?['filles'] as num?)?.toInt() ?? 0;

  int get _absencesAujourdhui =>
      (_statsAbsences?['absents_aujourdhui'] as num?)?.toInt() ?? 0;

  List<dynamic> get _paiementsParMois =>
      (_statistiques?['finances']?['paiements_mois'] as List?) ?? [];

  double _montantPourMois(int mois, int annee) {
    final entree = _paiementsParMois.firstWhere(
      (p) => p['mois'] == mois && p['annee'] == annee,
      orElse: () => null,
    );
    return entree != null
        ? double.tryParse(entree['total'].toString()) ?? 0
        : 0;
  }

  double get _montantMoisActuel {
    final now = DateTime.now();
    return _montantPourMois(now.month, now.year);
  }

  double? get _variationPaiements {
    final now = DateTime.now();
    final moisPrecedent = now.month == 1 ? 12 : now.month - 1;
    final anneePrecedente = now.month == 1 ? now.year - 1 : now.year;
    final montantPrecedent = _montantPourMois(moisPrecedent, anneePrecedente);

    if (montantPrecedent <= 0) return null;
    return (_montantMoisActuel - montantPrecedent) / montantPrecedent * 100;
  }

  // Les 6 derniers mois (mois courant inclus), du plus ancien au plus récent.
  List<({int mois, int annee})> get _sixDerniersMois {
    final now = DateTime.now();
    return List.generate(6, (i) {
      final date = DateTime(now.year, now.month - (5 - i));
      return (mois: date.month, annee: date.year);
    });
  }

  String _nomMoisAbrev(int mois) {
    const noms = [
      '', 'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun',
      'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'
    ];
    return noms[mois];
  }

  @override
  Widget build(BuildContext context) {
    if (_utilisateur == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFEFF6FF),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFEFF6FF),
      drawer: _sidebarGlass(context),
      body: Stack(
        children: [
          // ── Blobs abstraits en arrière-plan ────────────────
          Positioned(
            top: -80,
            right: -60,
            child: _blob(size: 300, couleur: const Color(0xFF1E3A8A).withValues(alpha: 0.08)),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: _blob(size: 200, couleur: const Color(0xFF0D9488).withValues(alpha: 0.10)),
          ),
          Positioned(
            top: 320,
            left: 140,
            child: _blob(size: 150, couleur: const Color(0xFFD97706).withValues(alpha: 0.04)),
          ),

          SafeArea(
            child: Column(
              children: [
                _topbar(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _chargerDonneesTableauDeBord,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _enTeteTitre(context),
                          const SizedBox(height: 24),
                          _grilleStats(),
                          const SizedBox(height: 24),
                          _sectionGraphiques(),
                          const SizedBox(height: 24),
                          _tableauPaiements(context),
                          const SizedBox(height: 40),
                          _footer(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

  // ══════════════════════════════════════════════════════
  // SIDEBAR (Drawer glassmorphism)
  // ══════════════════════════════════════════════════════

  Widget _sidebarGlass(BuildContext context) {
    final routeActuelle = ModalRoute.of(context)?.settings.name;

    return Drawer(
      backgroundColor: Colors.transparent,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            color: const Color(0xFF0F172A).withValues(alpha: 0.95),
            child: Column(
              children: [
                _logoArea(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(top: 8),
                    children: [
                      _menuItemGlass(context,
                        icone: Icons.dashboard,
                        titre: 'Tableau de bord',
                        route: '/tableau-de-bord',
                        routeActuelle: routeActuelle,
                      ),

                      _separateurGlass('Administration'),
                      _menuItemGlass(context, icone: Icons.people, titre: 'Utilisateurs', route: '/directeur/utilisateurs', routeActuelle: routeActuelle),
                      _menuItemGlass(context, icone: Icons.class_, titre: 'Classes', route: '/directeur/classes', routeActuelle: routeActuelle),
                      _menuItemGlass(context, icone: Icons.library_books_outlined, titre: 'Catalogue des matières', route: '/directeur/catalogue-matieres', routeActuelle: routeActuelle),
                      _menuItemGlass(context, icone: Icons.calendar_month, titre: 'Années & Périodes', route: '/directeur/annees', routeActuelle: routeActuelle),
                      _menuItemGlass(context, icone: Icons.people_outline, titre: 'Élèves', route: '/directeur/eleves', routeActuelle: routeActuelle),
                      _menuItemGlass(context, icone: Icons.price_change, titre: 'Frais scolaires', route: '/directeur/frais', routeActuelle: routeActuelle),

                      _separateurGlass('Pédagogie'),
                      _menuItemGlass(context, icone: Icons.edit_note, titre: 'Saisie des notes', route: '/enseignant/notes', routeActuelle: routeActuelle),
                      _menuItemGlass(context, icone: Icons.grade, titre: 'Validation des notes', route: '/notes/validation', routeActuelle: routeActuelle),
                      _menuItemGlass(context, icone: Icons.description, titre: 'Bulletins', route: '/bulletins', routeActuelle: routeActuelle),
                      _menuItemGlass(context, icone: Icons.event_busy, titre: 'Absences', route: '/enseignant/absences', routeActuelle: routeActuelle),
                      _menuItemGlass(context, icone: Icons.calendar_view_week, titre: 'Emplois du temps', route: '/emploi-du-temps', routeActuelle: routeActuelle),
                      _menuItemGlass(context, icone: Icons.bar_chart, titre: 'Statistiques', route: '/statistiques', routeActuelle: routeActuelle),

                      _separateurGlass('Finances'),
                      _menuItemGlass(context, icone: Icons.payment, titre: 'Paiements', route: '/paiements', routeActuelle: routeActuelle),
                      _menuItemGlass(context, icone: Icons.person_remove, titre: 'Liste de renvoi', route: '/paiements/renvoi', routeActuelle: routeActuelle),
                      _menuItemGlass(context,
                        icone: Icons.send_to_mobile,
                        titre: 'Notifications',
                        route: '/notifications',
                        routeActuelle: routeActuelle,
                        badge: _totalNotifications > 0 ? '$_totalNotifications' : null,
                      ),

                      Divider(color: Colors.white.withValues(alpha: 0.06), thickness: 1, height: 24),

                      _menuItemGlass(context, icone: Icons.sync, titre: 'Synchronisation', route: '/sync', routeActuelle: routeActuelle),
                      _menuItemGlass(context, icone: Icons.person, titre: 'Mon profil', route: '/profil', routeActuelle: routeActuelle),
                    ],
                  ),
                ),
                _carteUtilisateur(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _logoArea() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD97706).withValues(alpha: 0.3),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Icon(Icons.park, color: Color(0xFFD97706), size: 26),
              ),
              const SizedBox(width: 10),
              Text(
                'SSM',
                style: GoogleFonts.sora(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'SMART SCHOOL MANAGER',
            style: GoogleFonts.inter(
              fontSize: 10,
              letterSpacing: 0.5,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuItemGlass(
    BuildContext context, {
    required IconData icone,
    required String titre,
    required String route,
    required String? routeActuelle,
    String? badge,
  }) {
    final actif = route == routeActuelle;

    return Material(
      color: actif ? Colors.white.withValues(alpha: 0.06) : Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          if (!actif) Navigator.pushNamed(context, route);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: actif ? const Color(0xFFD97706) : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icone,
                size: 18,
                color: actif
                    ? const Color(0xFFD97706)
                    : Colors.white.withValues(alpha: 0.35),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  titre,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: actif ? Colors.white : Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _separateurGlass(String titre) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, left: 28, bottom: 4),
      child: Text(
        titre.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.3),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _carteUtilisateur(BuildContext context) {
    final initiale = _utilisateur!.nom.isNotEmpty
        ? _utilisateur!.nom.substring(0, 1).toUpperCase()
        : '?';

    return Container(
      margin: const EdgeInsets.fromLTRB(28, 0, 28, 20),
      padding: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/profil');
        },
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF3B5CB8), Color(0xFF0D9488)],
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                initiale,
                style: GoogleFonts.sora(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _utilisateur!.nom,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    _utilisateur!.role,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // TOPBAR
  // ══════════════════════════════════════════════════════

  Widget _topbar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.5),
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 20,
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.menu),
                color: const Color(0xFF0F172A),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              const SizedBox(width: 8),
              Container(
                width: 220,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 16, color: const Color(0xFF334155).withValues(alpha: 0.6)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Rechercher...',
                          hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF334155).withValues(alpha: 0.5)),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        style: GoogleFonts.inter(fontSize: 13),
                      ),
                    ),
                    Text('⌘K', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF334155).withValues(alpha: 0.4))),
                  ],
                ),
              ),
              const Spacer(),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    color: const Color(0xFF334155),
                    onPressed: () => Navigator.pushNamed(context, '/notifications'),
                  ),
                  if (_totalNotifications > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 16,
                        height: 16,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Color(0xFFDC2626),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          _totalNotifications > 9 ? '9+' : '$_totalNotifications',
                          style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF152C6B)],
                  ),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
                ),
                child: Text(
                  _utilisateur!.nom.isNotEmpty ? _utilisateur!.nom.substring(0, 1).toUpperCase() : '?',
                  style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // EN-TÊTE
  // ══════════════════════════════════════════════════════

  Widget _enTeteTitre(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.start,
      runSpacing: 12,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tableau de bord',
                style: GoogleFonts.sora(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              RichText(
                text: TextSpan(
                  style: GoogleFonts.inter(fontSize: 16, color: const Color(0xFF334155)),
                  children: [
                    const TextSpan(text: 'Vue globale de votre établissement. '),
                    TextSpan(
                      text: '$_totalEleves élèves',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF1E3A8A)),
                    ),
                    TextSpan(
                      text: ' suivis en temps réel.'
                          '${_anneeLibelle != null ? ' Année $_anneeLibelle.' : ''}',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF1E3A8A).withValues(alpha: 0.25), blurRadius: 14, offset: const Offset(0, 4)),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Export PDF à venir')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                ),
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: Text('Exporter', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/sync'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1E3A8A),
                side: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              ),
              icon: const Icon(Icons.sync, size: 18),
              label: Text('Synchroniser', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  // CARTES STATS
  // ══════════════════════════════════════════════════════

  Widget _grilleStats() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final colonnes = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 560 ? 2 : 1);
        return GridView.count(
          crossAxisCount: colonnes,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.7,
          children: [
            _carteAnimee(0, _carteGlass(
              label: 'Effectifs totaux',
              valeur: _chargementDonnees ? '—' : '$_totalEleves',
              icone: Icons.people,
              couleur: const Color(0xFF1E3A8A),
              variation: _chargementDonnees ? null : '+5%',
              variationPositive: true,
            )),
            _carteAnimee(1, _carteGlass(
              label: 'Recettes (mois)',
              valeur: _chargementDonnees ? '—' : '${_montantMoisActuel.toStringAsFixed(0)} FCFA',
              icone: Icons.paid,
              couleur: const Color(0xFFD97706),
              variation: _variationPaiements != null
                  ? '${_variationPaiements! >= 0 ? '+' : ''}${_variationPaiements!.toStringAsFixed(0)}%'
                  : null,
              variationPositive: (_variationPaiements ?? 0) >= 0,
            )),
            _carteAnimee(2, _carteGlass(
              label: 'Absences (auj.)',
              valeur: _chargementDonnees ? '—' : '$_absencesAujourdhui',
              icone: Icons.person_off,
              couleur: const Color(0xFFEA580C),
            )),
            _carteAnimee(3, _carteGlass(
              label: 'Alertes actives',
              valeur: _chargementDonnees ? '—' : '$_totalNotifications',
              icone: Icons.notifications,
              couleur: const Color(0xFFDC2626),
            )),
          ],
        );
      },
    );
  }

  Widget _carteAnimee(int index, Widget child) {
    final anim = _cardAnims[index];
    return AnimatedBuilder(
      animation: anim,
      builder: (context, c) => Opacity(
        opacity: anim.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - anim.value)),
          child: c,
        ),
      ),
      child: child,
    );
  }

  Widget _carteGlass({
    required String label,
    required String valeur,
    required IconData icone,
    required Color couleur,
    String? variation,
    bool variationPositive = true,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF334155))),
                    const SizedBox(height: 4),
                    Text(
                      valeur,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.sora(fontSize: 30, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                    ),
                    if (variation != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: (variationPositive ? const Color(0xFF16A34A) : const Color(0xFFDC2626)).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          variation,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: variationPositive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(icone, size: 32, color: couleur.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // GRAPHIQUES
  // ══════════════════════════════════════════════════════

  Widget _sectionGraphiques() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final large = constraints.maxWidth > 900;
        final graphiquePaiements = _carteGraphique(
          titre: 'Évolution des paiements',
          badge: 'Live',
          enfant: _chargementDonnees
              ? const SizedBox(height: 200)
              : SizedBox(height: 200, child: _lineChartPaiements()),
        );
        final graphiqueRepartition = _carteGraphique(
          titre: 'Répartition',
          enfant: Column(
            children: [
              SizedBox(
                height: 150,
                child: _chargementDonnees ? const SizedBox() : _donutRepartition(),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                children: [
                  _legendeRepartition('Garçons $_garcons', const Color(0xFF1E3A8A)),
                  _legendeRepartition('Filles $_filles', const Color(0xFF0D9488)),
                ],
              ),
            ],
          ),
        );

        if (large) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: graphiquePaiements),
              const SizedBox(width: 16),
              Expanded(flex: 1, child: graphiqueRepartition),
            ],
          );
        }
        return Column(
          children: [
            graphiquePaiements,
            const SizedBox(height: 16),
            graphiqueRepartition,
          ],
        );
      },
    );
  }

  Widget _carteGraphique({required String titre, String? badge, required Widget enfant}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
            boxShadow: [
              BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.06), blurRadius: 32, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(titre, style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.circle, size: 6, color: Color(0xFF0284C7)),
                          const SizedBox(width: 4),
                          Text(badge, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF0284C7), fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              enfant,
            ],
          ),
        ),
      ),
    );
  }

  Widget _lineChartPaiements() {
    final mois = _sixDerniersMois;
    final valeurs = mois.map((m) => _montantPourMois(m.mois, m.annee)).toList();
    final maxY = (valeurs.isEmpty ? 0.0 : valeurs.reduce((a, b) => a > b ? a : b)) * 1.2;

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY <= 0 ? 100 : maxY,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: (maxY <= 0 ? 100 : maxY) / 4,
          getDrawingHorizontalLine: (value) => FlLine(color: const Color(0xFF0F172A).withValues(alpha: 0.03), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= mois.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_nomMoisAbrev(mois[i].mois), style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF334155))),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF1E3A8A),
            getTooltipItems: (spots) => spots.map((s) {
              return LineTooltipItem('${s.y.toStringAsFixed(0)} FCFA', const TextStyle(color: Colors.white, fontSize: 11));
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [for (var i = 0; i < valeurs.length; i++) FlSpot(i.toDouble(), valeurs[i])],
            isCurved: true,
            color: const Color(0xFF1E3A8A),
            barWidth: 3,
            dotData: FlDotData(
              getDotPainter: (spot, percent, bar, index) =>
                  FlDotCirclePainter(radius: 4, color: const Color(0xFF1E3A8A), strokeWidth: 2, strokeColor: Colors.white),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF1E3A8A).withValues(alpha: 0.15),
                  const Color(0xFF1E3A8A).withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _donutRepartition() {
    final total = _garcons + _filles;
    if (total == 0) {
      return Center(
        child: Text('Aucune donnée', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF334155))),
      );
    }
    return PieChart(
      PieChartData(
        sectionsSpace: 0,
        centerSpaceRadius: 45,
        sections: [
          PieChartSectionData(value: _garcons.toDouble(), color: const Color(0xFF1E3A8A), showTitle: false, radius: 22),
          PieChartSectionData(value: _filles.toDouble(), color: const Color(0xFF0D9488), showTitle: false, radius: 22),
        ],
      ),
    );
  }

  Widget _legendeRepartition(String label, Color couleur) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: couleur, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
    );
  }

  // ══════════════════════════════════════════════════════
  // TABLEAU DERNIERS PAIEMENTS
  // ══════════════════════════════════════════════════════

  Widget _tableauPaiements(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
            boxShadow: [
              BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.06), blurRadius: 32, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Derniers paiements enregistrés',
                      style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/paiements'),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Voir tout', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1E3A8A))),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward, size: 14, color: Color(0xFF1E3A8A)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_chargementDonnees)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_derniersPaiements.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text('Aucun paiement enregistré', style: GoogleFonts.inter(color: const Color(0xFF334155))),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 36,
                    dataRowMinHeight: 48,
                    dataRowMaxHeight: 56,
                    columnSpacing: 24,
                    headingTextStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF334155), letterSpacing: 0.4),
                    columns: const [
                      DataColumn(label: Text('ÉLÈVE')),
                      DataColumn(label: Text('TRANCHE')),
                      DataColumn(label: Text('MONTANT')),
                      DataColumn(label: Text('DATE')),
                      DataColumn(label: Text('STATUT')),
                      DataColumn(label: Text('ACTION')),
                    ],
                    rows: _derniersPaiements.map((p) {
                      final eleve = p['eleve'];
                      final nomEleve = eleve != null ? '${eleve['nom']} ${eleve['prenom']}' : 'Élève inconnu';
                      return DataRow(cells: [
                        DataCell(Text(nomEleve, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13))),
                        DataCell(Text('${p['tranche']}', style: GoogleFonts.inter(fontSize: 13))),
                        DataCell(Text('${p['montant']} FCFA', style: GoogleFonts.inter(fontSize: 13))),
                        DataCell(Text('${p['date_paiement']}', style: GoogleFonts.inter(fontSize: 13))),
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFF16A34A).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                          child: Text('Payé', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF16A34A))),
                        )),
                        DataCell(OutlinedButton(
                          onPressed: () => Navigator.pushNamed(context, '/paiements'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1E3A8A),
                            side: const BorderSide(color: Color(0xFF1E3A8A)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                          ),
                          child: const Text('Détail', style: TextStyle(fontSize: 12)),
                        )),
                      ]);
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // FOOTER
  // ══════════════════════════════════════════════════════

  Widget _footer() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.park, size: 14, color: Color(0xFFD97706)),
          const SizedBox(width: 6),
          Text(
            'Smart School Manager · Togo 2026 · Version 2.0',
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF334155).withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }
}
