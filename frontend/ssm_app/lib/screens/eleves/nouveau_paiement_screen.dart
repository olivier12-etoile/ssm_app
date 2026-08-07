import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/frais_scolaire_model.dart';
import '../../models/paiement_model.dart';
import '../../services/frais_scolaire_service.dart';
import '../../services/paiement_service.dart';
import '../../widgets/recu_pdf_viewer.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _teal = Color(0xFF0D9488);
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
  return '$buffer FCFA';
}

class NouveauPaiementScreen extends StatefulWidget {
  final int eleveId;
  final String eleveNomComplet;
  final int classeId;
  final int anneeScolaireId;
  final SituationFinanciere situation;
  final int? fraisScolaireIdPreselectionne;

  const NouveauPaiementScreen({
    super.key,
    required this.eleveId,
    required this.eleveNomComplet,
    required this.classeId,
    required this.anneeScolaireId,
    required this.situation,
    this.fraisScolaireIdPreselectionne,
  });

  @override
  State<NouveauPaiementScreen> createState() => _NouveauPaiementScreenState();
}

class _NouveauPaiementScreenState extends State<NouveauPaiementScreen> {
  List<FraisScolaire> _frais = [];
  FraisScolaire? _fraisSelectionne;
  EcheanceFrais? _echeanceSelectionnee;
  ModePaiement _modePaiement = ModePaiement.especes;
  DateTime _date = DateTime.now();

  final _montantController = TextEditingController();
  final _referenceController = TextEditingController();
  final _observationController = TextEditingController();

  bool _chargement = true;
  bool _enregistrement = false;
  String? _erreur;
  Paiement? _paiementEnregistre;

  @override
  void initState() {
    super.initState();
    _chargerFrais();
  }

  @override
  void dispose() {
    _montantController.dispose();
    _referenceController.dispose();
    _observationController.dispose();
    super.dispose();
  }

  Future<void> _chargerFrais() async {
    try {
      final frais = await FraisScolaireService.getFrais(
        classeId: widget.classeId,
        anneeScolaireId: widget.anneeScolaireId,
        actif: true,
      );
      // On ne propose que les frais qui ont encore un reste à payer.
      final fraisAvecReste = frais.where((f) {
        final detail = widget.situation.detailPourFrais(f.id ?? -1);
        return detail == null || detail.reste > 0;
      }).toList();

      setState(() {
        _frais = fraisAvecReste;
        _chargement = false;
        if (widget.fraisScolaireIdPreselectionne != null) {
          _fraisSelectionne = fraisAvecReste.firstWhere(
            (f) => f.id == widget.fraisScolaireIdPreselectionne,
            orElse: () => fraisAvecReste.isNotEmpty ? fraisAvecReste.first : _fraisSelectionne!,
          );
          _recalculerMontant();
        }
      });
    } catch (e) {
      setState(() {
        _chargement = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  double _resteDuFrais(FraisScolaire frais) {
    final detail = widget.situation.detailPourFrais(frais.id ?? -1);
    return detail?.reste ?? frais.montant;
  }

  void _recalculerMontant() {
    if (_fraisSelectionne == null) {
      _montantController.text = '';
      return;
    }
    final reste = _resteDuFrais(_fraisSelectionne!);
    final suggestion = _echeanceSelectionnee?.montant ?? reste;
    final montant = suggestion > reste ? reste : suggestion;
    _montantController.text = montant > 0 ? montant.toStringAsFixed(0) : '0';
  }

  Future<void> _enregistrer() async {
    setState(() => _erreur = null);

    if (_fraisSelectionne == null) {
      setState(() => _erreur = 'Veuillez sélectionner un frais scolaire.');
      return;
    }

    final montant = double.tryParse(_montantController.text.replaceAll(',', '.'));
    if (montant == null || montant <= 0) {
      setState(() => _erreur = 'Le montant doit être supérieur à 0.');
      return;
    }

    final reste = _resteDuFrais(_fraisSelectionne!);
    if (montant > reste + 0.01) {
      setState(() => _erreur = 'Le montant dépasse le reste à payer (${_formatMontant(reste)}).');
      return;
    }

    setState(() => _enregistrement = true);

    final paiement = Paiement(
      eleveId: widget.eleveId,
      fraisScolaireId: _fraisSelectionne!.id!,
      echeanceId: _echeanceSelectionnee?.id,
      montant: montant,
      modePaiement: _modePaiement,
      reference: _referenceController.text.trim().isEmpty ? null : _referenceController.text.trim(),
      datePaiement: _date,
      observation: _observationController.text.trim().isEmpty ? null : _observationController.text.trim(),
    );

    try {
      final enregistre = await PaiementService.enregistrerPaiement(paiement);
      if (!mounted) return;
      setState(() {
        _paiementEnregistre = enregistre;
        _enregistrement = false;
      });
    } catch (e) {
      setState(() {
        _enregistrement = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _reinitialiserFormulaire() {
    setState(() {
      _paiementEnregistre = null;
      _fraisSelectionne = null;
      _echeanceSelectionnee = null;
      _modePaiement = ModePaiement.especes;
      _date = DateTime.now();
      _montantController.clear();
      _referenceController.clear();
      _observationController.clear();
      _erreur = null;
    });
    _chargerFrais();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
        title: Text('Nouveau paiement', style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
      ),
      body: _paiementEnregistre != null
          ? _vueConfirmation(_paiementEnregistre!)
          : _chargement
              ? const Center(child: CircularProgressIndicator(color: _indigo))
              : _vueFormulaire(),
    );
  }

  // ══════════════════════════════════════════════════════
  // FORMULAIRE
  // ══════════════════════════════════════════════════════

  Widget _vueFormulaire() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          widget.eleveNomComplet,
          style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: _texteFonce),
        ),
        const SizedBox(height: 4),
        Text(
          'Reste à payer global : ${_formatMontant(widget.situation.resteAPayer)}',
          style: GoogleFonts.jetBrainsMono(fontSize: 13, color: _texte),
        ),
        const SizedBox(height: 20),
        _titreSection('Frais scolaire'),
        if (_frais.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _vert.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: _vert, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tous les frais applicables sont déjà soldés.',
                    style: GoogleFonts.inter(fontSize: 13, color: _vert),
                  ),
                ),
              ],
            ),
          )
        else
          DropdownButtonFormField<FraisScolaire>(
            initialValue: _fraisSelectionne,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Frais concerné *',
              prefixIcon: Icon(Icons.category_outlined),
              border: OutlineInputBorder(),
            ),
            hint: const Text('Choisir un frais'),
            items: _frais.map((f) {
              return DropdownMenuItem<FraisScolaire>(
                value: f,
                child: Text('${f.nom} — reste ${_formatMontant(_resteDuFrais(f))}'),
              );
            }).toList(),
            onChanged: (v) => setState(() {
              _fraisSelectionne = v;
              _echeanceSelectionnee = null;
              _recalculerMontant();
            }),
          ),
        if (_fraisSelectionne != null && _fraisSelectionne!.echeances.isNotEmpty) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<EcheanceFrais?>(
            initialValue: _echeanceSelectionnee,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Échéance',
              prefixIcon: Icon(Icons.layers_outlined),
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<EcheanceFrais?>(
                value: null,
                child: Text('Paiement complet du reste'),
              ),
              ..._fraisSelectionne!.echeances.map((e) {
                return DropdownMenuItem<EcheanceFrais?>(
                  value: e,
                  child: Text('${e.libelle} (${_formatMontant(e.montant)})'),
                );
              }),
            ],
            onChanged: (v) => setState(() {
              _echeanceSelectionnee = v;
              _recalculerMontant();
            }),
          ),
        ],
        const SizedBox(height: 20),
        _titreSection('Montant'),
        TextField(
          controller: _montantController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.w600),
          decoration: const InputDecoration(
            labelText: 'Montant à payer (FCFA) *',
            prefixIcon: Icon(Icons.payments_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        _titreSection('Mode de paiement'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ModePaiement.values.map((mode) {
            final selectionne = _modePaiement == mode;
            return ChoiceChip(
              selected: selectionne,
              onSelected: (_) => setState(() => _modePaiement = mode),
              avatar: Icon(mode.icone, size: 16, color: selectionne ? Colors.white : _indigo),
              label: Text(mode.libelle),
              labelStyle: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selectionne ? Colors.white : _texte,
              ),
              selectedColor: _indigo,
              backgroundColor: const Color(0xFFF1F5F9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
            );
          }).toList(),
        ),
        if (_modePaiement != ModePaiement.especes) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _referenceController,
            style: GoogleFonts.inter(fontSize: 14),
            decoration: const InputDecoration(
              labelText: 'Référence (optionnel)',
              prefixIcon: Icon(Icons.confirmation_number_outlined),
              border: OutlineInputBorder(),
            ),
          ),
        ],
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event, color: _indigo),
          title: const Text('Date du paiement *'),
          subtitle: Text(_formatDateCourt(_date)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final choisie = await showDatePicker(
              context: context,
              initialDate: _date,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (choisie != null) setState(() => _date = choisie);
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _observationController,
          maxLines: 2,
          style: GoogleFonts.inter(fontSize: 14),
          decoration: const InputDecoration(
            labelText: 'Observation (optionnel)',
            prefixIcon: Icon(Icons.notes),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        if (_erreur != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _rouge.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, color: _rouge, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_erreur!, style: GoogleFonts.inter(fontSize: 13, color: _rouge))),
              ],
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _indigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _frais.isEmpty || _enregistrement ? null : _enregistrer,
            child: _enregistrement
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Enregistrer le paiement'),
          ),
        ),
      ],
    );
  }

  Widget _titreSection(String titre) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(
        titre.toUpperCase(),
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _indigo, letterSpacing: 0.4),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // CONFIRMATION
  // ══════════════════════════════════════════════════════

  Widget _vueConfirmation(Paiement paiement) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: _vert.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle, color: _vert, size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              'Paiement enregistré',
              style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700, color: _texteFonce),
            ),
            const SizedBox(height: 8),
            Text(
              _formatMontant(paiement.montant),
              style: GoogleFonts.jetBrainsMono(fontSize: 24, fontWeight: FontWeight.w700, color: _vert),
            ),
            if (paiement.numeroRecu != null) ...[
              const SizedBox(height: 4),
              Text(
                'Reçu ${paiement.numeroRecu}',
                style: GoogleFonts.inter(fontSize: 13, color: _gris),
              ),
            ],
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: RecuPdfViewer(paiementId: paiement.id!, numeroRecu: paiement.numeroRecu),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _reinitialiserFormulaire,
                style: OutlinedButton.styleFrom(foregroundColor: _teal),
                icon: const Icon(Icons.add),
                label: Text('Nouveau paiement', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Terminer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
