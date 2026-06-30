import 'package:flutter/material.dart';
import '../../services/dashboard_service.dart';
import '../../models/utilisateur.dart';
import '../../services/auth_service.dart';
import '../dashboard/menu_lateral.dart';
import '../secretaire/gestion_paiements_screen.dart';
import '../secretaire/liste_renvoi_screen.dart';
import '../notifications/notifications_attente_screen.dart';

class DashboardSecretaireScreen extends StatefulWidget {
  const DashboardSecretaireScreen({super.key});

  @override
  State<DashboardSecretaireScreen> createState() =>
      _DashboardSecretaireScreenState();
}

class _DashboardSecretaireScreenState
    extends State<DashboardSecretaireScreen> {
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

  @override
  Widget build(BuildContext context) {
    if (_chargement || _utilisateur == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final encaisseJour   = _donnees?['encaisse_aujourdhui'] ?? 0;
    final encaisseMois   = _donnees?['encaisse_mois'] ?? 0;
    final derniers       = (_donnees?['derniers_paiements'] as List?) ?? [];
    final notifications  = _donnees?['notifications'] as Map<String, dynamic>? ?? {};
    final totalEleves    = _donnees?['total_eleves'] ?? 0;
    final totalNotif     = notifications['total'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon espace secrétariat'),
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
              '$totalEleves élève(s) inscrit(s)',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),

            // ── Cartes encaissements ─────────────────────────
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.teal,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.today, color: Colors.white70),
                        const SizedBox(height: 8),
                        Text(
                          '$encaisseJour FCFA',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const Text(
                          'Encaissé aujourd\'hui',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.teal[700],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.calendar_month, color: Colors.white70),
                        const SizedBox(height: 8),
                        Text(
                          '$encaisseMois FCFA',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const Text(
                          'Encaissé ce mois',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Badge notifications en attente ────────────────
            if (totalNotif > 0)
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationsAttenteScreen(),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.send_to_mobile, color: Colors.green),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$totalNotif notification(s) WhatsApp en attente '
                          '(${notifications['absence'] ?? 0} absences, '
                          '${notifications['paiement'] ?? 0} paiements, '
                          '${notifications['bulletin'] ?? 0} bulletins)',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.green),
                    ],
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.grey),
                    SizedBox(width: 10),
                    Text('Aucune notification en attente'),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // ── Derniers paiements ─────────────────────────────
            const Text(
              'Derniers paiements',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            if (derniers.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Aucun paiement enregistré',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ...derniers.map((p) {
                final eleve = p['eleve'];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.teal,
                      child: Icon(Icons.payment, color: Colors.white),
                    ),
                    title: Text(
                      eleve != null
                          ? '${eleve['nom']} ${eleve['prenom']}'
                          : 'Élève inconnu',
                    ),
                    subtitle: Text('${p['tranche']} • ${p['date_paiement']}'),
                    trailing: Text(
                      '${p['montant']} FCFA',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
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
                          builder: (_) => const GestionPaiementsScreen()),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(14),
                    ),
                    icon: const Icon(Icons.payment),
                    label: const Text('Paiements'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ListeRenvoiScreen()),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(14),
                    ),
                    icon: const Icon(Icons.person_remove),
                    label: const Text('Liste renvoi'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}