import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/permission_securite_model.dart';
import '../../services/permission_securite_service.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _rouge = Color(0xFFDC2626);
const Color _vert = Color(0xFF16A34A);
const Color _ambre = Color(0xFFD97706);
const Color _gris = Color(0xFF94A3B8);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);
const Color _fond = Color(0xFFEFF6FF);

String _formatDateHeure(DateTime? d) {
  if (d == null) return '—';
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} à '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

String _formatTaille(int? octets) {
  if (octets == null) return '—';
  if (octets < 1024 * 1024) return '${(octets / 1024).toStringAsFixed(0)} Ko';
  return '${(octets / (1024 * 1024)).toStringAsFixed(1)} Mo';
}

// ══════════════════════════════════════════════════════════
// Section Système : version, état serveur/base de données/synchronisation,
// statut de la dernière sauvegarde.
// GET /parametres/systeme/statut, GET /parametres/systeme/sauvegarde
// (SystemeController). La sauvegarde réelle de la base est gérée par
// l'infrastructure (Railway) — cet écran est purement informatif.
// ══════════════════════════════════════════════════════════
class SystemeScreen extends StatefulWidget {
  const SystemeScreen({super.key});

  @override
  State<SystemeScreen> createState() => _SystemeScreenState();
}

class _SystemeScreenState extends State<SystemeScreen> {
  StatutSysteme? _statut;
  SauvegardeInfo? _sauvegarde;
  bool _chargement = true;
  String? _erreur;

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
        PermissionSecuriteService.getStatutSysteme(),
        PermissionSecuriteService.getSauvegardeInfo(),
      ]);
      if (!mounted) return;
      setState(() {
        _statut = resultats[0] as StatutSysteme;
        _sauvegarde = resultats[1] as SauvegardeInfo?;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fond,
      appBar: AppBar(
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
        title: Text('Système', style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator(color: _indigo))
          : _erreur != null && _statut == null
              ? _carteErreur(_erreur!, _charger)
              : RefreshIndicator(onRefresh: _charger, child: _corps()),
    );
  }

  Widget _corps() {
    final statut = _statut!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _titreSection('État général'),
        _carteBlanche(
          child: Column(
            children: [
              _ligneEtat('Version SSM', statut.version, couleur: _indigo, icone: Icons.info_outline, mono: true),
              const Divider(height: 20),
              _ligneStatut('Serveur', statut.serveurOperationnel, libelleOk: 'Opérationnel', libelleKo: 'Indisponible'),
              const Divider(height: 20),
              _ligneStatut('Base de données', statut.baseDonneesOperationnelle, libelleOk: 'Opérationnelle', libelleKo: 'Indisponible'),
              const Divider(height: 20),
              _ligneStatut('Synchronisation', statut.synchronisationAJour, libelleOk: 'À jour', libelleKo: 'En attente'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _titreSection('Sauvegarde'),
        _carteBlanche(child: _contenuSauvegarde()),
        const SizedBox(height: 16),
        Text(
          'Tirez vers le bas pour re-vérifier le statut.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 11, color: _gris),
        ),
      ],
    );
  }

  Widget _contenuSauvegarde() {
    final sauvegarde = _sauvegarde;
    if (sauvegarde == null) {
      return Row(
        children: [
          const Icon(Icons.info_outline, color: _gris),
          const SizedBox(width: 10),
          Expanded(child: Text('Aucune information de sauvegarde disponible pour le moment.', style: GoogleFonts.inter(fontSize: 12, color: _texte))),
        ],
      );
    }

    final (icone, couleur, libelle) = switch (sauvegarde.statut) {
      'reussie' => (Icons.check_circle, _vert, 'Réussie'),
      'echouee' => (Icons.error, _rouge, 'Échouée'),
      _ => (Icons.hourglass_top, _ambre, 'En cours'),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icone, color: couleur, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(libelle, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: _texteFonce)),
                  Text('Dernière sauvegarde : ${_formatDateHeure(sauvegarde.dateDerniereSauvegarde)}', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: _texte)),
                ],
              ),
            ),
          ],
        ),
        if (sauvegarde.tailleFichier != null) ...[
          const SizedBox(height: 8),
          Text('Taille : ${_formatTaille(sauvegarde.tailleFichier)}', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: _texte)),
        ],
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: _indigo.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)),
          child: Text(
            "La sauvegarde de la base de données est gérée automatiquement par l'infrastructure d'hébergement.",
            style: GoogleFonts.inter(fontSize: 11, color: _texte),
          ),
        ),
      ],
    );
  }

  Widget _ligneEtat(String label, String valeur, {required Color couleur, required IconData icone, bool mono = false}) {
    return Row(
      children: [
        Icon(icone, color: couleur, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 13, color: _texte))),
        Text(
          valeur,
          style: mono
              ? GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700, color: _texteFonce)
              : GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _texteFonce),
        ),
      ],
    );
  }

  Widget _ligneStatut(String label, bool ok, {required String libelleOk, required String libelleKo}) {
    final couleur = ok ? _vert : _rouge;
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: couleur, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 13, color: _texte))),
        Text(ok ? libelleOk : libelleKo, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: couleur)),
      ],
    );
  }

  Widget _titreSection(String titre) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(titre.toUpperCase(), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _indigo, letterSpacing: 0.4)),
    );
  }

  Widget _carteBlanche({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: child,
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
