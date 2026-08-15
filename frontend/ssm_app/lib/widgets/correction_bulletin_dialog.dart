import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/bulletin_model.dart';
import '../models/historique_statistique_bulletin_model.dart';
import '../services/historique_statistique_bulletin_service.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _ambre = Color(0xFFD97706);
const Color _rouge = Color(0xFFDC2626);
const Color _gris = Color(0xFF94A3B8);
const Color _texte = Color(0xFF334155);
const Color _texteFonce = Color(0xFF0F172A);

enum _ChampCorrigeable {
  decisionConseil('decision_conseil', 'Décision du conseil'),
  appreciationGenerale('appreciation_generale', 'Appréciation générale'),
  absencesJustifiees('absences_justifiees', 'Absences justifiées'),
  absencesNonJustifiees('absences_non_justifiees', 'Absences non justifiées'),
  retards('retards', 'Retards'),
  noteMatiere('note', "Note d'une matière");

  final String valeurApi;
  final String libelle;
  const _ChampCorrigeable(this.valeurApi, this.libelle);
}

String _libelleChampHistorique(String champApi) {
  for (final c in _ChampCorrigeable.values) {
    if (c.valeurApi == champApi) return c.libelle;
  }
  return champApi;
}

String _formatDate(DateTime? d) {
  if (d == null) return '—';
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} à '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

// Ouvre le dialog de correction d'un bulletin déjà validé (le backend
// n'accepte les corrections que sur statut = valide, voir
// CorrectionBulletinController). Retourne le bulletin mis à jour si une
// correction a été enregistrée, sinon null.
Future<Bulletin?> showCorrectionBulletinDialog(BuildContext context, Bulletin bulletin) {
  return showDialog<Bulletin>(
    context: context,
    builder: (context) => CorrectionBulletinDialog(bulletin: bulletin),
  );
}

class CorrectionBulletinDialog extends StatefulWidget {
  final Bulletin bulletin;

  const CorrectionBulletinDialog({super.key, required this.bulletin});

  @override
  State<CorrectionBulletinDialog> createState() => _CorrectionBulletinDialogState();
}

class _CorrectionBulletinDialogState extends State<CorrectionBulletinDialog> {
  _ChampCorrigeable? _champ;
  BulletinDetail? _matiere;
  DecisionConseil? _decisionChoisie;

  final _texteController = TextEditingController();
  final _nombreController = TextEditingController();
  final _motifController = TextEditingController();

  bool _envoiEnCours = false;

  List<CorrectionBulletin> _historique = [];
  bool _chargementHistorique = true;

  bool get _aDesMatieres => widget.bulletin.details.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _decisionChoisie = widget.bulletin.decisionConseil;
    _chargerHistorique();
  }

  @override
  void dispose() {
    _texteController.dispose();
    _nombreController.dispose();
    _motifController.dispose();
    super.dispose();
  }

  Future<void> _chargerHistorique() async {
    try {
      final historique = await HistoriqueStatistiqueBulletinService.getHistoriqueCorrections(widget.bulletin.id);
      if (!mounted) return;
      setState(() {
        _historique = historique;
        _chargementHistorique = false;
      });
    } catch (_) {
      // Non bloquant : la correction reste possible même si l'historique ne charge pas.
      if (mounted) setState(() => _chargementHistorique = false);
    }
  }

  void _changerChamp(_ChampCorrigeable? champ) {
    setState(() {
      _champ = champ;
      _matiere = null;
      _texteController.clear();
      _nombreController.clear();
      if (champ == _ChampCorrigeable.appreciationGenerale) {
        _texteController.text = widget.bulletin.appreciationGenerale ?? '';
      } else if (champ == _ChampCorrigeable.absencesJustifiees) {
        _nombreController.text = '${widget.bulletin.absencesJustifiees}';
      } else if (champ == _ChampCorrigeable.absencesNonJustifiees) {
        _nombreController.text = '${widget.bulletin.absencesNonJustifiees}';
      } else if (champ == _ChampCorrigeable.retards) {
        _nombreController.text = '${widget.bulletin.retards}';
      }
    });
  }

  void _changerMatiere(BulletinDetail? detail) {
    setState(() {
      _matiere = detail;
      _nombreController.text = detail != null ? detail.note.toStringAsFixed(2) : '';
    });
  }

  String _ancienneValeur() {
    switch (_champ) {
      case _ChampCorrigeable.decisionConseil:
        return widget.bulletin.decisionConseil?.libelle ?? '—';
      case _ChampCorrigeable.appreciationGenerale:
        return widget.bulletin.appreciationGenerale?.isNotEmpty == true ? widget.bulletin.appreciationGenerale! : '—';
      case _ChampCorrigeable.absencesJustifiees:
        return '${widget.bulletin.absencesJustifiees}';
      case _ChampCorrigeable.absencesNonJustifiees:
        return '${widget.bulletin.absencesNonJustifiees}';
      case _ChampCorrigeable.retards:
        return '${widget.bulletin.retards}';
      case _ChampCorrigeable.noteMatiere:
        return _matiere != null ? '${_matiere!.note.toStringAsFixed(2)}/20' : '—';
      case null:
        return '—';
    }
  }

  Future<void> _confirmer() async {
    final champ = _champ;
    if (champ == null) {
      _afficherErreur('Sélectionnez le champ à corriger.');
      return;
    }
    if (champ == _ChampCorrigeable.noteMatiere && _matiere == null) {
      _afficherErreur('Sélectionnez la matière concernée.');
      return;
    }
    final motif = _motifController.text.trim();
    if (motif.isEmpty) {
      _afficherErreur('Le motif de la correction est obligatoire.');
      return;
    }

    dynamic nouvelleValeur;
    switch (champ) {
      case _ChampCorrigeable.decisionConseil:
        if (_decisionChoisie == null) {
          _afficherErreur('Sélectionnez la nouvelle décision du conseil.');
          return;
        }
        nouvelleValeur = _decisionChoisie!.valeurApi;
        break;
      case _ChampCorrigeable.appreciationGenerale:
        final texte = _texteController.text.trim();
        if (texte.isEmpty) {
          _afficherErreur("La nouvelle appréciation ne peut pas être vide.");
          return;
        }
        nouvelleValeur = texte;
        break;
      case _ChampCorrigeable.absencesJustifiees:
      case _ChampCorrigeable.absencesNonJustifiees:
      case _ChampCorrigeable.retards:
        final entier = int.tryParse(_nombreController.text.trim());
        if (entier == null || entier < 0) {
          _afficherErreur('Entrez un entier positif ou nul.');
          return;
        }
        nouvelleValeur = entier;
        break;
      case _ChampCorrigeable.noteMatiere:
        final note = double.tryParse(_nombreController.text.trim().replaceAll(',', '.'));
        if (note == null || note < 0 || note > 20) {
          _afficherErreur('Entrez une note entre 0 et 20.');
          return;
        }
        nouvelleValeur = note;
        break;
    }

    setState(() => _envoiEnCours = true);
    try {
      final maj = await HistoriqueStatistiqueBulletinService.demanderCorrection(
        bulletinId: widget.bulletin.id,
        bulletinDetailId: champ == _ChampCorrigeable.noteMatiere ? _matiere!.id : null,
        champModifie: champ.valeurApi,
        nouvelleValeur: nouvelleValeur,
        motif: motif,
      );
      if (mounted) Navigator.pop(context, maj);
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _envoiEnCours = false);
    }
  }

  void _afficherErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: _rouge));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Demander une correction',
                        style: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w700, color: _texteFonce)),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<_ChampCorrigeable>(
                        value: _champ,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Champ à corriger', border: OutlineInputBorder(), isDense: true),
                        hint: const Text('Choisir un champ'),
                        items: [
                          for (final c in _ChampCorrigeable.values)
                            if (c != _ChampCorrigeable.noteMatiere || _aDesMatieres)
                              DropdownMenuItem(value: c, child: Text(c.libelle)),
                        ],
                        onChanged: _changerChamp,
                      ),
                      if (_champ == _ChampCorrigeable.noteMatiere) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<BulletinDetail>(
                          value: _matiere,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Matière', border: OutlineInputBorder(), isDense: true),
                          hint: const Text('Choisir une matière'),
                          items: widget.bulletin.details
                              .map((d) => DropdownMenuItem(value: d, child: Text(d.nomMatiere)))
                              .toList(),
                          onChanged: _changerMatiere,
                        ),
                      ],
                      if (_champ != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(color: _gris.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              Text('Valeur actuelle : ', style: GoogleFonts.inter(fontSize: 12, color: _texte)),
                              Text(_ancienneValeur(),
                                  style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: _texteFonce)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _champSaisieNouvelleValeur(),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: _motifController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Motif de la correction *',
                          hintText: 'Obligatoire — ex: erreur de saisie initiale',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _ambre.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _ambre.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: _ambre, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Cette correction sera enregistrée dans l\'historique et recalculera automatiquement la moyenne et le rang si nécessaire.',
                                style: GoogleFonts.inter(fontSize: 11, color: _texte),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _envoiEnCours ? null : _confirmer,
                          style: ElevatedButton.styleFrom(backgroundColor: _indigo, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                          child: _envoiEnCours
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Confirmer la correction'),
                        ),
                      ),
                      if (_historique.isNotEmpty || _chargementHistorique) ...[
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text('Historique des corrections', style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: _texteFonce)),
                        const SizedBox(height: 8),
                        if (_chargementHistorique)
                          const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)))
                        else
                          ..._historique.map(_ligneHistorique),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _champSaisieNouvelleValeur() {
    switch (_champ!) {
      case _ChampCorrigeable.decisionConseil:
        return DropdownButtonFormField<DecisionConseil>(
          value: _decisionChoisie,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Nouvelle décision', border: OutlineInputBorder(), isDense: true),
          items: DecisionConseil.values.map((d) => DropdownMenuItem(value: d, child: Text(d.libelle))).toList(),
          onChanged: (v) => setState(() => _decisionChoisie = v),
        );
      case _ChampCorrigeable.appreciationGenerale:
        return TextField(
          controller: _texteController,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Nouvelle appréciation', border: OutlineInputBorder(), alignLabelWithHint: true),
        );
      case _ChampCorrigeable.absencesJustifiees:
      case _ChampCorrigeable.absencesNonJustifiees:
      case _ChampCorrigeable.retards:
        return TextField(
          controller: _nombreController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Nouvelle valeur', border: OutlineInputBorder(), isDense: true),
        );
      case _ChampCorrigeable.noteMatiere:
        return TextField(
          controller: _nombreController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: GoogleFonts.jetBrainsMono(),
          decoration: const InputDecoration(labelText: 'Nouvelle note (/20)', border: OutlineInputBorder(), isDense: true),
        );
    }
  }

  Widget _ligneHistorique(CorrectionBulletin c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: _gris.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_libelleChampHistorique(c.champModifie), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _texteFonce)),
          const SizedBox(height: 2),
          Text('${c.ancienneValeur ?? '—'} → ${c.nouvelleValeur ?? '—'}',
              style: GoogleFonts.jetBrainsMono(fontSize: 11, color: _texte)),
          const SizedBox(height: 2),
          Text('Motif : ${c.motif}', style: GoogleFonts.inter(fontSize: 11, color: _texte, fontStyle: FontStyle.italic)),
          const SizedBox(height: 2),
          Text('Par ${c.demandePar} · ${_formatDate(c.createdAt)}', style: GoogleFonts.inter(fontSize: 10, color: _gris)),
        ],
      ),
    );
  }
}
