import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/frais_scolaire_model.dart';
import '../../services/frais_scolaire_service.dart';
import '../../services/classe_service.dart';
import '../../services/annee_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_sous_entete.dart';

String _formatDateCourt(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class _EcheanceEditable {
  final libelleController = TextEditingController();
  final montantController = TextEditingController();
  DateTime dateLimite;

  _EcheanceEditable({String? libelle, double? montant, DateTime? dateLimite})
      : dateLimite = dateLimite ?? DateTime.now() {
    if (libelle != null) libelleController.text = libelle;
    if (montant != null) montantController.text = _formatNombre(montant);
  }

  void dispose() {
    libelleController.dispose();
    montantController.dispose();
  }

  static String _formatNombre(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

class FraisScolaireFormScreen extends StatefulWidget {
  final FraisScolaire? fraisExistant;
  final int? anneeScolaireParDefaut;

  const FraisScolaireFormScreen({
    super.key,
    this.fraisExistant,
    this.anneeScolaireParDefaut,
  });

  @override
  State<FraisScolaireFormScreen> createState() => _FraisScolaireFormScreenState();
}

class _FraisScolaireFormScreenState extends State<FraisScolaireFormScreen> {
  final _nomController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _montantController = TextEditingController();
  final _serieController = TextEditingController();

  int? _classeId;
  int? _anneeScolaireId;
  DateTime _dateLimite = DateTime.now().add(const Duration(days: 30));
  bool _obligatoire = true;
  bool _actif = true;
  bool _paiementEnPlusieurs = false;
  final List<_EcheanceEditable> _echeances = [];

  List<dynamic> _classes = [];
  List<dynamic> _annees = [];

  bool _chargementReferences = true;
  bool _enregistrementEnCours = false;
  String? _erreur;

  bool get _modeEdition => widget.fraisExistant != null;

  double get _montant => double.tryParse(_montantController.text.replaceAll(',', '.')) ?? 0;

  double get _sommeEcheances => _echeances.fold(
        0,
        (total, e) => total + (double.tryParse(e.montantController.text.replaceAll(',', '.')) ?? 0),
      );

  bool get _echeancesValides {
    if (!_paiementEnPlusieurs) return true;
    if (_echeances.isEmpty) return false;
    for (final e in _echeances) {
      if (e.libelleController.text.trim().isEmpty) return false;
      if ((double.tryParse(e.montantController.text.replaceAll(',', '.')) ?? 0) <= 0) return false;
    }
    return (_sommeEcheances - _montant).abs() < 0.01;
  }

  @override
  void initState() {
    super.initState();
    _preRemplir();
    _chargerReferences();
  }

  void _preRemplir() {
    final frais = widget.fraisExistant;
    if (frais == null) {
      _anneeScolaireId = widget.anneeScolaireParDefaut;
      return;
    }

    _nomController.text = frais.nom;
    _descriptionController.text = frais.description ?? '';
    _montantController.text = frais.montant == frais.montant.roundToDouble()
        ? frais.montant.toInt().toString()
        : frais.montant.toString();
    _serieController.text = frais.serie ?? '';
    _classeId = frais.classeId;
    _anneeScolaireId = frais.anneeScolaireId;
    _dateLimite = frais.dateLimite;
    _obligatoire = frais.obligatoire;
    _actif = frais.actif;
    _paiementEnPlusieurs = frais.echeances.isNotEmpty;

    for (final e in frais.echeances) {
      _echeances.add(_EcheanceEditable(
        libelle: e.libelle,
        montant: e.montant,
        dateLimite: e.dateLimite,
      ));
    }
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
        _anneeScolaireId ??= _anneeParDefaut();
        _chargementReferences = false;
      });
    } catch (e) {
      setState(() => _chargementReferences = false);
    }
  }

  int? _anneeParDefaut() {
    if (_annees.isEmpty) return null;
    final active = _annees.firstWhere((a) => a['statut'] == 'active', orElse: () => null);
    return active?['id'] as int? ?? _annees.first['id'] as int?;
  }

  @override
  void dispose() {
    _nomController.dispose();
    _descriptionController.dispose();
    _montantController.dispose();
    _serieController.dispose();
    for (final e in _echeances) {
      e.dispose();
    }
    super.dispose();
  }

  void _ajouterEcheance() {
    setState(() {
      _echeances.add(_EcheanceEditable(
        libelle: 'Tranche ${_echeances.length + 1}',
        dateLimite: _dateLimite,
      ));
    });
  }

  void _supprimerEcheance(int index) {
    setState(() {
      _echeances[index].dispose();
      _echeances.removeAt(index);
    });
  }

  Future<void> _choisirDate({DateTime? initial, required ValueChanged<DateTime> onChoisi}) async {
    final choisie = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (choisie != null) onChoisi(choisie);
  }

  Future<void> _enregistrer() async {
    setState(() => _erreur = null);

    if (_nomController.text.trim().isEmpty) {
      setState(() => _erreur = 'Le nom du frais est obligatoire.');
      return;
    }
    if (_montant <= 0) {
      setState(() => _erreur = 'Le montant doit être supérieur à 0.');
      return;
    }
    if (_anneeScolaireId == null) {
      setState(() => _erreur = "Veuillez sélectionner l'année scolaire.");
      return;
    }
    if (_paiementEnPlusieurs && !_echeancesValides) {
      setState(() => _erreur =
          'La somme des tranches (${_sommeEcheances.toStringAsFixed(0)}) doit être égale au montant total (${_montant.toStringAsFixed(0)}).');
      return;
    }

    setState(() => _enregistrementEnCours = true);

    final frais = FraisScolaire(
      id: widget.fraisExistant?.id,
      nom: _nomController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      montant: _montant,
      classeId: _classeId,
      serie: _serieController.text.trim().isEmpty ? null : _serieController.text.trim(),
      anneeScolaireId: _anneeScolaireId!,
      dateLimite: _dateLimite,
      obligatoire: _obligatoire,
      actif: _actif,
      echeances: _paiementEnPlusieurs
          ? _echeances
              .asMap()
              .entries
              .map((entry) => EcheanceFrais(
                    libelle: entry.value.libelleController.text.trim(),
                    montant: double.parse(entry.value.montantController.text.replaceAll(',', '.')),
                    dateLimite: entry.value.dateLimite,
                    ordre: entry.key + 1,
                  ))
              .toList()
          : const [],
    );

    try {
      if (_modeEdition) {
        await FraisScolaireService.modifierFrais(widget.fraisExistant!.id!, frais);
      } else {
        await FraisScolaireService.creerFrais(frais);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _enregistrementEnCours = false;
        _erreur = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SSMPalette.fond,
      body: SafeArea(
        child: Column(
          children: [
            SSMSousEnTete(
              titre: _modeEdition ? 'Modifier le frais' : 'Nouveau frais',
              onRetour: () => Navigator.pop(context),
            ),
            Expanded(
              child: _chargementReferences
                  ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      children: [
                        _titreSection('Informations générales'),
                        _champTexte(controller: _nomController, label: 'Nom du frais *', icone: Icons.badge_outlined),
                        const SizedBox(height: 12),
                        _champTexte(
                          controller: _descriptionController,
                          label: 'Description',
                          icone: Icons.notes_outlined,
                          maxLignes: 2,
                        ),
                        const SizedBox(height: 12),
                        _champTexte(
                          controller: _montantController,
                          label: 'Montant total (FCFA) *',
                          icone: Icons.payments_outlined,
                          clavierNumerique: true,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int?>(
                          initialValue: _classeId,
                          isExpanded: true,
                          decoration: _decorationChamp('Classe concernée', icone: Icons.class_outlined),
                          items: [
                            const DropdownMenuItem<int?>(value: null, child: Text('Toutes les classes')),
                            ..._classes.map(
                              (c) => DropdownMenuItem<int?>(value: c['id'] as int, child: Text(c['nom'] as String)),
                            ),
                          ],
                          onChanged: (v) => setState(() => _classeId = v),
                        ),
                        const SizedBox(height: 12),
                        _champTexte(controller: _serieController, label: 'Série (optionnel)', icone: Icons.category_outlined),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          initialValue: _anneeScolaireId,
                          isExpanded: true,
                          decoration: _decorationChamp('Année scolaire *', icone: Icons.calendar_month_outlined),
                          items: _annees
                              .map((a) => DropdownMenuItem<int>(value: a['id'] as int, child: Text(a['libelle'] as String)))
                              .toList(),
                          onChanged: (v) => setState(() => _anneeScolaireId = v),
                        ),
                        const SizedBox(height: 12),
                        _ligneDate(
                          titre: 'Date limite *',
                          date: _dateLimite,
                          onTap: () => _choisirDate(initial: _dateLimite, onChoisi: (d) => setState(() => _dateLimite = d)),
                        ),
                        const SizedBox(height: 20),
                        Container(height: 1, color: SSMPalette.bordure),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          activeThumbColor: SSMPalette.indigo,
                          value: _obligatoire,
                          title: Text('Frais obligatoire', style: GoogleFonts.inter(fontSize: 14, color: SSMPalette.texte1)),
                          subtitle: Text(
                            _obligatoire ? 'Concerne tous les élèves éligibles' : 'Facultatif',
                            style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte3),
                          ),
                          onChanged: (v) => setState(() => _obligatoire = v),
                        ),
                        if (_modeEdition)
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            activeThumbColor: SSMPalette.teal,
                            value: _actif,
                            title: Text('Frais actif', style: GoogleFonts.inter(fontSize: 14, color: SSMPalette.texte1)),
                            onChanged: (v) => setState(() => _actif = v),
                          ),
                        const SizedBox(height: 8),
                        _titreSection('Échéances'),
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(SSMRayons.moyen)),
                          child: Row(
                            children: [
                              Expanded(child: _boutonModePaiement('Paiement en une fois', !_paiementEnPlusieurs, () {
                                setState(() => _paiementEnPlusieurs = false);
                              })),
                              Expanded(child: _boutonModePaiement('Plusieurs tranches', _paiementEnPlusieurs, () {
                                setState(() {
                                  _paiementEnPlusieurs = true;
                                  if (_echeances.isEmpty) _ajouterEcheance();
                                });
                              })),
                            ],
                          ),
                        ),
                        if (_paiementEnPlusieurs) ...[
                          const SizedBox(height: 12),
                          ..._echeances.asMap().entries.map((entry) => _carteEcheance(entry.key, entry.value)),
                          OutlinedButton.icon(
                            onPressed: _ajouterEcheance,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: SSMPalette.indigo,
                              side: const BorderSide(color: SSMPalette.indigo),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Ajouter une tranche'),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: (_echeancesValides ? SSMPalette.teal : SSMPalette.rouge).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(SSMRayons.moyen),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _echeancesValides ? Icons.check_circle : Icons.error_outline,
                                  size: 16,
                                  color: _echeancesValides ? SSMPalette.teal : SSMPalette.rouge,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Somme des tranches : ${_sommeEcheances.toStringAsFixed(0)} FCFA / ${_montant.toStringAsFixed(0)} FCFA',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 12,
                                      color: _echeancesValides ? SSMPalette.teal : SSMPalette.rouge,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        if (_erreur != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: SSMPalette.rougeClair,
                              borderRadius: BorderRadius.circular(SSMRayons.moyen),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber, color: SSMPalette.rouge, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(_erreur!, style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.rouge)),
                                ),
                              ],
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: SSMPalette.indigo,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
                            ),
                            onPressed: _enregistrementEnCours ? null : _enregistrer,
                            child: _enregistrementEnCours
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Enregistrer'),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _boutonModePaiement(String label, bool actif, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: actif ? SSMPalette.blanc : Colors.transparent,
          borderRadius: BorderRadius.circular(SSMRayons.petit),
          boxShadow: actif ? SSMOmbres.legere : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: actif ? SSMPalette.indigo : SSMPalette.texte2,
          ),
        ),
      ),
    );
  }

  Widget _carteEcheance(int index, _EcheanceEditable echeance) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SSMPalette.blanc,
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        border: Border.all(color: SSMPalette.bordure),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Tranche ${index + 1}',
                style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600, color: SSMPalette.indigo),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: SSMPalette.rouge, size: 20),
                onPressed: () => _supprimerEcheance(index),
              ),
            ],
          ),
          _champTexte(controller: echeance.libelleController, label: 'Libellé *', icone: Icons.label_outline, dense: true),
          const SizedBox(height: 8),
          _champTexte(
            controller: echeance.montantController,
            label: 'Montant (FCFA) *',
            icone: Icons.payments_outlined,
            clavierNumerique: true,
            dense: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          _ligneDate(
            titre: 'Échéance',
            date: echeance.dateLimite,
            onTap: () => _choisirDate(initial: echeance.dateLimite, onChoisi: (d) => setState(() => echeance.dateLimite = d)),
            couleurIcone: SSMPalette.teal,
            dense: true,
          ),
        ],
      ),
    );
  }

  Widget _ligneDate({
    required String titre,
    required DateTime date,
    required VoidCallback onTap,
    Color couleurIcone = SSMPalette.indigo,
    bool dense = false,
  }) {
    return Material(
      color: const Color(0xFFF9FAFB),
      borderRadius: BorderRadius.circular(SSMRayons.moyen),
      child: InkWell(
        borderRadius: BorderRadius.circular(SSMRayons.moyen),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: dense ? 10 : 14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(SSMRayons.moyen), border: Border.all(color: const Color(0xFFE5E7EB))),
          child: Row(
            children: [
              Icon(Icons.event_outlined, size: dense ? 18 : 20, color: couleurIcone),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$titre : ${_formatDateCourt(date)}',
                  style: GoogleFonts.inter(fontSize: dense ? 12 : 13, color: SSMPalette.texte1),
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: SSMPalette.texte3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _titreSection(String titre) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(
        titre.toUpperCase(),
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: SSMPalette.indigo, letterSpacing: 0.4),
      ),
    );
  }

  InputDecoration _decorationChamp(String label, {IconData? icone, bool dense = false}) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2),
      prefixIcon: icone != null ? Icon(icone, size: dense ? 18 : 20, color: SSMPalette.texte3) : null,
      isDense: dense,
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

  Widget _champTexte({
    required TextEditingController controller,
    required String label,
    required IconData icone,
    int maxLignes = 1,
    bool clavierNumerique = false,
    bool dense = false,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLignes,
      keyboardType: clavierNumerique ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: clavierNumerique
          ? GoogleFonts.jetBrainsMono(fontSize: 14, color: SSMPalette.texte1)
          : GoogleFonts.inter(fontSize: 14, color: SSMPalette.texte1),
      onChanged: onChanged,
      decoration: _decorationChamp(label, icone: icone, dense: dense),
    );
  }
}
