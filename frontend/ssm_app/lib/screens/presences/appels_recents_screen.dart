import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/presence_model.dart';
import '../../services/presence_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_pill.dart';
import 'appel_presence_screen.dart';

// ══════════════════════════════════════════════════════════
// AppelsRecentsScreen — historique des appels d'une classe.
// Tap sur un appel → AppelPresenceScreen en lecture seule si
// déjà terminé (édition encore possible si "en_cours").
// ══════════════════════════════════════════════════════════
class AppelsRecentsScreen extends StatefulWidget {
  final int classeId;
  final String classeNom;

  const AppelsRecentsScreen({super.key, required this.classeId, required this.classeNom});

  @override
  State<AppelsRecentsScreen> createState() => _AppelsRecentsScreenState();
}

class _AppelsRecentsScreenState extends State<AppelsRecentsScreen> {
  bool _chargement = true;
  String? _erreur;
  List<AppelPresence> _appels = [];

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
      final appels = await PresenceService.getAppelsRecents(widget.classeId);
      setState(() => _appels = appels);
    } catch (e) {
      setState(() => _erreur = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  String _formatDateAffichee(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _ouvrirAppel(AppelPresence appel) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AppelPresenceScreen(
          classeId: widget.classeId,
          classeNom: widget.classeNom,
          appelIdExistant: appel.id,
        ),
      ),
    );
    _charger();
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
          'Appels — ${widget.classeNom}',
          style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
        ),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
          : _erreur != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_erreur!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: SSMPalette.texte2)),
                  ),
                )
              : _appels.isEmpty
                  ? Center(
                      child: Text('Aucun appel enregistré pour cette classe', style: GoogleFonts.inter(color: SSMPalette.texte3)),
                    )
                  : RefreshIndicator(
                      onRefresh: _charger,
                      color: SSMPalette.indigo,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _appels.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => _carteAppel(_appels[i]),
                      ),
                    ),
    );
  }

  Widget _carteAppel(AppelPresence appel) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(SSMRayons.grand),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _ouvrirAppel(appel),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: SSMPalette.blanc,
            borderRadius: BorderRadius.circular(SSMRayons.grand),
            border: Border.all(color: SSMPalette.bordure),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _formatDateAffichee(appel.dateAppel),
                          style: GoogleFonts.sora(fontSize: 13.5, fontWeight: FontWeight.w700, color: SSMPalette.texte1),
                        ),
                        const SizedBox(width: 8),
                        SSMPill.couleur(
                          label: appel.estTermine ? 'Terminé' : 'En cours',
                          couleur: appel.estTermine ? SSMPalette.indigo : SSMPalette.ambre,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      appel.nomMatiere ?? 'Appel général',
                      style: GoogleFonts.inter(fontSize: 12.5, color: SSMPalette.texte2),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        _resumeChip(Icons.check_circle_outline, '${appel.nombrePresents} présents', SSMPalette.teal),
                        _resumeChip(Icons.cancel_outlined, '${appel.nombreAbsents} absents', SSMPalette.rouge),
                        _resumeChip(Icons.schedule_outlined, '${appel.nombreRetards} retards', SSMPalette.ambre),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: SSMPalette.texte3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resumeChip(IconData icone, String label, Color couleur) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone, size: 13, color: couleur),
        const SizedBox(width: 3),
        Text(label, style: GoogleFonts.inter(fontSize: 11.5, color: SSMPalette.texte2)),
      ],
    );
  }
}
