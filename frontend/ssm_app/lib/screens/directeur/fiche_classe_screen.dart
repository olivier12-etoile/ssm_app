import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';
import '../../services/classe_service.dart';
import '../../services/annee_service.dart';
import '../../services/eleve_service.dart';
import '../../services/classe_matiere_service.dart';
import '../../services/affectation_service.dart';
import '../../services/emploi_du_temps_service.dart';
import '../../services/cahier_texte_service.dart';
import '../../services/matiere_service.dart';
import '../../services/utilisateur_service.dart';
import '../../widgets/ssm_widgets.dart';
import 'fiche_utilisateur_screen.dart';
import '../emploi_du_temps/emploi_du_temps_classe_screen.dart';

const List<Map<String, dynamic>> _grilleHoraire = [
  {'debut': '07:00', 'fin': '08:00', 'recreation': false},
  {'debut': '08:00', 'fin': '09:00', 'recreation': false},
  {'debut': '09:00', 'fin': '10:00', 'recreation': false},
  {'debut': '10:00', 'fin': '10:15', 'recreation': true},
  {'debut': '10:00', 'fin': '11:00', 'recreation': false},
  {'debut': '11:00', 'fin': '12:00', 'recreation': false},
];

const List<Map<String, String>> _jours = [
  {'cle': 'lundi', 'label': 'Lundi'},
  {'cle': 'mardi', 'label': 'Mardi'},
  {'cle': 'mercredi', 'label': 'Mercredi'},
  {'cle': 'jeudi', 'label': 'Jeudi'},
  {'cle': 'vendredi', 'label': 'Vendredi'},
];

const List<Color> _paletteMatieres = [
  Color(0xFFBBDEFB), Color(0xFFC8E6C9), Color(0xFFFFE0B2), Color(0xFFF8BBD0),
  Color(0xFFD1C4E9), Color(0xFFB2EBF2), Color(0xFFFFF9C4), Color(0xFFD7CCC8),
  Color(0xFFC5CAE9), Color(0xFFDCEDC8),
];

Color _couleurMatiere(int matiereId) => _paletteMatieres[matiereId % _paletteMatieres.length];

const List<String> _niveaux = [
  '6ème', '5ème', '4ème', '3ème', 'Seconde', 'Première', 'Terminale',
];

class FicheClasseScreen extends StatefulWidget {
  final int classeId;

  const FicheClasseScreen({super.key, required this.classeId});

  @override
  State<FicheClasseScreen> createState() => _FicheClasseScreenState();
}

class _FicheClasseScreenState extends State<FicheClasseScreen> {
  Map<String, dynamic>? _classe;
  List<dynamic> _enseignants = [];
  List<dynamic> _matieresClasse = [];
  Map<String, dynamic>? _statistiques;

  List<dynamic> _eleves = [];
  Map<String, dynamic> _emploiDuTemps = {};
  List<dynamic> _cahierTexte = [];

  List<dynamic> _toutesMatieres = [];
  List<dynamic> _tousEnseignants = [];
  List<dynamic> _toutesClasses = [];
  int? _anneeId;
  dynamic _utilisateurConnecte;

  bool _chargement = true;
  String _rechercheEleve = '';
  int? _filtreMatiereCahier;

  @override
  void initState() {
    super.initState();
    _chargerTout();
  }

  Future<void> _chargerTout() async {
    setState(() => _chargement = true);
    try {
      final utilisateur = await AuthService.getUtilisateur();
      final details = await ClasseService.details(widget.classeId);
      final classe = details['classe'] as Map<String, dynamic>;

      final annees = await AnneeService.listerAnnees();
      int? anneeId = classe['annee_academique_id'] as int?;
      if (anneeId == null) {
        final anneeEnCours = annees.firstWhere(
          (a) => a['statut'] == 'en_cours',
          orElse: () => annees.isNotEmpty ? annees.first : null,
        );
        anneeId = anneeEnCours?['id'] as int?;
      }

      List<dynamic> eleves = [];
      Map<String, dynamic> emploi = {};
      if (anneeId != null) {
        final resultats = await Future.wait([
          EleveService.elevesParClasse(widget.classeId, anneeId),
          EmploiDuTempsService.parClasse(classeId: widget.classeId, anneeId: anneeId),
        ]);
        eleves = resultats[0] as List;
        emploi = resultats[1] as Map<String, dynamic>;
      }

      final cahier = await CahierTexteService.historiqueClasse(widget.classeId);

      setState(() {
        _utilisateurConnecte = utilisateur;
        _classe          = classe;
        _enseignants     = details['enseignants'] as List;
        _matieresClasse  = details['matieres'] as List;
        _statistiques    = details['statistiques'] as Map<String, dynamic>;
        _anneeId         = anneeId;
        _eleves          = eleves;
        _emploiDuTemps   = emploi;
        _cahierTexte     = cahier;
        _chargement      = false;
      });

      _chargerReferences();
    } catch (e) {
      setState(() => _chargement = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _chargerReferences() async {
    try {
      final toutesMatieres = await MatiereService.listerMatieres();

      final tousEnseignants = <dynamic>[];
      var page = 1;
      while (true) {
        final resultat = await UtilisateurService.lister(role: 'enseignant', page: page);
        tousEnseignants.addAll((resultat['data'] as List?) ?? []);
        final dernierePage = resultat['last_page'] as int? ?? 1;
        if (page >= dernierePage) break;
        page++;
      }

      final toutesClasses = await ClasseService.listerClasses();

      setState(() {
        _toutesMatieres  = toutesMatieres;
        _tousEnseignants = tousEnseignants;
        _toutesClasses   = toutesClasses;
      });
    } catch (_) {
      // Listes de référence non bloquantes.
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

  void _bientot() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fonctionnalité à venir')),
    );
  }

  dynamic _affectationPourMatiere(int matiereId) {
    try {
      return _enseignants.firstWhere((a) => a['matiere_id'] == matiereId);
    } catch (_) {
      return null;
    }
  }

  Map<int, List<dynamic>> get _matieresParEnseignant {
    final map = <int, List<dynamic>>{};
    for (final a in _enseignants) {
      final id = a['enseignant_id'] as int;
      map.putIfAbsent(id, () => []).add(a);
    }
    return map;
  }

  double _dureeEnHeures(String debut, String fin) {
    final d = debut.split(':').map(int.parse).toList();
    final f = fin.split(':').map(int.parse).toList();
    return ((f[0] * 60 + f[1]) - (d[0] * 60 + d[1])) / 60;
  }

  List<dynamic> _creneauxPour({int? enseignantId, int? matiereId}) {
    final resultat = <dynamic>[];
    for (final jour in _jours) {
      final liste = (_emploiDuTemps[jour['cle']] as List?) ?? [];
      for (final c in liste) {
        if (enseignantId != null && c['enseignant_id'] != enseignantId) continue;
        if (matiereId != null && c['matiere_id'] != matiereId) continue;
        resultat.add({...c, 'jour_label': jour['label']});
      }
    }
    return resultat;
  }

  Future<void> _appeler(String telephone) async {
    final uri = Uri.parse('tel:$telephone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 7,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: _chargement || _classe == null
            ? const Center(child: CircularProgressIndicator())
            : NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverToBoxAdapter(child: _heroHeader(context)),
                  SliverPersistentHeader(pinned: true, delegate: _TabBarDelegate(_tabBar())),
                ],
                body: TabBarView(
                  children: [
                    _tabInfos(),
                    _tabEleves(),
                    _tabProfesseurs(),
                    _tabMatieres(),
                    _tabEmploiDuTemps(),
                    _tabStatistiques(),
                    _tabCahierTexte(),
                  ],
                ),
              ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // EN-TÊTE HERO
  // ══════════════════════════════════════════════════════

  Widget _heroHeader(BuildContext context) {
    final classe        = _classe!;
    final nom           = classe['nom'] as String;
    final niveau        = classe['niveau'] as String? ?? '';
    final serie         = classe['serie'] as String?;
    final salle         = classe['salle'] as String?;
    final nombreEleves  = (classe['nombre_eleves'] as num?)?.toInt() ?? 0;
    final capaciteMax   = (classe['capacite_max'] as num?)?.toInt() ?? 50;
    final nombreMatieres = _matieresClasse.length;
    final nombreProfs   = _enseignants.map((e) => e['enseignant_id']).toSet().length;
    final pourcentage   = capaciteMax > 0 ? (nombreEleves / capaciteMax).clamp(0.0, 1.0) : 0.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + kToolbarHeight, 24, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF0D9488)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(nom, style: GoogleFonts.sora(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              _badgeBlanc(niveau),
              if (serie != null) _badgeBlanc(serie),
              if (salle != null) _badgeBlanc(salle),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _statHero(Icons.people, '$nombreEleves élèves')),
              Expanded(child: _statHero(Icons.book, '$nombreMatieres matières')),
              Expanded(child: _statHero(Icons.school, '$nombreProfs profs')),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pourcentage,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text('$nombreEleves / $capaciteMax', style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  Widget _badgeBlanc(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
    );
  }

  Widget _statHero(IconData icone, String label) {
    return Row(
      children: [
        Icon(icone, size: 15, color: Colors.white.withValues(alpha: 0.8)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.9)), overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _tabBar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: Colors.white.withValues(alpha: 0.95),
          child: TabBar(
            isScrollable: true,
            labelColor: const Color(0xFF1E3A8A),
            unselectedLabelColor: const Color(0xFF94A3B8),
            indicatorColor: const Color(0xFFD97706),
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
            tabs: const [
              Tab(text: '📋 Infos'),
              Tab(text: '👥 Élèves'),
              Tab(text: '👨‍🏫 Profs'),
              Tab(text: '📚 Matières'),
              Tab(text: '📅 EDT'),
              Tab(text: '📊 Stats'),
              Tab(text: '📖 Cahier'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _carteGlass({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: child,
    );
  }

  // ══════════════════════════════════════════════════════
  // TAB 1 — INFOS GÉNÉRALES
  // ══════════════════════════════════════════════════════

  Widget _tabInfos() {
    final classe    = _classe!;
    final prof      = classe['professeur_principal'] as Map<String, dynamic>?;
    final annee     = classe['annee'] as Map<String, dynamic>?;
    final statut    = classe['statut'] as String? ?? 'active';
    final actif     = statut == 'active';
    final createdAt = (classe['created_at'] as String?)?.split('T').first;
    final nombreEleves = (classe['nombre_eleves'] as num?)?.toInt() ?? 0;
    final capaciteMax  = (classe['capacite_max'] as num?)?.toInt() ?? 50;
    final pourcentage  = capaciteMax > 0 ? (nombreEleves / capaciteMax).clamp(0.0, 1.0) : 0.0;

    return RefreshIndicator(
      onRefresh: _chargerTout,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _carteGlass(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ligneInfo(Icons.class_, 'Nom', classe['nom'] as String),
                _ligneInfo(Icons.layers, 'Niveau', classe['niveau'] as String? ?? '—'),
                _ligneInfo(Icons.bookmark_outline, 'Série', classe['serie'] as String? ?? '—'),
                _ligneInfo(Icons.room, 'Salle', classe['salle'] as String? ?? '—'),
              ],
            ),
          ),
          _carteGlass(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Capacité', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pourcentage,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFF1F5F9),
                    color: pourcentage >= 1
                        ? const Color(0xFFDC2626)
                        : pourcentage >= 0.8
                            ? const Color(0xFFEA580C)
                            : const Color(0xFF16A34A),
                  ),
                ),
                const SizedBox(height: 4),
                Text('$nombreEleves / $capaciteMax élèves', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF334155))),
              ],
            ),
          ),
          _carteGlass(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Professeur principal', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
                const SizedBox(height: 8),
                if (prof != null)
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFF1E3A8A).withValues(alpha: 0.15),
                        backgroundImage: prof['photo_url'] != null ? NetworkImage(prof['photo_url'] as String) : null,
                        child: prof['photo_url'] == null
                            ? Text((prof['name'] as String).substring(0, 1).toUpperCase(),
                                style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: const Color(0xFF1E3A8A)))
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Text(prof['name'] as String, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  )
                else
                  Text('Non défini', style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF94A3B8))),
              ],
            ),
          ),
          _carteGlass(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ligneInfo(Icons.calendar_month, 'Année académique', annee?['libelle'] as String? ?? '—'),
                _ligneInfo(Icons.event, 'Créée le', createdAt ?? '—'),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 10),
                      Text('Statut : ', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF334155))),
                      SSMBadge(label: actif ? 'ACTIVE' : 'INACTIVE', couleur: actif ? const Color(0xFF16A34A) : const Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _afficherDialogModifierClasse,
                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF1E3A8A), side: const BorderSide(color: Color(0xFF1E3A8A))),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Modifier'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: actif
                    ? OutlinedButton.icon(
                        onPressed: _archiverClasse,
                        style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFDC2626), side: const BorderSide(color: Color(0xFFDC2626))),
                        icon: const Icon(Icons.archive_outlined, size: 16),
                        label: const Text('Archiver'),
                      )
                    : OutlinedButton.icon(
                        onPressed: _activerClasse,
                        style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF16A34A), side: const BorderSide(color: Color(0xFF16A34A))),
                        icon: const Icon(Icons.check_circle_outline, size: 16),
                        label: const Text('Activer'),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _ligneInfo(IconData icone, String label, String valeur) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icone, size: 16, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 10),
          Text('$label : ', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF334155))),
          Expanded(child: Text(valeur, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Future<void> _archiverClasse() async {
    try {
      await ClasseService.archiver(widget.classeId);
      _afficherSucces('Classe archivée');
      _chargerTout();
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _activerClasse() async {
    try {
      await ClasseService.activer(widget.classeId);
      _afficherSucces('Classe réactivée');
      _chargerTout();
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _afficherDialogModifierClasse() async {
    final classe = _classe!;
    final nomController      = TextEditingController(text: classe['nom'] as String);
    final serieController    = TextEditingController(text: classe['serie'] as String? ?? '');
    final salleController    = TextEditingController(text: classe['salle'] as String? ?? '');
    final capaciteController = TextEditingController(text: '${classe['capacite_max'] ?? 50}');
    String niveau = classe['niveau'] as String? ?? _niveaux.first;
    String statut = classe['statut'] as String? ?? 'active';
    int? professeurPrincipalId = classe['professeur_principal_id'] as int?;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500, maxHeight: 640),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Modifier la classe', style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(controller: nomController, decoration: const InputDecoration(labelText: 'Nom *', prefixIcon: Icon(Icons.class_))),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _niveaux.contains(niveau) ? niveau : null,
                              decoration: const InputDecoration(labelText: 'Niveau *', prefixIcon: Icon(Icons.layers)),
                              items: _niveaux.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
                              onChanged: (v) => setStateDialog(() => niveau = v ?? niveau),
                            ),
                            const SizedBox(height: 12),
                            TextField(controller: serieController, decoration: const InputDecoration(labelText: 'Série', prefixIcon: Icon(Icons.bookmark_outline))),
                            const SizedBox(height: 12),
                            TextField(controller: salleController, decoration: const InputDecoration(labelText: 'Salle', prefixIcon: Icon(Icons.room))),
                            const SizedBox(height: 12),
                            TextField(
                              controller: capaciteController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Capacité max *', prefixIcon: Icon(Icons.people)),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Text('Statut :', style: GoogleFonts.inter(fontSize: 14)),
                                const SizedBox(width: 12),
                                SegmentedButton<String>(
                                  segments: const [
                                    ButtonSegment(value: 'active', label: Text('Active')),
                                    ButtonSegment(value: 'inactive', label: Text('Inactive')),
                                  ],
                                  selected: {statut},
                                  onSelectionChanged: (s) => setStateDialog(() => statut = s.first),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<int>(
                              value: professeurPrincipalId,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Professeur principal', prefixIcon: Icon(Icons.school)),
                              hint: const Text('Aucun'),
                              items: _tousEnseignants.map((e) => DropdownMenuItem<int>(value: e['id'] as int, child: Text(e['name'] as String))).toList(),
                              onChanged: (v) => setStateDialog(() => professeurPrincipalId = v),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler'))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
                            onPressed: () async {
                              try {
                                await ClasseService.modifier(
                                  widget.classeId,
                                  nom: nomController.text,
                                  niveau: niveau,
                                  serie: serieController.text.isEmpty ? null : serieController.text,
                                  salle: salleController.text.isEmpty ? null : salleController.text,
                                  capaciteMax: int.tryParse(capaciteController.text),
                                  statut: statut,
                                  professeurPrincipalId: professeurPrincipalId,
                                );
                                if (context.mounted) Navigator.pop(context);
                                _afficherSucces('Classe modifiée avec succès');
                                _chargerTout();
                              } catch (e) {
                                _afficherErreur(e.toString().replaceAll('Exception: ', ''));
                              }
                            },
                            child: const Text('Enregistrer'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // TAB 2 — ÉLÈVES
  // ══════════════════════════════════════════════════════

  List<dynamic> get _elevesFiltres {
    if (_rechercheEleve.isEmpty) return _eleves;
    final q = _rechercheEleve.toLowerCase();
    return _eleves.where((e) {
      return (e['nom'] as String).toLowerCase().contains(q) ||
          (e['prenom'] as String).toLowerCase().contains(q) ||
          (e['matricule'] as String).toLowerCase().contains(q);
    }).toList();
  }

  Widget _tabEleves() {
    return RefreshIndicator(
      onRefresh: _chargerTout,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${_eleves.length} élève(s) inscrit(s)', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => setState(() => _rechercheEleve = v),
            decoration: const InputDecoration(labelText: 'Rechercher un élève', prefixIcon: Icon(Icons.search)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _afficherDialogAjouterEleve,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
                icon: const Icon(Icons.person_add, size: 16),
                label: const Text('Ajouter un élève'),
              ),
              ElevatedButton.icon(
                onPressed: () => _afficherDialogTransfert(),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white),
                icon: const Icon(Icons.compare_arrows, size: 16),
                label: const Text('Transférer'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  try {
                    final chemin = await ClasseService.exporterPdf(widget.classeId);
                    await OpenFile.open(chemin);
                  } catch (e) {
                    _afficherErreur(e.toString().replaceAll('Exception: ', ''));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
                icon: const Icon(Icons.picture_as_pdf, size: 16),
                label: const Text('Imprimer liste'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  try {
                    final chemin = await ClasseService.exporterExcel(widget.classeId);
                    await OpenFile.open(chemin);
                  } catch (e) {
                    _afficherErreur(e.toString().replaceAll('Exception: ', ''));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white),
                icon: const Icon(Icons.table_chart, size: 16),
                label: const Text('Export Excel'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_elevesFiltres.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Aucun élève', style: GoogleFonts.inter(color: const Color(0xFF334155)))),
            )
          else
            ..._elevesFiltres.map(_carteEleve),
        ],
      ),
    );
  }

  Widget _carteEleve(dynamic eleve) {
    final photoUrl = eleve['photo_url'] as String?;
    final sexe     = eleve['sexe'] as String?;
    final statut   = eleve['inscription_statut'] as String?;

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
                ? Text((eleve['nom'] as String).substring(0, 1).toUpperCase(),
                    style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: const Color(0xFF1E3A8A)))
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${eleve['nom']} ${eleve['prenom']}', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600)),
                Text(eleve['matricule'] as String, style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF94A3B8))),
              ],
            ),
          ),
          Icon(sexe == 'M' ? Icons.boy : Icons.girl, color: sexe == 'M' ? const Color(0xFF0284C7) : const Color(0xFFEC4899), size: 20),
          const SizedBox(width: 6),
          if (statut != null) SSMBadge(label: statut.toUpperCase(), couleur: const Color(0xFF16A34A)),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFF334155)),
            onSelected: (action) {
              switch (action) {
                case 'fiche':
                  Navigator.pushNamed(context, '/eleve/fiche', arguments: {'eleveId': eleve['id']});
                  break;
                case 'transferer':
                  _afficherDialogTransfert(eleveIdPreselectionne: eleve['id'] as int);
                  break;
                case 'retirer':
                  _bientot();
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'fiche', child: Text('Voir fiche')),
              PopupMenuItem(value: 'transferer', child: Text('Transférer')),
              PopupMenuItem(value: 'retirer', child: Text('Retirer')),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _afficherDialogAjouterEleve() async {
    final nomController    = TextEditingController();
    final prenomController = TextEditingController();
    String sexe = 'M';

    if (_anneeId == null) {
      _afficherErreur('Aucune année académique active');
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Ajouter un élève'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nomController, decoration: const InputDecoration(labelText: 'Nom')),
                const SizedBox(height: 12),
                TextField(controller: prenomController, decoration: const InputDecoration(labelText: 'Prénom')),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'M', label: Text('M')),
                    ButtonSegment(value: 'F', label: Text('F')),
                  ],
                  selected: {sexe},
                  onSelectionChanged: (s) => setStateDialog(() => sexe = s.first),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
              ElevatedButton(
                onPressed: () async {
                  if (nomController.text.isEmpty || prenomController.text.isEmpty) return;
                  try {
                    await EleveService.creerEleve(
                      nom: nomController.text,
                      prenom: prenomController.text,
                      sexe: sexe,
                      classeId: widget.classeId,
                      anneeAcademiqueId: _anneeId!,
                    );
                    if (context.mounted) Navigator.pop(context);
                    _afficherSucces('Élève ajouté avec succès');
                    _chargerTout();
                  } catch (e) {
                    _afficherErreur(e.toString().replaceAll('Exception: ', ''));
                  }
                },
                child: const Text('Ajouter'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _afficherDialogTransfert({int? eleveIdPreselectionne}) async {
    int? eleveId = eleveIdPreselectionne;
    int? classeDestinationId;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Transférer un élève'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (eleveIdPreselectionne == null)
                  DropdownButtonFormField<int>(
                    value: eleveId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Élève'),
                    items: _eleves.map((e) => DropdownMenuItem<int>(value: e['id'] as int, child: Text('${e['nom']} ${e['prenom']}'))).toList(),
                    onChanged: (v) => setStateDialog(() => eleveId = v),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: classeDestinationId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Classe de destination'),
                  items: _toutesClasses
                      .where((c) => c['id'] != widget.classeId)
                      .map((c) => DropdownMenuItem<int>(value: c['id'] as int, child: Text(c['nom'] as String)))
                      .toList(),
                  onChanged: (v) => setStateDialog(() => classeDestinationId = v),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
              ElevatedButton(
                onPressed: eleveId == null || classeDestinationId == null
                    ? null
                    : () async {
                        try {
                          await ClasseService.transfererEleve(
                            eleveId: eleveId!,
                            classeSourceId: widget.classeId,
                            classeDestinationId: classeDestinationId!,
                          );
                          if (context.mounted) Navigator.pop(context);
                          _afficherSucces('Élève transféré avec succès');
                          _chargerTout();
                        } catch (e) {
                          _afficherErreur(e.toString().replaceAll('Exception: ', ''));
                        }
                      },
                child: const Text('Confirmer'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // TAB 3 — PROFESSEURS
  // ══════════════════════════════════════════════════════

  Widget _tabProfesseurs() {
    final prof = _classe!['professeur_principal'] as Map<String, dynamic>?;
    final matieresProfPrincipal = prof != null
        ? _enseignants.where((e) => e['enseignant_id'] == _classe!['professeur_principal_id']).toList()
        : <dynamic>[];

    final matieresNonAffectees = _matieresClasse.where((m) => _affectationPourMatiere(m['matiere_id'] as int) == null).toList();

    return RefreshIndicator(
      onRefresh: _chargerTout,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (prof != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFD97706).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SSMBadge(label: 'PROFESSEUR PRINCIPAL', couleur: Color(0xFFD97706)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: const Color(0xFFD97706).withValues(alpha: 0.15),
                        backgroundImage: prof['photo_url'] != null ? NetworkImage(prof['photo_url'] as String) : null,
                        child: prof['photo_url'] == null
                            ? Text((prof['name'] as String).substring(0, 1).toUpperCase(),
                                style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFFD97706)))
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(prof['name'] as String, style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700)),
                            if (matieresProfPrincipal.isNotEmpty)
                              Wrap(
                                spacing: 6,
                                children: matieresProfPrincipal
                                    .map((m) => Text('${m['matiere_nom']} ', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF334155))))
                                    .toList(),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          SSMSectionTitre(titre: 'Enseignants'),
          if (_matieresParEnseignant.isEmpty)
            Text('Aucun enseignant affecté', style: GoogleFonts.inter(color: const Color(0xFF334155)))
          else
            ..._matieresParEnseignant.entries.map((entry) => _carteEnseignant(entry.key, entry.value)),

          if (matieresNonAffectees.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFEA580C).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Non affectées', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFFEA580C))),
                  const SizedBox(height: 8),
                  ...matieresNonAffectees.map((m) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(child: Text(m['matiere_nom'] as String, style: GoogleFonts.inter(fontSize: 13))),
                            TextButton(
                              onPressed: () => _afficherDialogAffecterMatiere(m['matiere_id'] as int, m['matiere_nom'] as String),
                              child: const Text('Affecter'),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _carteEnseignant(int enseignantId, List<dynamic> matieres) {
    final premiere = matieres.first;
    final telephone = premiere['enseignant_telephone'] as String?;
    final photoUrl  = premiere['enseignant_photo_url'] as String?;
    final horaires  = _creneauxPour(enseignantId: enseignantId);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFF1E3A8A).withValues(alpha: 0.15),
                backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                child: photoUrl == null
                    ? Text((premiere['enseignant_nom'] as String).substring(0, 1).toUpperCase(),
                        style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: const Color(0xFF1E3A8A)))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(premiere['enseignant_nom'] as String, style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => FicheUtilisateurScreen(userId: enseignantId)),
                ),
                child: const Text('Voir profil'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: matieres.map((m) {
              final coef = m['coefficient'];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF0D9488).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                child: Text(
                  coef != null ? '${m['matiere_nom']} (coef $coef)' : '${m['matiere_nom']}',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF0D9488)),
                ),
              );
            }).toList(),
          ),
          if (horaires.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              horaires.map((h) => '${h['jour_label']} ${(h['heure_debut'] as String).substring(0, 5)}').join(' • '),
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
            ),
          ],
          if (telephone != null) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => _appeler(telephone),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.phone, size: 13, color: Color(0xFF1E3A8A)),
                  const SizedBox(width: 4),
                  Text(telephone, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF1E3A8A))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _afficherDialogAffecterMatiere(int matiereId, String matiereNom) async {
    int? enseignantId;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text('Affecter — $matiereNom'),
            content: DropdownButtonFormField<int>(
              value: enseignantId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Enseignant'),
              items: _tousEnseignants.map((e) => DropdownMenuItem<int>(value: e['id'] as int, child: Text(e['name'] as String))).toList(),
              onChanged: (v) => setStateDialog(() => enseignantId = v),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
              ElevatedButton(
                onPressed: enseignantId == null
                    ? null
                    : () async {
                        try {
                          await AffectationService.ajouterAffectation(
                            enseignantId: enseignantId!,
                            classeId: widget.classeId,
                            matiereId: matiereId,
                          );
                          if (context.mounted) Navigator.pop(context);
                          _afficherSucces('Enseignant affecté');
                          _chargerTout();
                        } catch (e) {
                          _afficherErreur(e.toString().replaceAll('Exception: ', ''));
                        }
                      },
                child: const Text('Affecter'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // TAB 4 — MATIÈRES
  // ══════════════════════════════════════════════════════

  Widget _tabMatieres() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _afficherDialogAjouterMatiere,
        backgroundColor: const Color(0xFF0D9488),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Ajouter une matière', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: RefreshIndicator(
        onRefresh: _chargerTout,
        child: _matieresClasse.isEmpty
            ? ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text('Aucune matière configurée', style: GoogleFonts.inter(color: const Color(0xFF334155)))),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: _matieresClasse.length,
                itemBuilder: (context, index) => _carteMatiere(_matieresClasse[index]),
              ),
      ),
    );
  }

  Widget _carteMatiere(dynamic matiere) {
    final matiereId = matiere['matiere_id'] as int;
    final affectation = _affectationPourMatiere(matiereId);
    final nomEnseignant = affectation != null ? affectation['enseignant_nom'] as String : null;
    final volumeHoraire = _creneauxPour(matiereId: matiereId)
        .fold<double>(0, (total, c) => total + _dureeEnHeures(c['heure_debut'] as String, c['heure_fin'] as String));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(matiere['matiere_nom'] as String, style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SSMBadge(label: 'Coef ${matiere['coefficient']}', couleur: const Color(0xFF1E3A8A)),
                    if (nomEnseignant != null)
                      Text(nomEnseignant, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF334155)))
                    else
                      const SSMBadge(label: 'Non affecté', couleur: Color(0xFFEA580C)),
                  ],
                ),
                if (volumeHoraire > 0) ...[
                  const SizedBox(height: 4),
                  Text('${volumeHoraire.toStringAsFixed(1)} h/semaine', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 18, color: Color(0xFF1E3A8A)),
            onPressed: () => _afficherDialogModifierCoefficient(matiere),
          ),
        ],
      ),
    );
  }

  Future<void> _afficherDialogModifierCoefficient(dynamic matiere) async {
    final controller = TextEditingController(text: '${matiere['coefficient'] ?? 1}');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Coefficient — ${matiere['matiere_nom']}'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Coefficient'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              final coef = double.tryParse(controller.text.replaceAll(',', '.'));
              if (coef == null || coef <= 0) return;
              try {
                await ClasseMatiereService.ajouter(widget.classeId, matiere['matiere_id'] as int, coef);
                if (context.mounted) Navigator.pop(context);
                _afficherSucces('Coefficient mis à jour');
                _chargerTout();
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

  Future<void> _afficherDialogAjouterMatiere() async {
    final matieresDisponibles = _toutesMatieres
        .where((m) => !_matieresClasse.any((mc) => mc['matiere_id'] == m['id']))
        .toList();

    if (matieresDisponibles.isEmpty) {
      _afficherErreur('Toutes les matières sont déjà configurées pour cette classe');
      return;
    }

    int? matiereId = matieresDisponibles.first['id'] as int;
    final coefController = TextEditingController(text: '1');

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Ajouter une matière'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: matiereId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Matière'),
                  items: matieresDisponibles.map((m) => DropdownMenuItem<int>(value: m['id'] as int, child: Text(m['nom'] as String))).toList(),
                  onChanged: (v) => setStateDialog(() => matiereId = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: coefController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Coefficient'),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
              ElevatedButton(
                onPressed: () async {
                  final coef = double.tryParse(coefController.text.replaceAll(',', '.')) ?? 1;
                  try {
                    await ClasseMatiereService.ajouter(widget.classeId, matiereId!, coef);
                    if (context.mounted) Navigator.pop(context);
                    _afficherSucces('Matière ajoutée à la classe');
                    _chargerTout();
                  } catch (e) {
                    _afficherErreur(e.toString().replaceAll('Exception: ', ''));
                  }
                },
                child: const Text('Ajouter'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // TAB 5 — EMPLOI DU TEMPS
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: () async {
              if (_anneeId == null) return;
              try {
                final chemin = await EmploiDuTempsService.telechargerPdf(classeId: widget.classeId, anneeId: _anneeId!);
                await OpenFile.open(chemin);
              } catch (e) {
                _afficherErreur(e.toString().replaceAll('Exception: ', ''));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            icon: const Icon(Icons.picture_as_pdf, size: 16),
            label: const Text('Exporter EDT PDF'),
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: 60 + (5 * 120),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const SizedBox(width: 60),
                          ..._jours.map((j) => Expanded(
                                child: Center(child: Text(j['label']!, style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w700))),
                              )),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ..._grilleHoraire.map((row) {
                        final debut = row['debut'] as String;
                        final fin = row['fin'] as String;
                        final recreation = row['recreation'] as bool;

                        if (recreation) {
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(color: Colors.amber[100], borderRadius: BorderRadius.circular(6)),
                            child: Center(
                              child: Text('🔶 RÉCRÉATION', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber[900])),
                            ),
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 60,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 20),
                                child: Text('$debut\n$fin', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
                              ),
                            ),
                            ..._jours.map((j) {
                              final c = _creneauPourCellule(j['cle']!, debut);
                              return Expanded(
                                child: GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => EmploiDuTempsClasseScreen(classeId: widget.classeId, classeNom: _classe!['nom'] as String),
                                    ),
                                  ).then((_) => _chargerTout()),
                                  child: Container(
                                    height: 60,
                                    margin: const EdgeInsets.all(2),
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: c != null ? _couleurMatiere(c['matiere_id'] as int) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: c != null
                                        ? Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(c['matiere_nom'] as String,
                                                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                              Text(c['enseignant_nom'] as String,
                                                  style: GoogleFonts.inter(fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            ],
                                          )
                                        : const Center(child: Icon(Icons.add, size: 16, color: Colors.grey)),
                                  ),
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
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  // TAB 6 — STATISTIQUES
  // ══════════════════════════════════════════════════════

  Widget _tabStatistiques() {
    final stats = _statistiques ?? {};
    final garcons = (stats['garcons'] as num?)?.toInt() ?? 0;
    final filles  = (stats['filles'] as num?)?.toInt() ?? 0;
    final moyenne = (stats['moyenne_generale'] as num?)?.toDouble();
    final tauxReussite = (stats['taux_reussite'] as num?)?.toDouble() ?? 0;
    final totalAbsences = (stats['total_absences'] as num?)?.toInt() ?? 0;
    final totalPaiements = (stats['total_paiements'] as num?)?.toDouble() ?? 0;
    final elevesEnDifficulte = (stats['eleves_en_difficulte'] as List?) ?? [];

    return RefreshIndicator(
      onRefresh: _chargerTout,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.45,
            children: [
              _carteStatGrid('Effectif', '${garcons + filles}', 'G: $garcons · F: $filles', Icons.people, const Color(0xFF1E3A8A)),
              _carteStatGraphMoyenne(moyenne),
              _carteStatProgression('Taux de réussite', tauxReussite / 100, '${tauxReussite.toStringAsFixed(0)}%', const Color(0xFF16A34A)),
              _carteStatGrid('Absences', '$totalAbsences', 'total enregistrées', Icons.event_busy, const Color(0xFFEA580C)),
            ],
          ),
          const SizedBox(height: 16),
          _carteGlass(
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet, color: Color(0xFF0D9488)),
                const SizedBox(width: 10),
                Expanded(child: Text('Total encaissé', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF334155)))),
                Text('${totalPaiements.toStringAsFixed(0)} FCFA', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0D9488))),
              ],
            ),
          ),
          SSMSectionTitre(titre: 'Élèves en difficulté (moyenne < 8)'),
          if (elevesEnDifficulte.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF16A34A).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
              child: Text('Aucun élève en difficulté 🎉', style: GoogleFonts.inter(color: const Color(0xFF166534))),
            )
          else
            ...elevesEnDifficulte.map((e) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      Expanded(child: Text('${e['nom']} ${e['prenom']}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600))),
                      SSMBadge(label: '${e['moyenne']}/20', couleur: const Color(0xFFDC2626)),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Widget _carteStatGrid(String label, String valeur, String sousLabel, IconData icone, Color couleur) {
    return _carteGlass(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: couleur.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icone, color: couleur, size: 16),
          ),
          const SizedBox(height: 6),
          Text(valeur, style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF334155)), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(sousLabel, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _carteStatGraphMoyenne(double? moyenne) {
    return _carteGlass(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Moyenne générale', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
          const SizedBox(height: 4),
          Expanded(
            child: moyenne == null
                ? Center(child: Text('—', style: GoogleFonts.sora(fontSize: 18, color: const Color(0xFF94A3B8))))
                : Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: PieChart(PieChartData(
                            sectionsSpace: 0,
                            centerSpaceRadius: 20,
                            sections: [
                              PieChartSectionData(value: moyenne, color: const Color(0xFF1E3A8A), showTitle: false, radius: 11),
                              PieChartSectionData(value: (20 - moyenne).clamp(0, 20), color: const Color(0xFFF1F5F9), showTitle: false, radius: 11),
                            ],
                          )),
                        ),
                        Text(moyenne.toStringAsFixed(1), style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _carteStatProgression(String label, double valeur, String texte, Color couleur) {
    return _carteGlass(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF334155)), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Text(texte, style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: couleur)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(value: valeur.clamp(0.0, 1.0), minHeight: 6, backgroundColor: const Color(0xFFF1F5F9), color: couleur),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // TAB 7 — CAHIER DE TEXTE
  // ══════════════════════════════════════════════════════

  List<dynamic> get _cahierTexteFiltre {
    if (_filtreMatiereCahier == null) return _cahierTexte;
    return _cahierTexte.where((e) => e['matiere_id'] == _filtreMatiereCahier).toList();
  }

  Widget _tabCahierTexte() {
    final estEnseignant = _utilisateurConnecte?.estEnseignant == true;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: estEnseignant
          ? FloatingActionButton.extended(
              onPressed: _afficherDialogAjouterCahierTexte,
              backgroundColor: const Color(0xFF1E3A8A),
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text('Ajouter une entrée', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _chargerTout,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chipMatiereCahier('Toutes', null),
                  ..._matieresClasse.map((m) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _chipMatiereCahier(m['matiere_nom'] as String, m['matiere_id'] as int),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_cahierTexteFiltre.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Aucune entrée', style: GoogleFonts.inter(color: const Color(0xFF334155)))),
              )
            else
              ..._cahierTexteFiltre.map(_carteCahierTexte),
          ],
        ),
      ),
    );
  }

  Widget _chipMatiereCahier(String label, int? matiereId) {
    final selectionne = _filtreMatiereCahier == matiereId;
    return GestureDetector(
      onTap: () => setState(() => _filtreMatiereCahier = matiereId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selectionne ? const Color(0xFF1E3A8A) : const Color(0xFF1E3A8A).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: selectionne ? Colors.white : const Color(0xFF1E3A8A))),
      ),
    );
  }

  Widget _carteCahierTexte(dynamic entree) {
    final enseignant = entree['enseignant'] as Map<String, dynamic>?;
    final matiere    = entree['matiere'] as Map<String, dynamic>?;
    final dateCours  = (entree['date_cours'] as String?)?.split('T').first;
    final dateRemise = (entree['date_remise_devoir'] as String?)?.split('T').first;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(dateCours ?? '—', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
              const SizedBox(width: 8),
              Text(matiere?['nom'] as String? ?? '', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Cours du jour', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
          Text(entree['cours_du_jour'] as String? ?? '', style: GoogleFonts.inter(fontSize: 13)),
          if (entree['exercices'] != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFF0284C7).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Text('Exercices : ${entree['exercices']}', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF0284C7))),
            ),
          ],
          if (entree['devoir'] != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFEA580C).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(
                dateRemise != null ? 'Devoir : ${entree['devoir']} (pour le $dateRemise)' : 'Devoir : ${entree['devoir']}',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFEA580C)),
              ),
            ),
          ],
          if (enseignant != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: const Color(0xFF1E3A8A).withValues(alpha: 0.15),
                  child: Text((enseignant['name'] as String).substring(0, 1).toUpperCase(),
                      style: GoogleFonts.sora(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF1E3A8A))),
                ),
                const SizedBox(width: 6),
                Text(enseignant['name'] as String, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF334155))),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _afficherDialogAjouterCahierTexte() async {
    if (_matieresClasse.isEmpty) {
      _afficherErreur('Aucune matière configurée pour cette classe');
      return;
    }

    int matiereId = _matieresClasse.first['matiere_id'] as int;
    DateTime dateCours = DateTime.now();
    DateTime? dateRemiseDevoir;
    final coursController = TextEditingController();
    final exercicesController = TextEditingController();
    final devoirController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nouvelle entrée', style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<int>(
                              value: matiereId,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Matière'),
                              items: _matieresClasse.map((m) => DropdownMenuItem<int>(value: m['matiere_id'] as int, child: Text(m['matiere_nom'] as String))).toList(),
                              onChanged: (v) => setStateDialog(() => matiereId = v ?? matiereId),
                            ),
                            const SizedBox(height: 12),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.date_range),
                              title: Text('Date du cours : ${dateCours.day}/${dateCours.month}/${dateCours.year}'),
                              onTap: () async {
                                final d = await showDatePicker(context: context, initialDate: dateCours, firstDate: DateTime(2020), lastDate: DateTime(2035));
                                if (d != null) setStateDialog(() => dateCours = d);
                              },
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: coursController,
                              maxLines: 3,
                              decoration: const InputDecoration(labelText: 'Cours du jour *', alignLabelWithHint: true),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: exercicesController,
                              maxLines: 2,
                              decoration: const InputDecoration(labelText: 'Exercices', alignLabelWithHint: true),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: devoirController,
                              maxLines: 2,
                              decoration: const InputDecoration(labelText: 'Devoir', alignLabelWithHint: true),
                            ),
                            const SizedBox(height: 8),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.event),
                              title: Text(dateRemiseDevoir != null
                                  ? 'Remise devoir : ${dateRemiseDevoir!.day}/${dateRemiseDevoir!.month}/${dateRemiseDevoir!.year}'
                                  : 'Date de remise du devoir (optionnel)'),
                              onTap: () async {
                                final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2035));
                                if (d != null) setStateDialog(() => dateRemiseDevoir = d);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler'))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
                            onPressed: () async {
                              if (coursController.text.isEmpty) {
                                _afficherErreur('Le cours du jour est obligatoire');
                                return;
                              }
                              try {
                                await CahierTexteService.creer(
                                  classeId: widget.classeId,
                                  matiereId: matiereId,
                                  dateCours: _formatDate(dateCours),
                                  coursDuJour: coursController.text,
                                  exercices: exercicesController.text.isEmpty ? null : exercicesController.text,
                                  devoir: devoirController.text.isEmpty ? null : devoirController.text,
                                  dateRemiseDevoir: dateRemiseDevoir != null ? _formatDate(dateRemiseDevoir!) : null,
                                );
                                if (context.mounted) Navigator.pop(context);
                                _afficherSucces('Entrée enregistrée');
                                _chargerTout();
                              } catch (e) {
                                _afficherErreur(e.toString().replaceAll('Exception: ', ''));
                              }
                            },
                            child: const Text('Enregistrer'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget tabBar;
  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => tabBar;

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}
