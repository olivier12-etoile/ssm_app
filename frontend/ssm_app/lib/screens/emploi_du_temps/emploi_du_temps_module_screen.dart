import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/utilisateur.dart';
import '../../models/emploi_du_temps_model.dart';
import '../../models/dashboard_emploi_du_temps_model.dart';
import '../../services/auth_service.dart';
import '../../services/annee_service.dart';
import '../../services/emploi_du_temps_service.dart';
import '../../services/dashboard_emploi_du_temps_service.dart';
import '../../widgets/grille_emploi_du_temps_widget.dart';
import 'creation_grille_screen.dart';
import 'parametrage_creneaux_screen.dart';
import 'statistiques_emploi_du_temps_screen.dart';
import 'calendrier_scolaire_screen.dart';
import 'remplacement_screen.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _teal = Color(0xFF0D9488);
const Color _ambre = Color(0xFFD97706);
const Color _vert = Color(0xFF16A34A);
const Color _rouge = Color(0xFFDC2626);
const Color _gris = Color(0xFF94A3B8);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);

// ══════════════════════════════════════════════════════════
// Point d'entrée unique du module Emploi du Temps (même logique que
// notes_module_screen.dart) : la vue diffère radicalement selon le rôle,
// donc pas d'onglets partagés ici — juste un embranchement.
// ══════════════════════════════════════════════════════════
class EmploiDuTempsModuleScreen extends StatefulWidget {
  const EmploiDuTempsModuleScreen({super.key});

  @override
  State<EmploiDuTempsModuleScreen> createState() => _EmploiDuTempsModuleScreenState();
}

class _EmploiDuTempsModuleScreenState extends State<EmploiDuTempsModuleScreen> {
  Utilisateur? _utilisateur;
  bool _chargementUtilisateur = true;

  int? _anneeId;
  int? _periodeId;
  List<Map<String, dynamic>> _periodes = [];

  // Enseignant
  EmploiDuTemps? _monEmploiDuTemps;
  List<CreneauHoraire> _creneaux = [];
  List<JourSemaine> _joursActifs = [];
  bool _chargementGrillePerso = false;
  String? _erreurGrillePerso;

  // Directeur / censeur
  ResumeEmploiDuTemps? _resume;
  List<Map<String, dynamic>> _classes = [];
  bool _chargementGestion = false;
  String? _erreurGestion;

  bool get _estEnseignant => _utilisateur?.estEnseignant == true;
  bool get _estGestionnaire => _utilisateur?.estDirecteur == true || _utilisateur?.estCenseur == true;

  @override
  void initState() {
    super.initState();
    _initialiser();
  }

  Future<void> _initialiser() async {
    final utilisateur = await AuthService.getUtilisateur();
    setState(() {
      _utilisateur = utilisateur;
      _chargementUtilisateur = false;
    });
    await _resoudrePeriode();
  }

  Future<void> _resoudrePeriode() async {
    try {
      // La réponse de /annees/active est enveloppée : {annee, periode_active, ...}.
      final data = await AnneeService.anneeActive();
      final annee = data['annee'] as Map<String, dynamic>?;
      if (annee == null) return;

      final anneeId = annee['id'] as int;
      final periodeActive = data['periode_active'] as Map<String, dynamic>?;
      final periodes = (await AnneeService.listerPeriodes(anneeId)).map((p) => p as Map<String, dynamic>).toList();

      if (!mounted) return;
      setState(() {
        _anneeId = anneeId;
        _periodes = periodes;
        _periodeId = periodeActive?['id'] as int? ?? (periodes.isNotEmpty ? periodes.first['id'] as int : null);
      });

      if (_periodeId != null) _chargerContenu();
    } catch (_) {
      // Le sélecteur de période reste simplement vide si aucune année
      // active n'a pu être résolue.
    }
  }

  Future<void> _chargerContenu() async {
    if (_periodeId == null) return;
    if (_estEnseignant) {
      await _chargerGrillePerso();
    } else if (_estGestionnaire) {
      await _chargerGestion();
    }
  }

  Future<void> _chargerGrillePerso() async {
    setState(() {
      _chargementGrillePerso = true;
      _erreurGrillePerso = null;
    });
    try {
      final resultats = await Future.wait([
        EmploiDuTempsService.getCreneauxHoraires(anneeScolaireId: _anneeId),
        EmploiDuTempsService.getJoursTravailles(anneeScolaireId: _anneeId),
        DashboardEmploiDuTempsService.getMonEmploiDuTemps(_periodeId!),
      ]);

      final creneaux = (resultats[0] as List<CreneauHoraire>)..sort((a, b) => a.ordre.compareTo(b.ordre));
      final jours = resultats[1] as List<JourTravaille>;

      setState(() {
        _creneaux = creneaux;
        _joursActifs = JourSemaine.values.where((j) => jours.any((jt) => jt.jour == j && jt.actif)).toList();
        _monEmploiDuTemps = resultats[2] as EmploiDuTemps;
        _chargementGrillePerso = false;
      });
    } catch (e) {
      setState(() {
        _chargementGrillePerso = false;
        _erreurGrillePerso = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _chargerGestion() async {
    setState(() {
      _chargementGestion = true;
      _erreurGestion = null;
    });
    try {
      final resultats = await Future.wait([
        DashboardEmploiDuTempsService.getResume(_periodeId!),
        DashboardEmploiDuTempsService.getToutesLesClasses(_periodeId!),
      ]);
      setState(() {
        _resume = resultats[0] as ResumeEmploiDuTemps;
        _classes = resultats[1] as List<Map<String, dynamic>>;
        _chargementGestion = false;
      });
    } catch (e) {
      setState(() {
        _chargementGestion = false;
        _erreurGestion = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  // ── Navigation ────────────────────────────────────────

  String get _routeDashboardPrincipal {
    switch (_utilisateur?.role) {
      case 'enseignant':
        return '/dashboard/enseignant';
      case 'censeur':
        return '/dashboard/censeur';
      case 'secretaire':
        return '/dashboard/secretaire';
      default: // directeur, super_admin
        return '/tableau-de-bord';
    }
  }

  void _retour() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, _routeDashboardPrincipal);
    }
  }

  Future<void> _ouvrirDisponibilite() async {
    if (_utilisateur == null || _periodeId == null) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FeuilleDisponibilite(enseignantId: _utilisateur!.id, periodeId: _periodeId!),
    );
  }

  Future<void> _ouvrirClasse(Map<String, dynamic> classe) async {
    final statut = classe['statut'] as String? ?? 'non_cree';
    if (statut == 'valide') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _GrilleClasseLectureSeuleScreen(
            classeId: classe['classe_id'] as int,
            classeNom: classe['classe_nom'] as String,
            periodeId: _periodeId!,
          ),
        ),
      );
    } else {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreationGrilleScreen()));
    }
    _chargerContenu();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _retour),
        title: Text('Emploi du Temps', style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: Colors.white)),
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
      ),
      body: _chargementUtilisateur
          ? const Center(child: CircularProgressIndicator(color: _indigo))
          : _utilisateur == null
              ? _vueMessage('Impossible de charger votre profil. Reconnectez-vous.')
              : SafeArea(child: _corps()),
    );
  }

  Widget _corps() {
    return RefreshIndicator(
      onRefresh: _chargerContenu,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _selecteurPeriode(),
          const SizedBox(height: 16),
          if (_periodeId == null)
            _vueMessage("Aucune période disponible pour l'année scolaire active.")
          else if (_estEnseignant)
            ..._contenuEnseignant()
          else if (_estGestionnaire)
            ..._contenuGestionnaire()
          else
            _vueMessage("Ce module n'est pas disponible pour votre rôle."),
        ],
      ),
    );
  }

  Widget _selecteurPeriode() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: DropdownButtonFormField<int>(
        value: _periodeId,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Période',
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        items: _periodes.map((p) => DropdownMenuItem<int>(value: p['id'] as int, child: Text(p['nom'] as String))).toList(),
        onChanged: (id) {
          if (id == null) return;
          setState(() => _periodeId = id);
          _chargerContenu();
        },
      ),
    );
  }

  Widget _vueMessage(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 50),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.info_outline, color: _gris, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: GoogleFonts.inter(color: _texte)),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // VUE ENSEIGNANT
  // ══════════════════════════════════════════════════════

  List<Widget> _contenuEnseignant() {
    return [
      Row(
        children: [
          Expanded(
            child: Text('Mon emploi du temps', style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: _texteFonce)),
          ),
          OutlinedButton.icon(
            onPressed: _ouvrirDisponibilite,
            icon: const Icon(Icons.event_available_outlined, size: 18),
            label: const Text('Ma disponibilité'),
            style: OutlinedButton.styleFrom(foregroundColor: _indigo, side: const BorderSide(color: _indigo)),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (_chargementGrillePerso)
        const Padding(padding: EdgeInsets.symmetric(vertical: 60), child: Center(child: CircularProgressIndicator(color: _indigo)))
      else if (_erreurGrillePerso != null)
        _carteErreur(_erreurGrillePerso!, _chargerGrillePerso)
      else
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: GrilleEmploiDuTempsWidget(
            creneaux: _creneaux,
            jours: _joursActifs,
            grille: _monEmploiDuTemps?.grille ?? {},
          ),
        ),
    ];
  }

  // ══════════════════════════════════════════════════════
  // VUE DIRECTEUR / CENSEUR
  // ══════════════════════════════════════════════════════

  List<Widget> _contenuGestionnaire() {
    if (_chargementGestion) {
      return [const Padding(padding: EdgeInsets.symmetric(vertical: 60), child: Center(child: CircularProgressIndicator(color: _indigo)))];
    }
    if (_erreurGestion != null) {
      return [_carteErreur(_erreurGestion!, _chargerGestion)];
    }

    return [
      if (_resume != null) _grilleResume(_resume!),
      const SizedBox(height: 20),
      _actionsRapides(),
      const SizedBox(height: 20),
      Text('Toutes les classes', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: _texteFonce)),
      const SizedBox(height: 10),
      if (_classes.isEmpty)
        Text('Aucune classe configurée.', style: GoogleFonts.inter(color: _gris))
      else
        ..._classes.map(_carteClasse),
    ];
  }

  Widget _grilleResume(ResumeEmploiDuTemps resume) {
    final cartes = [
      _CarteResume(label: 'Classes', valeur: '${resume.nombreClasses}', icone: Icons.class_outlined, couleur: _indigo),
      _CarteResume(label: 'Emplois créés', valeur: '${resume.nombreEmplois}', icone: Icons.event_note_outlined, couleur: _teal),
      _CarteResume(label: 'Emplois validés', valeur: '${resume.nombreValides}', icone: Icons.verified_outlined, couleur: _vert),
      _CarteResume(
        label: 'Conflits',
        valeur: '${resume.nombreConflits}',
        icone: Icons.warning_amber_rounded,
        couleur: resume.nombreConflits > 0 ? _rouge : _gris,
      ),
      _CarteResume(label: "Séances aujourd'hui", valeur: '${resume.nombreSeancesAujourdhui}', icone: Icons.today_outlined, couleur: _indigo),
      _CarteResume(
        label: 'Incomplets',
        valeur: '${resume.nombreIncomplets}',
        icone: Icons.hourglass_bottom_outlined,
        couleur: resume.nombreIncomplets > 0 ? _ambre : _gris,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.7,
      children: cartes,
    );
  }

  Widget _actionsRapides() {
    final actions = <_ActionModule>[
      _ActionModule('Paramétrer les créneaux', Icons.schedule_outlined, _indigo,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ParametrageCreneauxScreen()))),
      _ActionModule(
        'Statistiques',
        Icons.bar_chart_outlined,
        _teal,
        _periodeId == null
            ? null
            : () => Navigator.push(context, MaterialPageRoute(builder: (_) => StatistiquesEmploiDuTempsScreen(periodeId: _periodeId!))),
      ),
      _ActionModule(
        'Calendrier scolaire',
        Icons.calendar_month_outlined,
        _ambre,
        _anneeId == null
            ? null
            : () => Navigator.push(context, MaterialPageRoute(builder: (_) => CalendrierScolaireScreen(anneeScolaireId: _anneeId!))),
      ),
      _ActionModule('Gérer les remplacements', Icons.swap_horiz_outlined, _vert,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RemplacementScreen()))),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.6,
      children: actions.map((a) => _carteAction(a)).toList(),
    );
  }

  Widget _carteAction(_ActionModule action) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: action.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: action.couleur.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
                child: Icon(action.icone, color: action.onTap == null ? _gris : action.couleur, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  action.label,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: action.onTap == null ? _gris : _texteFonce),
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _carteClasse(Map<String, dynamic> classe) {
    final statut = classe['statut'] as String? ?? 'non_cree';
    final pourcentage = classe['pourcentage_completion'] as int? ?? 0;
    final couleurStatut = statut == 'valide'
        ? _vert
        : statut == 'brouillon'
            ? _ambre
            : _gris;
    final libelleStatut = statut == 'valide' ? 'Validé' : (statut == 'brouillon' ? 'Brouillon' : 'Non créé');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _ouvrirClasse(classe),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: couleurStatut, width: 4)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(classe['classe_nom'] as String? ?? '',
                        style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: _texteFonce)),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (pourcentage / 100).clamp(0.0, 1.0),
                        minHeight: 5,
                        backgroundColor: const Color(0xFFF1F5F9),
                        color: couleurStatut,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: couleurStatut.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                    child: Text(libelleStatut, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: couleurStatut)),
                  ),
                  const SizedBox(height: 4),
                  Text('$pourcentage%', style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: _texte)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _carteErreur(String message, Future<void> Function() onReessayer) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
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
    );
  }
}

class _ActionModule {
  final String label;
  final IconData icone;
  final Color couleur;
  final VoidCallback? onTap;
  _ActionModule(this.label, this.icone, this.couleur, this.onTap);
}

class _CarteResume extends StatelessWidget {
  final String label;
  final String valeur;
  final IconData icone;
  final Color couleur;

  const _CarteResume({required this.label, required this.valeur, required this.icone, required this.couleur});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: couleur.withValues(alpha: 0.25)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: couleur.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icone, color: couleur, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(valeur, style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700, color: _texteFonce)),
                Text(label, style: GoogleFonts.inter(fontSize: 11, color: _texte), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// Grille d'une classe en lecture seule (statut validé) — vue rapide
// atteinte depuis "Toutes les classes", sans passer par l'écran de
// création (réservé aux emplois en brouillon).
// ══════════════════════════════════════════════════════════
class _GrilleClasseLectureSeuleScreen extends StatefulWidget {
  final int classeId;
  final String classeNom;
  final int periodeId;

  const _GrilleClasseLectureSeuleScreen({required this.classeId, required this.classeNom, required this.periodeId});

  @override
  State<_GrilleClasseLectureSeuleScreen> createState() => _GrilleClasseLectureSeuleScreenState();
}

class _GrilleClasseLectureSeuleScreenState extends State<_GrilleClasseLectureSeuleScreen> {
  EmploiDuTemps? _emploi;
  List<CreneauHoraire> _creneaux = [];
  List<JourSemaine> _jours = [];
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
      final resultats = await Future.wait([
        DashboardEmploiDuTempsService.getEmploiDuTempsClasse(widget.classeId, widget.periodeId),
        EmploiDuTempsService.getCreneauxHoraires(),
        EmploiDuTempsService.getJoursTravailles(),
      ]);
      final creneaux = (resultats[1] as List<CreneauHoraire>)..sort((a, b) => a.ordre.compareTo(b.ordre));
      final jours = resultats[2] as List<JourTravaille>;
      setState(() {
        _emploi = resultats[0] as EmploiDuTemps?;
        _creneaux = creneaux;
        _jours = JourSemaine.values.where((j) => jours.any((jt) => jt.jour == j && jt.actif)).toList();
        _chargement = false;
      });
    } catch (e) {
      setState(() {
        _chargement = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.classeNom, style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: Colors.white)),
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator(color: _indigo))
          : _erreur != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_erreur!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: _rouge)),
                  ),
                )
              : _emploi == null
                  ? Center(
                      child: Text("Aucun emploi du temps pour cette classe.", style: GoogleFonts.inter(color: _texte)),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        child: GrilleEmploiDuTempsWidget(creneaux: _creneaux, jours: _jours, grille: _emploi!.grille),
                      ),
                    ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// Feuille modale : disponibilité (libre/occupé) de l'enseignant connecté,
// jour par jour.
// ══════════════════════════════════════════════════════════
class _FeuilleDisponibilite extends StatefulWidget {
  final int enseignantId;
  final int periodeId;

  const _FeuilleDisponibilite({required this.enseignantId, required this.periodeId});

  @override
  State<_FeuilleDisponibilite> createState() => _FeuilleDisponibiliteState();
}

class _FeuilleDisponibiliteState extends State<_FeuilleDisponibilite> {
  List<DisponibiliteEnseignant> _disponibilite = [];
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final disponibilite = await DashboardEmploiDuTempsService.getDisponibiliteEnseignant(widget.enseignantId, widget.periodeId);
      setState(() {
        _disponibilite = disponibilite;
        _chargement = false;
      });
    } catch (e) {
      setState(() {
        _chargement = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final parJour = <JourSemaine, List<DisponibiliteEnseignant>>{};
    for (final d in _disponibilite) {
      parJour.putIfAbsent(JourSemaine.depuisApi(d.jour), () => []).add(d);
    }
    final jours = JourSemaine.values.where(parJour.containsKey).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(color: Color(0xFFF8FAFC), borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('Ma disponibilité', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: _texteFonce)),
            ),
            Expanded(
              child: _chargement
                  ? const Center(child: CircularProgressIndicator(color: _indigo))
                  : _erreur != null
                      ? Center(child: Text(_erreur!, style: GoogleFonts.inter(color: _rouge)))
                      : ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          children: jours.map((jour) => _sectionJour(jour, parJour[jour]!)).toList(),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionJour(JourSemaine jour, List<DisponibiliteEnseignant> creneaux) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(jour.libelle, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _texteFonce)),
          const SizedBox(height: 6),
          ...creneaux.map((c) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(c.libelleCreneau, style: GoogleFonts.jetBrainsMono(fontSize: 12, color: _texteFonce)),
                    ),
                    if (!c.estLibre && c.classeOccupee != null) ...[
                      Text('${c.classeOccupee} · ${c.matiereOccupee ?? ''}',
                          style: GoogleFonts.inter(fontSize: 11, color: _texte)),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (c.estLibre ? _vert : _rouge).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        c.estLibre ? 'Libre' : 'Occupé',
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: c.estLibre ? _vert : _rouge),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
