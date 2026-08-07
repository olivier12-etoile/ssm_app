import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_file/open_file.dart';
import '../../services/annee_service.dart';
import '../../widgets/ssm_widgets.dart';

const Color _rouge = Color(0xFFDC2626);
const Color _orange = Color(0xFFEA580C);
const Color _vert = Color(0xFF16A34A);
const Color _gris = Color(0xFF94A3B8);

class ElevesNonEnRegleScreen extends StatefulWidget {
  const ElevesNonEnRegleScreen({super.key});

  @override
  State<ElevesNonEnRegleScreen> createState() =>
      _ElevesNonEnRegleScreenState();
}

class _ElevesNonEnRegleScreenState extends State<ElevesNonEnRegleScreen> {
  bool _chargement = true;
  bool _exportEnCours = false;
  Map<String, dynamic> _classes = {};
  String _filtre = 'tous';

  @override
  void initState() {
    super.initState();
    _charger();
  }

  List<String>? get _motifsActuels {
    switch (_filtre) {
      case 'paiement':
        return ['paiement'];
      case 'absences':
        return ['absences'];
      case 'dossier':
        return ['dossier'];
      default:
        return ['paiement', 'absences'];
    }
  }

  Future<void> _charger() async {
    setState(() => _chargement = true);
    try {
      final data = await AnneeService.elevesNonEnRegle(
        motif: _motifsActuels,
      );
      final classesData = data['classes'];
      setState(() {
        _classes = classesData is Map
            ? classesData.cast<String, dynamic>()
            : {};
        _chargement = false;
      });
    } catch (e) {
      setState(() {
        _classes = {};
        _chargement = false;
      });
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
      final chemin = await AnneeService.telechargerElevesNonEnReglePdf(
        motif: _motifsActuels,
      );
      await OpenFile.open(chemin);
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _exportEnCours = false);
    }
  }

  Future<void> _exporterExcel() async {
    setState(() => _exportEnCours = true);
    try {
      final chemin = await AnneeService.telechargerElevesNonEnRegleExcel(
        motif: _motifsActuels,
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: _rouge,
        foregroundColor: Colors.white,
        title: Text(
          'Élèves non en règle',
          style: GoogleFonts.sora(fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              children: [
                _chip('Tous', 'tous'),
                _chip('Impayés', 'paiement'),
                _chip('Absences excessives', 'absences'),
                _chip('Dossier incomplet', 'dossier'),
              ],
            ),
          ),
          Expanded(
            child: _chargement
                ? const Center(
                    child: CircularProgressIndicator(color: _rouge),
                  )
                : _classes.isEmpty
                ? Center(
                    child: Text(
                      'Aucun élève non en règle 🎉',
                      style: GoogleFonts.inter(color: _gris),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _charger,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: _classes.entries
                          .map((entry) => _sectionClasse(entry.key, entry.value as List))
                          .toList(),
                    ),
                  ),
          ),
          if (_classes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _rouge,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _exportEnCours ? null : _exporterPdf,
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Exporter PDF'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _vert,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _exportEnCours ? null : _exporterExcel,
                      icon: const Icon(Icons.table_chart),
                      label: const Text('Exporter Excel'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(String label, String valeur) {
    final selectionne = _filtre == valeur;
    return ChoiceChip(
      label: Text(label),
      selected: selectionne,
      selectedColor: _rouge.withValues(alpha: 0.15),
      labelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: selectionne ? _rouge : _gris,
      ),
      onSelected: (_) {
        setState(() => _filtre = valeur);
        _charger();
      },
    );
  }

  Widget _sectionClasse(String classeNom, List eleves) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SSMSectionTitre(titre: classeNom),
          ...eleves.map((e) => _carteEleve(e as Map<String, dynamic>)),
        ],
      ),
    );
  }

  Widget _carteEleve(Map<String, dynamic> eleve) {
    final motifs = (eleve['motifs'] as Map?)?.cast<String, dynamic>() ?? {};
    final paiement = motifs['paiement'] as Map<String, dynamic>?;
    final absences = motifs['absences'] as Map<String, dynamic>?;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: const Border(left: BorderSide(color: _rouge, width: 4)),
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
            radius: 20,
            backgroundColor: _rouge.withValues(alpha: 0.1),
            child: Text(
              (eleve['nom'] as String? ?? '?').substring(0, 1),
              style: GoogleFonts.sora(color: _rouge, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
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
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (paiement != null)
                      SSMBadge(
                        label:
                            '💰 Dette : ${paiement['montant_restant']} FCFA',
                        couleur: _rouge,
                      ),
                    if (absences != null)
                      SSMBadge(
                        label:
                            '📅 ${absences['nombre_absences_non_justifiees']} absences',
                        couleur: _orange,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
