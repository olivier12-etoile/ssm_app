import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/classe_service.dart';
import '../../services/annee_service.dart';
import '../../services/eleve_service.dart';
import '../../widgets/ssm_widgets.dart';

class SelectionClasseEdtScreen extends StatefulWidget {
  const SelectionClasseEdtScreen({super.key});

  @override
  State<SelectionClasseEdtScreen> createState() =>
      _SelectionClasseEdtScreenState();
}

class _SelectionClasseEdtScreenState extends State<SelectionClasseEdtScreen> {
  List<dynamic> _classes = [];
  Map<int, int> _effectifs = {};
  int? _anneeId;
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _chargerClasses();
  }

  Future<void> _chargerClasses() async {
    try {
      final resultats = await Future.wait([
        ClasseService.listerClasses(),
        AnneeService.listerAnnees(),
      ]);
      final liste  = resultats[0];
      final annees = resultats[1];
      final anneeEnCours = annees.firstWhere(
        (a) => a['statut'] == 'en_cours',
        orElse: () => annees.isNotEmpty ? annees.first : null,
      );

      setState(() {
        _classes    = liste;
        _anneeId    = anneeEnCours?['id'] as int?;
        _chargement = false;
      });

      if (_anneeId != null) await _chargerEffectifs();
    } catch (e) {
      setState(() => _chargement = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _chargerEffectifs() async {
    if (_anneeId == null || _classes.isEmpty) return;
    try {
      final listes = await Future.wait(_classes.map((classe) {
        return EleveService.elevesParClasse(classe['id'] as int, _anneeId!);
      }));

      final effectifs = <int, int>{};
      for (var i = 0; i < _classes.length; i++) {
        effectifs[_classes[i]['id'] as int] = listes[i].length;
      }

      setState(() => _effectifs = effectifs);
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _afficherErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFDC2626),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Emplois du temps',
          style: GoogleFonts.sora(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerClasses,
          ),
        ],
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : _classes.isEmpty
              ? Center(
                  child: Text(
                    'Aucune classe pour l\'instant',
                    style: GoogleFonts.inter(color: const Color(0xFF334155)),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SSMSectionTitre(titre: 'Sélectionnez une classe'),
                    ..._classes.map((classe) {
                      final classeId   = classe['id'] as int;
                      final classeNom  = classe['nom'] as String;
                      final effectif   = _effectifs[classeId] ?? 0;
                      final capaciteMax = (classe['capacite_max'] as int?) ?? 50;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SSMCarteClasse(
                          nom: classeNom,
                          nombreEleves: effectif,
                          capaciteMax: capaciteMax,
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/emploi-du-temps/classe',
                            arguments: {
                              'classeId': classeId,
                              'classeNom': classeNom,
                            },
                          ),
                        ),
                      );
                    }),
                  ],
                ),
    );
  }
}
