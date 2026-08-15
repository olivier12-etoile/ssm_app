import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/ssm_theme.dart';

// Champ de saisie réutilisable pour une note sur 20 : clavier numérique,
// couleur dynamique selon la valeur (rouge clair si < 10, teal clair si
// valide et >= 10, rouge franc si hors limites), lecture seule si la
// saisie est verrouillée.
class NoteInputField extends StatelessWidget {
  final TextEditingController controller;
  final bool lectureSeule;
  final ValueChanged<String>? onChanged;

  const NoteInputField({
    super.key,
    required this.controller,
    this.lectureSeule = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final texte = controller.text.trim();
    final valeur = texte.isEmpty ? null : double.tryParse(texte.replaceAll(',', '.'));
    final horsLimites = texte.isNotEmpty && (valeur == null || valeur < 0 || valeur > 20);
    final faible = valeur != null && !horsLimites && valeur < 10;

    Color couleurFond;
    Color couleurTexte;
    Color couleurBordure;

    if (horsLimites) {
      couleurFond = SSMPalette.rouge.withValues(alpha: 0.1);
      couleurTexte = SSMPalette.rouge;
      couleurBordure = SSMPalette.rouge;
    } else if (faible) {
      couleurFond = SSMPalette.rouge.withValues(alpha: 0.06);
      couleurTexte = SSMPalette.rouge;
      couleurBordure = const Color(0xFFE5E7EB);
    } else if (valeur != null) {
      couleurFond = SSMPalette.teal.withValues(alpha: 0.07);
      couleurTexte = SSMPalette.texte1;
      couleurBordure = const Color(0xFFE5E7EB);
    } else {
      couleurFond = SSMPalette.blanc;
      couleurTexte = SSMPalette.texte1;
      couleurBordure = const Color(0xFFE5E7EB);
    }

    return SizedBox(
      width: 76,
      child: TextField(
        controller: controller,
        enabled: !lectureSeule,
        readOnly: lectureSeule,
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: GoogleFonts.jetBrainsMono(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: lectureSeule ? SSMPalette.texte3 : couleurTexte,
        ),
        onChanged: onChanged,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: lectureSeule ? const Color(0xFFF1F5F9) : couleurFond,
          hintText: '—',
          hintStyle: GoogleFonts.jetBrainsMono(color: SSMPalette.texte3),
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SSMRayons.petit),
            borderSide: BorderSide(color: couleurBordure),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SSMRayons.petit),
            borderSide: BorderSide(color: couleurBordure),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SSMRayons.petit),
            borderSide: const BorderSide(color: SSMPalette.indigo, width: 1.5),
          ),
        ),
      ),
    );
  }
}
