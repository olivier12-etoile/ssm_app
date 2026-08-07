import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_file/open_file.dart';
import '../../services/eleve_service.dart';
import '../../widgets/ssm_widgets.dart';

const Color _indigo = Color(0xFF1E3A8A);
const Color _ambre = Color(0xFFD97706);
const Color _vert = Color(0xFF16A34A);
const Color _rouge = Color(0xFFDC2626);
const Color _rougeFonce = Color(0xFF991B1B);
const Color _orange = Color(0xFFEA580C);
const Color _gris = Color(0xFF94A3B8);

Color _couleurAppBar(String type) {
  switch (type) {
    case 'en_regle':
      return _vert;
    case 'en_retard_paiement':
      return _rouge;
    case 'absents_aujourd_hui':
      return _orange;
    case 'suspendus':
      return _rougeFonce;
    case 'redoublants':
      return _ambre;
    default:
      return _indigo;
  }
}

String _infoContextuelle(String type, Map<String, dynamic> eleve) {
  final valeur = eleve['valeur']?.toString();
  switch (type) {
    case 'en_retard_paiement':
      return valeur != null ? 'Dette: $valeur' : 'Dette impayée';
    case 'absents_aujourd_hui':
      return "Absent aujourd'hui";
    case 'redoublants':
      return 'Redoublant';
    case 'en_difficulte':
      return valeur != null ? 'Moyenne: $valeur' : 'Moyenne insuffisante';
    case 'sans_photo':
      return 'Aucune photo';
    case 'sans_telephone':
      return 'Pas de téléphone parent';
    default:
      return valeur ?? '';
  }
}

Color _couleurStatutEleve(String? statut) {
  switch (statut) {
    case 'actif':
      return _indigo;
    case 'suspendu':
      return _orange;
    case 'exclu':
      return _rouge;
    case 'diplome':
      return _vert;
    case 'transfere':
      return _ambre;
    case 'abandon':
      return _gris;
    default:
      return _gris;
  }
}

Color _couleurInfoContextuelle(String type) {
  switch (type) {
    case 'en_retard_paiement':
      return _rouge;
    case 'absents_aujourd_hui':
      return _orange;
    case 'redoublants':
      return _ambre;
    case 'en_difficulte':
      return _rouge;
    default:
      return _gris;
  }
}

class ListeIntelligenteScreen extends StatefulWidget {
  final String type;
  final String titre;

  const ListeIntelligenteScreen({
    super.key,
    required this.type,
    required this.titre,
  });

  @override
  State<ListeIntelligenteScreen> createState() =>
      _ListeIntelligenteScreenState();
}

class _ListeIntelligenteScreenState extends State<ListeIntelligenteScreen> {
  bool _chargement = true;
  bool _exportEnCours = false;
  Map<String, dynamic> _classes = {};
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _chargement = true);
    try {
      final data = await EleveService.listeIntelligente(widget.type);
      setState(() {
        _classes = (data['classes'] as Map?)?.cast<String, dynamic>() ?? {};
        _total = data['total'] as int? ?? 0;
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

  Future<void> _exporterPdf({bool ouvrirPourImpression = false}) async {
    setState(() => _exportEnCours = true);
    try {
      final chemin = await EleveService.telechargerListeIntelligentePdf(
        widget.type,
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
      final chemin = await EleveService.telechargerListeIntelligenteExcel(
        widget.type,
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
    final couleur = _couleurAppBar(widget.type);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: couleur,
        foregroundColor: Colors.white,
        title: Text(
          widget.titre,
          style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _exportEnCours ? null : () => _exporterPdf(),
          ),
          IconButton(
            icon: const Icon(Icons.table_chart),
            onPressed: _exportEnCours ? null : _exporterExcel,
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _exportEnCours
                ? null
                : () => _exporterPdf(ouvrirPourImpression: true),
          ),
        ],
      ),
      body: _chargement
          ? Center(child: CircularProgressIndicator(color: couleur))
          : _classes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off, size: 64, color: _gris),
                  const SizedBox(height: 12),
                  Text(
                    'Aucun élève dans cette catégorie',
                    style: GoogleFonts.sora(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _gris,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _charger,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: couleur.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_total élève(s) trouvé(s)',
                          style: GoogleFonts.sora(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Groupés par classe',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: _gris,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._classes.entries.map(
                    (entry) => _sectionClasse(
                      entry.key,
                      entry.value as List,
                      couleur,
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
      bottomNavigationBar: _classes.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _rouge,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _exportEnCours ? null : () => _exporterPdf(),
                        icon: const Icon(Icons.picture_as_pdf, size: 18),
                        label: const Text('Exporter PDF'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _vert,
                        side: const BorderSide(color: _vert),
                      ),
                      onPressed: _exportEnCours ? null : _exporterExcel,
                      icon: const Icon(Icons.table_chart, size: 18),
                      label: const Text('Excel'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _gris,
                        side: const BorderSide(color: _gris),
                      ),
                      onPressed: _exportEnCours
                          ? null
                          : () => _exporterPdf(ouvrirPourImpression: true),
                      icon: const Icon(Icons.print, size: 18),
                      label: const Text('Imprimer'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _sectionClasse(String classeNom, List eleves, Color couleur) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SSMSectionTitre(titre: '$classeNom (${eleves.length} élèves)'),
          ...eleves.map(
            (e) => _carteEleve(e as Map<String, dynamic>, couleur),
          ),
        ],
      ),
    );
  }

  Widget _carteEleve(Map<String, dynamic> eleve, Color couleur) {
    final infoTexte = _infoContextuelle(widget.type, eleve);
    final infoCouleur = _couleurInfoContextuelle(widget.type);

    return Material(
      color: Colors.white.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.pushNamed(
          context,
          '/eleve/fiche',
          arguments: {'eleveId': eleve['eleve_id'] as int},
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
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
                radius: 20,
                backgroundColor: couleur.withValues(alpha: 0.1),
                backgroundImage: eleve['photo_url'] != null
                    ? NetworkImage(eleve['photo_url'] as String)
                    : null,
                child: eleve['photo_url'] == null
                    ? Text(
                        (eleve['nom'] as String? ?? '?').substring(0, 1),
                        style: GoogleFonts.sora(
                          color: couleur,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${eleve['nom']} ${eleve['prenom']}',
                      style: GoogleFonts.sora(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (infoTexte.isNotEmpty)
                      Text(
                        infoTexte,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: infoCouleur,
                        ),
                      ),
                  ],
                ),
              ),
              SSMBadge(
                label: (eleve['statut'] as String? ?? 'actif'),
                couleur: _couleurStatutEleve(eleve['statut'] as String?),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: _gris),
            ],
          ),
        ),
      ),
    );
  }
}
