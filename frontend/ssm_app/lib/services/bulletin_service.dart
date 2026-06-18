import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/auth_service.dart';

class BulletinService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type':  'application/json',
      'Accept':        'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Bulletin d'un élève
  static Future<Map<String, dynamic>> genererBulletin({
    required int eleveId,
    required int periodeId,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/bulletins/eleve'),
      headers: await _headers(),
      body: jsonEncode({
        'eleve_id':   eleveId,
        'periode_id': periodeId,
      }),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur génération bulletin');
  }

  // Bulletins d'une classe
  static Future<Map<String, dynamic>> bulletinsClasse({
    required int classeId,
    required int periodeId,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/bulletins/classe'),
      headers: await _headers(),
      body: jsonEncode({
        'classe_id':  classeId,
        'periode_id': periodeId,
      }),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur génération bulletins classe');
  }
}