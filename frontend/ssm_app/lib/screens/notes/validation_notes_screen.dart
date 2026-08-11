import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/analyse_performance_model.dart';
import '../../services/validation_note_service.dart';
import 'detail_validation_screen.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _teal = Color(0xFF0D9488);
const Color _ambre = Color(0xFFD97706);
const Color _vert = Color(0xFF16A34A);
const Color _rouge = Color(0xFFDC2626);
const Color _gris = Color(0xFF94A3B8);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);

String _formatDateCourt(DateTime? d) =>
    d == null ? '—' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class ValidationNotesScreen extends StatefulWidget {
  const ValidationNotesScreen({super.key});

  @override
  State<ValidationNotesScreen> createState() => _ValidationNotesScreenState();
}

class _ValidationNotesScreenState extends State<ValidationNotesScreen> {
  List<SaisieEnAttenteValidation> _saisies = [];
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final saisies = await ValidationNoteService.getEnAttente();
      setState(() {
        _saisies = saisies;
        _chargement = false;
      });
    } catch (e) {
      setState(() {
        _chargement = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _ouvrirDetail(SaisieEnAttenteValidation saisie) async {
    final resultat = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => DetailValidationScreen(saisieId: saisie.id)),
    );
    if (resultat == true) _charger();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _enTete(),
            Expanded(
              child: _chargement
                  ? const Center(child: CircularProgressIndicator(color: _indigo))
                  : _erreur != null
                      ? _vueErreur()
                      : RefreshIndicator(
                          onRefresh: _charger,
                          child: _saisies.isEmpty
                              ? ListView(
                                  padding: const EdgeInsets.all(40),
                                  children: [
                                    const Icon(Icons.check_circle_outline, size: 56, color: _vert),
                                    const SizedBox(height: 12),
                                    Center(
                                      child: Text(
                                        'Aucune saisie en attente de validation',
                                        style: GoogleFonts.inter(color: _texte),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                  itemCount: _saisies.length,
                                  itemBuilder: (context, index) => _carteSaisie(_saisies[index]),
                                ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vueErreur() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: _rouge, size: 40),
            const SizedBox(height: 12),
            Text(_erreur!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: _texte)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _charger,
              style: ElevatedButton.styleFrom(backgroundColor: _indigo, foregroundColor: Colors.white),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _enTete() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_indigo, _teal], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Validation des notes', style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                Text(
                  '${_saisies.length} saisie(s) en attente',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.75)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _carteSaisie(SaisieEnAttenteValidation saisie) {
    final aDesAnomalies = saisie.nombreAnomalies > 0;

    return GestureDetector(
      onTap: () => _ouvrirDetail(saisie),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(14),
              border: Border(left: BorderSide(color: aDesAnomalies ? _ambre : _indigo, width: 4)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
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
                            saisie.classeNom,
                            style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: _texteFonce),
                          ),
                          const SizedBox(height: 2),
                          Text(saisie.matiereNom, style: GoogleFonts.inter(fontSize: 12, color: _texte)),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.person_outline, size: 12, color: _gris),
                              const SizedBox(width: 4),
                              Text(saisie.enseignantNom, style: GoogleFonts.inter(fontSize: 11, color: _gris)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (aDesAnomalies) _badge('${saisie.nombreAnomalies} anomalie(s)', _ambre),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Soumis le ${_formatDateCourt(saisie.dateSoumission)}',
                      style: GoogleFonts.inter(fontSize: 11, color: _gris),
                    ),
                    Text(
                      saisie.moyenneClasse != null ? 'Moyenne : ${saisie.moyenneClasse!.toStringAsFixed(2)}/20' : 'Moyenne : —',
                      style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: _indigo),
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

  Widget _badge(String label, Color couleur) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: couleur.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: couleur)),
    );
  }
}
