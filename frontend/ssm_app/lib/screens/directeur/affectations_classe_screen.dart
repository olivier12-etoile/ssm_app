import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/affectation_service.dart';
import '../../services/classe_matiere_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_avatar.dart';
import '../../widgets/ssm/ssm_pill.dart';

class AffectationsClasseScreen extends StatefulWidget {
  final int classeId;
  final String classeNom;

  const AffectationsClasseScreen({
    super.key,
    required this.classeId,
    required this.classeNom,
  });

  @override
  State<AffectationsClasseScreen> createState() =>
      _AffectationsClasseScreenState();
}

class _AffectationsClasseScreenState extends State<AffectationsClasseScreen> {
  List<dynamic> _matieresClasse = [];
  List<dynamic> _affectations = [];
  List<dynamic> _enseignants = [];
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _chargerDonnees();
  }

  Future<void> _chargerDonnees() async {
    try {
      final resultats = await Future.wait([
        ClasseMatiereService.listerParClasse(widget.classeId),
        AffectationService.listerParClasse(widget.classeId),
        AffectationService.listerEnseignants(),
      ]);
      setState(() {
        _matieresClasse = resultats[0];
        _affectations = resultats[1];
        _enseignants = resultats[2];
        _chargement = false;
      });
    } catch (e) {
      setState(() => _chargement = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _afficherErreur(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: SSMPalette.rouge));
  }

  void _afficherSucces(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: SSMPalette.teal));
  }

  dynamic _affectationPourMatiere(int matiereId) {
    return _affectations.firstWhere(
      (a) => a['matiere_id'] == matiereId,
      orElse: () => null,
    );
  }

  InputDecoration _decorationChamp(String label, {IconData? icone}) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2),
      prefixIcon: icone != null ? Icon(icone, size: 19, color: SSMPalette.texte3) : null,
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SSMRayons.moyen),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SSMRayons.moyen),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SSMRayons.moyen),
        borderSide: const BorderSide(color: SSMPalette.indigo, width: 1.5),
      ),
    );
  }

  Future<void> _afficherDialogAffectation(
    int matiereId,
    String matiereNom,
    dynamic affectationActuelle,
  ) async {
    if (_enseignants.isEmpty) {
      _afficherErreur(
        'Aucun enseignant disponible. Créez des enseignants d\'abord.',
      );
      return;
    }

    int? enseignantSelectionne = affectationActuelle?['enseignant_id'] as int?;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: SSMPalette.blanc,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
            title: Text(
              'Affecter un enseignant — $matiereNom',
              style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
            ),
            content: SizedBox(
              width: 400,
              child: DropdownButtonFormField<int>(
                initialValue: enseignantSelectionne,
                isExpanded: true,
                decoration: _decorationChamp('Enseignant', icone: Icons.school_outlined),
                hint: Text('Choisir un enseignant', style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte3)),
                items: _enseignants.map((e) {
                  return DropdownMenuItem<int>(
                    value: e['id'] as int,
                    child: Text(e['name'] as String),
                  );
                }).toList(),
                onChanged: (v) =>
                    setStateDialog(() => enseignantSelectionne = v),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Annuler', style: GoogleFonts.inter(color: SSMPalette.texte2)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: SSMPalette.indigo,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
                ),
                onPressed: enseignantSelectionne == null
                    ? null
                    : () async {
                        final navigator = Navigator.of(context);
                        try {
                          if (affectationActuelle != null) {
                            await AffectationService.supprimerAffectation(
                              affectationActuelle['id'] as int,
                            );
                          }
                          await AffectationService.ajouterAffectation(
                            enseignantId: enseignantSelectionne!,
                            classeId: widget.classeId,
                            matiereId: matiereId,
                          );
                          navigator.pop();
                          _afficherSucces('Enseignant affecté avec succès');
                          _chargerDonnees();
                        } catch (e) {
                          navigator.pop();
                          _afficherErreur(
                            e.toString().replaceAll('Exception: ', ''),
                          );
                        }
                      },
                child: const Text('Affecter'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmerRetrait(dynamic affectation) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SSMPalette.blanc,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
        title: Text(
          "Retirer l'affectation",
          style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
        ),
        content: Text(
          'Retirer ${affectation['enseignant_nom']} de "${affectation['matiere_nom']}" ?',
          style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte1),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler', style: GoogleFonts.inter(color: SSMPalette.texte2)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: SSMPalette.rouge,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );

    if (confirme != true) return;

    try {
      await AffectationService.supprimerAffectation(affectation['id'] as int);
      _afficherSucces('Affectation retirée');
      _chargerDonnees();
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SSMPalette.fond,
      appBar: AppBar(
        title: Text(widget.classeNom),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerDonnees,
          ),
        ],
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
          : _matieresClasse.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.book_outlined, size: 56, color: SSMPalette.texte3),
                  const SizedBox(height: 12),
                  Text(
                    'Aucune matière assignée à cette classe',
                    style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte3),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _matieresClasse.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final matiere = _matieresClasse[index];
                final matiereId = matiere['matiere_id'] as int;
                final matiereNom = matiere['matiere_nom'] as String;
                final coefficient = matiere['coefficient'];
                final affectation = _affectationPourMatiere(matiereId);

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SSMPalette.blanc,
                    borderRadius: BorderRadius.circular(SSMRayons.grand),
                    border: Border.all(color: SSMPalette.bordure),
                  ),
                  child: Row(
                    children: [
                      SSMAvatar(nom: matiereNom, rayon: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              matiereNom,
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: SSMPalette.texte1),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text('Coef. $coefficient', style: GoogleFonts.inter(fontSize: 11.5, color: SSMPalette.texte3)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: affectation != null
                                      ? Text(
                                          affectation['enseignant_nom'] as String,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(fontSize: 11.5, color: SSMPalette.texte2),
                                        )
                                      : const SSMPill.couleur(label: 'Non affecté', couleur: SSMPalette.ambre),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: SSMPalette.indigo),
                        tooltip: "Affecter / changer l'enseignant",
                        onPressed: () => _afficherDialogAffectation(
                          matiereId,
                          matiereNom,
                          affectation,
                        ),
                      ),
                      if (affectation != null)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: SSMPalette.rouge),
                          tooltip: "Retirer l'affectation",
                          onPressed: () => _confirmerRetrait(affectation),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
