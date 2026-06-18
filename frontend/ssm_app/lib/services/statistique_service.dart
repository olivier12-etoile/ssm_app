import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/auth_service.dart';

class StatistiqueService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type':  'application/json',
      'Accept':        'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> chargerStatistiques({
    int? anneeId,
  }) async {
    final url = anneeId != null
        ? '${AppConfig.apiBaseUrl}/statistiques?annee_id=$anneeId'
        : '${AppConfig.apiBaseUrl}/statistiques';

    final response = await http.get(
      Uri.parse(url),
      headers: await _headers(),
    );

    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement statistiques');
  }
}