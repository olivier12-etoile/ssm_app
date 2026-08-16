import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/classe_matiere_service.dart';
import '../../services/classe_service.dart';
import '../../services/matiere_service.dart';
import '../../services/affectation_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_data_table.dart';
import '../../widgets/ssm/ssm_panel.dart';
import '../../widgets/ssm/ssm_pill.dart';
import '../../widgets/ssm/ssm_stat_card.dart';

class MatieresParClasseScreen extends StatefulWidget {
  final int classeId;
  final String? nomClasse;

  const MatieresParClasseScreen({
    super.key,
    required this.classeId,
    this.nomClasse,
  });

  @override
  State<MatieresParClasseScreen> createState() =>
      _MatieresParClasseScreenState();
}

class _MatieresParClasseScreenState extends State<MatieresParClasseScreen> {
  List<dynamic> _matieresClasse = [];
  List<dynamic> _toutesMatieres = [];
  List<dynamic> _affectations = [];
  String? _nomClasse;
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _nomClasse = widget.nomClasse;
    _chargerDonnees();
    if (_nomClasse == null) _chargerNomClasse();
  }

  Future<void> _chargerNomClasse() async {
    try {
      final classes = await ClasseService.listerClasses();
      final classe = classes.firstWhere(
        (c) => c['id'] == widget.classeId,
        orElse: () => null,
      );
      if (classe != null && mounted) {
        setState(() => _nomClasse = classe['nom'] as String);
      }
    } catch (_) {
      // Le titre reste sur la valeur par défaut si la classe n'est pas trouvée.
    }
  }

  Future<void> _chargerDonnees() async {
    setState(() => _chargement = true);
    try {
      final resultats = await Future.wait([
        ClasseMatiereService.listerParClasse(widget.classeId),
        MatiereService.listerMatieres(),
        AffectationService.listerParClasse(widget.classeId),
      ]);
      setState(() {
        _matieresClasse = resultats[0];
        _toutesMatieres = resultats[1];
        _affectations = resultats[2];
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: SSMPalette.teal),
    );
  }

  // ══════════════════════════════════════════════════════
  // Correspondances matière (couleur) / affectation (enseignant)
  // ══════════════════════════════════════════════════════

  Color _couleurMatiere(int matiereId) {
    final matiere = _toutesMatieres.firstWhere(
      (m) => m['id'] == matiereId,
      orElse: () => null,
    );
    final couleur = matiere?['couleur'] as String?;
    if (couleur == null || couleur.isEmpty) return SSMPalette.indigo;
    try {
      return Color(int.parse(couleur.replaceAll('#', '0xFF')));
    } catch (_) {
      return SSMPalette.indigo;
    }
  }

  String? _enseignantMatiere(int matiereId) {
    final affectation = _affectations.firstWhere(
      (a) => a['matiere_id'] == matiereId,
      orElse: () => null,
    );
    return affectation?['enseignant_nom'] as String?;
  }

  double _coefficient(dynamic ligne) =>
      double.tryParse(ligne['coefficient'].toString()) ?? 1.0;

  InputDecoration _decorationChamp(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2),
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

  @override
  Widget build(BuildContext context) {
    final nombreEnseignants = _affectations
        .where((a) => a['enseignant_id'] != null)
        .map((a) => a['enseignant_id'])
        .toSet()
        .length;
    final coefTotal = _matieresClasse.fold<double>(
      0,
      (s, l) => s + _coefficient(l),
    );

    return Scaffold(
      backgroundColor: SSMPalette.fond,
      appBar: AppBar(
        backgroundColor: SSMPalette.blanc,
        foregroundColor: SSMPalette.texte1,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: SSMPalette.texte2),
        title: Text(
          'Matières de ${_nomClasse ?? '...'}',
          style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${_matieresClasse.length} matière${_matieresClasse.length > 1 ? 's' : ''} configurée${_matieresClasse.length > 1 ? 's' : ''}',
              style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte3),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _afficherDialogAjout,
        backgroundColor: SSMPalette.indigo,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter une matière'),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
          : RefreshIndicator(
              onRefresh: _chargerDonnees,
              color: SSMPalette.indigo,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                children: [
                  _resume(nombreEnseignants, coefTotal),
                  const SizedBox(height: 16),
                  if (_matieresClasse.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.menu_book_outlined, size: 56, color: SSMPalette.texte3),
                            const SizedBox(height: 12),
                            Text(
                              'Aucune matière assignée à cette classe',
                              style: GoogleFonts.inter(fontSize: 13.5, color: SSMPalette.texte2),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SSMPanel(
                      titre: 'Matières assignées',
                      padding: EdgeInsets.zero,
                      child: SSMDataTable(
                        colonnes: const [
                          SSMDataColumn('Matière'),
                          SSMDataColumn('Enseignant'),
                          SSMDataColumn('Coefficient'),
                          SSMDataColumn('Actions'),
                        ],
                        lignes: [for (final l in _matieresClasse) _ligneMatiereClasse(l)],
                      ),
                    ),
                  const SizedBox(height: 12),
                  _carteAjouter(),
                ],
              ),
            ),
    );
  }

  // ══════════════════════════════════════════════════════
  // RÉSUMÉ COMPACT
  // ══════════════════════════════════════════════════════

  Widget _resume(int nombreEnseignants, double coefTotal) {
    return Row(
      children: [
        Expanded(
          child: SSMStatCard(
            icone: Icons.menu_book_outlined,
            couleur: SSMPalette.indigo,
            valeur: '${_matieresClasse.length}',
            label: 'matières',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SSMStatCard(
            icone: Icons.person_outline,
            couleur: SSMPalette.teal,
            valeur: '$nombreEnseignants',
            label: 'enseignants',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SSMStatCard(
            icone: Icons.calculate_outlined,
            couleur: SSMPalette.ambre,
            valeur: coefTotal.toStringAsFixed(1),
            label: 'coef. total',
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  // LIGNE MATIÈRE DE LA CLASSE (tableau)
  // ══════════════════════════════════════════════════════

  List<Widget> _ligneMatiereClasse(dynamic ligne) {
    final matiereId = ligne['matiere_id'] as int;
    final nom = ligne['matiere_nom'] as String;
    final coef = _coefficient(ligne);
    final couleur = _couleurMatiere(matiereId);
    final enseignant = _enseignantMatiere(matiereId);

    return [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              nom.isNotEmpty ? nom.characters.first.toUpperCase() : '?',
              style: GoogleFonts.sora(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          Text(nom, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
        ],
      ),
      enseignant != null
          ? SSMPill.couleur(label: enseignant, couleur: SSMPalette.teal)
          : const SSMPill.couleur(label: 'Non affecté', couleur: SSMPalette.ambre),
      Text(coef.toStringAsFixed(1), style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18, color: SSMPalette.indigo),
            onPressed: () => _afficherDialogModifierCoefficient(matiereId, nom, coef),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: SSMPalette.rouge),
            onPressed: () => _confirmerSuppression(ligne),
          ),
        ],
      ),
    ];
  }

  // ══════════════════════════════════════════════════════
  // CARTE "AJOUTER UNE MATIÈRE" (bordure pointillée)
  // ══════════════════════════════════════════════════════

  Widget _carteAjouter() {
    return GestureDetector(
      onTap: _afficherDialogAjout,
      child: CustomPaint(
        painter: _BordurePointilleePainter(
          couleur: SSMPalette.indigo.withValues(alpha: 0.3),
          rayon: SSMRayons.grand,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: SSMPalette.indigo.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(SSMRayons.grand),
          ),
          child: Column(
            children: [
              const Icon(Icons.add_circle_outline, color: SSMPalette.indigo, size: 26),
              const SizedBox(height: 8),
              Text(
                'Ajouter une matière',
                style: GoogleFonts.inter(fontSize: 13.5, color: SSMPalette.indigo, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // DIALOG AJOUT
  // ══════════════════════════════════════════════════════

  Future<void> _afficherDialogAjout() async {
    final matieresAjoutees = _matieresClasse
        .map((l) => l['matiere_id'])
        .toSet();
    final matieresDisponibles = _toutesMatieres
        .where((m) => !matieresAjoutees.contains(m['id']))
        .toList();

    if (matieresDisponibles.isEmpty) {
      _afficherErreur(
        'Toutes les matières de l\'école sont déjà ajoutées à cette classe',
      );
      return;
    }

    int? matiereSelectionnee;
    final coefficientController = TextEditingController(text: '1');

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final matiere = matieresSelectionneeDe(
            matieresDisponibles,
            matiereSelectionnee,
          );
          final coef = double.tryParse(
            coefficientController.text.replaceAll(',', '.'),
          );

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SSMRayons.grand),
            ),
            backgroundColor: SSMPalette.blanc,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ajouter une matière',
                      style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<int>(
                      initialValue: matiereSelectionnee,
                      isExpanded: true,
                      decoration: _decorationChamp('Matière'),
                      hint: const Text('Choisir une matière'),
                      items: matieresDisponibles.map((m) {
                        final couleur = _couleurDepuisHex(
                          m['couleur'] as String?,
                        );
                        return DropdownMenuItem<int>(
                          value: m['id'] as int,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: couleur,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(m['nom'] as String),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (v) =>
                          setStateDialog(() => matiereSelectionnee = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: coefficientController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: _decorationChamp('Coefficient', hint: 'ex: 3, 4.5, 7'),
                      onChanged: (_) => setStateDialog(() {}),
                    ),
                    const SizedBox(height: 16),
                    if (matiere != null)
                      Text(
                        '${matiere['nom']} · Coefficient ${coef?.toStringAsFixed(1) ?? '—'}',
                        style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: SSMPalette.indigo),
                      ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('Annuler', style: GoogleFonts.inter(color: SSMPalette.texte2)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: SSMPalette.indigo,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(SSMRayons.moyen),
                              ),
                            ),
                            onPressed: matiereSelectionnee == null
                                ? null
                                : () async {
                                    if (coef == null ||
                                        coef < 0.5 ||
                                        coef > 10) {
                                      _afficherErreur(
                                        'Le coefficient doit être compris entre 0.5 et 10',
                                      );
                                      return;
                                    }
                                    try {
                                      await ClasseMatiereService.ajouter(
                                        classeId: widget.classeId,
                                        matiereId: matiereSelectionnee!,
                                        coefficient: coef,
                                      );
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                      }
                                      _afficherSucces(
                                        'Matière ajoutée à la classe',
                                      );
                                      _chargerDonnees();
                                    } catch (e) {
                                      _afficherErreur(
                                        e.toString().replaceAll(
                                          'Exception: ',
                                          '',
                                        ),
                                      );
                                    }
                                  },
                            child: const Text('Ajouter'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    coefficientController.dispose();
  }

  dynamic matieresSelectionneeDe(List<dynamic> matieres, int? id) {
    if (id == null) return null;
    return matieres.firstWhere((m) => m['id'] == id, orElse: () => null);
  }

  Color _couleurDepuisHex(String? hex) {
    if (hex == null || hex.isEmpty) return SSMPalette.indigo;
    try {
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return SSMPalette.indigo;
    }
  }

  // ══════════════════════════════════════════════════════
  // DIALOG MODIFIER COEFFICIENT
  // ══════════════════════════════════════════════════════

  Future<void> _afficherDialogModifierCoefficient(
    int matiereId,
    String nom,
    double coefActuel,
  ) async {
    final coefficientController = TextEditingController(
      text: coefActuel.toStringAsFixed(1),
    );

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
        backgroundColor: SSMPalette.blanc,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Modifier le coefficient de $nom',
                  style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: coefficientController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _decorationChamp('Coefficient', hint: 'ex: 3, 4.5, 7'),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Annuler', style: GoogleFonts.inter(color: SSMPalette.texte2)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SSMPalette.indigo,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(SSMRayons.moyen),
                          ),
                        ),
                        onPressed: () async {
                          final coef = double.tryParse(
                            coefficientController.text.replaceAll(',', '.'),
                          );
                          if (coef == null || coef < 0.5 || coef > 10) {
                            _afficherErreur(
                              'Le coefficient doit être compris entre 0.5 et 10',
                            );
                            return;
                          }
                          try {
                            await ClasseMatiereService.ajouter(
                              classeId: widget.classeId,
                              matiereId: matiereId,
                              coefficient: coef,
                            );
                            if (context.mounted) Navigator.pop(context);
                            _afficherSucces('Coefficient modifié avec succès');
                            _chargerDonnees();
                          } catch (e) {
                            _afficherErreur(
                              e.toString().replaceAll('Exception: ', ''),
                            );
                          }
                        },
                        child: const Text('Enregistrer'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    coefficientController.dispose();
  }

  // ══════════════════════════════════════════════════════
  // CONFIRMATION SUPPRESSION
  // ══════════════════════════════════════════════════════

  Future<void> _confirmerSuppression(dynamic ligne) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
        backgroundColor: SSMPalette.blanc,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: SSMPalette.ambre,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Retirer "${ligne['matiere_nom']}" de cette classe ?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: SSMPalette.texte1),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text('Annuler', style: GoogleFonts.inter(color: SSMPalette.texte2)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SSMPalette.rouge,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(SSMRayons.moyen),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Retirer'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirme != true) return;

    try {
      await ClasseMatiereService.supprimer(ligne['id'] as int);
      _afficherSucces('Matière retirée de la classe');
      _chargerDonnees();
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }
}

// ══════════════════════════════════════════════════════
// Bordure pointillée (pas de dépendance externe)
// ══════════════════════════════════════════════════════

class _BordurePointilleePainter extends CustomPainter {
  final Color couleur;
  final double rayon;

  _BordurePointilleePainter({required this.couleur, this.rayon = 12});

  @override
  void paint(Canvas canvas, Size size) {
    final peinture = Paint()
      ..color = couleur
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final contour = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(rayon)),
      );

    const largeurTrait = 6.0;
    const espace = 4.0;
    final chemin = Path();

    for (final metrique in contour.computeMetrics()) {
      double distance = 0;
      while (distance < metrique.length) {
        final fin = (distance + largeurTrait).clamp(0, metrique.length);
        chemin.addPath(
          metrique.extractPath(distance, fin.toDouble()),
          Offset.zero,
        );
        distance += largeurTrait + espace;
      }
    }

    canvas.drawPath(chemin, peinture);
  }

  @override
  bool shouldRepaint(covariant _BordurePointilleePainter oldDelegate) =>
      oldDelegate.couleur != couleur || oldDelegate.rayon != rayon;
}
