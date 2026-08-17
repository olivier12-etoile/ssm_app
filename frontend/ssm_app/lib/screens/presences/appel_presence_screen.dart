import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/emploi_du_temps_model.dart';
import '../../models/presence_model.dart';
import '../../services/annee_service.dart';
import '../../services/classe_service.dart';
import '../../services/emploi_du_temps_service.dart';
import '../../services/presence_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_avatar.dart';
import '../../widgets/ssm/ssm_panel.dart';

InputDecoration _decorationChamp(String label, {IconData? icone}) {
  return InputDecoration(
    labelText: label,
    labelStyle: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2),
    prefixIcon: icone != null ? Icon(icone, color: SSMPalette.texte3) : null,
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

// ══════════════════════════════════════════════════════════
// AppelPresenceScreen — écran d'appel rapide pour une classe.
//
// Deux modes :
// - Nouvel appel (appelIdExistant == null) : formulaire de config
//   (matière/date/créneau) puis liste d'élèves tous "présents" par
//   défaut, l'enseignant ne signale que les absents/retards.
// - Consultation (appelIdExistant fourni, ex: depuis "Appels
//   récents") : charge l'appel existant ; si déjà terminé, la liste
//   passe en lecture seule (aucun tap possible sur les statuts).
// ══════════════════════════════════════════════════════════
class AppelPresenceScreen extends StatefulWidget {
  final int classeId;
  final String classeNom;
  final int? appelIdExistant;

  const AppelPresenceScreen({
    super.key,
    required this.classeId,
    required this.classeNom,
    this.appelIdExistant,
  });

  @override
  State<AppelPresenceScreen> createState() => _AppelPresenceScreenState();
}

class _AppelPresenceScreenState extends State<AppelPresenceScreen> {
  bool _chargementInitial = true;
  bool _demarrageEnCours = false;
  bool _finalisationEnCours = false;
  String? _erreurChargement;

  List<dynamic> _matieresClasse = [];
  List<CreneauHoraire> _creneaux = [];
  List<dynamic> _periodes = [];

  int? _matiereSelectionneeId;
  int? _creneauSelectionneId;
  int? _periodeSelectionneeId;
  DateTime _dateSelectionnee = DateTime.now();

  AppelPresence? _appel;
  List<Presence> _presences = [];
  int? _eleveEnEdition;

  final TextEditingController _motifController = TextEditingController();
  final TextEditingController _minutesController = TextEditingController();

  bool get _lectureSeule => _appel?.estTermine ?? false;

  @override
  void initState() {
    super.initState();
    _initialiser();
  }

  @override
  void dispose() {
    _motifController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  Future<void> _initialiser() async {
    setState(() {
      _chargementInitial = true;
      _erreurChargement = null;
    });
    try {
      if (widget.appelIdExistant != null) {
        final appel = await PresenceService.getAppel(widget.appelIdExistant!);
        setState(() {
          _appel = appel;
          _presences = List.of(appel.presences);
        });
      } else {
        final details = await ClasseService.details(widget.classeId);
        final classe = details['classe'] as Map<String, dynamic>;
        final anneeId = classe['annee_academique_id'] as int?;
        final matieres = (details['matieres'] as List?) ?? [];

        List<dynamic> periodes = [];
        List<CreneauHoraire> creneaux = [];
        if (anneeId != null) {
          final resultats = await Future.wait([
            AnneeService.listerPeriodes(anneeId),
            EmploiDuTempsService.getCreneauxHoraires(anneeScolaireId: anneeId),
          ]);
          periodes = resultats[0];
          creneaux = resultats[1] as List<CreneauHoraire>;
        }

        setState(() {
          _matieresClasse = matieres;
          _periodes = periodes;
          _creneaux = creneaux;
          _periodeSelectionneeId = periodes.isNotEmpty
              ? (periodes.firstWhere(
                  (p) => p['statut'] == 'ouverte',
                  orElse: () => periodes.first,
                )['id'] as int)
              : null;
        });
      }
    } catch (e) {
      setState(() => _erreurChargement = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _chargementInitial = false);
    }
  }

  String _formatDateIso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatDateAffichee(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  void _afficherErreur(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: SSMPalette.rouge));
  }

  Future<void> _choisirDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dateSelectionnee,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (d != null) setState(() => _dateSelectionnee = d);
  }

  Future<void> _demarrerAppel() async {
    if (_periodeSelectionneeId == null) {
      _afficherErreur('Aucune période disponible pour cette classe.');
      return;
    }
    setState(() => _demarrageEnCours = true);
    try {
      final appel = await PresenceService.creerAppel(
        classeId: widget.classeId,
        matiereId: _matiereSelectionneeId,
        periodeId: _periodeSelectionneeId!,
        dateAppel: _formatDateIso(_dateSelectionnee),
        creneauHoraireId: _creneauSelectionneId,
      );
      setState(() {
        _appel = appel;
        _presences = List.of(appel.presences);
      });
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _demarrageEnCours = false);
    }
  }

  Future<void> _envoyerMarquage(Presence p) async {
    try {
      await PresenceService.marquerPresence(
        appelId: _appel!.id,
        eleveId: p.eleveId!,
        statut: p.statut,
        justifie: p.justifie,
        motif: p.motifJustification,
        minutesRetard: p.minutesRetard,
      );
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _remplacerLocal(Presence maj) {
    setState(() {
      _presences = _presences.map((p) => p.eleveId == maj.eleveId ? maj : p).toList();
    });
  }

  void _tapStatut(Presence actuelle, StatutPresence statut) {
    if (_lectureSeule || actuelle.eleveId == null) return;

    if (statut == StatutPresence.present) {
      final maj = actuelle.copyWith(
        statut: StatutPresence.present,
        justifie: false,
        motifJustification: null,
        minutesRetard: null,
      );
      _remplacerLocal(maj);
      if (_eleveEnEdition == actuelle.eleveId) setState(() => _eleveEnEdition = null);
      _envoyerMarquage(maj);
      return;
    }

    final maj = actuelle.copyWith(
      statut: statut,
      justifie: statut == StatutPresence.absent ? actuelle.justifie : false,
    );
    _remplacerLocal(maj);
    setState(() {
      _eleveEnEdition = actuelle.eleveId;
      _motifController.text = maj.motifJustification ?? '';
      _minutesController.text = maj.minutesRetard?.toString() ?? '';
    });
    _envoyerMarquage(maj);
  }

  Future<void> _confirmerTerminerAppel() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terminer l\'appel ?'),
        content: const Text(
          'Les parents des élèves absents (et en retard, si activé) seront notifiés par WhatsApp. '
          'Cette action est définitive.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.indigo, foregroundColor: Colors.white),
            child: const Text('Terminer'),
          ),
        ],
      ),
    );
    if (confirme != true || _appel == null) return;

    final notifieAvant = <int, bool>{
      for (final p in _presences)
        if (p.eleveId != null) p.eleveId!: p.notifieParent,
    };

    setState(() => _finalisationEnCours = true);
    try {
      final appel = await PresenceService.terminerAppel(_appel!.id);
      final nombreNotifies = appel.presences
          .where((p) => p.eleveId != null && (notifieAvant[p.eleveId] ?? false) == false && p.notifieParent)
          .length;

      setState(() {
        _appel = appel;
        _presences = List.of(appel.presences);
        _eleveEnEdition = null;
      });

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Appel terminé'),
          content: Text(
            nombreNotifies > 0
                ? 'Notifications envoyées à $nombreNotifies parent(s).'
                : 'Appel enregistré. Aucune notification à envoyer.',
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _finalisationEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SSMPalette.fond,
      appBar: AppBar(
        backgroundColor: SSMPalette.blanc,
        foregroundColor: SSMPalette.texte2,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: SSMPalette.texte2),
        title: Text(
          widget.classeNom,
          style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
        ),
        actions: [
          if (_lectureSeule)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: SSMPalette.indigoClair, borderRadius: BorderRadius.circular(SSMRayons.pilule)),
                  child: Text('Terminé', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: SSMPalette.indigo)),
                ),
              ),
            ),
        ],
      ),
      body: _chargementInitial
          ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
          : _erreurChargement != null && _appel == null
              ? _vueErreur()
              : _appel == null
                  ? ListView(padding: const EdgeInsets.all(16), children: [_panelConfiguration()])
                  : _vueAppel(),
      bottomNavigationBar: (_appel != null && !_lectureSeule)
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _finalisationEnCours ? null : _confirmerTerminerAppel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SSMPalette.indigo,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
                      disabledBackgroundColor: SSMPalette.indigo.withValues(alpha: 0.4),
                    ),
                    icon: _finalisationEnCours
                        ? const SizedBox(
                            width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.flag_outlined),
                    label: Text(_finalisationEnCours ? 'Finalisation...' : "Terminer l'appel", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _vueErreur() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: SSMPalette.rouge, size: 40),
            const SizedBox(height: 12),
            Text(_erreurChargement!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: SSMPalette.texte2)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _initialiser, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }

  Widget _panelConfiguration() {
    return SSMPanel(
      titre: "Nouvel appel — ${widget.classeNom}",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_periodes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Aucune période académique disponible pour cette classe.',
                style: GoogleFonts.inter(fontSize: 12.5, color: SSMPalette.rouge),
              ),
            )
          else if (_periodes.length > 1) ...[
            DropdownButtonFormField<int>(
              initialValue: _periodeSelectionneeId,
              decoration: _decorationChamp('Période'),
              items: _periodes
                  .cast<Map<String, dynamic>>()
                  .map((p) => DropdownMenuItem(value: p['id'] as int, child: Text(p['nom'] as String)))
                  .toList(),
              onChanged: (v) => setState(() => _periodeSelectionneeId = v),
            ),
            const SizedBox(height: 12),
          ],
          DropdownButtonFormField<int?>(
            initialValue: _matiereSelectionneeId,
            decoration: _decorationChamp('Matière (optionnel)'),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('Appel général (sans matière)')),
              ..._matieresClasse.map(
                (m) => DropdownMenuItem<int?>(
                  value: m['matiere_id'] as int,
                  child: Text(m['matiere_nom'] as String),
                ),
              ),
            ],
            onChanged: (v) => setState(() => _matiereSelectionneeId = v),
          ),
          const SizedBox(height: 12),
          if (_creneaux.isNotEmpty) ...[
            DropdownButtonFormField<int?>(
              initialValue: _creneauSelectionneId,
              decoration: _decorationChamp('Créneau horaire (optionnel)'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Aucun créneau précis')),
                ..._creneaux.map(
                  (c) => DropdownMenuItem<int?>(
                    value: c.id,
                    child: Text('${c.libelle} (${c.heureDebut} - ${c.heureFin})'),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _creneauSelectionneId = v),
            ),
            const SizedBox(height: 12),
          ],
          InkWell(
            onTap: _choisirDate,
            borderRadius: BorderRadius.circular(SSMRayons.moyen),
            child: InputDecorator(
              decoration: _decorationChamp("Date de l'appel", icone: Icons.calendar_today),
              child: Text(_formatDateAffichee(_dateSelectionnee), style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte1)),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_demarrageEnCours || _periodes.isEmpty) ? null : _demarrerAppel,
              style: ElevatedButton.styleFrom(
                backgroundColor: SSMPalette.teal,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
              ),
              icon: _demarrageEnCours
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.play_circle_outline),
              label: Text(_demarrageEnCours ? 'Démarrage...' : "Démarrer l'appel", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vueAppel() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text(
          _appel!.nomMatiere != null
              ? '${_appel!.nomMatiere} · ${_formatDateAffichee(_appel!.dateAppel)}'
              : 'Appel général · ${_formatDateAffichee(_appel!.dateAppel)}',
          style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
        ),
        const SizedBox(height: 12),
        _compteur(),
        const SizedBox(height: 14),
        if (!_lectureSeule)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Touchez Absent ou Retard pour signaler un élève — tous les autres restent présents.',
              style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte3),
            ),
          ),
        ..._presences.map(_ligneEleve),
      ],
    );
  }

  Widget _compteur() {
    final presents = _presences.where((p) => p.statut == StatutPresence.present).length;
    final absents = _presences.where((p) => p.statut == StatutPresence.absent).length;
    final retards = _presences.where((p) => p.statut == StatutPresence.retard).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: SSMPalette.blanc,
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        border: Border.all(color: SSMPalette.bordure),
      ),
      child: Row(
        children: [
          Expanded(child: _statutMini('$presents', 'présents', SSMPalette.teal)),
          Container(width: 1, height: 30, color: SSMPalette.bordure),
          Expanded(child: _statutMini('$absents', 'absents', SSMPalette.rouge)),
          Container(width: 1, height: 30, color: SSMPalette.bordure),
          Expanded(child: _statutMini('$retards', 'retards', SSMPalette.ambre)),
        ],
      ),
    );
  }

  Widget _statutMini(String valeur, String label, Color couleur) {
    return Column(
      children: [
        Text(valeur, style: GoogleFonts.sora(fontSize: 21, fontWeight: FontWeight.w700, color: couleur)),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte2)),
      ],
    );
  }

  Widget _ligneEleve(Presence p) {
    final enEdition = _eleveEnEdition == p.eleveId;
    final couleurBordure = p.statut == StatutPresence.present ? SSMPalette.bordure : p.statut.couleur.withValues(alpha: 0.45);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: SSMPalette.blanc,
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        border: Border.all(color: couleurBordure),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SSMAvatar(nom: p.nomEleve ?? '?', rayon: 15),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  p.nomEleve ?? 'Élève',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: SSMPalette.texte1),
                ),
              ),
              const SizedBox(width: 6),
              _chipStatut(p, StatutPresence.present, Icons.check_circle_outline),
              const SizedBox(width: 6),
              _chipStatut(p, StatutPresence.absent, Icons.cancel_outlined),
              const SizedBox(width: 6),
              _chipStatut(p, StatutPresence.retard, Icons.schedule_outlined),
            ],
          ),
          if (enEdition && !_lectureSeule) _formulaireInline(p),
          if (_lectureSeule && p.statut != StatutPresence.present)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 42),
              child: Text(
                p.statut == StatutPresence.absent
                    ? (p.justifie
                        ? 'Absence justifiée${p.motifJustification != null && p.motifJustification!.isNotEmpty ? ' — ${p.motifJustification}' : ''}'
                        : 'Absence non justifiée')
                    : '${p.minutesRetard ?? '?'} min de retard',
                style: GoogleFonts.inter(fontSize: 11.5, color: SSMPalette.texte3),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chipStatut(Presence p, StatutPresence statut, IconData icone) {
    final actif = p.statut == statut;
    return InkWell(
      onTap: _lectureSeule ? null : () => _tapStatut(p, statut),
      borderRadius: BorderRadius.circular(SSMRayons.pilule),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: actif ? statut.couleur.withValues(alpha: 0.12) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(SSMRayons.pilule),
          border: Border.all(color: actif ? statut.couleur.withValues(alpha: 0.4) : const Color(0xFFF3F4F6)),
        ),
        child: Icon(icone, size: 16, color: actif ? statut.couleur : SSMPalette.texte3),
      ),
    );
  }

  Widget _formulaireInline(Presence p) {
    if (p.statut == StatutPresence.absent) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, left: 42),
        child: Row(
          children: [
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: p.justifie,
                activeThumbColor: SSMPalette.teal,
                onChanged: (v) {
                  final maj = p.copyWith(justifie: v);
                  _remplacerLocal(maj);
                  _envoyerMarquage(maj);
                },
              ),
            ),
            Text('Justifiée', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _motifController,
                style: GoogleFonts.inter(fontSize: 12),
                decoration: _decorationChamp('Motif (optionnel)').copyWith(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                onSubmitted: (v) {
                  final maj = p.copyWith(motifJustification: v.isEmpty ? null : v);
                  _remplacerLocal(maj);
                  _envoyerMarquage(maj);
                },
              ),
            ),
          ],
        ),
      );
    }

    if (p.statut == StatutPresence.retard) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, left: 42),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: TextField(
                controller: _minutesController,
                keyboardType: TextInputType.number,
                style: GoogleFonts.inter(fontSize: 12),
                decoration: _decorationChamp('Minutes').copyWith(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                onSubmitted: (v) {
                  final maj = p.copyWith(minutesRetard: int.tryParse(v));
                  _remplacerLocal(maj);
                  _envoyerMarquage(maj);
                },
              ),
            ),
            const SizedBox(width: 8),
            Text('de retard', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
