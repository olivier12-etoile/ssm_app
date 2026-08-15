import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../../models/rapport_paiement_model.dart';
import '../../services/rapport_paiement_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_sous_entete.dart';
import 'impayes_classe_screen.dart';

// Rouge foncé — 4ème état "en retard", plus sévère que "non réglé". Reprend
// la même valeur que StatutFinancier.enRetard / ssm_statut_financier_badge.
const Color _rougeFonce = Color(0xFF991B1B);

String _formatMontant(double m) {
  final entier = m.round();
  final texte = entier.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < texte.length; i++) {
    if (i > 0 && (texte.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(texte[i]);
  }
  return '$buffer FCFA';
}

Color _couleurReste(SituationClasse s) {
  if (s.resteARecouvrer <= 0) return SSMPalette.teal;
  final ratio = s.montantAttendu > 0 ? s.resteARecouvrer / s.montantAttendu : 1.0;
  return ratio >= 0.3 ? SSMPalette.rouge : SSMPalette.ambre;
}

enum _TriSituation { reste, alphabetique }

// ══════════════════════════════════════════════════════════
// Vue "cards" — situation financière de toutes les classes
// ══════════════════════════════════════════════════════════
class SituationParClasseScreen extends StatefulWidget {
  const SituationParClasseScreen({super.key});

  @override
  State<SituationParClasseScreen> createState() => _SituationParClasseScreenState();
}

class _SituationParClasseScreenState extends State<SituationParClasseScreen> {
  List<SituationClasse> _situations = [];
  bool _chargement = true;
  String? _erreur;
  _TriSituation _tri = _TriSituation.reste;

  bool _exportConsolideEnCours = false;
  String? _exportCarteEnCours; // "$classeId-$format" pendant un export de card

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
      final situations = await RapportPaiementService.getToutesLesSituationsClasses();
      setState(() {
        _situations = situations;
        _chargement = false;
      });
    } catch (e) {
      setState(() {
        _chargement = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  List<SituationClasse> get _situationsTriees {
    final liste = [..._situations];
    if (_tri == _TriSituation.alphabetique) {
      liste.sort((a, b) => a.nomClasse.compareTo(b.nomClasse));
    } else {
      liste.sort((a, b) => b.resteARecouvrer.compareTo(a.resteARecouvrer));
    }
    return liste;
  }

  void _afficherErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: SSMPalette.rouge),
    );
  }

  // ── Export ────────────────────────────────────────────

  Future<void> _enregistrerEtOuvrir(List<int> octets, String nomFichier) async {
    final dossier = await getApplicationDocumentsDirectory();
    final chemin = '${dossier.path}/$nomFichier';
    await File(chemin).writeAsBytes(octets);
    await OpenFile.open(chemin);
  }

  Future<void> _exporterConsolide(String format) async {
    setState(() => _exportConsolideEnCours = true);
    try {
      final octets = format == 'excel'
          ? await RapportPaiementService.exportToutesSituationsExcel()
          : await RapportPaiementService.exportToutesSituationsPdf();
      await _enregistrerEtOuvrir(octets, 'situation_toutes_classes.${format == 'excel' ? 'xlsx' : 'pdf'}');
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _exportConsolideEnCours = false);
    }
  }

  Future<void> _exporterCarte(SituationClasse s, String format) async {
    final cle = '${s.classeId}-$format';
    setState(() => _exportCarteEnCours = cle);
    try {
      final octets = format == 'excel'
          ? await RapportPaiementService.exportSituationClasseExcel(s.classeId)
          : await RapportPaiementService.exportSituationClassePdf(s.classeId);
      final nomFichierSur = s.nomClasse.replaceAll(RegExp(r'\s+'), '_');
      await _enregistrerEtOuvrir(octets, 'situation_$nomFichierSur.${format == 'excel' ? 'xlsx' : 'pdf'}');
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _exportCarteEnCours = null);
    }
  }

  Future<void> _choisirExportConsolide() async {
    final format = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: SSMPalette.blanc,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Text('Exporter la vue consolidée', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined, color: SSMPalette.rouge),
              title: const Text('PDF'),
              onTap: () => Navigator.pop(context, 'pdf'),
            ),
            ListTile(
              leading: const Icon(Icons.grid_on_outlined, color: SSMPalette.teal),
              title: const Text('Excel'),
              onTap: () => Navigator.pop(context, 'excel'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (format != null) await _exporterConsolide(format);
  }

  void _voirImpayes(SituationClasse s) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImpayesClasseScreen(classeId: s.classeId, classeNom: s.nomClasse),
      ),
    );
  }

  // ══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SSMPalette.fond,
      body: SafeArea(
        child: Column(
          children: [
            SSMSousEnTete(
              titre: 'Situation par classe',
              onRetour: () => Navigator.pop(context),
              actions: [
                PopupMenuButton<_TriSituation>(
                  icon: const Icon(Icons.sort, color: SSMPalette.texte2),
                  tooltip: 'Trier',
                  onSelected: (valeur) => setState(() => _tri = valeur),
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: _TriSituation.reste, child: Text('Reste à recouvrer (décroissant)')),
                    PopupMenuItem(value: _TriSituation.alphabetique, child: Text('Ordre alphabétique')),
                  ],
                ),
              ],
            ),
            Expanded(
              child: _chargement
                  ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
                  : _erreur != null
                      ? _vueErreur()
                      : RefreshIndicator(
                          onRefresh: _charger,
                          color: SSMPalette.indigo,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _exportConsolideEnCours ? null : _choisirExportConsolide,
                                  icon: _exportConsolideEnCours
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Icon(Icons.ios_share, size: 18),
                                  label: const Text('Exporter vue consolidée'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: SSMPalette.indigo,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (_situations.isEmpty)
                                _messageVide('Aucune classe avec une situation financière calculable.')
                              else
                                LayoutBuilder(
                                  builder: (context, contraintes) {
                                    final colonnes = contraintes.maxWidth >= 900
                                        ? 3
                                        : contraintes.maxWidth >= 600
                                            ? 2
                                            : 1;
                                    return GridView.count(
                                      crossAxisCount: colonnes,
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      mainAxisSpacing: 14,
                                      crossAxisSpacing: 14,
                                      childAspectRatio: colonnes == 1 ? 1.55 : 1.15,
                                      children: _situationsTriees.map(_carteClasse).toList(),
                                    );
                                  },
                                ),
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
            Icon(Icons.error_outline, color: SSMPalette.rouge, size: 40),
            const SizedBox(height: 12),
            Text(_erreur!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: SSMPalette.texte2)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _charger,
              style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.indigo, foregroundColor: Colors.white, elevation: 0),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageVide(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(child: Text(message, style: GoogleFonts.inter(color: SSMPalette.texte3))),
    );
  }

  // ══════════════════════════════════════════════════════
  // Card par classe — structure ✓/⚠/✕ conservée, habillage plat
  // ══════════════════════════════════════════════════════

  Widget _carteClasse(SituationClasse s) {
    final couleurReste = _couleurReste(s);
    final exportPdfEnCours = _exportCarteEnCours == '${s.classeId}-pdf';
    final exportExcelEnCours = _exportCarteEnCours == '${s.classeId}-excel';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SSMPalette.blanc,
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        border: Border.all(color: SSMPalette.bordure),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.nomClasse,
            style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: SSMPalette.texte1),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text('${s.totalEleves} élève(s)', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte3)),
          const SizedBox(height: 10),
          _lignePastille(Icons.check_circle, SSMPalette.teal, 'En règle', s.nombreEnRegle),
          const SizedBox(height: 4),
          _lignePastille(Icons.error, SSMPalette.ambre, 'Partiels', s.nombrePartiels),
          const SizedBox(height: 4),
          _lignePastille(Icons.cancel, SSMPalette.rouge, 'Non réglés', s.nombreNonRegles),
          if (s.nombreEnRetard > 0) ...[
            const SizedBox(height: 4),
            _lignePastille(Icons.warning_amber_rounded, _rougeFonce, 'En retard', s.nombreEnRetard),
          ],
          const Spacer(),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: couleurReste.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(SSMRayons.moyen),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reste à recouvrer', style: GoogleFonts.inter(fontSize: 10, color: SSMPalette.texte3)),
                Text(
                  _formatMontant(s.resteARecouvrer),
                  style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.w700, color: couleurReste),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _voirImpayes(s),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SSMPalette.indigo,
                    side: const BorderSide(color: SSMPalette.indigo),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
                  ),
                  child: const Text('Voir', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 6),
              _boutonExportIcone(
                icone: Icons.picture_as_pdf_outlined,
                couleur: SSMPalette.rouge,
                enCours: exportPdfEnCours,
                onTap: () => _exporterCarte(s, 'pdf'),
              ),
              const SizedBox(width: 6),
              _boutonExportIcone(
                icone: Icons.grid_on_outlined,
                couleur: SSMPalette.teal,
                enCours: exportExcelEnCours,
                onTap: () => _exporterCarte(s, 'excel'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _lignePastille(IconData icone, Color couleur, String label, int valeur) {
    return Row(
      children: [
        Icon(icone, size: 14, color: couleur),
        const SizedBox(width: 6),
        Expanded(
          child: Text('$label : $valeur', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
        ),
      ],
    );
  }

  Widget _boutonExportIcone({
    required IconData icone,
    required Color couleur,
    required bool enCours,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 38,
      height: 34,
      child: OutlinedButton(
        onPressed: enCours ? null : onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: couleur,
          side: BorderSide(color: couleur.withValues(alpha: 0.5)),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
        ),
        child: enCours
            ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: couleur))
            : Icon(icone, size: 16),
      ),
    );
  }
}
