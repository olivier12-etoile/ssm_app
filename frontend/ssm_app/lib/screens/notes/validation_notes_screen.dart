import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/analyse_performance_model.dart';
import '../../services/validation_note_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_pill.dart';
import '../../widgets/ssm/ssm_sous_entete.dart';
import 'detail_validation_screen.dart';

String _formatDateCourt(DateTime? d) =>
    d == null ? '—' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class ValidationNotesScreen extends StatefulWidget {
  final int? classeIdPreselectionne;
  // À false quand cet écran est embarqué dans notes_module_screen.dart : il
  // n'affiche alors ni bouton retour ni son propre bandeau — le conteneur
  // (ssm_page_scaffold) fournit déjà la navigation et le titre de page.
  final bool afficherBoutonRetour;

  const ValidationNotesScreen({
    super.key,
    this.classeIdPreselectionne,
    this.afficherBoutonRetour = true,
  });

  @override
  State<ValidationNotesScreen> createState() => _ValidationNotesScreenState();
}

class _ValidationNotesScreenState extends State<ValidationNotesScreen> {
  List<SaisieEnAttenteValidation> _saisies = [];
  bool _chargement = true;
  String? _erreur;

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
      final saisies = await ValidationNoteService.getEnAttente();
      setState(() {
        _saisies = widget.classeIdPreselectionne == null
            ? saisies
            : saisies.where((s) => s.classeId == widget.classeIdPreselectionne).toList();
        _chargement = false;
      });
    } catch (e) {
      setState(() {
        _chargement = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _ouvrirDetail(SaisieEnAttenteValidation saisie) async {
    final resultat = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => DetailValidationScreen(saisieId: saisie.id)),
    );
    if (resultat == true) _charger();
  }

  @override
  Widget build(BuildContext context) {
    // Embarqué dans notes_module_screen.dart : celui-ci défile déjà toute la
    // page dans un SingleChildScrollView (hauteur non bornée) — un ListView
    // ou un Expanded planterait ici. On rend donc un contenu "plat" (Column)
    // sans scroll, RefreshIndicator ni bandeau propres (déjà fournis par le
    // conteneur parent).
    if (!widget.afficherBoutonRetour) {
      if (_chargement) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator(color: SSMPalette.indigo)),
        );
      }
      if (_erreur != null) return _vueErreur();
      if (_saisies.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.check_circle_outline, size: 56, color: SSMPalette.teal),
                const SizedBox(height: 12),
                Text(
                  'Aucune saisie en attente de validation',
                  style: GoogleFonts.inter(color: SSMPalette.texte2),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final saisie in _saisies) _carteSaisie(saisie)],
      );
    }

    return Scaffold(
      backgroundColor: SSMPalette.fond,
      body: SafeArea(
        child: Column(
          children: [
            SSMSousEnTete(
              titre: 'Validation des notes',
              sousTitre: '${_saisies.length} saisie(s) en attente',
              onRetour: () => Navigator.pop(context),
            ),
            Expanded(
              child: _chargement
                  ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
                  : _erreur != null
                      ? _vueErreur()
                      : RefreshIndicator(
                          onRefresh: _charger,
                          color: SSMPalette.indigo,
                          child: _saisies.isEmpty
                              ? ListView(
                                  padding: const EdgeInsets.all(40),
                                  children: [
                                    Icon(Icons.check_circle_outline, size: 56, color: SSMPalette.teal),
                                    const SizedBox(height: 12),
                                    Center(
                                      child: Text(
                                        'Aucune saisie en attente de validation',
                                        style: GoogleFonts.inter(color: SSMPalette.texte2),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                  itemCount: _saisies.length,
                                  itemBuilder: (context, index) => _carteSaisie(_saisies[index]),
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

  Widget _carteSaisie(SaisieEnAttenteValidation saisie) {
    final aDesAnomalies = saisie.nombreAnomalies > 0;

    return Material(
      color: SSMPalette.blanc,
      borderRadius: BorderRadius.circular(SSMRayons.grand),
      child: InkWell(
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        onTap: () => _ouvrirDetail(saisie),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SSMRayons.grand),
            border: Border(
              top: BorderSide(color: SSMPalette.bordure),
              right: BorderSide(color: SSMPalette.bordure),
              bottom: BorderSide(color: SSMPalette.bordure),
              left: BorderSide(color: aDesAnomalies ? SSMPalette.ambre : SSMPalette.indigo, width: 3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          saisie.classeNom,
                          style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: SSMPalette.texte1),
                        ),
                        const SizedBox(height: 2),
                        Text(saisie.matiereNom, style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.person_outline, size: 12, color: SSMPalette.texte3),
                            const SizedBox(width: 4),
                            Text(saisie.enseignantNom, style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte3)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (aDesAnomalies) SSMPill.couleur(label: '${saisie.nombreAnomalies} anomalie(s)', couleur: SSMPalette.ambre),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Soumis le ${_formatDateCourt(saisie.dateSoumission)}',
                    style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte3),
                  ),
                  Text(
                    saisie.moyenneClasse != null ? 'Moyenne : ${saisie.moyenneClasse!.toStringAsFixed(2)}/20' : 'Moyenne : —',
                    style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
