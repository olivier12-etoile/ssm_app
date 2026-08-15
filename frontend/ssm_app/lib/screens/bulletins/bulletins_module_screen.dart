import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/utilisateur.dart';
import '../../models/bulletin_model.dart';
import '../../services/auth_service.dart';
import '../../services/annee_service.dart';
import '../../services/classe_service.dart';
import '../../services/bulletin_service.dart';
import '../../widgets/ssm_widgets.dart';
import 'generation_bulletin_screen.dart';
import 'validation_bulletins_screen.dart';
import 'historique_recherche_bulletins_screen.dart';
import 'statistiques_bulletins_screen.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _teal = Color(0xFF0D9488);
const Color _ambre = Color(0xFFD97706);
const Color _vert = Color(0xFF16A34A);
const Color _rouge = Color(0xFFDC2626);
const Color _gris = Color(0xFF94A3B8);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);

// Marque blanche (voir CLAUDE.md "Marque blanche") : convertit la couleur
// hexadécimale de l'école (ex: "#1E3A8A") en Color, avec repli sur la
// couleur par défaut du design system si absente/invalide.
Color _depuisHex(String? hex, Color repli) {
  if (hex == null || hex.isEmpty) return repli;
  try {
    return Color(int.parse(hex.replaceAll('#', '0xFF')));
  } catch (_) {
    return repli;
  }
}

// ══════════════════════════════════════════════════════════
// Point d'entrée unique du module Bulletins (même logique que
// notes_module_screen.dart / parametres_module_screen.dart) : sélecteurs
// année/période, résumé de génération de l'école, liste des classes avec
// statut de génération, puis navigation vers la génération détaillée
// (generation_bulletin_screen.dart), la validation en attente
// (validation_bulletins_screen.dart), l'historique/recherche
// (historique_recherche_bulletins_screen.dart) et les statistiques
// (statistiques_bulletins_screen.dart).
// ══════════════════════════════════════════════════════════
class BulletinsModuleScreen extends StatefulWidget {
  const BulletinsModuleScreen({super.key});

  @override
  State<BulletinsModuleScreen> createState() => _BulletinsModuleScreenState();
}

class _BulletinsModuleScreenState extends State<BulletinsModuleScreen> {
  Utilisateur? _utilisateur;
  bool _chargement = true;
  String? _erreur;

  List<dynamic> _annees = [];
  List<dynamic> _periodes = [];
  int? _anneeId;
  int? _periodeId;

  ResumeDashboardBulletin? _resume;
  bool _chargementResume = false;

  List<dynamic> _classes = [];
  final Map<int, List<StatutGenerationEleve>> _statutParClasse = {};
  bool _chargementClasses = false;

  Color get _couleurPrimaire => _depuisHex(_utilisateur?.couleurPrimaire, _indigo);
  Color get _couleurSecondaire => _depuisHex(_utilisateur?.couleurSecondaire, _teal);

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final utilisateur = await AuthService.getUtilisateur();
      final annees = await AnneeService.listerAnnees();
      if (!mounted) return;
      setState(() {
        _utilisateur = utilisateur;
        _annees = annees;
        _chargement = false;
      });
      await _resoudreSelectionActive();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  // Pré-sélectionne l'année et la période actives, comme les autres
  // modules_screen.dart — l'utilisateur peut toujours changer ensuite.
  Future<void> _resoudreSelectionActive() async {
    try {
      final data = await AnneeService.anneeActive();
      final annee = data['annee'] as Map<String, dynamic>?;
      final periodeActive = data['periode_active'] as Map<String, dynamic>?;
      final anneeId = annee?['id'] as int?;
      if (anneeId == null) return;

      final periodes = await AnneeService.listerPeriodes(anneeId);
      if (!mounted) return;
      setState(() {
        _anneeId = anneeId;
        _periodes = periodes;
        _periodeId = periodeActive?['id'] as int? ?? (periodes.isNotEmpty ? periodes.first['id'] as int : null);
      });

      if (_periodeId != null) _chargerDonneesPeriode();
    } catch (_) {
      // Les sélecteurs restent vides ; l'utilisateur choisit manuellement.
    }
  }

  Future<void> _changerAnnee(int? anneeId) async {
    if (anneeId == null) return;
    setState(() {
      _anneeId = anneeId;
      _periodeId = null;
      _periodes = [];
      _resume = null;
      _classes = [];
      _statutParClasse.clear();
    });
    try {
      final periodes = await AnneeService.listerPeriodes(anneeId);
      if (mounted) setState(() => _periodes = periodes);
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _changerPeriode(int? periodeId) {
    setState(() => _periodeId = periodeId);
    if (periodeId != null) _chargerDonneesPeriode();
  }

  Future<void> _chargerDonneesPeriode() async {
    final anneeId = _anneeId;
    final periodeId = _periodeId;
    if (anneeId == null || periodeId == null) return;

    setState(() {
      _chargementResume = true;
      _chargementClasses = true;
    });

    try {
      final resume = await BulletinService.getResumeDashboard(anneeScolaireId: anneeId, periodeId: periodeId);
      if (mounted) {
        setState(() {
          _resume = resume;
          _chargementResume = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _chargementResume = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }

    try {
      final classesGroupees = await ClasseService.lister(anneeId: anneeId);
      final classes = _aplatirClasses(classesGroupees);

      final statuts = await Future.wait(classes.map((c) => BulletinService
          .getStatutGeneration(classeId: c['id'] as int, periodeId: periodeId)
          .catchError((_) => <StatutGenerationEleve>[])));

      if (!mounted) return;
      setState(() {
        _classes = classes;
        _statutParClasse
          ..clear()
          ..addEntries(List.generate(classes.length, (i) => MapEntry(classes[i]['id'] as int, statuts[i])));
        _chargementClasses = false;
      });
    } catch (e) {
      if (mounted) setState(() => _chargementClasses = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // `GET /classes` renvoie les classes groupées par cycle (puis niveau,
  // puis série) — on aplatit récursivement, comme ClasseService.listerClasses().
  List<dynamic> _aplatirClasses(dynamic valeur) {
    final toutes = <dynamic>[];
    void parcourir(dynamic v) {
      if (v is List) {
        toutes.addAll(v);
      } else if (v is Map) {
        for (final sous in v.values) {
          parcourir(sous);
        }
      }
    }

    parcourir(valeur);
    return toutes;
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
      default: // directeur, comptable, super_admin
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

  void _ouvrirGeneration({int? classeId}) {
    if (_anneeId == null || _periodeId == null) {
      _afficherErreur('Sélectionnez une année et une période avant de générer des bulletins.');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GenerationBulletinScreen(
          anneeScolaireId: _anneeId!,
          periodeId: _periodeId!,
          classeIdInitiale: classeId,
        ),
      ),
    ).then((_) => _chargerDonneesPeriode());
  }

  void _ouvrirValidation() {
    if (_anneeId == null) {
      _afficherErreur('Sélectionnez une année scolaire.');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ValidationBulletinsScreen(anneeScolaireId: _anneeId!, periodeIdInitiale: _periodeId),
      ),
    ).then((_) => _chargerDonneesPeriode());
  }

  void _ouvrirHistoriqueRecherche() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoriqueRechercheBulletinsScreen()));
  }

  void _ouvrirStatistiques() {
    if (_anneeId == null) {
      _afficherErreur('Sélectionnez une année scolaire.');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StatistiquesBulletinsScreen(anneeScolaireId: _anneeId!, periodeIdInitiale: _periodeId),
      ),
    );
  }

  void _afficherErreur(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: _rouge),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _retour),
        title: Text('Bulletins', style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: Colors.white)),
        backgroundColor: _couleurPrimaire,
        foregroundColor: Colors.white,
      ),
      body: _chargement
          ? Center(child: CircularProgressIndicator(color: _couleurPrimaire))
          : _erreur != null
              ? _vueErreur()
              : RefreshIndicator(
                  onRefresh: _chargerDonneesPeriode,
                  child: Stack(
                    children: [
                      Positioned(top: -80, right: -60, child: _blob(size: 260, couleur: _couleurPrimaire.withValues(alpha: 0.08))),
                      Positioned(bottom: -60, left: -60, child: _blob(size: 200, couleur: _couleurSecondaire.withValues(alpha: 0.10))),
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _carteSelecteurs(),
                          const SizedBox(height: 16),
                          _grilleResume(),
                          const SizedBox(height: 16),
                          _boutonGenerer(),
                          const SizedBox(height: 16),
                          _boutonsNavigation(),
                          const SizedBox(height: 20),
                          SSMSectionTitre(titre: 'Classes'),
                          _listeClasses(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _vueErreur() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: _rouge, size: 40),
            const SizedBox(height: 12),
            Text(_erreur!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: _texte)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _charger,
              style: ElevatedButton.styleFrom(backgroundColor: _couleurPrimaire, foregroundColor: Colors.white),
              child: const Text('Réessayer'),
            ),
          ],
        ),
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

  Widget _carteGlass({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
            boxShadow: [
              BoxShadow(color: _texteFonce.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 5)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  // ── Sélecteurs année/période ────────────────────────────

  Widget _carteSelecteurs() {
    return _carteGlass(
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              value: _anneeId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Année scolaire',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: _annees
                  .map((a) => DropdownMenuItem<int>(value: a['id'] as int, child: Text(a['libelle'] as String)))
                  .toList(),
              onChanged: _changerAnnee,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<int>(
              value: _periodeId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Période',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: _periodes
                  .map((p) => DropdownMenuItem<int>(value: p['id'] as int, child: Text(p['nom'] as String)))
                  .toList(),
              onChanged: _periodes.isEmpty ? null : _changerPeriode,
            ),
          ),
        ],
      ),
    );
  }

  // ── Cards résumé ─────────────────────────────────────────

  Widget _grilleResume() {
    if (_chargementResume) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
    }
    final r = _resume;
    if (r == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Choisissez une année et une période pour voir le résumé.', style: GoogleFonts.inter(color: _gris)),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.5,
      children: [
        SSMStatCard(
          titre: 'Bulletins générés',
          valeur: '${r.bulletinsGeneres}',
          icone: Icons.description_outlined,
          couleurIcone: _couleurPrimaire,
        ),
        SSMStatCard(
          titre: 'Validés',
          valeur: '${r.bulletinsValides}',
          icone: Icons.verified_outlined,
          couleurIcone: _vert,
        ),
        SSMStatCard(
          titre: 'En attente de validation',
          valeur: '${r.bulletinsEnAttente}',
          icone: Icons.hourglass_bottom,
          couleurIcone: _ambre,
        ),
        SSMStatCard(
          titre: 'Classes concernées',
          valeur: '${r.classesConcernees}',
          icone: Icons.class_outlined,
          couleurIcone: _teal,
        ),
        SSMStatCard(
          titre: 'Non générés',
          valeur: '${r.bulletinsNonGeneres}',
          icone: Icons.error_outline,
          couleurIcone: _rouge,
        ),
        SSMStatCard(
          titre: 'Effectif total',
          valeur: '${r.effectifTotal}',
          icone: Icons.groups_outlined,
          couleurIcone: _texteFonce,
        ),
      ],
    );
  }

  // ── Actions ───────────────────────────────────────────────

  Widget _boutonGenerer() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _ouvrirGeneration(),
        style: ElevatedButton.styleFrom(
          backgroundColor: _couleurPrimaire,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        icon: const Icon(Icons.auto_awesome),
        label: Text('Générer des bulletins', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _boutonsNavigation() {
    return Row(
      children: [
        Expanded(
          child: SSMActionRapide(
            icone: Icons.playlist_add_check,
            label: 'Validation en attente',
            couleur: _ambre,
            onTap: _ouvrirValidation,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SSMActionRapide(
            icone: Icons.history,
            label: 'Historique & Recherche',
            couleur: _couleurSecondaire,
            onTap: _ouvrirHistoriqueRecherche,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SSMActionRapide(
            icone: Icons.bar_chart,
            label: 'Statistiques',
            couleur: _couleurPrimaire,
            onTap: _ouvrirStatistiques,
          ),
        ),
      ],
    );
  }

  // ── Liste des classes avec statut de génération ────────────

  Widget _listeClasses() {
    if (_chargementClasses) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
    }
    if (_classes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text('Aucune classe pour cette année scolaire.', style: GoogleFonts.inter(color: _gris)),
      );
    }

    return Column(
      children: _classes.map((c) {
        final classeId = c['id'] as int;
        final nom = c['nom'] as String? ?? '—';
        final statuts = _statutParClasse[classeId] ?? const [];
        final total = statuts.length;
        final genCount = statuts.where((s) => s.genere).length;

        final (label, couleur) = switch ((total, genCount)) {
          (0, _) => ('Aucun élève', _gris),
          (_, 0) => ('Non commencé', _gris),
          (var t, var g) when g == t => ('Terminé', _vert),
          _ => ('En cours $genCount/$total', _ambre),
        };

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _ouvrirGeneration(classeId: classeId),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _gris.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: couleur.withValues(alpha: 0.14), shape: BoxShape.circle),
                      child: Icon(Icons.class_outlined, color: couleur, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(nom, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: _texteFonce)),
                    ),
                    SSMBadge(label: label, couleur: couleur),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right, color: _gris, size: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
