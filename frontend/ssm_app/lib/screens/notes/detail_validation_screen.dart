import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/analyse_performance_model.dart';
import '../../services/validation_note_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/note_input_field.dart';
import '../../widgets/ssm/ssm_alert_item.dart';
import '../../widgets/ssm/ssm_panel.dart';
import '../../widgets/ssm/ssm_quick_action_button.dart';
import '../../widgets/ssm/ssm_sous_entete.dart';

String _formatValeur(double? v) {
  if (v == null) return '—';
  return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}

class DetailValidationScreen extends StatefulWidget {
  final int saisieId;

  const DetailValidationScreen({super.key, required this.saisieId});

  @override
  State<DetailValidationScreen> createState() => _DetailValidationScreenState();
}

class _DetailValidationScreenState extends State<DetailValidationScreen> {
  DetailSaisieValidation? _detail;
  bool _chargement = true;
  bool _actionEnCours = false;
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
      final detail = await ValidationNoteService.getDetailSaisie(widget.saisieId);
      setState(() {
        _detail = detail;
        _chargement = false;
      });
    } catch (e) {
      setState(() {
        _chargement = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _afficherErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: SSMPalette.rouge),
    );
  }

  Future<void> _confirmerValidation() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SSMPalette.blanc,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
        title: Text('Valider cette saisie ?', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
        content: Text(
          'Les notes seront verrouillées et ne pourront plus être modifiées par l\'enseignant sans déverrouillage explicite.',
          style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Annuler', style: GoogleFonts.inter(color: SSMPalette.texte2))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.teal, foregroundColor: Colors.white, elevation: 0),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Valider'),
          ),
        ],
      ),
    );

    if (confirme != true) return;

    setState(() => _actionEnCours = true);
    try {
      await ValidationNoteService.valider(widget.saisieId);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _actionEnCours = false);
    }
  }

  Future<void> _demanderRejet() async {
    final motifController = TextEditingController();

    final motif = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SSMPalette.blanc,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
        title: Text('Rejeter cette saisie', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "L'enseignant devra corriger et resoumettre ses notes.",
              style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: motifController,
              autofocus: true,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Motif du rejet *',
                labelStyle: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2),
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
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler', style: GoogleFonts.inter(color: SSMPalette.texte2))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.rouge, foregroundColor: Colors.white, elevation: 0),
            onPressed: () {
              if (motifController.text.trim().isEmpty) return;
              Navigator.pop(context, motifController.text.trim());
            },
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );

    if (motif == null || motif.isEmpty) return;

    setState(() => _actionEnCours = true);
    try {
      await ValidationNoteService.rejeter(widget.saisieId, motif);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _actionEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SSMPalette.fond,
      body: SafeArea(
        child: _chargement
            ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
            : _erreur != null
                ? _vueErreur()
                : Column(
                    children: [
                      _entete(),
                      if (_detail!.statistiques.anomalies.isNotEmpty) _banniereAnomalies(),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          children: [
                            SSMPanel(titre: 'Statistiques', child: _cartesStats()),
                            const SizedBox(height: 16),
                            SSMPanel(
                              titre: 'Notes des élèves',
                              padding: EdgeInsets.zero,
                              child: _tableauNotes(),
                            ),
                          ],
                        ),
                      ),
                      _barreActions(),
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
            Icon(Icons.error_outline, color: SSMPalette.rouge, size: 40),
            const SizedBox(height: 12),
            Text(_erreur!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: SSMPalette.texte2)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _charger,
              style: ElevatedButton.styleFrom(backgroundColor: SSMPalette.indigo, foregroundColor: Colors.white, elevation: 0),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // EN-TÊTE
  // ══════════════════════════════════════════════════════

  Widget _entete() {
    final saisie = _detail!.saisie;
    return SSMSousEnTete(
      titre: saisie.classeNom ?? 'Classe',
      sousTitre: '${saisie.matiereNom ?? ''} · ${saisie.periodeNom ?? ''}',
      onRetour: () => Navigator.pop(context),
      complement: Row(
        children: [
          Icon(Icons.person_outline, size: 12, color: SSMPalette.texte3),
          const SizedBox(width: 4),
          Text(_detail!.enseignantNom, style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte3)),
        ],
      ),
    );
  }

  Widget _banniereAnomalies() {
    final critique = _detail!.statistiques.aDesAnomaliesCritiques;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: SSMAlertItem(
        type: critique ? SSMAlerteType.danger : SSMAlerteType.avertissement,
        icone: Icons.warning_amber_rounded,
        titre: 'Anomalies détectées',
        sousTitre: _detail!.statistiques.anomalies.join('\n'),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // STATS
  // ══════════════════════════════════════════════════════

  Widget _cartesStats() {
    final s = _detail!.statistiques;
    return Row(
      children: [
        Expanded(child: _colonneStat('Moyenne', _formatValeur(s.moyenne), SSMPalette.indigo)),
        Expanded(child: _colonneStat('Meilleure', _formatValeur(s.meilleureNote), SSMPalette.teal)),
        Expanded(child: _colonneStat('Plus faible', _formatValeur(s.plusFaibleNote), SSMPalette.rouge)),
        Expanded(child: _colonneStat('Réussite', '${s.tauxReussite.toStringAsFixed(0)}%', SSMPalette.teal)),
      ],
    );
  }

  Widget _colonneStat(String label, String valeur, Color couleur) {
    return Column(
      children: [
        Text(valeur, style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.w700, color: couleur)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: SSMPalette.texte3)),
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  // TABLEAU DES NOTES (lecture seule)
  // ══════════════════════════════════════════════════════

  Widget _tableauNotes() {
    if (_detail!.eleves.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Aucune note saisie', style: GoogleFonts.inter(color: SSMPalette.texte3)),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Expanded(flex: 3, child: Text('Élève', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: SSMPalette.texte3))),
              Expanded(child: Text('Devoir', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: SSMPalette.texte3))),
              Expanded(child: Text('Composition', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: SSMPalette.texte3))),
            ],
          ),
        ),
        const Divider(height: 1, color: SSMPalette.bordure),
        ..._detail!.eleves.map((eleve) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      eleve.nomComplet,
                      style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte1),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: NoteInputField(
                        controller: TextEditingController(text: _formatValeur(eleve.noteDevoir?.valeur)),
                        lectureSeule: true,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: NoteInputField(
                        controller: TextEditingController(text: _formatValeur(eleve.noteComposition?.valeur)),
                        lectureSeule: true,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  // ACTIONS
  // ══════════════════════════════════════════════════════

  Widget _barreActions() {
    return Container(
      width: double.infinity,
      color: SSMPalette.blanc,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: SSMPalette.bordure))),
      child: _actionEnCours
          ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
          : Row(
              children: [
                Expanded(
                  child: SSMQuickActionButton(
                    icone: Icons.close,
                    label: 'Rejeter',
                    variante: SSMActionVariante.rouge,
                    onTap: _demanderRejet,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SSMQuickActionButton(
                    icone: Icons.check,
                    label: 'Valider',
                    variante: SSMActionVariante.teal,
                    onTap: _confirmerValidation,
                  ),
                ),
              ],
            ),
    );
  }
}
