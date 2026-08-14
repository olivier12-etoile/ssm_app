import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/utilisateur.dart';
import '../../models/parametre_ecole_model.dart';
import '../../services/auth_service.dart';
import '../../services/parametre_ecole_service.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _teal = Color(0xFF0D9488);
const Color _rouge = Color(0xFFDC2626);
const Color _ambre = Color(0xFFD97706);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);
const Color _fond = Color(0xFFEFF6FF);

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
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: _rouge),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fond,
      appBar: AppBar(
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
        title: Text('Notifications', style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator(color: _indigo))
          : _erreur != null && _types.isEmpty
              ? _carteErreur(_erreur!, _charger)
              : RefreshIndicator(
                  onRefresh: _charger,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      if (_lectureSeule) ...[_bandeauLectureSeule(), const SizedBox(height: 16)],
                      for (final cible in _libellesCibles.keys) ...[
                        _sectionCible(cible),
                        const SizedBox(height: 20),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _sectionCible(String cible) {
    final liste = _types[cible] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(cible == 'parents' ? Icons.family_restroom_outlined : Icons.school_outlined, color: _indigo, size: 18),
            const SizedBox(width: 8),
            Text(_libellesCibles[cible]!.toUpperCase(), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _indigo, letterSpacing: 0.4)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: liste.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Aucun type disponible.', style: GoogleFonts.inter(fontSize: 12, color: _texte)),
                )
              : Column(
                  children: liste
                      .map((type) => _ligneType(cible, type, dernier: type == liste.last))
                      .toList(),
                ),
        ),
      ],
    );
  }

  Widget _ligneType(String cible, TypeNotificationEcole type, {required bool dernier}) {
    final enCours = _cleEnCours == '$cible|${type.typeEvenement}';

    return Container(
      decoration: BoxDecoration(
        border: dernier ? null : Border(bottom: BorderSide(color: const Color(0xFFE2E8F0).withValues(alpha: 0.7))),
      ),
      child: SwitchListTile(
        value: type.actif,
        activeThumbColor: _teal,
        title: Text(type.libelle, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _texteFonce)),
        secondary: enCours
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _indigo))
            : null,
        onChanged: _lectureSeule || enCours ? null : (_) => _basculer(cible, type),
      ),
    );
  }

  Widget _bandeauLectureSeule() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _ambre.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10), border: Border.all(color: _ambre.withValues(alpha: 0.3))),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: _ambre, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text('Lecture seule — seul le directeur peut modifier ces réglages.', style: GoogleFonts.inter(fontSize: 12, color: _texte))),
        ],
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
            const Icon(Icons.error_outline, color: _rouge, size: 36),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center, style: GoogleFonts.inter(color: _texte)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onReessayer,
              style: ElevatedButton.styleFrom(backgroundColor: _indigo, foregroundColor: Colors.white),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
