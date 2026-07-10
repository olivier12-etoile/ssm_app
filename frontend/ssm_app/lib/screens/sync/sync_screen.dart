import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/sync_service.dart';
import '../../widgets/ssm_widgets.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  List<dynamic> _queue      = [];
  bool _chargement          = true;
  bool _synchronisation     = false;
  bool _estConnecte         = false;

  @override
  void initState() {
    super.initState();
    _chargerDonnees();
  }

  Future<void> _chargerDonnees() async {
    final queue    = await SyncService.voirQueue();
    final connecte = await SyncService.estConnecte();
    setState(() {
      _queue       = queue;
      _estConnecte = connecte;
      _chargement  = false;
    });
  }

  Future<void> _synchroniser() async {
    setState(() => _synchronisation = true);
    final resultat = await SyncService.synchroniser();
    await _chargerDonnees();
    setState(() => _synchronisation = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resultat.message),
          backgroundColor: resultat.succes > 0
              ? const Color(0xFF16A34A)
              : const Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _viderQueue() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vider la file d\'attente'),
        content: const Text(
          'Voulez-vous supprimer toutes les données en attente ?\nCes données ne seront pas synchronisées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Oui', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirme == true) {
      await SyncService.viderQueue();
      _chargerDonnees();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Synchronisation',
          style: GoogleFonts.sora(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF334155),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerDonnees,
          ),
        ],
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // ── Statut connexion ──────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _estConnecte
                          ? const Color(0xFF16A34A).withValues(alpha: 0.08)
                          : const Color(0xFFDC2626).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _estConnecte
                            ? const Color(0xFF16A34A).withValues(alpha: 0.3)
                            : const Color(0xFFDC2626).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: _estConnecte
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFDC2626),
                          child: Icon(
                            _estConnecte ? Icons.wifi : Icons.wifi_off,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _estConnecte
                                    ? 'Connecté à Internet'
                                    : 'Hors ligne',
                                style: GoogleFonts.sora(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_queue.length} requête(s) en attente',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _estConnecte
                            ? const SSMBadge(
                                label: 'CONNECTÉ',
                                couleur: Color(0xFF16A34A),
                              )
                            : const SSMBadge(
                                label: 'HORS LIGNE',
                                couleur: Color(0xFFDC2626),
                              ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Boutons actions ────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _estConnecte && !_synchronisation
                              ? _synchroniser
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: _synchronisation
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.sync),
                          label: Text(
                            _synchronisation
                                ? 'Synchronisation...'
                                : 'Synchroniser',
                            style: GoogleFonts.sora(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (_queue.isNotEmpty)
                        ElevatedButton.icon(
                          onPressed: _viderQueue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.delete),
                          label: Text(
                            'Vider',
                            style: GoogleFonts.sora(fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── File d'attente ─────────────────────────
                  if (_queue.isEmpty)
                    Center(
                      child: Column(
                        children: [
                          const Icon(Icons.check_circle_outline,
                              size: 64, color: Color(0xFF16A34A)),
                          const SizedBox(height: 16),
                          Text(
                            'Toutes les données sont synchronisées',
                            style: GoogleFonts.inter(color: const Color(0xFF334155)),
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SSMSectionTitre(titre: 'Données en attente'),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: _queue.map((r) {
                              return SSMListeTile(
                                titre: '${r['methode']} — ${r['url']}',
                                icone: Icons.cloud_upload_outlined,
                                couleurIcone: const Color(0xFF334155),
                                dateHeure: r['timestamp'] as String?,
                              );
                            }).toList(),
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
