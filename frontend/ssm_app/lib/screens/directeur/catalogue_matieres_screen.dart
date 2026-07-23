import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/matiere_service.dart';

const List<Color> _couleursCatalogue = [
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

const Color _indigoCatalogue = Color(0xFF1E3A8A);

Color _couleurDepuisHex(String? hex) {
  if (hex == null || hex.isEmpty) return _indigoCatalogue;
  try {
    return Color(int.parse(hex.replaceAll('#', '0xFF')));
  } catch (_) {
    return _indigoCatalogue;
  }
}

class CatalogueMatieresScreen extends StatefulWidget {
  const CatalogueMatieresScreen({super.key});

  @override
  State<CatalogueMatieresScreen> createState() => _CatalogueMatieresScreenState();
}

class _CatalogueMatieresScreenState extends State<CatalogueMatieresScreen> {
  List<dynamic> _matieres = [];
  bool _chargement = true;
  String _recherche = '';
  Timer? _debounceRecherche;

  @override
  void initState() {
    super.initState();
    _chargerListe();
  }

  @override
  void dispose() {
    _debounceRecherche?.cancel();
    super.dispose();
  }

  Future<void> _chargerListe() async {
    setState(() => _chargement = true);
    try {
      final matieres = await MatiereService.listerMatieres(
        recherche: _recherche.isEmpty ? null : _recherche,
      );
      setState(() {
        _matieres = matieres;
        _chargement = false;
      });
    } catch (e) {
      setState(() => _chargement = false);
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Catalogue des matières',
            style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: Colors.white)),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _afficherDialogMatiere(),
        backgroundColor: _indigoCatalogue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Nouvelle matière',
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _messageExplicatif(),
              const SizedBox(height: 12),
              _barreRecherche(),
              const SizedBox(height: 12),
              Expanded(
                child: _chargement
                    ? const Center(child: CircularProgressIndicator())
                    : _matieres.isEmpty
                        ? Center(
                            child: Text('Aucune matière créée',
                                style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF334155))),
                          )
                        : RefreshIndicator(
                            onRefresh: _chargerListe,
                            child: ListView.builder(
                              itemCount: _matieres.length,
                              itemBuilder: (context, index) => _itemMatiere(_matieres[index]),
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _messageExplicatif() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _indigoCatalogue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: _indigoCatalogue, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ce catalogue liste les matières disponibles pour votre école. '
              'Configurez les matières de chaque classe depuis le module Classes.',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF334155)),
            ),
          ),
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

  Widget _itemMatiere(dynamic matiere) {
    final id = matiere['id'] as int;
    final nom = matiere['nom'] as String;
    final code = matiere['code'] as String?;
    final couleur = _couleurDepuisHex(matiere['couleur'] as String?);

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          height: 64,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: couleur, shape: BoxShape.circle)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(nom,
                    style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              if (code != null && code.isNotEmpty) ...[
                Text(code, style: GoogleFonts.jetBrainsMono(fontSize: 12, color: const Color(0xFF94A3B8))),
                const SizedBox(width: 4),
              ],
              IconButton(
                icon: const Icon(Icons.edit, size: 18, color: _indigoCatalogue),
                onPressed: () => _afficherDialogMatiere(matiere: matiere),
              ),
              IconButton(
                icon: const Icon(Icons.delete, size: 18, color: Color(0xFFDC2626)),
                onPressed: () => _confirmerSuppression(id, nom),
              ),
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
    Color couleurSelectionnee = estModification ? _couleurDepuisHex(matiere['couleur'] as String?) : _indigoCatalogue;

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
                    Text(estModification ? 'Modifier la matière' : 'Nouvelle matière',
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
                    Text('Couleur', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF334155))),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _couleursCatalogue.map((c) {
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
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler'))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _indigoCatalogue,
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
  // SUPPRESSION
  // ══════════════════════════════════════════════════════

  Future<void> _confirmerSuppression(int id, String nom) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer "$nom" ?'),
        content: const Text('Cette action est impossible si la matière est utilisée dans une classe.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirme != true) return;

    try {
      await MatiereService.supprimerMatiere(id);
      _afficherSucces('Matière supprimée avec succès');
      _chargerListe();
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }
}