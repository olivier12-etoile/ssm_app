import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/auth_service.dart';

class MatiereService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type':  'application/json',
      'Accept':        'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<List<dynamic>> listerMatieres() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/matieres'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement matières');
  }

  static Future<void> creerMatiere({
    required String nom,
    String? code,
    double coefficient = 1.0,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/matieres'),
      headers: await _headers(),
      body: jsonEncode({
        'nom':         nom,
        'code':        code,
        'coefficient': coefficient,
      }),
    );
    if (response.statusCode != 201) {
      throw Exception('Erreur création matière');
    }
  }
}