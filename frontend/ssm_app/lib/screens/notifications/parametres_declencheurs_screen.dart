import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/notification_model.dart';
import '../../models/utilisateur.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_panel.dart';
import '../../widgets/ssm/ssm_sous_entete.dart';

const Map<String, String> _descriptions = {
  'notes_validees':
      "Envoie un message aux parents dès que toutes les matières d'une classe sont validées pour la période en cours.",
  'paiement_enregistre': "Envoie un message au parent à chaque paiement enregistré et validé.",
  'impaye': "Envoie un rappel aux parents des élèves en situation d'impayé (relance hebdomadaire automatique).",
  'bulletin_disponible': "Envoie un message au parent dès qu'un bulletin est généré pour son enfant.",
  'absence': "Envoie un message au parent lorsqu'une absence est enregistrée pour son enfant.",
};

const Map<String, IconData> _icones = {
  'notes_validees': Icons.fact_check_outlined,
  'paiement_enregistre': Icons.payments_outlined,
  'impaye': Icons.report_gmailerrorred_outlined,
  'bulletin_disponible': Icons.description_outlined,
  'absence': Icons.event_busy_outlined,
};

// ══════════════════════════════════════════════════════════
// Activation/désactivation des déclencheurs automatiques du
// module Notifications — accessible au directeur uniquement.
// ══════════════════════════════════════════════════════════
class ParametresDeclencheursScreen extends StatefulWidget {
  const ParametresDeclencheursScreen({super.key});

  @override
  State<ParametresDeclencheursScreen> createState() => _ParametresDeclencheursScreenState();
}

class _ParametresDeclencheursScreenState extends State<ParametresDeclencheursScreen> {
  Utilisateur? _utilisateur;
  List<ParametreDeclencheur> _declencheurs = [];
  bool _chargement = true;
  String? _erreur;
  final Set<String> _enCoursDeMaj = {};

  bool get _estAutorise => (_utilisateur?.estDirecteur ?? false) || (_utilisateur?.estSuperAdmin ?? false);

  @override
  void initState() {
    super.initState();
    _initialiser();
  }

  Future<void> _initialiser() async {
    final utilisateur = await AuthService.getUtilisateur();
    if (!mounted) return;
    setState(() => _utilisateur = utilisateur);

    if (!_estAutorise) {
      setState(() => _chargement = false);
      return;
    }
    await _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final declencheurs = await NotificationService.getParametresDeclencheurs();
      if (!mounted) return;
      setState(() {
        _declencheurs = declencheurs;
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

  Future<void> _basculer(ParametreDeclencheur declencheur, bool valeur) async {
    setState(() {
      _enCoursDeMaj.add(declencheur.cle);
      _declencheurs = _declencheurs
          .map((d) => d.cle == declencheur.cle
              ? ParametreDeclencheur(cle: d.cle, libelle: d.libelle, actif: valeur)
              : d)
          .toList();
    });

    try {
      await NotificationService.updateParametreDeclencheur(declencheur.cle, valeur);
    } catch (e) {
      setState(() {
        _declencheurs = _declencheurs
            .map((d) => d.cle == declencheur.cle
                ? ParametreDeclencheur(cle: d.cle, libelle: d.libelle, actif: !valeur)
                : d)
            .toList();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: SSMPalette.rouge),
        );
      }
    } finally {
      if (mounted) setState(() => _enCoursDeMaj.remove(declencheur.cle));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SSMPalette.fond,
      body: SafeArea(
        child: Column(
          children: [
            SSMSousEnTete(titre: 'Déclencheurs automatiques', onRetour: () => Navigator.pop(context)),
            Expanded(
              child: _chargement
                  ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
                  : !_estAutorise
                      ? _vueNonAutorise()
                      : _erreur != null
                          ? _vueErreur(_erreur!)
                          : RefreshIndicator(
                              onRefresh: _charger,
                              color: SSMPalette.indigo,
                              child: ListView(
                                padding: const EdgeInsets.all(16),
                                children: [
                                  Text(
                                    "Ces déclencheurs envoient automatiquement une notification WhatsApp aux parents "
                                    "lorsqu'un événement précis se produit dans les autres modules de SSM.",
                                    style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2, height: 1.4),
                                  ),
                                  const SizedBox(height: 16),
                                  for (final d in _declencheurs) ...[
                                    _carteDeclencheur(d),
                                    const SizedBox(height: 12),
                                  ],
                                ],
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vueNonAutorise() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, color: SSMPalette.texte3, size: 40),
            const SizedBox(height: 12),
            Text(
              'Seul le directeur peut configurer les déclencheurs automatiques.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: SSMPalette.texte2),
            ),
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
            const Icon(Icons.error_outline, color: SSMPalette.rouge, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: GoogleFonts.inter(color: SSMPalette.texte2)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _charger, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }

  Widget _carteDeclencheur(ParametreDeclencheur d) {
    final icone = _icones[d.cle] ?? Icons.notifications_active_outlined;
    final description = _descriptions[d.cle] ?? '';
    final enCours = _enCoursDeMaj.contains(d.cle);
    final couleurEtat = d.actif ? SSMPalette.teal : SSMPalette.texte3;

    return SSMPanel(
      titre: d.libelle,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: couleurEtat.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(SSMRayons.petit)),
            child: Icon(icone, color: couleurEtat, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: description.isEmpty
                ? const SizedBox.shrink()
                : Text(description, style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2, height: 1.4)),
          ),
          const SizedBox(width: 8),
          enCours
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: SSMPalette.indigo))
              : Switch(
                  value: d.actif,
                  activeThumbColor: SSMPalette.teal,
                  onChanged: (v) => _basculer(d, v),
                ),
        ],
      ),
    );
  }
}
