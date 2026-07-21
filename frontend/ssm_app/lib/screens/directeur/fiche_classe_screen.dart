import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/classe_service.dart';
import '../../services/annee_service.dart';
import '../../services/eleve_service.dart';
import '../../services/classe_matiere_service.dart';
import '../../services/affectation_service.dart';
import '../../services/emploi_du_temps_service.dart';
import '../../widgets/ssm_widgets.dart';
import 'fiche_utilisateur_screen.dart';
import '../emploi_du_temps/emploi_du_temps_classe_screen.dart';

const List<Map<String, dynamic>> _grilleHoraire = [
  {'debut': '07:00', 'fin': '08:00'},
  {'debut': '08:00', 'fin': '09:00'},
  {'debut': '09:00', 'fin': '10:00'},
  {'debut': '10:00', 'fin': '11:00'},
  {'debut': '11:00', 'fin': '12:00'},
];

const List<Map<String, String>> _jours = [
  {'cle': 'lundi', 'label': 'Lun'},
  {'cle': 'mardi', 'label': 'Mar'},
  {'cle': 'mercredi', 'label': 'Mer'},
  {'cle': 'jeudi', 'label': 'Jeu'},
  {'cle': 'vendredi', 'label': 'Ven'},
];

class FicheClasseScreen extends StatefulWidget {
  final int classeId;
  final String classeNom;

  const FicheClasseScreen({
    super.key,
    required this.classeId,
    required this.classeNom,
  });

  @override
  State<FicheClasseScreen> createState() => _FicheClasseScreenState();
}

class _FicheClasseScreenState extends State<FicheClasseScreen> {
  Map<String, dynamic>? _classe;

  List<dynamic> _eleves = [];
  List<dynamic> _matieresClasse = [];
  List<dynamic> _affectations = [];
  Map<String, dynamic> _emploiDuTemps = {};

  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _chargerDonnees();
  }

  Future<void> _chargerDonnees() async {
    setState(() => _chargement = true);
    try {
      final resultats = await Future.wait([
        ClasseService.listerClasses(),
        AnneeService.listerAnnees(),
        ClasseMatiereService.listerParClasse(widget.classeId),
        AffectationService.listerParClasse(widget.classeId),
      ]);

      final classes = resultats[0];
      final annees   = resultats[1];
      final anneeEnCours = annees.firstWhere(
        (a) => a['statut'] == 'en_cours',
        orElse: () => annees.isNotEmpty ? annees.first : null,
      );
      final anneeId = anneeEnCours?['id'] as int?;

      List<dynamic> eleves = [];
      Map<String, dynamic> emploi = {};
      if (anneeId != null) {
        eleves = await EleveService.elevesParClasse(widget.classeId, anneeId);
        emploi = await EmploiDuTempsService.parClasse(
          classeId: widget.classeId,
          anneeId: anneeId,
        );
      }

      setState(() {
        _classe          = classes.firstWhere(
          (c) => c['id'] == widget.classeId,
          orElse: () => {'nom': widget.classeNom},
        );
        _matieresClasse  = resultats[2];
        _affectations    = resultats[3];
        _eleves          = eleves;
        _emploiDuTemps   = emploi;
        _chargement      = false;
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

  dynamic _affectationPourMatiere(int matiereId) {
    try {
      return _affectations.firstWhere((a) => a['matiere_id'] == matiereId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _appeler(String telephone) async {
    final uri = Uri.parse('tel:$telephone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _modifierCoefficient(dynamic matiere) async {
    final controller = TextEditingController(text: '${matiere['coefficient'] ?? 1}');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Coefficient — ${matiere['matiere_nom']}'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Coefficient', prefixIcon: Icon(Icons.numbers)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
            onPressed: () async {
              final coef = double.tryParse(controller.text.replaceAll(',', '.'));
              if (coef == null || coef <= 0) return;
              try {
                await ClasseMatiereService.ajouter(widget.classeId, matiere['matiere_id'] as int, coef);
                if (context.mounted) Navigator.pop(context);
                _afficherSucces('Coefficient mis à jour');
                _chargerDonnees();
              } catch (e) {
                _afficherErreur(e.toString().replaceAll('Exception: ', ''));
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nom          = _classe?['nom'] as String? ?? widget.classeNom;
    final niveau       = _classe?['niveau'] as String?;
    final capaciteMax  = (_classe?['capacite_max'] as int?) ?? 50;
    final effectif     = _eleves.length;
    final pourcentage  = capaciteMax > 0 ? (effectif / capaciteMax).clamp(0.0, 1.0) : 0.0;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(child: _enTeteClasse(nom, niveau, capaciteMax, effectif, pourcentage)),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                TabBar(
                  labelColor: const Color(0xFF1E3A8A),
                  unselectedLabelColor: const Color(0xFF94A3B8),
                  indicatorColor: const Color(0xFFD97706),
                  labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                  tabs: const [
                    Tab(text: 'Élèves'),
                    Tab(text: 'Enseignants'),
                    Tab(text: 'Matières'),
                    Tab(text: 'Emploi du temps'),
                  ],
                ),
              ),
            ),
          ],
          body: _chargement
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  children: [
                    _tabEleves(),
                    _tabEnseignants(),
                    _tabMatieres(),
                    _tabEmploiDuTemps(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _enTeteClasse(String nom, String? niveau, int capaciteMax, int effectif, double pourcentage) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(color: Color(0xFF1E3A8A)),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    nom,
                    style: GoogleFonts.sora(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                '$effectif élève(s) inscrit(s)',
                style: GoogleFonts.inter(fontSize: 14, color: Colors.white.withValues(alpha: 0.7)),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pourcentage,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  color: const Color(0xFFD97706),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '$effectif / $capaciteMax élèves',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                if (niveau != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
                    child: Text(niveau, style: GoogleFonts.inter(fontSize: 12, color: Colors.white)),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
                  child: Text('Capacité : $capaciteMax', style: GoogleFonts.inter(fontSize: 12, color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // TAB 1 — ÉLÈVES
  // ══════════════════════════════════════════════════════

  Widget _tabEleves() {
    if (_eleves.isEmpty) {
      return Center(
        child: Text('Aucun élève inscrit', style: GoogleFonts.inter(color: const Color(0xFF334155))),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _eleves.length,
      itemBuilder: (context, index) {
        final e = _eleves[index];
        final photoUrl = e['photo_url'] as String?;
        final nomComplet = '${e['nom']} ${e['prenom']}';
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFF1E3A8A).withValues(alpha: 0.15),
                backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                child: photoUrl == null
                    ? Text((e['nom'] as String).substring(0, 1).toUpperCase(),
                        style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: const Color(0xFF1E3A8A)))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nomComplet, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600)),
                    Text('Matricule : ${e['matricule']}',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/eleve/fiche', arguments: {'eleveId': e['id']}),
                child: const Text('Voir fiche'),
              ),
            ],
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════
  // TAB 2 — ENSEIGNANTS
  // ══════════════════════════════════════════════════════

  Widget _tabEnseignants() {
    if (_matieresClasse.isEmpty) {
      return Center(
        child: Text('Aucune matière configurée pour cette classe', style: GoogleFonts.inter(color: const Color(0xFF334155))),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _matieresClasse.length,
      itemBuilder: (context, index) {
        final matiere = _matieresClasse[index];
        final affectation = _affectationPourMatiere(matiere['matiere_id'] as int);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: affectation == null
              ? Row(
                  children: [
                    const Icon(Icons.person_off, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(matiere['matiere_nom'] as String,
                          style: GoogleFonts.sora(fontWeight: FontWeight.w600)),
                    ),
                    SSMBadge(label: 'Non affecté', couleur: const Color(0xFFEA580C)),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFF1E3A8A).withValues(alpha: 0.15),
                      backgroundImage: affectation['enseignant_photo_url'] != null
                          ? NetworkImage(affectation['enseignant_photo_url'] as String)
                          : null,
                      child: affectation['enseignant_photo_url'] == null
                          ? Text((affectation['enseignant_nom'] as String).substring(0, 1).toUpperCase(),
                              style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: const Color(0xFF1E3A8A)))
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(affectation['enseignant_nom'] as String,
                              style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${matiere['matiere_nom']} (coef ${affectation['coefficient'] ?? matiere['coefficient'] ?? 1})',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF0D9488)),
                            ),
                          ),
                          if (affectation['enseignant_telephone'] != null) ...[
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () => _appeler(affectation['enseignant_telephone'] as String),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.phone, size: 13, color: Color(0xFF1E3A8A)),
                                  const SizedBox(width: 4),
                                  Text(affectation['enseignant_telephone'] as String,
                                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF1E3A8A))),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FicheUtilisateurScreen(userId: affectation['enseignant_id'] as int),
                        ),
                      ),
                      child: const Text('Voir profil'),
                    ),
                  ],
                ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════
  // TAB 3 — MATIÈRES
  // ══════════════════════════════════════════════════════

  Widget _tabMatieres() {
    if (_matieresClasse.isEmpty) {
      return Center(
        child: Text('Aucune matière configurée pour cette classe', style: GoogleFonts.inter(color: const Color(0xFF334155))),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _matieresClasse.length,
      itemBuilder: (context, index) {
        final matiere = _matieresClasse[index];
        final affectation = _affectationPourMatiere(matiere['matiere_id'] as int);
        final nomEnseignant = affectation != null ? affectation['enseignant_nom'] as String : 'Non affecté';

        return SSMListeTile(
          titre: matiere['matiere_nom'] as String,
          sousTitre: 'Coefficient : ${matiere['coefficient']}  •  Enseignant : $nomEnseignant',
          icone: Icons.book,
          couleurIcone: const Color(0xFF1E3A8A),
          trailing: IconButton(
            icon: const Icon(Icons.edit, size: 18, color: Color(0xFF1E3A8A)),
            onPressed: () => _modifierCoefficient(matiere),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════
  // TAB 4 — EMPLOI DU TEMPS
  // ══════════════════════════════════════════════════════

  dynamic _creneauPourCellule(String jour, String heureDebut) {
    final liste = (_emploiDuTemps[jour] as List?) ?? [];
    try {
      return liste.firstWhere((c) => (c['heure_debut'] as String).substring(0, 5) == heureDebut);
    } catch (_) {
      return null;
    }
  }

  Widget _tabEmploiDuTemps() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EmploiDuTempsClasseScreen(classeId: widget.classeId, classeNom: widget.classeNom),
                ),
              ),
              icon: const Icon(Icons.open_in_full, size: 16),
              label: const Text('Voir en plein écran'),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    width: 60 + (5 * 110),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const SizedBox(width: 48),
                            ..._jours.map((j) => Expanded(
                                  child: Center(
                                    child: Text(j['label']!,
                                        style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w700)),
                                  ),
                                )),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ..._grilleHoraire.map((row) {
                          final debut = row['debut'] as String;
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 48,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(debut, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
                                ),
                              ),
                              ..._jours.map((j) {
                                final c = _creneauPourCellule(j['cle']!, debut);
                                return Expanded(
                                  child: Container(
                                    height: 50,
                                    margin: const EdgeInsets.all(2),
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: c != null
                                          ? const Color(0xFF1E3A8A).withValues(alpha: 0.1)
                                          : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: c != null
                                        ? Text(
                                            c['matiere_nom'] as String,
                                            style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: const Color(0xFF1E3A8A)),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          )
                                        : null,
                                  ),
                                );
                              }),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: const Color(0xFFF8FAFC), child: tabBar);
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}
