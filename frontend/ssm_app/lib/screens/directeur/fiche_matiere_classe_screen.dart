import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../services/annee_service.dart';
import '../../services/cahier_texte_service.dart';
import '../../services/evaluation_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_avatar.dart';
import '../../widgets/ssm/ssm_data_table.dart';
import '../../widgets/ssm/ssm_panel.dart';
import '../../widgets/ssm/ssm_pill.dart';
import '../../widgets/ssm/ssm_stat_card.dart';

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
  if (note >= 14) return SSMPalette.teal;
  if (note >= 10) return SSMPalette.ambre;
  return SSMPalette.rouge;
}

InputDecoration _decorationChamp(String label, {bool dense = false, String? hint}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2),
    isDense: dense,
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
      SnackBar(content: Text(message), backgroundColor: SSMPalette.rouge),
    );
  }

  void _afficherSucces(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: SSMPalette.teal),
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
        backgroundColor: SSMPalette.fond,
        appBar: AppBar(
          backgroundColor: widget.couleurMatiere,
          foregroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.matiereNom,
            style: GoogleFonts.sora(
              fontSize: 17,
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
                      color: Colors.white.withValues(alpha: 0.75),
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
        body: Column(
          children: [
            _breadcrumb(context),
            Expanded(
              child: TabBarView(
                children: [
                  _tabCahierTexte(),
                  _tabNotesEtMoyennes(),
                  _tabEvaluations(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _breadcrumb(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(
        color: SSMPalette.blanc,
        border: Border(bottom: BorderSide(color: SSMPalette.bordure)),
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: () =>
                Navigator.popUntil(context, (route) => route.isFirst),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Classes',
              style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte3),
            ),
          ),
          const Icon(Icons.chevron_right, size: 14, color: SSMPalette.texte3),
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              widget.classeNom,
              style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte3),
            ),
          ),
          const Icon(Icons.chevron_right, size: 14, color: SSMPalette.texte3),
          Text(
            widget.matiereNom,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: SSMPalette.texte1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter une séance'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _chargerCahier,
        color: widget.couleurMatiere,
        child: _chargementCahier
            ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                children: [
                  Text(
                    '${_seances.length} séance${_seances.length > 1 ? 's' : ''} enregistrée${_seances.length > 1 ? 's' : ''}',
                    style: GoogleFonts.inter(fontSize: 12.5, color: SSMPalette.texte2),
                  ),
                  const SizedBox(height: 12),
                  if (_seances.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'Aucune séance enregistrée',
                          style: GoogleFonts.inter(color: SSMPalette.texte3),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SSMPalette.blanc,
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        border: Border.all(color: SSMPalette.bordure),
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
                  style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: SSMPalette.texte1),
                ),
              ),
              if (dateCours != null)
                SSMPill.couleur(label: _joursSemaine[dateCours.weekday - 1], couleur: widget.couleurMatiere),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18, color: SSMPalette.indigo),
                onPressed: () => _afficherDialogSeance(seance: seance),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: SSMPalette.rouge),
                onPressed: () => _confirmerSuppressionSeance(seance),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '📖 COURS DU JOUR',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: SSMPalette.texte3),
          ),
          const SizedBox(height: 2),
          Text(
            seance['cours_du_jour'] as String? ?? '',
            style: GoogleFonts.inter(fontSize: 13.5, color: SSMPalette.texte1),
          ),
          if (exercices != null && exercices.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '✏️ EXERCICES',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: SSMPalette.texte3),
            ),
            const SizedBox(height: 2),
            Text(exercices, style: GoogleFonts.inter(fontSize: 13.5, color: SSMPalette.texte1)),
          ],
          if (devoir != null && devoir.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: SSMPalette.ambreClair,
                borderRadius: BorderRadius.circular(SSMRayons.petit),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.assignment_outlined, color: SSMPalette.ambre, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateRemise != null
                              ? 'Devoir à remettre le ${_formatDateComplete(dateRemise)}'
                              : 'Devoir',
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: SSMPalette.ambre),
                        ),
                        const SizedBox(height: 2),
                        Text(devoir, style: GoogleFonts.inter(fontSize: 12.5, color: SSMPalette.texte1)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
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
              borderRadius: BorderRadius.circular(SSMRayons.grand),
            ),
            backgroundColor: SSMPalette.blanc,
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
                      style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.date_range, color: SSMPalette.texte2),
                              title: Text(
                                'Date du cours : ${_formatDateComplete(dateCours)}',
                                style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte1),
                              ),
                              onTap: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: dateCours,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                );
                                if (d != null) {
                                  setStateDialog(() => dateCours = d);
                                }
                              },
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: coursController,
                              maxLines: 4,
                              decoration: _decorationChamp('Cours du jour *', hint: 'Décrivez le contenu du cours...'),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: exercicesController,
                              maxLines: 3,
                              decoration: _decorationChamp('Exercices', hint: 'Exercices donnés aux élèves...'),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: devoirController,
                              maxLines: 3,
                              decoration: _decorationChamp('Devoir', hint: 'Devoir à faire à la maison...'),
                              onChanged: (_) => setStateDialog(() {}),
                            ),
                            if (devoirController.text.trim().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.event, color: SSMPalette.texte2),
                                title: Text(
                                  dateRemiseDevoir != null
                                      ? 'Date de remise : ${_formatDateComplete(dateRemiseDevoir!)}'
                                      : 'Date de remise (optionnel)',
                                  style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte1),
                                ),
                                onTap: () async {
                                  final d = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.now(),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2035),
                                  );
                                  if (d != null) {
                                    setStateDialog(() => dateRemiseDevoir = d);
                                  }
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
                            child: Text('Annuler', style: GoogleFonts.inter(color: SSMPalette.texte2)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.couleurMatiere,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(SSMRayons.moyen),
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
                const Icon(Icons.warning_amber_rounded, color: SSMPalette.ambre, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Supprimer cette séance ?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.texte1),
                ),
                const SizedBox(height: 6),
                Text(
                  'Cette action est irréversible.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte3),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Supprimer'),
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
      return const Center(child: CircularProgressIndicator(color: SSMPalette.indigo));
    }
    if (_periodeId == null) {
      return Center(
        child: Text(
          'Aucune période active',
          style: GoogleFonts.inter(color: SSMPalette.texte3),
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
      color: widget.couleurMatiere,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: SSMStatCard(
                  icone: Icons.groups_outlined,
                  couleur: SSMPalette.indigo,
                  valeur: moyenneClasse != null ? '${moyenneClasse.toStringAsFixed(2)}/20' : '—',
                  label: 'Moyenne classe',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SSMStatCard(
                  icone: Icons.star_outline,
                  couleur: SSMPalette.teal,
                  valeur: meilleureLigne != null ? '${(meilleureLigne['eleve'] as Map)['nom']}' : '—',
                  label: 'Meilleur élève',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SSMStatCard(
                  icone: Icons.trending_down,
                  couleur: SSMPalette.rouge,
                  valeur: '$nombreSous10',
                  label: 'Élèves < 10',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (lignes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'Aucune note enregistrée pour $_periodeNom',
                  style: GoogleFonts.inter(color: SSMPalette.texte3),
                ),
              ),
            )
          else
            SSMPanel(
              titre: 'Élèves',
              padding: EdgeInsets.zero,
              child: SSMDataTable(
                colonnes: const [
                  SSMDataColumn('Élève'),
                  SSMDataColumn('Moyenne'),
                  SSMDataColumn('Mention'),
                ],
                lignes: [for (final l in lignes) _ligneEleveNote(l['eleve'], l['entree'])],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _ligneEleveNote(dynamic eleve, dynamic entree) {
    final nom = '${eleve['nom']} ${eleve['prenom']}';
    final moyenne = entree['moyenne_finale'] != null
        ? (entree['moyenne_finale'] as num).toDouble()
        : null;

    return [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SSMAvatar(nom: eleve['nom'] as String? ?? '?', rayon: 15, couleur: widget.couleurMatiere),
          const SizedBox(width: 8),
          Text(nom, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
        ],
      ),
      moyenne != null
          ? Text(
              '${moyenne.toStringAsFixed(2)}/20',
              style: GoogleFonts.sora(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: moyenne >= 10 ? SSMPalette.teal : SSMPalette.rouge,
              ),
            )
          : Text('—', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte3)),
      moyenne != null
          ? SSMPill.couleur(label: _mention(moyenne), couleur: _couleurMention(moyenne))
          : const SizedBox.shrink(),
    ];
  }

  // ══════════════════════════════════════════════════════
  // TAB 3 — ÉVALUATIONS
  // ══════════════════════════════════════════════════════

  Widget _tabEvaluations() {
    if (_chargementPeriode || _chargementEvaluations) {
      return const Center(child: CircularProgressIndicator(color: SSMPalette.indigo));
    }
    if (_periodeId == null) {
      return Center(
        child: Text(
          'Aucune période active',
          style: GoogleFonts.inter(color: SSMPalette.texte3),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _chargerEvaluations,
      color: widget.couleurMatiere,
      child: _evaluations.isEmpty
          ? ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'Aucune évaluation pour $_periodeNom',
                      style: GoogleFonts.inter(color: SSMPalette.texte3),
                    ),
                  ),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SSMPanel(
                  titre: 'Évaluations',
                  padding: EdgeInsets.zero,
                  child: SSMDataTable(
                    colonnes: const [
                      SSMDataColumn('Type'),
                      SSMDataColumn('Évaluation'),
                      SSMDataColumn('Date'),
                      SSMDataColumn(''),
                    ],
                    lignes: [for (final e in _evaluations) _ligneEvaluation(e)],
                  ),
                ),
              ],
            ),
    );
  }

  List<Widget> _ligneEvaluation(dynamic evaluation) {
    final type = evaluation['type'] as String;
    final estDevoir = type == 'devoir';
    final date = (evaluation['date_evaluation'] as String?)?.split('T').first;

    return [
      SSMPill.couleur(label: estDevoir ? 'Devoir' : 'Composition', couleur: estDevoir ? SSMPalette.indigo : SSMPalette.ambre),
      Text(
        '${evaluation['libelle'] ?? ''} · N°${evaluation['numero']}',
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: SSMPalette.texte1),
      ),
      Text(date ?? '—', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte3)),
      TextButton(
        onPressed: () => _afficherNotesEvaluation(evaluation),
        child: const Text('Voir les notes'),
      ),
    ];
  }

  Future<void> _afficherNotesEvaluation(dynamic evaluation) async {
    final notes = (evaluation['notes'] as List?) ?? [];
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
        backgroundColor: SSMPalette.blanc,
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
                  style: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: notes.isEmpty
                      ? Center(
                          child: Text(
                            'Aucune note saisie',
                            style: GoogleFonts.inter(color: SSMPalette.texte3),
                          ),
                        )
                      : ListView.separated(
                          itemCount: notes.length,
                          separatorBuilder: (context, index) => const Divider(height: 1, color: SSMPalette.bordure),
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
                                      style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte1),
                                    ),
                                  ),
                                  Text(
                                    valeur != null ? '${valeur.toStringAsFixed(2)}/20' : '—',
                                    style: GoogleFonts.sora(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: valeur != null && valeur >= 10 ? SSMPalette.teal : SSMPalette.rouge,
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
                    child: Text('Fermer', style: GoogleFonts.inter(color: SSMPalette.texte2)),
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
