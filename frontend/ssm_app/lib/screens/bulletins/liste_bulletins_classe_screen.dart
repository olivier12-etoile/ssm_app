import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/bulletin_model.dart';
import '../../services/bulletin_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_data_table.dart';
import '../../widgets/ssm/ssm_pill.dart';
import '../../widgets/ssm/ssm_quick_action_button.dart';
import '../../widgets/ssm/ssm_sous_entete.dart';
import 'apercu_bulletin_screen.dart';

class ListeBulletinsClasseScreen extends StatefulWidget {
  final int classeId;
  final int periodeId;

  const ListeBulletinsClasseScreen({super.key, required this.classeId, required this.periodeId});

  @override
  State<ListeBulletinsClasseScreen> createState() => _ListeBulletinsClasseScreenState();
}

class _ListeBulletinsClasseScreenState extends State<ListeBulletinsClasseScreen> {
  List<Bulletin> _bulletins = [];
  bool _chargement = true;
  String? _erreur;

  bool _telechargementZip = false;
  bool _telechargementGlobal = false;
  bool _validationEnCours = false;

  bool get _tousGeneresNonValides =>
      _bulletins.isNotEmpty && _bulletins.every((b) => b.statut == StatutBulletin.genere);

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
      final bulletins = await BulletinService.listerBulletinsClasse(classeId: widget.classeId, periodeId: widget.periodeId);
      if (!mounted) return;
      setState(() {
        _bulletins = bulletins;
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

  Future<void> _telechargerEtOuvrir(Future<Uint8List> Function() action, String nomFichier) async {
    try {
      final octets = await action();
      final dossier = await getTemporaryDirectory();
      final fichier = File('${dossier.path}/$nomFichier');
      await fichier.writeAsBytes(octets);
      await OpenFile.open(fichier.path);
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _telechargerZip() async {
    setState(() => _telechargementZip = true);
    await _telechargerEtOuvrir(
      () => BulletinService.telechargerClasseZip(classeId: widget.classeId, periodeId: widget.periodeId),
      'bulletins_classe_${widget.classeId}_${widget.periodeId}.zip',
    );
    if (mounted) setState(() => _telechargementZip = false);
  }

  Future<void> _telechargerRecapitulatif() async {
    setState(() => _telechargementGlobal = true);
    await _telechargerEtOuvrir(
      () => BulletinService.telechargerGlobalClasse(classeId: widget.classeId, periodeId: widget.periodeId),
      'recapitulatif_classe_${widget.classeId}_${widget.periodeId}.pdf',
    );
    if (mounted) setState(() => _telechargementGlobal = false);
  }

  Future<void> _validerTous() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SSMPalette.blanc,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
        title: Text('Valider tous les bulletins ?', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
        content: Text(
          '${_bulletins.length} bulletin(s) seront validés officiellement pour cette classe et cette période.',
          style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Annuler', style: GoogleFonts.inter(color: SSMPalette.texte2))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.teal, foregroundColor: Colors.white, elevation: 0),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    if (confirme != true) return;

    setState(() => _validationEnCours = true);
    try {
      final nombre = await BulletinService.validerClasse(classeId: widget.classeId, periodeId: widget.periodeId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$nombre bulletin(s) validé(s)'), backgroundColor: SSMPalette.teal),
      );
      await _charger();
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _validationEnCours = false);
    }
  }

  void _afficherErreur(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: SSMPalette.rouge));
  }

  void _ouvrirApercu(Bulletin b) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ApercuBulletinScreen(bulletinId: b.id, resume: b)),
    ).then((_) => _charger());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SSMPalette.fond,
      body: SafeArea(
        child: Column(
          children: [
            SSMSousEnTete(titre: 'Bulletins de la classe', onRetour: () => Navigator.pop(context)),
            Expanded(
              child: _chargement
                  ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
                  : _erreur != null
                      ? _vueErreur()
                      : RefreshIndicator(
                          onRefresh: _charger,
                          color: SSMPalette.indigo,
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              _boutonsHaut(),
                              const SizedBox(height: 16),
                              if (_bulletins.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 40),
                                  child: Center(
                                    child: Text('Aucun bulletin généré pour cette classe et cette période.', style: GoogleFonts.inter(color: SSMPalette.texte3)),
                                  ),
                                )
                              else
                                LayoutBuilder(builder: (context, contraintes) {
                                  return contraintes.maxWidth >= 620 ? _tableauBulletins() : _listeCartes();
                                }),
                            ],
                          ),
                        ),
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
            const Icon(Icons.error_outline, color: SSMPalette.rouge, size: 40),
            const SizedBox(height: 12),
            Text(_erreur!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: SSMPalette.texte2)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _charger, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }

  Widget _boutonsHaut() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _telechargementZip
                  ? const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: SSMPalette.indigo)))
                  : SSMQuickActionButton(
                      icone: Icons.folder_zip_outlined,
                      label: 'Télécharger tous (ZIP)',
                      variante: SSMActionVariante.primaire,
                      onTap: _bulletins.isEmpty ? null : _telechargerZip,
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _telechargementGlobal
                  ? const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: SSMPalette.teal)))
                  : SSMQuickActionButton(
                      icone: Icons.summarize_outlined,
                      label: 'Récapitulatif classe',
                      variante: SSMActionVariante.teal,
                      onTap: _bulletins.isEmpty ? null : _telechargerRecapitulatif,
                    ),
            ),
          ],
        ),
        if (_tousGeneresNonValides) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: _validationEnCours
                ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: SSMPalette.teal)))
                : SSMQuickActionButton(
                    icone: Icons.verified_outlined,
                    label: 'Valider tous les bulletins',
                    variante: SSMActionVariante.teal,
                    onTap: _validerTous,
                  ),
          ),
        ],
      ],
    );
  }

  // ── Tableau (desktop large) ────────────────────────────────

  Widget _tableauBulletins() {
    return SSMDataTable(
      colonnes: const [
        SSMDataColumn('Rang'),
        SSMDataColumn('Élève'),
        SSMDataColumn('Moyenne'),
        SSMDataColumn('Statut'),
      ],
      onLigneTap: (i) => _ouvrirApercu(_bulletins[i]),
      lignes: [
        for (final b in _bulletins)
          [
            Text(b.rang != null ? '${b.rang}${b.rangExAequo ? ' ex' : ''}' : '—',
                style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
            Text(b.nomEleve ?? 'Élève #${b.eleveId}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
            Text('${b.moyenneGenerale.toStringAsFixed(2)}/20', style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700, color: SSMPalette.texte1)),
            SSMPill.couleur(label: b.statut.libelle, couleur: b.statut.couleur),
          ],
      ],
    );
  }

  // ── Cartes (mobile / tablette étroite) ─────────────────────

  Widget _listeCartes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final b in _bulletins) _carteBulletin(b)],
    );
  }

  Widget _carteBulletin(Bulletin b) {
    final rangAffiche = b.rang != null ? '${b.rang}${b.rangExAequo ? ' ex' : ''}' : '—';
    return Material(
      color: SSMPalette.blanc,
      borderRadius: BorderRadius.circular(SSMRayons.grand),
      child: InkWell(
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        onTap: () => _ouvrirApercu(b),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SSMRayons.grand),
            border: Border.all(color: SSMPalette.bordure),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: SSMPalette.indigo.withValues(alpha: 0.1), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(rangAffiche, style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  b.nomEleve ?? 'Élève #${b.eleveId}',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: SSMPalette.texte1),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('${b.moyenneGenerale.toStringAsFixed(2)}/20', style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700, color: SSMPalette.texte1)),
              const SizedBox(width: 10),
              SSMPill.couleur(label: b.statut.libelle, couleur: b.statut.couleur),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: SSMPalette.texte3, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
