import 'package:flutter/material.dart';
import '../../services/sync_service.dart';

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
              ? Colors.green
              : Colors.red,
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
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Oui',
                style: TextStyle(color: Colors.white)),
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
      appBar: AppBar(
        title: const Text('Synchronisation'),
        backgroundColor: Colors.blueGrey,
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
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: _estConnecte
                                ? Colors.green
                                : Colors.red,
                            child: Icon(
                              _estConnecte
                                  ? Icons.wifi
                                  : Icons.wifi_off,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                _estConnecte
                                    ? 'Connecté à Internet'
                                    : 'Hors ligne',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '${_queue.length} requête(s) en attente',
                                style: const TextStyle(
                                    color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
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
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
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
                          label: Text(_synchronisation
                              ? 'Synchronisation...'
                              : 'Synchroniser'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (_queue.isNotEmpty)
                        ElevatedButton.icon(
                          onPressed: _viderQueue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.delete),
                          label: const Text('Vider'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── File d'attente ─────────────────────────
                  if (_queue.isEmpty)
                    const Center(
                      child: Column(
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 64, color: Colors.green),
                          SizedBox(height: 16),
                          Text(
                            'Toutes les données sont synchronisées',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Données en attente',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._queue.asMap().entries.map((entry) {
                          final i = entry.key;
                          final r = entry.value;
                          return Card(
                            margin:
                                const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    Colors.blueGrey,
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              title: Text(
                                '${r['methode']} — ${r['url']}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                r['timestamp'] as String,
                                style: const TextStyle(
                                    fontSize: 11),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                ],
              ),
            ),
    );
  }
}