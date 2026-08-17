import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/presence_model.dart';
import '../../services/annee_service.dart';
import '../../services/classe_service.dart';
import '../../services/presence_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_data_table.dart';
import '../../widgets/ssm/ssm_panel.dart';
import '../../widgets/ssm/ssm_stat_card.dart';

// ══════════════════════════════════════════════════════════
// StatistiquesPresenceClasseScreen — taux de présence global de
// la classe + classement des élèves les plus absents, sur la
// période sélectionnée.
// ══════════════════════════════════════════════════════════
class StatistiquesPresenceClasseScreen extends StatefulWidget {
  final int classeId;
  final String classeNom;

  const StatistiquesPresenceClasseScreen({super.key, required this.classeId, required this.classeNom});

  @override
  State<StatistiquesPresenceClasseScreen> createState() => _StatistiquesPresenceClasseScreenState();
}

class _StatistiquesPresenceClasseScreenState extends State<StatistiquesPresenceClasseScreen> {
  bool _chargement = true;
  String? _erreur;

  List<dynamic> _periodes = [];
  int? _periodeSelectionneeId;
  StatistiquePresenceClasse? _statistiques;

  @override
  void initState() {
    super.initState();
    _initialiser();
  }

  Future<void> _initialiser() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final details = await ClasseService.details(widget.classeId);
      final classe = details['classe'] as Map<String, dynamic>;
      final anneeId = classe['annee_academique_id'] as int?;

      List<dynamic> periodes = [];
      if (anneeId != null) {
        periodes = await AnneeService.listerPeriodes(anneeId);
      }

      final periodeId = periodes.isNotEmpty
          ? (periodes.firstWhere((p) => p['statut'] == 'ouverte', orElse: () => periodes.first)['id'] as int)
          : null;

      setState(() {
        _periodes = periodes;
        _periodeSelectionneeId = periodeId;
      });

      if (periodeId != null) {
        await _chargerStatistiques(periodeId);
      }
    } catch (e) {
      setState(() => _erreur = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _chargerStatistiques(int periodeId) async {
    try {
      final stats = await PresenceService.getStatistiquesClasse(widget.classeId, periodeId);
      if (!mounted) return;
      setState(() => _statistiques = stats);
    } catch (e) {
      if (!mounted) return;
      setState(() => _erreur = e.toString().replaceAll('Exception: ', ''));
    }
  }

  Color _couleurTaux(double taux) {
    if (taux >= 90) return SSMPalette.teal;
    if (taux >= 75) return SSMPalette.ambre;
    return SSMPalette.rouge;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SSMPalette.fond,
      appBar: AppBar(
        backgroundColor: SSMPalette.blanc,
        foregroundColor: SSMPalette.texte2,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: SSMPalette.texte2),
        title: Text(
          'Présence — ${widget.classeNom}',
          style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
        ),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
          : (_erreur != null && _statistiques == null)
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_erreur!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: SSMPalette.texte2)),
                  ),
                )
              : _corps(),
    );
  }

  Widget _corps() {
    final stats = _statistiques ?? StatistiquePresenceClasse();
    final couleur = _couleurTaux(stats.tauxPresence);

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
                _chargerStatistiques(v);
              },
            ),
          ),
        Row(
          children: [
            Expanded(
              child: SSMStatCard(
                icone: Icons.event_available,
                couleur: couleur,
                valeur: '${stats.tauxPresence.toStringAsFixed(1)}%',
                label: 'Taux de présence',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SSMStatCard(
                icone: Icons.checklist_outlined,
                couleur: SSMPalette.indigo,
                valeur: '${stats.totalAppels}',
                label: 'Appels enregistrés',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (stats.tauxPresence / 100).clamp(0, 1),
            minHeight: 8,
            backgroundColor: SSMPalette.bordure,
            color: couleur,
          ),
        ),
        const SizedBox(height: 20),
        SSMPanel(
          titre: 'Élèves les plus absents',
          padding: EdgeInsets.zero,
          child: stats.elevesPlusAbsents.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('Aucune donnée sur cette période', style: GoogleFonts.inter(color: SSMPalette.texte3)),
                  ),
                )
              : SSMDataTable(
                  colonnes: const [
                    SSMDataColumn(''),
                    SSMDataColumn('Élève'),
                    SSMDataColumn('Absences'),
                    SSMDataColumn('Retards'),
                    SSMDataColumn('Taux présence'),
                  ],
                  lignes: [
                    for (int i = 0; i < stats.elevesPlusAbsents.length; i++) _ligneEleve(i + 1, stats.elevesPlusAbsents[i]),
                  ],
                ),
        ),
      ],
    );
  }

  List<Widget> _ligneEleve(int rang, EleveAbsences e) {
    return [
      Text('$rang', style: GoogleFonts.jetBrainsMono(fontSize: 12, color: SSMPalette.texte3)),
      Text('${e.nom} ${e.prenom}', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: SSMPalette.texte1)),
      Text('${e.nombreAbsences}', style: GoogleFonts.inter(fontSize: 12, color: e.nombreAbsences > 0 ? SSMPalette.rouge : SSMPalette.texte2)),
      Text('${e.retards}', style: GoogleFonts.inter(fontSize: 12, color: e.retards > 0 ? SSMPalette.ambre : SSMPalette.texte2)),
      Text('${e.tauxPresence.toStringAsFixed(0)}%', style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte1)),
    ];
  }
}
