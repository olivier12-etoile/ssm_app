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
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_pill.dart';
import '../../widgets/ssm/ssm_quick_action_button.dart';
import '../../widgets/ssm/ssm_sous_entete.dart';
import '../../widgets/correction_bulletin_dialog.dart';

const Color _indigo = Color(0xFF1E3A8A);
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
// IMPORTANT — seul l'écran AUTOUR du bulletin (bandeau de navigation,
// badge de statut, barre d'actions) est migré vers le design system
// flat/clean de l'application (SSMSousEnTete, SSMPill, SSMQuickActionButton).
// La zone d'affichage du bulletin lui-même (en-tête école, infos élève,
// récap, décision, présence, appréciation, aperçu PDF) reste pilotée par
// l'identité visuelle propre de l'école (logo, couleurs définies dans
// Paramètres → Identité visuelle) — c'est un document officiel, pas un
// écran de gestion, voir CLAUDE.md "Marque blanche". Son style n'est donc
// pas modifié ici.
//
// Pourquoi pas de tableau "matières" natif ici : aucun endpoint backend ne
// renvoie un Bulletin unique avec ses bulletin_details (GET /bulletins/{id}
// n'existe pas ; seuls génération/régénération/correction renvoient le
// bulletin complet, juste après l'action). On affiche donc le résumé déjà
// connu (rang, moyenne, statut, décision, absences/retards — transmis par
// l'écran appelant via [resume], ou récupéré après une correction) et on
// s'appuie sur le PDF officiel (déjà 100% fidèle au brief) pour le détail
// par matière, exactement comme recu_pdf_viewer.dart le fait déjà pour les
// reçus de paiement : téléchargement puis ouverture avec le lecteur PDF par
// défaut de l'appareil (aucun lecteur PDF intégré dans ce projet).
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: SSMPalette.rouge));
  }

  void _afficherSucces(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: SSMPalette.teal));
  }

  @override
  Widget build(BuildContext context) {
    final bulletin = _bulletin;

    return Scaffold(
      backgroundColor: SSMPalette.fond,
      body: SafeArea(
        child: Column(
          children: [
            SSMSousEnTete(
              titre: 'Aperçu du bulletin',
              sousTitre: bulletin?.nomEleve,
              onRetour: () => Navigator.pop(context),
              actions: bulletin != null && bulletin.estValideOuVerrouille
                  ? [
                      Padding(
                        padding: const EdgeInsets.only(right: 12, top: 10),
                        child: SSMPill.couleur(label: '✓ Validé', couleur: SSMPalette.teal),
                      ),
                    ]
                  : null,
            ),
            Expanded(
              child: _chargement
                  ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
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
            ),
          ],
        ),
      ),
    );
  }

  // ── Zone d'affichage du bulletin — identité visuelle de l'école,
  // volontairement non migrée vers le thème indigo/teal/amber (voir
  // commentaire d'en-tête du fichier). ────────────────────────────

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
              _badgeStatut(b),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badgeStatut(Bulletin b) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(color: b.statut.couleur.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(b.statut.libelle, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: b.statut.couleur)),
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
          _statPresence('Absences justifiées', b.absencesJustifiees, const Color(0xFF16A34A)),
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

  Widget _carteApercuPdf() {
    return _carteGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.picture_as_pdf, color: _rouge),
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
            child: _telechargementApercu
                ? const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _indigo)))
                : SSMQuickActionButton(
                    icone: Icons.visibility_outlined,
                    label: "Ouvrir l'aperçu PDF",
                    variante: SSMActionVariante.primaire,
                    onTap: () => _telechargerEtOuvrir(officiel: false),
                  ),
          ),
        ],
      ),
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

  // ── Barre d'actions — chrome, design system ─────────────────

  Widget _barreActions(Bulletin? bulletin) {
    return Column(
      children: [
        Row(
          children: [
            if (bulletin != null && bulletin.statut == StatutBulletin.valide) ...[
              Expanded(
                child: SSMQuickActionButton(
                  icone: Icons.edit_outlined,
                  label: 'Demander une correction',
                  variante: SSMActionVariante.gris,
                  onTap: _ouvrirCorrection,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: _telechargementOfficiel
                  ? const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: SSMPalette.teal)))
                  : SSMQuickActionButton(
                      icone: Icons.download_outlined,
                      label: 'Télécharger PDF',
                      variante: SSMActionVariante.teal,
                      onTap: () => _telechargerEtOuvrir(officiel: true),
                    ),
            ),
          ],
        ),
        if (bulletin != null && bulletin.statut == StatutBulletin.genere) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: _validationEnCours
                ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: SSMPalette.teal)))
                : SSMQuickActionButton(
                    icone: Icons.verified_outlined,
                    label: 'Valider ce bulletin',
                    variante: SSMActionVariante.teal,
                    onTap: _validerBulletin,
                  ),
          ),
        ],
      ],
    );
  }
}

extension _NullOuVide on String? {
  bool get isNullOuVide => this == null || this!.trim().isEmpty;
}
