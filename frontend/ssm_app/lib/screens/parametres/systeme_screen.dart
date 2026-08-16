import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/permission_securite_model.dart';
import '../../services/permission_securite_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_panel.dart';
import '../../widgets/ssm/ssm_sous_entete.dart';
import '../../widgets/ssm/ssm_stat_card.dart';

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
      backgroundColor: SSMPalette.fond,
      body: SafeArea(
        child: Column(
          children: [
            SSMSousEnTete(titre: 'Système', sousTitre: 'Version, serveur et synchronisation', onRetour: () => Navigator.pop(context)),
            Expanded(
              child: _chargement
                  ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
                  : _erreur != null && _statut == null
                      ? _carteErreur(_erreur!, _charger)
                      : RefreshIndicator(onRefresh: _charger, color: SSMPalette.indigo, child: _corps()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _corps() {
    final statut = _statut!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _titreSection('État général'),
        LayoutBuilder(builder: (context, contraintes) {
          final colonnes = contraintes.maxWidth >= 900 ? 4 : (contraintes.maxWidth >= 560 ? 2 : 1);
          final cartes = [
            SSMStatCard(icone: Icons.info_outline, couleur: SSMPalette.indigo, valeur: statut.version, label: 'Version SSM'),
            SSMStatCard(
              icone: Icons.dns_outlined,
              couleur: statut.serveurOperationnel ? SSMPalette.teal : SSMPalette.rouge,
              valeur: statut.serveurOperationnel ? 'Actif' : 'Indisponible',
              label: 'Serveur',
            ),
            SSMStatCard(
              icone: Icons.storage_outlined,
              couleur: statut.baseDonneesOperationnelle ? SSMPalette.teal : SSMPalette.rouge,
              valeur: statut.baseDonneesOperationnelle ? 'Actif' : 'Indisponible',
              label: 'Base de données',
            ),
            SSMStatCard(
              icone: Icons.sync,
              couleur: statut.synchronisationAJour ? SSMPalette.teal : SSMPalette.ambre,
              valeur: statut.synchronisationAJour ? 'À jour' : 'En attente',
              label: 'Synchronisation',
            ),
          ];
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cartes.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: colonnes,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 168,
            ),
            itemBuilder: (context, i) => cartes[i],
          );
        }),
        const SizedBox(height: 20),
        _titreSection('Sauvegarde'),
        SSMPanel(titre: 'Dernière sauvegarde', child: _contenuSauvegarde()),
        const SizedBox(height: 16),
        Text(
          'Tirez vers le bas pour re-vérifier le statut.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte3),
        ),
      ],
    );
  }

  Widget _contenuSauvegarde() {
    final sauvegarde = _sauvegarde;
    if (sauvegarde == null) {
      return Row(
        children: [
          const Icon(Icons.info_outline, color: SSMPalette.texte3),
          const SizedBox(width: 10),
          Expanded(child: Text('Aucune information de sauvegarde disponible pour le moment.', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2))),
        ],
      );
    }

    final (icone, couleur, libelle) = switch (sauvegarde.statut) {
      'reussie' => (Icons.check_circle, SSMPalette.teal, 'Réussie'),
      'echouee' => (Icons.error, SSMPalette.rouge, 'Échouée'),
      _ => (Icons.hourglass_top, SSMPalette.ambre, 'En cours'),
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
                  Text(libelle, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: SSMPalette.texte1)),
                  Text('Dernière sauvegarde : ${_formatDateHeure(sauvegarde.dateDerniereSauvegarde)}', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: SSMPalette.texte2)),
                ],
              ),
            ),
          ],
        ),
        if (sauvegarde.tailleFichier != null) ...[
          const SizedBox(height: 8),
          Text('Taille : ${_formatTaille(sauvegarde.tailleFichier)}', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: SSMPalette.texte2)),
        ],
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: SSMPalette.indigoClair, borderRadius: BorderRadius.circular(SSMRayons.petit)),
          child: Text(
            "La sauvegarde de la base de données est gérée automatiquement par l'infrastructure d'hébergement.",
            style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte2),
          ),
        ),
      ],
    );
  }

  Widget _titreSection(String titre) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(titre.toUpperCase(), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: SSMPalette.indigo, letterSpacing: 0.4)),
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
