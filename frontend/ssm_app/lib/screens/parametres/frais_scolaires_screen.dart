import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/frais_scolaire_model.dart';
import '../../services/frais_scolaire_service.dart';
import '../../services/classe_service.dart';
import '../../services/annee_service.dart';
import 'frais_scolaire_form_screen.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _teal = Color(0xFF0D9488);
const Color _ambre = Color(0xFFD97706);
const Color _vert = Color(0xFF16A34A);
const Color _rouge = Color(0xFFDC2626);
const Color _gris = Color(0xFF94A3B8);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);

String _formatDateCourt(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _formatMontant(double m) {
  final entier = m.round();
  final texte = entier.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < texte.length; i++) {
    if (i > 0 && (texte.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(texte[i]);
  }
  return '${buffer.toString()} FCFA';
}

class FraisScolairesScreen extends StatefulWidget {
  const FraisScolairesScreen({super.key});

  @override
  State<FraisScolairesScreen> createState() => _FraisScolairesScreenState();
}

class _FraisScolairesScreenState extends State<FraisScolairesScreen> {
  List<FraisScolaire> _frais = [];
  List<dynamic> _classes = [];
  List<dynamic> _annees = [];

  int? _filtreClasseId;
  int? _filtreAnneeId;
  bool? _filtreActif;

  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _chargerReferences();
    _chargerListe();
  }

  Future<void> _chargerReferences() async {
    try {
      final resultats = await Future.wait([
        ClasseService.listerClasses(),
        AnneeService.listerAnnees(),
      ]);
      setState(() {
        _classes = resultats[0];
        _annees = resultats[1];
        _filtreAnneeId ??= _anneeParDefaut();
      });
    } catch (_) {
      // Listes de référence non bloquantes pour l'affichage.
    }
  }

  int? _anneeParDefaut() {
    if (_annees.isEmpty) return null;
    final active = _annees.firstWhere(
      (a) => a['statut'] == 'active',
      orElse: () => null,
    );
    return active?['id'] as int?;
  }

  Future<void> _chargerListe() async {
    setState(() => _chargement = true);
    try {
      final frais = await FraisScolaireService.getFrais(
        classeId: _filtreClasseId,
        anneeScolaireId: _filtreAnneeId,
        actif: _filtreActif,
      );
      setState(() {
        _frais = frais;
        _chargement = false;
      });
    } catch (e) {
      setState(() => _chargement = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _afficherErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: _rouge),
    );
  }

  void _afficherSucces(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: _vert),
    );
  }

  Future<void> _ouvrirFormulaire({FraisScolaire? frais}) async {
    final resultat = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FraisScolaireFormScreen(
          fraisExistant: frais,
          anneeScolaireParDefaut: _filtreAnneeId ?? _anneeParDefaut(),
        ),
      ),
    );
    if (resultat == true) _chargerListe();
  }

  Future<void> _confirmerDesactivation(FraisScolaire frais) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Désactiver ce frais ?'),
        content: Text(
          '"${frais.nom}" ne sera plus proposé aux nouveaux paiements, mais son historique reste conservé.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _rouge, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Désactiver'),
          ),
        ],
      ),
    );
    if (confirme != true) return;

    try {
      await FraisScolaireService.desactiverFrais(frais.id!);
      _afficherSucces('Frais "${frais.nom}" désactivé');
      _chargerListe();
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _ouvrirFormulaire(),
        backgroundColor: _indigo,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Nouveau frais',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _enTete(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _chargerListe,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _barreFiltres(),
                    const SizedBox(height: 16),
                    if (_chargement)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator(color: _indigo)),
                      )
                    else if (_frais.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text(
                            'Aucun frais scolaire trouvé',
                            style: GoogleFonts.inter(color: _texte),
                          ),
                        ),
                      )
                    else
                      ..._frais.map(_carteFrais),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // EN-TÊTE
  // ══════════════════════════════════════════════════════

  Widget _enTete() {
    final actifs = _frais.where((f) => f.actif).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_indigo, _teal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
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
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 4),
              Text(
                'Retour',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.8)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Frais Scolaires',
                    style: GoogleFonts.sora(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$actifs frais actif(s)',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.7)),
                  ),
                ],
              ),
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Text(
                  '${_frais.length}',
                  style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // FILTRES
  // ══════════════════════════════════════════════════════

  Widget _barreFiltres() {
    return Row(
      children: [
        Expanded(child: _dropdownGlass<int?>(
          valeur: _filtreClasseId,
          hint: 'Classe',
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('Toutes les classes')),
            ..._classes.map(
              (c) => DropdownMenuItem<int?>(value: c['id'] as int, child: Text(c['nom'] as String)),
            ),
          ],
          onChanged: (v) {
            setState(() => _filtreClasseId = v);
            _chargerListe();
          },
        )),
        const SizedBox(width: 8),
        Expanded(child: _dropdownGlass<int?>(
          valeur: _filtreAnneeId,
          hint: 'Année',
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('Toutes')),
            ..._annees.map(
              (a) => DropdownMenuItem<int?>(value: a['id'] as int, child: Text(a['libelle'] as String)),
            ),
          ],
          onChanged: (v) {
            setState(() => _filtreAnneeId = v);
            _chargerListe();
          },
        )),
        const SizedBox(width: 8),
        Expanded(child: _dropdownGlass<bool?>(
          valeur: _filtreActif,
          hint: 'Statut',
          items: const [
            DropdownMenuItem<bool?>(value: null, child: Text('Tous')),
            DropdownMenuItem<bool?>(value: true, child: Text('Actifs')),
            DropdownMenuItem<bool?>(value: false, child: Text('Inactifs')),
          ],
          onChanged: (v) {
            setState(() => _filtreActif = v);
            _chargerListe();
          },
        )),
      ],
    );
  }

  Widget _dropdownGlass<T>({
    required T valeur,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(50),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: valeur,
              isDense: true,
              isExpanded: true,
              icon: const Icon(Icons.expand_more, size: 16),
              hint: Text(hint, style: GoogleFonts.inter(fontSize: 12, color: _texte)),
              style: GoogleFonts.inter(fontSize: 12, color: _texte),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // CARTE FRAIS
  // ══════════════════════════════════════════════════════

  Widget _carteFrais(FraisScolaire frais) {
    final couleur = frais.actif ? _indigo : _gris;
    final classeLabel = frais.classeNom ?? 'Toutes classes';

    return GestureDetector(
      onTap: () => _ouvrirFormulaire(frais: frais),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(14),
              border: Border(left: BorderSide(color: couleur, width: 4)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            frais.nom,
                            style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: _texteFonce),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.class_outlined, size: 13, color: _gris),
                              const SizedBox(width: 4),
                              Text(classeLabel, style: GoogleFonts.inter(fontSize: 12, color: _texte)),
                              if (frais.serie != null) ...[
                                const SizedBox(width: 4),
                                Text('(${frais.serie})', style: GoogleFonts.inter(fontSize: 12, color: _gris)),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatMontant(frais.montant),
                      style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.w700, color: couleur),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: _gris, size: 20),
                      onSelected: (valeur) {
                        if (valeur == 'modifier') {
                          _ouvrirFormulaire(frais: frais);
                        } else if (valeur == 'desactiver') {
                          _confirmerDesactivation(frais);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'modifier', child: Text('Modifier')),
                        if (frais.actif)
                          const PopupMenuItem(value: 'desactiver', child: Text('Désactiver')),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.event, size: 13, color: _gris),
                    const SizedBox(width: 4),
                    Text(
                      'Échéance : ${_formatDateCourt(frais.dateLimite)}',
                      style: GoogleFonts.inter(fontSize: 12, color: _texte),
                    ),
                    const Spacer(),
                    _badge(
                      frais.obligatoire ? 'Obligatoire' : 'Facultatif',
                      frais.obligatoire ? _ambre : _teal,
                    ),
                    const SizedBox(width: 6),
                    _badge(frais.actif ? 'Actif' : 'Inactif', frais.actif ? _vert : _gris),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color couleur) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: couleur),
      ),
    );
  }
}
