import 'package:flutter/material.dart';
import '../../services/dashboard_service.dart';
import '../../models/utilisateur.dart';
import '../../services/auth_service.dart';
import '../dashboard/menu_lateral.dart';
import '../directeur/validation_notes_screen.dart';

class DashboardCenseurScreen extends StatefulWidget {
  const DashboardCenseurScreen({super.key});

  @override
  State<DashboardCenseurScreen> createState() =>
      _DashboardCenseurScreenState();
}

class _DashboardCenseurScreenState extends State<DashboardCenseurScreen> {
  Map<String, dynamic>? _donnees;
  Utilisateur? _utilisateur;
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
      setState(() {
        _utilisateur = u;
        _donnees     = data;
        _chargement  = false;
      });
    } catch (e) {
      setState(() => _chargement = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _couleurMoyenne(double moyenne) {
    if (moyenne >= 14) return Colors.green;
    if (moyenne >= 10) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement || _utilisateur == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final notesAValider   = (_donnees?['notes_a_valider'] as List?) ?? [];
    final totalAValider   = _donnees?['total_notes_a_valider'] ?? 0;
    final absencesJour    = (_donnees?['absences_aujourdhui'] as List?) ?? [];
    final absencesSemaine = (_donnees?['absences_semaine'] as List?) ?? [];
    final moyennesClasses = (_donnees?['moyennes_classes'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon espace censeur'),
        backgroundColor: Color(
          int.parse(_utilisateur!.couleurPrimaire.replaceAll('#', '0xFF')),
        ),
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
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Bonjour, ${_utilisateur!.nom} 👋',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Vue pédagogique et disciplinaire',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),

            // ── Alerte notes à valider ──────────────────────
            if (totalAValider > 0) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.pending_actions, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          '$totalAValider note(s) en attente de validation',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
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
                          backgroundColor: Colors.blue,
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

            // ── Aperçu des notes en attente ──────────────────
            if (notesAValider.isNotEmpty) ...[
              const Text(
                'Notes récentes à valider',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 10),
              ...notesAValider.take(5).map((n) {
                final eleve       = n['eleve'];
                final matiere     = n['matiere'];
                final enseignant  = n['enseignant'];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Text(
                        '${n['valeur']}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      eleve != null
                          ? '${eleve['nom']} ${eleve['prenom']}'
                          : 'Élève inconnu',
                    ),
                    subtitle: Text(
                      '${matiere?['nom'] ?? ''} • Par ${enseignant?['name'] ?? '—'}',
                    ),
                  ),
                );
              }),
              const SizedBox(height: 24),
            ],

            // ── Absences du jour ──────────────────────────────
            const Text(
              'Absences aujourd\'hui',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: absencesJour.isEmpty
                    ? Colors.green[50]
                    : Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    absencesJour.isEmpty
                        ? Icons.check_circle
                        : Icons.warning_amber,
                    color: absencesJour.isEmpty
                        ? Colors.green
                        : Colors.orange,
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

            // ── Absences par classe (semaine) ─────────────────
            const Text(
              'Absences cette semaine par classe',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
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
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: absencesSemaine.map<Widget>((a) {
                      final nom   = a['nom'] as String;
                      final total = a['total'] as int;
                      final max   = absencesSemaine
                          .map((e) => e['total'] as int)
                          .reduce((x, y) => x > y ? x : y);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(width: 70, child: Text(nom)),
                            Expanded(
                              child: LinearProgressIndicator(
                                value: total / max,
                                backgroundColor: Colors.grey[200],
                                color: Colors.brown,
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(4),
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
              ),
            const SizedBox(height: 24),

            // ── Classement moyennes par classe ────────────────
            const Text(
              'Classement des classes (moyenne)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
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
                final moyenne = double.tryParse(c['moyenne'].toString()) ?? 0;
                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: i == 0 ? Colors.amber : Colors.grey[300],
                      child: Text('${i + 1}'),
                    ),
                    title: Text(c['nom'] as String),
                    trailing: Text(
                      '$moyenne/20',
                      style: TextStyle(
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
    );
  }
}