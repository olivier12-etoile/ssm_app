import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_file/open_file.dart';
import '../../services/annee_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_avatar.dart';
import '../../widgets/ssm/ssm_data_table.dart';
import '../../widgets/ssm/ssm_panel.dart';
import '../../widgets/ssm/ssm_pill.dart';

// Bronze : teinte brune/orange dérivée de SSMPalette.ambre pour le podium.
const Color _bronze = Color(0xFFB45309);

Color _couleurMention(String? mention) {
  switch (mention) {
    case 'Excellent':
    case 'Très Bien':
      return SSMPalette.teal;
    case 'Bien':
    case 'Assez Bien':
      return SSMPalette.indigo;
    case 'Passable':
      return SSMPalette.ambre;
    default:
      return SSMPalette.rouge;
  }
}

class RangsClasseScreen extends StatefulWidget {
  final int classeId;
  final String classeNom;
  final int periodeId;
  final String periodeNom;

  const RangsClasseScreen({
    super.key,
    required this.classeId,
    required this.classeNom,
    required this.periodeId,
    required this.periodeNom,
  });

  @override
  State<RangsClasseScreen> createState() => _RangsClasseScreenState();
}

class _RangsClasseScreenState extends State<RangsClasseScreen> {
  bool _chargement = true;
  List<dynamic> _eleves = [];
  double? _moyenneClasse;
  bool _exportEnCours = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _chargement = true);
    try {
      final data = await AnneeService.rangsClasseDetail(
        classeId: widget.classeId,
        periodeId: widget.periodeId,
      );
      setState(() {
        _eleves = data['eleves'] as List? ?? [];
        _moyenneClasse = (data['moyenne_classe'] as num?)?.toDouble();
        _chargement = false;
      });
    } catch (e) {
      setState(() => _chargement = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _afficherErreur(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: SSMPalette.rouge));
  }

  Future<void> _exporterPdf() async {
    setState(() => _exportEnCours = true);
    try {
      final chemin = await AnneeService.telechargerRangsPdf(
        classeId: widget.classeId,
        periodeId: widget.periodeId,
      );
      await OpenFile.open(chemin);
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _exportEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final classes = _eleves.length > 3 ? _eleves.sublist(3) : <dynamic>[];
    final podium = _eleves.length > 3 ? _eleves.sublist(0, 3) : _eleves;

    return Scaffold(
      backgroundColor: SSMPalette.fond,
      appBar: AppBar(
        title: Text('Classement — ${widget.classeNom}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _exportEnCours ? null : _exporterPdf,
          ),
        ],
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
          : RefreshIndicator(
              onRefresh: _charger,
              color: SSMPalette.indigo,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    widget.periodeNom,
                    style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_eleves.length} élèves classés · Moyenne classe : ${_moyenneClasse?.toStringAsFixed(2) ?? '—'}/20',
                    style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
                  ),
                  const SizedBox(height: 16),
                  if (podium.isNotEmpty) _podium(podium),
                  if (classes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _tableClassement(classes),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SSMPalette.ambre,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
                      ),
                      onPressed: _exportEnCours ? null : _exporterPdf,
                      icon: _exportEnCours
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.picture_as_pdf),
                      label: const Text('Exporter PDF'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _podium(List<dynamic> podium) {
    final premier = podium.isNotEmpty ? podium[0] as Map<String, dynamic> : null;
    final deuxieme = podium.length > 1 ? podium[1] as Map<String, dynamic> : null;
    final troisieme = podium.length > 2 ? podium[2] as Map<String, dynamic> : null;

    return SSMPanel(
      titre: 'Podium',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (deuxieme != null)
            Expanded(
              child: _placePodium(
                deuxieme,
                rang: 2,
                tailleAvatar: 44,
                couleur: SSMPalette.texte3,
              ),
            ),
          if (premier != null)
            Expanded(
              child: _placePodium(
                premier,
                rang: 1,
                tailleAvatar: 56,
                couleur: SSMPalette.ambre,
                couronne: true,
              ),
            ),
          if (troisieme != null)
            Expanded(
              child: _placePodium(
                troisieme,
                rang: 3,
                tailleAvatar: 44,
                couleur: _bronze,
              ),
            ),
        ],
      ),
    );
  }

  Widget _placePodium(
    Map<String, dynamic> eleve, {
    required int rang,
    required double tailleAvatar,
    required Color couleur,
    bool couronne = false,
  }) {
    final moyenne = (eleve['moyenne'] as num?)?.toDouble();
    return Container(
      margin: EdgeInsets.only(top: couronne ? 0 : 20),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: SSMPalette.blanc,
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        border: Border.all(color: SSMPalette.bordure),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (couronne) Icon(Icons.emoji_events, color: couleur, size: 20),
          if (couronne) const SizedBox(height: 4),
          SSMAvatar(
            nom: eleve['nom'] as String? ?? '?',
            photoUrl: eleve['photo_url'] as String?,
            couleur: couleur,
            rayon: tailleAvatar / 2,
          ),
          const SizedBox(height: 8),
          Text(
            '${eleve['nom']} ${eleve['prenom']}',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: rang == 1 ? 13 : 12,
              fontWeight: rang == 1 ? FontWeight.w700 : FontWeight.w600,
              color: SSMPalette.texte1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            moyenne != null ? '${moyenne.toStringAsFixed(2)}/20' : '—',
            style: GoogleFonts.sora(
              fontSize: rang == 1 ? 18 : 15,
              fontWeight: FontWeight.w700,
              color: couleur,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableClassement(List<dynamic> classes) {
    return SSMDataTable(
      colonnes: const [
        SSMDataColumn('Rang'),
        SSMDataColumn(''),
        SSMDataColumn('Élève'),
        SSMDataColumn('Moyenne'),
        SSMDataColumn('Mention'),
      ],
      lignes: [
        for (final entry in classes.asMap().entries)
          _ligneClassement(entry.value, entry.key + 4),
      ],
    );
  }

  List<Widget> _ligneClassement(dynamic e, int rangFallback) {
    final eleve = e as Map<String, dynamic>;
    final rang = eleve['rang'] as int? ?? rangFallback;
    final moyenne = (eleve['moyenne'] as num?)?.toDouble();
    final mention = eleve['mention'] as String?;
    final couleurMention = _couleurMention(mention);

    return [
      SSMPill.couleur(label: '$rang', couleur: rang <= 10 ? SSMPalette.indigo : SSMPalette.texte3),
      SSMAvatar(nom: eleve['nom'] as String? ?? '?', photoUrl: eleve['photo_url'] as String?, rayon: 15),
      Text(
        '${eleve['nom']} ${eleve['prenom']}',
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: SSMPalette.texte1),
      ),
      Text(
        moyenne != null ? '${moyenne.toStringAsFixed(2)}/20' : '—',
        style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: couleurMention),
      ),
      mention != null ? SSMPill.couleur(label: mention, couleur: couleurMention) : const SizedBox.shrink(),
    ];
  }
}
