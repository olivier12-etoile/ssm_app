import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/bulletin_model.dart';
import '../../models/historique_statistique_bulletin_model.dart';
import '../../services/annee_service.dart';
import '../../services/classe_service.dart';
import '../../services/historique_statistique_bulletin_service.dart';
import '../../widgets/ssm_widgets.dart';
import 'apercu_bulletin_screen.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _gris = Color(0xFF94A3B8);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);
const Color _rouge = Color(0xFFDC2626);

class HistoriqueRechercheBulletinsScreen extends StatefulWidget {
  const HistoriqueRechercheBulletinsScreen({super.key});

  @override
  State<HistoriqueRechercheBulletinsScreen> createState() => _HistoriqueRechercheBulletinsScreenState();
}

class _HistoriqueRechercheBulletinsScreenState extends State<HistoriqueRechercheBulletinsScreen> {
  final _rechercheController = TextEditingController();

  List<dynamic> _annees = [];
  List<dynamic> _classes = [];
  List<dynamic> _periodes = [];
  int? _anneeScolaireId;
  int? _classeId;
  int? _periodeId;
  bool _chargementFiltres = true;

  final List<BulletinHistorique> _resultats = [];
  int _page = 1;
  int _lastPage = 1;
  int _total = 0;
  bool _chargementResultats = false;
  bool _rechercheLancee = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _chargerFiltres();
  }

  @override
  void dispose() {
    _rechercheController.dispose();
    super.dispose();
  }

  Future<void> _chargerFiltres() async {
    try {
      final resultats = await Future.wait([
        AnneeService.listerAnnees(),
        ClasseService.listerClasses(),
      ]);
      if (!mounted) return;
      setState(() {
        _annees = resultats[0];
        _classes = resultats[1];
        _chargementFiltres = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargementFiltres = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _changerAnnee(int? anneeId) async {
    setState(() {
      _anneeScolaireId = anneeId;
      _periodeId = null;
      _periodes = [];
    });
    if (anneeId == null) return;
    try {
      final periodes = await AnneeService.listerPeriodes(anneeId);
      if (mounted) setState(() => _periodes = periodes);
    } catch (_) {
      // Les périodes restent vides ; le filtre reste facultatif.
    }
  }

  Future<void> _rechercher({bool nouvellePage = false}) async {
    if (!nouvellePage) {
      setState(() {
        _resultats.clear();
        _page = 1;
        _erreur = null;
        _rechercheLancee = true;
      });
    }

    setState(() => _chargementResultats = true);
    try {
      final resultat = await HistoriqueStatistiqueBulletinService.rechercherBulletins(
        query: _rechercheController.text.trim().isEmpty ? null : _rechercheController.text.trim(),
        classeId: _classeId,
        anneeScolaireId: _anneeScolaireId,
        periodeId: _periodeId,
        page: _page,
      );
      if (!mounted) return;
      setState(() {
        _resultats.addAll(resultat.resultats);
        _lastPage = resultat.lastPage;
        _total = resultat.total;
        _chargementResultats = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargementResultats = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _chargerPageSuivante() {
    _page++;
    _rechercher(nouvellePage: true);
  }

  void _reinitialiserFiltres() {
    setState(() {
      _classeId = null;
      _anneeScolaireId = null;
      _periodeId = null;
      _periodes = [];
    });
  }

  void _ouvrirApercu(BulletinHistorique h) {
    final resume = Bulletin(
      id: h.id,
      eleveId: h.eleveId,
      nomEleve: h.nomEleve,
      classeId: h.classeId ?? 0,
      nomClasse: h.nomClasse,
      periodeId: h.periodeId,
      nomPeriode: h.nomPeriode,
      moyenneGenerale: h.moyenneGenerale,
      rang: h.rang,
      effectifClasse: 0,
      totalCoefficients: 0,
      totalPoints: 0,
      statut: h.statut,
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ApercuBulletinScreen(bulletinId: h.id, resume: resume)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Historique & Recherche', style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: Colors.white)),
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
      ),
      body: _chargementFiltres
          ? const Center(child: CircularProgressIndicator(color: _indigo))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _rechercheController,
                        decoration: InputDecoration(
                          hintText: 'Nom, prénom ou matricule',
                          prefixIcon: const Icon(Icons.search),
                          border: const OutlineInputBorder(),
                          isDense: true,
                          suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: () => _rechercher()),
                        ),
                        onSubmitted: (_) => _rechercher(),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _classeId,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Classe', border: OutlineInputBorder(), isDense: true),
                              hint: const Text('Toutes'),
                              items: _classes.map((c) => DropdownMenuItem<int>(value: c['id'] as int, child: Text(c['nom'] as String))).toList(),
                              onChanged: (v) => setState(() => _classeId = v),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _anneeScolaireId,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Année', border: OutlineInputBorder(), isDense: true),
                              hint: const Text('Toutes'),
                              items: _annees.map((a) => DropdownMenuItem<int>(value: a['id'] as int, child: Text(a['libelle'] as String))).toList(),
                              onChanged: _changerAnnee,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _periodeId,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Période', border: OutlineInputBorder(), isDense: true),
                              hint: const Text('Toutes'),
                              items: _periodes.map((p) => DropdownMenuItem<int>(value: p['id'] as int, child: Text(p['nom'] as String))).toList(),
                              onChanged: _periodes.isEmpty ? null : (v) => setState(() => _periodeId = v),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(onPressed: _reinitialiserFiltres, child: const Text('Réinitialiser')),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _rechercher(),
                            style: ElevatedButton.styleFrom(backgroundColor: _indigo, foregroundColor: Colors.white),
                            child: const Text('Rechercher'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(child: _corpsResultats()),
              ],
            ),
    );
  }

  Widget _corpsResultats() {
    if (!_rechercheLancee) {
      return Center(
        child: Text('Recherchez un élève ou filtrez par classe/année/période.', style: GoogleFonts.inter(color: _gris)),
      );
    }
    if (_erreur != null) {
      return Center(child: Text(_erreur!, style: GoogleFonts.inter(color: _rouge)));
    }
    if (_resultats.isEmpty && !_chargementResultats) {
      return Center(child: Text('Aucun bulletin trouvé.', style: GoogleFonts.inter(color: _gris)));
    }

    final afficherChargerPlus = _page < _lastPage;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: _resultats.length + 1 + (afficherChargerPlus ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('$_total résultat(s)', style: GoogleFonts.inter(fontSize: 12, color: _texte)),
          );
        }
        if (afficherChargerPlus && index == _resultats.length + 1) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: _chargementResultats
                  ? const CircularProgressIndicator(color: _indigo)
                  : OutlinedButton(onPressed: _chargerPageSuivante, child: const Text('Charger plus')),
            ),
          );
        }
        final h = _resultats[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _ouvrirApercu(h),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _gris.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(h.nomEleve ?? 'Élève #${h.eleveId}',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _texteFonce)),
                          const SizedBox(height: 2),
                          Text(
                            '${h.nomClasse ?? '—'} · ${h.nomPeriode ?? '—'}${h.nomAnnee != null ? ' · ${h.nomAnnee}' : ''}',
                            style: GoogleFonts.inter(fontSize: 11, color: _gris),
                          ),
                        ],
                      ),
                    ),
                    Text('${h.moyenneGenerale.toStringAsFixed(2)}/20',
                        style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700, color: _texteFonce)),
                    const SizedBox(width: 10),
                    SSMBadge(label: h.statut.libelle, couleur: h.statut.couleur),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
