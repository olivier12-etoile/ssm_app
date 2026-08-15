import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/caisse_model.dart';
import '../models/paiement_model.dart';
import '../services/caisse_service.dart';
import '../theme/ssm_theme.dart';

String _formatMontant(double m) {
  final entier = m.round();
  final signe = entier < 0 ? '-' : '';
  final texte = entier.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < texte.length; i++) {
    if (i > 0 && (texte.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(texte[i]);
  }
  return '$signe$buffer FCFA';
}

String _formatDateCourt(DateTime? d) => d == null
    ? '—'
    : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

InputDecoration _decorationChamp(String label, {String? hintText, String? suffixText}) {
  return InputDecoration(
    labelText: label,
    hintText: hintText,
    suffixText: suffixText,
    labelStyle: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2),
    hintStyle: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte3),
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
  );
}

// Dialog de correction d'un paiement — réservé au directeur.
// Affiche montant/mode actuels en lecture seule, permet de saisir un
// nouveau montant et/ou un nouveau mode de paiement, exige un motif, et
// affiche l'historique des corrections déjà appliquées à ce paiement.
class CorrectionPaiementDialog extends StatefulWidget {
  final Paiement paiement;

  const CorrectionPaiementDialog({super.key, required this.paiement});

  // Ouvre le dialog ; retourne true si une correction a été enregistrée.
  static Future<bool?> afficher(BuildContext context, Paiement paiement) {
    return showDialog<bool>(
      context: context,
      builder: (_) => CorrectionPaiementDialog(paiement: paiement),
    );
  }

  @override
  State<CorrectionPaiementDialog> createState() => _CorrectionPaiementDialogState();
}

class _CorrectionPaiementDialogState extends State<CorrectionPaiementDialog> {
  late final TextEditingController _montantController;
  final TextEditingController _motifController = TextEditingController();
  ModePaiement? _nouveauMode;

  List<Correction> _historique = [];
  bool _chargementHistorique = true;
  bool _envoiEnCours = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _montantController = TextEditingController(text: widget.paiement.montant.toStringAsFixed(0));
    _chargerHistorique();
  }

  @override
  void dispose() {
    _montantController.dispose();
    _motifController.dispose();
    super.dispose();
  }

  Future<void> _chargerHistorique() async {
    try {
      final historique = await CaisseService.getHistoriqueCorrections(widget.paiement.id!);
      if (!mounted) return;
      setState(() {
        _historique = historique;
        _chargementHistorique = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _chargementHistorique = false);
    }
  }

  Future<void> _confirmer() async {
    final motif = _motifController.text.trim();
    if (motif.isEmpty) {
      setState(() => _erreur = 'Le motif est obligatoire.');
      return;
    }

    final nouveauMontant = double.tryParse(_montantController.text.replaceAll(' ', '').replaceAll(',', '.'));
    if (nouveauMontant == null || nouveauMontant <= 0) {
      setState(() => _erreur = 'Montant invalide.');
      return;
    }

    final montantInchange = (nouveauMontant - widget.paiement.montant).abs() < 0.01;
    final modeInchange = _nouveauMode == null || _nouveauMode == widget.paiement.modePaiement;

    if (montantInchange && modeInchange) {
      setState(() => _erreur = 'Modifiez le montant et/ou le mode de paiement avant de confirmer.');
      return;
    }

    setState(() {
      _envoiEnCours = true;
      _erreur = null;
    });

    try {
      await CaisseService.creerCorrection(
        paiementId: widget.paiement.id!,
        nouveauMontant: montantInchange ? null : nouveauMontant,
        nouveauModePaiement: modeInchange ? null : _nouveauMode!.valeurApi,
        motif: motif,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _envoiEnCours = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: SSMPalette.blanc,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.grand)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.edit_note, color: SSMPalette.indigo, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Corriger le paiement',
                        style: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Reçu ${widget.paiement.numeroRecu ?? '—'}',
                  style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte3),
                ),
                const SizedBox(height: 16),

                // ── Contexte actuel (lecture seule) ──
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(SSMRayons.moyen),
                    border: Border.all(color: SSMPalette.bordure),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Montant actuel', style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte3)),
                            const SizedBox(height: 2),
                            Text(
                              _formatMontant(widget.paiement.montant),
                              style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.w700, color: SSMPalette.texte1),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Mode actuel', style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte3)),
                            const SizedBox(height: 2),
                            Text(
                              widget.paiement.modePaiement.libelle,
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: SSMPalette.texte1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _montantController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.w600, color: SSMPalette.texte1),
                  decoration: _decorationChamp('Nouveau montant', suffixText: 'FCFA'),
                ),
                const SizedBox(height: 14),

                DropdownButtonFormField<ModePaiement?>(
                  initialValue: _nouveauMode,
                  isExpanded: true,
                  decoration: _decorationChamp('Nouveau mode de paiement (optionnel)'),
                  hint: Text(
                    'Garder « ${widget.paiement.modePaiement.libelle} »',
                    style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte3),
                  ),
                  items: ModePaiement.values
                      .map((m) => DropdownMenuItem(value: m, child: Text(m.libelle, style: GoogleFonts.inter(fontSize: 14))))
                      .toList(),
                  onChanged: (valeur) => setState(() => _nouveauMode = valeur),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: _motifController,
                  maxLines: 3,
                  style: GoogleFonts.inter(fontSize: 14, color: SSMPalette.texte1),
                  decoration: _decorationChamp('Motif de la correction *', hintText: 'Expliquez la raison de cette correction…'),
                ),
                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: SSMPalette.ambreClair,
                    borderRadius: BorderRadius.circular(SSMRayons.moyen),
                    border: Border.all(color: SSMPalette.ambre.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: SSMPalette.ambre, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Cette action sera tracée et visible dans l\'historique.',
                          style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.ambre, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),

                if (_erreur != null) ...[
                  const SizedBox(height: 10),
                  Text(_erreur!, style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.rouge)),
                ],

                const SizedBox(height: 16),

                if (_chargementHistorique)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: SSMPalette.indigo)),
                    ),
                  )
                else if (_historique.isNotEmpty) ...[
                  Text(
                    'Corrections précédentes',
                    style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: SSMPalette.indigo),
                  ),
                  const SizedBox(height: 8),
                  ..._historique.map(_ligneHistorique),
                  const SizedBox(height: 8),
                ],

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _envoiEnCours ? null : () => Navigator.pop(context),
                      child: Text('Annuler', style: GoogleFonts.inter(color: SSMPalette.texte2)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _envoiEnCours ? null : _confirmer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SSMPalette.indigo,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
                      ),
                      child: _envoiEnCours
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Confirmer la correction'),
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

  Widget _ligneHistorique(Correction c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: SSMPalette.blanc,
        borderRadius: BorderRadius.circular(SSMRayons.petit),
        border: Border.all(color: SSMPalette.bordure),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_formatMontant(c.ancienMontant)} → ${_formatMontant(c.nouveauMontant)}',
                  style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w600, color: SSMPalette.texte1),
                ),
              ),
              Text(_formatDateCourt(c.createdAt), style: GoogleFonts.inter(fontSize: 10, color: SSMPalette.texte3)),
            ],
          ),
          const SizedBox(height: 3),
          Text('Motif : ${c.motif}', style: GoogleFonts.inter(fontSize: 11, color: SSMPalette.texte2)),
          if (c.corrigeParNom != null) ...[
            const SizedBox(height: 2),
            Text('Par ${c.corrigeParNom}', style: GoogleFonts.inter(fontSize: 10, color: SSMPalette.texte3)),
          ],
        ],
      ),
    );
  }
}
