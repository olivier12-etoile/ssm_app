import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/ssm_theme.dart';

// ══════════════════════════════════════════════════════════
// SSMAvatar — Avatar réutilisable (élève, utilisateur…) : photo
// réseau si disponible, sinon initiale colorée. Couleur dérivée
// du sexe ('M'/'F') si aucune couleur explicite n'est fournie.
// Variantes optionnelles : anneau blanc (héros de fiche), bouton
// caméra superposé (changer la photo), overlay de chargement.
// ══════════════════════════════════════════════════════════
class SSMAvatar extends StatelessWidget {
  final String? photoUrl;
  final String nom;
  final String? sexe;
  final double rayon;
  final Color? couleur;
  final double epaisseurAnneau;
  final Color couleurAnneau;
  final VoidCallback? onTap;
  final bool afficherBoutonCamera;
  final bool enTeleversement;

  const SSMAvatar({
    super.key,
    required this.nom,
    this.photoUrl,
    this.sexe,
    this.rayon = 22,
    this.couleur,
    this.epaisseurAnneau = 0,
    this.couleurAnneau = SSMPalette.blanc,
    this.onTap,
    this.afficherBoutonCamera = false,
    this.enTeleversement = false,
  });

  Color get _couleurEffective {
    if (couleur != null) return couleur!;
    if (sexe == 'F') return SSMPalette.teal;
    if (sexe == 'M') return SSMPalette.indigo;
    return SSMPalette.texte3;
  }

  String get _initiale {
    final valeur = nom.trim();
    return valeur.isNotEmpty ? valeur[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final photoValide = photoUrl != null && photoUrl!.isNotEmpty;

    Widget cercle = Container(
      width: rayon * 2,
      height: rayon * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _couleurEffective.withValues(alpha: photoValide ? 1 : 0.15),
        border: epaisseurAnneau > 0 ? Border.all(color: couleurAnneau, width: epaisseurAnneau) : null,
        image: photoValide
            ? DecorationImage(image: NetworkImage(photoUrl!), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: photoValide
          ? null
          : Text(
              _initiale,
              style: GoogleFonts.inter(
                fontSize: rayon * 0.72,
                fontWeight: FontWeight.w700,
                color: _couleurEffective,
              ),
            ),
    );

    if (enTeleversement) {
      cercle = Stack(
        alignment: Alignment.center,
        children: [
          cercle,
          Container(
            width: rayon * 2,
            height: rayon * 2,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x66000000)),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            ),
          ),
        ],
      );
    }

    if (afficherBoutonCamera) {
      cercle = Stack(
        clipBehavior: Clip.none,
        children: [
          cercle,
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: rayon * 0.62,
              height: rayon * 0.62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SSMPalette.indigo,
                border: Border.all(color: SSMPalette.blanc, width: 2),
              ),
              child: Icon(Icons.camera_alt, size: rayon * 0.32, color: Colors.white),
            ),
          ),
        ],
      );
    }

    if (onTap == null) return cercle;

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: cercle,
      ),
    );
  }
}
