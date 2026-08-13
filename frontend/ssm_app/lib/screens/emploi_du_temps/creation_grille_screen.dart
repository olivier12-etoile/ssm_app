import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/emploi_du_temps_model.dart';
import '../../services/emploi_du_temps_service.dart';
import '../../services/annee_service.dart';
import '../../services/classe_service.dart';
import '../../services/classe_matiere_service.dart';
import '../../widgets/grille_emploi_du_temps_widget.dart';
import '../../widgets/seance_form_dialog.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _ambre = Color(0xFFD97706);
const Color _vert = Color(0xFF16A34A);
const Color _rouge = Color(0xFFDC2626);
const Color _gris = Color(0xFF94A3B8);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);

// ══════════════════════════════════════════════════════════
// CreationGrilleScreen — écran principal du module : sélection
// année/période/classe, grille de création des séances, volume horaire
// par matière, validation et duplication.
// ══════════════════════════════════════════════════════════
class CreationGrilleScreen extends StatefulWidget {
  const CreationGrilleScreen({super.key});

  @override
  State<CreationGrilleScreen> createState() => _CreationGrilleScreenState();
}

class _CreationGrilleScreenState extends State<CreationGrilleScreen> {
  List<Map<String, dynamic>> _annees = [];
  List<Map<String, dynamic>> _periodes = [];
  List<Map<String, dynamic>> _classes = [];

  int? _anneeId;
  int? _periodeId;
  int? _classeId;

  List<CreneauHoraire> _creneaux = [];
  List<JourSemaine> _joursActifs = [];
  List<Map<String, dynamic>> _classeMatieres = [];
  EmploiDuTemps? _emploiDuTemps;

  bool _chargementSelecteurs = true;
  bool _chargementAnnee = false;
  bool _chargementGrille = false;
  bool _creationEnCours = false;
  bool _validationEnCours = false;
  String? _erreurSelecteurs;
  String? _erreurGrille;

  @override
  void initState() {
    super.initState();
    _chargerSelecteurs();
  }

  // ══════════════════════════════════════════════════════
  // CHARGEMENT
  // ══════════════════════════════════════════════════════

  Future<void> _chargerSelecteurs() async {
    setState(() {
      _chargementSelecteurs = true;
      _erreurSelecteurs = null;
    });
    try {
      final annees = (await AnneeService.listerAnnees()).map((a) => a as Map<String, dynamic>).toList();
      final anneeActiveData = await AnneeService.anneeActive();
      final anneeActive = anneeActiveData['annee'] as Map<String, dynamic>?;

      setState(() {
        _annees = annees;
        _anneeId = anneeActive?['id'] as int? ?? (annees.isNotEmpty ? annees.first['id'] as int : null);
        _chargementSelecteurs = false;
      });

      if (_anneeId != null) await _chargerAnnee(_anneeId!);
    } catch (e) {
      setState(() {
        _chargementSelecteurs = false;
        _erreurSelecteurs = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  // Recharge tout ce qui dépend de l'année scolaire sélectionnée : les
  // périodes, les classes, ainsi que la grille horaire de référence
  // (créneaux + jours travaillés) sur laquelle repose la création.
  Future<void> _chargerAnnee(int anneeId) async {
    setState(() {
      _chargementAnnee = true;
      _periodeId = null;
      _classeId = null;
      _emploiDuTemps = null;
    });
    try {
      final resultats = await Future.wait([
        AnneeService.listerPeriodes(anneeId),
        ClasseService.lister(anneeId: anneeId),
        EmploiDuTempsService.getCreneauxHoraires(anneeScolaireId: anneeId),
        EmploiDuTempsService.getJoursTravailles(anneeScolaireId: anneeId),
      ]);

      final periodes = (resultats[0] as List).map((p) => p as Map<String, dynamic>).toList();
      final classesParCycle = resultats[1] as Map<String, dynamic>;
      final classes = classesParCycle.values
          .expand((liste) => (liste as List).map((c) => c as Map<String, dynamic>))
          .toList();
      final creneaux = (resultats[2] as List<CreneauHoraire>)..sort((a, b) => a.ordre.compareTo(b.ordre));
      final joursTravailles = resultats[3] as List<JourTravaille>;

      setState(() {
        _periodes = periodes;
        _classes = classes;
        _creneaux = creneaux;
        _joursActifs = JourSemaine.values
            .where((j) => joursTravailles.any((jt) => jt.jour == j && jt.actif))
            .toList();
        _chargementAnnee = false;
      });
    } catch (e) {
      setState(() {
        _chargementAnnee = false;
        _erreurSelecteurs = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _chargerGrille() async {
    if (_classeId == null || _periodeId == null) return;

    setState(() {
      _chargementGrille = true;
      _erreurGrille = null;
    });
    try {
      final resultats = await Future.wait([
        EmploiDuTempsService.consulterParClasse(classeId: _classeId!, periodeId: _periodeId!),
        ClasseMatiereService.listerParClasse(_classeId!),
      ]);

      var emploi = resultats[0] as EmploiDuTemps?;
      // La consultation par classe ne renvoie pas le volume horaire déjà
      // programmé par matière (seul l'endpoint de détail le calcule) : on
      // le recharge pour l'afficher dans le panneau récapitulatif.
      if (emploi?.id != null) {
        emploi = await EmploiDuTempsService.getEmploiDuTemps(emploi!.id!);
      }

      setState(() {
        _emploiDuTemps = emploi;
        _classeMatieres = (resultats[1] as List).map((m) => m as Map<String, dynamic>).toList();
        _chargementGrille = false;
      });
    } catch (e) {
      setState(() {
        _chargementGrille = false;
        _erreurGrille = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  // ══════════════════════════════════════════════════════
  // VOLUME HORAIRE — fusion "attendu" (classe_matiere) x "programmé"
  // ══════════════════════════════════════════════════════

  List<VolumeHoraireMatiere> get _volumesHoraires {
    final programmes = {for (final v in _emploiDuTemps?.volumesHoraires ?? []) v.matiereId: v};

    return _classeMatieres.map((cm) {
      final matiereId = cm['matiere_id'] as int;
      final programme = programmes[matiereId];
      final attendu = (cm['volume_horaire_hebdomadaire'] as num?)?.toDouble();

      return VolumeHoraireMatiere(
        matiereId: matiereId,
        matiere: cm['matiere_nom'] as String? ?? '',
        heuresProgrammees: programme?.heuresProgrammees ?? 0,
      ).avecAttendu(attendu);
    }).toList();
  }

  bool get _grilleVide => _emploiDuTemps == null || _emploiDuTemps!.grille.values.every((m) => m.isEmpty);

  String? get _raisonBlocageValidation {
    if (_emploiDuTemps == null) return 'Créez d\'abord l\'emploi du temps de cette classe.';
    if (_emploiDuTemps!.estValide) return 'Cet emploi du temps est déjà validé.';
    if (_grilleVide) return 'Aucune séance programmée.';

    final incomplets = _volumesHoraires
        .where((v) => v.heuresAttendues != null && v.heuresAttendues! > 0 && !v.estComplet)
        .map((v) => v.matiere)
        .toList();
    if (incomplets.isNotEmpty) {
      return 'Volume horaire incomplet pour : ${incomplets.join(', ')}';
    }
    return null;
  }

  // ══════════════════════════════════════════════════════
  // ACTIONS
  // ══════════════════════════════════════════════════════

  Future<void> _creerEmploiDuTemps() async {
    if (_classeId == null || _periodeId == null) return;
    setState(() => _creationEnCours = true);
    try {
      await EmploiDuTempsService.creerEmploiDuTemps(classeId: _classeId!, periodeId: _periodeId!);
      setState(() => _creationEnCours = false);
      _afficherSucces('Emploi du temps créé — ajoutez des séances dans la grille');
      _chargerGrille();
    } catch (e) {
      setState(() => _creationEnCours = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _onCelluleTap(JourSemaine jour, CreneauHoraire creneau, Seance? seanceExistante) async {
    if (_emploiDuTemps?.id == null) return;
    if (_emploiDuTemps!.estValide) {
      _afficherErreur('Cet emploi du temps est validé et ne peut plus être modifié.');
      return;
    }

    final resultat = await SeanceFormDialog.afficher(
      context,
      classeId: _classeId!,
      emploiDuTempsId: _emploiDuTemps!.id!,
      jour: jour,
      creneau: creneau,
      seanceExistante: seanceExistante,
    );

    if (resultat == true) _chargerGrille();
  }

  Future<void> _onCelluleLongPress(JourSemaine jour, CreneauHoraire creneau, Seance seance) async {
    if (_emploiDuTemps == null || _emploiDuTemps!.estValide || seance.id == null) return;

    final confirme = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Supprimer cette séance ?'),
            content: Text(
              '${seance.nomMatiere ?? 'Cette séance'} — ${jour.libelle} ${creneau.heureDebut} - ${creneau.heureFin}',
              style: GoogleFonts.inter(fontSize: 13),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _rouge, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Supprimer'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirme) return;
    try {
      await EmploiDuTempsService.supprimerSeance(seance.id!);
      _afficherSucces('Séance supprimée');
      _chargerGrille();
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _valider() async {
    if (_emploiDuTemps?.id == null) return;
    setState(() => _validationEnCours = true);
    try {
      await EmploiDuTempsService.validerEmploiDuTemps(_emploiDuTemps!.id!);
      _afficherSucces('Emploi du temps validé avec succès');
      await _chargerGrille();
    } on ConflitEmploiDuTempsException catch (e) {
      _afficherConflits(e.conflits, titre: 'Impossible de valider : des conflits subsistent');
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _validationEnCours = false);
    }
  }

  Future<void> _afficherConflits(List<ConflitDetecte> conflits, {required String titre}) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titre, style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 360,
          child: ListView(
            shrinkWrap: true,
            children: conflits
                .map((c) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline, size: 16, color: _rouge),
                          const SizedBox(width: 8),
                          Expanded(child: Text(c.message, style: GoogleFonts.inter(fontSize: 13))),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
      ),
    );
  }

  Future<void> _ouvrirDupliquerVers() async {
    if (_emploiDuTemps?.id == null) return;

    int? classeDestinationId;
    bool enCours = false;
    final classesDisponibles = _classes.where((c) => c['id'] != _classeId).toList();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
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
                    Text('Dupliquer vers...',
                        style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700, color: _texteFonce)),
                    const SizedBox(height: 8),
                    Text(
                      'Les séances de la classe actuelle seront copiées vers la classe choisie '
                      '(les créneaux en conflit enseignant ne seront pas copiés).',
                      style: GoogleFonts.inter(fontSize: 13, color: _texte),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: classeDestinationId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Classe destination',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: classesDisponibles
                          .map((c) => DropdownMenuItem<int>(value: c['id'] as int, child: Text(c['nom'] as String)))
                          .toList(),
                      onChanged: (id) => setStateDialog(() => classeDestinationId = id),
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
                            onPressed: (classeDestinationId == null || enCours)
                                ? null
                                : () async {
                                    setStateDialog(() => enCours = true);
                                    try {
                                      final resultat = await EmploiDuTempsService.dupliquer(
                                        emploiSourceId: _emploiDuTemps!.id!,
                                        classeDestinationId: classeDestinationId!,
                                      );
                                      if (context.mounted) Navigator.pop(context);
                                      final copiees = (resultat['seances_copiees'] as List?)?.length ?? 0;
                                      final conflits = (resultat['seances_en_conflit'] as List?)?.length ?? 0;
                                      _afficherSucces(conflits > 0
                                          ? '$copiees séance(s) copiée(s), $conflits en conflit à traiter manuellement'
                                          : '$copiees séance(s) copiée(s) avec succès');
                                    } catch (e) {
                                      setStateDialog(() => enCours = false);
                                      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
                                    }
                                  },
                            child: enCours
                                ? const SizedBox(
                                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Dupliquer'),
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
  }

  void _afficherErreur(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: _rouge));
  }

  void _afficherSucces(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: _vert));
  }

  // ══════════════════════════════════════════════════════
  // UI
  // ══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: _chargementSelecteurs
            ? const Center(child: CircularProgressIndicator(color: _indigo))
            : _erreurSelecteurs != null
                ? _vueErreur(_erreurSelecteurs!, _chargerSelecteurs)
                : RefreshIndicator(
                    onRefresh: () async {
                      if (_anneeId != null) await _chargerAnnee(_anneeId!);
                      await _chargerGrille();
                    },
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _barreTitre(),
                        const SizedBox(height: 16),
                        _selecteurs(),
                        const SizedBox(height: 20),
                        if (_classeId == null || _periodeId == null)
                          _messageSelection()
                        else if (_chargementGrille || _chargementAnnee)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 60),
                            child: Center(child: CircularProgressIndicator(color: _indigo)),
                          )
                        else if (_erreurGrille != null)
                          _vueErreur(_erreurGrille!, _chargerGrille)
                        else if (_emploiDuTemps == null)
                          _propositionCreation()
                        else ...[
                          _grille(),
                          _sectionVolumesHoraires(),
                        ],
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _barreTitre() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: _texteFonce),
          onPressed: () => Navigator.canPop(context)
              ? Navigator.pop(context)
              : Navigator.pushReplacementNamed(context, '/tableau-de-bord'),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text("Emploi du temps",
              style: GoogleFonts.sora(fontSize: 22, fontWeight: FontWeight.w700, color: _texteFonce)),
        ),
        if (_emploiDuTemps != null) ...[
          if (!_emploiDuTemps!.estValide)
            OutlinedButton.icon(
              onPressed: _emploiDuTemps!.id == null ? null : _ouvrirDupliquerVers,
              icon: const Icon(Icons.copy_all_outlined, size: 18),
              label: const Text('Dupliquer vers...'),
              style: OutlinedButton.styleFrom(foregroundColor: _indigo, side: const BorderSide(color: _indigo)),
            ),
          const SizedBox(width: 10),
          Tooltip(
            message: _raisonBlocageValidation ?? "Valider définitivement l'emploi du temps",
            child: ElevatedButton.icon(
              onPressed: (_raisonBlocageValidation == null && !_validationEnCours) ? _valider : null,
              icon: _validationEnCours
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(_emploiDuTemps!.estValide ? Icons.verified : Icons.check_circle_outline, size: 18),
              label: Text(_emploiDuTemps!.estValide ? 'Validé' : "Valider l'emploi du temps"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _emploiDuTemps!.estValide ? _vert : _indigo,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _selecteurs() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _dropdownSelecteur<int>(
            label: 'Année scolaire',
            largeur: 200,
            valeur: _anneeId,
            items: _annees.map((a) => DropdownMenuItem(value: a['id'] as int, child: Text(a['libelle'] as String))).toList(),
            onChanged: (id) {
              if (id == null) return;
              setState(() => _anneeId = id);
              _chargerAnnee(id);
            },
          ),
          _dropdownSelecteur<int>(
            label: 'Période',
            largeur: 180,
            valeur: _periodeId,
            items: _periodes.map((p) => DropdownMenuItem(value: p['id'] as int, child: Text(p['nom'] as String))).toList(),
            onChanged: _chargementAnnee
                ? null
                : (id) {
                    setState(() => _periodeId = id);
                    _chargerGrille();
                  },
          ),
          _dropdownSelecteur<int>(
            label: 'Classe',
            largeur: 200,
            valeur: _classeId,
            items: _classes.map((c) => DropdownMenuItem(value: c['id'] as int, child: Text(c['nom'] as String))).toList(),
            onChanged: _chargementAnnee
                ? null
                : (id) {
                    setState(() => _classeId = id);
                    _chargerGrille();
                  },
          ),
        ],
      ),
    );
  }

  Widget _dropdownSelecteur<T>({
    required String label,
    required double largeur,
    required T? valeur,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?)? onChanged,
  }) {
    return SizedBox(
      width: largeur,
      child: DropdownButtonFormField<T>(
        value: valeur,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  Widget _messageSelection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 50),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.filter_alt_outlined, size: 48, color: _gris),
            const SizedBox(height: 12),
            Text('Choisissez une période et une classe pour afficher la grille',
                style: GoogleFonts.inter(fontSize: 14, color: _texte)),
          ],
        ),
      ),
    );
  }

  Widget _propositionCreation() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 50),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.calendar_month_outlined, size: 56, color: _gris),
            const SizedBox(height: 14),
            Text("Aucun emploi du temps pour cette classe sur cette période",
                textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: _texte)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _creationEnCours ? null : _creerEmploiDuTemps,
              icon: _creationEnCours
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.add),
              label: const Text("Créer l'emploi du temps"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _grille() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: GrilleEmploiDuTempsWidget(
        creneaux: _creneaux,
        jours: _joursActifs,
        grille: _emploiDuTemps!.grille,
        modeEdition: !_emploiDuTemps!.estValide,
        onCellTap: _onCelluleTap,
        onCellLongPress: _onCelluleLongPress,
      ),
    );
  }

  Widget _sectionVolumesHoraires() {
    final volumes = _volumesHoraires;
    if (volumes.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Volume horaire par matière', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: _texteFonce)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: volumes.map((v) {
              final attendu = v.heuresAttendues;
              final couleur = (attendu == null || attendu <= 0) ? _gris : (v.estComplet ? _vert : _ambre);
              final texte = (attendu != null && attendu > 0)
                  ? '${v.matiere} ${_formatHeures(v.heuresProgrammees)}/${_formatHeures(attendu)}h'
                  : '${v.matiere} ${_formatHeures(v.heuresProgrammees)}h';

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: couleur.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9999)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: couleur, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(texte, style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w600, color: couleur)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _vueErreur(String message, Future<void> Function() onReessayer) {
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

  String _formatHeures(double h) => h == h.roundToDouble() ? h.toInt().toString() : h.toStringAsFixed(1);
}
