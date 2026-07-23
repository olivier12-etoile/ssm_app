import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/classe_matiere_service.dart';
import '../../services/classe_service.dart';
import '../../services/matiere_service.dart';
import '../../services/affectation_service.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _teal = Color(0xFF0D9488);
const Color _orange = Color(0xFFEA580C);
const Color _rouge = Color(0xFFDC2626);

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: _rouge),
    );
  }

  void _afficherSucces(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFF16A34A)),
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
    if (couleur == null || couleur.isEmpty) return _indigo;
    try {
      return Color(int.parse(couleur.replaceAll('#', '0xFF')));
    } catch (_) {
      return _indigo;
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

  @override
  Widget build(BuildContext context) {
    final nombreEnseignants = _affectations
        .where((a) => a['enseignant_id'] != null)
        .map((a) => a['enseignant_id'])
        .toSet()
        .length;
    final coefTotal = _matieresClasse.fold<double>(0, (s, l) => s + _coefficient(l));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _afficherDialogAjout,
        backgroundColor: _indigo,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Ajouter une matière',
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _enTete(),
            Expanded(
              child: _chargement
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _chargerDonnees,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _resume(nombreEnseignants, coefTotal),
                          const SizedBox(height: 16),
                          if (_matieresClasse.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Column(
                                  children: [
                                    const Icon(Icons.book_outlined, size: 64, color: Color(0xFF94A3B8)),
                                    const SizedBox(height: 12),
                                    Text('Aucune matière assignée à cette classe',
                                        style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF334155))),
                                  ],
                                ),
                              ),
                            )
                          else
                            ..._matieresClasse.map((l) => _carteMatiereClasse(l)),
                          const SizedBox(height: 12),
                          _carteAjouter(),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // EN-TÊTE
  // ══════════════════════════════════════════════════════

  Widget _enTete() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: _indigo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => Navigator.canPop(context) ? Navigator.pop(context) : null,
              ),
              const SizedBox(width: 4),
              Text('Retour', style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.8))),
            ],
          ),
          const SizedBox(height: 8),
          Text('Matières de ${_nomClasse ?? '...'}',
              style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 4),
          Text('${_matieresClasse.length} matières configurées',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // RÉSUMÉ COMPACT
  // ══════════════════════════════════════════════════════

  Widget _resume(int nombreEnseignants, double coefTotal) {
    return Row(
      children: [
        Expanded(child: _miniCard('${_matieresClasse.length}', 'matières', Icons.book)),
        const SizedBox(width: 10),
        Expanded(child: _miniCard('$nombreEnseignants', 'enseignants', Icons.person)),
        const SizedBox(width: 10),
        Expanded(child: _miniCard(coefTotal.toStringAsFixed(1), 'coef. total', Icons.calculate)),
      ],
    );
  }

  Widget _miniCard(String valeur, String label, IconData icone) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            children: [
              Icon(icone, size: 18, color: _indigo),
              const SizedBox(height: 6),
              Text(valeur, style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
              const SizedBox(height: 2),
              Text(label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF334155))),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // CARTE MATIÈRE DE LA CLASSE
  // ══════════════════════════════════════════════════════

  Widget _carteMatiereClasse(dynamic ligne) {
    final matiereId = ligne['matiere_id'] as int;
    final nom = ligne['matiere_nom'] as String;
    final coef = _coefficient(ligne);
    final couleur = _couleurMatiere(matiereId);
    final enseignant = _enseignantMatiere(matiereId);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(14),
            border: Border(left: BorderSide(color: couleur, width: 4)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    nom.isNotEmpty ? nom.characters.first.toUpperCase() : '?',
                    style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nom, style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                    const SizedBox(height: 2),
                    Text(
                      enseignant != null ? 'M. $enseignant' : 'Non affecté',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: enseignant != null ? _teal : _orange,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Coef.', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
                  Text(coef.toStringAsFixed(1),
                      style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700, color: _indigo)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 20, color: _indigo),
                onPressed: () => _afficherDialogModifierCoefficient(matiereId, nom, coef),
              ),
              IconButton(
                icon: const Icon(Icons.delete, size: 20, color: _rouge),
                onPressed: () => _confirmerSuppression(ligne),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // CARTE "AJOUTER UNE MATIÈRE" (bordure pointillée)
  // ══════════════════════════════════════════════════════

  Widget _carteAjouter() {
    return GestureDetector(
      onTap: _afficherDialogAjout,
      child: CustomPaint(
        painter: _BordurePointilleePainter(couleur: _indigo.withValues(alpha: 0.3), rayon: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: _indigo.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              const Icon(Icons.add_circle_outline, color: _indigo, size: 28),
              const SizedBox(height: 8),
              Text('Ajouter une matière', style: GoogleFonts.inter(fontSize: 14, color: _indigo, fontWeight: FontWeight.w600)),
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
    final matieresAjoutees = _matieresClasse.map((l) => l['matiere_id']).toSet();
    final matieresDisponibles = _toutesMatieres.where((m) => !matieresAjoutees.contains(m['id'])).toList();

    if (matieresDisponibles.isEmpty) {
      _afficherErreur('Toutes les matières de l\'école sont déjà ajoutées à cette classe');
      return;
    }

    int? matiereSelectionnee;
    final coefficientController = TextEditingController(text: '1');

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final matiere = matieresSelectionneeDe(matieresDisponibles, matiereSelectionnee);
          final coef = double.tryParse(coefficientController.text.replaceAll(',', '.'));

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ajouter une matière',
                        style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<int>(
                      value: matiereSelectionnee,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Matière',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      hint: const Text('Choisir une matière'),
                      items: matieresDisponibles.map((m) {
                        final couleur = _couleurDepuisHex(m['couleur'] as String?);
                        return DropdownMenuItem<int>(
                          value: m['id'] as int,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 12, height: 12, decoration: BoxDecoration(color: couleur, shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Text(m['nom'] as String),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setStateDialog(() => matiereSelectionnee = v),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: coefficientController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Coefficient',
                        hintText: 'ex: 3, 4.5, 7',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (_) => setStateDialog(() {}),
                    ),
                    const SizedBox(height: 16),
                    if (matiere != null)
                      Text(
                        '${matiere['nom']} · Coefficient ${coef?.toStringAsFixed(1) ?? '—'}',
                        style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: _indigo),
                      ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler'))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _indigo,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: matiereSelectionnee == null
                                ? null
                                : () async {
                                    if (coef == null || coef < 0.5 || coef > 10) {
                                      _afficherErreur('Le coefficient doit être compris entre 0.5 et 10');
                                      return;
                                    }
                                    try {
                                      await ClasseMatiereService.ajouter(widget.classeId, matiereSelectionnee!, coef);
                                      if (context.mounted) Navigator.pop(context);
                                      _afficherSucces('Matière ajoutée à la classe');
                                      _chargerDonnees();
                                    } catch (e) {
                                      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
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
    if (hex == null || hex.isEmpty) return _indigo;
    try {
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return _indigo;
    }
  }

  // ══════════════════════════════════════════════════════
  // DIALOG MODIFIER COEFFICIENT
  // ══════════════════════════════════════════════════════

  Future<void> _afficherDialogModifierCoefficient(int matiereId, String nom, double coefActuel) async {
    final coefficientController = TextEditingController(text: coefActuel.toStringAsFixed(1));

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Modifier le coefficient de $nom',
                    style: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                const SizedBox(height: 16),
                TextField(
                  controller: coefficientController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Coefficient',
                    hintText: 'ex: 3, 4.5, 7',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler'))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          final coef = double.tryParse(coefficientController.text.replaceAll(',', '.'));
                          if (coef == null || coef < 0.5 || coef > 10) {
                            _afficherErreur('Le coefficient doit être compris entre 0.5 et 10');
                            return;
                          }
                          try {
                            await ClasseMatiereService.ajouter(widget.classeId, matiereId, coef);
                            if (context.mounted) Navigator.pop(context);
                            _afficherSucces('Coefficient modifié avec succès');
                            _chargerDonnees();
                          } catch (e) {
                            _afficherErreur(e.toString().replaceAll('Exception: ', ''));
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 48),
                const SizedBox(height: 16),
                Text('Retirer "${ligne['matiere_nom']}" de cette classe ?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler'))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _rouge,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(rayon)));

    const largeurTrait = 6.0;
    const espace = 4.0;
    final chemin = Path();

    for (final metrique in contour.computeMetrics()) {
      double distance = 0;
      while (distance < metrique.length) {
        final fin = (distance + largeurTrait).clamp(0, metrique.length);
        chemin.addPath(metrique.extractPath(distance, fin.toDouble()), Offset.zero);
        distance += largeurTrait + espace;
      }
    }

    canvas.drawPath(chemin, peinture);
  }

  @override
  bool shouldRepaint(covariant _BordurePointilleePainter oldDelegate) =>
      oldDelegate.couleur != couleur || oldDelegate.rayon != rayon;
}