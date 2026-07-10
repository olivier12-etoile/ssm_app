import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/notification_attente_service.dart';
import '../../services/whatsapp_service.dart';
import '../../widgets/ssm_widgets.dart';

class NotificationsAttenteScreen extends StatefulWidget {
  const NotificationsAttenteScreen({super.key});

  @override
  State<NotificationsAttenteScreen> createState() =>
      _NotificationsAttenteScreenState();
}

class _NotificationsAttenteScreenState
    extends State<NotificationsAttenteScreen> {
  List<dynamic> _notifications = [];
  Map<String, dynamic> _parType = {};
  bool _chargement             = true;
  String _filtreActuel         = 'tout';
  bool _modeEnvoiChaine        = false;
  int _indexChaine             = 0;

  @override
  void initState() {
    super.initState();
    _chargerNotifications();
  }

  Future<void> _chargerNotifications() async {
    setState(() => _chargement = true);
    try {
      final data = await NotificationAttenteService.lister(
        type: _filtreActuel,
      );
      setState(() {
        _notifications = data['notifications'] as List;
        _parType       = data['par_type'] as Map<String, dynamic>;
        _chargement    = false;
      });
    } catch (e) {
      setState(() => _chargement = false);
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _afficherErreur(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFFDC2626)),
    );
  }

  void _afficherSucces(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFF16A34A)),
    );
  }

  IconData _iconeType(String type) {
    switch (type) {
      case 'absence':  return Icons.event_busy;
      case 'paiement': return Icons.payment;
      case 'bulletin': return Icons.description;
      default:         return Icons.notifications;
    }
  }

  Color _couleurType(String type) {
    switch (type) {
      case 'absence':  return Colors.brown;
      case 'paiement': return Colors.teal;
      case 'bulletin': return Colors.deepPurple;
      default:         return Colors.grey;
    }
  }

  // Envoyer une seule notification
  Future<void> _envoyerUne(dynamic notif) async {
    final eleve     = notif['eleve'];
    final telephone = notif['telephone_parent'] as String;
    final message   = notif['message'] as String;
    final id        = notif['id'] as int;

    final succes = await WhatsAppService.envoyerMessage(
      numeroTelephone: telephone,
      message:         message,
    );

    if (succes) {
      try {
        await NotificationAttenteService.marquerEnvoyee(id);
        _afficherSucces(
            'Envoyé à ${eleve != null ? eleve['nom'] : 'parent'}');
        _chargerNotifications();
      } catch (e) {
        _afficherErreur('Erreur marquage envoyé');
      }
    } else {
      _afficherErreur('Impossible d\'ouvrir WhatsApp');
    }
  }

  // ── Mode envoi en chaîne ────────────────────────────────
  Future<void> _demarrerEnvoiChaine() async {
    if (_notifications.isEmpty) return;
    setState(() {
      _modeEnvoiChaine = true;
      _indexChaine     = 0;
    });
    await _envoyerSuivantChaine();
  }

  Future<void> _envoyerSuivantChaine() async {
    if (_indexChaine >= _notifications.length) {
      setState(() => _modeEnvoiChaine = false);
      _afficherSucces('Toutes les notifications ont été traitées !');
      _chargerNotifications();
      return;
    }

    final notif = _notifications[_indexChaine];
    final telephone = notif['telephone_parent'] as String;
    final message   = notif['message'] as String;
    final id        = notif['id'] as int;

    final succes = await WhatsAppService.envoyerMessage(
      numeroTelephone: telephone,
      message:         message,
    );

    if (succes) {
      await NotificationAttenteService.marquerEnvoyee(id);
    }

    setState(() => _indexChaine++);
  }

  Future<void> _supprimer(int id) async {
    try {
      await NotificationAttenteService.supprimer(id);
      _afficherSucces('Notification supprimée');
      _chargerNotifications();
    } catch (e) {
      _afficherErreur(e.toString().replaceAll('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Notifications à envoyer',
          style: GoogleFonts.sora(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF16A34A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerNotifications,
          ),
        ],
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Filtres ──────────────────────────────
                Container(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.05),
                  padding: const EdgeInsets.all(12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _chipFiltre('tout', 'Tout',
                            (_parType['absence'] ?? 0) +
                                (_parType['paiement'] ?? 0) +
                                (_parType['bulletin'] ?? 0)),
                        const SizedBox(width: 8),
                        _chipFiltre('absence', 'Absences',
                            _parType['absence'] ?? 0),
                        const SizedBox(width: 8),
                        _chipFiltre('paiement', 'Paiements',
                            _parType['paiement'] ?? 0),
                        const SizedBox(width: 8),
                        _chipFiltre('bulletin', 'Bulletins',
                            _parType['bulletin'] ?? 0),
                      ],
                    ),
                  ),
                ),

                // ── Bouton envoi en chaîne ─────────────────
                if (_notifications.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _demarrerEnvoiChaine,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(14),
                        ),
                        icon: const Icon(Icons.send),
                        label: Text(
                          'Envoyer tout (${_notifications.length})',
                        ),
                      ),
                    ),
                  ),

                // ── Mode chaîne actif ──────────────────────
                if (_modeEnvoiChaine)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: Colors.orange[100],
                    child: Column(
                      children: [
                        Text(
                          'Envoi en cours : ${_indexChaine + 1} / ${_notifications.length}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _envoyerSuivantChaine,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange[800],
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.skip_next),
                          label: const Text('Continuer → Suivant'),
                        ),
                      ],
                    ),
                  ),

                // ── Liste ──────────────────────────────────
                Expanded(
                  child: _notifications.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline,
                                  size: 64, color: Colors.green),
                              SizedBox(height: 16),
                              Text(
                                'Aucune notification en attente',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _notifications.length,
                          itemBuilder: (context, index) {
                            final notif = _notifications[index];
                            final type  = notif['type'] as String;
                            final eleve = notif['eleve'];

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
                                sousTitre: type.toUpperCase(),
                                icone: _iconeType(type),
                                couleurIcone: _couleurType(type),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.message,
                                        color: Color(0xFF16A34A),
                                      ),
                                      tooltip: 'Envoyer via WhatsApp',
                                      onPressed: () => _envoyerUne(notif),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.close,
                                        color: Color(0xFFDC2626),
                                      ),
                                      tooltip: 'Supprimer',
                                      onPressed: () =>
                                          _supprimer(notif['id'] as int),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _chipFiltre(String valeur, String label, int compteur) {
    final actif = _filtreActuel == valeur;
    return GestureDetector(
      onTap: () {
        setState(() => _filtreActuel = valeur);
        _chargerNotifications();
      },
      child: Container(
        decoration: actif
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(9999),
                border: const Border.fromBorderSide(
                  BorderSide(color: Color(0xFF16A34A), width: 2),
                ),
              )
            : null,
        padding: actif ? const EdgeInsets.all(2) : EdgeInsets.zero,
        child: SSMBadge(
          label: '$label ($compteur)',
          couleur: const Color(0xFF16A34A),
        ),
      ),
    );
  }
}