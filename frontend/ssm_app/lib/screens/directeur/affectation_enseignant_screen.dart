import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/affectation_service.dart';
import '../../services/classe_service.dart';
import '../../services/classe_matiere_service.dart';
import '../../widgets/ssm_widgets.dart';

class AffectationEnseignantScreen extends StatefulWidget {
  final int userId;
  final String userName;

  const AffectationEnseignantScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<AffectationEnseignantScreen> createState() =>
      _AffectationEnseignantScreenState();
}

class _AffectationEnseignantScreenState
    extends State<AffectationEnseignantScreen> {
  List<dynamic> _classes = [];
  Map<int, List<dynamic>> _matieresParClasse = {};
  Map<int, Map<int, int>> _affectationsParClasse = {}; // classeId -> {matiereId: affectationId}
  Map<int, Set<int>> _selections = {}; // classeId -> matiereIds cochées dans l'UI

  bool _chargement = true;
  int? _classeEnEnregistrement;

  @override
  void initState() {
    super.initState();
    _chargerDonnees();
  }

  Future<void> _chargerDonnees() async {
    setState(() => _chargement = true);
    try {
      final classes = await ClasseService.listerClasses();

      final matieresParClasse = <int, List<dynamic>>{};
      await Future.wait(classes.map((c) async {
        final classeId = c['id'] as int;
        matieresParClasse[classeId] =
            await ClasseMatiereService.listerParClasse(classeId);
      }));

      final donneesAffectations =
          await AffectationService.listerAffectations(widget.userId);
      final affectations =
          (donneesAffectations['affectations'] as List?) ?? [];

      final affectationsParClasse = <int, Map<int, int>>{};
      final selections = <int, Set<int>>{};
      for (final classe in classes) {
        final classeId = classe['id'] as int;
        affectationsParClasse[classeId] = {};
        selections[classeId] = {};
      }
      for (final a in affectations) {
        final classeId = a['classe_id'] as int;
        final matiereId = a['matiere_id'] as int;
        affectationsParClasse.putIfAbsent(classeId, () => {});
        affectationsParClasse[classeId]![matiereId] = a['id'] as int;
        selections.putIfAbsent(classeId, () => {});
        selections[classeId]!.add(matiereId);
      }

      setState(() {
        _classes                = classes;
        _matieresParClasse      = matieresParClasse;
        _affectationsParClasse  = affectationsParClasse;
        _selections             = selections;
        _chargement             = false;
      });
    } catch (e) {
      setState(() => _chargement = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _afficherErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFFDC2626)),
    );
  }

  void _afficherSucces(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFF16A34A)),
    );
  }

  Future<void> _enregistrerClasse(int classeId) async {
    setState(() => _classeEnEnregistrement = classeId);

    final affecteesInitiales = _affectationsParClasse[classeId] ?? {};
    final selectionActuelle  = _selections[classeId] ?? {};

    try {
      // Nouvelles cases cochées → créer l'affectation
      for (final matiereId in selectionActuelle) {
        if (!affecteesInitiales.containsKey(matiereId)) {
          await AffectationService.ajouterAffectation(
            enseignantId: widget.userId,
            classeId:     classeId,
            matiereId:    matiereId,
          );
        }
      }
      // Cases décochées → supprimer l'affectation
      for (final entry in affecteesInitiales.entries) {
        if (!selectionActuelle.contains(entry.key)) {
          await AffectationService.supprimerAffectation(entry.value);
        }
      }

      _afficherSucces('Affectations mises à jour');
      await _chargerDonnees();
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _classeEnEnregistrement = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: _blob(size: 260, couleur: const Color(0xFF1E3A8A).withValues(alpha: 0.06)),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: _blob(size: 200, couleur: const Color(0xFF0D9488).withValues(alpha: 0.08)),
          ),
          SafeArea(
            child: Column(
              children: [
                _appBarGlass(context),
                Expanded(
                  child: _chargement
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: _chargerDonnees,
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              SSMSectionTitre(titre: 'Classes et matières affectées'),
                              if (_classes.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Aucune classe pour l\'instant',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                )
                              else
                                ..._classes.map((c) => _carteClasse(c)),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _blob({required double size, required Color couleur}) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: couleur),
        ),
      ),
    );
  }

  Widget _appBarGlass(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.7))),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 16),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Text(
                  'Affectations — ${widget.userName}',
                  style: GoogleFonts.sora(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Color(0xFF1E3A8A)),
                onPressed: _chargerDonnees,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _carteClasse(dynamic classe) {
    final classeId  = classe['id'] as int;
    final classeNom = classe['nom'] as String;
    final matieres  = _matieresParClasse[classeId] ?? [];
    final selection = _selections[classeId] ?? {};
    final enregistrementEnCours = _classeEnEnregistrement == classeId;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  classeNom,
                  style: GoogleFonts.sora(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                if (matieres.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Aucune matière configurée pour cette classe',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                    ),
                  )
                else
                  ...matieres.map((m) {
                    final matiereId  = m['matiere_id'] as int;
                    final matiereNom = m['matiere_nom'] as String;
                    return CheckboxListTile(
                      value: selection.contains(matiereId),
                      onChanged: (v) {
                        setState(() {
                          final ensemble = _selections.putIfAbsent(classeId, () => {});
                          if (v == true) {
                            ensemble.add(matiereId);
                          } else {
                            ensemble.remove(matiereId);
                          }
                        });
                      },
                      activeColor: const Color(0xFF1E3A8A),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                      title: Text(
                        matiereNom,
                        style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF334155)),
                      ),
                    );
                  }),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: enregistrementEnCours ? null : () => _enregistrerClasse(classeId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: enregistrementEnCours
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text('Enregistrer', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
