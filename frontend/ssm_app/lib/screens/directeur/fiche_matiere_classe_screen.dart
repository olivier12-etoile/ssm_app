import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../services/annee_service.dart';
import '../../services/cahier_texte_service.dart';
import '../../services/evaluation_service.dart';

const List<String> _joursSemaine = [
  'Lundi',
  'Mardi',
  'Mercredi',
  'Jeudi',
  'Vendredi',
  'Samedi',
  'Dimanche',
];

const List<String> _moisAnnee = [
  '',
  'Janvier',
  'Février',
  'Mars',
  'Avril',
  'Mai',
  'Juin',
  'Juillet',
  'Août',
  'Septembre',
  'Octobre',
  'Novembre',
  'Décembre',
];

String _formatDateComplete(DateTime d) =>
    '${_joursSemaine[d.weekday - 1]} ${d.day} ${_moisAnnee[d.month]} ${d.year}';

String _mention(double note) {
  if (note >= 18) return 'Excellent';
  if (note >= 16) return 'Très Bien';
  if (note >= 14) return 'Bien';
  if (note >= 12) return 'Assez Bien';
  if (note >= 10) return 'Passable';
  return 'Insuffisant';
}

Color _couleurMention(double note) {
  if (note >= 14) return const Color(0xFF16A34A);
  if (note >= 10) return const Color(0xFFD97706);
  return const Color(0xFFDC2626);
}

class FicheMatiereClasseScreen extends StatefulWidget {
  final int classeId;
  final String classeNom;
  final int matiereId;
  final String matiereNom;
  final Color couleurMatiere;
  final double coefficient;
  final String? enseignantNom;

  const FicheMatiereClasseScreen({
    super.key,
    required this.classeId,
    required this.classeNom,
    required this.matiereId,
    required this.matiereNom,
    required this.couleurMatiere,
    required this.coefficient,
    this.enseignantNom,
  });

  @override
  State<FicheMatiereClasseScreen> createState() =>
      _FicheMatiereClasseScreenState();
}

class _FicheMatiereClasseScreenState extends State<FicheMatiereClasseScreen> {
  bool _peutSaisir = false;

  // ── Cahier de texte ──────────────────────────────────
  List<dynamic> _seances = [];
  bool _chargementCahier = true;

  // ── Période active ───────────────────────────────────
  int? _periodeId;
  String? _periodeNom;
  bool _chargementPeriode = true;

  // ── Notes & moyennes ─────────────────────────────────
  List<dynamic> _elevesMoyennes = [];
  bool _chargementNotes = false;

  // ── Évaluations ──────────────────────────────────────
  List<dynamic> _evaluations = [];
  bool _chargementEvaluations = false;

  @override
  void initState() {
    super.initState();
    _chargerUtilisateur();
    _chargerCahier();
    _chargerPeriodeEtDonnees();
  }

  Future<void> _chargerUtilisateur() async {
    final utilisateur = await AuthService.getUtilisateur();
    if (mounted) {
      setState(
        () => _peutSaisir =
            utilisateur?.estEnseignant == true ||
            utilisateur?.estDirecteur == true,
      );
    }
  }

  Future<void> _chargerCahier() async {
    setState(() => _chargementCahier = true);
    try {
      final seances = await CahierTexteService.lister(
        classeId: widget.classeId,
        matiereId: widget.matiereId,
      );
      setState(() {
        _seances = seances;
        _chargementCahier = false;
      });
    } catch (e) {
      setState(() => _chargementCahier = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _chargerPeriodeEtDonnees() async {
    setState(() => _chargementPeriode = true);
    try {
      final annees = await AnneeService.listerAnnees();
      final anneeEnCours = annees.firstWhere(
        (a) => a['statut'] == 'en_cours',
        orElse: () => annees.isNotEmpty ? annees.first : null,
      );
      final anneeId = anneeEnCours?['id'] as int?;

      if (anneeId != null) {
        final periodes = await AnneeService.listerPeriodes(anneeId);
        final periodeActive = periodes.firstWhere(
          (p) => p['statut'] == 'actif',
          orElse: () => periodes.isNotEmpty ? periodes.first : null,
        );
        setState(() {
          _periodeId = periodeActive?['id'] as int?;
          _periodeNom = periodeActive?['nom'] as String?;
          _chargementPeriode = false;
        });
      } else {
        setState(() => _chargementPeriode = false);
      }

      if (_periodeId != null) {
        await Future.wait([_chargerNotes(), _chargerEvaluations()]);
      }
    } catch (e) {
      setState(() => _chargementPeriode = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _chargerNotes() async {
    if (_periodeId == null) return;
    setState(() => _chargementNotes = true);
    try {
      final eleves = await EvaluationService.moyennesClasse(
        classeId: widget.classeId,
        periodeId: _periodeId!,
      );
      setState(() {
        _elevesMoyennes = eleves;
        _chargementNotes = false;
      });
    } catch (e) {
      setState(() => _chargementNotes = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _chargerEvaluations() async {
    if (_periodeId == null) return;
    setState(() => _chargementEvaluations = true);
    try {
      final evaluations = await EvaluationService.listerEvaluations(
        classeId: widget.classeId,
        matiereId: widget.matiereId,
        periodeId: _periodeId!,
      );
      setState(() {
        _evaluations = evaluations;
        _chargementEvaluations = false;
      });
    } catch (e) {
      setState(() => _chargementEvaluations = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _afficherErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFDC2626),
      ),
    );
  }

  void _afficherSucces(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF16A34A),
      ),
    );
  }

  // Entrée de _elevesMoyennes.matieres correspondant à cette matière.
  dynamic _entreeMatiere(dynamic eleve) {
    final matieres = (eleve['matieres'] as List?) ?? [];
    return matieres.firstWhere(
      (m) => m['matiere_id'] == widget.matiereId,
      orElse: () => null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: widget.couleurMatiere,
          foregroundColor: Colors.white,
          title: Text(
            widget.matiereNom,
            style: GoogleFonts.sora(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${widget.classeNom} · Coef. ${widget.coefficient.toStringAsFixed(1)}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                TabBar(
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
                  indicatorColor: Colors.white,
                  labelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  tabs: const [
                    Tab(text: '📋 Cahier de texte'),
                    Tab(text: '📊 Notes & Moyennes'),
                    Tab(text: '📅 Évaluations'),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _tabCahierTexte(),
            _tabNotesEtMoyennes(),
            _tabEvaluations(),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // TAB 1 — CAHIER DE TEXTE
  // ══════════════════════════════════════════════════════

  Widget _tabCahierTexte() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _peutSaisir
          ? FloatingActionButton.extended(
              onPressed: () => _afficherDialogSeance(),
              backgroundColor: widget.couleurMatiere,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                'Ajouter une séance',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _chargerCahier,
        child: _chargementCahier
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                children: [
                  Text(
                    '${_seances.length} séance${_seances.length > 1 ? 's' : ''} enregistrée${_seances.length > 1 ? 's' : ''}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_seances.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'Aucune séance enregistrée',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF334155),
                          ),
                        ),
                      ),
                    )
                  else
                    ..._seances.map(_carteSeance),
                ],
              ),
      ),
    );
  }

  Widget _carteSeance(dynamic seance) {
    final dateCours = DateTime.tryParse(seance['date_cours'] as String? ?? '');
    final dateRemise = seance['date_remise_devoir'] != null
        ? DateTime.tryParse(seance['date_remise_devoir'] as String)
        : null;
    final exercices = seance['exercices'] as String?;
    final devoir = seance['devoir'] as String?;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      dateCours != null ? _formatDateComplete(dateCours) : '—',
                      style: GoogleFonts.sora(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  if (dateCours != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: widget.couleurMatiere.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _joursSemaine[dateCours.weekday - 1],
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: widget.couleurMatiere,
                        ),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(
                      Icons.edit,
                      size: 18,
                      color: Color(0xFF1E3A8A),
                    ),
                    onPressed: () => _afficherDialogSeance(seance: seance),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete,
                      size: 18,
                      color: Color(0xFFDC2626),
                    ),
                    onPressed: () => _confirmerSuppressionSeance(seance),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '📖 COURS DU JOUR',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                seance['cours_du_jour'] as String? ?? '',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF0F172A),
                ),
              ),
              if (exercices != null && exercices.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  '✏️ EXERCICES',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  exercices,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
              if (devoir != null && devoir.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.assignment_outlined,
                        color: Color(0xFFD97706),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dateRemise != null
                                  ? 'Devoir à remettre le ${_formatDateComplete(dateRemise)}'
                                  : 'Devoir',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF92400E),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              devoir,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _afficherDialogSeance({dynamic seance}) async {
    final estModification = seance != null;
    DateTime dateCours = estModification && seance['date_cours'] != null
        ? DateTime.tryParse(seance['date_cours'] as String) ?? DateTime.now()
        : DateTime.now();
    DateTime? dateRemiseDevoir =
        estModification && seance['date_remise_devoir'] != null
        ? DateTime.tryParse(seance['date_remise_devoir'] as String)
        : null;
    final coursController = TextEditingController(
      text: estModification ? seance['cours_du_jour'] as String? ?? '' : '',
    );
    final exercicesController = TextEditingController(
      text: estModification ? seance['exercices'] as String? ?? '' : '',
    );
    final devoirController = TextEditingController(
      text: estModification ? seance['devoir'] as String? ?? '' : '',
    );

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480, maxHeight: 700),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      estModification
                          ? 'Modifier la séance'
                          : 'Nouvelle séance',
                      style: GoogleFonts.sora(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.date_range),
                              title: Text(
                                'Date du cours : ${_formatDateComplete(dateCours)}',
                              ),
                              onTap: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: dateCours,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                );
                                if (d != null)
                                  setStateDialog(() => dateCours = d);
                              },
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: coursController,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: 'Cours du jour *',
                                hintText: 'Décrivez le contenu du cours...',
                                alignLabelWithHint: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: exercicesController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Exercices',
                                hintText: 'Exercices donnés aux élèves...',
                                alignLabelWithHint: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: devoirController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Devoir',
                                hintText: 'Devoir à faire à la maison...',
                                alignLabelWithHint: true,
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => setStateDialog(() {}),
                            ),
                            if (devoirController.text.trim().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.event),
                                title: Text(
                                  dateRemiseDevoir != null
                                      ? 'Date de remise : ${_formatDateComplete(dateRemiseDevoir!)}'
                                      : 'Date de remise (optionnel)',
                                ),
                                onTap: () async {
                                  final d = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.now(),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2035),
                                  );
                                  if (d != null)
                                    setStateDialog(() => dateRemiseDevoir = d);
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Annuler'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.couleurMatiere,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () async {
                              if (coursController.text.trim().isEmpty) {
                                _afficherErreur(
                                  'Le cours du jour est obligatoire',
                                );
                                return;
                              }
                              try {
                                if (estModification) {
                                  await CahierTexteService.modifier(
                                    seance['id'] as int,
                                    dateCours: _formatDate(dateCours),
                                    coursDuJour: coursController.text,
                                    exercices: exercicesController.text.isEmpty
                                        ? null
                                        : exercicesController.text,
                                    devoir: devoirController.text.isEmpty
                                        ? null
                                        : devoirController.text,
                                    dateRemiseDevoir: dateRemiseDevoir != null
                                        ? _formatDate(dateRemiseDevoir!)
                                        : null,
                                  );
                                  _afficherSucces(
                                    'Séance modifiée avec succès',
                                  );
                                } else {
                                  await CahierTexteService.creer(
                                    classeId: widget.classeId,
                                    matiereId: widget.matiereId,
                                    dateCours: _formatDate(dateCours),
                                    coursDuJour: coursController.text,
                                    exercices: exercicesController.text.isEmpty
                                        ? null
                                        : exercicesController.text,
                                    devoir: devoirController.text.isEmpty
                                        ? null
                                        : devoirController.text,
                                    dateRemiseDevoir: dateRemiseDevoir != null
                                        ? _formatDate(dateRemiseDevoir!)
                                        : null,
                                  );
                                  _afficherSucces('Séance enregistrée');
                                }
                                if (context.mounted) Navigator.pop(context);
                                _chargerCahier();
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
          );
        },
      ),
    );

    coursController.dispose();
    exercicesController.dispose();
    devoirController.dispose();
  }

  Future<void> _confirmerSuppressionSeance(dynamic seance) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette séance ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirme != true) return;

    try {
      await CahierTexteService.supprimer(seance['id'] as int);
      _afficherSucces('Séance supprimée');
      _chargerCahier();
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  String _formatDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  // ══════════════════════════════════════════════════════
  // TAB 2 — NOTES & MOYENNES
  // ══════════════════════════════════════════════════════

  Widget _tabNotesEtMoyennes() {
    if (_chargementPeriode || _chargementNotes) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_periodeId == null) {
      return Center(
        child: Text(
          'Aucune période active',
          style: GoogleFonts.inter(color: const Color(0xFF334155)),
        ),
      );
    }

    final lignes = _elevesMoyennes
        .map((e) => {'eleve': e, 'entree': _entreeMatiere(e)})
        .where((l) => l['entree'] != null)
        .toList();

    final moyennesValides = lignes
        .map((l) => (l['entree'] as Map)['moyenne_finale'])
        .where((m) => m != null)
        .map((m) => (m as num).toDouble())
        .toList();

    final moyenneClasse = moyennesValides.isEmpty
        ? null
        : moyennesValides.reduce((a, b) => a + b) / moyennesValides.length;

    dynamic meilleureLigne;
    double? meilleureNote;
    for (final l in lignes) {
      final note = (l['entree'] as Map)['moyenne_finale'];
      if (note == null) continue;
      final valeur = (note as num).toDouble();
      if (meilleureNote == null || valeur > meilleureNote) {
        meilleureNote = valeur;
        meilleureLigne = l;
      }
    }

    final nombreSous10 = moyennesValides.where((m) => m < 10).length;

    return RefreshIndicator(
      onRefresh: _chargerNotes,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: _miniCard(
                  'Moyenne classe',
                  moyenneClasse != null
                      ? '${moyenneClasse.toStringAsFixed(2)}/20'
                      : '—',
                  const Color(0xFF1E3A8A),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniCard(
                  'Meilleur élève',
                  meilleureLigne != null
                      ? '${(meilleureLigne['eleve'] as Map)['nom']}'
                      : '—',
                  const Color(0xFF16A34A),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniCard(
                  'Élèves < 10',
                  '$nombreSous10',
                  const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (lignes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Aucune note enregistrée pour $_periodeNom',
                  style: GoogleFonts.inter(color: const Color(0xFF334155)),
                ),
              ),
            )
          else
            ...lignes.map((l) => _ligneEleve(l['eleve'], l['entree'])),
        ],
      ),
    );
  }

  Widget _miniCard(String label, String valeur, Color couleur) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            valeur,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.sora(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: couleur,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ligneEleve(dynamic eleve, dynamic entree) {
    final nom = '${eleve['nom']} ${eleve['prenom']}';
    final moyenne = entree['moyenne_finale'] != null
        ? (entree['moyenne_finale'] as num).toDouble()
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: widget.couleurMatiere.withValues(alpha: 0.15),
            child: Text(
              (eleve['nom'] as String).substring(0, 1).toUpperCase(),
              style: GoogleFonts.sora(
                fontWeight: FontWeight.w700,
                color: widget.couleurMatiere,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              nom,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (moyenne != null) ...[
            Text(
              '${moyenne.toStringAsFixed(2)}/20',
              style: GoogleFonts.sora(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: moyenne >= 10
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFDC2626),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _couleurMention(moyenne).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _mention(moyenne),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _couleurMention(moyenne),
                ),
              ),
            ),
          ] else
            Text(
              '—',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF94A3B8),
              ),
            ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // TAB 3 — ÉVALUATIONS
  // ══════════════════════════════════════════════════════

  Widget _tabEvaluations() {
    if (_chargementPeriode || _chargementEvaluations) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_periodeId == null) {
      return Center(
        child: Text(
          'Aucune période active',
          style: GoogleFonts.inter(color: const Color(0xFF334155)),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _chargerEvaluations,
      child: _evaluations.isEmpty
          ? ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Aucune évaluation pour $_periodeNom',
                      style: GoogleFonts.inter(color: const Color(0xFF334155)),
                    ),
                  ),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _evaluations.length,
              itemBuilder: (context, index) =>
                  _carteEvaluation(_evaluations[index]),
            ),
    );
  }

  Widget _carteEvaluation(dynamic evaluation) {
    final type = evaluation['type'] as String;
    final estDevoir = type == 'devoir';
    final date = (evaluation['date_evaluation'] as String?)?.split('T').first;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color:
                  (estDevoir
                          ? const Color(0xFF0284C7)
                          : const Color(0xFF7C3AED))
                      .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              estDevoir ? 'Devoir' : 'Composition',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: estDevoir
                    ? const Color(0xFF0284C7)
                    : const Color(0xFF7C3AED),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${evaluation['libelle'] ?? ''} · N°${evaluation['numero']}',
                  style: GoogleFonts.sora(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                if (date != null)
                  Text(
                    date,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _afficherNotesEvaluation(evaluation),
            child: const Text('Voir les notes'),
          ),
        ],
      ),
    );
  }

  Future<void> _afficherNotesEvaluation(dynamic evaluation) async {
    final notes = (evaluation['notes'] as List?) ?? [];
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  evaluation['libelle'] as String? ?? 'Notes',
                  style: GoogleFonts.sora(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: notes.isEmpty
                      ? Center(
                          child: Text(
                            'Aucune note saisie',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF334155),
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: notes.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final n = notes[index];
                            final valeur = (n['valeur'] as num?)?.toDouble();
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${n['nom']} ${n['prenom']}',
                                      style: GoogleFonts.inter(fontSize: 14),
                                    ),
                                  ),
                                  Text(
                                    valeur != null
                                        ? '${valeur.toStringAsFixed(2)}/20'
                                        : '—',
                                    style: GoogleFonts.sora(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: valeur != null && valeur >= 10
                                          ? const Color(0xFF16A34A)
                                          : const Color(0xFFDC2626),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fermer'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
