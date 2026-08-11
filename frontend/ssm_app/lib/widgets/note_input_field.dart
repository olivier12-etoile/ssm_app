import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color _vert = Color(0xFF16A34A);
const Color _rouge = Color(0xFFDC2626);
const Color _gris = Color(0xFF94A3B8);
const Color _texteFonce = Color(0xFF0F172A);

// Champ de saisie réutilisable pour une note sur 20 : clavier numérique,
// couleur dynamique selon la valeur (rouge clair si < 10, vert clair si
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
      couleurFond = _rouge.withValues(alpha: 0.1);
      couleurTexte = _rouge;
      couleurBordure = _rouge;
    } else if (faible) {
      couleurFond = _rouge.withValues(alpha: 0.06);
      couleurTexte = _rouge;
      couleurBordure = const Color(0xFFE2E8F0);
    } else if (valeur != null) {
      couleurFond = _vert.withValues(alpha: 0.07);
      couleurTexte = _texteFonce;
      couleurBordure = const Color(0xFFE2E8F0);
    } else {
      couleurFond = Colors.white;
      couleurTexte = _texteFonce;
      couleurBordure = const Color(0xFFE2E8F0);
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
          color: lectureSeule ? _gris : couleurTexte,
        ),
        onChanged: onChanged,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: lectureSeule ? const Color(0xFFF1F5F9) : couleurFond,
          hintText: '—',
          hintStyle: GoogleFonts.jetBrainsMono(color: _gris),
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: couleurBordure),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: couleurBordure),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
          ),
        ),
      ),
    );
  }
}
