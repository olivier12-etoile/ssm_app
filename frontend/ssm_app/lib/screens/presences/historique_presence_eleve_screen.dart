import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/presence_model.dart';
import '../../services/annee_service.dart';
import '../../services/eleve_service.dart';
import '../../services/presence_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_data_table.dart';
import '../../widgets/ssm/ssm_panel.dart';
import '../../widgets/ssm/ssm_pill.dart';
import '../../widgets/ssm/ssm_stat_card.dart';

// ══════════════════════════════════════════════════════════
// HistoriquePresenceEleveScreen — onglet "Présences" de la fiche
// élève : cartes résumé (module Bulletins réutilise déjà ces
// totaux) + historique chronologique des appels de la période
// sélectionnée.
// ══════════════════════════════════════════════════════════
class HistoriquePresenceEleveScreen extends StatefulWidget {
  final int eleveId;
  final String? eleveNom;

  const HistoriquePresenceEleveScreen({super.key, required this.eleveId, this.eleveNom});

  @override
  State<HistoriquePresenceEleveScreen> createState() => _HistoriquePresenceEleveScreenState();
}

class _HistoriquePresenceEleveScreenState extends State<HistoriquePresenceEleveScreen> {
  bool _chargement = true;
  String? _erreur;

  List<dynamic> _periodes = [];
  int? _periodeSelectionneeId;
  HistoriquePresenceEleve? _historique;

  @override
  void initState() {
    super.initState();
    _chargerPeriodesEtHistorique();
  }

  Future<void> _chargerPeriodesEtHistorique() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final details = await EleveService.details(widget.eleveId);
      final inscription = details['inscription_actuelle'] as Map<String, dynamic>?;
      final anneeId = inscription?['annee_academique_id'] as int?;

      List<dynamic> periodes = [];
      if (anneeId != null) {
        periodes = await AnneeService.listerPeriodes(anneeId);
      }

      final periodeId = _periodeSelectionneeId ??
          (periodes.isNotEmpty
              ? (periodes.firstWhere((p) => p['statut'] == 'ouverte', orElse: () => periodes.first)['id'] as int)
              : null);

      setState(() {
        _periodes = periodes;
        _periodeSelectionneeId = periodeId;
      });

      if (periodeId != null) {
        await _chargerHistorique(periodeId);
      }
    } catch (e) {
      setState(() => _erreur = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _chargerHistorique(int periodeId) async {
    try {
      final historique = await PresenceService.getHistoriqueEleve(widget.eleveId, periodeId);
      if (!mounted) return;
      setState(() => _historique = historique);
    } catch (e) {
      if (!mounted) return;
      setState(() => _erreur = e.toString().replaceAll('Exception: ', ''));
    }
  }

  String _formatDateAffichee(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) {
      return const Center(child: CircularProgressIndicator(color: SSMPalette.indigo));
    }

    if (_erreur != null && _historique == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_erreur!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: SSMPalette.texte2)),
        ),
      );
    }

    final historique = _historique ?? HistoriquePresenceEleve();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_periodes.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: DropdownButtonFormField<int>(
              initialValue: _periodeSelectionneeId,
              decoration: InputDecoration(
                labelText: 'Période',
                labelStyle: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte2),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(SSMRayons.moyen),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
              items: _periodes
                  .cast<Map<String, dynamic>>()
                  .map((p) => DropdownMenuItem(value: p['id'] as int, child: Text(p['nom'] as String)))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _periodeSelectionneeId = v);
                _chargerHistorique(v);
              },
            ),
          ),
        GridView.count(
          crossAxisCount: MediaQuery.of(context).size.width > 700 ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.35,
          children: [
            SSMStatCard(
              icone: Icons.check_circle_outline,
              couleur: SSMPalette.teal,
              valeur: '${historique.totalPresences}',
              label: 'Présences',
            ),
            SSMStatCard(
              icone: Icons.fact_check_outlined,
              couleur: SSMPalette.indigo,
              valeur: '${historique.totalAbsencesJustifiees}',
              label: 'Absences justifiées',
            ),
            SSMStatCard(
              icone: Icons.cancel_outlined,
              couleur: SSMPalette.rouge,
              valeur: '${historique.totalAbsencesNonJustifiees}',
              label: 'Absences non justifiées',
            ),
            SSMStatCard(
              icone: Icons.schedule_outlined,
              couleur: SSMPalette.ambre,
              valeur: '${historique.totalRetards}',
              label: 'Retards',
            ),
          ],
        ),
        const SizedBox(height: 16),
        SSMPanel(
          titre: 'Historique',
          padding: EdgeInsets.zero,
          child: historique.detail.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('Aucun appel enregistré sur cette période', style: GoogleFonts.inter(color: SSMPalette.texte3)),
                  ),
                )
              : SSMDataTable(
                  colonnes: const [
                    SSMDataColumn('Date'),
                    SSMDataColumn('Matière'),
                    SSMDataColumn('Statut'),
                    SSMDataColumn('Justifié'),
                  ],
                  lignes: [for (final p in historique.detail) _ligneHistorique(p)],
                ),
        ),
      ],
    );
  }

  List<Widget> _ligneHistorique(Presence p) {
    return [
      Text(p.date != null ? _formatDateAffichee(p.date!) : '—', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte1)),
      Text(p.matiere ?? '—', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte1)),
      SSMPill.couleur(label: p.statut.label, couleur: p.statut.couleur),
      Text(
        p.statut == StatutPresence.absent ? (p.justifie ? 'Oui' : 'Non') : '—',
        style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2),
      ),
    ];
  }
}
