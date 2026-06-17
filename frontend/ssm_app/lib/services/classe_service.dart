import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/auth_service.dart';

class ClasseService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type':  'application/json',
      'Accept':        'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<List<dynamic>> listerClasses() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/classes'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Erreur chargement classes');
  }

  static Future<void> creerClasse({
    required String nom,
    required String niveau,
    int capaciteMax = 50,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/classes'),
      headers: await _headers(),
      body: jsonEncode({
        'nom':          nom,
        'niveau':       niveau,
        'capacite_max': capaciteMax,
      }),
    );
    if (response.statusCode != 201) {
      throw Exception('Erreur création classe');
    }
  }
}