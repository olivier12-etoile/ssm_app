import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/bulletin_model.dart';
import '../../services/bulletin_service.dart';
import '../../widgets/ssm_widgets.dart';
import 'apercu_bulletin_screen.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _teal = Color(0xFF0D9488);
const Color _vert = Color(0xFF16A34A);
const Color _rouge = Color(0xFFDC2626);
const Color _gris = Color(0xFF94A3B8);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);

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
        title: const Text('Valider tous les bulletins ?'),
        content: Text('${_bulletins.length} bulletin(s) seront validés officiellement pour cette classe et cette période.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: _vert, foregroundColor: Colors.white),
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
        SnackBar(content: Text('$nombre bulletin(s) validé(s)'), backgroundColor: _vert),
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: _rouge));
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Bulletins de la classe', style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: Colors.white)),
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator(color: _indigo))
          : _erreur != null
              ? _vueErreur()
              : RefreshIndicator(
                  onRefresh: _charger,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _boutonsHaut(),
                      const SizedBox(height: 16),
                      if (_bulletins.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Text('Aucun bulletin généré pour cette classe et cette période.', style: GoogleFonts.inter(color: _gris)),
                          ),
                        )
                      else
                        ..._bulletins.map(_ligneBulletin),
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
              style: ElevatedButton.styleFrom(backgroundColor: _indigo, foregroundColor: Colors.white),
              child: const Text('Réessayer'),
            ),
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
              child: OutlinedButton.icon(
                onPressed: (_bulletins.isEmpty || _telechargementZip) ? null : _telechargerZip,
                style: OutlinedButton.styleFrom(foregroundColor: _indigo, side: const BorderSide(color: _indigo)),
                icon: _telechargementZip
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _indigo))
                    : const Icon(Icons.folder_zip_outlined, size: 18),
                label: const Text('Télécharger tous (ZIP)'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: (_bulletins.isEmpty || _telechargementGlobal) ? null : _telechargerRecapitulatif,
                style: OutlinedButton.styleFrom(foregroundColor: _teal, side: const BorderSide(color: _teal)),
                icon: _telechargementGlobal
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _teal))
                    : const Icon(Icons.summarize_outlined, size: 18),
                label: const Text('Récapitulatif classe'),
              ),
            ),
          ],
        ),
        if (_tousGeneresNonValides) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _validationEnCours ? null : _validerTous,
              style: ElevatedButton.styleFrom(backgroundColor: _vert, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
              icon: _validationEnCours
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.verified_outlined),
              label: const Text('Valider tous les bulletins'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _ligneBulletin(Bulletin b) {
    final rangAffiche = b.rang != null ? '${b.rang}${b.rangExAequo ? ' ex' : ''}' : '—';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _ouvrirApercu(b),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: (b.rang != null && b.rang! <= 3) ? Colors.amber.withValues(alpha: 0.5) : _gris.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: (b.rang != null && b.rang! <= 3) ? Colors.amber : _indigo.withValues(alpha: 0.1),
                  child: Text(
                    rangAffiche,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: (b.rang != null && b.rang! <= 3) ? Colors.white : _indigo,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    b.nomEleve ?? 'Élève #${b.eleveId}',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: _texteFonce),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${b.moyenneGenerale.toStringAsFixed(2)}/20',
                  style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700, color: _texteFonce),
                ),
                const SizedBox(width: 10),
                SSMBadge(label: b.statut.libelle, couleur: b.statut.couleur),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: _gris, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
