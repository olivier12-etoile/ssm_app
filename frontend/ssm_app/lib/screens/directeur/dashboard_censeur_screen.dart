import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/dashboard_service.dart';
import '../../services/classe_service.dart';
import '../../services/annee_service.dart';
import '../../services/eleve_service.dart';
import '../../models/utilisateur.dart';
import '../../services/auth_service.dart';
import '../dashboard/menu_lateral.dart';
import '../../widgets/ssm_widgets.dart';
import '../directeur/validation_notes_screen.dart';
import '../directeur/eleves_par_classe_screen.dart';
import '../censeur/suivi_absences_classe_screen.dart';

class DashboardCenseurScreen extends StatefulWidget {
  const DashboardCenseurScreen({super.key});

  @override
  State<DashboardCenseurScreen> createState() =>
      _DashboardCenseurScreenState();
}

class _DashboardCenseurScreenState extends State<DashboardCenseurScreen> {
  Map<String, dynamic>? _donnees;
  Utilisateur? _utilisateur;
  List<dynamic> _classes = [];
  Map<int, int> _effectifs = {};
  int? _anneeId;
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _chargerTout();
  }

  Future<void> _chargerTout() async {
    try {
      final u = await AuthService.getUtilisateur();
      final resultats = await Future.wait([
        DashboardService.chargerDashboard(),
        ClasseService.listerClasses(),
        AnneeService.listerAnnees(),
      ]);

      final data = resultats[0] as Map<String, dynamic>;
      final classes = resultats[1] as List;
      final annees = resultats[2] as List;
      final anneeEnCours = annees.firstWhere(
        (a) => a['statut'] == 'en_cours',
        orElse: () => annees.isNotEmpty ? annees.first : null,
      );
      final anneeId = anneeEnCours?['id'] as int?;

      var effectifs = <int, int>{};
      if (anneeId != null && classes.isNotEmpty) {
        try {
          final listes = await Future.wait(classes.map(
            (c) => EleveService.elevesParClasse(c['id'] as int, anneeId),
          ));
          for (var i = 0; i < classes.length; i++) {
            effectifs[classes[i]['id'] as int] = listes[i].length;
          }
        } catch (_) {
          // Les effectifs restent vides si le calcul échoue — non bloquant.
        }
      }

      setState(() {
        _utilisateur = u;
        _donnees     = data;
        _classes     = classes;
        _effectifs   = effectifs;
        _anneeId     = anneeId;
        _chargement  = false;
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

  int _absencesJourPourClasse(int classeId, List<dynamic> absencesJour) {
    return absencesJour.where((a) => a['classe']?['id'] == classeId).length;
  }

  int _notesAttentePourClasse(int classeId) {
    // Laravel sérialise une collection pluck() vide en `[]` (liste) et non
    // en `{}` (objet) — on ne peut donc pas caster directement en Map.
    final brut = _donnees?['notes_a_valider_par_classe'];
    if (brut is Map) {
      return (brut['$classeId'] as int?) ?? 0;
    }
    return 0;
  }

  Color _couleurMoyenne(double moyenne) {
    if (moyenne >= 14) return SSMBadge.succes;
    if (moyenne >= 10) return SSMBadge.avertissement;
    return SSMBadge.erreur;
  }

  Color _couleurRang(int rang) {
    switch (rang) {
      case 1: return const Color(0xFFFFD700); // Or
      case 2: return const Color(0xFFC0C0C0); // Argent
      case 3: return const Color(0xFFCD7F32); // Bronze
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement || _utilisateur == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final notesAValider   = (_donnees?['notes_a_valider'] as List?) ?? [];
    final totalAValider   = (_donnees?['total_notes_a_valider'] as int?) ?? 0;
    final absencesJour    = (_donnees?['absences_aujourdhui'] as List?) ?? [];
    final absencesSemaine = (_donnees?['absences_semaine'] as List?) ?? [];
    final moyennesClasses = (_donnees?['moyennes_classes'] as List?) ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Espace Censeur',
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
              sousTitre: 'Vue pédagogique et disciplinaire',
              valeurPrincipale: '$totalAValider',
              labelValeur: 'notes à valider',
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Alerte notes à valider ──────────────────
                  if (totalAValider > 0) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: const Border(
                          left: BorderSide(color: Color(0xFF0284C7), width: 4),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.pending_actions,
                                  color: Color(0xFF0284C7)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '$totalAValider note(s) en attente de validation',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0284C7),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ValidationNotesScreen(),
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E3A8A),
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Valider maintenant'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Emplois du temps ─────────────────────────
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF1E3A8A),
                        child:
                            Icon(Icons.calendar_view_week, color: Colors.white),
                      ),
                      title: const Text('Emplois du temps',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          Navigator.pushNamed(context, '/emploi-du-temps'),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Mes classes ──────────────────────────────
                  SSMSectionTitre(titre: 'Mes classes'),
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
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ..._classes.map((classe) {
                      final classeId = classe['id'] as int;
                      final classeNom = classe['nom'] as String;
                      final effectif = _effectifs[classeId] ?? 0;
                      final capaciteMax = (classe['capacite_max'] as int?) ?? 50;
                      final absencesClasse =
                          _absencesJourPourClasse(classeId, absencesJour);
                      final notesAttenteClasse =
                          _notesAttentePourClasse(classeId);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SSMCarteClasse(
                              nom: classeNom,
                              nombreEleves: effectif,
                              capaciteMax: capaciteMax,
                              onTap: () {
                                if (_anneeId == null) return;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ElevesParClasseScreen(
                                      classeId: classeId,
                                      anneeId: _anneeId!,
                                      nomClasse: classeNom,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '$absencesClasse absence(s) • $notesAttenteClasse note(s) en attente',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: const Color(0xFF334155),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        settings: const RouteSettings(
                                            name: '/censeur/classe/absences'),
                                        builder: (_) =>
                                            SuiviAbsencesClasseScreen(
                                          classeId: classeId,
                                          classeNom: classeNom,
                                        ),
                                      ),
                                    ),
                                    child: const Text('📋 Présences'),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ValidationNotesScreen(
                                          classeIdPreselectionne: classeId,
                                        ),
                                      ),
                                    ),
                                    child: const Text('✅ Notes'),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _anneeId == null
                                        ? null
                                        : () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    ElevesParClasseScreen(
                                                  classeId: classeId,
                                                  anneeId: _anneeId!,
                                                  nomClasse: classeNom,
                                                ),
                                              ),
                                            ),
                                    child: const Text('👥 Élèves'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 24),

                  // ── Notes récentes à valider ──────────────────
                  if (notesAValider.isNotEmpty) ...[
                    SSMSectionTitre(titre: 'Notes récentes à valider'),
                    ...notesAValider.take(5).map((n) {
                      final eleve = n['eleve'];
                      final matiere = n['matiere'];
                      final enseignant = n['enseignant'];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
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
                        child: SSMListeTile(
                          titre: eleve != null
                              ? '${eleve['nom']} ${eleve['prenom']}'
                              : 'Élève inconnu',
                          sousTitre:
                              '${matiere?['nom'] ?? ''} • Par ${enseignant?['name'] ?? '—'}',
                          icone: Icons.grade,
                          couleurIcone: const Color(0xFF0284C7),
                          trailing: Text(
                            '${n['valeur']}',
                            style: GoogleFonts.sora(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0284C7),
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                  ],

                  // ── Absences du jour ───────────────────────────
                  SSMSectionTitre(titre: 'Absences aujourd\'hui'),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: (absencesJour.isEmpty
                              ? SSMBadge.succes
                              : SSMBadge.avertissement)
                          .withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          absencesJour.isEmpty
                              ? Icons.check_circle
                              : Icons.warning_amber,
                          color: absencesJour.isEmpty
                              ? SSMBadge.succes
                              : SSMBadge.avertissement,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          absencesJour.isEmpty
                              ? 'Aucune absence signalée aujourd\'hui'
                              : '${absencesJour.length} absence(s) aujourd\'hui',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Absences cette semaine ─────────────────────
                  SSMSectionTitre(titre: 'Absences cette semaine'),
                  if (absencesSemaine.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Aucune absence cette semaine',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: absencesSemaine.map<Widget>((a) {
                          final nom = a['nom'] as String;
                          final total = a['total'] as int;
                          final max = absencesSemaine
                              .map((e) => e['total'] as int)
                              .reduce((x, y) => x > y ? x : y);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                SizedBox(width: 70, child: Text(nom)),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: total / max,
                                      backgroundColor: Colors.grey[200],
                                      color: const Color(0xFF0D9488),
                                      minHeight: 8,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('$total',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // ── Classement des classes ─────────────────────
                  SSMSectionTitre(titre: 'Classement des classes'),
                  if (moyennesClasses.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Aucune note validée pour le moment',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    ...moyennesClasses.asMap().entries.map((entry) {
                      final i = entry.key;
                      final c = entry.value;
                      final rang = i + 1;
                      final moyenne =
                          double.tryParse(c['moyenne'].toString()) ?? 0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
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
                        child: SSMListeTile(
                          titre: '#$rang · ${c['nom']}',
                          icone: rang <= 3
                              ? Icons.military_tech
                              : Icons.leaderboard,
                          couleurIcone: _couleurRang(rang),
                          trailing: Text(
                            '$moyenne/20',
                            style: GoogleFonts.sora(
                              fontWeight: FontWeight.bold,
                              color: _couleurMoyenne(moyenne),
                            ),
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
}
