import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/dashboard_service.dart';
import '../../services/annee_service.dart';
import '../../services/eleve_service.dart';
import '../../models/utilisateur.dart';
import '../../services/auth_service.dart';
import '../../screens/dashboard/menu_lateral.dart';
import '../../widgets/ssm_widgets.dart';
import '../enseignant/saisie_notes_screen.dart';
import '../enseignant/liste_presence_screen.dart';
import '../emploi_du_temps/emploi_du_temps_enseignant_screen.dart';

class DashboardEnseignantScreen extends StatefulWidget {
  const DashboardEnseignantScreen({super.key});

  @override
  State<DashboardEnseignantScreen> createState() =>
      _DashboardEnseignantScreenState();
}

class _DashboardEnseignantScreenState
    extends State<DashboardEnseignantScreen> {
  Map<String, dynamic>? _donnees;
  Utilisateur? _utilisateur;
  int _totalEleves = 0;
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _chargerTout();
  }

  Future<void> _chargerTout() async {
    try {
      final u = await AuthService.getUtilisateur();
      final data = await DashboardService.chargerDashboard();

      final affectations = (data['affectations'] as List?) ?? [];
      final classesGroupees = <int>{};
      for (final a in affectations) {
        classesGroupees.add(a['classe_id'] as int);
      }

      var totalEleves = 0;
      if (classesGroupees.isNotEmpty) {
        try {
          final annees = await AnneeService.listerAnnees();
          final anneeEnCours = annees.firstWhere(
            (a) => a['statut'] == 'en_cours',
            orElse: () => annees.isNotEmpty ? annees.first : null,
          );
          final anneeId = anneeEnCours?['id'] as int?;

          if (anneeId != null) {
            final listes = await Future.wait(classesGroupees.map(
              (classeId) => EleveService.elevesParClasse(classeId, anneeId),
            ));
            totalEleves = listes.fold<int>(0, (total, l) => total + l.length);
          }
        } catch (_) {
          // Le total élèves reste à 0 si le calcul échoue — non bloquant.
        }
      }

      setState(() {
        _utilisateur = u;
        _donnees = data;
        _totalEleves = totalEleves;
        _chargement = false;
      });
    } catch (e) {
      setState(() => _chargement = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  Color _couleurStatut(String statut) {
    switch (statut) {
      case 'valide':    return SSMBadge.succes;
      case 'soumis':    return SSMBadge.info;
      case 'rejete':    return SSMBadge.erreur;
      case 'brouillon': return SSMBadge.avertissement;
      default:          return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement || _utilisateur == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Laravel sérialise un pluck() vide en `[]` (liste) et non en `{}`
    // (objet) — on ne peut donc pas caster directement en Map.
    final notesBrut = _donnees?['notes'];
    final notes = notesBrut is Map
        ? Map<String, dynamic>.from(notesBrut)
        : <String, dynamic>{};
    final absencesJour = (_donnees?['absences_aujourdhui'] as List?) ?? [];
    final notesRejetees = (_donnees?['notes_rejetees'] as List?) ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Mon espace',
          style: GoogleFonts.sora(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _chargement = true);
              _chargerTout();
            },
          ),
        ],
      ),
      drawer: MenuLateral(utilisateur: _utilisateur!),
      body: RefreshIndicator(
        onRefresh: _chargerTout,
        child: ListView(
          children: [
            SSMEnteteEcran(
              salutation: 'Bonjour, ${_utilisateur!.nom} 👋',
              sousTitre: '${_classesAffectees.length} classe(s) affectée(s)',
              valeurPrincipale: '$_totalEleves',
              labelValeur: 'élèves',
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Mon emploi du temps ──────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          settings: const RouteSettings(
                              name: '/emploi-du-temps/enseignant'),
                          builder: (_) => const EmploiDuTempsEnseignantScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.calendar_view_week),
                      label: const Text('Mon emploi du temps'),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Alerte notes rejetées ──────────────────
                  if (notesRejetees.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.warning_amber,
                                  color: Color(0xFFDC2626)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${notesRejetees.length} note(s) rejetée(s) à corriger',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...notesRejetees.take(3).map((n) {
                            final eleve = n['eleve'];
                            final matiere = n['matiere'];
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '• ${eleve?['nom']} ${eleve?['prenom']} — ${matiere?['nom']}',
                                style: GoogleFonts.inter(fontSize: 12),
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SaisieNotesScreen(),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFDC2626),
                                side: const BorderSide(color: Color(0xFFDC2626)),
                              ),
                              icon: const Icon(Icons.edit),
                              label: const Text('Corriger maintenant'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Statut de mes notes ─────────────────────
                  Text(
                    'Statut de mes notes',
                    style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.4,
                    children: [
                      SSMStatCard(
                        titre: 'Brouillon',
                        valeur: '${notes['brouillon'] ?? 0}',
                        icone: Icons.edit,
                        couleurIcone: _couleurStatut('brouillon'),
                      ),
                      SSMStatCard(
                        titre: 'Soumis',
                        valeur: '${notes['soumis'] ?? 0}',
                        icone: Icons.send,
                        couleurIcone: _couleurStatut('soumis'),
                      ),
                      SSMStatCard(
                        titre: 'Validé',
                        valeur: '${notes['valide'] ?? 0}',
                        icone: Icons.check_circle,
                        couleurIcone: _couleurStatut('valide'),
                      ),
                      SSMStatCard(
                        titre: 'Rejeté',
                        valeur: '${notes['rejete'] ?? 0}',
                        icone: Icons.cancel,
                        couleurIcone: _couleurStatut('rejete'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Mes classes & matières ───────────────────
                  SSMSectionTitre(titre: 'Mes classes & matières'),
                  if (_classesAffectees.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Aucune classe affectée pour le moment.\nContactez la direction.',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ..._classesAffectees.map((classe) {
                      final classeId = classe['classe_id'] as int;
                      final classeNom = classe['classe_nom'] as String;
                      final matieres =
                          (classe['matieres'] as List<String>).join(', ');

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: const Border(
                            left: BorderSide(
                                color: Color(0xFF1E3A8A), width: 4),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
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
                            const SizedBox(height: 2),
                            Text(
                              matieres,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _boutonCarteClasse(
                                    icone: Icons.event_available,
                                    label: 'Présences',
                                    couleur: const Color(0xFF0D9488),
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ListePresenceScreen(
                                          classeId: classeId,
                                          classeNom: classeNom,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _boutonCarteClasse(
                                    icone: Icons.edit_note,
                                    label: 'Notes',
                                    couleur: const Color(0xFF1E3A8A),
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => SaisieNotesScreen(
                                          classeIdPreselectionne: classeId,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 24),

                  // ── Absences aujourd'hui ─────────────────────
                  SSMSectionTitre(titre: 'Absences aujourd\'hui'),
                  if (absencesJour.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: SSMBadge.succes.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: SSMBadge.succes),
                          const SizedBox(width: 8),
                          const Text('Aucune absence saisie aujourd\'hui'),
                        ],
                      ),
                    )
                  else
                    ...absencesJour.map((a) {
                      final eleve = a['eleve'];
                      final notifie = a['notifie'] == true;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: SSMListeTile(
                          titre: eleve != null
                              ? '${eleve['nom']} ${eleve['prenom']}'
                              : 'Élève inconnu',
                          icone: Icons.event_busy,
                          couleurIcone: const Color(0xFFEA580C),
                          trailing: SSMBadge(
                            label: notifie ? 'Notifié' : 'Non notifié',
                            couleur: notifie
                                ? SSMBadge.succes
                                : SSMBadge.avertissement,
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _boutonCarteClasse({
    required IconData icone,
    required String label,
    required Color couleur,
    required VoidCallback onTap,
  }) {
    return Material(
      color: couleur.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icone, size: 18, color: couleur),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: couleur,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _classesAffectees {
    final affectations = (_donnees?['affectations'] as List?) ?? [];
    final classesGroupees = <int, Map<String, dynamic>>{};

    for (final a in affectations) {
      final classeId = a['classe_id'] as int;
      classesGroupees.putIfAbsent(classeId, () => {
            'classe_id': classeId,
            'classe_nom': a['classe_nom'],
            'matieres': <String>[],
          });
      (classesGroupees[classeId]!['matieres'] as List<String>)
          .add(a['matiere_nom'] as String);
    }

    return classesGroupees.values.toList();
  }
}
