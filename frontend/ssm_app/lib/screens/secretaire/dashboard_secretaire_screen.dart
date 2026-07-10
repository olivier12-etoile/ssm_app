import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/dashboard_service.dart';
import '../../models/utilisateur.dart';
import '../../services/auth_service.dart';
import '../dashboard/menu_lateral.dart';
import '../../widgets/ssm_widgets.dart';
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
          backgroundColor: const Color(0xFFDC2626),
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

    final encaisseJour  = _donnees?['encaisse_aujourdhui'] ?? 0;
    final encaisseMois  = _donnees?['encaisse_mois'] ?? 0;
    final derniers      = (_donnees?['derniers_paiements'] as List?) ?? [];
    final notifications =
        _donnees?['notifications'] as Map<String, dynamic>? ?? {};
    final totalEleves = _donnees?['total_eleves'] ?? 0;
    final totalNotif  = (notifications['total'] as int?) ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Espace Secrétariat',
          style: GoogleFonts.sora(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0D9488),
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
              sousTitre: '$totalEleves élève(s) inscrit(s)',
              valeurPrincipale: '$totalEleves',
              labelValeur: 'élèves',
              couleur: const Color(0xFF0D9488),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Cartes encaissements ───────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D9488),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.today, color: Colors.white),
                              const SizedBox(height: 8),
                              Text(
                                '$encaisseJour FCFA',
                                style: GoogleFonts.sora(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 20,
                                ),
                              ),
                              Text(
                                'Encaissé aujourd\'hui',
                                style: GoogleFonts.inter(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 12,
                                ),
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
                            color: const Color(0xFF0F766E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.calendar_month,
                                  color: Colors.white),
                              const SizedBox(height: 8),
                              Text(
                                '$encaisseMois FCFA',
                                style: GoogleFonts.sora(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 20,
                                ),
                              ),
                              Text(
                                'Encaissé ce mois',
                                style: GoogleFonts.inter(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Badge notifications en attente ──────────
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
                          color: const Color(0xFF16A34A).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color:
                                  const Color(0xFF16A34A).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.send_to_mobile,
                                color: Color(0xFF16A34A)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '$totalNotif notification(s) WhatsApp en attente '
                                '(${notifications['absence'] ?? 0} absences, '
                                '${notifications['paiement'] ?? 0} paiements, '
                                '${notifications['bulletin'] ?? 0} bulletins)',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF166534),
                                ),
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                color: Color(0xFF16A34A)),
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

                  // ── Derniers paiements ───────────────────────
                  SSMSectionTitre(
                    titre: 'Derniers paiements',
                    action: 'Voir tout',
                    onAction: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        settings: const RouteSettings(name: '/paiements'),
                        builder: (_) => const GestionPaiementsScreen(),
                      ),
                    ),
                  ),
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
                          sousTitre: '${p['tranche']} • ${p['date_paiement']}',
                          icone: Icons.payment,
                          couleurIcone: const Color(0xFF0D9488),
                          trailing: Text(
                            '${p['montant']} FCFA',
                            style: GoogleFonts.sora(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0D9488),
                            ),
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 24),

                  // ── Actions rapides ──────────────────────────
                  SSMSectionTitre(titre: 'Actions rapides'),
                  Row(
                    children: [
                      Expanded(
                        child: SSMActionRapide(
                          icone: Icons.payment,
                          label: 'Paiements',
                          couleur: const Color(0xFF0D9488),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const GestionPaiementsScreen(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SSMActionRapide(
                          icone: Icons.person_remove,
                          label: 'Liste renvoi',
                          couleur: const Color(0xFFDC2626),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ListeRenvoiScreen(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
