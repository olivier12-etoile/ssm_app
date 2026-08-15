import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/bulletin_model.dart';
import '../../services/annee_service.dart';
import '../../services/classe_service.dart';
import '../../services/eleve_service.dart';
import '../../services/bulletin_service.dart';
import 'liste_bulletins_classe_screen.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _teal = Color(0xFF0D9488);
const Color _ambre = Color(0xFFD97706);
const Color _vert = Color(0xFF16A34A);
const Color _rouge = Color(0xFFDC2626);
const Color _gris = Color(0xFF94A3B8);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);

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
        title: const Text('Générer les bulletins ?'),
        content: Text(
          malgreBlocages
              ? '${_elevesPrets.length} élève(s) prêt(s) sur $total seront générés. '
                  '${_elevesBloques.length} élève(s) resteront bloqué(s) (voir raisons ci-dessous).'
              : 'Les bulletins seront générés pour les $total élève(s) de la classe.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: _indigo, foregroundColor: Colors.white),
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: _rouge));
  }

  void _afficherSucces(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: _vert));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Génération de bulletins', style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: Colors.white)),
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
      ),
      body: _chargementListes
          ? const Center(child: CircularProgressIndicator(color: _indigo))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _carteSelecteurs(),
                const SizedBox(height: 16),
                _boutonVerifier(),
                const SizedBox(height: 16),
                if (_verificationEnCours) const Center(child: CircularProgressIndicator(color: _indigo)),
                if (_statuts != null) ..._blocVerification(),
                if (_generationEnCours) _blocGenerationEnCours(),
                if (_resume != null) ..._blocResume(),
                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 12),
                Text('Génération individuelle', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: _texteFonce)),
                const SizedBox(height: 4),
                Text('Recherchez un élève par nom, prénom ou matricule.', style: GoogleFonts.inter(fontSize: 12, color: _texte)),
                const SizedBox(height: 12),
                _blocRechercheIndividuelle(),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  // ── Sélecteurs ────────────────────────────────────────────

  Widget _carteSelecteurs() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _gris.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          DropdownButtonFormField<int>(
            value: _classeId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Classe', prefixIcon: Icon(Icons.class_outlined), border: OutlineInputBorder(), isDense: true),
            hint: const Text('Choisir une classe'),
            items: _classes.map((c) => DropdownMenuItem<int>(value: c['id'] as int, child: Text(c['nom'] as String))).toList(),
            onChanged: _changerClasse,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _periodeId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Période', prefixIcon: Icon(Icons.segment), border: OutlineInputBorder(), isDense: true),
            hint: const Text('Choisir une période'),
            items: _periodes.map((p) => DropdownMenuItem<int>(value: p['id'] as int, child: Text(p['nom'] as String))).toList(),
            onChanged: _changerPeriode,
          ),
        ],
      ),
    );
  }

  Widget _boutonVerifier() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: (_classeId == null || _periodeId == null || _verificationEnCours) ? null : _verifier,
        style: OutlinedButton.styleFrom(foregroundColor: _indigo, side: const BorderSide(color: _indigo), padding: const EdgeInsets.symmetric(vertical: 14)),
        icon: const Icon(Icons.fact_check_outlined),
        label: Text('Vérifier avant génération', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
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
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bloques.isEmpty ? _vert.withValues(alpha: 0.08) : _ambre.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: (bloques.isEmpty ? _vert : _ambre).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(bloques.isEmpty ? Icons.check_circle_outline : Icons.warning_amber_outlined,
                color: bloques.isEmpty ? _vert : _ambre),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                bloques.isEmpty
                    ? '${statuts.length} élève(s) — tous prêts (${dejaGeneres.length} déjà généré(s)).'
                    : '${bloques.length} élève(s) bloqué(s) sur ${statuts.length}, ${prets.length} prêt(s), ${dejaGeneres.length} déjà généré(s).',
                style: GoogleFonts.inter(fontSize: 12, color: _texte),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      ...statuts.map(_ligneStatutEleve),
      const SizedBox(height: 12),
      if (bloques.isEmpty)
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: prets.isEmpty ? null : () => _genererClasse(malgreBlocages: false),
            style: ElevatedButton.styleFrom(backgroundColor: _indigo, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
            icon: const Icon(Icons.auto_awesome),
            label: Text('Générer les bulletins de la classe', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        )
      else ...[
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: null,
            style: ElevatedButton.styleFrom(backgroundColor: _gris, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
            icon: const Icon(Icons.block),
            label: const Text('Génération complète impossible — élèves bloqués'),
          ),
        ),
        const SizedBox(height: 8),
        if (prets.isNotEmpty)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _genererClasse(malgreBlocages: true),
              style: OutlinedButton.styleFrom(foregroundColor: _ambre, side: const BorderSide(color: _ambre), padding: const EdgeInsets.symmetric(vertical: 14)),
              icon: const Icon(Icons.playlist_add_check),
              label: Text('Générer quand même pour les ${prets.length} élève(s) prêt(s)', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ),
      ],
    ];
  }

  Widget _ligneStatutEleve(StatutGenerationEleve s) {
    final pret = s.genere || s.raisonBlocage == null;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: pret ? _vert : _rouge, width: 4)),
      ),
      child: Row(
        children: [
          Icon(s.genere ? Icons.check_circle : (pret ? Icons.check_circle_outline : Icons.cancel_outlined),
              color: pret ? _vert : _rouge, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.nom, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _texteFonce)),
                if (s.genere)
                  Text('Bulletin déjà généré', style: GoogleFonts.inter(fontSize: 11, color: _gris))
                else if (s.raisonBlocage != null)
                  Text(s.raisonBlocage!, style: GoogleFonts.inter(fontSize: 11, color: _rouge)),
              ],
            ),
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
          const CircularProgressIndicator(color: _indigo),
          const SizedBox(height: 12),
          Text(
            total > 0 ? 'Génération en cours pour $total élève(s)...' : 'Génération en cours...',
            style: GoogleFonts.inter(color: _texte),
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
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _indigo.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Résultat de la génération', style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: _texteFonce)),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.check_circle, color: _vert, size: 16),
                const SizedBox(width: 6),
                Text('${r.nombreReussis} réussi(s)', style: GoogleFonts.inter(fontSize: 13, color: _texte)),
                const SizedBox(width: 16),
                Icon(Icons.cancel, color: _rouge, size: 16),
                const SizedBox(width: 6),
                Text('${r.nombreEchecs} échec(s)', style: GoogleFonts.inter(fontSize: 13, color: _texte)),
              ],
            ),
            if (r.echecs.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...r.echecs.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• ${e.nom} : ${e.raison ?? '—'}', style: GoogleFonts.inter(fontSize: 12, color: _rouge)),
                  )),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _voirBulletinsGeneres,
                style: ElevatedButton.styleFrom(backgroundColor: _teal, foregroundColor: Colors.white),
                icon: const Icon(Icons.list_alt),
                label: const Text('Voir les bulletins générés'),
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
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => _rechercherEleves(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _rechercheEnCours ? null : _rechercherEleves,
              style: ElevatedButton.styleFrom(backgroundColor: _indigo, foregroundColor: Colors.white),
              child: _rechercheEnCours
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.search),
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
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _gris.withValues(alpha: 0.2))),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${e['nom']} ${e['prenom']}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _texteFonce)),
                      if (e['matricule'] != null)
                        Text('Matricule : ${e['matricule']}', style: GoogleFonts.inter(fontSize: 11, color: _gris)),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: (enCours || _periodeId == null) ? null : () => _genererIndividuel(eleveId),
                  style: OutlinedButton.styleFrom(foregroundColor: _indigo, side: const BorderSide(color: _indigo)),
                  child: enCours
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _indigo))
                      : const Text('Générer son bulletin'),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
