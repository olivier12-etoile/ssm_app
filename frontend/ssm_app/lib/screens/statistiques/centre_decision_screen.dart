import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/statistique_detail_model.dart';
import '../../services/annee_service.dart';
import '../../services/statistique_detail_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_alert_item.dart';
import '../../widgets/ssm/ssm_sous_entete.dart';
import '../notes/analyse_performance_screen.dart';
import 'paiements_detail_screen.dart';
import 'pedagogique_detail_screen.dart';

SSMAlerteType _typeAlerte(String type) {
  switch (type) {
    case 'danger':
      return SSMAlerteType.danger;
    case 'warning':
      return SSMAlerteType.avertissement;
    default:
      return SSMAlerteType.succes;
  }
}

IconData _iconeAlerte(String type) {
  switch (type) {
    case 'danger':
      return Icons.error_outline;
    case 'warning':
      return Icons.warning_amber_rounded;
    default:
      return Icons.info_outline;
  }
}

Color _couleurAlerte(String type) {
  switch (type) {
    case 'danger':
      return SSMPalette.rouge;
    case 'warning':
      return SSMPalette.ambre;
    default:
      return SSMPalette.teal;
  }
}

// ══════════════════════════════════════════════════════════
// "Centre de Décision" du module Statistiques : liste des alertes
// actionnables générées par CentreDecisionService (backend), avec
// navigation contextuelle vers l'écran concerné selon `routeAction`.
// Même composant SSMAlertItem que le panneau "Alertes importantes" du
// tableau de bord directeur, pour une cohérence totale.
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
      backgroundColor: SSMPalette.fond,
      body: SafeArea(
        child: Column(
          children: [
            SSMSousEnTete(titre: 'Centre de Décision', onRetour: () => Navigator.pop(context)),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _charger,
                color: SSMPalette.indigo,
                child: _chargement && _erreur == null
                    ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
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
      ),
    );
  }

  Widget _vueErreur() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 80),
      children: [
        const Icon(Icons.error_outline, color: SSMPalette.rouge, size: 40),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(_erreur ?? '', textAlign: TextAlign.center, style: GoogleFonts.inter(color: SSMPalette.texte2)),
        ),
        const SizedBox(height: 16),
        Center(child: ElevatedButton(onPressed: _charger, child: const Text('Réessayer'))),
      ],
    );
  }

  // État vide "clair" : grand check central sur fond teal léger, signal
  // immédiat qu'aucune action n'est requise.
  Widget _vueOk() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 100),
      children: [
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(color: SSMPalette.tealClair, shape: BoxShape.circle),
            child: const Icon(Icons.check_circle, color: SSMPalette.teal, size: 48),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Tout est en ordre ✓',
          textAlign: TextAlign.center,
          style: GoogleFonts.sora(fontSize: 19, fontWeight: FontWeight.w700, color: SSMPalette.texte1),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            "Aucune alerte active pour l'année et la période sélectionnées.",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2),
          ),
        ),
      ],
    );
  }

  Widget _carteAlerte(Alerte alerte) {
    final couleur = _couleurAlerte(alerte.type);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(SSMRayons.petit + 2),
          onTap: () => _gererAction(alerte),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SSMAlertItem(
                      type: _typeAlerte(alerte.type),
                      icone: _iconeAlerte(alerte.type),
                      titre: alerte.titre,
                      sousTitre: alerte.description,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(alerte.valeurFormatee, style: GoogleFonts.jetBrainsMono(fontSize: 17, fontWeight: FontWeight.w700, color: couleur)),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 4),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${alerte.action} →',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: couleur),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
