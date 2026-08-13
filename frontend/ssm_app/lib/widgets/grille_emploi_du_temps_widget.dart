import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/emploi_du_temps_model.dart';

const Color _couleurParDefaut = Color(0xFF1E3A8A);
const Color _grisRecreation = Color(0xFFF1F5F9);
const Color _texteGris = Color(0xFF94A3B8);

// Convertit une couleur hexadécimale "#RRGGBB" (telle qu'enregistrée sur la
// matière ou la séance) en Color Flutter — réutilisée par le formulaire de
// séance pour l'aperçu de couleur.
Color couleurDepuisHex(String? hex, {Color parDefaut = _couleurParDefaut}) {
  if (hex == null || hex.isEmpty) return parDefaut;
  try {
    return Color(int.parse(hex.replaceAll('#', '0xFF')));
  } catch (_) {
    return parDefaut;
  }
}

// Texte blanc ou sombre selon la luminosité du fond, pour garder un
// contraste lisible quelle que soit la couleur choisie pour la matière.
Color couleurTexteLisibleSur(Color fond) {
  return ThemeData.estimateBrightnessForColor(fond) == Brightness.dark
      ? Colors.white
      : const Color(0xFF0F172A);
}

// ══════════════════════════════════════════════════════════
// GrilleEmploiDuTempsWidget — grille jours x créneaux, réutilisée en
// création (modeEdition = true) et en consultation lecture seule
// (modeEdition = false).
// ══════════════════════════════════════════════════════════
class GrilleEmploiDuTempsWidget extends StatelessWidget {
  final List<CreneauHoraire> creneaux;
  final List<JourSemaine> jours;
  final Map<JourSemaine, Map<int, Seance>> grille;
  final bool modeEdition;
  final void Function(JourSemaine jour, CreneauHoraire creneau, Seance? seanceExistante)? onCellTap;
  final void Function(JourSemaine jour, CreneauHoraire creneau, Seance seanceExistante)? onCellLongPress;

  const GrilleEmploiDuTempsWidget({
    super.key,
    required this.creneaux,
    required this.jours,
    required this.grille,
    this.modeEdition = false,
    this.onCellTap,
    this.onCellLongPress,
  });

  static const double _largeurColonneHoraire = 84;
  static const double _largeurColonneJour = 148;
  static const double _hauteurLigne = 76;

  @override
  Widget build(BuildContext context) {
    if (creneaux.isEmpty) {
      return _etatVide();
    }

    final largeurTotale = _largeurColonneHoraire + (_largeurColonneJour * jours.length);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: largeurTotale,
        child: Column(
          children: [
            _enteteJours(),
            ...creneaux.map((creneau) => _ligneCreneau(creneau)),
          ],
        ),
      ),
    );
  }

  Widget _etatVide() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.calendar_view_week_outlined, size: 48, color: _texteGris),
            const SizedBox(height: 12),
            Text(
              'Aucun créneau horaire configuré pour cette année scolaire',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF334155)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _enteteJours() {
    return Row(
      children: [
        const SizedBox(width: _largeurColonneHoraire),
        ...jours.map((jour) => SizedBox(
              width: _largeurColonneJour,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  jour.libelle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                ),
              ),
            )),
      ],
    );
  }

  Widget _ligneCreneau(CreneauHoraire creneau) {
    if (creneau.type != TypeCreneau.cours) {
      return _ligneRecreation(creneau);
    }

    return SizedBox(
      height: _hauteurLigne,
      child: Row(
        children: [
          _celluleHoraire(creneau),
          ...jours.map((jour) => _celluleSeance(jour, creneau)),
        ],
      ),
    );
  }

  Widget _ligneRecreation(CreneauHoraire creneau) {
    return Container(
      width: _largeurColonneHoraire + (_largeurColonneJour * jours.length),
      height: 38,
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: _grisRecreation,
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text(
        '${creneau.type.libelle.toUpperCase()} — ${creneau.heureDebut} - ${creneau.heureFin}',
        style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
      ),
    );
  }

  Widget _celluleHoraire(CreneauHoraire creneau) {
    return SizedBox(
      width: _largeurColonneHoraire,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(creneau.heureDebut,
              style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
          Text(creneau.heureFin, style: GoogleFonts.jetBrainsMono(fontSize: 11, color: _texteGris)),
        ],
      ),
    );
  }

  Widget _celluleSeance(JourSemaine jour, CreneauHoraire creneau) {
    final seance = grille[jour]?[creneau.id ?? -1];

    return SizedBox(
      width: _largeurColonneJour,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: seance != null ? _carteSeance(jour, creneau, seance) : _celluleVide(jour, creneau),
      ),
    );
  }

  Widget _celluleVide(JourSemaine jour, CreneauHoraire creneau) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: modeEdition ? () => onCellTap?.call(jour, creneau, null) : null,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          alignment: Alignment.center,
          child: modeEdition ? const Icon(Icons.add, size: 18, color: _texteGris) : null,
        ),
      ),
    );
  }

  Widget _carteSeance(JourSemaine jour, CreneauHoraire creneau, Seance seance) {
    final couleurFond = couleurDepuisHex(seance.couleur);
    final couleurTexte = couleurTexteLisibleSur(couleurFond);

    return Material(
      color: couleurFond,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: modeEdition ? () => onCellTap?.call(jour, creneau, seance) : null,
        onLongPress: modeEdition ? () => onCellLongPress?.call(jour, creneau, seance) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                seance.nomMatiere ?? 'Matière',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w700, color: couleurTexte),
              ),
              const SizedBox(height: 2),
              Text(
                seance.nomEnseignant ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 10, color: couleurTexte.withValues(alpha: 0.85)),
              ),
              if (seance.salle != null && seance.salle!.isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(
                  seance.salle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.jetBrainsMono(fontSize: 9, color: couleurTexte.withValues(alpha: 0.75)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
