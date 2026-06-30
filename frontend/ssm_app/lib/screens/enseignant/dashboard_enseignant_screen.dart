import 'package:flutter/material.dart';
import '../../services/dashboard_service.dart';
import '../../models/utilisateur.dart';
import '../../services/auth_service.dart';
import '../../screens/dashboard/menu_lateral.dart';
import '../enseignant/saisie_notes_screen.dart';
import '../enseignant/saisie_absences_screen.dart';

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

  Color _couleurStatut(String statut) {
    switch (statut) {
      case 'valide':    return Colors.green;
      case 'soumis':    return Colors.blue;
      case 'rejete':    return Colors.red;
      case 'brouillon': return Colors.orange;
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

    final affectations  = (_donnees?['affectations'] as List?) ?? [];
    final notes          = _donnees?['notes'] as Map<String, dynamic>? ?? {};
    final absencesJour   = (_donnees?['absences_aujourdhui'] as List?) ?? [];
    final notesRejetees  = (_donnees?['notes_rejetees'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon espace enseignant'),
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
              '${affectations.length} affectation(s) en cours',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),

            // ── Alerte notes rejetées ──────────────────────
            if (notesRejetees.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(
                          '${notesRejetees.length} note(s) rejetée(s) à corriger',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...notesRejetees.take(3).map((n) {
                      final eleve   = n['eleve'];
                      final matiere = n['matiere'];
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '• ${eleve?['nom']} ${eleve?['prenom']} — ${matiere?['nom']}',
                          style: const TextStyle(fontSize: 12),
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
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
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

            // ── Statut de mes notes ─────────────────────────
            const Text(
              'Statut de mes notes',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _carteStatutNote('Brouillon', notes['brouillon'] ?? 0,
                    _couleurStatut('brouillon')),
                const SizedBox(width: 8),
                _carteStatutNote('Soumis', notes['soumis'] ?? 0,
                    _couleurStatut('soumis')),
                const SizedBox(width: 8),
                _carteStatutNote('Validé', notes['valide'] ?? 0,
                    _couleurStatut('valide')),
                const SizedBox(width: 8),
                _carteStatutNote('Rejeté', notes['rejete'] ?? 0,
                    _couleurStatut('rejete')),
              ],
            ),
            const SizedBox(height: 24),

            // ── Mes classes affectées ───────────────────────
            const Text(
              'Mes classes & matières',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            if (affectations.isEmpty)
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
              ...affectations.map((a) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.indigo,
                      child: Icon(Icons.class_, color: Colors.white),
                    ),
                    title: Text(a['classe_nom'] as String),
                    subtitle: Text(
                        '${a['matiere_nom']} • Coef. ${a['coefficient']}'),
                  ),
                );
              }),
            const SizedBox(height: 24),

            // ── Absences marquées aujourd'hui ───────────────
            const Text(
              'Absences marquées aujourd\'hui',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            if (absencesJour.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Aucune absence saisie aujourd\'hui'),
                  ],
                ),
              )
            else
              ...absencesJour.map((a) {
                final eleve = a['eleve'];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.brown,
                      child: Icon(Icons.event_busy, color: Colors.white),
                    ),
                    title: Text(
                      eleve != null
                          ? '${eleve['nom']} ${eleve['prenom']}'
                          : 'Élève inconnu',
                    ),
                    trailing: a['notifie'] == true
                        ? const Chip(
                            label: Text('Notifié', style: TextStyle(fontSize: 11)),
                            backgroundColor: Colors.green,
                            labelStyle: TextStyle(color: Colors.white),
                          )
                        : const Chip(
                            label: Text('Non notifié', style: TextStyle(fontSize: 11)),
                          ),
                  ),
                );
              }),
            const SizedBox(height: 24),

            // ── Actions rapides ──────────────────────────────
            const Text(
              'Actions rapides',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SaisieNotesScreen()),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(14),
                    ),
                    icon: const Icon(Icons.edit_note),
                    label: const Text('Saisir notes'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SaisieAbsencesScreen()),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.brown,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(14),
                    ),
                    icon: const Icon(Icons.event_busy),
                    label: const Text('Saisir absences'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _carteStatutNote(String label, dynamic valeur, Color couleur) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Text(
                '$valeur',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: couleur,
                ),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}