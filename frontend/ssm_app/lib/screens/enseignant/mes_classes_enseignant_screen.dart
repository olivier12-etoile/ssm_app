import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/utilisateur.dart';
import '../../services/affectation_service.dart';
import '../../services/annee_service.dart';
import '../../services/auth_service.dart';
import '../../services/eleve_service.dart';
import '../../theme/ssm_theme.dart';
import '../../widgets/ssm/ssm_page_scaffold.dart';
import '../../widgets/ssm/ssm_pill.dart';
import '../../widgets/ssm/ssm_quick_action_button.dart';
import '../../widgets/ssm/ssm_sidebar.dart';
import '../notes/selection_saisie_screen.dart';
import '../presences/appel_presence_screen.dart';
import '../emploi_du_temps/emploi_du_temps_module_screen.dart';

Color _couleurDepuisHex(String? hex) {
  if (hex == null || hex.isEmpty) return SSMPalette.indigo;
  try {
    return Color(int.parse(hex.replaceAll('#', '0xFF')));
  } catch (_) {
    return SSMPalette.indigo;
  }
}

// ══════════════════════════════════════════════════════════
// MesClassesEnseignantScreen — liste des classes affectées à
// l'enseignant connecté, avec accès rapide (Notes / Appel /
// Emploi du temps / Cahier) pour chacune.
// ══════════════════════════════════════════════════════════
class MesClassesEnseignantScreen extends StatefulWidget {
  const MesClassesEnseignantScreen({super.key});

  @override
  State<MesClassesEnseignantScreen> createState() => _MesClassesEnseignantScreenState();
}

class _MesClassesEnseignantScreenState extends State<MesClassesEnseignantScreen> {
  Utilisateur? _utilisateur;
  List<Map<String, dynamic>> _classes = [];
  Map<int, int> _nombreElevesParClasse = {};
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _chargement = true);
    try {
      final utilisateur = await AuthService.getUtilisateur();
      if (utilisateur == null) {
        setState(() => _chargement = false);
        return;
      }

      final affectationsData = await AffectationService.listerAffectations(utilisateur.id);
      final affectations = (affectationsData['affectations'] as List?) ?? [];

      final classesGroupees = <int, Map<String, dynamic>>{};
      for (final a in affectations) {
        final classeId = a['classe_id'] as int;
        classesGroupees.putIfAbsent(
          classeId,
          () => {
            'classe_id': classeId,
            'classe_nom': a['classe_nom'],
            'matieres': <Map<String, dynamic>>[],
          },
        );
        (classesGroupees[classeId]!['matieres'] as List<Map<String, dynamic>>).add({
          'matiere_id': a['matiere_id'],
          'matiere_nom': a['matiere_nom'],
          'coefficient': a['coefficient'],
          'couleur': a['couleur'],
        });
      }
      final classes = classesGroupees.values.toList();

      var nombreElevesParClasse = <int, int>{};
      try {
        final anneeActiveData = await AnneeService.anneeActive();
        final anneeActive = anneeActiveData['annee'] as Map<String, dynamic>?;
        final anneeId = anneeActive?['id'] as int?;
        if (anneeId != null && classes.isNotEmpty) {
          final listes = await Future.wait(
            classes.map((c) => EleveService.elevesParClasse(c['classe_id'] as int, anneeId)),
          );
          for (var i = 0; i < classes.length; i++) {
            nombreElevesParClasse[classes[i]['classe_id'] as int] = listes[i].length;
          }
        }
      } catch (_) {
        // Effectifs non bloquants si le calcul échoue.
      }

      if (!mounted) return;
      setState(() {
        _utilisateur = utilisateur;
        _classes = classes;
        _nombreElevesParClasse = nombreElevesParClasse;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _chargement = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: SSMPalette.rouge),
      );
    }
  }

  List<SSMNavSection> _sections() {
    return const [
      SSMNavSection(titre: 'Principal', items: [
        SSMNavItem(icone: Icons.dashboard_outlined, label: 'Tableau de bord', route: '/dashboard/enseignant'),
        SSMNavItem(icone: Icons.class_outlined, label: 'Mes classes', route: '/enseignant/mes-classes'),
        SSMNavItem(icone: Icons.edit_note_outlined, label: 'Notes & évaluations', route: '/notes'),
        SSMNavItem(icone: Icons.how_to_reg_outlined, label: 'Présences / Appel', route: '/enseignant/appel'),
        SSMNavItem(icone: Icons.calendar_view_week_outlined, label: 'Mon emploi du temps', route: '/emploi-du-temps'),
      ]),
      SSMNavSection(titre: 'Général', items: [
        SSMNavItem(icone: Icons.notifications_outlined, label: 'Notifications', route: '/notifications'),
        SSMNavItem(icone: Icons.settings_outlined, label: 'Paramètres', route: '/parametres'),
      ]),
    ];
  }

  void _naviguer(BuildContext context, String route) {
    if (route == '/enseignant/mes-classes') return;
    if (route == '/enseignant/appel') {
      _ouvrirSelectionAppel();
      return;
    }
    Navigator.pushNamed(context, route);
  }

  Future<void> _ouvrirSelectionAppel() async {
    if (_classes.isEmpty) return;
    if (_classes.length == 1) {
      _ouvrirAppel(_classes.first);
      return;
    }
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text('Faire l\'appel — choisir une classe',
                  style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
            ),
            for (final c in _classes)
              ListTile(
                leading: const Icon(Icons.class_outlined, color: SSMPalette.indigo),
                title: Text(c['classe_nom'] as String, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _ouvrirAppel(c);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _ouvrirAppel(Map<String, dynamic> classe) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AppelPresenceScreen(
          classeId: classe['classe_id'] as int,
          classeNom: classe['classe_nom'] as String,
        ),
      ),
    );
  }

  Future<void> _choisirMatiereCahier(Map<String, dynamic> classe) async {
    final matieres = classe['matieres'] as List<Map<String, dynamic>>;
    if (matieres.length == 1) {
      _ouvrirCahierMatiere(classe, matieres.first);
      return;
    }

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text('Cahier de texte — ${classe['classe_nom']}',
                  style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
            ),
            for (final m in matieres)
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _couleurDepuisHex(m['couleur'] as String?).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.book, color: _couleurDepuisHex(m['couleur'] as String?), size: 18),
                ),
                title: Text('${m['matiere_nom']}', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                subtitle: Text('Coef. ${m['coefficient']}', style: GoogleFonts.inter(fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _ouvrirCahierMatiere(classe, m);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _ouvrirCahierMatiere(Map<String, dynamic> classe, Map<String, dynamic> matiere) {
    Navigator.pushNamed(
      context,
      '/directeur/matiere/fiche',
      arguments: {
        'classeId': classe['classe_id'] as int,
        'classeNom': classe['classe_nom'] as String,
        'matiereId': matiere['matiere_id'] as int,
        'matiereNom': matiere['matiere_nom'] as String,
        'couleurMatiere': _couleurDepuisHex(matiere['couleur'] as String?),
        'coefficient': double.tryParse(matiere['coefficient'].toString()) ?? 1.0,
        'enseignantNom': _utilisateur?.nom,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final utilisateur = _utilisateur;

    return SSMPageScaffold(
      nomEcole: utilisateur?.codeEcole ?? 'Mon établissement',
      codeEcole: utilisateur?.codeEcole ?? '—',
      nomUtilisateur: utilisateur?.nom ?? '…',
      role: 'Enseignant',
      sections: _sections(),
      routeActuelle: '/enseignant/mes-classes',
      onNavigate: (route) => _naviguer(context, route),
      onProfilTap: () => Navigator.pushNamed(context, '/profil'),
      breadcrumb: 'Tableau de bord',
      breadcrumbActuel: 'Mes classes',
      child: _chargement
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: Center(child: CircularProgressIndicator(color: SSMPalette.indigo)),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mes classes',
                    style: GoogleFonts.sora(fontSize: 19, fontWeight: FontWeight.w700, color: SSMPalette.indigo)),
                const SizedBox(height: 3),
                Text('${_classes.length} classe(s) affectée(s)',
                    style: GoogleFonts.inter(fontSize: 12, color: SSMPalette.texte2)),
                const SizedBox(height: 16),
                if (_classes.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    decoration: BoxDecoration(
                      color: SSMPalette.blanc,
                      borderRadius: BorderRadius.circular(SSMRayons.grand),
                      border: Border.all(color: SSMPalette.bordure),
                    ),
                    child: Center(
                      child: Text('Aucune classe affectée pour le moment.\nContactez la direction.',
                          textAlign: TextAlign.center, style: GoogleFonts.inter(color: SSMPalette.texte3)),
                    ),
                  )
                else
                  for (final classe in _classes) ...[
                    _carteClasse(classe),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
    );
  }

  Widget _carteClasse(Map<String, dynamic> classe) {
    final classeId = classe['classe_id'] as int;
    final classeNom = classe['classe_nom'] as String;
    final matieres = classe['matieres'] as List<Map<String, dynamic>>;
    final nombreEleves = _nombreElevesParClasse[classeId];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SSMPalette.blanc,
        borderRadius: BorderRadius.circular(SSMRayons.grand),
        border: Border.all(color: SSMPalette.bordure),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(classeNom,
                    style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: SSMPalette.texte1)),
              ),
              SSMPill.couleur(label: '${nombreEleves ?? '—'} élèves', couleur: SSMPalette.indigo),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: matieres
                .map((m) => SSMPill.couleur(
                      label: '${m['matiere_nom']} (coef ${m['coefficient']})',
                      couleur: _couleurDepuisHex(m['couleur'] as String?),
                    ))
                .toList(),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SSMQuickActionButton(
                icone: Icons.edit_note_outlined,
                label: 'Saisir des notes',
                variante: SSMActionVariante.primaire,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SelectionSaisieScreen()),
                ),
              ),
              SSMQuickActionButton(
                icone: Icons.how_to_reg_outlined,
                label: 'Faire l\'appel',
                variante: SSMActionVariante.teal,
                onTap: () => _ouvrirAppel(classe),
              ),
              SSMQuickActionButton(
                icone: Icons.calendar_view_week_outlined,
                label: 'Emploi du temps',
                variante: SSMActionVariante.gris,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    settings: const RouteSettings(name: '/emploi-du-temps'),
                    builder: (_) => const EmploiDuTempsModuleScreen(),
                  ),
                ),
              ),
              SSMQuickActionButton(
                icone: Icons.menu_book_outlined,
                label: 'Cahier de texte',
                variante: SSMActionVariante.ambre,
                onTap: () => _choisirMatiereCahier(classe),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
