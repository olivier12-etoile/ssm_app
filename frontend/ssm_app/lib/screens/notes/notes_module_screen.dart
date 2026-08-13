import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/utilisateur.dart';
import '../../services/auth_service.dart';
import '../../services/annee_service.dart';
import '../../services/validation_note_service.dart';
import 'dashboard_notes_screen.dart';
import 'selection_saisie_screen.dart';
import 'validation_notes_screen.dart';
import 'analyse_performance_screen.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _teal = Color(0xFF0D9488);
const Color _ambre = Color(0xFFD97706);
const Color _vert = Color(0xFF16A34A);
const Color _rouge = Color(0xFFDC2626);
const Color _gris = Color(0xFF94A3B8);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);

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
      return _vert;
    case 'rejet':
      return _rouge;
    case 'deverrouillage':
      return _ambre;
    default:
      return _indigo;
  }
}

String _formatDateHeure(String? iso) {
  if (iso == null) return '—';
  final d = DateTime.tryParse(iso);
  if (d == null) return '—';
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} à '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

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

class _NotesModuleScreenState extends State<NotesModuleScreen> with SingleTickerProviderStateMixin {
  Utilisateur? _utilisateur;
  bool _chargementUtilisateur = true;

  TabController? _tabController;
  int? _periodeId;
  int _nombreEnAttente = 0;

  bool get _estEnseignant => _utilisateur?.estEnseignant == true;
  bool get _estGestionnaire => _utilisateur?.estDirecteur == true || _utilisateur?.estCenseur == true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    final utilisateur = await AuthService.getUtilisateur();
    setState(() {
      _utilisateur = utilisateur;
      _chargementUtilisateur = false;
    });

    if (_estGestionnaire) {
      _tabController = TabController(length: 2, vsync: this);
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

  String get _routeDashboardPrincipal {
    switch (_utilisateur?.role) {
      case 'enseignant':
        return '/dashboard/enseignant';
      case 'censeur':
        return '/dashboard/censeur';
      case 'secretaire':
        return '/dashboard/secretaire';
      default: // directeur, super_admin
        return '/tableau-de-bord';
    }
  }

  void _retour() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, _routeDashboardPrincipal);
    }
  }

  Future<void> _ouvrirHistorique() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _FeuilleHistorique(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _retour),
        title: Text('Notes & Évaluations', style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: Colors.white)),
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
        actions: [
          if (_estGestionnaire)
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'Historique des validations',
              onPressed: _ouvrirHistorique,
            ),
        ],
        bottom: _estGestionnaire && _tabController != null
            ? TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Validation'),
                        if (_nombreEnAttente > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: _ambre, borderRadius: BorderRadius.circular(999)),
                            child: Text('$_nombreEnAttente', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Tab(text: 'Vue d\'ensemble'),
                ],
              )
            : null,
      ),
      body: _chargementUtilisateur
          ? const Center(child: CircularProgressIndicator(color: _indigo))
          : _utilisateur == null
              ? _vueErreur('Impossible de charger votre profil. Reconnectez-vous.')
              : _corps(),
      floatingActionButton: _estGestionnaire
          ? FloatingActionButton.extended(
              onPressed: _periodeId == null
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AnalysePerformanceScreen(periodeId: _periodeId!)),
                      ),
              backgroundColor: _periodeId == null ? _gris : _teal,
              icon: const Icon(Icons.insights, color: Colors.white),
              label: Text(
                'Analyse des performances',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            )
          : null,
    );
  }

  Widget _corps() {
    if (_estEnseignant) {
      // Section "Mes saisies" en priorité — pas d'accès à la validation.
      return const SelectionSaisieScreen();
    }

    if (_estGestionnaire) {
      return TabBarView(
        controller: _tabController,
        children: [
          // "Validation en attente" en priorité (1er onglet) : contenu
          // intégral de ValidationNotesScreen, réutilisé tel quel — sert
          // aussi de vue "Toutes les saisies en attente" pour la supervision.
          const ValidationNotesScreen(afficherBoutonRetour: false),
          // "Vue d'ensemble" : cards résumé + progression de dashboard_notes_screen.dart.
          const DashboardNotesScreen(),
        ],
      );
    }

    return _vueErreur("Ce module n'est pas disponible pour votre rôle.");
  }

  Widget _vueErreur(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, color: _gris, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: GoogleFonts.inter(color: _texte)),
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
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text('Historique des validations', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: _texteFonce)),
                ],
              ),
            ),
            Expanded(
              child: _chargement
                  ? const Center(child: CircularProgressIndicator(color: _indigo))
                  : _erreur != null
                      ? Center(child: Text(_erreur!, style: GoogleFonts.inter(color: _rouge)))
                      : _lignes.isEmpty
                          ? Center(child: Text('Aucune action enregistrée pour le moment.', style: GoogleFonts.inter(color: _gris)))
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: couleur, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${classe?['nom'] ?? '—'} — ${matiere?['nom'] ?? '—'} (${periode?['nom'] ?? '—'})',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _texteFonce),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: couleur.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                child: Text(_libelleAction(action), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: couleur)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Par ${effectuePar?['name'] ?? '—'} · ${_formatDateHeure(ligne['created_at'] as String?)}',
            style: GoogleFonts.inter(fontSize: 11, color: _gris),
          ),
          if (motif != null && motif.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Motif : $motif', style: GoogleFonts.inter(fontSize: 11, color: _texte, fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }
}
