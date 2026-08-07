import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_file/open_file.dart';
import '../../services/annee_service.dart';
import '../../widgets/ssm_widgets.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _ambre = Color(0xFFD97706);
const Color _vert = Color(0xFF16A34A);
const Color _rouge = Color(0xFFDC2626);
const Color _gris = Color(0xFF94A3B8);

Color _couleurMention(String? mention) {
  switch (mention) {
    case 'Excellent':
    case 'Très Bien':
      return _vert;
    case 'Bien':
    case 'Assez Bien':
      return _indigo;
    case 'Passable':
      return _ambre;
    default:
      return _rouge;
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
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: _rouge));
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
        title: Text(
          'Classement — ${widget.classeNom}',
          style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _exportEnCours ? null : _exporterPdf,
          ),
        ],
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator(color: _indigo))
          : RefreshIndicator(
              onRefresh: _charger,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  Container(
                    width: double.infinity,
                    color: _indigo,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.periodeNom,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_eleves.length} élèves classés · Moyenne classe : ${_moyenneClasse?.toStringAsFixed(2) ?? '—'}/20',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (podium.isNotEmpty) _podium(podium),
                  const SizedBox(height: 12),
                  ...classes.asMap().entries.map(
                    (entry) => _ligneClassement(entry.value, entry.key + 4),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _ambre,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _exportEnCours ? null : _exporterPdf,
                        icon: _exportEnCours
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.picture_as_pdf),
                        label: const Text('Exporter PDF'),
                      ),
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (deuxieme != null)
            Expanded(
              child: _placePodium(
                deuxieme,
                rang: 2,
                tailleAvatar: 50,
                couleur: const Color(0xFFC0C0C0),
              ),
            ),
          if (premier != null)
            Expanded(
              child: _placePodium(
                premier,
                rang: 1,
                tailleAvatar: 60,
                couleur: const Color(0xFFFFD700),
                couronne: true,
              ),
            ),
          if (troisieme != null)
            Expanded(
              child: _placePodium(
                troisieme,
                rang: 3,
                tailleAvatar: 50,
                couleur: const Color(0xFFCD7F32),
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
    return Column(
      children: [
        if (couronne) const Icon(Icons.emoji_events, color: Color(0xFFFFD700)),
        Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: tailleAvatar / 2,
              backgroundColor: couleur,
              backgroundImage: eleve['photo_url'] != null
                  ? NetworkImage(eleve['photo_url'] as String)
                  : null,
              child: eleve['photo_url'] == null
                  ? Text(
                      '$rang',
                      style: GoogleFonts.sora(
                        fontSize: rang == 1 ? 24 : 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '${eleve['nom']} ${eleve['prenom']}',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: rang == 1 ? 14 : 13,
            fontWeight: rang == 1 ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
        Text(
          moyenne != null ? '${moyenne.toStringAsFixed(2)}/20' : '—',
          style: GoogleFonts.sora(
            fontSize: rang == 1 ? 20 : 16,
            fontWeight: FontWeight.w700,
            color: _ambre,
          ),
        ),
      ],
    );
  }

  Widget _ligneClassement(dynamic e, int rangFallback) {
    final eleve = e as Map<String, dynamic>;
    final rang = eleve['rang'] as int? ?? rangFallback;
    final moyenne = (eleve['moyenne'] as num?)?.toDouble();
    final mention = eleve['mention'] as String?;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: rang <= 10
                ? _indigo
                : const Color(0xFFF1F5F9),
            child: Text(
              '$rang',
              style: GoogleFonts.sora(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: rang <= 10 ? Colors.white : _gris,
              ),
            ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 20,
            backgroundImage: eleve['photo_url'] != null
                ? NetworkImage(eleve['photo_url'] as String)
                : null,
            backgroundColor: _indigo.withValues(alpha: 0.1),
            child: eleve['photo_url'] == null
                ? Text(
                    (eleve['nom'] as String? ?? '?').substring(0, 1),
                    style: GoogleFonts.sora(
                      color: _indigo,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${eleve['nom']} ${eleve['prenom']}',
                  style: GoogleFonts.sora(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                moyenne != null ? '${moyenne.toStringAsFixed(2)}/20' : '—',
                style: GoogleFonts.sora(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _couleurMention(mention),
                ),
              ),
              if (mention != null)
                SSMBadge(label: mention, couleur: _couleurMention(mention)),
            ],
          ),
        ],
      ),
    );
  }
}
