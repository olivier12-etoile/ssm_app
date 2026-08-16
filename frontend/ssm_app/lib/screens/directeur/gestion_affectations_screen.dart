import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/affectation_service.dart';
import '../../services/classe_matiere_service.dart';
import '../../services/classe_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_avatar.dart';
import '../../widgets/ssm/ssm_pill.dart';
import 'affectations_classe_screen.dart';

class GestionAffectationsScreen extends StatefulWidget {
  const GestionAffectationsScreen({super.key});

  @override
  State<GestionAffectationsScreen> createState() =>
      _GestionAffectationsScreenState();
}

class _GestionAffectationsScreenState extends State<GestionAffectationsScreen> {
  List<dynamic> _classes = [];
  Map<int, int> _totalMatieres = {};
  Map<int, int> _matieresAffectees = {};
  bool _chargement = true;
  bool _chargementCompteurs = false;

  @override
  void initState() {
    super.initState();
    _chargerDonnees();
  }

  Future<void> _chargerDonnees() async {
    try {
      final classes = await ClasseService.listerClasses();
      setState(() {
        _classes = classes;
        _chargement = false;
      });
      await _chargerCompteurs();
    } catch (e) {
      setState(() => _chargement = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _chargerCompteurs() async {
    if (_classes.isEmpty) return;

    setState(() => _chargementCompteurs = true);

    try {
      final resultats = await Future.wait(
        _classes.map((classe) {
          final classeId = classe['id'] as int;
          return Future.wait([
            ClasseMatiereService.listerParClasse(classeId),
            AffectationService.listerParClasse(classeId),
          ]);
        }),
      );

      final totaux = <int, int>{};
      final affectees = <int, int>{};

      for (var i = 0; i < _classes.length; i++) {
        final classeId = _classes[i]['id'] as int;
        final matieresClasse = resultats[i][0];
        final affectations = resultats[i][1];

        totaux[classeId] = matieresClasse.length;
        affectees[classeId] = affectations
            .map((a) => a['matiere_id'])
            .toSet()
            .length;
      }

      setState(() {
        _totalMatieres = totaux;
        _matieresAffectees = affectees;
        _chargementCompteurs = false;
      });
    } catch (e) {
      setState(() => _chargementCompteurs = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _afficherErreur(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: SSMPalette.rouge));
  }

  void _ouvrirClasse(dynamic classe) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/directeur/affectations/classe'),
        builder: (_) => AffectationsClasseScreen(
          classeId: classe['id'] as int,
          classeNom: classe['nom'] as String,
        ),
      ),
    ).then((_) => _chargerCompteurs());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SSMPalette.fond,
      appBar: AppBar(
        title: const Text('Affectations enseignants'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerDonnees,
          ),
        ],
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator(color: SSMPalette.indigo))
          : _classes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.class_outlined, size: 56, color: SSMPalette.texte3),
                  const SizedBox(height: 12),
                  Text(
                    "Aucune classe pour l'instant",
                    style: GoogleFonts.inter(fontSize: 13, color: SSMPalette.texte3),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _classes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final classe = _classes[index];
                final classeId = classe['id'] as int;
                final total = _totalMatieres[classeId];
                final affectees = _matieresAffectees[classeId];
                final complet =
                    total != null &&
                    total > 0 &&
                    affectees != null &&
                    affectees >= total;
                final couleurStatut = complet ? SSMPalette.teal : SSMPalette.ambre;

                return Material(
                  color: SSMPalette.blanc,
                  borderRadius: BorderRadius.circular(SSMRayons.grand),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(SSMRayons.grand),
                    onTap: () => _ouvrirClasse(classe),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(SSMRayons.grand),
                        border: Border.all(color: SSMPalette.bordure),
                      ),
                      child: Row(
                        children: [
                          SSMAvatar(nom: classe['niveau'].toString(), rayon: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  classe['nom'] as String,
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: SSMPalette.texte1),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Niveau : ${classe['niveau']}',
                                  style: GoogleFonts.inter(fontSize: 11.5, color: SSMPalette.texte3),
                                ),
                              ],
                            ),
                          ),
                          _chargementCompteurs
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: SSMPalette.indigo),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      complet ? Icons.check_circle : Icons.warning_amber,
                                      size: 15,
                                      color: couleurStatut,
                                    ),
                                    const SizedBox(width: 5),
                                    SSMPill.couleur(
                                      label: '${affectees ?? 0}/${total ?? 0} affectées',
                                      couleur: couleurStatut,
                                    ),
                                  ],
                                ),
                          const SizedBox(width: 6),
                          Icon(Icons.chevron_right, size: 18, color: SSMPalette.texte3),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
