import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../models/statistique_notification_model.dart';

class StatistiqueNotificationService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Map<String, String> _query(String? dateDebut, String? dateFin) {
    final query = <String, String>{};
    if (dateDebut != null) query['date_debut'] = dateDebut;
    if (dateFin != null) query['date_fin'] = dateFin;
    return query;
  }

  // Résumé + évolution, combiné avec la répartition par canal et par
  // catégorie (3 appels API fusionnés en un seul objet typé).
  static Future<StatistiqueNotification> getStatistiques({String? dateDebut, String? dateFin}) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/notifications/statistiques')
        .replace(queryParameters: _query(dateDebut, dateFin).isEmpty ? null : _query(dateDebut, dateFin));

    final response = await http.get(uri, headers: await _headers());
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Erreur chargement des statistiques');
    }

    final parCanal = await getStatistiquesParCanal(dateDebut: dateDebut, dateFin: dateFin);
    final parCategorie = await getStatistiquesParCategorie(dateDebut: dateDebut, dateFin: dateFin);

    return StatistiqueNotification.fromJson({
      ...data as Map<String, dynamic>,
      'par_canal': parCanal,
      'par_categorie': parCategorie,
    });
  }

  static Future<Map<String, int>> getStatistiquesParCanal({String? dateDebut, String? dateFin}) async {
    final query = _query(dateDebut, dateFin);
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/notifications/statistiques/par-canal')
        .replace(queryParameters: query.isEmpty ? null : query);

    final response = await http.get(uri, headers: await _headers());
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Erreur chargement des statistiques par canal');
    }
    final map = data['par_canal'] as Map<String, dynamic>? ?? {};
    return map.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  static Future<Map<String, int>> getStatistiquesParCategorie({String? dateDebut, String? dateFin}) async {
    final query = _query(dateDebut, dateFin);
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/notifications/statistiques/par-categorie')
        .replace(queryParameters: query.isEmpty ? null : query);

    final response = await http.get(uri, headers: await _headers());
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Erreur chargement des statistiques par catégorie');
    }
    final map = data['par_categorie'] as Map<String, dynamic>? ?? {};
    return map.map((k, v) => MapEntry(k, (v as num).toInt()));
  }
}
