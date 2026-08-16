import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/statistique_detail_model.dart';
import '../../services/annee_service.dart';
import '../../services/statistique_detail_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_alert_item.dart';
import '../../widgets/ssm/ssm_data_table.dart';
import '../../widgets/ssm/ssm_panel.dart';
import '../../widgets/ssm/ssm_sous_entete.dart';

const List<Color> _couleursMedaille = [Color(0xFFD4AF37), Color(0xFFA8A8A8), Color(0xFFB08D57)];

Color _couleurMoyenne(double? moyenne) {
  if (moyenne == null) return SSMPalette.texte3;
  if (moyenne >= 14) return SSMPalette.teal;
  if (moyenne >= 10) return SSMPalette.indigo;
  return SSMPalette.rouge;
}

// ══════════════════════════════════════════════════════════
// Écran détaillé "Résultats pédagogiques" du module Statistiques : 4
// onglets (par matière, par enseignant, par classe, classements) pour une
// période choisie.
// ══════════════════════════════════════════════════════════
class PedagogiqueDetailScreen extends StatefulWidget {
  final int? periodeId;
  final int initialTabIndex;

  const PedagogiqueDetailScreen({super.key, this.periodeId, this.initialTabIndex = 0});

  @override
  State<PedagogiqueDetailScreen> createState() => _PedagogiqueDetailScreenState();
}

class _PedagogiqueDetailScreenState extends State<PedagogiqueDetailScreen> {
  late int _ongletActif = widget.initialTabIndex;

  List<dynamic> _periodes = [];
  int? _periodeId;

  List<StatMatiere> _parMatiere = [];
  List<StatEnseignant> _parEnseignant = [];
  List<StatClasse> _parClasse = [];
  List<StatClasse> _meilleuresClasses = [];
  List<EleveClassement> _meilleursEleves = [];
  List<EleveClassement> _elevesEnDifficulte = [];
  double _seuilDifficulte = 8;

  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _initialiser();
  }

  Future<void> _initialiser() async {
    try {
      var periodeId = widget.periodeId;
      List<dynamic> periodes = [];

      final data = await AnneeService.anneeActive();
      final annee = data['annee'] as Map<String, dynamic>?;
      if (annee != null) {
        periodes = await AnneeService.listerPeriodes(annee['id'] as int);
        periodeId ??= (data['periode_active'] as Map<String, dynamic>?)?['id'] as int? ??
            (periodes.isNotEmpty ? periodes.first['id'] as int : null);
      }

      if (!mounted) return;
      setState(() {
        _periodes = periodes;
        _periodeId = periodeId;
      });
      await _charger();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _charger() async {
    if (_periodeId == null) {
      setState(() => _chargement = false);
      return;
    }
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final resultats = await Future.wait([
        StatistiqueDetailService.getPedagogiqueParMatiere(_periodeId!),
        StatistiqueDetailService.getPedagogiqueParEnseignant(_periodeId!),
        StatistiqueDetailService.getPedagogiqueParClasse(_periodeId!),
        StatistiqueDetailService.getMeilleuresClasses(_periodeId!),
        StatistiqueDetailService.getMeilleursEleves(_periodeId!),
        StatistiqueDetailService.getElevesEnDifficulte(_periodeId!, seuil: _seuilDifficulte),
      ]);
      if (!mounted) return;
      setState(() {
        _parMatiere = resultats[0] as List<StatMatiere>;
        _parEnseignant = resultats[1] as List<StatEnseignant>;
        _parClasse = resultats[2] as List<StatClasse>;
        _meilleuresClasses = resultats[3] as List<StatClasse>;
        _meilleursEleves = resultats[4] as List<EleveClassement>;
        _elevesEnDifficulte = resultats[5] as List<EleveClassement>;
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

  Future<void> _rechargerDifficulte() async {
    if (_periodeId == null) return;
    try {
      final eleves = await StatistiqueDetailService.getElevesEnDifficulte(_periodeId!, seuil: _seuilDifficulte);
      if (mounted) setState(() => _elevesEnDifficulte = eleves);
    } catch (_) {
      // La section reste simplement inchangée si le rechargement échoue.
    }
  }

  void _changerPeriode(int? id) {
    if (id == null || id == _periodeId) return;
    setState(() => _periodeId = id);
    _charger();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SSMPalette.fond,
      body: SafeArea(
        child: Column(
          children: [
            SSMSousEnTete(
              titre: 'Résultats pédagogiques',
              onRetour: () => Navigator.pop(context),
              complement: _selecteurPeriode(),
            ),
            _barreOnglets(),
            Expanded(
              child: _chargement && _erreur == null
                  ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
                  : _erreur != null
                      ? _carteErreur(_erreur!, _charger)
                      : IndexedStack(
                          index: _ongletActif,
                          sizing: StackFit.expand,
                          children: [
                            _ongletMatiere(),
                            _ongletEnseignant(),
                            _ongletClasse(),
                            _ongletClassements(),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selecteurPeriode() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(SSMRayons.moyen),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _periodeId,
          isDense: true,
          icon: const Icon(Icons.expand_more, size: 16, color: SSMPalette.texte3),
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: SSMPalette.texte1),
          items: _periodes.map((p) => DropdownMenuItem<int>(value: p['id'] as int, child: Text(p['nom'] as String? ?? '—'))).toList(),
          onChanged: _changerPeriode,
        ),
      ),
    );
  }

  // Onglets stylés comme des pilules (indigo actif) — même pattern que
  // _boutonTri de debiteurs_screen.dart, pour rester cohérent.
  Widget _barreOnglets() {
    const libelles = ['Par matière', 'Par enseignant', 'Par classe', 'Classements'];
    return Container(
      color: SSMPalette.blanc,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < libelles.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              _boutonOnglet(libelles[i], i),
            ],
          ],
        ),
      ),
    );
  }

  Widget _boutonOnglet(String label, int index) {
    final actif = _ongletActif == index;
    return GestureDetector(
      onTap: () => setState(() => _ongletActif = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: actif ? SSMPalette.indigo : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(SSMRayons.pilule),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: actif ? Colors.white : SSMPalette.texte2),
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

  Widget _etatVide(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(child: Text(message, style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2))),
    );
  }

  Widget _carteBlanche({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SSMPalette.blanc,
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        border: Border.all(color: SSMPalette.bordure),
      ),
      child: child,
    );
  }

  // ══════════════════════════════════════════════════════
  // ONGLET PAR MATIÈRE
  // ══════════════════════════════════════════════════════

  Widget _ongletMatiere() {
    if (_parMatiere.isEmpty) return _etatVide('Aucune note saisie pour cette période.');
    return RefreshIndicator(
      onRefresh: _charger,
      color: SSMPalette.indigo,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: _parMatiere.map((m) {
          final couleur = _couleurMoyenne(m.moyenneGenerale);
          return _carteBlanche(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(m.matiere, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: SSMPalette.texte1))),
                    Text(
                      m.moyenneGenerale != null ? '${m.moyenneGenerale!.toStringAsFixed(1)}/20' : '—',
                      style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.w700, color: couleur),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    _mini('Meilleure note', m.meilleureNote != null ? '${m.meilleureNote}/20' : '—'),
                    _mini('Plus faible note', m.plusFaibleNote != null ? '${m.plusFaibleNote}/20' : '—'),
                    _mini('Taux de réussite', '${m.tauxReussite.toStringAsFixed(0)}%'),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // ONGLET PAR ENSEIGNANT
  // ══════════════════════════════════════════════════════

  Widget _ongletEnseignant() {
    if (_parEnseignant.isEmpty) return _etatVide('Aucun enseignant trouvé pour cette période.');
    return RefreshIndicator(
      onRefresh: _charger,
      color: SSMPalette.indigo,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: _parEnseignant.map((e) {
          return _carteBlanche(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: SSMPalette.indigoClair,
                  child: Text(
                    e.nom.isNotEmpty ? e.nom[0].toUpperCase() : '?',
                    style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: SSMPalette.indigo),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.nom, style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: SSMPalette.texte1)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 14,
                        runSpacing: 2,
                        children: [
                          _mini('Notes saisies', '${e.nbNotesSaisies}'),
                          _mini('Classes', '${e.nbClasses}'),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  e.moyenneClasses != null ? '${e.moyenneClasses!.toStringAsFixed(1)}/20' : '—',
                  style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.w700, color: _couleurMoyenne(e.moyenneClasses)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // ONGLET PAR CLASSE
  // ══════════════════════════════════════════════════════

  Widget _ongletClasse() {
    if (_parClasse.isEmpty) return _etatVide('Aucune classe trouvée pour cette période.');
    return RefreshIndicator(
      onRefresh: _charger,
      color: SSMPalette.indigo,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: _parClasse.map((c) {
          final couleur = _couleurMoyenne(c.moyenneGenerale);
          return _carteBlanche(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(c.classe, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: SSMPalette.texte1))),
                    Text(
                      c.moyenneGenerale != null ? '${c.moyenneGenerale!.toStringAsFixed(1)}/20' : '—',
                      style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.w700, color: couleur),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (c.meilleurEleve != null) _lignePersonne(Icons.emoji_events_outlined, 'Meilleur élève', c.meilleurEleve!, SSMPalette.teal),
                if (c.dernierEleve != null) _lignePersonne(Icons.trending_down, 'Dernier élève', c.dernierEleve!, SSMPalette.rouge),
                const SizedBox(height: 4),
                _mini('Taux de réussite', '${c.tauxReussite.toStringAsFixed(0)}%'),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _lignePersonne(IconData icone, String label, String valeur, Color couleur) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icone, size: 14, color: couleur),
          const SizedBox(width: 6),
          Text('$label : ', style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte2)),
          Expanded(child: Text(valeur, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: SSMPalette.texte1))),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // ONGLET CLASSEMENTS
  // ══════════════════════════════════════════════════════

  Widget _ongletClassements() {
    return RefreshIndicator(
      onRefresh: _charger,
      color: SSMPalette.indigo,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SSMPanel(
            titre: 'Top 10 classes',
            padding: EdgeInsets.zero,
            child: _meilleuresClasses.isEmpty
                ? Padding(padding: const EdgeInsets.all(16), child: _etatVide('Aucun classement disponible.'))
                : Column(
                    children: [
                      for (final entry in _meilleuresClasses.asMap().entries) _ligneRangClasse(entry.key, entry.value),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          SSMPanel(
            titre: 'Top 10 élèves',
            padding: EdgeInsets.zero,
            child: _meilleursEleves.isEmpty
                ? Padding(padding: const EdgeInsets.all(16), child: _etatVide('Aucun classement disponible.'))
                : Column(children: [for (final e in _meilleursEleves) _ligneRangEleve(e)]),
          ),
          const SizedBox(height: 16),
          _sectionDifficulte(),
        ],
      ),
    );
  }

  Widget _badgeRang(int rang) {
    final estMedaille = rang <= 3;
    final couleur = estMedaille ? _couleursMedaille[rang - 1] : SSMPalette.texte3;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: couleur.withValues(alpha: 0.15), shape: BoxShape.circle),
      child: estMedaille
          ? Icon(Icons.emoji_events, size: 15, color: couleur)
          : Text('$rang', style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w700, color: couleur)),
    );
  }

  Widget _ligneRangClasse(int index, StatClasse c) {
    final rang = index + 1;
    final couleur = _couleurMoyenne(c.moyenneGenerale);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: SSMPalette.bordure))),
      child: Row(
        children: [
          _badgeRang(rang),
          const SizedBox(width: 12),
          Expanded(child: Text(c.classe, style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600, color: SSMPalette.texte1))),
          Text(
            c.moyenneGenerale != null ? '${c.moyenneGenerale!.toStringAsFixed(1)}/20' : '—',
            style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700, color: couleur),
          ),
        ],
      ),
    );
  }

  Widget _ligneRangEleve(EleveClassement e) {
    final couleur = _couleurMoyenne(e.moyenne);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: SSMPalette.bordure))),
      child: Row(
        children: [
          _badgeRang(e.rang),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.nomComplet, style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
                Text(e.classe, style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte3)),
              ],
            ),
          ),
          Text(
            e.moyenne != null ? '${e.moyenne!.toStringAsFixed(1)}/20' : '—',
            style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700, color: couleur),
          ),
        ],
      ),
    );
  }

  Widget _sectionDifficulte() {
    return SSMPanel(
      titre: 'Élèves en difficulté',
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Seuil de moyenne', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
                Text('${_seuilDifficulte.toStringAsFixed(0)}/20', style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: SSMPalette.rouge)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Slider(
              value: _seuilDifficulte,
              min: 0,
              max: 15,
              divisions: 15,
              activeColor: SSMPalette.rouge,
              label: '${_seuilDifficulte.toStringAsFixed(0)}/20',
              onChanged: (v) => setState(() => _seuilDifficulte = v),
              onChangeEnd: (_) => _rechargerDifficulte(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: _elevesEnDifficulte.isEmpty
                ? const SSMAlertItem(
                    type: SSMAlerteType.succes,
                    icone: Icons.check_circle_outline,
                    titre: 'Aucun élève sous ce seuil',
                    sousTitre: "Tous les élèves ont une moyenne au-dessus du seuil choisi.",
                  )
                : SSMAlertItem(
                    type: SSMAlerteType.avertissement,
                    icone: Icons.warning_amber_rounded,
                    titre: '${_elevesEnDifficulte.length} élève(s) en difficulté',
                    sousTitre: 'Moyenne sous le seuil de ${_seuilDifficulte.toStringAsFixed(0)}/20 pour la période sélectionnée.',
                  ),
          ),
          if (_elevesEnDifficulte.isNotEmpty)
            SSMDataTable(
              colonnes: const [SSMDataColumn('Élève'), SSMDataColumn('Classe'), SSMDataColumn('Moyenne')],
              lignes: [
                for (final e in _elevesEnDifficulte)
                  [
                    Text(e.nomComplet, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
                    Text(e.classe, style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
                    Text(
                      e.moyenne != null ? '${e.moyenne!.toStringAsFixed(1)}/20' : '—',
                      style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: SSMPalette.rouge),
                    ),
                  ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _mini(String label, String valeur) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(valeur, style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: SSMPalette.texte1)),
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: SSMPalette.texte3)),
      ],
    );
  }
}
