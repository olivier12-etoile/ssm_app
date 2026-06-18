import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../config/app_config.dart';
import '../services/auth_service.dart';

class SyncService {
  static const String _queueKey = 'sync_queue';

  // ── Vérifier la connexion ─────────────────────────────
  static Future<bool> estConnecte() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  // ── Ajouter une requête à la file d'attente ───────────
  static Future<void> ajouterAQueue({
    required String methode,
    required String url,
    Map<String, dynamic>? corps,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final queueStr = prefs.getString(_queueKey) ?? '[]';
    final queue = jsonDecode(queueStr) as List;

    queue.add({
      'methode':    methode,
      'url':        url,
      'corps':      corps,
      'timestamp':  DateTime.now().toIso8601String(),
    });

    await prefs.setString(_queueKey, jsonEncode(queue));
    debugPrint('✅ Requête ajoutée à la queue offline: $methode $url');
  }

  // ── Voir la file d'attente ────────────────────────────
  static Future<List<dynamic>> voirQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final queueStr = prefs.getString(_queueKey) ?? '[]';
    return jsonDecode(queueStr) as List;
  }

  // ── Synchroniser toutes les requêtes en attente ───────
  static Future<SyncResultat> synchroniser() async {
    final connecte = await estConnecte();
    if (!connecte) {
      return SyncResultat(
        succes:  0,
        echecs:  0,
        message: 'Pas de connexion internet',
      );
    }

    final prefs    = await SharedPreferences.getInstance();
    final queueStr = prefs.getString(_queueKey) ?? '[]';
    final queue    = jsonDecode(queueStr) as List;

    if (queue.isEmpty) {
      return SyncResultat(
        succes:  0,
        echecs:  0,
        message: 'Aucune donnée en attente',
      );
    }

    final token = await AuthService.getToken();
    final headers = {
      'Content-Type':  'application/json',
      'Accept':        'application/json',
      'Authorization': 'Bearer $token',
    };

    int succes = 0;
    int echecs = 0;
    final restant = <dynamic>[];

    for (final requete in queue) {
      try {
        final methode = requete['methode'] as String;
        final url     = requete['url'] as String;
        final corps   = requete['corps'] as Map<String, dynamic>?;

        http.Response response;

        switch (methode.toUpperCase()) {
          case 'POST':
            response = await http.post(
              Uri.parse(url),
              headers: headers,
              body: corps != null ? jsonEncode(corps) : null,
            );
            break;
          case 'PATCH':
            response = await http.patch(
              Uri.parse(url),
              headers: headers,
              body: corps != null ? jsonEncode(corps) : null,
            );
            break;
          case 'DELETE':
            response = await http.delete(
              Uri.parse(url),
              headers: headers,
            );
            break;
          default:
            response = await http.get(
              Uri.parse(url),
              headers: headers,
            );
        }

        if (response.statusCode >= 200 && response.statusCode < 300) {
          succes++;
          debugPrint('✅ Sync réussie: $methode $url');
        } else {
          echecs++;
          restant.add(requete);
          debugPrint('❌ Sync échouée: $methode $url - ${response.statusCode}');
        }
      } catch (e) {
        echecs++;
        restant.add(requete);
        debugPrint('❌ Sync erreur: $e');
      }
    }

    // Garder seulement les requêtes échouées
    await prefs.setString(_queueKey, jsonEncode(restant));

    return SyncResultat(
      succes:  succes,
      echecs:  echecs,
      message: '$succes synchronisée(s), $echecs échouée(s)',
    );
  }

  // ── Vider la file d'attente ───────────────────────────
  static Future<void> viderQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_queueKey, '[]');
  }

  // ── Nombre de requêtes en attente ─────────────────────
  static Future<int> nombreEnAttente() async {
    final queue = await voirQueue();
    return queue.length;
  }
}

class SyncResultat {
  final int succes;
  final int echecs;
  final String message;

  SyncResultat({
    required this.succes,
    required this.echecs,
    required this.message,
  });
}