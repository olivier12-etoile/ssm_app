import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/utilisateur.dart';
import '../../models/parametre_ecole_model.dart';
import '../../services/auth_service.dart';
import '../../services/parametre_ecole_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_alert_item.dart';
import '../../widgets/ssm/ssm_panel.dart';
import '../../widgets/ssm/ssm_sous_entete.dart';

const Map<String, String> _libellesCibles = {
  'parents': 'Parents',
  'enseignants': 'Enseignants',
};

// ══════════════════════════════════════════════════════════
// Section Notifications : types de notifications acceptés par l'école,
// par destinataire (parents / enseignants).
// GET/PUT /parametres/notifications-ecole (ParametreNotificationEcoleController).
// Distinct des "déclencheurs automatiques" du module Notifications
// existant (/notifications/parametres-declencheurs) : ici on active ou
// désactive des TYPES d'événements, pas des automatisations techniques.
// Mêmes switches ssm que parametres_declencheurs_screen.dart du module
// Notifications, pour rester cohérent.
// ══════════════════════════════════════════════════════════
class NotificationsEcoleScreen extends StatefulWidget {
  const NotificationsEcoleScreen({super.key});

  @override
  State<NotificationsEcoleScreen> createState() => _NotificationsEcoleScreenState();
}

class _NotificationsEcoleScreenState extends State<NotificationsEcoleScreen> {
  Utilisateur? _utilisateur;
  Map<String, List<TypeNotificationEcole>> _types = {};

  bool _chargement = true;
  String? _erreur;
  String? _cleEnCours;

  bool get _lectureSeule => _utilisateur?.estDirecteur != true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final resultats = await Future.wait([
        AuthService.getUtilisateur(),
        ParametreEcoleService.getNotificationsEcole(),
      ]);
      if (!mounted) return;
      setState(() {
        _utilisateur = resultats[0] as Utilisateur?;
        _types = resultats[1] as Map<String, List<TypeNotificationEcole>>;
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

  Future<void> _basculer(String cible, TypeNotificationEcole type) async {
    final cleUnique = '$cible|${type.typeEvenement}';
    setState(() => _cleEnCours = cleUnique);

    final nouvelleValeur = !type.actif;
    try {
      await ParametreEcoleService.updateNotificationEcole(
        cible: cible,
        typeEvenement: type.typeEvenement,
        actif: nouvelleValeur,
      );
      if (!mounted) return;
      setState(() {
        _types = {
          ..._types,
          cible: _types[cible]!.map((t) => t.typeEvenement == type.typeEvenement ? t.copyWith(actif: nouvelleValeur) : t).toList(),
        };
        _cleEnCours = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cleEnCours = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: SSMPalette.rouge),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SSMPalette.fond,
      body: SafeArea(
        child: Column(
          children: [
            SSMSousEnTete(titre: 'Notifications', sousTitre: 'Types de notifications par destinataire', onRetour: () => Navigator.pop(context)),
            Expanded(
              child: _chargement
                  ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
                  : _erreur != null && _types.isEmpty
                      ? _carteErreur(_erreur!, _charger)
                      : RefreshIndicator(
                          onRefresh: _charger,
                          color: SSMPalette.indigo,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                            children: [
                              if (_lectureSeule) ...[
                                const SSMAlertItem(
                                  type: SSMAlerteType.avertissement,
                                  icone: Icons.lock_outline,
                                  titre: 'Lecture seule',
                                  sousTitre: 'Seul le directeur peut modifier ces réglages.',
                                ),
                                const SizedBox(height: 16),
                              ],
                              for (final cible in _libellesCibles.keys) ...[
                                _sectionCible(cible),
                                const SizedBox(height: 16),
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

  Widget _sectionCible(String cible) {
    final liste = _types[cible] ?? [];

    return SSMPanel(
      titre: _libellesCibles[cible]!,
      padding: EdgeInsets.zero,
      child: liste.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Aucun type disponible.', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
            )
          : Column(
              children: liste.map((type) => _ligneType(cible, type, dernier: type == liste.last)).toList(),
            ),
    );
  }

  Widget _ligneType(String cible, TypeNotificationEcole type, {required bool dernier}) {
    final enCours = _cleEnCours == '$cible|${type.typeEvenement}';

    return Container(
      decoration: BoxDecoration(border: dernier ? null : const Border(bottom: BorderSide(color: SSMPalette.bordure))),
      child: SwitchListTile(
        value: type.actif,
        activeThumbColor: SSMPalette.teal,
        title: Text(type.libelle, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
        secondary: enCours
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: SSMPalette.indigo))
            : null,
        onChanged: _lectureSeule || enCours ? null : (_) => _basculer(cible, type),
      ),
    );
  }

  Widget _carteErreur(String message, Future<void> Function() onReessayer) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: SSMPalette.rouge, size: 36),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center, style: GoogleFonts.inter(color: SSMPalette.texte2)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onReessayer, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
