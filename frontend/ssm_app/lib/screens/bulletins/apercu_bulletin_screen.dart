import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/bulletin_model.dart';
import '../../models/parametre_ecole_model.dart';
import '../../services/bulletin_service.dart';
import '../../services/parametre_ecole_service.dart';
import '../../widgets/ssm_widgets.dart';
import '../../widgets/correction_bulletin_dialog.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _teal = Color(0xFF0D9488);
const Color _vert = Color(0xFF16A34A);
const Color _rouge = Color(0xFFDC2626);
const Color _gris = Color(0xFF94A3B8);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);

Color _depuisHex(String? hex, Color repli) {
  if (hex == null || hex.isEmpty) return repli;
  try {
    return Color(int.parse(hex.replaceAll('#', '0xFF')));
  } catch (_) {
    return repli;
  }
}

// ══════════════════════════════════════════════════════════
// Prévisualisation complète d'un bulletin avant/après validation.
//
// Important — pourquoi pas de tableau "matières" natif ici : aucun
// endpoint backend ne renvoie un Bulletin unique avec ses bulletin_details
// (GET /bulletins/{id} n'existe pas ; seuls génération/régénération/
// correction renvoient le bulletin complet, juste après l'action). On
// affiche donc le résumé déjà connu (rang, moyenne, statut, décision,
// absences/retards — transmis par l'écran appelant via [resume], ou
// récupéré après une correction) et on s'appuie sur le PDF officiel
// (déjà 100% fidèle au brief) pour le détail par matière, exactement
// comme recu_pdf_viewer.dart le fait déjà pour les reçus de paiement :
// téléchargement puis ouverture avec le lecteur PDF par défaut de
// l'appareil (aucun lecteur PDF intégré dans ce projet).
// ══════════════════════════════════════════════════════════
class ApercuBulletinScreen extends StatefulWidget {
  final int bulletinId;
  final Bulletin? resume;

  const ApercuBulletinScreen({super.key, required this.bulletinId, this.resume});

  @override
  State<ApercuBulletinScreen> createState() => _ApercuBulletinScreenState();
}

class _ApercuBulletinScreenState extends State<ApercuBulletinScreen> {
  Bulletin? _bulletin;
  InformationsEtablissement? _etablissement;
  IdentiteVisuelle? _identite;
  bool _chargement = true;

  bool _telechargementApercu = false;
  bool _telechargementOfficiel = false;
  bool _validationEnCours = false;

  Color get _couleurPrimaire => _depuisHex(_identite?.couleurPrincipale, _indigo);
  Color get _couleurEntetes => _depuisHex(_identite?.couleurEntetes ?? _identite?.couleurPrincipale, _indigo);

  @override
  void initState() {
    super.initState();
    _bulletin = widget.resume;
    _chargerIdentite();
  }

  // L'identité visuelle (logo, couleurs) est un habillage : si elle ne
  // charge pas, on retombe simplement sur les couleurs par défaut sans
  // bloquer l'aperçu du bulletin.
  Future<void> _chargerIdentite() async {
    try {
      final resultats = await Future.wait([
        ParametreEcoleService.getInformationsEtablissement(),
        ParametreEcoleService.getIdentiteVisuelle(),
      ]);
      if (!mounted) return;
      setState(() {
        _etablissement = resultats[0] as InformationsEtablissement;
        _identite = resultats[1] as IdentiteVisuelle;
        _chargement = false;
      });
    } catch (_) {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _telechargerEtOuvrir({required bool officiel}) async {
    setState(() {
      if (officiel) {
        _telechargementOfficiel = true;
      } else {
        _telechargementApercu = true;
      }
    });
    try {
      final octets = officiel
          ? await BulletinService.telechargerPdf(widget.bulletinId)
          : await BulletinService.telechargerApercu(widget.bulletinId);
      final dossier = await getTemporaryDirectory();
      final fichier = File('${dossier.path}/bulletin_${widget.bulletinId}.pdf');
      await fichier.writeAsBytes(octets);
      await OpenFile.open(fichier.path);
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _telechargementApercu = false;
          _telechargementOfficiel = false;
        });
      }
    }
  }

  Future<void> _validerBulletin() async {
    final bulletin = _bulletin;
    if (bulletin == null) return;
    setState(() => _validationEnCours = true);
    try {
      final maj = await BulletinService.validerBulletin(bulletin.id);
      if (mounted) setState(() => _bulletin = maj);
      _afficherSucces('Bulletin validé avec succès');
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _validationEnCours = false);
    }
  }

  // Correction (décision du conseil, appréciation générale, absences,
  // retards, ou note d'une matière) — ouvre le dialog dédié et partagé du
  // module (widgets/correction_bulletin_dialog.dart), qui affiche aussi
  // l'historique des corrections déjà enregistrées pour ce bulletin. Le
  // backend (CorrectionBulletinController) n'accepte les corrections que
  // sur un bulletin déjà "valide" — pas "genere" — puisque c'est le
  // mécanisme de correction tracée post-validation du module. Un bulletin
  // "genere" se corrige en le régénérant (écran de génération) plutôt
  // qu'ici.
  Future<void> _ouvrirCorrection() async {
    final bulletin = _bulletin;
    if (bulletin == null) return;

    final maj = await showCorrectionBulletinDialog(context, bulletin);
    if (maj != null) {
      if (mounted) setState(() => _bulletin = maj);
      _afficherSucces('Correction enregistrée');
    }
  }

  void _afficherErreur(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: _rouge));
  }

  void _afficherSucces(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: _vert));
  }

  @override
  Widget build(BuildContext context) {
    final bulletin = _bulletin;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Aperçu du bulletin', style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: Colors.white)),
        backgroundColor: _couleurPrimaire,
        foregroundColor: Colors.white,
        actions: [
          if (bulletin != null && bulletin.estValideOuVerrouille)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(child: _BadgeValide()),
            ),
        ],
      ),
      body: _chargement
          ? Center(child: CircularProgressIndicator(color: _couleurPrimaire))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _enTeteEcole(),
                const SizedBox(height: 16),
                if (bulletin != null) _carteInfosEleve(bulletin) else _carteBulletinMinimal(),
                if (bulletin != null) ...[
                  const SizedBox(height: 16),
                  _carteRecap(bulletin),
                  if (bulletin.decisionConseil != null) ...[
                    const SizedBox(height: 16),
                    _carteDecision(bulletin),
                  ],
                  const SizedBox(height: 16),
                  _cartePresence(bulletin),
                  if (!bulletin.appreciationGenerale.isNullOuVide) ...[
                    const SizedBox(height: 16),
                    _carteAppreciation(bulletin),
                  ],
                ],
                const SizedBox(height: 16),
                _carteApercuPdf(),
                const SizedBox(height: 20),
                _barreActions(bulletin),
              ],
            ),
    );
  }

  // ── En-tête école (logo, nom, couleurs identité visuelle) ────

  Widget _enTeteEcole() {
    final nom = _etablissement?.nomOfficiel ?? _etablissement?.nomCourt ?? 'Établissement';
    final logo = _identite?.logoPrincipal;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_couleurEntetes, _couleurEntetes.withValues(alpha: 0.8)]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              if (logo != null && logo.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(logo, width: 44, height: 44, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(Icons.school, color: Colors.white, size: 32)),
                ),
                const SizedBox(width: 12),
              ] else ...[
                const Icon(Icons.school, color: Colors.white, size: 32),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nom, style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                    if (_etablissement?.adresse != null)
                      Text(_etablissement!.adresse!, style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _carteBulletinMinimal() {
    return _carteGlass(
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: _gris),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Résumé indisponible pour ce bulletin (#${widget.bulletinId}) — utilisez le PDF ci-dessous pour le consulter.',
              style: GoogleFonts.inter(fontSize: 12, color: _texte),
            ),
          ),
        ],
      ),
    );
  }

  // ── Infos élève ───────────────────────────────────────────

  Widget _carteInfosEleve(Bulletin b) {
    return _carteGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(b.nomEleve ?? 'Élève #${b.eleveId}', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: _texteFonce)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              if (b.matriculeEleve != null) _infoLigne('Matricule', b.matriculeEleve!),
              _infoLigne('Classe', b.nomClasse ?? '—'),
              _infoLigne('Période', b.nomPeriode ?? '—'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoLigne(String label, String valeur) {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.inter(fontSize: 12, color: _texte),
        children: [
          TextSpan(text: '$label : ', style: const TextStyle(color: _gris)),
          TextSpan(text: valeur, style: const TextStyle(fontWeight: FontWeight.w600, color: _texteFonce)),
        ],
      ),
    );
  }

  // ── Moyenne / rang / statut ────────────────────────────────

  Widget _carteRecap(Bulletin b) {
    return _carteGlass(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Moyenne générale', style: GoogleFonts.inter(fontSize: 12, color: _texte)),
                const SizedBox(height: 4),
                Text(
                  '${b.moyenneGenerale.toStringAsFixed(2)}/20',
                  style: GoogleFonts.jetBrainsMono(fontSize: 24, fontWeight: FontWeight.w700, color: _couleurPrimaire),
                ),
                const SizedBox(height: 2),
                Text('Coeff. total ${b.totalCoefficients.toStringAsFixed(2)} — Points ${b.totalPoints.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(fontSize: 11, color: _gris)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (b.rang != null)
                Text(
                  '${b.rang}${b.rang == 1 ? 'er' : 'e'}${b.rangExAequo ? ' ex æquo' : ''}',
                  style: GoogleFonts.jetBrainsMono(fontSize: 18, fontWeight: FontWeight.w700, color: _texteFonce),
                ),
              Text('/ ${b.effectifClasse}', style: GoogleFonts.inter(fontSize: 11, color: _gris)),
              const SizedBox(height: 8),
              SSMBadge(label: b.statut.libelle, couleur: b.statut.couleur),
            ],
          ),
        ],
      ),
    );
  }

  Widget _carteDecision(Bulletin b) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(color: _couleurPrimaire, borderRadius: BorderRadius.circular(12)),
      child: Text(
        b.decisionConseil!.libelle.toUpperCase(),
        textAlign: TextAlign.center,
        style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5),
      ),
    );
  }

  Widget _cartePresence(Bulletin b) {
    return _carteGlass(
      child: Row(
        children: [
          _statPresence('Absences justifiées', b.absencesJustifiees, _vert),
          _statPresence('Absences non justifiées', b.absencesNonJustifiees, _rouge),
          _statPresence('Retards', b.retards, Colors.orange),
        ],
      ),
    );
  }

  Widget _statPresence(String label, int valeur, Color couleur) {
    return Expanded(
      child: Column(
        children: [
          Text('$valeur', style: GoogleFonts.jetBrainsMono(fontSize: 18, fontWeight: FontWeight.w700, color: couleur)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 10, color: _texte)),
        ],
      ),
    );
  }

  Widget _carteAppreciation(Bulletin b) {
    return _carteGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Appréciation générale', style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: _texteFonce)),
          const SizedBox(height: 6),
          Text(b.appreciationGenerale!, style: GoogleFonts.inter(fontSize: 13, color: _texte)),
        ],
      ),
    );
  }

  // ── PDF officiel (détail par matière complet) ────────────────

  Widget _carteApercuPdf() {
    return _carteGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.picture_as_pdf, color: _rouge),
              const SizedBox(width: 8),
              Text('Bulletin PDF complet', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: _texteFonce)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Le détail par matière (coefficients, notes, moyennes de classe, appréciations), les signatures et le cachet ne sont visibles que dans le PDF officiel.',
            style: GoogleFonts.inter(fontSize: 12, color: _texte),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _telechargementApercu ? null : () => _telechargerEtOuvrir(officiel: false),
              style: OutlinedButton.styleFrom(foregroundColor: _couleurPrimaire, side: BorderSide(color: _couleurPrimaire)),
              icon: _telechargementApercu
                  ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _couleurPrimaire))
                  : const Icon(Icons.visibility_outlined, size: 18),
              label: const Text("Ouvrir l'aperçu PDF"),
            ),
          ),
        ],
      ),
    );
  }

  // ── Barre d'actions ───────────────────────────────────────

  Widget _barreActions(Bulletin? bulletin) {
    return Column(
      children: [
        Row(
          children: [
            if (bulletin != null && bulletin.statut == StatutBulletin.valide)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _ouvrirCorrection,
                  style: OutlinedButton.styleFrom(foregroundColor: _couleurPrimaire, side: BorderSide(color: _couleurPrimaire)),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Demander une correction'),
                ),
              ),
            if (bulletin != null && bulletin.statut == StatutBulletin.valide) const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _telechargementOfficiel ? null : () => _telechargerEtOuvrir(officiel: true),
                style: ElevatedButton.styleFrom(backgroundColor: _teal, foregroundColor: Colors.white),
                icon: _telechargementOfficiel
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.download_outlined, size: 18),
                label: const Text('Télécharger PDF'),
              ),
            ),
          ],
        ),
        if (bulletin != null && bulletin.statut == StatutBulletin.genere) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _validationEnCours ? null : _validerBulletin,
              style: ElevatedButton.styleFrom(backgroundColor: _vert, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
              icon: _validationEnCours
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.verified_outlined),
              label: const Text('Valider ce bulletin'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _carteGlass({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
            boxShadow: [
              BoxShadow(color: _texteFonce.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 5)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _BadgeValide extends StatelessWidget {
  const _BadgeValide();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text('Validé', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
        ],
      ),
    );
  }
}

extension _NullOuVide on String? {
  bool get isNullOuVide => this == null || this!.trim().isEmpty;
}
