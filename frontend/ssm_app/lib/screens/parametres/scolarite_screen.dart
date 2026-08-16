import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/utilisateur.dart';
import '../../models/parametre_ecole_model.dart';
import '../../services/auth_service.dart';
import '../../services/parametre_ecole_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_alert_item.dart';
import '../../widgets/ssm/ssm_panel.dart';
import '../../widgets/ssm/ssm_sous_entete.dart';

const Map<String, String> _modelesBulletin = {
  'standard': 'Standard',
  'compact': 'Compact',
  'detaille': 'Détaillé',
};

InputDecoration _decorationChamp(String label, {IconData? icone, String? aide}) {
  return InputDecoration(
    labelText: label,
    labelStyle: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2),
    helperText: aide,
    prefixIcon: icone != null ? Icon(icone, size: 20, color: SSMPalette.texte3) : null,
    filled: true,
    fillColor: const Color(0xFFF9FAFB),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen), borderSide: const BorderSide(color: SSMPalette.indigo, width: 1.5)),
  );
}

Widget _boutonEnregistrer({required bool enCours, required bool visible, required VoidCallback onPressed}) {
  if (!visible) return const SizedBox.shrink();
  return SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: SSMPalette.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
      ),
      onPressed: enCours ? null : onPressed,
      child: enCours
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Text('Enregistrer'),
    ),
  );
}

// ══════════════════════════════════════════════════════════
// Section Scolarité : 4 sous-sections (Organisation académique, Notes &
// moyennes, Bulletins, Règles de validation) empilées en ssm_panel — 3
// ressources API indépendantes (parametres/academique, /bulletins,
// /validation-notes), chacune avec son propre bouton "Enregistrer".
// ongletInitial fait défiler automatiquement vers la section demandée
// lorsqu'on arrive depuis un sous-item du menu Paramètres.
// ══════════════════════════════════════════════════════════
class ScolariteScreen extends StatefulWidget {
  final int ongletInitial;
  const ScolariteScreen({super.key, this.ongletInitial = 0});

  @override
  State<ScolariteScreen> createState() => _ScolariteScreenState();
}

class _ScolariteScreenState extends State<ScolariteScreen> {
  final _cleOrganisation = GlobalKey();
  final _cleNotesMoyennes = GlobalKey();
  final _cleBulletins = GlobalKey();
  final _cleValidation = GlobalKey();

  Utilisateur? _utilisateur;
  bool _chargement = true;
  String? _erreur;

  ParametreAcademique? _academique;
  ParametreBulletin? _bulletin;
  ParametreValidationNote? _validation;

  bool get _lectureSeule => _utilisateur?.estDirecteur != true;

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
      final resultats = await Future.wait([
        AuthService.getUtilisateur(),
        ParametreEcoleService.getParametreAcademique(),
        ParametreEcoleService.getParametreBulletin(),
        ParametreEcoleService.getParametreValidationNote(),
      ]);
      if (!mounted) return;
      setState(() {
        _utilisateur = resultats[0] as Utilisateur?;
        _academique = resultats[1] as ParametreAcademique;
        _bulletin = resultats[2] as ParametreBulletin;
        _validation = resultats[3] as ParametreValidationNote;
        _chargement = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _allerVersSection(widget.ongletInitial));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _allerVersSection(int index) {
    final cle = switch (index) {
      1 => _cleNotesMoyennes,
      2 => _cleBulletins,
      3 => _cleValidation,
      _ => _cleOrganisation,
    };
    final contexteCible = cle.currentContext;
    if (contexteCible != null) {
      Scrollable.ensureVisible(contexteCible, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _snack(String message, {bool erreur = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: erreur ? SSMPalette.rouge : SSMPalette.teal),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SSMPalette.fond,
      body: SafeArea(
        child: Column(
          children: [
            SSMSousEnTete(titre: 'Scolarité', sousTitre: 'Organisation, notes, bulletins et validation', onRetour: () => Navigator.pop(context)),
            Expanded(
              child: _chargement
                  ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
                  : _erreur != null && _academique == null
                      ? _carteErreur(_erreur!, _charger)
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                          children: [
                            if (_lectureSeule) ...[
                              const SSMAlertItem(
                                type: SSMAlerteType.avertissement,
                                icone: Icons.lock_outline,
                                titre: 'Lecture seule',
                                sousTitre: 'Seul le directeur peut modifier ces paramètres.',
                              ),
                              const SizedBox(height: 16),
                            ],
                            SSMPanel(
                              key: _cleOrganisation,
                              titre: 'Organisation académique',
                              child: _SectionOrganisation(academique: _academique!, lectureSeule: _lectureSeule, onSnack: _snack),
                            ),
                            const SizedBox(height: 16),
                            SSMPanel(
                              key: _cleNotesMoyennes,
                              titre: 'Notes & moyennes',
                              child: _SectionNotesMoyennes(academique: _academique!, lectureSeule: _lectureSeule, onSnack: _snack),
                            ),
                            const SizedBox(height: 16),
                            SSMPanel(
                              key: _cleBulletins,
                              titre: 'Bulletins',
                              child: _SectionBulletins(bulletin: _bulletin!, lectureSeule: _lectureSeule, onSnack: _snack),
                            ),
                            const SizedBox(height: 16),
                            SSMPanel(
                              key: _cleValidation,
                              titre: 'Règles de validation',
                              child: _SectionValidation(validation: _validation!, lectureSeule: _lectureSeule, onSnack: _snack),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _carteErreur(String message, Future<void> Function() onReessayer) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: SSMPalette.rouge, size: 36),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center, style: GoogleFonts.inter(color: SSMPalette.texte2)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onReessayer, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// Organisation académique (type de découpage)
// ══════════════════════════════════════════════════════════
class _SectionOrganisation extends StatefulWidget {
  final ParametreAcademique academique;
  final bool lectureSeule;
  final void Function(String, {bool erreur}) onSnack;

  const _SectionOrganisation({required this.academique, required this.lectureSeule, required this.onSnack});

  @override
  State<_SectionOrganisation> createState() => _SectionOrganisationState();
}

class _SectionOrganisationState extends State<_SectionOrganisation> {
  late String? _typeDecoupage;
  bool _enregistrementEnCours = false;

  @override
  void initState() {
    super.initState();
    _typeDecoupage = widget.academique.typeDecoupage;
  }

  Future<void> _demanderChangement(String nouveauType) async {
    if (nouveauType == _typeDecoupage) return;

    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SSMPalette.blanc,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
        title: Text('Changer le découpage académique ?', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
        content: Text(
          'Le découpage passera de "${_libelleDecoupage(_typeDecoupage)}" à "${_libelleDecoupage(nouveauType)}" pour '
          "l'année scolaire active.\n\nSi des périodes existent déjà pour cette année, le changement sera bloqué.",
          style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Annuler', style: GoogleFonts.inter(color: SSMPalette.texte2))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.ambre, foregroundColor: Colors.white, elevation: 0),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirme != true) return;

    setState(() => _enregistrementEnCours = true);
    try {
      final resultat = await ParametreEcoleService.updateParametreAcademique(
        widget.academique.copyWith(typeDecoupage: nouveauType),
        inclureTypeDecoupage: true,
      );
      if (!mounted) return;
      setState(() {
        _typeDecoupage = nouveauType;
        _enregistrementEnCours = false;
      });
      widget.onSnack('Découpage académique mis à jour avec succès');
      final avertissements = (resultat['avertissements'] as List).cast<String>();
      for (final a in avertissements) {
        widget.onSnack(a);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _enregistrementEnCours = false);
      widget.onSnack(e.toString().replaceAll('Exception: ', ''), erreur: true);
    }
  }

  String _libelleDecoupage(String? type) => switch (type) {
        'trimestres' => 'Trimestres',
        'semestres' => 'Semestres',
        _ => 'Non défini',
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Ce réglage détermine le découpage de l'année scolaire active (trimestres ou semestres). "
          "Il est géré ici pour la commodité, mais reste stocké au niveau de l'année scolaire elle-même.",
          style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2),
        ),
        const SizedBox(height: 12),
        _optionDecoupage('trimestres', 'Trimestres', 'Découpage en 3 périodes'),
        const SizedBox(height: 10),
        _optionDecoupage('semestres', 'Semestres', 'Découpage en 2 périodes'),
        if (_enregistrementEnCours) ...[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator(color: SSMPalette.indigo)),
        ],
      ],
    );
  }

  Widget _optionDecoupage(String valeur, String titre, String sousTitre) {
    final selectionne = _typeDecoupage == valeur;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        onTap: widget.lectureSeule || _enregistrementEnCours ? null : () => _demanderChangement(valeur),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selectionne ? SSMPalette.indigoClair : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(SSMRayons.grand),
            border: Border.all(color: selectionne ? SSMPalette.indigo : const Color(0xFFE5E7EB), width: selectionne ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Icon(selectionne ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: selectionne ? SSMPalette.indigo : SSMPalette.texte3),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titre, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: SSMPalette.texte1)),
                    Text(sousTitre, style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// Notes & moyennes
// ══════════════════════════════════════════════════════════
class _SectionNotesMoyennes extends StatefulWidget {
  final ParametreAcademique academique;
  final bool lectureSeule;
  final void Function(String, {bool erreur}) onSnack;

  const _SectionNotesMoyennes({required this.academique, required this.lectureSeule, required this.onSnack});

  @override
  State<_SectionNotesMoyennes> createState() => _SectionNotesMoyennesState();
}

class _SectionNotesMoyennesState extends State<_SectionNotesMoyennes> {
  late final TextEditingController _baremeController;
  late bool _coefMatiere;
  late bool _coefClasse;
  late bool _coefNiveau;
  late String _modeCalcul;
  bool _enregistrementEnCours = false;

  @override
  void initState() {
    super.initState();
    _baremeController = TextEditingController(text: widget.academique.baremeNoteMax.toString());
    _coefMatiere = widget.academique.coefficientsParMatiere;
    _coefClasse = widget.academique.coefficientsParClasse;
    _coefNiveau = widget.academique.coefficientsParNiveau;
    _modeCalcul = widget.academique.modeCalculMoyenne;
  }

  @override
  void dispose() {
    _baremeController.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    final bareme = int.tryParse(_baremeController.text.trim());
    if (bareme == null || bareme < 10 || bareme > 100) {
      widget.onSnack('Le barème doit être un nombre entre 10 et 100.', erreur: true);
      return;
    }

    setState(() => _enregistrementEnCours = true);
    try {
      final resultat = await ParametreEcoleService.updateParametreAcademique(
        widget.academique.copyWith(
          baremeNoteMax: bareme,
          coefficientsParMatiere: _coefMatiere,
          coefficientsParClasse: _coefClasse,
          coefficientsParNiveau: _coefNiveau,
          modeCalculMoyenne: _modeCalcul,
        ),
      );
      if (!mounted) return;
      setState(() => _enregistrementEnCours = false);
      widget.onSnack('Paramètres de notation enregistrés avec succès');
      final avertissements = (resultat['avertissements'] as List).cast<String>();
      for (final a in avertissements) {
        widget.onSnack(a);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _enregistrementEnCours = false);
      widget.onSnack(e.toString().replaceAll('Exception: ', ''), erreur: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _baremeController,
          enabled: !widget.lectureSeule,
          keyboardType: TextInputType.number,
          style: GoogleFonts.jetBrainsMono(fontSize: 14, color: SSMPalette.texte1),
          decoration: _decorationChamp(
            'Barème maximal des notes',
            icone: Icons.grade_outlined,
            aide: "S'applique uniquement aux futures saisies de notes.",
          ),
        ),
        const SizedBox(height: 14),
        Text('COEFFICIENTS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: SSMPalette.indigo, letterSpacing: 0.4)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: SSMPalette.indigo,
          value: _coefMatiere,
          title: Text('Coefficients par matière', style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte1)),
          onChanged: widget.lectureSeule ? null : (v) => setState(() => _coefMatiere = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: SSMPalette.indigo,
          value: _coefClasse,
          title: Text('Coefficients par classe', style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte1)),
          onChanged: widget.lectureSeule ? null : (v) => setState(() => _coefClasse = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: SSMPalette.indigo,
          value: _coefNiveau,
          title: Text('Coefficients par niveau', style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte1)),
          onChanged: widget.lectureSeule ? null : (v) => setState(() => _coefNiveau = v),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _modeCalcul,
          decoration: _decorationChamp('Mode de calcul de la moyenne', icone: Icons.calculate_outlined),
          items: [
            DropdownMenuItem(value: 'simple', child: Text('Simple (moyenne devoir + composition)', style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte1))),
            DropdownMenuItem(value: 'ponderee', child: Text('Pondérée', style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte1))),
          ],
          onChanged: widget.lectureSeule ? null : (v) => setState(() => _modeCalcul = v ?? _modeCalcul),
        ),
        const SizedBox(height: 16),
        _boutonEnregistrer(enCours: _enregistrementEnCours, visible: !widget.lectureSeule, onPressed: _enregistrer),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
// Bulletins
// ══════════════════════════════════════════════════════════
class _SectionBulletins extends StatefulWidget {
  final ParametreBulletin bulletin;
  final bool lectureSeule;
  final void Function(String, {bool erreur}) onSnack;

  const _SectionBulletins({required this.bulletin, required this.lectureSeule, required this.onSnack});

  @override
  State<_SectionBulletins> createState() => _SectionBulletinsState();
}

class _SectionBulletinsState extends State<_SectionBulletins> {
  late ParametreBulletin _valeur;
  bool _enregistrementEnCours = false;

  @override
  void initState() {
    super.initState();
    _valeur = widget.bulletin;
  }

  Future<void> _enregistrer() async {
    setState(() => _enregistrementEnCours = true);
    try {
      final misAJour = await ParametreEcoleService.updateParametreBulletin(_valeur);
      if (!mounted) return;
      setState(() {
        _valeur = misAJour;
        _enregistrementEnCours = false;
      });
      widget.onSnack('Configuration des bulletins enregistrée avec succès');
    } catch (e) {
      if (!mounted) return;
      setState(() => _enregistrementEnCours = false);
      widget.onSnack(e.toString().replaceAll('Exception: ', ''), erreur: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('MODÈLE', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: SSMPalette.indigo, letterSpacing: 0.4)),
        const SizedBox(height: 10),
        Row(
          children: _modelesBulletin.entries
              .map((e) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: _carteModele(e.key, e.value))))
              .toList(),
        ),
        const SizedBox(height: 18),
        Text('ÉLÉMENTS AFFICHÉS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: SSMPalette.indigo, letterSpacing: 0.4)),
        _switch('Logo de l\'établissement', _valeur.afficherLogo, (v) => setState(() => _valeur = _valeur.copyWith(afficherLogo: v))),
        _switch('Matricule des élèves', _valeur.afficherMatricule, (v) => setState(() => _valeur = _valeur.copyWith(afficherMatricule: v))),
        _switch('Effectif de la classe', _valeur.afficherEffectif, (v) => setState(() => _valeur = _valeur.copyWith(afficherEffectif: v))),
        _switch('Coefficients', _valeur.afficherCoefficients, (v) => setState(() => _valeur = _valeur.copyWith(afficherCoefficients: v))),
        _switch('Rang de l\'élève', _valeur.afficherRang, (v) => setState(() => _valeur = _valeur.copyWith(afficherRang: v))),
        _switch('Appréciations', _valeur.afficherAppreciations, (v) => setState(() => _valeur = _valeur.copyWith(afficherAppreciations: v))),
        _switch('Absences', _valeur.afficherAbsences, (v) => setState(() => _valeur = _valeur.copyWith(afficherAbsences: v))),
        _switch('Retards', _valeur.afficherRetards, (v) => setState(() => _valeur = _valeur.copyWith(afficherRetards: v))),
        _switch('Décision du conseil de classe', _valeur.afficherDecisionConseil, (v) => setState(() => _valeur = _valeur.copyWith(afficherDecisionConseil: v))),
        _switch('Signature du directeur', _valeur.afficherSignatureDirecteur, (v) => setState(() => _valeur = _valeur.copyWith(afficherSignatureDirecteur: v))),
        _switch('Cachet de l\'établissement', _valeur.afficherCachet, (v) => setState(() => _valeur = _valeur.copyWith(afficherCachet: v))),
        const SizedBox(height: 16),
        _boutonEnregistrer(enCours: _enregistrementEnCours, visible: !widget.lectureSeule, onPressed: _enregistrer),
      ],
    );
  }

  Widget _switch(String label, bool valeur, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      activeThumbColor: SSMPalette.indigo,
      value: valeur,
      title: Text(label, style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte1)),
      onChanged: widget.lectureSeule ? null : onChanged,
    );
  }

  // Mini-aperçu visuel schématique de la densité de chaque modèle (pas un
  // vrai rendu PDF, juste un indice visuel de mise en page).
  Widget _carteModele(String cle, String libelle) {
    final selectionne = _valeur.modeleBulletin == cle;
    final nombreLignes = switch (cle) {
      'compact' => 3,
      'detaille' => 7,
      _ => 5,
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        onTap: widget.lectureSeule ? null : () => setState(() => _valeur = _valeur.copyWith(modeleBulletin: cle)),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selectionne ? SSMPalette.indigoClair : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(SSMRayons.grand),
            border: Border.all(color: selectionne ? SSMPalette.indigo : const Color(0xFFE5E7EB), width: selectionne ? 1.5 : 1),
          ),
          child: Column(
            children: [
              Container(
                height: 70,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: SSMPalette.blanc, borderRadius: BorderRadius.circular(SSMRayons.petit)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    nombreLignes,
                    (i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1.5),
                      child: Container(height: 3, width: double.infinity, color: (selectionne ? SSMPalette.indigo : SSMPalette.texte3).withValues(alpha: 0.4)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(libelle, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: selectionne ? SSMPalette.indigo : SSMPalette.texte2)),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// Règles de validation des notes
// ══════════════════════════════════════════════════════════
class _SectionValidation extends StatefulWidget {
  final ParametreValidationNote validation;
  final bool lectureSeule;
  final void Function(String, {bool erreur}) onSnack;

  const _SectionValidation({required this.validation, required this.lectureSeule, required this.onSnack});

  @override
  State<_SectionValidation> createState() => _SectionValidationState();
}

class _SectionValidationState extends State<_SectionValidation> {
  late ParametreValidationNote _valeur;
  bool _enregistrementEnCours = false;

  static const _rolesDisponibles = {'directeur': 'Directeur', 'censeur': 'Censeur'};

  @override
  void initState() {
    super.initState();
    _valeur = widget.validation;
  }

  void _basculerRole(String role) {
    final roles = [..._valeur.rolesAutorisesValidation];
    if (roles.contains(role)) {
      if (roles.length == 1) {
        widget.onSnack('Au moins un rôle doit rester autorisé à valider.', erreur: true);
        return;
      }
      roles.remove(role);
    } else {
      roles.add(role);
    }
    setState(() => _valeur = _valeur.copyWith(rolesAutorisesValidation: roles));
  }

  Future<void> _enregistrer() async {
    setState(() => _enregistrementEnCours = true);
    try {
      final misAJour = await ParametreEcoleService.updateParametreValidationNote(_valeur);
      if (!mounted) return;
      setState(() {
        _valeur = misAJour;
        _enregistrementEnCours = false;
      });
      widget.onSnack('Règles de validation enregistrées avec succès');
    } catch (e) {
      if (!mounted) return;
      setState(() => _enregistrementEnCours = false);
      widget.onSnack(e.toString().replaceAll('Exception: ', ''), erreur: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: SSMPalette.indigo,
          value: _valeur.validationObligatoire,
          title: Text('Validation obligatoire', style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte1)),
          subtitle: Text(
            _valeur.validationObligatoire
                ? 'Les notes soumises doivent être validées avant publication.'
                : 'Les notes soumises sont publiées automatiquement.',
            style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2),
          ),
          onChanged: widget.lectureSeule ? null : (v) => setState(() => _valeur = _valeur.copyWith(validationObligatoire: v)),
        ),
        const SizedBox(height: 10),
        Text('RÔLES AUTORISÉS À VALIDER', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: SSMPalette.indigo, letterSpacing: 0.4)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _rolesDisponibles.entries.map((e) {
            final selectionne = _valeur.rolesAutorisesValidation.contains(e.key);
            return FilterChip(
              label: Text(e.value),
              selected: selectionne,
              selectedColor: SSMPalette.indigoClair,
              checkmarkColor: SSMPalette.indigo,
              backgroundColor: const Color(0xFFF9FAFB),
              labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: selectionne ? SSMPalette.indigo : SSMPalette.texte2),
              onSelected: widget.lectureSeule ? null : (_) => _basculerRole(e.key),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: SSMPalette.indigo,
          value: _valeur.modificationApresValidation,
          title: Text('Modification possible après validation', style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte1)),
          onChanged: widget.lectureSeule ? null : (v) => setState(() => _valeur = _valeur.copyWith(modificationApresValidation: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: SSMPalette.indigo,
          value: _valeur.verrouillageAutoCloture,
          title: Text('Verrouillage automatique à la clôture de période', style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte1)),
          onChanged: widget.lectureSeule ? null : (v) => setState(() => _valeur = _valeur.copyWith(verrouillageAutoCloture: v)),
        ),
        const SizedBox(height: 16),
        _boutonEnregistrer(enCours: _enregistrementEnCours, visible: !widget.lectureSeule, onPressed: _enregistrer),
      ],
    );
  }
}
