import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/utilisateur.dart';
import '../../services/auth_service.dart';
import '../../services/annee_service.dart';
import '../../services/validation_note_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_page_scaffold.dart';
import '../../widgets/ssm/ssm_sidebar.dart';
import 'dashboard_notes_screen.dart';
import 'selection_saisie_screen.dart';
import 'validation_notes_screen.dart';
import 'analyse_performance_screen.dart';

String _libelleAction(String action) {
  switch (action) {
    case 'soumission':
      return 'Soumission';
    case 'validation':
      return 'Validation';
    case 'rejet':
      return 'Rejet';
    case 'deverrouillage':
      return 'Déverrouillage';
    default:
      return action;
  }
}

Color _couleurAction(String action) {
  switch (action) {
    case 'validation':
      return SSMPalette.teal;
    case 'rejet':
      return SSMPalette.rouge;
    case 'deverrouillage':
      return SSMPalette.ambre;
    default:
      return SSMPalette.indigo;
  }
}

String _formatDateHeure(String? iso) {
  if (iso == null) return '—';
  final d = DateTime.tryParse(iso);
  if (d == null) return '—';
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} à '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

enum _OngletNotes { validation, vueEnsemble }

// ══════════════════════════════════════════════════════════
// Point d'entrée unique du module Notes & Évaluations.
// Regroupe Saisie (enseignant) et Validation + vue d'ensemble
// (directeur/censeur) derrière un seul écran, sans dupliquer le contenu
// des écrans existants : ils sont réutilisés tels quels (embarqués ou
// atteints par navigation, selon le cas — voir le commentaire sur
// ValidationNotesScreen.afficherBoutonRetour pour le pourquoi).
// ══════════════════════════════════════════════════════════
class NotesModuleScreen extends StatefulWidget {
  const NotesModuleScreen({super.key});

  @override
  State<NotesModuleScreen> createState() => _NotesModuleScreenState();
}

class _NotesModuleScreenState extends State<NotesModuleScreen> {
  Utilisateur? _utilisateur;
  bool _chargementUtilisateur = true;

  _OngletNotes _onglet = _OngletNotes.validation;
  int? _periodeId;
  int _nombreEnAttente = 0;

  bool get _estEnseignant => _utilisateur?.estEnseignant == true;
  bool get _estGestionnaire => _utilisateur?.estDirecteur == true || _utilisateur?.estCenseur == true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final utilisateur = await AuthService.getUtilisateur();
    setState(() {
      _utilisateur = utilisateur;
      _chargementUtilisateur = false;
    });

    if (_estGestionnaire) {
      _resoudrePeriodeActive();
      _chargerNombreEnAttente();
    }
  }

  Future<void> _resoudrePeriodeActive() async {
    try {
      // La réponse de /annees/active est enveloppée : {annee, periode_active, ...}.
      final data = await AnneeService.anneeActive();
      final anneeId = (data['annee'] as Map<String, dynamic>?)?['id'] as int?;
      final periodeActiveId = (data['periode_active'] as Map<String, dynamic>?)?['id'] as int?;

      if (periodeActiveId != null) {
        if (mounted) setState(() => _periodeId = periodeActiveId);
        return;
      }

      if (anneeId != null) {
        final periodes = await AnneeService.listerPeriodes(anneeId);
        if (periodes.isNotEmpty && mounted) {
          setState(() => _periodeId = periodes.first['id'] as int);
        }
      }
    } catch (_) {
      // Le bouton "Analyse des performances" reste simplement désactivé
      // si aucune période n'a pu être résolue.
    }
  }

  Future<void> _chargerNombreEnAttente() async {
    try {
      final saisies = await ValidationNoteService.getEnAttente();
      if (mounted) setState(() => _nombreEnAttente = saisies.length);
    } catch (_) {
      // Le badge reste à 0 si le chargement échoue — non bloquant.
    }
  }

  // ── Navigation ────────────────────────────────────────

  void _naviguer(BuildContext context, String route) {
    if (route == '/notes') return;
    Navigator.pushNamed(context, route);
  }

  Future<void> _ouvrirHistorique() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _FeuilleHistorique(),
    );
  }

  // ── Navigation latérale, adaptée au rôle connecté (voir menu_lateral.dart) ──
  List<SSMNavSection> _sections() {
    final role = _utilisateur?.role;

    if (role == 'enseignant') {
      return [
        const SSMNavSection(titre: 'Principal', items: [
          SSMNavItem(icone: Icons.dashboard_outlined, label: 'Tableau de bord', route: '/dashboard/enseignant'),
        ]),
        SSMNavSection(titre: 'Mes classes', items: [
          const SSMNavItem(icone: Icons.grade_outlined, label: 'Notes & évaluations', route: '/notes'),
          const SSMNavItem(icone: Icons.event_busy_outlined, label: 'Saisie des absences', route: '/enseignant/absences'),
          const SSMNavItem(icone: Icons.calendar_view_week_outlined, label: 'Mon emploi du temps', route: '/emploi-du-temps'),
        ]),
        const SSMNavSection(titre: 'Général', items: [
          SSMNavItem(icone: Icons.sync_outlined, label: 'Synchronisation', route: '/sync'),
          SSMNavItem(icone: Icons.person_outline, label: 'Mon profil', route: '/profil'),
          SSMNavItem(icone: Icons.settings_outlined, label: 'Paramètres', route: '/parametres'),
        ]),
      ];
    }

    if (role == 'censeur') {
      return [
        const SSMNavSection(titre: 'Principal', items: [
          SSMNavItem(icone: Icons.dashboard_outlined, label: 'Tableau de bord', route: '/dashboard/censeur'),
        ]),
        SSMNavSection(titre: 'Pédagogie', items: [
          SSMNavItem(
            icone: Icons.grade_outlined,
            label: 'Notes & évaluations',
            route: '/notes',
            badge: _nombreEnAttente > 0 ? _nombreEnAttente : null,
            couleurBadge: SSMPalette.ambre,
          ),
          const SSMNavItem(icone: Icons.description_outlined, label: 'Bulletins', route: '/bulletins'),
          const SSMNavItem(icone: Icons.event_busy_outlined, label: 'Saisie des absences', route: '/enseignant/absences'),
          const SSMNavItem(icone: Icons.calendar_view_week_outlined, label: 'Emplois du temps', route: '/emploi-du-temps'),
        ]),
        const SSMNavSection(titre: 'Général', items: [
          SSMNavItem(icone: Icons.sync_outlined, label: 'Synchronisation', route: '/sync'),
          SSMNavItem(icone: Icons.person_outline, label: 'Mon profil', route: '/profil'),
          SSMNavItem(icone: Icons.settings_outlined, label: 'Paramètres', route: '/parametres'),
        ]),
      ];
    }

    // Directeur (et rôles par défaut) : même structure que le dashboard directeur.
    return [
      const SSMNavSection(titre: 'Principal', items: [
        SSMNavItem(icone: Icons.dashboard_outlined, label: 'Tableau de bord', route: '/tableau-de-bord'),
        SSMNavItem(icone: Icons.people_outline, label: 'Élèves', route: '/directeur/eleves'),
        SSMNavItem(icone: Icons.price_change_outlined, label: 'Frais scolaires', route: '/directeur/frais'),
        SSMNavItem(icone: Icons.calendar_view_week_outlined, label: 'Emploi du temps', route: '/emploi-du-temps'),
        SSMNavItem(icone: Icons.description_outlined, label: 'Bulletins PDF', route: '/bulletins'),
      ]),
      SSMNavSection(titre: 'Pilotage', items: [
        SSMNavItem(
          icone: Icons.grade_outlined,
          label: 'Notes & évaluations',
          route: '/notes',
          badge: _nombreEnAttente > 0 ? _nombreEnAttente : null,
          couleurBadge: SSMPalette.ambre,
        ),
        const SSMNavItem(icone: Icons.bar_chart_outlined, label: 'Statistiques', route: '/statistiques'),
        const SSMNavItem(icone: Icons.notifications_outlined, label: 'Notifications', route: '/notifications'),
        const SSMNavItem(icone: Icons.settings_outlined, label: 'Paramètres école', route: '/parametres'),
      ]),
    ];
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

  @override
  Widget build(BuildContext context) {
    if (_chargementUtilisateur) {
      return const Scaffold(backgroundColor: SSMPalette.fond, body: Center(child: CircularProgressIndicator(color: SSMPalette.indigo)));
    }

    if (_utilisateur == null) {
      return Scaffold(
        backgroundColor: SSMPalette.fond,
        body: _vueErreur('Impossible de charger votre profil. Reconnectez-vous.'),
      );
    }

    return SSMPageScaffold(
      nomEcole: _utilisateur?.codeEcole ?? 'Mon établissement',
      codeEcole: _utilisateur?.codeEcole ?? '—',
      nomUtilisateur: _utilisateur?.nom ?? '…',
      role: _libelleRole(_utilisateur?.role),
      sections: _sections(),
      routeActuelle: '/notes',
      onNavigate: (route) => _naviguer(context, route),
      onProfilTap: () => Navigator.pushNamed(context, '/profil'),
      breadcrumb: 'Accueil',
      breadcrumbActuel: 'Notes & Évaluations',
      actionsTopBar: _estGestionnaire
          ? [
              IconButton(
                icon: const Icon(Icons.history, color: SSMPalette.texte2),
                tooltip: 'Historique des validations',
                onPressed: _ouvrirHistorique,
              ),
            ]
          : null,
      floatingActionButton: _estGestionnaire
          ? FloatingActionButton.extended(
              onPressed: _periodeId == null
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AnalysePerformanceScreen(periodeId: _periodeId!)),
                      ),
              backgroundColor: _periodeId == null ? SSMPalette.texte3 : SSMPalette.teal,
              icon: const Icon(Icons.insights, color: Colors.white),
              label: Text(
                'Analyse des performances',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            )
          : null,
      child: _corps(),
    );
  }

  Widget _corps() {
    if (_estEnseignant) {
      // Section "Mes saisies" en priorité — pas d'accès à la validation.
      return const SelectionSaisieScreen(independant: false);
    }

    if (_estGestionnaire) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _segments(),
          const SizedBox(height: 16),
          if (_onglet == _OngletNotes.validation)
            const ValidationNotesScreen(afficherBoutonRetour: false)
          else
            const DashboardNotesScreen(),
        ],
      );
    }

    return _vueErreur("Ce module n'est pas disponible pour votre rôle.");
  }

  // ── Sélecteur d'onglet (remplace la TabBar de l'ancien AppBar) ──
  Widget _segments() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(SSMRayons.moyen)),
      child: Row(
        children: [
          Expanded(child: _segment('Validation', _OngletNotes.validation, badge: _nombreEnAttente)),
          Expanded(child: _segment("Vue d'ensemble", _OngletNotes.vueEnsemble)),
        ],
      ),
    );
  }

  Widget _segment(String label, _OngletNotes valeur, {int badge = 0}) {
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: actif ? FontWeight.w600 : FontWeight.w400,
                color: actif ? SSMPalette.indigo : SSMPalette.texte2,
              ),
            ),
            if (badge > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: SSMPalette.ambre, borderRadius: BorderRadius.circular(SSMRayons.pilule)),
                child: Text('$badge', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _vueErreur(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, color: SSMPalette.texte3, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: GoogleFonts.inter(color: SSMPalette.texte2)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// Feuille modale : historique des validations (soumission, validation,
// rejet, déverrouillage), toutes saisies confondues.
// ══════════════════════════════════════════════════════════
class _FeuilleHistorique extends StatefulWidget {
  const _FeuilleHistorique();

  @override
  State<_FeuilleHistorique> createState() => _FeuilleHistoriqueState();
}

class _FeuilleHistoriqueState extends State<_FeuilleHistorique> {
  List<dynamic> _lignes = [];
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final data = await ValidationNoteService.getHistorique();
      setState(() {
        _lignes = (data['data'] as List?) ?? [];
        _chargement = false;
      });
    } catch (e) {
      setState(() {
        _chargement = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: SSMPalette.fond,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: SSMPalette.bordure, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text('Historique des validations', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
                ],
              ),
            ),
            Expanded(
              child: _chargement
                  ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
                  : _erreur != null
                      ? Center(child: Text(_erreur!, style: GoogleFonts.inter(color: SSMPalette.rouge)))
                      : _lignes.isEmpty
                          ? Center(child: Text('Aucune action enregistrée pour le moment.', style: GoogleFonts.inter(color: SSMPalette.texte3)))
                          : ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: _lignes.length,
                              itemBuilder: (context, index) => _carteLigne(_lignes[index] as Map<String, dynamic>),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _carteLigne(Map<String, dynamic> ligne) {
    final action = ligne['action'] as String? ?? '';
    final couleur = _couleurAction(action);
    final saisie = ligne['saisie_note'] as Map<String, dynamic>?;
    final classe = saisie?['classe'] as Map<String, dynamic>?;
    final matiere = saisie?['matiere'] as Map<String, dynamic>?;
    final periode = saisie?['periode'] as Map<String, dynamic>?;
    final effectuePar = ligne['effectue_par'] as Map<String, dynamic>?;
    final motif = ligne['motif'] as String?;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${classe?['nom'] ?? '—'} — ${matiere?['nom'] ?? '—'} (${periode?['nom'] ?? '—'})',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: SSMPalette.texte1),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: couleur.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(SSMRayons.pilule)),
                child: Text(_libelleAction(action), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: couleur)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Par ${effectuePar?['name'] ?? '—'} · ${_formatDateHeure(ligne['created_at'] as String?)}',
            style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte3),
          ),
          if (motif != null && motif.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Motif : $motif', style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte2, fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }
}
