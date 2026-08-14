import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/utilisateur.dart';
import '../../models/parametre_ecole_model.dart';
import '../../services/auth_service.dart';
import '../../services/parametre_ecole_service.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _rouge = Color(0xFFDC2626);
const Color _vert = Color(0xFF16A34A);
const Color _ambre = Color(0xFFD97706);
const Color _gris = Color(0xFF94A3B8);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);
const Color _fond = Color(0xFFEFF6FF);

const List<Color> _paletteCouleurs = [
  Color(0xFF1E3A8A), // Indigo
  Color(0xFF0D9488), // Teal
  Color(0xFFD97706), // Ambre
  Color(0xFF16A34A), // Vert
  Color(0xFFDC2626), // Rouge
  Color(0xFFEA580C), // Orange
  Color(0xFF7C3AED), // Violet
  Color(0xFFDB2777), // Rose
  Color(0xFF0891B2), // Cyan
  Color(0xFF65A30D), // Lime
  Color(0xFF0F172A), // Noir/Ardoise
  Color(0xFF64748B), // Gris
];

Color _hexVersColor(String hex) {
  try {
    return Color(int.parse(hex.replaceAll('#', '0xFF')));
  } catch (_) {
    return _indigo;
  }
}

String _colorVersHex(Color c) {
  final valeur = c.toARGB32() & 0xFFFFFF;
  return '#${valeur.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

// ══════════════════════════════════════════════════════════
// Section Établissement > Identité visuelle : logos, cachet, signature
// (IdentiteVisuelleController::uploadLogo/uploadCachet/uploadSignature/
// supprimerLogo) et couleurs (updateCouleurs). Ces éléments sont ensuite
// injectés automatiquement dans les PDF (bulletins, reçus) via
// IdentiteEcoleHelper côté backend.
// ══════════════════════════════════════════════════════════
class IdentiteVisuelleScreen extends StatefulWidget {
  const IdentiteVisuelleScreen({super.key});

  @override
  State<IdentiteVisuelleScreen> createState() => _IdentiteVisuelleScreenState();
}

class _IdentiteVisuelleScreenState extends State<IdentiteVisuelleScreen> {
  Utilisateur? _utilisateur;
  IdentiteVisuelle? _identite;

  bool _chargement = true;
  String? _erreur;

  String? _uploadEnCours; // 'principal' | 'secondaire' | 'cachet' | 'signature'
  bool _enregistrementCouleursEnCours = false;

  late String _couleurPrincipale;
  late String _couleurSecondaire;
  late String _couleurBoutons;
  late String _couleurEntetes;

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
      final utilisateur = await AuthService.getUtilisateur();
      final identite = await ParametreEcoleService.getIdentiteVisuelle();
      if (!mounted) return;
      setState(() {
        _utilisateur = utilisateur;
        _identite = identite;
        _couleurPrincipale = identite.couleurPrincipale;
        _couleurSecondaire = identite.couleurSecondaire;
        _couleurBoutons = identite.couleurBoutons ?? identite.couleurPrincipale;
        _couleurEntetes = identite.couleurEntetes ?? identite.couleurPrincipale;
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

  // ── Uploads ────────────────────────────────────────────

  Future<void> _choisirEtUploader(String cible) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
    if (image == null) return;

    setState(() => _uploadEnCours = cible);
    try {
      final String url;
      switch (cible) {
        case 'principal':
        case 'secondaire':
          url = await ParametreEcoleService.uploadLogo(cible, File(image.path));
          break;
        case 'cachet':
          url = await ParametreEcoleService.uploadCachet(File(image.path));
          break;
        default:
          url = await ParametreEcoleService.uploadSignature(File(image.path));
      }
      if (!mounted) return;
      setState(() {
        _identite = switch (cible) {
          'principal' => _identite!.copyWith(logoPrincipal: url),
          'secondaire' => _identite!.copyWith(logoSecondaire: url),
          'cachet' => _identite!.copyWith(cachetNumerique: url),
          _ => _identite!.copyWith(signatureDirecteur: url),
        };
        _uploadEnCours = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadEnCours = null);
      _afficherErreur(e);
    }
  }

  Future<void> _supprimerLogo(String type) async {
    setState(() => _uploadEnCours = type);
    try {
      await ParametreEcoleService.supprimerLogo(type);
      if (!mounted) return;
      setState(() {
        _identite = type == 'principal' ? _identite!.copyWith(logoPrincipal: null) : _identite!.copyWith(logoSecondaire: null);
        _uploadEnCours = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadEnCours = null);
      _afficherErreur(e);
    }
  }

  // ── Couleurs ───────────────────────────────────────────

  Future<void> _choisirCouleur(String cible) async {
    final actuelle = switch (cible) {
      'principale' => _couleurPrincipale,
      'secondaire' => _couleurSecondaire,
      'boutons' => _couleurBoutons,
      _ => _couleurEntetes,
    };

    final choisie = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _FeuilleChoixCouleur(couleurActuelle: actuelle),
    );

    if (choisie == null) return;
    setState(() {
      switch (cible) {
        case 'principale':
          _couleurPrincipale = choisie;
          break;
        case 'secondaire':
          _couleurSecondaire = choisie;
          break;
        case 'boutons':
          _couleurBoutons = choisie;
          break;
        default:
          _couleurEntetes = choisie;
      }
    });
  }

  Future<void> _enregistrerCouleurs() async {
    setState(() => _enregistrementCouleursEnCours = true);
    try {
      await ParametreEcoleService.updateCouleurs(
        couleurPrincipale: _couleurPrincipale,
        couleurSecondaire: _couleurSecondaire,
        couleurBoutons: _couleurBoutons,
        couleurEntetes: _couleurEntetes,
      );
      if (!mounted) return;
      setState(() => _enregistrementCouleursEnCours = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couleurs enregistrées avec succès'), backgroundColor: _vert),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _enregistrementCouleursEnCours = false);
      _afficherErreur(e);
    }
  }

  void _afficherErreur(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: _rouge),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fond,
      appBar: AppBar(
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
        title: Text('Identité visuelle', style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator(color: _indigo))
          : _erreur != null && _identite == null
              ? _carteErreur(_erreur!, _charger)
              : _corps(),
    );
  }

  Widget _corps() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _indigo.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: _indigo, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ces éléments seront utilisés automatiquement sur les bulletins et reçus.',
                  style: GoogleFonts.inter(fontSize: 12, color: _texte),
                ),
              ),
            ],
          ),
        ),
        if (_lectureSeule) ...[
          const SizedBox(height: 12),
          _bandeauLectureSeule(),
        ],
        const SizedBox(height: 20),
        _titreSection('Logos, cachet et signature'),
        LayoutBuilder(
          builder: (context, constraints) {
            final colonnes = constraints.maxWidth > 700 ? 4 : 2;
            const espacement = 12.0;
            final largeur = (constraints.maxWidth - espacement * (colonnes - 1)) / colonnes;

            return Wrap(
              spacing: espacement,
              runSpacing: espacement,
              children: [
                SizedBox(width: largeur, child: _zoneUpload('Logo principal', 'principal', _identite?.logoPrincipal, avecSuppression: true)),
                SizedBox(width: largeur, child: _zoneUpload('Logo secondaire', 'secondaire', _identite?.logoSecondaire, avecSuppression: true)),
                SizedBox(width: largeur, child: _zoneUpload('Cachet numérique', 'cachet', _identite?.cachetNumerique)),
                SizedBox(width: largeur, child: _zoneUpload('Signature directeur', 'signature', _identite?.signatureDirecteur)),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        _titreSection('Couleurs'),
        _ligneCouleur('Couleur principale', _couleurPrincipale, () => _choisirCouleur('principale')),
        _ligneCouleur('Couleur secondaire', _couleurSecondaire, () => _choisirCouleur('secondaire')),
        _ligneCouleur('Couleur des boutons', _couleurBoutons, () => _choisirCouleur('boutons')),
        _ligneCouleur('Couleur des en-têtes', _couleurEntetes, () => _choisirCouleur('entetes')),
        const SizedBox(height: 16),
        _apercuLive(),
        const SizedBox(height: 20),
        if (!_lectureSeule)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _enregistrementCouleursEnCours ? null : _enregistrerCouleurs,
              child: _enregistrementCouleursEnCours
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Enregistrer les couleurs'),
            ),
          ),
      ],
    );
  }

  Widget _zoneUpload(String label, String cible, String? url, {bool avecSuppression = false}) {
    final enCours = _uploadEnCours == cible;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _texte)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _lectureSeule || enCours ? null : () => _choisirEtUploader(cible),
          child: Stack(
            children: [
              Container(
                height: 110,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _gris.withValues(alpha: 0.3), style: BorderStyle.solid),
                ),
                clipBehavior: Clip.antiAlias,
                child: enCours
                    ? const Center(child: CircularProgressIndicator(color: _indigo, strokeWidth: 2))
                    : url != null
                        ? Image.network(url, fit: BoxFit.contain, errorBuilder: (_, _, _) => _placeholderUpload())
                        : _placeholderUpload(),
              ),
              if (url != null && avecSuppression && !_lectureSeule && !enCours)
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => _supprimerLogo(cible),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: _rouge, shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: Colors.white, size: 14),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _placeholderUpload() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_photo_alternate_outlined, color: _gris.withValues(alpha: 0.7), size: 28),
          const SizedBox(height: 4),
          Text('Ajouter', style: GoogleFonts.inter(fontSize: 11, color: _gris)),
        ],
      ),
    );
  }

  Widget _ligneCouleur(String label, String hex, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: _lectureSeule ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _hexVersColor(hex),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _texteFonce))),
              Text(hex, style: GoogleFonts.jetBrainsMono(fontSize: 12, color: _texte)),
              if (!_lectureSeule) ...[
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, color: _gris, size: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _apercuLive() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Aperçu', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _texte, letterSpacing: 0.4)),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                decoration: BoxDecoration(color: _hexVersColor(_couleurEntetes), borderRadius: BorderRadius.circular(8)),
                child: Text("En-tête de l'école", style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
                  decoration: BoxDecoration(color: _hexVersColor(_couleurBoutons), borderRadius: BorderRadius.circular(8)),
                  child: Text('Bouton exemple', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
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
          Expanded(child: Text('Lecture seule — seul le directeur peut modifier l\'identité visuelle.', style: GoogleFonts.inter(fontSize: 12, color: _texte))),
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

  Widget _titreSection(String titre) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(titre.toUpperCase(), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _indigo, letterSpacing: 0.4)),
    );
  }
}

// ══════════════════════════════════════════════════════════
// Feuille de sélection d'une couleur : palette de suggestions + saisie hex
// manuelle (pas de dépendance color-picker externe, ce projet n'en utilise
// pas — voir _couleursSuggerees dans fiche_classe_screen.dart pour le
// précédent).
// ══════════════════════════════════════════════════════════
class _FeuilleChoixCouleur extends StatefulWidget {
  final String couleurActuelle;
  const _FeuilleChoixCouleur({required this.couleurActuelle});

  @override
  State<_FeuilleChoixCouleur> createState() => _FeuilleChoixCouleurState();
}

class _FeuilleChoixCouleurState extends State<_FeuilleChoixCouleur> {
  late final TextEditingController _hexController;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _hexController = TextEditingController(text: widget.couleurActuelle);
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _valider() {
    final hex = _hexController.text.trim().toUpperCase();
    if (!RegExp(r'^#[0-9A-F]{6}$').hasMatch(hex)) {
      setState(() => _erreur = 'Format invalide — utilisez #RRGGBB.');
      return;
    }
    Navigator.pop(context, hex);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choisir une couleur', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: _texteFonce)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _paletteCouleurs
                  .map((c) => GestureDetector(
                        onTap: () => Navigator.pop(context, _colorVersHex(c)),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _colorVersHex(c) == _hexController.text.trim().toUpperCase() ? _texteFonce : Colors.white,
                              width: 2,
                            ),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _hexController,
              textCapitalization: TextCapitalization.characters,
              style: GoogleFonts.jetBrainsMono(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Code hexadécimal',
                hintText: '#1E3A8A',
                prefixIcon: const Icon(Icons.tag),
                border: const OutlineInputBorder(),
                errorText: _erreur,
              ),
              onChanged: (_) => setState(() => _erreur = null),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _indigo, foregroundColor: Colors.white),
                onPressed: _valider,
                child: const Text('Valider'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
