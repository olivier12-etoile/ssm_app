import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/bulletin_model.dart';
import '../../services/annee_service.dart';
import '../../services/classe_service.dart';
import '../../services/eleve_service.dart';
import '../../services/bulletin_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_alert_item.dart';
import '../../widgets/ssm/ssm_panel.dart';
import '../../widgets/ssm/ssm_pill.dart';
import '../../widgets/ssm/ssm_quick_action_button.dart';
import '../../widgets/ssm/ssm_sous_entete.dart';
import 'liste_bulletins_classe_screen.dart';

// ══════════════════════════════════════════════════════════
// Génération d'un lot de bulletins (classe entière) ou d'un bulletin
// individuel. `classeIdInitiale` permet d'arriver directement depuis une
// classe tapée sur BulletinsModuleScreen ; la classe et la période restent
// modifiables ici dans tous les cas.
// ══════════════════════════════════════════════════════════
class GenerationBulletinScreen extends StatefulWidget {
  final int anneeScolaireId;
  final int periodeId;
  final int? classeIdInitiale;

  const GenerationBulletinScreen({
    super.key,
    required this.anneeScolaireId,
    required this.periodeId,
    this.classeIdInitiale,
  });

  @override
  State<GenerationBulletinScreen> createState() => _GenerationBulletinScreenState();
}

class _GenerationBulletinScreenState extends State<GenerationBulletinScreen> {
  List<dynamic> _classes = [];
  List<dynamic> _periodes = [];
  int? _classeId;
  int? _periodeId;
  bool _chargementListes = true;

  List<StatutGenerationEleve>? _statuts;
  bool _verificationEnCours = false;

  bool _generationEnCours = false;
  ResumeGenerationClasse? _resume;

  // ── Génération individuelle (recherche élève) ────────────
  final _rechercheController = TextEditingController();
  List<dynamic> _resultatsRecherche = [];
  bool _rechercheEnCours = false;
  int? _eleveEnCoursDeGeneration;

  @override
  void initState() {
    super.initState();
    _classeId = widget.classeIdInitiale;
    _periodeId = widget.periodeId;
    _chargerListes();
  }

  @override
  void dispose() {
    _rechercheController.dispose();
    super.dispose();
  }

  Future<void> _chargerListes() async {
    try {
      final resultats = await Future.wait([
        ClasseService.lister(anneeId: widget.anneeScolaireId),
        AnneeService.listerPeriodes(widget.anneeScolaireId),
      ]);
      if (!mounted) return;
      setState(() {
        _classes = _aplatirClasses(resultats[0]);
        _periodes = resultats[1] as List<dynamic>;
        _chargementListes = false;
      });
      if (_classeId != null && _periodeId != null) _verifier();
    } catch (e) {
      if (!mounted) return;
      setState(() => _chargementListes = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  List<dynamic> _aplatirClasses(dynamic valeur) {
    final toutes = <dynamic>[];
    void parcourir(dynamic v) {
      if (v is List) {
        toutes.addAll(v);
      } else if (v is Map) {
        for (final sous in v.values) {
          parcourir(sous);
        }
      }
    }

    parcourir(valeur);
    return toutes;
  }

  void _changerClasse(int? classeId) {
    setState(() {
      _classeId = classeId;
      _statuts = null;
      _resume = null;
    });
  }

  void _changerPeriode(int? periodeId) {
    setState(() {
      _periodeId = periodeId;
      _statuts = null;
      _resume = null;
    });
  }

  // ── Vérification avant génération ────────────────────────

  Future<void> _verifier() async {
    if (_classeId == null || _periodeId == null) {
      _afficherErreur('Sélectionnez une classe et une période.');
      return;
    }
    setState(() {
      _verificationEnCours = true;
      _statuts = null;
      _resume = null;
    });
    try {
      final statuts = await BulletinService.getStatutGeneration(classeId: _classeId!, periodeId: _periodeId!);
      if (!mounted) return;
      setState(() {
        _statuts = statuts;
        _verificationEnCours = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _verificationEnCours = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  List<StatutGenerationEleve> get _elevesBloques =>
      (_statuts ?? []).where((s) => !s.genere && s.raisonBlocage != null).toList();

  List<StatutGenerationEleve> get _elevesPrets =>
      (_statuts ?? []).where((s) => !s.genere && s.raisonBlocage == null).toList();

  List<StatutGenerationEleve> get _elevesDejaGeneres => (_statuts ?? []).where((s) => s.genere).toList();

  // ── Génération de la classe ───────────────────────────────
  // Le backend (GenerationBulletinService::genererPourClasse) traite déjà
  // chaque élève indépendamment et renvoie réussis/échoués séparément :
  // qu'on parte du bouton principal ou de "Générer quand même pour les
  // élèves prêts", l'appel est donc rigoureusement le même — seule la
  // confirmation affichée change, pour être honnête sur ce qui va se
  // passer pour les élèves bloqués (ils resteront en échec, avec leur raison).
  Future<void> _genererClasse({required bool malgreBlocages}) async {
    final confirme = await _confirmerGeneration(malgreBlocages: malgreBlocages);
    if (confirme != true) return;

    setState(() {
      _generationEnCours = true;
      _resume = null;
    });

    try {
      final resume = await BulletinService.genererClasse(classeId: _classeId!, periodeId: _periodeId!);
      if (!mounted) return;
      setState(() {
        _resume = resume;
        _generationEnCours = false;
      });
      _verifier();
    } catch (e) {
      if (!mounted) return;
      setState(() => _generationEnCours = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<bool?> _confirmerGeneration({required bool malgreBlocages}) {
    final total = (_statuts ?? []).length;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SSMPalette.blanc,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
        title: Text('Générer les bulletins ?', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
        content: Text(
          malgreBlocages
              ? '${_elevesPrets.length} élève(s) prêt(s) sur $total seront générés. '
                  '${_elevesBloques.length} élève(s) resteront bloqué(s) (voir raisons ci-dessous).'
              : 'Les bulletins seront générés pour les $total élève(s) de la classe.',
          style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Annuler', style: GoogleFonts.inter(color: SSMPalette.texte2))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Générer'),
          ),
        ],
      ),
    );
  }

  // ── Génération individuelle ───────────────────────────────

  Future<void> _rechercherEleves() async {
    final terme = _rechercheController.text.trim();
    if (terme.isEmpty) {
      setState(() => _resultatsRecherche = []);
      return;
    }
    setState(() => _rechercheEnCours = true);
    try {
      final data = await EleveService.lister(recherche: terme, page: 1);
      if (!mounted) return;
      setState(() {
        _resultatsRecherche = data['data'] as List? ?? [];
        _rechercheEnCours = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _rechercheEnCours = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _genererIndividuel(int eleveId) async {
    if (_periodeId == null) {
      _afficherErreur('Sélectionnez une période.');
      return;
    }
    setState(() => _eleveEnCoursDeGeneration = eleveId);
    try {
      await BulletinService.genererIndividuel(eleveId: eleveId, periodeId: _periodeId!);
      _afficherSucces('Bulletin généré avec succès');
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _eleveEnCoursDeGeneration = null);
    }
  }

  void _voirBulletinsGeneres() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ListeBulletinsClasseScreen(classeId: _classeId!, periodeId: _periodeId!),
      ),
    );
  }

  void _afficherErreur(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: SSMPalette.rouge));
  }

  void _afficherSucces(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: SSMPalette.teal));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SSMPalette.fond,
      body: SafeArea(
        child: Column(
          children: [
            SSMSousEnTete(titre: 'Génération de bulletins', onRetour: () => Navigator.pop(context)),
            Expanded(
              child: _chargementListes
                  ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      children: [
                        _carteSelecteurs(),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: SSMQuickActionButton(
                            icone: Icons.fact_check_outlined,
                            label: 'Vérifier avant génération',
                            variante: SSMActionVariante.primaire,
                            onTap: (_classeId == null || _periodeId == null || _verificationEnCours) ? null : _verifier,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_verificationEnCours) const Center(child: CircularProgressIndicator(color: SSMPalette.indigo)),
                        if (_statuts != null) ..._blocVerification(),
                        if (_generationEnCours) _blocGenerationEnCours(),
                        if (_resume != null) ..._blocResume(),
                        const SizedBox(height: 28),
                        const Divider(),
                        const SizedBox(height: 12),
                        Text('Génération individuelle', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.texte1)),
                        const SizedBox(height: 4),
                        Text('Recherchez un élève par nom, prénom ou matricule.', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
                        const SizedBox(height: 12),
                        _blocRechercheIndividuelle(),
                        const SizedBox(height: 24),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sélecteurs ────────────────────────────────────────────

  Widget _carteSelecteurs() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SSMPalette.blanc,
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        border: Border.all(color: SSMPalette.bordure),
      ),
      child: Column(
        children: [
          DropdownButtonFormField<int>(
            value: _classeId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Classe', prefixIcon: Icon(Icons.class_outlined), isDense: true),
            hint: const Text('Choisir une classe'),
            items: _classes.map((c) => DropdownMenuItem<int>(value: c['id'] as int, child: Text(c['nom'] as String))).toList(),
            onChanged: _changerClasse,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _periodeId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Période', prefixIcon: Icon(Icons.segment), isDense: true),
            hint: const Text('Choisir une période'),
            items: _periodes.map((p) => DropdownMenuItem<int>(value: p['id'] as int, child: Text(p['nom'] as String))).toList(),
            onChanged: _changerPeriode,
          ),
        ],
      ),
    );
  }

  // ── Résultat de la vérification ────────────────────────────

  List<Widget> _blocVerification() {
    final statuts = _statuts!;
    final bloques = _elevesBloques;
    final prets = _elevesPrets;
    final dejaGeneres = _elevesDejaGeneres;

    return [
      SSMAlertItem(
        type: bloques.isEmpty ? SSMAlerteType.succes : SSMAlerteType.avertissement,
        icone: bloques.isEmpty ? Icons.check_circle_outline : Icons.warning_amber_outlined,
        titre: bloques.isEmpty ? 'Tous les élèves sont prêts' : '${bloques.length} élève(s) bloqué(s)',
        sousTitre: bloques.isEmpty
            ? '${statuts.length} élève(s) — ${dejaGeneres.length} déjà généré(s).'
            : '${bloques.length} bloqué(s) sur ${statuts.length}, ${prets.length} prêt(s), ${dejaGeneres.length} déjà généré(s).',
      ),
      const SizedBox(height: 10),
      ...bloques.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: SSMAlertItem(
              type: SSMAlerteType.danger,
              icone: Icons.cancel_outlined,
              titre: s.nom,
              sousTitre: s.raisonBlocage ?? 'Blocage inconnu',
            ),
          )),
      ...[...prets, ...dejaGeneres].map(_ligneStatutPret),
      const SizedBox(height: 12),
      if (bloques.isEmpty)
        SizedBox(
          width: double.infinity,
          child: SSMQuickActionButton(
            icone: Icons.auto_awesome,
            label: 'Générer les bulletins de la classe',
            variante: SSMActionVariante.primaire,
            onTap: prets.isEmpty ? null : () => _genererClasse(malgreBlocages: false),
          ),
        )
      else ...[
        SizedBox(
          width: double.infinity,
          child: SSMQuickActionButton(
            icone: Icons.block,
            label: 'Génération complète impossible — élèves bloqués',
            variante: SSMActionVariante.gris,
          ),
        ),
        const SizedBox(height: 8),
        if (prets.isNotEmpty)
          SizedBox(
            width: double.infinity,
            child: SSMQuickActionButton(
              icone: Icons.playlist_add_check,
              label: 'Générer quand même pour les ${prets.length} élève(s) prêt(s)',
              variante: SSMActionVariante.ambre,
              onTap: () => _genererClasse(malgreBlocages: true),
            ),
          ),
      ],
    ];
  }

  Widget _ligneStatutPret(StatutGenerationEleve s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: SSMPalette.blanc,
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        border: Border.all(color: SSMPalette.bordure),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(s.nom, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
          ),
          SSMPill.couleur(
            label: s.genere ? 'Déjà généré' : 'Prêt',
            couleur: s.genere ? SSMPalette.indigo : SSMPalette.teal,
          ),
        ],
      ),
    );
  }

  Widget _blocGenerationEnCours() {
    final total = (_statuts ?? []).length;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          const CircularProgressIndicator(color: SSMPalette.indigo),
          const SizedBox(height: 12),
          Text(
            total > 0 ? 'Génération en cours pour $total élève(s)...' : 'Génération en cours...',
            style: GoogleFonts.inter(color: SSMPalette.texte2),
          ),
        ],
      ),
    );
  }

  // ── Résumé après génération ─────────────────────────────────

  List<Widget> _blocResume() {
    final r = _resume!;
    return [
      const SizedBox(height: 8),
      SSMPanel(
        titre: 'Résultat de la génération',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: SSMPalette.teal, size: 16),
                const SizedBox(width: 6),
                Text('${r.nombreReussis} réussi(s)', style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte1)),
                const SizedBox(width: 16),
                const Icon(Icons.cancel, color: SSMPalette.rouge, size: 16),
                const SizedBox(width: 6),
                Text('${r.nombreEchecs} échec(s)', style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte1)),
              ],
            ),
            if (r.echecs.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...r.echecs.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• ${e.nom} : ${e.raison ?? '—'}', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.rouge)),
                  )),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SSMQuickActionButton(
                icone: Icons.list_alt,
                label: 'Voir les bulletins générés',
                variante: SSMActionVariante.teal,
                onTap: _voirBulletinsGeneres,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  // ── Génération individuelle ─────────────────────────────────

  Widget _blocRechercheIndividuelle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _rechercheController,
                decoration: const InputDecoration(
                  hintText: 'Nom, prénom ou matricule',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
                onSubmitted: (_) => _rechercherEleves(),
              ),
            ),
            const SizedBox(width: 8),
            SSMQuickActionButton(
              icone: Icons.search,
              label: 'Rechercher',
              variante: SSMActionVariante.primaire,
              onTap: _rechercheEnCours ? null : _rechercherEleves,
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._resultatsRecherche.map((e) {
          final eleveId = e['id'] as int;
          final enCours = _eleveEnCoursDeGeneration == eleveId;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: SSMPalette.blanc,
              borderRadius: BorderRadius.circular(SSMRayons.grand),
              border: Border.all(color: SSMPalette.bordure),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${e['nom']} ${e['prenom']}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
                      if (e['matricule'] != null)
                        Text('Matricule : ${e['matricule']}', style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte3)),
                    ],
                  ),
                ),
                enCours
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: SSMPalette.indigo))
                    : SSMQuickActionButton(
                        icone: Icons.description_outlined,
                        label: 'Générer son bulletin',
                        variante: SSMActionVariante.teal,
                        onTap: _periodeId == null ? null : () => _genererIndividuel(eleveId),
                      ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
