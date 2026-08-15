import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_file/open_file.dart';
import '../../services/eleve_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_avatar.dart';
import '../../widgets/ssm/ssm_pill.dart';

Color _couleurAppBar(String type) {
  switch (type) {
    case 'en_regle':
      return SSMPalette.teal;
    case 'en_retard_paiement':
      return SSMPalette.rouge;
    case 'absents_aujourd_hui':
      return SSMPalette.ambre;
    case 'suspendus':
      return SSMPalette.rouge;
    case 'redoublants':
      return SSMPalette.ambre;
    default:
      return SSMPalette.indigo;
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
      return SSMPalette.indigo;
    case 'suspendu':
      return SSMPalette.ambre;
    case 'exclu':
      return SSMPalette.rouge;
    case 'diplome':
      return SSMPalette.teal;
    case 'transfere':
      return SSMPalette.ambre;
    case 'abandon':
      return SSMPalette.texte3;
    default:
      return SSMPalette.texte3;
  }
}

Color _couleurInfoContextuelle(String type) {
  switch (type) {
    case 'en_retard_paiement':
      return SSMPalette.rouge;
    case 'absents_aujourd_hui':
      return SSMPalette.ambre;
    case 'redoublants':
      return SSMPalette.ambre;
    case 'en_difficulte':
      return SSMPalette.rouge;
    default:
      return SSMPalette.texte3;
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: SSMPalette.rouge),
    );
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
      backgroundColor: SSMPalette.fond,
      appBar: AppBar(
        backgroundColor: SSMPalette.blanc,
        foregroundColor: SSMPalette.texte1,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: SSMPalette.texte2),
        title: Text(
          widget.titre,
          style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: SSMPalette.bordure),
        ),
      ),
      body: _chargement
          ? Center(child: CircularProgressIndicator(color: couleur))
          : _classes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 56, color: SSMPalette.texte3),
                  const SizedBox(height: 12),
                  Text(
                    'Aucun élève dans cette catégorie',
                    style: GoogleFonts.sora(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: SSMPalette.texte3,
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
                      borderRadius: BorderRadius.circular(SSMRayons.grand),
                      border: Border.all(color: couleur.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_total élève(s) trouvé(s)',
                          style: GoogleFonts.sora(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: couleur,
                          ),
                        ),
                        Text(
                          'Groupés par classe',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: SSMPalette.texte2,
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
                          backgroundColor: SSMPalette.rouge,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
                        ),
                        onPressed: _exportEnCours ? null : () => _exporterPdf(),
                        icon: const Icon(Icons.picture_as_pdf, size: 18),
                        label: const Text('Exporter PDF'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: SSMPalette.teal,
                        side: const BorderSide(color: SSMPalette.teal),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
                      ),
                      onPressed: _exportEnCours ? null : _exporterExcel,
                      icon: const Icon(Icons.table_chart, size: 18),
                      label: const Text('Excel'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: SSMPalette.texte2,
                        side: const BorderSide(color: SSMPalette.bordure),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SSMRayons.moyen)),
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
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '$classeNom (${eleves.length} élèves)',
              style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: SSMPalette.indigo),
            ),
          ),
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
      color: SSMPalette.blanc,
      borderRadius: BorderRadius.circular(SSMRayons.grand),
      child: InkWell(
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        onTap: () => Navigator.pushNamed(
          context,
          '/eleve/fiche',
          arguments: {'eleveId': eleve['eleve_id'] as int},
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SSMRayons.grand),
            border: Border.all(color: SSMPalette.bordure),
          ),
          child: Row(
            children: [
              SSMAvatar(
                nom: eleve['nom'] as String? ?? '?',
                photoUrl: eleve['photo_url'] as String?,
                couleur: couleur,
                rayon: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${eleve['nom']} ${eleve['prenom']}',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: SSMPalette.texte1),
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
              SSMPill.couleur(
                label: (eleve['statut'] as String? ?? 'actif'),
                couleur: _couleurStatutEleve(eleve['statut'] as String?),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: SSMPalette.texte3),
            ],
          ),
        ),
      ),
    );
  }
}
