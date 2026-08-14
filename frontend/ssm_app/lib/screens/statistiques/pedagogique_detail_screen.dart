import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/statistique_detail_model.dart';
import '../../services/annee_service.dart';
import '../../services/statistique_detail_service.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _teal = Color(0xFF0D9488);
const Color _vert = Color(0xFF16A34A);
const Color _rouge = Color(0xFFDC2626);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);
const Color _gris = Color(0xFF94A3B8);
const Color _fond = Color(0xFFEFF6FF);
const List<Color> _couleursMedaille = [Color(0xFFD4AF37), Color(0xFFA8A8A8), Color(0xFFB08D57)];

Color _couleurMoyenne(double? moyenne) {
  if (moyenne == null) return _gris;
  if (moyenne >= 14) return _vert;
  if (moyenne >= 10) return _teal;
  return _rouge;
}

// ══════════════════════════════════════════════════════════
// Écran détaillé "Résultats pédagogiques" du module Statistiques (Phase 5) :
// 4 onglets (par matière, par enseignant, par classe, classements) pour une
// période choisie.
// ══════════════════════════════════════════════════════════
class PedagogiqueDetailScreen extends StatefulWidget {
  final int? periodeId;
  final int initialTabIndex;

  const PedagogiqueDetailScreen({super.key, this.periodeId, this.initialTabIndex = 0});

  @override
  State<PedagogiqueDetailScreen> createState() => _PedagogiqueDetailScreenState();
}

class _PedagogiqueDetailScreenState extends State<PedagogiqueDetailScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

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
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialTabIndex);
    _initialiser();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
      backgroundColor: _fond,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: Text('Résultats pédagogiques', style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: Colors.white)),
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Par matière'),
            Tab(text: 'Par enseignant'),
            Tab(text: 'Par classe'),
            Tab(text: 'Classements'),
          ],
        ),
      ),
      body: Stack(
        children: [
          Positioned(top: -80, right: -60, child: _blob(size: 240, couleur: _indigo.withValues(alpha: 0.08))),
          Positioned(bottom: -60, left: -60, child: _blob(size: 200, couleur: _teal.withValues(alpha: 0.10))),
          SafeArea(
            child: Column(
              children: [
                Padding(padding: const EdgeInsets.all(16), child: _selecteurPeriode()),
                Expanded(
                  child: _chargement && _erreur == null
                      ? const Center(child: CircularProgressIndicator(color: _indigo))
                      : _erreur != null
                          ? _carteErreur(_erreur!, _charger)
                          : TabBarView(
                              controller: _tabController,
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
        ],
      ),
    );
  }

  Widget _blob({required double size, required Color couleur}) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: couleur)),
      ),
    );
  }

  Widget _selecteurPeriode() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
          ),
          child: DropdownButtonFormField<int>(
            value: _periodeId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Période',
              labelStyle: GoogleFonts.inter(fontSize: 12, color: _texte),
              isDense: true,
              border: InputBorder.none,
            ),
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _texteFonce),
            items: _periodes.map((p) => DropdownMenuItem<int>(value: p['id'] as int, child: Text(p['nom'] as String? ?? '—'))).toList(),
            onChanged: _changerPeriode,
          ),
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

  Widget _etatVide(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(child: Text(message, style: GoogleFonts.inter(fontSize: 12, color: _texte))),
    );
  }

  Widget _carteGlass({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
            boxShadow: [BoxShadow(color: _texteFonce.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 4))],
          ),
          child: child,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // ONGLET PAR MATIÈRE
  // ══════════════════════════════════════════════════════

  Widget _ongletMatiere() {
    if (_parMatiere.isEmpty) return _etatVide('Aucune note saisie pour cette période.');
    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: _parMatiere.map((m) {
          final couleur = _couleurMoyenne(m.moyenneGenerale);
          return _carteGlass(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(m.matiere, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: _texteFonce))),
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
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: _parEnseignant.map((e) {
          return _carteGlass(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: _indigo.withValues(alpha: 0.15),
                  child: Text(
                    e.nom.isNotEmpty ? e.nom[0].toUpperCase() : '?',
                    style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: _indigo),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.nom, style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: _texteFonce)),
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
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: _parClasse.map((c) {
          final couleur = _couleurMoyenne(c.moyenneGenerale);
          return _carteGlass(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(c.classe, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: _texteFonce))),
                    Text(
                      c.moyenneGenerale != null ? '${c.moyenneGenerale!.toStringAsFixed(1)}/20' : '—',
                      style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.w700, color: couleur),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (c.meilleurEleve != null) _lignePersonne(Icons.emoji_events_outlined, 'Meilleur élève', c.meilleurEleve!, _vert),
                if (c.dernierEleve != null) _lignePersonne(Icons.trending_down, 'Dernier élève', c.dernierEleve!, _rouge),
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
          Text('$label : ', style: GoogleFonts.inter(fontSize: 11, color: _texte)),
          Expanded(child: Text(valeur, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: _texteFonce))),
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
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Top 10 classes', style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: _texteFonce)),
          const SizedBox(height: 10),
          if (_meilleuresClasses.isEmpty)
            _etatVide('Aucun classement disponible.')
          else
            ..._meilleuresClasses.asMap().entries.map((entry) => _carteRangClasse(entry.key, entry.value)),
          const SizedBox(height: 24),
          Text('Top 10 élèves', style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: _texteFonce)),
          const SizedBox(height: 10),
          if (_meilleursEleves.isEmpty)
            _etatVide('Aucun classement disponible.')
          else
            ..._meilleursEleves.map(_carteRangEleve),
          const SizedBox(height: 24),
          _sectionDifficulte(),
        ],
      ),
    );
  }

  Widget _badgeRang(int rang) {
    final couleur = rang <= 3 ? _couleursMedaille[rang - 1] : _gris;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: couleur.withValues(alpha: 0.15), shape: BoxShape.circle),
      child: rang <= 3
          ? Icon(Icons.emoji_events, size: 15, color: couleur)
          : Text('$rang', style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w700, color: couleur)),
    );
  }

  Widget _carteRangClasse(int index, StatClasse c) {
    final rang = index + 1;
    final couleur = _couleurMoyenne(c.moyenneGenerale);
    return _carteGlass(
      child: Row(
        children: [
          _badgeRang(rang),
          const SizedBox(width: 12),
          Expanded(child: Text(c.classe, style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600, color: _texteFonce))),
          Text(
            c.moyenneGenerale != null ? '${c.moyenneGenerale!.toStringAsFixed(1)}/20' : '—',
            style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700, color: couleur),
          ),
        ],
      ),
    );
  }

  Widget _carteRangEleve(EleveClassement e) {
    final couleur = _couleurMoyenne(e.moyenne);
    return _carteGlass(
      child: Row(
        children: [
          _badgeRang(e.rang),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.nomComplet, style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600, color: _texteFonce)),
                Text(e.classe, style: GoogleFonts.inter(fontSize: 11, color: _gris)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Élèves en difficulté', style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: _texteFonce)),
            Text('Seuil : ${_seuilDifficulte.toStringAsFixed(0)}/20', style: GoogleFonts.jetBrainsMono(fontSize: 12, color: _rouge)),
          ],
        ),
        Slider(
          value: _seuilDifficulte,
          min: 0,
          max: 15,
          divisions: 15,
          activeColor: _rouge,
          label: '${_seuilDifficulte.toStringAsFixed(0)}/20',
          onChanged: (v) => setState(() => _seuilDifficulte = v),
          onChangeEnd: (_) => _rechargerDifficulte(),
        ),
        if (_elevesEnDifficulte.isEmpty)
          _etatVide('Aucun élève sous ce seuil.')
        else
          ..._elevesEnDifficulte.map((e) => _carteGlass(
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: _rouge, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.nomComplet, style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600, color: _texteFonce)),
                          Text(e.classe, style: GoogleFonts.inter(fontSize: 11, color: _gris)),
                        ],
                      ),
                    ),
                    Text(
                      e.moyenne != null ? '${e.moyenne!.toStringAsFixed(1)}/20' : '—',
                      style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700, color: _rouge),
                    ),
                  ],
                ),
              )),
      ],
    );
  }

  Widget _mini(String label, String valeur) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(valeur, style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: _texteFonce)),
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: _gris)),
      ],
    );
  }
}
