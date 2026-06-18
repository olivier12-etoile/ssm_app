import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/sync_service.dart';

class StatutConnexionWidget extends StatefulWidget {
  const StatutConnexionWidget({super.key});

  @override
  State<StatutConnexionWidget> createState() =>
      _StatutConnexionWidgetState();
}

class _StatutConnexionWidgetState extends State<StatutConnexionWidget> {
  bool _estConnecte        = true;
  int _nombreEnAttente     = 0;
  bool _synchronisation    = false;

  @override
  void initState() {
    super.initState();
    _verifierConnexion();
    _ecouter();
  }

  Future<void> _verifierConnexion() async {
    final connecte  = await SyncService.estConnecte();
    final enAttente = await SyncService.nombreEnAttente();
    setState(() {
      _estConnecte     = connecte;
      _nombreEnAttente = enAttente;
    });

    // Si connecté et données en attente → syncer auto
    if (connecte && enAttente > 0) {
      _synchroniserAuto();
    }
  }

  void _ecouter() {
    Connectivity().onConnectivityChanged.listen((result) {
      final connecte = result != ConnectivityResult.none;
      setState(() => _estConnecte = connecte);

      if (connecte && _nombreEnAttente > 0) {
        _synchroniserAuto();
      }
    });
  }

  Future<void> _synchroniserAuto() async {
    setState(() => _synchronisation = true);

    final resultat = await SyncService.synchroniser();
    final enAttente = await SyncService.nombreEnAttente();

    setState(() {
      _nombreEnAttente  = enAttente;
      _synchronisation  = false;
    });

    if (mounted && resultat.succes > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${resultat.message}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_estConnecte && _nombreEnAttente == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: _estConnecte ? Colors.orange : Colors.red[700],
      child: Row(
        children: [
          Icon(
            _estConnecte ? Icons.sync : Icons.wifi_off,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _estConnecte
                  ? '$_nombreEnAttente donnée(s) en attente de synchronisation'
                  : 'Mode hors-ligne — données sauvegardées localement',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ),
          if (_estConnecte && _nombreEnAttente > 0)
            _synchronisation
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : TextButton(
                    onPressed: _synchroniserAuto,
                    child: const Text(
                      'Syncer',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
        ],
      ),
    );
  }
}