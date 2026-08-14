import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/statistique_detail_model.dart';
import '../../services/annee_service.dart';
import '../../services/statistique_detail_service.dart';
import '../notes/analyse_performance_screen.dart';
import 'paiements_detail_screen.dart';
import 'pedagogique_detail_screen.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _teal = Color(0xFF0D9488);
const Color _bleuInfo = Color(0xFF0284C7);
const Color _ambre = Color(0xFFD97706);
const Color _vert = Color(0xFF16A34A);
const Color _rouge = Color(0xFFDC2626);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);
const Color _fond = Color(0xFFEFF6FF);

Color _couleurType(String type) {
  switch (type) {
    case 'danger':
      return _rouge;
    case 'warning':
      return _ambre;
    default:
      return _bleuInfo;
  }
}

IconData _iconeType(String type) {
  switch (type) {
    case 'danger':
      return Icons.error_outline;
    case 'warning':
      return Icons.warning_amber_rounded;
    default:
      return Icons.info_outline;
  }
}

// ══════════════════════════════════════════════════════════
// "Centre de Décision" du module Statistiques (Phase 5) : liste des alertes
// actionnables générées par CentreDecisionService (backend), avec
// navigation contextuelle vers l'écran concerné selon `routeAction`.
// ══════════════════════════════════════════════════════════
class CentreDecisionScreen extends StatefulWidget {
  final int? anneeScolaireId;
  final int? periodeId;

  const CentreDecisionScreen({super.key, this.anneeScolaireId, this.periodeId});

  @override
  State<CentreDecisionScreen> createState() => _CentreDecisionScreenState();
}

class _CentreDecisionScreenState extends State<CentreDecisionScreen> {
  int? _anneeId;
  int? _periodeId;

  List<Alerte> _alertes = [];
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _initialiser();
  }

  Future<void> _initialiser() async {
    try {
      var anneeId = widget.anneeScolaireId;
      var periodeId = widget.periodeId;

      if (anneeId == null || periodeId == null) {
        final data = await AnneeService.anneeActive();
        final annee = data['annee'] as Map<String, dynamic>?;
        final periodeActive = data['periode_active'] as Map<String, dynamic>?;
        anneeId ??= annee?['id'] as int?;
        periodeId ??= periodeActive?['id'] as int?;

        if (periodeId == null && anneeId != null) {
          final periodes = await AnneeService.listerPeriodes(anneeId);
          if (periodes.isNotEmpty) periodeId = periodes.first['id'] as int;
        }
      }

      if (!mounted) return;
      setState(() {
        _anneeId = anneeId;
        _periodeId = periodeId;
      });
      await _charger();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _charger() async {
    if (_anneeId == null || _periodeId == null) {
      setState(() => _chargement = false);
      return;
    }
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final alertes = await StatistiqueDetailService.getAlertes(anneeScolaireId: _anneeId!, periodeId: _periodeId!);
      if (!mounted) return;
      setState(() {
        _alertes = alertes;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  // Interprète `routeAction` (un chemin d'API, ex:
  // "/statistiques/paiements/eleves-non-en-regle?annee_scolaire_id=3") pour
  // choisir l'écran Flutter le plus pertinent — il n'y a pas de
  // correspondance 1:1 route API ↔ route Flutter, donc on fait
  // correspondre par préfixe plutôt que par égalité stricte.
  void _gererAction(Alerte alerte) {
    final uri = Uri.tryParse(alerte.routeAction);
    if (uri == null) {
      _actionIndisponible();
      return;
    }
    final chemin = uri.path;
    final params = uri.queryParameters;
    final anneeScolaireId = int.tryParse(params['annee_scolaire_id'] ?? '');
    final periodeId = int.tryParse(params['periode_id'] ?? '');
    final seuil = double.tryParse(params['seuil'] ?? '');

    if (chemin.contains('/paiements/eleves-non-en-regle')) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => PaiementsDetailScreen(anneeScolaireId: anneeScolaireId ?? _anneeId)));
      return;
    }

    if (chemin.contains('/notes/analyse/enseignants-en-retard')) {
      if (periodeId == null) {
        _actionIndisponible();
        return;
      }
      Navigator.push(context, MaterialPageRoute(builder: (_) => AnalysePerformanceScreen(periodeId: periodeId)));
      return;
    }

    if (chemin.contains('/pedagogique/eleves-en-difficulte')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PedagogiqueDetailScreen(periodeId: periodeId ?? _periodeId, initialTabIndex: 3)),
      );
      return;
    }

    if (chemin.contains('/pedagogique/par-classe')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PedagogiqueDetailScreen(periodeId: periodeId ?? _periodeId, initialTabIndex: 2)),
      );
      return;
    }

    if (chemin.contains('/emploi-du-temps')) {
      Navigator.pushNamed(context, '/emploi-du-temps');
      return;
    }

    if (chemin.contains('/annees/')) {
      Navigator.pushNamed(context, '/directeur/annees');
      return;
    }

    // Pas de correspondance connue (ex: seuil transmis mais action générique) :
    // on tente quand même le seuil s'il est présent, sinon message générique.
    if (seuil != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PedagogiqueDetailScreen(periodeId: periodeId ?? _periodeId, initialTabIndex: 3)),
      );
      return;
    }

    _actionIndisponible();
  }

  void _actionIndisponible() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Action non disponible pour cette alerte.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fond,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: Text('Centre de Décision', style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: Colors.white)),
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Positioned(top: -80, right: -60, child: _blob(size: 240, couleur: _indigo.withValues(alpha: 0.08))),
          Positioned(bottom: -60, left: -60, child: _blob(size: 200, couleur: _teal.withValues(alpha: 0.10))),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _charger,
              child: _chargement && _erreur == null
                  ? const Center(child: CircularProgressIndicator(color: _indigo))
                  : _erreur != null
                      ? _vueErreur()
                      : _alertes.isEmpty
                          ? _vueOk()
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _alertes.length,
                              itemBuilder: (context, index) => _carteAlerte(_alertes[index]),
                            ),
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
        child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: couleur)),
      ),
    );
  }

  Widget _vueErreur() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 80),
      children: [
        const Icon(Icons.error_outline, color: _rouge, size: 40),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(_erreur ?? '', textAlign: TextAlign.center, style: GoogleFonts.inter(color: _texte)),
        ),
        const SizedBox(height: 16),
        Center(
          child: ElevatedButton(
            onPressed: _charger,
            style: ElevatedButton.styleFrom(backgroundColor: _indigo, foregroundColor: Colors.white),
            child: const Text('Réessayer'),
          ),
        ),
      ],
    );
  }

  Widget _vueOk() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 100),
      children: [
        const Icon(Icons.check_circle, color: _vert, size: 64),
        const SizedBox(height: 16),
        Text(
          'Tout est en ordre ✓',
          textAlign: TextAlign.center,
          style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700, color: _texteFonce),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            "Aucune alerte active pour l'année et la période sélectionnées.",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: _texte),
          ),
        ),
      ],
    );
  }

  Widget _carteAlerte(Alerte alerte) {
    final couleur = _couleurType(alerte.type);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(14),
            border: Border(left: BorderSide(color: couleur, width: 4)),
            boxShadow: [BoxShadow(color: _texteFonce.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: couleur.withValues(alpha: 0.14), shape: BoxShape.circle),
                    child: Icon(_iconeType(alerte.type), color: couleur, size: 19),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(alerte.titre, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: _texteFonce)),
                        const SizedBox(height: 4),
                        Text(alerte.description, style: GoogleFonts.inter(fontSize: 12, color: _texte)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(alerte.valeurFormatee, style: GoogleFonts.jetBrainsMono(fontSize: 18, fontWeight: FontWeight.w700, color: couleur)),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => _gererAction(alerte),
                  style: OutlinedButton.styleFrom(foregroundColor: couleur, side: BorderSide(color: couleur)),
                  icon: const Icon(Icons.arrow_forward, size: 15),
                  label: Text(alerte.action, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
