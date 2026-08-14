import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/utilisateur.dart';
import '../../models/parametre_ecole_model.dart';
import '../../services/auth_service.dart';
import '../../services/parametre_ecole_service.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _rouge = Color(0xFFDC2626);
const Color _vert = Color(0xFF16A34A);
const Color _ambre = Color(0xFFD97706);
const Color _gris = Color(0xFF94A3B8);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);
const Color _fond = Color(0xFFEFF6FF);

const Map<String, String> _modelesBulletin = {
  'standard': 'Standard',
  'compact': 'Compact',
  'detaille': 'Détaillé',
};

// ══════════════════════════════════════════════════════════
// Section Scolarité : 4 onglets (Organisation académique, Notes &
// moyennes, Bulletins, Règles de validation) — 3 ressources API
// indépendantes (parametres/academique, /bulletins, /validation-notes),
// chacune avec son propre bouton "Enregistrer".
// ══════════════════════════════════════════════════════════
class ScolariteScreen extends StatefulWidget {
  final int ongletInitial;
  const ScolariteScreen({super.key, this.ongletInitial = 0});

  @override
  State<ScolariteScreen> createState() => _ScolariteScreenState();
}

class _ScolariteScreenState extends State<ScolariteScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

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
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.ongletInitial);
    _charger();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _snack(String message, {bool erreur = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: erreur ? _rouge : _vert),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fond,
      appBar: AppBar(
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
        title: Text('Scolarité', style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Organisation'),
            Tab(text: 'Notes & moyennes'),
            Tab(text: 'Bulletins'),
            Tab(text: 'Validation'),
          ],
        ),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator(color: _indigo))
          : _erreur != null && _academique == null
              ? _carteErreur(_erreur!, _charger)
              : Column(
                  children: [
                    if (_lectureSeule) Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: _bandeauLectureSeule()),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _OngletOrganisation(academique: _academique!, lectureSeule: _lectureSeule, onSnack: _snack, onRecharge: _charger),
                          _OngletNotesMoyennes(academique: _academique!, lectureSeule: _lectureSeule, onSnack: _snack),
                          _OngletBulletins(bulletin: _bulletin!, lectureSeule: _lectureSeule, onSnack: _snack),
                          _OngletValidation(validation: _validation!, lectureSeule: _lectureSeule, onSnack: _snack),
                        ],
                      ),
                    ),
                  ],
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
            const Icon(Icons.error_outline, color: _rouge, size: 36),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center, style: GoogleFonts.inter(color: _texte)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onReessayer,
              style: ElevatedButton.styleFrom(backgroundColor: _indigo, foregroundColor: Colors.white),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _bandeauLectureSeule() {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: _ambre.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10), border: Border.all(color: _ambre.withValues(alpha: 0.3))),
    child: Row(
      children: [
        const Icon(Icons.lock_outline, color: _ambre, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text('Lecture seule — seul le directeur peut modifier ces paramètres.', style: GoogleFonts.inter(fontSize: 12, color: _texte))),
      ],
    ),
  );
}

Widget _boutonEnregistrer({required bool enCours, required bool visible, required VoidCallback onPressed}) {
  if (!visible) return const SizedBox.shrink();
  return SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: enCours ? null : onPressed,
      child: enCours
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Text('Enregistrer'),
    ),
  );
}

// ══════════════════════════════════════════════════════════
// Onglet 1 — Organisation académique (type de découpage)
// ══════════════════════════════════════════════════════════
class _OngletOrganisation extends StatefulWidget {
  final ParametreAcademique academique;
  final bool lectureSeule;
  final void Function(String, {bool erreur}) onSnack;
  final Future<void> Function() onRecharge;

  const _OngletOrganisation({
    required this.academique,
    required this.lectureSeule,
    required this.onSnack,
    required this.onRecharge,
  });

  @override
  State<_OngletOrganisation> createState() => _OngletOrganisationState();
}

class _OngletOrganisationState extends State<_OngletOrganisation> {
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
        title: const Text('Changer le découpage académique ?'),
        content: Text(
          'Le découpage passera de "${_libelleDecoupage(_typeDecoupage)}" à "${_libelleDecoupage(nouveauType)}" pour '
          "l'année scolaire active.\n\nSi des périodes existent déjà pour cette année, le changement sera bloqué.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _ambre, foregroundColor: Colors.white),
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          "Ce réglage détermine le découpage de l'année scolaire active (trimestres ou semestres). "
          "Il est géré ici pour la commodité, mais reste stocké au niveau de l'année scolaire elle-même.",
          style: GoogleFonts.inter(fontSize: 12, color: _texte),
        ),
        const SizedBox(height: 16),
        _optionDecoupage('trimestres', 'Trimestres', 'Découpage en 3 périodes'),
        const SizedBox(height: 10),
        _optionDecoupage('semestres', 'Semestres', 'Découpage en 2 périodes'),
        if (_enregistrementEnCours) ...[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator(color: _indigo)),
        ],
      ],
    );
  }

  Widget _optionDecoupage(String valeur, String titre, String sousTitre) {
    final selectionne = _typeDecoupage == valeur;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: widget.lectureSeule || _enregistrementEnCours ? null : () => _demanderChangement(valeur),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selectionne ? _indigo.withValues(alpha: 0.08) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selectionne ? _indigo : _gris.withValues(alpha: 0.3), width: selectionne ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Icon(selectionne ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: selectionne ? _indigo : _gris),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titre, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: _texteFonce)),
                    Text(sousTitre, style: GoogleFonts.inter(fontSize: 12, color: _texte)),
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
// Onglet 2 — Notes & moyennes
// ══════════════════════════════════════════════════════════
class _OngletNotesMoyennes extends StatefulWidget {
  final ParametreAcademique academique;
  final bool lectureSeule;
  final void Function(String, {bool erreur}) onSnack;

  const _OngletNotesMoyennes({required this.academique, required this.lectureSeule, required this.onSnack});

  @override
  State<_OngletNotesMoyennes> createState() => _OngletNotesMoyennesState();
}

class _OngletNotesMoyennesState extends State<_OngletNotesMoyennes> {
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _baremeController,
          enabled: !widget.lectureSeule,
          keyboardType: TextInputType.number,
          style: GoogleFonts.jetBrainsMono(fontSize: 14),
          decoration: const InputDecoration(
            labelText: 'Barème maximal des notes',
            prefixIcon: Icon(Icons.grade_outlined),
            helperText: "S'applique uniquement aux futures saisies de notes.",
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Text('COEFFICIENTS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _indigo, letterSpacing: 0.4)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: _indigo,
          value: _coefMatiere,
          title: const Text('Coefficients par matière'),
          onChanged: widget.lectureSeule ? null : (v) => setState(() => _coefMatiere = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: _indigo,
          value: _coefClasse,
          title: const Text('Coefficients par classe'),
          onChanged: widget.lectureSeule ? null : (v) => setState(() => _coefClasse = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: _indigo,
          value: _coefNiveau,
          title: const Text('Coefficients par niveau'),
          onChanged: widget.lectureSeule ? null : (v) => setState(() => _coefNiveau = v),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _modeCalcul,
          decoration: const InputDecoration(labelText: 'Mode de calcul de la moyenne', prefixIcon: Icon(Icons.calculate_outlined), border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 'simple', child: Text('Simple (moyenne devoir + composition)')),
            DropdownMenuItem(value: 'ponderee', child: Text('Pondérée')),
          ],
          onChanged: widget.lectureSeule ? null : (v) => setState(() => _modeCalcul = v ?? _modeCalcul),
        ),
        const SizedBox(height: 20),
        _boutonEnregistrer(enCours: _enregistrementEnCours, visible: !widget.lectureSeule, onPressed: _enregistrer),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
// Onglet 3 — Bulletins
// ══════════════════════════════════════════════════════════
class _OngletBulletins extends StatefulWidget {
  final ParametreBulletin bulletin;
  final bool lectureSeule;
  final void Function(String, {bool erreur}) onSnack;

  const _OngletBulletins({required this.bulletin, required this.lectureSeule, required this.onSnack});

  @override
  State<_OngletBulletins> createState() => _OngletBulletinsState();
}

class _OngletBulletinsState extends State<_OngletBulletins> {
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('MODÈLE', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _indigo, letterSpacing: 0.4)),
        const SizedBox(height: 10),
        Row(
          children: _modelesBulletin.entries
              .map((e) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: _carteModele(e.key, e.value))))
              .toList(),
        ),
        const SizedBox(height: 20),
        Text('ÉLÉMENTS AFFICHÉS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _indigo, letterSpacing: 0.4)),
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
        const SizedBox(height: 20),
        _boutonEnregistrer(enCours: _enregistrementEnCours, visible: !widget.lectureSeule, onPressed: _enregistrer),
      ],
    );
  }

  Widget _switch(String label, bool valeur, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      activeThumbColor: _indigo,
      value: valeur,
      title: Text(label, style: GoogleFonts.inter(fontSize: 13)),
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
        borderRadius: BorderRadius.circular(12),
        onTap: widget.lectureSeule ? null : () => setState(() => _valeur = _valeur.copyWith(modeleBulletin: cle)),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selectionne ? _indigo.withValues(alpha: 0.08) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selectionne ? _indigo : _gris.withValues(alpha: 0.3), width: selectionne ? 1.5 : 1),
          ),
          child: Column(
            children: [
              Container(
                height: 70,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    nombreLignes,
                    (i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1.5),
                      child: Container(height: 3, width: double.infinity, color: (selectionne ? _indigo : _gris).withValues(alpha: 0.4)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(libelle, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: selectionne ? _indigo : _texte)),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// Onglet 4 — Règles de validation des notes
// ══════════════════════════════════════════════════════════
class _OngletValidation extends StatefulWidget {
  final ParametreValidationNote validation;
  final bool lectureSeule;
  final void Function(String, {bool erreur}) onSnack;

  const _OngletValidation({required this.validation, required this.lectureSeule, required this.onSnack});

  @override
  State<_OngletValidation> createState() => _OngletValidationState();
}

class _OngletValidationState extends State<_OngletValidation> {
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: _indigo,
          value: _valeur.validationObligatoire,
          title: const Text('Validation obligatoire'),
          subtitle: Text(
            _valeur.validationObligatoire
                ? 'Les notes soumises doivent être validées avant publication.'
                : 'Les notes soumises sont publiées automatiquement.',
            style: GoogleFonts.inter(fontSize: 12, color: _texte),
          ),
          onChanged: widget.lectureSeule ? null : (v) => setState(() => _valeur = _valeur.copyWith(validationObligatoire: v)),
        ),
        const SizedBox(height: 12),
        Text('RÔLES AUTORISÉS À VALIDER', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _indigo, letterSpacing: 0.4)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _rolesDisponibles.entries.map((e) {
            final selectionne = _valeur.rolesAutorisesValidation.contains(e.key);
            return FilterChip(
              label: Text(e.value),
              selected: selectionne,
              selectedColor: _indigo.withValues(alpha: 0.15),
              checkmarkColor: _indigo,
              labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: selectionne ? _indigo : _texte),
              onSelected: widget.lectureSeule ? null : (_) => _basculerRole(e.key),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: _indigo,
          value: _valeur.modificationApresValidation,
          title: const Text('Modification possible après validation'),
          onChanged: widget.lectureSeule ? null : (v) => setState(() => _valeur = _valeur.copyWith(modificationApresValidation: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: _indigo,
          value: _valeur.verrouillageAutoCloture,
          title: const Text('Verrouillage automatique à la clôture de période'),
          onChanged: widget.lectureSeule ? null : (v) => setState(() => _valeur = _valeur.copyWith(verrouillageAutoCloture: v)),
        ),
        const SizedBox(height: 20),
        _boutonEnregistrer(enCours: _enregistrementEnCours, visible: !widget.lectureSeule, onPressed: _enregistrer),
      ],
    );
  }
}
