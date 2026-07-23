import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/matiere_service.dart';

const List<Color> _couleursMatiere = [
  Color(0xFF1E3A8A), // Indigo
  Color(0xFF0D9488), // Teal
  Color(0xFFD97706), // Ambre
  Color(0xFF16A34A), // Vert
  Color(0xFFDC2626), // Rouge
  Color(0xFFEA580C), // Orange
  Color(0xFF7C3AED), // Violet
  Color(0xFFDB2777), // Rose
  Color(0xFF0891B2), // Cyan
  Color(0xFF65A30D), // Lime
];

const Color _couleurParDefaut = Color(0xFF1E3A8A);

Color _couleurMatiere(dynamic matiere) {
  final couleur = matiere['couleur'] as String?;
  if (couleur == null || couleur.isEmpty) return _couleurParDefaut;
  try {
    return Color(int.parse(couleur.replaceAll('#', '0xFF')));
  } catch (_) {
    return _couleurParDefaut;
  }
}

class GestionMatieresScreen extends StatefulWidget {
  const GestionMatieresScreen({super.key});

  @override
  State<GestionMatieresScreen> createState() => _GestionMatieresScreenState();
}

class _GestionMatieresScreenState extends State<GestionMatieresScreen> {
  List<dynamic> _matieres = [];
  bool _chargementListe = true;
  String _recherche = '';
  Timer? _debounceRecherche;

  Map<String, dynamic>? _statistiques;
  bool _chargementStats = true;

  @override
  void initState() {
    super.initState();
    _chargerListe();
    _chargerStatistiques();
  }

  @override
  void dispose() {
    _debounceRecherche?.cancel();
    super.dispose();
  }

  Future<void> _chargerListe() async {
    setState(() => _chargementListe = true);
    try {
      final matieres = await MatiereService.listerMatieres(
        recherche: _recherche.isEmpty ? null : _recherche,
      );
      setState(() {
        _matieres = matieres;
        _chargementListe = false;
      });
    } catch (e) {
      setState(() => _chargementListe = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _chargerStatistiques() async {
    setState(() => _chargementStats = true);
    try {
      final stats = await MatiereService.statistiques();
      setState(() {
        _statistiques = stats;
        _chargementStats = false;
      });
    } catch (e) {
      setState(() => _chargementStats = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _onRechercheChangee(String valeur) {
    _debounceRecherche?.cancel();
    _debounceRecherche = Timer(const Duration(milliseconds: 400), () {
      _recherche = valeur;
      _chargerListe();
    });
  }

  void _afficherErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFFDC2626)),
    );
  }

  void _afficherSucces(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFF16A34A)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _afficherDialogMatiere(),
          backgroundColor: const Color(0xFF1E3A8A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          icon: const Icon(Icons.add, color: Colors.white),
          label: Text('Nouvelle matière',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
        body: SafeArea(
          child: Column(
            children: [
              _enTete(),
              TabBar(
                labelColor: const Color(0xFF1E3A8A),
                unselectedLabelColor: const Color(0xFF94A3B8),
                indicatorColor: const Color(0xFF1E3A8A),
                labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                tabs: const [
                  Tab(text: 'Matières'),
                  Tab(text: 'Statistiques'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _ongletListe(),
                    _ongletStatistiques(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // EN-TÊTE
  // ══════════════════════════════════════════════════════

  Widget _enTete() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF0D9488)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushReplacementNamed(context, '/tableau-de-bord');
                  }
                },
              ),
              const SizedBox(width: 4),
              Text('Retour', style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.8))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Matières', style: GoogleFonts.sora(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('${_matieres.length} matières configurées',
                      style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.7))),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text('${_matieres.length}',
                        style: GoogleFonts.sora(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
                    Text('matières', style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // ONGLET 1 — LISTE
  // ══════════════════════════════════════════════════════

  Widget _ongletListe() {
    return RefreshIndicator(
      onRefresh: _chargerListe,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _barreRecherche(),
          const SizedBox(height: 16),
          if (_chargementListe)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_matieres.isEmpty)
            _etatVide()
          else
            ..._matieres.map((m) => _carteMatiere(m)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _barreRecherche() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(50),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 16, color: const Color(0xFF334155).withValues(alpha: 0.6)),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  onChanged: _onRechercheChangee,
                  decoration: InputDecoration(
                    hintText: 'Rechercher une matière...',
                    border: InputBorder.none,
                    isDense: true,
                    hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF334155).withValues(alpha: 0.5)),
                  ),
                  style: GoogleFonts.inter(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _etatVide() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.book_outlined, size: 64, color: Color(0xFF94A3B8)),
            const SizedBox(height: 16),
            Text('Aucune matière créée', style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF334155))),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              ),
              onPressed: () => _afficherDialogMatiere(),
              child: const Text('Créer la première matière'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _carteMatiere(dynamic matiere) {
    final id = matiere['id'] as int;
    final nom = matiere['nom'] as String;
    final code = matiere['code'] as String?;
    final couleur = _couleurMatiere(matiere);
    final nombreClasses = (matiere['nombre_classes'] as num?)?.toInt() ?? 0;
    final enseignants = (matiere['enseignants'] as List?) ?? [];

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(14),
            border: Border(left: BorderSide(color: couleur, width: 4)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: couleur.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.book, color: couleur, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nom,
                        style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                    if (code != null && code.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(code,
                          style: GoogleFonts.jetBrainsMono(fontSize: 12, color: const Color(0xFF94A3B8))),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.school, size: 13, color: const Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Text('$nombreClasses classe${nombreClasses > 1 ? 's' : ''}',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                        const SizedBox(width: 12),
                        Icon(Icons.person, size: 13, color: const Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Text('${enseignants.length} prof${enseignants.length > 1 ? 's' : ''}',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Text('$nombreClasses classe${nombreClasses > 1 ? 's' : ''}',
                        style: GoogleFonts.inter(
                            fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E3A8A))),
                  ),
                  const SizedBox(height: 4),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Color(0xFF94A3B8)),
                    onSelected: (valeur) {
                      if (valeur == 'modifier') _afficherDialogMatiere(matiere: matiere);
                      if (valeur == 'statistiques') DefaultTabController.of(context).animateTo(1);
                      if (valeur == 'supprimer') _confirmerSuppression(id, nom, nombreClasses);
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'modifier',
                        child: Row(children: [
                          Icon(Icons.edit, color: Color(0xFF1E3A8A), size: 18),
                          SizedBox(width: 8),
                          Text('Modifier'),
                        ]),
                      ),
                      const PopupMenuItem(
                        value: 'statistiques',
                        child: Row(children: [
                          Icon(Icons.bar_chart, color: Color(0xFF0D9488), size: 18),
                          SizedBox(width: 8),
                          Text('Statistiques'),
                        ]),
                      ),
                      const PopupMenuItem(
                        value: 'supprimer',
                        child: Row(children: [
                          Icon(Icons.delete, color: Color(0xFFDC2626), size: 18),
                          SizedBox(width: 8),
                          Text('Supprimer'),
                        ]),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // ONGLET 2 — STATISTIQUES
  // ══════════════════════════════════════════════════════

  Widget _ongletStatistiques() {
    if (_chargementStats) {
      return const Center(child: CircularProgressIndicator());
    }
    final stats = _statistiques;
    if (stats == null) {
      return Center(child: Text('Erreur chargement statistiques', style: GoogleFonts.inter(color: const Color(0xFF334155))));
    }

    final matieres = (stats['matieres'] as List?) ?? [];
    final plusFacile = stats['matiere_plus_facile'] as Map<String, dynamic>?;
    final plusDifficile = stats['matiere_plus_difficile'] as Map<String, dynamic>?;

    return RefreshIndicator(
      onRefresh: _chargerStatistiques,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: _carteExtreme(
                titre: 'La plus facile',
                donnees: plusFacile,
                couleur: const Color(0xFF16A34A),
                icone: Icons.trending_up,
              )),
              const SizedBox(width: 12),
              Expanded(child: _carteExtreme(
                titre: 'La plus difficile',
                donnees: plusDifficile,
                couleur: const Color(0xFFDC2626),
                icone: Icons.trending_down,
              )),
            ],
          ),
          const SizedBox(height: 20),
          if (matieres.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text('Aucune statistique disponible', style: GoogleFonts.inter(color: const Color(0xFF334155))),
              ),
            )
          else
            ...matieres.map((m) => _carteStatMatiere(m as Map<String, dynamic>)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _carteExtreme({
    required String titre,
    required Map<String, dynamic>? donnees,
    required Color couleur,
    required IconData icone,
  }) {
    final nom = donnees?['matiere_nom'] as String?;
    final moyenne = donnees?['moyenne_generale'];

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: couleur.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icone, color: couleur, size: 24),
              const SizedBox(height: 8),
              Text(titre, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF334155))),
              const SizedBox(height: 4),
              Text(nom ?? '—',
                  style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(moyenne != null ? '$moyenne/20' : '—',
                  style: GoogleFonts.sora(fontSize: 28, fontWeight: FontWeight.w700, color: couleur)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _carteStatMatiere(Map<String, dynamic> matiere) {
    final nom = matiere['matiere_nom'] as String? ?? '';
    final moyenne = (matiere['moyenne_generale'] as num?)?.toDouble();
    final moyennesParClasse = (matiere['moyennes_par_classe'] as List?) ?? [];
    final couleur = moyenne == null
        ? const Color(0xFF94A3B8)
        : moyenne > 12
            ? const Color(0xFF16A34A)
            : moyenne > 8
                ? const Color(0xFFEA580C)
                : const Color(0xFFDC2626);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.book, size: 18, color: couleur),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(nom,
                        style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                  ),
                  Text(moyenne != null ? '${moyenne.toStringAsFixed(2)}/20' : '—/20',
                      style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: couleur)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: moyenne != null ? (moyenne / 20).clamp(0.0, 1.0) : 0,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFF1F5F9),
                  color: couleur,
                ),
              ),
              const SizedBox(height: 6),
              Text('${moyennesParClasse.length} classe${moyennesParClasse.length > 1 ? 's' : ''} concernée${moyennesParClasse.length > 1 ? 's' : ''}',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF334155))),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // DIALOG CRÉER / MODIFIER
  // ══════════════════════════════════════════════════════

  Future<void> _afficherDialogMatiere({dynamic matiere}) async {
    final estModification = matiere != null;
    final nomController = TextEditingController(text: estModification ? matiere['nom'] as String? : '');
    final codeController = TextEditingController(text: estModification ? (matiere['code'] as String? ?? '') : '');
    Color couleurSelectionnee = estModification ? _couleurMatiere(matiere) : _couleurParDefaut;

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
                    Text(estModification ? 'Modifier' : 'Nouvelle matière',
                        style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                    const SizedBox(height: 20),
                    TextField(
                      controller: nomController,
                      decoration: InputDecoration(
                        labelText: 'Nom *',
                        hintText: 'ex: Mathématiques, Français, SVT...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      style: GoogleFonts.inter(fontSize: 14),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: codeController,
                      decoration: InputDecoration(
                        labelText: 'Code (optionnel)',
                        hintText: 'ex: MATH, FR, SVT',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      style: GoogleFonts.jetBrainsMono(fontSize: 14),
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 16),
                    Text('Couleur d\'identification',
                        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF334155))),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _couleursMatiere.map((c) {
                        final selectionnee = c.toARGB32() == couleurSelectionnee.toARGB32();
                        return GestureDetector(
                          onTap: () => setStateDialog(() => couleurSelectionnee = c),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: selectionnee ? Border.all(color: Colors.white, width: 2) : null,
                              boxShadow: selectionnee
                                  ? [BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 6, offset: const Offset(0, 2))]
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: couleurSelectionnee.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(color: couleurSelectionnee, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            nomController.text.isEmpty ? 'Aperçu' : nomController.text,
                            style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler'))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E3A8A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () async {
                              if (nomController.text.trim().isEmpty) {
                                _afficherErreur('Le nom de la matière est obligatoire');
                                return;
                              }
                              final couleurHex =
                                  '#${couleurSelectionnee.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
                              try {
                                if (estModification) {
                                  await MatiereService.modifierMatiere(
                                    matiere['id'] as int,
                                    nom: nomController.text.trim(),
                                    code: codeController.text.trim().isEmpty ? null : codeController.text.trim(),
                                    couleur: couleurHex,
                                  );
                                  if (context.mounted) Navigator.pop(context);
                                  _afficherSucces('Matière modifiée avec succès');
                                } else {
                                  await MatiereService.creerMatiere(
                                    nom: nomController.text.trim(),
                                    code: codeController.text.trim().isEmpty ? null : codeController.text.trim(),
                                    couleur: couleurHex,
                                  );
                                  if (context.mounted) Navigator.pop(context);
                                  _afficherSucces('Matière créée avec succès');
                                }
                                _chargerListe();
                                _chargerStatistiques();
                              } catch (e) {
                                _afficherErreur(e.toString().replaceAll('Exception: ', ''));
                              }
                            },
                            child: Text(estModification ? 'Modifier' : 'Créer'),
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

    nomController.dispose();
    codeController.dispose();
  }

  // ══════════════════════════════════════════════════════
  // DIALOG SUPPRESSION
  // ══════════════════════════════════════════════════════

  Future<void> _confirmerSuppression(int id, String nom, int nombreClasses) async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 48),
                const SizedBox(height: 16),
                Text('Supprimer "$nom" ?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                if (nombreClasses > 0) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Cette matière est utilisée dans $nombreClasses classe(s). '
                    'La supprimer retirera également ses données de ces classes.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFDC2626)),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler'))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          try {
                            await MatiereService.supprimerMatiere(id);
                            if (context.mounted) Navigator.pop(context);
                            _afficherSucces('Matière supprimée avec succès');
                            _chargerListe();
                            _chargerStatistiques();
                          } catch (e) {
                            _afficherErreur(e.toString().replaceAll('Exception: ', ''));
                          }
                        },
                        child: const Text('Supprimer quand même'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}